import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/Widgets/direct_connection_sheet.dart';
import 'package:connect/Widgets/referral_intro_sheet.dart';

class _VoucheeData {
  final int id;
  final String name;
  final String avatarUrl;
  final String profession;
  final String company;
  final int vouchesCount;
  final int degree;
  final Map<String, dynamic> fullProfile;

  const _VoucheeData({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.profession,
    required this.company,
    required this.vouchesCount,
    required this.degree,
    required this.fullProfile,
  });
}

class VouchedUserCard extends StatefulWidget {
  final String postId;
  final String postContent;

  const VouchedUserCard({
    super.key,
    required this.postId,
    required this.postContent,
  });

  @override
  State<VouchedUserCard> createState() => _VouchedUserCardState();
}

class _VouchedUserCardState extends State<VouchedUserCard> {
  static final Map<String, _VoucheeData> _cache = {};

  _VoucheeData? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVoucheeData();
  }

  @override
  void didUpdateWidget(covariant VouchedUserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId ||
        oldWidget.postContent != widget.postContent) {
      _loadVoucheeData();
    }
  }

  Future<void> _loadVoucheeData() async {
    final cached = _cache[widget.postId];
    if (cached != null) {
      if (mounted) {
        setState(() {
          _data = cached;
          _isLoading = false;
        });
      }
      return;
    }

    final myUserId =
        Provider.of<ProfileProvider>(context, listen: false).userId;

    try {
      int? voucheeId;
      Map<String, dynamic>? profile;

      // 1. Try finding in user_vouches by announcement_post_id
      try {
        final res = await Supabase.instance.client
            .from('user_vouches')
            .select('vouchee_id, profiles!vouchee_id(id, name, avatar_url, profession, company)')
            .eq('announcement_post_id', widget.postId)
            .maybeSingle();

        if (res != null) {
          voucheeId = res['vouchee_id'] is int
              ? res['vouchee_id'] as int
              : int.tryParse(res['vouchee_id']?.toString() ?? '');
          if (res['profiles'] is Map) {
            profile = Map<String, dynamic>.from(res['profiles']);
          }
        }
      } catch (e) {
        debugPrint("Error looking up vouch by post ID: $e");
      }

      // 2. Fallback: extract @Name from post content
      if (voucheeId == null || profile == null) {
        final match =
            RegExp(r'(?:⭐\s*)?Vouched for @([^\n\r"]+)').firstMatch(widget.postContent);
        if (match != null) {
          final rawName = match.group(1)?.trim();
          if (rawName != null && rawName.isNotEmpty) {
            try {
              final found = await Supabase.instance.client
                  .from('profiles')
                  .select('id, name, avatar_url, profession, company')
                  .ilike('name', rawName)
                  .limit(1)
                  .maybeSingle();
              if (found != null) {
                profile = Map<String, dynamic>.from(found);
                voucheeId = profile['id'] is int
                    ? profile['id'] as int
                    : int.tryParse(profile['id']?.toString() ?? '');
              }
            } catch (e) {
              debugPrint("Error looking up profile by name: $e");
            }
          }
        }
      }

      if (voucheeId == null || profile == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 3. Fetch total vouches count for this vouchee
      int vouchesCount = 1;
      try {
        vouchesCount = await Supabase.instance.client
            .from('user_vouches')
            .count(CountOption.exact)
            .eq('vouchee_id', voucheeId);
      } catch (e) {
        debugPrint("Error counting vouches: $e");
      }

      // 4. Determine degree with viewer (check mutual connections)
      int degree = -1;
      if (myUserId != null && myUserId != voucheeId) {
        try {
          final mutuals = await Supabase.instance.client
              .rpc('get_mutual_connections', params: {
            'p_viewer_id': myUserId,
            'p_target_id': voucheeId,
          });
          if (mutuals is List && mutuals.isNotEmpty) {
            degree = 2;
          }
        } catch (_) {}
      }

      final data = _VoucheeData(
        id: voucheeId,
        name: profile['name']?.toString() ?? 'User',
        avatarUrl: profile['avatar_url']?.toString() ?? '',
        profession: profile['profession']?.toString() ?? '',
        company: profile['company']?.toString() ?? '',
        vouchesCount: vouchesCount,
        degree: degree,
        fullProfile: profile,
      );

      _cache[widget.postId] = data;
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading vouchee card data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildInitials(String name) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : 'U';
    return Container(
      color: Colors.white.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        height: 64,
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
      );
    }

    final data = _data;
    if (data == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConnectionProfilePage(
              profileData: data.fullProfile,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            // Profile Picture
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
              ),
              child: ClipOval(
                child: (data.avatarUrl.isNotEmpty && data.avatarUrl.startsWith('http'))
                    ? Image.network(
                        data.avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildInitials(data.name),
                      )
                    : _buildInitials(data.name),
              ),
            ),
            const SizedBox(width: 12),

            // Info column: Name, Profession, Number of Vouches
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (data.profession.isNotEmpty || data.company.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      [data.profession, data.company]
                          .where((s) => s.isNotEmpty)
                          .join(' • '),
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  // Number of Vouches badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          color: context.textSecondary,
                          size: 11,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${data.vouchesCount} ${data.vouchesCount == 1 ? 'Vouch' : 'Vouches'}",
                          style: TextStyle(
                            color: context.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 10.5,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Connect button (using already implemented direct / referral connection pipelines)
            Consumer2<ConnectionProvider, NotificationProvider>(
              builder: (context, connProvider, notifProvider, _) {
                final myUserId =
                    Provider.of<ProfileProvider>(context, listen: false).userId;
                if (myUserId == null || myUserId == data.id) {
                  return const SizedBox.shrink();
                }

                final isConnected = connProvider.isConnected(data.id);
                if (isConnected) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded,
                            color: Colors.white70, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          "Connected",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final bool isDirect = data.degree == -1;
                final bool isRequestSent =
                    isDirect && notifProvider.hasSentDirectRequest(data.id);

                return ElevatedButton.icon(
                  onPressed: isRequestSent
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          if (isDirect) {
                            DirectConnectionSheet.show(
                              context: context,
                              targetUserId: data.id,
                              targetUserName: data.name,
                              targetUserAvatar: data.avatarUrl,
                              targetUserProfession: data.profession,
                            );
                          } else {
                            ReferralIntroSheet.show(
                              context: context,
                              targetUserId: data.id,
                              targetUserName: data.name,
                              degree: data.degree,
                            );
                          }
                        },
                  icon: Icon(
                    isRequestSent ? Icons.done_rounded : Icons.person_add_rounded,
                    size: 13,
                    color: isRequestSent ? context.textSecondary : Colors.black,
                  ),
                  label: Text(
                    isRequestSent ? "Sent" : "Connect",
                    style: TextStyle(
                      color: isRequestSent ? context.textSecondary : Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRequestSent
                        ? context.surfaceSecondary
                        : Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    shape: const StadiumBorder(),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
