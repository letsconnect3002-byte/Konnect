import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:connect/Pages/ThreadDetailPage.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/custom_network_provider.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Models/custom_network.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/Providers/vouch_provider.dart';
import 'package:connect/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:connect/services/analytics_service.dart';
import 'package:connect/Widgets/anonymous_avatar.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late NotificationProvider _notificationProvider;
  final Set<String> _processingActionNotificationIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<NotificationProvider>(context, listen: false);
        provider.subscribeToNotifications();
        provider.fetchNotifications();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
  }

  @override
  void dispose() {
    if (_notificationProvider.unreadCount > 0) {
      _notificationProvider.markAllAsSeen();
    }
    super.dispose();
  }

  String _getRelativeTime(String? createdAtStr) {
    if (createdAtStr == null) return '';
    try {
      final dateTime = DateTime.parse(createdAtStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return "now";
      } else if (difference.inMinutes < 60) {
        return "${difference.inMinutes}m";
      } else if (difference.inHours < 24) {
        return "${difference.inHours}h";
      } else if (difference.inDays < 7) {
        return "${difference.inDays}d";
      } else {
        return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
      }
    } catch (_) {
      return '';
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.canvasBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const GlassmorphicFlexibleSpace(),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              final unseen =
                  provider.notifications.where((n) => !n['is_seen']).toList();
              if (unseen.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  provider.markAllAsSeen();
                },
                child: const Text(
                  "Mark all read",
                  style: TextStyle(
                    color: Color(0xFF00F2FE),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          final state = provider.state;

          if (state is NotificationLoading && provider.notifications.isEmpty) {
            return Skeletonizer(
              enabled: true,
              child: _buildSkeletonNotificationList(),
            );
          }

          final allNotifs = provider.notifications;
          if (allNotifs.isEmpty) {
            return _buildEmptyState();
          }

          // Calculate groups
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          final yesterdayStart = todayStart.subtract(const Duration(days: 1));
          final sevenDaysAgoStart =
              todayStart.subtract(const Duration(days: 7));

          final List<Map<String, dynamic>> newGroup = [];
          final List<Map<String, dynamic>> yesterdayGroup = [];
          final List<Map<String, dynamic>> last7DaysGroup = [];
          final List<Map<String, dynamic>> earlierGroup = [];

          for (final n in allNotifs) {
            final type = n['type']?.toString();
            final isPlanNotif = type == 'plan_invite' ||
                type == 'plan_update' ||
                type == 'plan_reminder_30' ||
                type == 'plan_reminder_start';
            if (isPlanNotif) {
              continue;
            }

            final createdAtStr = n['created_at'] as String?;
            if (createdAtStr == null) {
              earlierGroup.add(n);
              continue;
            }
            try {
              final dateTime = DateTime.parse(createdAtStr).toLocal();
              if (dateTime.isAfter(todayStart)) {
                newGroup.add(n);
              } else if (dateTime.isAfter(yesterdayStart)) {
                yesterdayGroup.add(n);
              } else if (dateTime.isAfter(sevenDaysAgoStart)) {
                last7DaysGroup.add(n);
              } else {
                earlierGroup.add(n);
              }
            } catch (_) {
              earlierGroup.add(n);
            }
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _buildGroupCard("New", newGroup, provider),
              _buildGroupCard("Yesterday", yesterdayGroup, provider),
              _buildGroupCard("Last 7 days", last7DaysGroup, provider),
              _buildGroupCard("Earlier", earlierGroup, provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGroupCard(String title, List<Map<String, dynamic>> items,
      NotificationProvider provider) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      // decoration: BoxDecoration(
      //   color: const Color(0xFF131422),
      //   borderRadius: BorderRadius.circular(24),
      //   border: Border.all(
      //     color: Colors.white.withValues(alpha: 0.04),
      //     width: 1.5,
      //   ),
      // ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildNotificationItem(item, provider);
            },
          ),
          // const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFeedNotificationItem(
      Map<String, dynamic> notification, NotificationProvider provider) {
    final otherUser = notification['other_user'] as Map<String, dynamic>? ?? {};
    final String timeStr =
        _getRelativeTime(notification['created_at'] as String?);
    final bool isUnseen = notification['is_seen'] == false;
    final String type = notification['type'] ?? 'feed_reply';

    String rootPostId = notification['root_post_id']?.toString() ??
        notification['rootPostId']?.toString() ??
        '';
    String targetPostId = notification['post_id']?.toString() ??
        notification['postId']?.toString() ??
        '';
    String realType = type;
    String parentAuthorName = 'a post';
    bool isAnonymous = false;
    String? explicitActorName;
    String networkId = '';
    String networkName = '';

    final String? rawNote = notification['note'] as String?;
    if (rawNote != null && rawNote.startsWith('{')) {
      try {
        final parsed = jsonDecode(rawNote);
        if (parsed['real_type'] != null) realType = parsed['real_type'].toString();
        if (parsed['root_post_id'] != null && rootPostId.isEmpty) {
          rootPostId = parsed['root_post_id'].toString();
        }
        if (parsed['post_id'] != null && targetPostId.isEmpty) {
          targetPostId = parsed['post_id'].toString();
        }
        if (parsed['parent_author_name'] != null) {
          parentAuthorName = parsed['parent_author_name'].toString();
        }
        if (parsed['is_anonymous'] == true) {
          isAnonymous = true;
        }
        if (parsed['actor_name'] != null && parsed['actor_name'].toString().isNotEmpty) {
          explicitActorName = parsed['actor_name'].toString();
        }
        if (parsed['network_id'] != null) {
          networkId = parsed['network_id'].toString();
        }
        if (parsed['network_name'] != null) {
          networkName = parsed['network_name'].toString();
        }
      } catch (_) {}
    }
    if (rootPostId.isEmpty && targetPostId.isNotEmpty) {
      rootPostId = targetPostId;
    }

    final String name = isAnonymous
        ? (explicitActorName ?? (otherUser['anon_name']?.toString().isNotEmpty == true ? otherUser['anon_name'].toString() : 'Anonymous'))
        : (otherUser['name'] ?? 'Connection');
    final String avatarUrl = isAnonymous
        ? ''
        : (otherUser['avatar_url'] ?? otherUser['avatarUrl'] ?? '');

    String actionText = 'replied to your post.';
    IconData iconData = Icons.chat_bubble_outline_rounded;

    if (realType == 'feed_reply_mention') {
      actionText = networkName.isNotEmpty
          ? 'replied to your post and mentioned you in $networkName.'
          : 'replied to your post and mentioned you on their post.';
      iconData = Icons.alternate_email_rounded;
    } else if (realType == 'feed_reply') {
      actionText = networkName.isNotEmpty
          ? 'replied to your post in $networkName.'
          : 'replied to your post.';
      iconData = Icons.chat_bubble_outline_rounded;
    } else if (realType == 'feed_mention') {
      actionText = networkName.isNotEmpty
          ? 'mentioned you in $networkName.'
          : 'mentioned you on their post.';
      iconData = Icons.alternate_email_rounded;
    } else if (realType == 'feed_post') {
      actionText = networkName.isNotEmpty
          ? 'has uploaded a post in $networkName, tap to see.'
          : 'has uploaded a post, tap to see.';
      iconData = Icons.dynamic_feed_rounded;
    } else if (realType == 'feed_connection_reply') {
      actionText = networkName.isNotEmpty
          ? 'replied to $parentAuthorName in $networkName, tap to join the conversation.'
          : 'replied to $parentAuthorName, tap to join the conversation.';
      iconData = Icons.forum_outlined;
    }

    return Dismissible(
      key: Key(notification['id'].toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        provider.deleteNotification(notification['id'].toString());
      },
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          AnalyticsService.logEvent(
            name: 'notification_item_tapped',
            parameters: {'type': realType},
          );
          if (isUnseen) {
            provider.markAsSeen(notification['id'].toString());
          }
          if (networkId.isNotEmpty) {
            try {
              final customNetProv =
                  Provider.of<CustomNetworkProvider>(context, listen: false);
              final feedProv = Provider.of<FeedProvider>(context, listen: false);
              for (final net in customNetProv.myNetworks) {
                if (net.id == networkId) {
                  customNetProv.selectCustomNetwork(net);
                  feedProv.selectCustomNetwork(net);
                  break;
                }
              }
            } catch (_) {}
          }
          if (rootPostId.isNotEmpty) {
            appShellKey.currentState?.setSelectedIndex(0);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ThreadDetailPage(
                  rootPostId: rootPostId,
                  highlightPostId: targetPostId.isNotEmpty ? targetPostId : rootPostId,
                ),
              ),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUnseen
                ? context.accentPrimary.withValues(alpha: 0.12)
                : context.surfaceSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnseen
                  ? context.accentPrimary.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  isAnonymous
                      ? AnonymousAvatar(
                          seed: (notification['other_user_id'] ??
                                  otherUser['id'] ??
                                  name)
                              .toString(),
                          radius: 20,
                        )
                      : Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.surfaceHighlight,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: ClipOval(
                            child: avatarUrl.isNotEmpty
                                ? Image.network(
                                    avatarUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Center(
                                      child: Text(
                                        _getInitials(name),
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      _getInitials(name),
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.surfaceSecondary,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          iconData,
                          size: 9,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(
                            text: "$name ",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: actionText),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUnseen)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: context.accentPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
      Map<String, dynamic> notification, NotificationProvider provider) {
    final String type = notification['type'] ?? 'qr_code';
    if (type == 'plan_invite' ||
        type == 'plan_update' ||
        type == 'plan_reminder_30' ||
        type == 'plan_reminder_start') {
      return const SizedBox.shrink();
    }
    if (type == 'feed_reply' ||
        type == 'feed_mention' ||
        type == 'feed_reply_mention' ||
        type == 'feed_post' ||
        type == 'feed_connection_reply') {
      return _buildFeedNotificationItem(notification, provider);
    }
    if (type.startsWith('tribe_')) {
      return const SizedBox.shrink();
    }
    if (type == 'custom_network_added') {
      return _buildCustomNetworkNotificationItem(notification, provider);
    }
    final otherUser = notification['other_user'] as Map<String, dynamic>? ?? {};
    final String name = otherUser['name'] ?? 'Unknown User';
    final String profession = otherUser['profession'] ?? 'Connection';
    final String avatarUrl =
        otherUser['avatar_url'] ?? otherUser['avatarUrl'] ?? '';
    final String timeStr =
        _getRelativeTime(notification['created_at'] as String?);
    final bool isUnseen = notification['is_seen'] == false;

    final String? rawNote = notification['note'] as String?;
    final bool isReferral = type == 'referral';
    final bool isReferralRequest = isReferral &&
        rawNote != null &&
        (rawNote.startsWith('[REFERRAL_REQUEST]') ||
            rawNote.startsWith('[REFERRAL_REQUEST_ACTIONED]'));
    final bool isRequestActioned =
        rawNote != null && rawNote.startsWith('[REFERRAL_REQUEST_ACTIONED]');
    final bool isNormalReferral = isReferral && !isReferralRequest;

    final referredUser =
        notification['referred_user'] as Map<String, dynamic>? ?? {};
    final String referredName = referredUser['name'] ?? 'Unknown User';
    final String referredAvatarUrl =
        referredUser['avatar_url'] ?? referredUser['avatarUrl'] ?? '';
    final String referredProfession = referredUser['profession'] ?? '';

    final connectionProvider =
        Provider.of<ConnectionProvider>(context);
    final targetConnectionUserId =
        isReferral ? referredUser['id'] : otherUser['id'];
    final bool isAlreadyConnected = targetConnectionUserId != null &&
        connectionProvider.connections
            .any((c) => c['id'] == targetConnectionUserId);

    final bool isQr = type == 'qr_code';
    final bool isReferralConnect = type == 'referral_connect';
    final bool isDirectRequest = type == 'direct_connection_request';
    final bool isVouchRequest = type == 'vouch_request' && !isAlreadyConnected;
    final bool isVouchReceived = type == 'vouch_received' ||
        (type == 'vouch_request' && isAlreadyConnected);
    final bool isVouchAccepted = type == 'vouch_accepted';
    final bool isVouch = isVouchRequest || isVouchReceived || isVouchAccepted;

    final Color accentColor = (isReferral || isReferralConnect || isDirectRequest)
        ? context.accentSecondary
        : (isVouch
            ? const Color(0xFFF59E0B)
            : (isQr ? const Color(0xFF00F2FE) : const Color(0xFF8B5CF6)));

    String? directRequestMessage;
    if (isDirectRequest && rawNote != null && rawNote.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawNote);
        if (parsed is Map) {
          directRequestMessage = parsed['message']?.toString();
        }
      } catch (_) {
        directRequestMessage = rawNote;
      }
    }

    String? vouchId;
    if (isVouch && rawNote != null && rawNote.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawNote);
        if (parsed is Map) {
          vouchId = parsed['vouch_id']?.toString();
        }
      } catch (_) {}
    }

    String? displayNote;
    if (rawNote != null) {
      if (rawNote.startsWith('[REFERRAL_REQUEST_ACTIONED]:')) {
        displayNote = rawNote.substring('[REFERRAL_REQUEST_ACTIONED]:'.length);
      } else if (rawNote.startsWith('[REFERRAL_REQUEST]:')) {
        displayNote = rawNote.substring('[REFERRAL_REQUEST]:'.length);
      } else if (rawNote == '[REFERRAL_REQUEST]' ||
          rawNote == '[REFERRAL_REQUEST_ACTIONED]') {
        displayNote = null;
      } else {
        displayNote = rawNote;
      }
    }

    return Dismissible(
      key: Key(notification['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFEF4444),
          size: 24,
        ),
      ),
      onDismissed: (direction) {
        HapticFeedback.mediumImpact();
        provider.deleteNotification(notification['id']);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            provider.markAsSeen(notification['id']);
            if (isDirectRequest) {
              _showDirectRequestNoteModal(
                context: context,
                notification: notification,
                senderName: name,
                senderAvatar: avatarUrl,
                senderProfession: profession,
                cardType: 'both',
                noteMessage: directRequestMessage ?? '',
                isAlreadyConnected: isAlreadyConnected,
              );
              return;
            }
            final targetUser = isReferral ? referredUser : otherUser;
            final profileMap = {
              'id': targetUser['id'],
              'name': targetUser['name'] ?? 'Unknown',
              'profession': targetUser['profession'] ?? '',
              'avatarUrl':
                  targetUser['avatar_url'] ?? targetUser['avatarUrl'] ?? '',
              'company': targetUser['company'] ?? '',
              'bio': targetUser['bio'] ?? '',
              'connection_profile_id': targetUser['id'],
            };
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ConnectionProfilePage(profileData: profileMap),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isUnseen
                        ? Border.all(
                            color: accentColor.withValues(alpha: 0.6),
                            width: 2,
                          )
                        : null,
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1A1B2E),
                    ),
                    child: ClipOval(
                      child: avatarUrl.startsWith('http')
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(
                                child: Text(
                                  _getInitials(name),
                                  style: TextStyle(
                                    color: isUnseen ? accentColor : Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                _getInitials(name),
                                style: TextStyle(
                                  color: isUnseen ? accentColor : Colors.white60,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isReferral)
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontFamily: 'Inter',
                              height: 1.3,
                            ),
                            children: [
                              TextSpan(
                                text: name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: isReferralRequest
                                    ? " asked to be introduced to "
                                    : " referred ",
                                style: const TextStyle(color: Colors.white70),
                              ),
                              TextSpan(
                                text: referredName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (!isReferralRequest)
                                const TextSpan(
                                  text: " to you",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              if (timeStr.isNotEmpty)
                                TextSpan(
                                  text: " • $timeStr",
                                  style: const TextStyle(
                                    color: Color(0xFF5C5E78),
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                        )
                      else
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontFamily: 'Inter',
                              height: 1.3,
                            ),
                            children: [
                              TextSpan(
                                text: name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: isDirectRequest
                                    ? " sent you a direct connection request"
                                    : (isVouchRequest
                                        ? " wants to connect & vouched for you"
                                        : (isVouchReceived
                                            ? " vouched for you on your profile"
                                            : (isVouchAccepted
                                                ? " accepted your vouch and connected with you!"
                                                : (isQr
                                                    ? " connected via QR scan"
                                                    : (type == 'referral_connect'
                                                        ? " connected via Referral"
                                                        : " connected via Private Key"))))),
                                style: const TextStyle(color: Colors.white70),
                              ),
                              if (timeStr.isNotEmpty)
                                TextSpan(
                                  text: " • $timeStr",
                                  style: const TextStyle(
                                    color: Color(0xFF5C5E78),
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (isDirectRequest) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 76,
                              height: 30,
                              child: isAlreadyConnected
                                  ? ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1F2030),
                                        foregroundColor:
                                            const Color(0xFF8B8C9E),
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          side: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.03),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        final chatProfileMap = {
                                          'id': otherUser['id'],
                                          'name': name,
                                          'profession': profession,
                                          'avatarUrl': avatarUrl,
                                          'avatar_url': avatarUrl,
                                        };
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                IndividualChatPage(
                                                    connectionData:
                                                        chatProfileMap),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        "Message",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: Colors.black,
                                          shadowColor: Colors.transparent,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          final targetId = otherUser['id'];
                                          final sharedCard =
                                              'both';
                                          connectionProvider
                                              .connectUsers(
                                            provider.userId!,
                                            targetId,
                                            sharedCardByPresenter: sharedCard,
                                            connectionType: 'direct_connect',
                                          )
                                              .then((_) {
                                            provider.markAsSeen(
                                                notification['id']);
                                          }).catchError((err) {
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      "Could not connect. Please try again.")),
                                            );
                                          });
                                        },
                                        child: const Text(
                                          "Connect",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Inter',
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showDirectRequestNoteModal(
                                context: context,
                                notification: notification,
                                senderName: name,
                                senderAvatar: avatarUrl,
                                senderProfession: profession,
                                cardType: 'both',
                                noteMessage: directRequestMessage ?? '',
                                isAlreadyConnected: isAlreadyConnected,
                              ),
                              child: Container(
                                height: 30,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white
                                        .withValues(alpha: 0.18),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 11.5,
                                      color: context.textPrimary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "View Note",
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (isVouchRequest) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 30,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.black,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 0),
                                    minimumSize: const Size(0, 30),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () async {
                                    HapticFeedback.lightImpact();
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    final vouchProvider =
                                        Provider.of<VouchProvider>(context,
                                            listen: false);
                                    final targetId = otherUser['id'];

                                    // Optimistically hide Accept/Decline and switch to accepted state
                                    setState(() {
                                      notification['type'] = 'vouch_received';
                                      notification['is_seen'] = true;
                                    });

                                    try {
                                      if (vouchId != null) {
                                        await vouchProvider.acceptVouch(
                                          vouchId,
                                          voucheeId: provider.userId,
                                        );
                                      }
                                      if (targetId != null &&
                                          provider.userId != null) {
                                        await connectionProvider.connectUsers(
                                          provider.userId!,
                                          targetId,
                                          sharedCardByPresenter: 'both',
                                          connectionType: 'direct_connect',
                                        );
                                      }
                                      await Supabase.instance.client
                                          .from('connection_notifications')
                                          .update({
                                        'type': 'vouch_received',
                                        'is_seen': true,
                                      }).eq('id', notification['id']);
                                      await provider.fetchNotifications();
                                      if (mounted) {
                                        try {
                                          final feedProv = Provider.of<FeedProvider>(context, listen: false);
                                          feedProv.fetchInitialFeed(silent: true);
                                        } catch (_) {}
                                      }
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              "Connected with $name and vouch accepted!"),
                                          backgroundColor:
                                              const Color(0xFF10B981),
                                        ),
                                      );
                                    } catch (e) {
                                      setState(() {
                                        notification['type'] = 'vouch_request';
                                      });
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              "Could not accept vouch: $e"),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    "Accept",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 30,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.05),
                                  foregroundColor: Colors.white70,
                                  side: BorderSide(
                                    color: Colors.white
                                        .withValues(alpha: 0.15),
                                    width: 0.8,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 0),
                                  minimumSize: const Size(0, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () async {
                                  HapticFeedback.lightImpact();
                                  final vouchProvider =
                                      Provider.of<VouchProvider>(context,
                                          listen: false);
                                  try {
                                    if (vouchId != null) {
                                      await vouchProvider
                                          .declineVouch(vouchId);
                                    }
                                    await provider
                                        .deleteNotification(notification['id']);
                                  } catch (_) {}
                                },
                                child: const Text(
                                  "Decline",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (isReferral &&
                          displayNote != null &&
                          displayNote.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _showNotificationDetails(
                              context, notification, displayNote),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 11,
                                color: context.accentSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "Note attached • View details",
                                  style: TextStyle(
                                    color: context.accentSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (isReferralRequest) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 76,
                              height: 30,
                              child: Builder(
                                builder: (context) {
                                  if (!isRequestActioned) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: Colors.black,
                                          shadowColor: Colors.transparent,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          _showNotificationDetails(
                                            context,
                                            notification,
                                            displayNote,
                                            startWithNoteInput: true,
                                          );
                                        },
                                        child: const Text(
                                          "Introduce",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Inter',
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    );
                                  } else {
                                    return ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1F2030),
                                        foregroundColor:
                                            const Color(0xFF8B8C9E),
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          side: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.03),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      onPressed: null,
                                      child: const Text(
                                        "Introduced",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            if (displayNote != null &&
                                displayNote.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => _showNotificationDetails(
                                    context, notification, displayNote),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: context.accentSecondary
                                          .withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    "Details",
                                    style: TextStyle(
                                      color: context.accentSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isReferralRequest && !isDirectRequest && !isVouchRequest) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 76,
                    height: 30,
                    child: Builder(
                      builder: (context) {
                        if (isNormalReferral) {
                          if (isAlreadyConnected) {
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1F2030),
                                foregroundColor: const Color(0xFF8B8C9E),
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    width: 1,
                                  ),
                                ),
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                final targetId = isReferral
                                    ? referredUser['id']
                                    : otherUser['id'];
                                final targetName =
                                    isReferral ? referredName : name;
                                final targetProf = isReferral
                                    ? referredProfession
                                    : profession;
                                final targetAvatar = isReferral
                                    ? referredAvatarUrl
                                    : avatarUrl;
                                final chatProfileMap = {
                                  'id': targetId,
                                  'name': targetName,
                                  'profession': targetProf,
                                  'avatarUrl': targetAvatar,
                                  'avatar_url': targetAvatar,
                                };
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => IndividualChatPage(
                                        connectionData: chatProfileMap),
                                  ),
                                );
                              },
                              child: const Text(
                                "Message",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            );
                          } else {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.black,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final targetId = isReferral
                                      ? referredUser['id']
                                      : otherUser['id'];
                                  final sharedCard = 'both';
                                  connectionProvider
                                      .connectUsers(
                                    provider.userId!,
                                    targetId,
                                    sharedCardByPresenter: sharedCard,
                                    connectionType: isReferral
                                        ? 'referral_connect'
                                        : 'direct_connect',
                                  )
                                      .then((_) {
                                    provider.markAsSeen(notification['id']);
                                  }).catchError((err) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Could not connect. Please try again.")),
                                    );
                                  });
                                },
                                child: const Text(
                                  "Connect",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            );
                          }
                        } else {
                          if (isUnseen) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.black,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  provider.markAsSeen(notification['id']);
                                  final chatProfileMap = {
                                    'id': otherUser['id'],
                                    'name': name,
                                    'profession': profession,
                                    'avatarUrl': avatarUrl,
                                    'avatar_url': avatarUrl,
                                  };
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => IndividualChatPage(
                                          connectionData: chatProfileMap),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Chat",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1F2030),
                                foregroundColor: const Color(0xFF8B8C9E),
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    width: 1,
                                  ),
                                ),
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                final chatProfileMap = {
                                  'id': otherUser['id'],
                                  'name': name,
                                  'profession': profession,
                                  'avatarUrl': avatarUrl,
                                  'avatar_url': avatarUrl,
                                };
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => IndividualChatPage(
                                        connectionData: chatProfileMap),
                                  ),
                                );
                              },
                              child: const Text(
                                "Message",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomNetworkNotificationItem(
      Map<String, dynamic> notification, NotificationProvider provider) {
    final otherUser =
        notification['other_user'] as Map<String, dynamic>? ?? {};
    final String name = otherUser['name'] ?? 'Someone';
    final String avatarUrl =
        otherUser['avatar_url'] ?? otherUser['avatarUrl'] ?? '';
    final String timeStr =
        _getRelativeTime(notification['created_at'] as String?);
    final bool isUnseen = notification['is_seen'] == false;

    String networkName = 'a Network';
    String? networkId;
    final String? rawNote = notification['note'] as String?;
    if (rawNote != null && rawNote.startsWith('{')) {
      try {
        final parsed = jsonDecode(rawNote);
        networkName = parsed['network_name']?.toString() ?? 'a Network';
        networkId = parsed['network_id']?.toString();
      } catch (_) {}
    }

    const Color accentColor = Color(0xFF8B5CF6);

    return Dismissible(
      key: Key(notification['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFEF4444),
          size: 24,
        ),
      ),
      onDismissed: (direction) {
        HapticFeedback.mediumImpact();
        provider.deleteNotification(notification['id']);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            HapticFeedback.lightImpact();
            provider.markAsSeen(notification['id']);
            if (networkId != null && mounted) {
              try {
                final customNetProv = Provider.of<CustomNetworkProvider>(
                    context,
                    listen: false);
                final feedProv =
                    Provider.of<FeedProvider>(context, listen: false);
                await customNetProv.fetchMyNetworks();
                CustomNetwork? match;
                for (final net in customNetProv.myNetworks) {
                  if (net.id == networkId) {
                    match = net;
                    break;
                  }
                }
                if (match != null) {
                  customNetProv.selectCustomNetwork(match);
                  feedProv.selectCustomNetwork(match);
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                }
              } catch (e) {
                debugPrint('Error opening custom network from notification: $e');
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isUnseen
                        ? Border.all(
                            color: accentColor.withValues(alpha: 0.6),
                            width: 2,
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1A1B2E),
                        ),
                        child: ClipOval(
                          child: avatarUrl.startsWith('http')
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Center(
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0F101A),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.hub_rounded,
                            color: Colors.white,
                            size: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontFamily: 'Inter',
                            height: 1.3,
                          ),
                          children: [
                            TextSpan(
                              text: name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const TextSpan(
                              text: " added you to ",
                              style: TextStyle(color: Colors.white70),
                            ),
                            TextSpan(
                              text: networkName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (timeStr.isNotEmpty)
                              TextSpan(
                                text: " \u2022 $timeStr",
                                style: const TextStyle(
                                  color: Color(0xFF5C5E78),
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF13141F),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.02),
              ),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF5C5E78),
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "All Caught Up!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              "New connections via QR code scans or Private Keys will show up here.",
              style: TextStyle(
                color: Color(0xFF8B8C9E),
                fontSize: 13,
                fontFamily: 'Inter',
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonNotificationList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const CircleAvatar(radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 100,
                      height: 10,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 76,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDirectRequestNoteModal({
    required BuildContext context,
    required Map<String, dynamic> notification,
    required String senderName,
    required String senderAvatar,
    required String senderProfession,
    required String cardType,
    required String noteMessage,
    required bool isAlreadyConnected,
  }) {
    HapticFeedback.mediumImpact();
    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E202C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Title & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Connection Note",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white60, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Sender profile preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF13141F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1A1B2E),
                      ),
                      child: ClipOval(
                        child: senderAvatar.startsWith('http')
                            ? Image.network(
                                senderAvatar,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    _getInitials(senderName),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  _getInitials(senderName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            senderName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            senderProfession.isNotEmpty
                                ? senderProfession
                                : "Direct Connection Request",
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

              const SizedBox(height: 16),

              // Note quote card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.surfaceSecondary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          size: 16,
                          color: context.accentSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "MESSAGE",
                          style: context.captionText.copyWith(
                            color: context.textSecondary,
                            letterSpacing: 1.2,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      noteMessage.trim().isNotEmpty
                          ? noteMessage
                          : "No message included with this request.",
                      style: TextStyle(
                        color: noteMessage.trim().isNotEmpty
                            ? Colors.white
                            : context.textSecondary,
                        fontSize: 13.5,
                        fontStyle: noteMessage.trim().isNotEmpty
                            ? FontStyle.normal
                            : FontStyle.italic,
                        fontFamily: 'Inter',
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Action button
              if (!isAlreadyConnected)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final otherUser = notification['other_user'] as Map<String, dynamic>? ?? {};
                      final senderId = otherUser['id'] as int;
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      connectionProvider.connectUsers(
                        notificationProvider.userId!,
                        senderId,
                        sharedCardByPresenter: 'both',
                        connectionType: 'direct_connect',
                      ).then((_) {
                        notificationProvider.markAsSeen(notification['id']);
                      }).catchError((err) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text("Could not connect. Please try again.")),
                        );
                      });
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_rounded, size: 16, color: Colors.black),
                        SizedBox(width: 8),
                        Text(
                          "Accept & Connect",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F2030),
                    foregroundColor: const Color(0xFF8B8C9E),
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Close"),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationDetails(BuildContext context,
      Map<String, dynamic> notification, String? noteText,
      {bool startWithNoteInput = false}) {
    HapticFeedback.mediumImpact();
    final otherUser = notification['other_user'] as Map<String, dynamic>? ?? {};
    final referredUser =
        notification['referred_user'] as Map<String, dynamic>? ?? {};
    final String type = notification['type'] ?? 'referral';

    final String requesterName = otherUser['name'] ?? 'Unknown User';
    final String requesterProfession = otherUser['profession'] ?? '';
    final String requesterAvatar =
        otherUser['avatar_url'] ?? otherUser['avatarUrl'] ?? '';

    final String targetName = referredUser['name'] ?? 'Unknown User';
    final String targetProfession = referredUser['profession'] ?? '';
    final String targetAvatar =
        referredUser['avatar_url'] ?? referredUser['avatarUrl'] ?? '';

    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    final isAlreadyConnected = referredUser['id'] != null &&
        connectionProvider.connections
            .any((c) => c['id'] == referredUser['id']);

    final rawNote = notification['note'] as String?;
    final bool isReferralRequest = type == 'referral' &&
        rawNote != null &&
        (rawNote.startsWith('[REFERRAL_REQUEST]') ||
            rawNote.startsWith('[REFERRAL_REQUEST_ACTIONED]'));

    bool showNoteInput = startWithNoteInput;
    final controller = TextEditingController(
      text: "Hey $targetName, I'd like to introduce you to $requesterName.",
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentNote = notification['note'] as String?;
            final isRequestActioned = currentNote != null &&
                currentNote.startsWith('[REFERRAL_REQUEST_ACTIONED]');
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E202C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header with Close Icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isReferralRequest
                                  ? "Introduction Request"
                                  : "Referral Details",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white60, size: 20),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Connection flow visual card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13141F),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.03),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Requester details
                              _buildProfileRow(
                                  context,
                                  requesterName,
                                  requesterProfession,
                                  requesterAvatar,
                                  isReferralRequest ? "Requester" : "Referrer"),

                              // Connection arrow
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 20),
                                    Container(
                                      height: 24,
                                      width: 2,
                                      color: context.accentSecondary
                                          .withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.arrow_downward_rounded,
                                      size: 16,
                                      color: context.accentSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isReferralRequest
                                          ? "wants to connect with"
                                          : "referred to you",
                                      style: TextStyle(
                                        color: context.textMuted,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Target details
                              _buildProfileRow(
                                  context,
                                  targetName,
                                  targetProfession,
                                  targetAvatar,
                                  isReferralRequest ? "Target" : "Referred"),
                            ],
                          ),
                        ),

                        if (noteText != null && noteText.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            "MESSAGE FROM SENDER",
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13141F),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.03),
                              ),
                            ),
                            child: Text(
                              "\"$noteText\"",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                fontFamily: 'Inter',
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],

                        if (isReferralRequest && showNoteInput && !isRequestActioned) ...[
                          const SizedBox(height: 20),
                          const Text(
                            "YOUR INTRODUCTION NOTE",
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: controller,
                            maxLines: 3,
                            maxLength: 69,
                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF131422),
                              hintText: "Add your message...",
                              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF7C3AED)),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.1)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: (showNoteInput && !isRequestActioned)
                                    ? () {
                                        setDialogState(() {
                                          showNoteInput = false;
                                        });
                                      }
                                    : () => Navigator.pop(context),
                                child: Text((showNoteInput && !isRequestActioned) ? "Cancel" : "Close"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Builder(builder: (context) {
                                if (isReferralRequest) {
                                  return Container(
                                    decoration: !isRequestActioned
                                        ? BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                          )
                                        : null,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isRequestActioned
                                            ? const Color(0xFF1F2030)
                                            : Colors.transparent,
                                        foregroundColor: isRequestActioned
                                            ? const Color(0xFF8B8C9E)
                                            : Colors.black,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                      onPressed: isRequestActioned
                                          ? null
                                          : () {
                                              HapticFeedback.lightImpact();
                                              if (!showNoteInput) {
                                                setDialogState(() {
                                                  showNoteInput = true;
                                                });
                                              } else {
                                                final noteToSend = controller.text.trim();
                                                notificationProvider.sendReferral(
                                                  toUserId: referredUser['id'],
                                                  referredUserId: otherUser['id'],
                                                  note: noteToSend,
                                                ).then((_) {
                                                  notificationProvider.markReferralRequestActioned(
                                                    notification['id'],
                                                    notification['note'] ?? '',
                                                  );
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text("Introduction request approved and sent!"),
                                                      backgroundColor: Color(0xFF7C3AED),
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                }).catchError((err) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text("Could not send introduction. Please try again.")),
                                                  );
                                                });
                                              }
                                            },
                                      child: Text(
                                        isRequestActioned
                                            ? "Introduced"
                                            : (showNoteInput ? "Send Intro" : "Introduce"),
                                        style: TextStyle(
                                          color: isRequestActioned
                                              ? const Color(0xFF8B8C9E)
                                              : Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  // isNormalReferral
                                  if (isAlreadyConnected) {
                                    return ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1F2030),
                                        foregroundColor: const Color(0xFF8B8C9E),
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.pop(context);
                                        final chatProfileMap = {
                                          'id': referredUser['id'],
                                          'name': targetName,
                                          'profession': targetProfession,
                                          'avatarUrl': targetAvatar,
                                          'avatar_url': targetAvatar,
                                        };
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                IndividualChatPage(
                                                    connectionData: chatProfileMap),
                                          ),
                                        );
                                      },
                                      child: const Text("Message"),
                                    );
                                  } else {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: Colors.black,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                        ),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          connectionProvider.connectUsers(
                                            notificationProvider.userId!,
                                            referredUser['id'],
                                            sharedCardByPresenter: 'both',
                                            connectionType: 'referral_connect',
                                          ).then((_) {
                                            notificationProvider
                                                .markAsSeen(notification['id']);
                                            Navigator.pop(context);
                                          }).catchError((err) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text("Could not connect. Please try again.")),
                                            );
                                          });
                                        },
                                        child: const Text(
                                          "Connect",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileRow(BuildContext context, String name, String profession,
      String avatar, String role) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.surfacePrimary,
          ),
          child: ClipOval(
            child: avatar.startsWith('http')
                ? Image.network(
                    avatar,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        _getInitials(name),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      _getInitials(name),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
              if (profession.isNotEmpty)
                Text(
                  profession,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 11,
                    fontFamily: 'Inter',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            role.toUpperCase(),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
