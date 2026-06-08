import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
              ),
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
      margin: const EdgeInsets.only(bottom: 20),
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
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
          const SizedBox(height: 12),
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

    final bool isQr = type == 'qr_code';
    final Color accentColor =
        isQr ? const Color(0xFF00F2FE) : const Color(0xFF8B5CF6);

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
            final profileMap = {
              'id': otherUser['id'],
              'name': name,
              'profession': profession,
              'avatarUrl': avatarUrl,
              'company': otherUser['company'] ?? '',
              'bio': otherUser['bio'] ?? '',
              'connection_profile_id': otherUser['id'],
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF1A1B2E),
                    backgroundImage: avatarUrl.startsWith('http')
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl.startsWith('http')
                        ? null
                        : Text(
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
                              text: isQr
                                  ? " connected via QR scan"
                                  : " connected via VIP Pass",
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
                      // const SizedBox(height: 2),
                      // Text(
                      //   profession,
                      //   style: const TextStyle(
                      //     color: Color(0xFF5C5E78),
                      //     fontSize: 11.5,
                      //     fontFamily: 'Inter',
                      //   ),
                      // ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  height: 30,
                  child: isUnseen
                      ? Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isQr
                                  ? [
                                      const Color(0xFF00F2FE),
                                      const Color(0xFF00B5FE)
                                    ]
                                  : [
                                      const Color(0xFF8B5CF6),
                                      const Color(0xFF6D28D9)
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
                        )
                      : ElevatedButton(
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
              "New connections via QR code scans or VIP pass keys will show up here.",
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
}
