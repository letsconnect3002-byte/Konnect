import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/services/linkrunner_service.dart';

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

  static Future<void> checkAndShowPrompt(BuildContext context) async {
    try {
      final pendingReferrerIdStr = await LinkrunnerService.getPendingReferrerId();
      final pendingInviteCode = await LinkrunnerService.getPendingInviteCode();

      if (pendingReferrerIdStr == null || pendingReferrerIdStr.isEmpty) return;

      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);

      final myUserId = profileProvider.userId;
      if (myUserId == null) return;

      final int? referrerId = int.tryParse(pendingReferrerIdStr);
      if (referrerId == null || referrerId == myUserId) {
        await LinkrunnerService.clearPendingReferralData();
        return;
      }

      // Check if already connected
      final alreadyConnected = connectionProvider.connections.any(
        (c) => (c['id'] == referrerId || c['connection_profile_id'] == referrerId),
      );
      if (alreadyConnected) {
        await LinkrunnerService.clearPendingReferralData();
        return;
      }

      // Fetch referrer profile details
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', referrerId)
          .maybeSingle();

      if (response == null) {
        await LinkrunnerService.clearPendingReferralData();
        return;
      }

      final Map<String, dynamic> referrerProfile = Map<String, dynamic>.from(response);

      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => ReferralConnectionModal(
            referrerProfile: referrerProfile,
            referrerId: referrerId,
            inviteCode: pendingInviteCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ReferralConnectionModal] Error checking pending referral: $e');
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
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User Avatar with fallback first letter in center
            CircleAvatar(
              radius: 38,
              backgroundColor: context.accentPrimary.withValues(alpha: 0.18),
              backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
              child: hasAvatar
                  ? null
                  : Text(
                      initial,
                      style: TextStyle(
                        color: context.accentPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 18),

            // Title
            Text(
              "Connection Invite",
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Clean Description without (Professional) tag
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 14,
                  height: 1.45,
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
            const SizedBox(height: 26),

            // Action Buttons
            Row(
              children: [
                // Skip Button
                Expanded(
                  child: TextButton(
                    onPressed: _isConnecting
                        ? null
                        : () async {
                            await LinkrunnerService.clearPendingReferralData();
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

                              await LinkrunnerService.clearPendingReferralData();

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Connected with $name!"),
                                    backgroundColor: context.surfacePrimary,
                                    behavior: SnackBarBehavior.floating,
                                  ),
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
