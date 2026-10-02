import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/vouch_model.dart';
import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:connect/Pages/yet_to_be_built_profile_page.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Providers/vouch_provider.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/Widgets/direct_connection_sheet.dart';
import 'package:connect/Widgets/referral_intro_sheet.dart';
import 'package:connect/Widgets/vouch_bottom_sheet.dart';

/// Interactive modal sheet that opens when clicking a user's name or profile picture.
/// Displays name, profession, company, degree connection status, and vouches under the active scope.
class UserProfileModal extends StatefulWidget {
  final int userId;
  final String userName;
  final String? avatarUrl;
  final int? degree;
  final String? scope;

  const UserProfileModal({
    super.key,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.degree,
    this.scope,
  });

  static Future<void> show(
    BuildContext context, {
    required int userId,
    required String userName,
    String? avatarUrl,
    int? degree,
    String? scope,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UserProfileModal(
        userId: userId,
        userName: userName,
        avatarUrl: avatarUrl,
        degree: degree,
        scope: scope,
      ),
    );
  }

  @override
  State<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<UserProfileModal> {
  late int _resolvedUserId;
  late String _name;
  late String _avatarUrl;
  int _degree = -1;
  String _profession = '';
  String _company = '';
  bool _isLoadingProfile = true;
  Map<String, dynamic> _rawProfile = {};
  List<String> _mutualIntents = [];

  @override
  void initState() {
    super.initState();
    _resolvedUserId = widget.userId;
    _name = widget.userName;
    _avatarUrl = widget.avatarUrl ?? '';
    _degree = widget.degree ?? -1;

    _fetchProfileAndVouches();
  }

  Future<void> _fetchProfileAndVouches() async {
    final client = Supabase.instance.client;
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final connProvider = Provider.of<ConnectionProvider>(context, listen: false);
    final myUserId = profileProvider.userId;

    try {
      Map<String, dynamic>? profile;

      if (_resolvedUserId != 0) {
        profile = await client
            .from('profiles')
            .select('id, name, avatar_url, profession, company, bio')
            .eq('id', _resolvedUserId)
            .maybeSingle();
      } else if (_name.isNotEmpty) {
        profile = await client
            .from('profiles')
            .select('id, name, avatar_url, profession, company, bio')
            .ilike('name', _name)
            .limit(1)
            .maybeSingle();
      }

      if (profile != null) {
        _rawProfile = profile;
        final idVal = profile['id'];
        if (idVal is int) {
          _resolvedUserId = idVal;
        } else if (idVal != null) {
          _resolvedUserId = int.tryParse(idVal.toString()) ?? _resolvedUserId;
        }

        final nameVal = profile['name']?.toString() ?? '';
        if (nameVal.isNotEmpty) _name = nameVal;

        final avVal = profile['avatar_url']?.toString() ?? '';
        if (avVal.isNotEmpty) _avatarUrl = avVal;

        _profession = profile['profession']?.toString() ?? '';
        _company = profile['company']?.toString() ?? '';
      }

      // Check degree connection
      if (myUserId != null && _resolvedUserId != 0 && myUserId != _resolvedUserId) {
        if (connProvider.connections.any((c) => c['id'] == _resolvedUserId)) {
          _degree = 1;
        } else if (_degree <= 0) {
          try {
            final mutuals = await client.rpc('get_mutual_connections', params: {
              'p_viewer_id': myUserId,
              'p_target_id': _resolvedUserId,
            });
            if (mutuals is List && mutuals.isNotEmpty) {
              _degree = 2;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint("Error loading user profile modal: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }

    if (_resolvedUserId != 0 && mounted) {
      final vProvider = Provider.of<VouchProvider>(context, listen: false);
      vProvider.loadVouches(_resolvedUserId);
      if (myUserId != null && myUserId != _resolvedUserId) {
        vProvider.checkHasVouched(
          voucherId: myUserId,
          voucheeId: _resolvedUserId,
        );
        vProvider.getMutualIntents(
          userId1: myUserId,
          userId2: _resolvedUserId,
        ).then((intents) {
          if (mounted && intents.isNotEmpty) {
            setState(() => _mutualIntents = intents);
          }
        });
      }
    }
  }

  List<UserVouch> _filterVouchesByScope(List<UserVouch> allVouches, String scope) {
    final s = scope.trim().toLowerCase();
    return allVouches.where((v) {
      final vScope = v.feedScope.trim().toLowerCase();
      final effectiveScope = vScope.isEmpty ? 'network' : vScope;
      if (s == 'global') {
        return effectiveScope == 'global';
      } else if (s == 'inner_circle') {
        return effectiveScope == 'inner_circle';
      } else {
        // network scope
        return effectiveScope == 'network';
      }
    }).toList();
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
  }

  String _formatProfessionCompany() {
    final p = _profession.trim();
    final c = _company.trim();
    if (p.isNotEmpty && c.isNotEmpty) {
      return "$p at $c";
    } else if (p.isNotEmpty) {
      return p;
    } else if (c.isNotEmpty) {
      return c;
    }
    return _isLoadingProfile ? "Loading..." : "Mandala Member";
  }

  Widget _buildDegreeBadge(BuildContext context) {
    if (_degree == 1) {
      return Text(
        "1°",
        style: TextStyle(
          color: context.accentSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    } else if (_degree == 2) {
      return Text(
        "2°",
        style: TextStyle(
          color: context.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    } else if (_degree >= 3) {
      return Text(
        "3°",
        style: TextStyle(
          color: context.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildConnectAction(BuildContext context, int myUserId) {
    final connProvider = Provider.of<ConnectionProvider>(context, listen: false);
    final notifProvider = Provider.of<NotificationProvider>(context);

    final bool isMe = (myUserId == _resolvedUserId);
    if (isMe) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          "You",
          style: TextStyle(
            color: context.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final bool isConnected = connProvider.connections.any((c) => c['id'] == _resolvedUserId);
    if (isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: context.accentPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: context.accentPrimary.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 13, color: context.accentPrimary),
            const SizedBox(width: 4),
            Text(
              "Connected",
              style: TextStyle(
                color: context.accentPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final bool isDirect = (_degree == -1);
    final bool isSent = isDirect && notifProvider.hasSentDirectRequest(_resolvedUserId);

    void handleTap() {
      if (isSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Direct request already sent to $_name"),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (isDirect) {
        DirectConnectionSheet.show(
          context: context,
          targetUserId: _resolvedUserId,
          targetUserName: _name,
          targetUserAvatar: _avatarUrl,
        );
      } else {
        ReferralIntroSheet.show(
          context: context,
          targetUserId: _resolvedUserId,
          targetUserName: _name,
          degree: _degree,
        );
      }
    }

    return BounceTap(
      onTap: handleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSent ? Colors.white.withValues(alpha: 0.05) : null,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isSent
                ? Colors.white.withValues(alpha: 0.25)
                : context.accentPrimary.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSent
                  ? Icons.done_rounded
                  : (isDirect ? Icons.send_rounded : Icons.person_add_outlined),
              size: 13,
              color: isSent ? Colors.white70 : context.accentPrimary,
            ),
            const SizedBox(width: 4),
            Text(
              isSent
                  ? "Request Sent"
                  : (isDirect ? "Direct Request" : "Connect"),
              style: TextStyle(
                color: isSent ? Colors.white70 : context.accentPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVouchAction(BuildContext context, int myUserId) {
    final vouchProvider = Provider.of<VouchProvider>(context);
    final hasVouched = vouchProvider.hasVouchedFor(myUserId, _resolvedUserId);

    if (hasVouched) {
      final isPending = vouchProvider.getCachedVouchStatus(myUserId, _resolvedUserId) == 'pending';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isPending
              ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending
                ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.20),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPending ? Icons.hourglass_top_rounded : Icons.verified_rounded,
              color: isPending ? const Color(0xFFF59E0B) : Colors.white70,
              size: 11,
            ),
            const SizedBox(width: 4),
            Text(
              isPending ? "Vouch Requested" : "Vouched",
              style: TextStyle(
                color: isPending ? const Color(0xFFF59E0B) : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      );
    }

    final activeScope = widget.scope ?? Provider.of<FeedProvider>(context, listen: false).currentScope;

    return BounceTap(
      onTap: () {
        HapticFeedback.lightImpact();
        VouchBottomSheet.show(
          context: context,
          targetUserId: _resolvedUserId,
          targetUserName: _name,
          targetUserAvatar: _avatarUrl,
          targetUserProfession: _profession,
          initialScope: activeScope,
          onVouched: () {
            vouchProvider.loadVouches(_resolvedUserId);
            vouchProvider.checkHasVouched(
              voucherId: myUserId,
              voucheeId: _resolvedUserId,
            );
            vouchProvider.getMutualIntents(
              userId1: myUserId,
              userId2: _resolvedUserId,
            ).then((intents) {
              if (mounted) setState(() => _mutualIntents = intents);
            });
            if (mounted) setState(() {});
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.0,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, color: Colors.white, size: 11),
            SizedBox(width: 4),
            Text(
              "Vouch",
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToFullProfile() {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final myUserId = profileProvider.userId ?? 0;
    final isMe = (myUserId == _resolvedUserId);

    Navigator.pop(context);

    if (isMe) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const YetToBeBuiltProfilePage(),
        ),
      );
      return;
    }

    final connProvider = Provider.of<ConnectionProvider>(context, listen: false);
    final matchingConn = connProvider.connections.where((c) {
      final cId = c['id'] ?? c['connection_profile_id'] ?? c['user_id'];
      return cId == _resolvedUserId;
    }).firstOrNull;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConnectionProfilePage(
          profileData: matchingConn ?? {
            'id': _resolvedUserId,
            'connection_profile_id': _resolvedUserId,
            'name': _name,
            'avatar_url': _avatarUrl,
            'profession': _profession,
            'company': _company,
            ..._rawProfile,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context);
    final vouchProvider = Provider.of<VouchProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final connProvider = Provider.of<ConnectionProvider>(context);
    final myUserId = profileProvider.userId ?? 0;

    final matchingConn = connProvider.connections.where((c) {
      final cId = c['id'] ?? c['connection_profile_id'] ?? c['user_id'];
      return cId == _resolvedUserId;
    }).firstOrNull;
    final bool isConnected = matchingConn != null;
    final bool isMe = (myUserId == _resolvedUserId);

    final String activeScope = widget.scope ?? feedProvider.currentScope;
    final String networkName;
    if (feedProvider.isCustomNetworkActive && feedProvider.activeCustomNetwork != null) {
      networkName = feedProvider.activeCustomNetwork!.name;
    } else if (activeScope == 'global') {
      networkName = 'Global';
    } else if (activeScope == 'inner_circle') {
      networkName = 'Inner Circle';
    } else {
      networkName = 'Network';
    }

    final allVouches = _resolvedUserId != 0 ? vouchProvider.getVouchesFor(_resolvedUserId) : <UserVouch>[];
    final vouchesUnderScope = _filterVouchesByScope(allVouches, activeScope);
    final int scopeVouches = vouchesUnderScope.length;
    final int totalVouches = allVouches.length >= scopeVouches ? allVouches.length : scopeVouches;
    final bool isLoadingVouches = _resolvedUserId != 0 && vouchProvider.isLoading(_resolvedUserId);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // User Card Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor: context.surfaceSecondary,
                  backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                  child: _avatarUrl.isEmpty
                      ? Text(
                          _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),

                // Name & Profession & Degree Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _name,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_degree > 0) ...[
                            const SizedBox(width: 5),
                            _buildDegreeBadge(context),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatProfessionCompany(),
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildConnectAction(context, myUserId),
                    if (isConnected && !isMe) ...[
                      const SizedBox(height: 6),
                      _buildVouchAction(context, myUserId),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Confidential Mutual Match Banner (revealed only upon mutual match)
          if (_mutualIntents.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_open_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "MUTUAL INTENT MATCH",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "You and $_name mutually signaled: ${_mutualIntents.join(' • ')}",
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Active Scope & Total Vouches Pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 14,
                    color: context.accentSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Network: ",
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    networkName,
                    style: TextStyle(
                      color: context.accentSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "$scopeVouches under $networkName",
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    " • Total: $totalVouches",
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

          // Vouches Scrollable List
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 15,
                        color: context.accentPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "VOUCHES UNDER ${networkName.toUpperCase()} ($scopeVouches)",
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          "Total: $totalVouches",
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (isLoadingVouches)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (vouchesUnderScope.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 28,
                              color: context.textMuted,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "No vouches under $networkName yet",
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Only endorsements published with visibility in $networkName appear here.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.textMuted,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...vouchesUnderScope.map((vouch) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Voucher Header
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: context.surfaceSecondary,
                                  backgroundImage: vouch.voucherAvatarUrl.isNotEmpty
                                      ? NetworkImage(vouch.voucherAvatarUrl)
                                      : null,
                                  child: vouch.voucherAvatarUrl.isEmpty
                                      ? Text(
                                          vouch.voucherName.isNotEmpty
                                              ? vouch.voucherName[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vouch.voucherName,
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (vouch.voucherProfession.isNotEmpty)
                                        Text(
                                          vouch.voucherProfession,
                                          style: TextStyle(
                                            color: context.textMuted,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTimeAgo(vouch.createdAt),
                                  style: TextStyle(
                                    color: context.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Statement / Structured Relationship
                            if (vouch.relationshipType != null && vouch.relationshipType!.isNotEmpty) ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.12),
                                        width: 0.6,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.verified_rounded,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          vouch.relationshipType!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (vouch.contextTag != null && vouch.contextTag!.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        vouch.contextTag!,
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (vouch.optionalNote != null && vouch.optionalNote!.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  "“${vouch.optionalNote!.trim()}”",
                                  style: TextStyle(
                                    color: context.textPrimary.withValues(alpha: 0.9),
                                    fontSize: 12,
                                    height: 1.35,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ] else ...[
                              Text(
                                "\"${vouch.statement}\"",
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 13,
                                  height: 1.4,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          // Bottom Button: View Full Profile (ONLY shown if the user is connected to them or isMe)
          if (isConnected || isMe)
            Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              child: BounceTap(
                onTap: _navigateToFullProfile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "View Full Profile",
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: context.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}
