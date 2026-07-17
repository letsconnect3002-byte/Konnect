import 'dart:convert';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:connect/Pages/PlanDetailPage.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/Providers/plans_provider.dart';
import 'package:connect/Providers/tribe_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late NotificationProvider _notificationProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<NotificationProvider>(context, listen: false)
            .fetchNotifications();
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
            if (isPlanNotif && n['plan_loaded'] == true && n['plan'] == null) {
              // Skip notifications for deleted plans
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

  Widget _buildNotificationItem(
      Map<String, dynamic> notification, NotificationProvider provider) {
    final String type = notification['type'] ?? 'qr_code';
    if (type == 'plan_invite' ||
        type == 'plan_update' ||
        type == 'plan_reminder_30' ||
        type == 'plan_reminder_start') {
      return PlanNotificationCard(notification: notification, provider: provider);
    }
    if (type == 'tribe_invite' ||
        type == 'tribe_request' ||
        type == 'tribe_approved' ||
        type == 'tribe_request_approved' ||
        type == 'tribe_request_declined' ||
        type == 'tribe_invite_declined') {
      return _buildTribeNotificationItem(notification, provider);
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
    final bool isReferralRequest = type == 'referral' &&
        rawNote != null &&
        (rawNote.startsWith('[REFERRAL_REQUEST]') ||
            rawNote.startsWith('[REFERRAL_REQUEST_ACTIONED]'));
    final bool isRequestActioned =
        rawNote != null && rawNote.startsWith('[REFERRAL_REQUEST_ACTIONED]');
    final bool isNormalReferral = type == 'referral' && !isReferralRequest;
    final bool isReferral = type == 'referral';
    final bool isQr = type == 'qr_code';
    final bool isReferralConnect = type == 'referral_connect';
    final Color accentColor = (isReferral || isReferralConnect)
        ? context.accentSecondary
        : (isQr ? const Color(0xFF00F2FE) : const Color(0xFF8B5CF6));

    final referredUser =
        notification['referred_user'] as Map<String, dynamic>? ?? {};
    final String referredName = referredUser['name'] ?? 'Unknown User';
    final String referredAvatarUrl =
        referredUser['avatar_url'] ?? referredUser['avatarUrl'] ?? '';
    final String referredProfession = referredUser['profession'] ?? '';

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

    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    final bool isAlreadyConnected = referredUser['id'] != null &&
        connectionProvider.connections
            .any((c) => c['id'] == referredUser['id']);

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
                                text: isQr
                                    ? " connected via QR scan"
                                    : (type == 'referral_connect'
                                        ? " connected via Referral"
                                        : " connected via Private Key"),
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
                                        gradient: LinearGradient(
                                          colors: [
                                            context.accentSecondary,
                                            context.accentSecondary
                                                .withValues(alpha: 0.7)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: Colors.white,
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
                if (!isReferralRequest) ...[
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
                                final chatProfileMap = {
                                  'id': referredUser['id'],
                                  'name': referredName,
                                  'profession': referredProfession,
                                  'avatarUrl': referredAvatarUrl,
                                  'avatar_url': referredAvatarUrl,
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
                                gradient: LinearGradient(
                                  colors: [
                                    context.accentSecondary,
                                    context.accentSecondary
                                        .withValues(alpha: 0.7)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
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
                                  connectionProvider
                                      .connectUsers(
                                    provider.userId!,
                                    referredUser['id'],
                                    sharedCardByPresenter: referredUser['default_card_visibility']?.toString(),
                                    connectionType: 'referral_connect',
                                  )
                                      .then((_) {
                                    provider.markAsSeen(notification['id']);
                                  }).catchError((err) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text("Error: $err")),
                                    );
                                  });
                                },
                                child: const Text(
                                  "Connect",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                            );
                          }
                        } else {
                          if (isUnseen) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isQr
                                      ? [
                                          const Color(0xFF00F2FE),
                                          const Color(0xFF00B5FE)
                                        ]
                                      : (type == 'referral_connect'
                                          ? [
                                              context.accentSecondary,
                                              context.accentSecondary
                                                  .withValues(alpha: 0.7)
                                            ]
                                          : [
                                              const Color(0xFF8B5CF6),
                                              const Color(0xFF6D28D9)
                                            ]),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
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

  Widget _buildTribeNotificationItem(
      Map<String, dynamic> notification, NotificationProvider provider) {
    final String type = notification['type'] ?? 'tribe_invite';
    final otherUser = notification['other_user'] as Map<String, dynamic>? ?? {};
    final String name = otherUser['name'] ?? 'Unknown User';
    final String avatarUrl =
        otherUser['avatar_url'] ?? otherUser['avatarUrl'] ?? '';
    final String timeStr =
        _getRelativeTime(notification['created_at'] as String?);
    final bool isUnseen = notification['is_seen'] == false;

    final String? rawNote = notification['note'] as String?;
    String tribeName = 'a Mafia';
    String? tribeId;
    if (rawNote != null && rawNote.startsWith('{')) {
      try {
        final parsed = jsonDecode(rawNote);
        tribeName = parsed['tribe_name']?.toString() ?? 'a Mafia';
        tribeId = parsed['tribe_id']?.toString();
      } catch (_) {}
    }

    const Color accentColor = Color(0xFF8B5CF6);

    String actionText;
    IconData actionIcon;
    if (type == 'tribe_invite') {
      actionText = " invited you to join ";
      actionIcon = Icons.mail_rounded;
    } else if (type == 'tribe_request') {
      actionText = " requested to join ";
      actionIcon = Icons.person_add_rounded;
    } else if (type == 'tribe_request_approved') {
      actionText = "'s request to join ";
      actionIcon = Icons.check_circle_rounded;
    } else if (type == 'tribe_request_declined') {
      actionText = "'s request to join ";
      actionIcon = Icons.cancel_rounded;
    } else if (type == 'tribe_invite_declined') {
      actionText = " declined invite to ";
      actionIcon = Icons.cancel_rounded;
    } else {
      actionText = " approved your request to join ";
      actionIcon = Icons.check_circle_rounded;
    }

    // Determine if this notification has already been actioned
    final bool isActioned = type == 'tribe_request_approved' ||
        type == 'tribe_request_declined' ||
        type == 'tribe_invite_declined' ||
        type == 'tribe_approved';

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
                                child: Icon(
                                  actionIcon,
                                  color:
                                      isUnseen ? accentColor : Colors.white60,
                                  size: 18,
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                actionIcon,
                                color: isUnseen ? accentColor : Colors.white60,
                                size: 18,
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
                              text: actionText,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            TextSpan(
                              text: tribeName,
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
                      if ((type == 'tribe_invite' || type == 'tribe_request') && tribeId != null && !isActioned) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(
                              width: 76,
                              height: 30,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF8B5CF6),
                                      Color(0xFF6D28D9)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () async {
                                    HapticFeedback.lightImpact();
                                    final tribeProvider =
                                        Provider.of<TribeProvider>(context,
                                            listen: false);
                                    try {
                                      if (type == 'tribe_invite') {
                                        await tribeProvider
                                            .joinTribeDirectly(tribeId!);
                                      } else {
                                        final requesterId = (otherUser['id'] as num?)?.toInt();
                                        if (requesterId == null) throw Exception("Invalid requester.");
                                        await tribeProvider
                                            .approveRequest(tribeId!, requesterId);
                                      }
                                      await provider.fetchNotifications();
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  "Action failed: $e")),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text(
                                    "Accept",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 76,
                              height: 30,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1F2030),
                                  foregroundColor: const Color(0xFF8B8C9E),
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.03),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                onPressed: () async {
                                  HapticFeedback.lightImpact();
                                  final tribeProvider =
                                      Provider.of<TribeProvider>(context,
                                          listen: false);
                                  try {
                                    final targetId = type == 'tribe_invite'
                                        ? provider.userId!
                                        : (otherUser['id'] as num?)?.toInt();
                                    if (targetId == null) throw Exception("Invalid target user.");
                                    await tribeProvider
                                        .declineRequestOrInvite(
                                            tribeId!, targetId);
                                    await provider.fetchNotifications();
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "Decline failed: $e")),
                                      );
                                    }
                                  }
                                },
                                child: const Text(
                                  "Decline",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (isActioned) ...[
                        const SizedBox(height: 6),
                        Text(
                          type == 'tribe_request_approved'
                              ? "Approved"
                              : type == 'tribe_approved'
                                  ? "Joined"
                                  : "Declined",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                            color: (type == 'tribe_request_approved' || type == 'tribe_approved')
                                ? Colors.green.withValues(alpha: 0.7)
                                : Colors.redAccent.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
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
                                            gradient: LinearGradient(
                                              colors: [
                                                context.accentSecondary,
                                                context.accentSecondary.withValues(alpha: 0.7)
                                              ],
                                            ),
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
                                            : Colors.white,
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
                                                    SnackBar(content: Text("Error: $err")),
                                                  );
                                                });
                                              }
                                            },
                                      child: Text(isRequestActioned
                                          ? "Introduced"
                                          : (showNoteInput ? "Send Intro" : "Introduce")),
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
                                        gradient: LinearGradient(
                                          colors: [
                                            context.accentSecondary,
                                            context.accentSecondary
                                                .withValues(alpha: 0.7)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: Colors.white,
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
                                            sharedCardByPresenter: referredUser['default_card_visibility']?.toString(),
                                            connectionType: 'referral_connect',
                                          ).then((_) {
                                            notificationProvider
                                                .markAsSeen(notification['id']);
                                            Navigator.pop(context);
                                          }).catchError((err) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text("Error: $err")),
                                            );
                                          });
                                        },
                                        child: const Text("Connect"),
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

