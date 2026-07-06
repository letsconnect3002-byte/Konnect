import 'package:connect/Config/app_theme.dart';
import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/notification_provider.dart';
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
    final otherUser = notification['other_user'] as Map<String, dynamic>? ?? {};
    final String type = notification['type'] ?? 'qr_code';
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
                                                    rawNote,
                                                  );
                                                  setDialogState(() {
                                                    final newNote = rawNote.replaceFirst(
                                                        '[REFERRAL_REQUEST]',
                                                        '[REFERRAL_REQUEST_ACTIONED]');
                                                    notification['note'] = newNote;
                                                    showNoteInput = false;
                                                  });
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
                                          connectionProvider
                                              .connectUsers(
                                            notificationProvider.userId!,
                                            referredUser['id'],
                                            connectionType: 'referral_connect',
                                          )
                                              .then((_) {
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
