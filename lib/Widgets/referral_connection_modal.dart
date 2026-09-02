import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/services/linkrunner_service.dart';
import 'package:connect/Config/supabase_config.dart';
import 'package:connect/services/analytics_service.dart';

class ReferralConnectionModal extends StatefulWidget {
  final Map<String, dynamic> referrerProfile;
  final int referrerId;
  final String? inviteCode;

  const ReferralConnectionModal({
    super.key,
    required this.referrerProfile,
    required this.referrerId,
    this.inviteCode,
  });

  static void _showFeedbackSnackBar(BuildContext context, String message, {bool isSuccess = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.surfaceSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: context.borderMuted.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        content: Row(
          children: [
            if (isSuccess) ...[
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _isCheckingPrompt = false;

  static Future<void> checkAndShowPrompt(BuildContext context, {bool isExplicitLinkClick = false}) async {
    if (_isCheckingPrompt) return;
    _isCheckingPrompt = true;
    try {
      String? pendingReferrerIdStr = await LinkrunnerService.getPendingReferrerId();
      final pendingInviteCode = await LinkrunnerService.getPendingInviteCode();

      if ((pendingReferrerIdStr == null || pendingReferrerIdStr.isEmpty) &&
          (pendingInviteCode == null || pendingInviteCode.isEmpty)) {
        return;
      }

      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
      final myUserId = profileProvider.userId;
      if (myUserId == null) return;

      int? referrerId = pendingReferrerIdStr != null ? int.tryParse(pendingReferrerIdStr) : null;

      // 1. Check invite_codes and invite_code_redemptions status in Supabase
      if (pendingInviteCode != null && pendingInviteCode.isNotEmpty) {
        try {
          // Extract exact MNDL-XXXXXX code string (ignoring surrounding asterisks/punctuation/spaces)
          final RegExp codeRegex = RegExp(r'MNDL-[A-Za-z0-9]+', caseSensitive: false);
          final Match? match = codeRegex.firstMatch(pendingInviteCode);
          final String cleanCode = match != null
              ? match.group(0)!.toUpperCase()
              : pendingInviteCode.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '').toUpperCase().trim();

          final adminClient =
              SupabaseClient(SupabaseConfig.url, SupabaseConfig.serviceRoleKey);

          // Check if this current user already has a recorded action for this code in Supabase
          final userActionRow = await adminClient
              .from('invite_code_redemptions')
              .select('action')
              .ilike('code', cleanCode)
              .eq('user_id', myUserId)
              .maybeSingle();

          if (userActionRow != null) {
            final String action = userActionRow['action']?.toString() ?? 'connected';
            if (action == 'connected') {
              await LinkrunnerService.clearPendingReferralData();
              if (isExplicitLinkClick && context.mounted) {
                _showFeedbackSnackBar(context, "You are already connected using this invite!");
              }
              return;
            } else if (action == 'skipped') {
              if (!isExplicitLinkClick) {
                // Routine app reload / reopen -> Suppress modal
                await LinkrunnerService.clearPendingReferralData();
                return;
              }
              // If isExplicitLinkClick is true, user intentionally clicked the link again in WhatsApp.
              // Fall through to validate expiration and show the modal.
            }
          }

          final codeRow = await adminClient
              .from('invite_codes')
              .select()
              .ilike('code', cleanCode)
              .maybeSingle();

          if (codeRow != null) {
            final String keyType = codeRow['key_type']?.toString() ?? 'single_use';
            if (keyType == 'group_24h') {
              final expiresAtStr = codeRow['expires_at']?.toString();
              if (expiresAtStr != null) {
                final expiresAt = DateTime.parse(expiresAtStr);
                if (DateTime.now().toUtc().isAfter(expiresAt.toUtc())) {
                  await LinkrunnerService.clearPendingReferralData();
                  if (isExplicitLinkClick && context.mounted) {
                    _showFeedbackSnackBar(context, "This 24-hour group invite link has expired.");
                  }
                  return;
                }
              }
            } else {
              final bool isUsed = codeRow['is_used'] == true;
              if (isUsed) {
                // Code has already been used -> Expired link
                await LinkrunnerService.clearPendingReferralData();
                if (isExplicitLinkClick && context.mounted) {
                  _showFeedbackSnackBar(context, "This single-use invite link has already been used.");
                }
                return;
              }

              final bool isSkipped = codeRow['is_skipped'] == true;
              if (isSkipped && !isExplicitLinkClick) {
                // User previously clicked Skip, and this is a routine app reopen.
                await LinkrunnerService.clearPendingReferralData();
                return;
              }
              if (isSkipped && isExplicitLinkClick) {
                // User re-clicked the URL link. Reset is_skipped and show modal.
                try {
                  await adminClient
                      .from('invite_codes')
                      .update({'is_skipped': false})
                      .eq('id', codeRow['id']);
                } catch (e) {
                  debugPrint('[ReferralConnectionModal] Error resetting is_skipped: $e');
                }
              }
            }

            final dynamic senderId = codeRow['sender_id'];
            if (senderId != null) {
              referrerId = int.tryParse(senderId.toString());
            }
          } else {
            // Code row was not found in invite_codes table.
            if (referrerId == null) {
              await LinkrunnerService.clearPendingReferralData();
              return;
            }
          }
        } catch (e) {
          debugPrint('[ReferralConnectionModal] Error querying invite code: $e');
        }
      } else if (referrerId != null) {
        // Plain referrer link without invite_code (e.g. referrer=24)
        // On routine reopens, block if already processed
        if (!isExplicitLinkClick && await LinkrunnerService.isReferrerProcessed(referrerId.toString())) {
          await LinkrunnerService.clearPendingReferralData();
          return;
        }
      }

      // 3. Self-referral check
      if (referrerId == myUserId) {
        await LinkrunnerService.clearPendingReferralData();
        if (isExplicitLinkClick && context.mounted) {
          _showFeedbackSnackBar(context, "This is your own invite link!");
        }
        return;
      }

      if (referrerId == null) {
        await LinkrunnerService.clearPendingReferralData();
        return;
      }

      // 4. Fetch referrer profile details
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', referrerId)
          .maybeSingle();

      if (response == null) {
        await LinkrunnerService.clearPendingReferralData();
        if (isExplicitLinkClick && context.mounted) {
          _showFeedbackSnackBar(context, "Inviter profile was not found.");
        }
        return;
      }

      final Map<String, dynamic> referrerProfile = Map<String, dynamic>.from(response);
      final String referrerName = referrerProfile['full_name'] ?? referrerProfile['name'] ?? 'User';

      // 5. Check if already connected
      final alreadyConnected = connectionProvider.connections.any(
        (c) => (c['id'] == referrerId || c['connection_profile_id'] == referrerId),
      );
      if (alreadyConnected) {
        await LinkrunnerService.markReferrerAsProcessed(
          referrerId.toString(),
          inviteCode: pendingInviteCode,
        );
        if (isExplicitLinkClick && context.mounted) {
          _showFeedbackSnackBar(context, "You are already connected with $referrerName!");
        }
        return;
      }

      // Consume pending referral data so routine app reloads will not re-trigger this modal
      await LinkrunnerService.clearPendingReferralData();

      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => ReferralConnectionModal(
            referrerProfile: referrerProfile,
            referrerId: referrerId!,
            inviteCode: pendingInviteCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ReferralConnectionModal] Error checking pending referral: $e');
    } finally {
      _isCheckingPrompt = false;
    }
  }

  @override
  State<ReferralConnectionModal> createState() => _ReferralConnectionModalState();
}

class _ReferralConnectionModalState extends State<ReferralConnectionModal> {
  bool _isConnecting = false;

  @override
  Widget build(BuildContext context) {
    final String name = widget.referrerProfile['name']?.toString().trim() ?? 'A friend';
    final String avatarUrl = widget.referrerProfile['avatar_url']?.toString() ??
        widget.referrerProfile['avatarUrl']?.toString() ?? '';
    final bool hasAvatar = avatarUrl.isNotEmpty && avatarUrl.startsWith('http');
    final String initial = (name.isNotEmpty) ? name[0].toUpperCase() : 'U';

    return Dialog(
      backgroundColor: context.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User Avatar
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.surfaceSecondary,
                border: Border.all(
                  color: context.accentPrimary,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: hasAvatar
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            initial,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Connection Request Title
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 16,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: name,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: " invited you to connect on Jana!"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Buttons Row
            Row(
              children: [
                // Skip Button
                Expanded(
                  child: TextButton(
                    onPressed: _isConnecting
                        ? null
                        : () async {
                            final myUserId = Provider.of<ProfileProvider>(context, listen: false).userId;
                            final codeToSkip = widget.inviteCode ??
                                await LinkrunnerService.getPendingInviteCode();
                            if (codeToSkip != null && codeToSkip.isNotEmpty && myUserId != null) {
                              try {
                                final RegExp codeRegex =
                                    RegExp(r'MNDL-[A-Za-z0-9]+', caseSensitive: false);
                                final Match? match = codeRegex.firstMatch(codeToSkip);
                                final String cleanCode = match != null
                                    ? match.group(0)!.toUpperCase()
                                    : codeToSkip
                                        .replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '')
                                        .toUpperCase()
                                        .trim();

                                final adminClient = SupabaseClient(
                                    SupabaseConfig.url, SupabaseConfig.serviceRoleKey);

                                // Record user skip in Supabase table
                                await adminClient.from('invite_code_redemptions').upsert(
                                  {
                                    'code': cleanCode,
                                    'user_id': myUserId,
                                    'action': 'skipped',
                                    'created_at': DateTime.now().toUtc().toIso8601String(),
                                  },
                                  onConflict: 'code,user_id',
                                );

                                final codeRow = await adminClient
                                    .from('invite_codes')
                                    .select('key_type')
                                    .ilike('code', cleanCode)
                                    .maybeSingle();

                                final keyType = codeRow?['key_type']?.toString() ?? 'single_use';
                                if (keyType == 'single_use') {
                                  await adminClient
                                      .from('invite_codes')
                                      .update({'is_skipped': true})
                                      .ilike('code', cleanCode);
                                }
                              } catch (e) {
                                debugPrint(
                                    '[ReferralConnectionModal] Error updating is_skipped: $e');
                              }
                            }

                            await LinkrunnerService.markReferrerAsProcessed(
                              widget.referrerId.toString(),
                              inviteCode: widget.inviteCode,
                            );
                            AnalyticsService.logEvent(
                              name: 'referral_intro_responded',
                              parameters: {
                                'referrer_id': widget.referrerId,
                                'action': 'skipped',
                              },
                            );
                            if (context.mounted) Navigator.pop(context);
                          },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                      ),
                    ),
                    child: Text(
                      "Skip",
                      style: TextStyle(
                        color: context.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Connect Button (Standardized color & label)
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnecting
                        ? null
                        : () async {
                            setState(() => _isConnecting = true);
                            try {
                              final profileProvider =
                                  Provider.of<ProfileProvider>(context, listen: false);
                              final connectionProvider =
                                  Provider.of<ConnectionProvider>(context, listen: false);
                              final myUserId = profileProvider.userId;

                              final codeToRedeem = widget.inviteCode ??
                                  await LinkrunnerService.getPendingInviteCode();

                              if (codeToRedeem != null && codeToRedeem.isNotEmpty) {
                                try {
                                  // Pipeline: Redeem Private Key directly
                                  await connectionProvider.redeemInviteCode(
                                    codeToRedeem,
                                    'both',
                                  );
                                  await connectionProvider.fetchConnections();
                                  debugPrint('[ReferralConnectionModal] Connected via Private Key pipeline ($codeToRedeem)');
                                } catch (redeemErr) {
                                  debugPrint('[ReferralConnectionModal] Redeem code failed ($redeemErr), using fallback connection');
                                  if (myUserId != null) {
                                    await connectionProvider.connectUsers(
                                      myUserId,
                                      widget.referrerId,
                                      connectionType: 'vip_pass_key',
                                    );
                                    await connectionProvider.markInviteCodeAsUsedByCode(codeToRedeem);
                                    await connectionProvider.recordInviteCodeAction(codeToRedeem, myUserId, 'connected');
                                    await connectionProvider.fetchConnections();
                                  }
                                }
                              } else if (myUserId != null) {
                                await connectionProvider.connectUsers(
                                  myUserId,
                                  widget.referrerId,
                                  connectionType: 'referral',
                                );
                                await connectionProvider.fetchConnections();
                              }

                              await LinkrunnerService.markReferrerAsProcessed(
                                widget.referrerId.toString(),
                                inviteCode: widget.inviteCode,
                              );
                              AnalyticsService.logEvent(
                                name: 'referral_intro_responded',
                                parameters: {
                                  'referrer_id': widget.referrerId,
                                  'action': 'accepted',
                                },
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                                ReferralConnectionModal._showFeedbackSnackBar(
                                  context,
                                  "Connected with $name!",
                                  isSuccess: true,
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setState(() => _isConnecting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Failed to connect: $e"),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accentPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                      ),
                      elevation: 0,
                    ),
                    child: _isConnecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            "Connect",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