class PlanNotificationCard extends StatefulWidget {
  final Map<String, dynamic> notification;
  final NotificationProvider provider;

  const PlanNotificationCard({
    super.key,
    required this.notification,
    required this.provider,
  });

  @override
  State<PlanNotificationCard> createState() => _PlanNotificationCardState();
}

class _PlanNotificationCardState extends State<PlanNotificationCard> {
  Map<String, dynamic>? _plan;
  bool _loading = true;
  bool _submitting = false;
  bool _showDeclineReason = false;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadPlan() async {
    if (widget.notification['plan_loaded'] == true) {
      if (mounted) {
        setState(() {
          _plan = widget.notification['plan'] as Map<String, dynamic>?;
          _loading = false;
        });
      }
      return;
    }
    final planId = widget.notification['note'] as String?;
    if (planId != null) {
      final plansProvider = Provider.of<PlansProvider>(context, listen: false);
      final plan = await plansProvider.getPlanById(planId);
      if (mounted) {
        setState(() {
          _plan = plan;
          _loading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _respond(String status, {String? reason}) async {
    final planId = widget.notification['note'] as String?;
    if (planId == null) return;

    setState(() => _submitting = true);
    final plansProvider = Provider.of<PlansProvider>(context, listen: false);
    await plansProvider.respondToPlanInviteByPlanId(
      planId: planId,
      status: status,
      declineReason: reason,
    );
    // Mark notification as seen
    await widget.provider.markAsSeen(widget.notification['id']);
    if (mounted) {
      setState(() {
        widget.notification['invite_status'] = status;
        _submitting = false;
        _showDeclineReason = false;
      });
      _loadPlan();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_plan == null) {
      // Plan was probably deleted or not found
      return const SizedBox.shrink();
    }

    final otherUser = widget.notification['other_user'] as Map<String, dynamic>? ?? {};
    final String inviterName = otherUser['name'] ?? 'Someone';
    final String avatarUrl = otherUser['avatar_url'] ?? otherUser['avatarUrl'] ?? '';
    final String timeStr = _getRelativeTime(widget.notification['created_at'] as String?);
    final bool isUnseen = widget.notification['is_seen'] == false;

    final title = _plan!['title'] as String? ?? 'Untitled Plan';
    final category = _plan!['category'] as String? ?? 'other';
    final startsAtStr = _plan!['starts_at'] as String?;
    final startsAt = startsAtStr != null ? DateTime.tryParse(startsAtStr)?.toLocal() : null;
    final location = _plan!['location'] as String?;
    final isOnline = _plan!['is_online'] == true;
    final type = widget.notification['type'] ?? 'plan_invite';

    // Find my status in invites
    final plansProvider = Provider.of<PlansProvider>(context);
    
    // We can also fetch the status from our plans list if we have it loaded
    final matchingPlan = plansProvider.plans.firstWhere(
      (p) => p['id'] == _plan!['id'],
      orElse: () => <String, dynamic>{},
    );
    final myStatus = widget.notification['invite_status'] as String? ??
        matchingPlan['my_status'] as String? ?? 'pending';

    final startsAtText = startsAt != null ? _formatDateTime(startsAt) : 'Time not set';

    String timeLabel = "in 30 minutes";
    if (startsAt != null) {
      try {
        final diff = startsAt.difference(DateTime.now());
        if (diff.isNegative) {
          timeLabel = "now";
        } else {
          final days = diff.inDays;
          final hours = diff.inHours % 24;
          final minutes = diff.inMinutes % 60;
          final seconds = diff.inSeconds % 60;

          final pad = (int n) => n.toString().padLeft(2, '0');

          if (days > 0) {
            timeLabel = "in ${days}d:${pad(hours)}h:${pad(minutes)}m:${pad(seconds)}s";
          } else if (hours > 0) {
            timeLabel = "in ${pad(hours)}h:${pad(minutes)}m:${pad(seconds)}s";
          } else {
            timeLabel = "in ${pad(minutes)}m:${pad(seconds)}s";
          }
        }
      } catch (e) {
        print("Error formatting starts_at countdown in card: $e");
      }
    }

    return Dismissible(
      key: Key(widget.notification['id'].toString()),
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
        widget.provider.deleteNotification(widget.notification['id']);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.provider.markAsSeen(widget.notification['id']);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlanDetailPage(planId: _plan!['id'] as String),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Inviter avatar
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isUnseen
                        ? Border.all(
                            color: AppColors.accentPrimary.withValues(alpha: 0.6),
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
                                  Center(child: Text(_getInitials(inviterName))),
                            )
                          : Center(child: Text(_getInitials(inviterName))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Message text
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontFamily: 'Inter',
                            height: 1.3,
                          ),
                          children: [
                            if (type == 'plan_reminder_30' ||
                                type == 'plan_reminder_start') ...[
                              const TextSpan(
                                text: "Reminder: ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: '${categoryEmoji(category)} $title',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: type == 'plan_reminder_30'
                                    ? " starts $timeLabel"
                                    : " is starting now!",
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ] else ...[
                              TextSpan(
                                text: inviterName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: () {
                                  if (type == 'plan_invite') {
                                    return " invited you to join ";
                                  } else {
                                    final fields = widget.notification['changed_fields'];
                                    if (fields is List && fields.isNotEmpty) {
                                      final labelsMap = {
                                        'starts_at': 'time',
                                        'location': 'location',
                                        'title': 'title',
                                        'description': 'description',
                                        'category': 'category',
                                        'plan_type': 'type',
                                        'is_online': 'online status',
                                        'meeting_link': 'meeting link',
                                      };
                                      final labels = fields.map((f) => labelsMap[f] ?? f).toList();
                                      return " updated the plan (changed: ${labels.join(', ')}) ";
                                    }
                                    return " updated the plan ";
                                  }
                                }(),
                                style: const TextStyle(color: Colors.white70),
                              ),
                              TextSpan(
                                text: '${categoryEmoji(category)} $title',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
                      const SizedBox(height: 4),
                      // Time / location of the plan
                      Text(
                        '$startsAtText${location != null && location.isNotEmpty ? ' · $location' : (isOnline ? ' · Online' : '')}',
                        style: AppTypography.bodyText.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      
                      // Accept/Decline action buttons (only for plan_invite type & pending status)
                      if (type == 'plan_invite' && myStatus == 'pending') ...[
                        const SizedBox(height: 10),
                        if (!_showDeclineReason)
                          Row(
                            children: [
                              // Accept
                              GestureDetector(
                                onTap: _submitting ? null : () => _respond('accepted'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentPrimary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Accept',
                                    style: AppTypography.captionText.copyWith(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Decline
                              GestureDetector(
                                onTap: _submitting ? null : () => setState(() => _showDeclineReason = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    border: Border.all(color: AppColors.borderMuted),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Decline',
                                    style: AppTypography.captionText.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          // Decline reason input
                          const SizedBox(height: 6),
                          Text(
                            "Why can't you make it?",
                            style: AppTypography.captionText.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderMuted),
                            ),
                            child: TextField(
                              controller: _reasonController,
                              style: AppTypography.bodyText.copyWith(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'e.g. Family dinner (optional)',
                                hintStyle: AppTypography.bodyText.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _submitting
                                    ? null
                                    : () => _respond('declined', reason: _reasonController.text.trim()),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Submit',
                                    style: AppTypography.captionText.copyWith(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() => _showDeclineReason = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: AppTypography.captionText.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ] else if (type == 'plan_invite') ...[
                        // Status badge (Accepted/Declined)
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: myStatus == 'accepted'
                                ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                                : const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            myStatus == 'accepted' ? 'Accepted' : 'Declined',
                            style: AppTypography.captionText.copyWith(
                              color: myStatus == 'accepted'
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFEF4444),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
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

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _getRelativeTime(String? createdAtStr) {
    if (createdAtStr == null) return '';
    try {
      final dateTime = DateTime.parse(createdAtStr).toLocal();
      final diff = DateTime.now().difference(dateTime);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dateTime.day}/${dateTime.month}';
    } catch (e) {
      return '';
    }
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, $displayHour:$minute $period';
  }
}
