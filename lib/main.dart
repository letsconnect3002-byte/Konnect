import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connect/firebase_options.dart';
import 'package:connect/Providers/LocalDatabaseHelper.dart';
import 'package:connect/Config/supabase_config.dart';
import 'package:connect/Pages/DirectMessagesHubPage.dart';
import 'package:connect/Pages/OtherProfilesPage.dart';
import 'package:connect/Pages/yet_to_be_built_profile_page.dart';
import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:connect/Pages/Tribe/TribeChatPage.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/chat_provider.dart';
import 'package:connect/Providers/tribe_provider.dart';
import 'package:connect/Repositories/tribe_repository.dart';
import 'package:connect/Widgets/in_app_notification_banner.dart';
import 'package:connect/Widgets/profile_nudge_banner.dart';
import 'package:connect/Pages/YourNetworkPage.dart';
import 'package:connect/Pages/NotificationPage.dart';
import 'package:connect/Pages/ThreadDetailPage.dart';
import 'package:connect/Repositories/profile_repository.dart';
import 'package:connect/Repositories/connection_repository.dart';
import 'package:connect/Repositories/chat_repository.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/services/analytics_service.dart';
import 'package:connect/Repositories/notification_repository.dart';
import 'package:connect/Providers/plans_provider.dart';
import 'package:connect/Repositories/plans_repository.dart';
import 'package:connect/Providers/network_provider.dart';
import 'package:connect/Repositories/network_repository.dart';
import 'package:connect/Repositories/pulse_repository.dart';
import 'package:connect/Providers/pulse_provider.dart';
import 'package:connect/Pages/CircleFeedPage.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/services/linkrunner_service.dart';
import 'package:connect/Widgets/referral_connection_modal.dart';
import 'package:connect/Repositories/feed_repository.dart';
import 'package:connect/services/share_receiver_service.dart';
import 'package:timezone/data/latest.dart' as tz_latest;
import 'package:timezone/timezone.dart' as tz;
import 'package:audio_session/audio_session.dart' as session;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:connect/Config/app_theme.dart';
import 'package:connect/Pages/AuthScreen.dart';
import 'package:connect/Pages/ResetPasswordScreen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final Set<String> _recentlyShownBanners = {};

void showInAppMessageBanner({
  required String messageId,
  required String roomId,
  required int senderId,
  required String senderName,
  required String avatarUrl,
  required String message,
}) {
  if (_recentlyShownBanners.contains(messageId)) return;
  _recentlyShownBanners.add(messageId);
  Timer(const Duration(seconds: 10),
      () => _recentlyShownBanners.remove(messageId));

  final overlayState = navigatorKey.currentState?.overlay;
  if (overlayState != null) {
    InAppNotificationBanner.show(
      overlayState: overlayState,
      senderId: senderId,
      senderName: senderName,
      avatarUrl: avatarUrl,
      message: message,
      onTap: () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (routeContext) => IndividualChatPage(
              otherUserId: senderId,
            ),
          ),
        );
      },
    );
    print("InAppBanner: Message banner displayed for messageId: $messageId");
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel notificationChannel =
    AndroidNotificationChannel(
  'messages_channel',
  'Messages',
  description: 'Notifications for new messages',
  importance: Importance.max,
);

int getNotificationId(String messageId) {
  try {
    final cleanStr = messageId.replaceAll('-', '');
    if (cleanStr.length < 8) {
      return messageId.hashCode & 0x7FFFFFFF;
    }
    final hex = cleanStr.substring(0, 8);
    return int.parse(hex, radix: 16) & 0x7FFFFFFF;
  } catch (e) {
    print("Error parsing UUID for notification ID: $e");
    return messageId.hashCode & 0x7FFFFFFF;
  }
}

/// Shows a local notification keyed by [roomId] so that multiple messages
/// from the same conversation collapse into a single tray entry.
/// [messageLines] contains every unread message payload for this room,
/// ordered oldest-first.  When there is more than one line, Android uses
/// InboxStyle so the user can see ALL accumulated messages in the tray.
Future<void> showLocalNotification(
  String roomId,
  String title,
  List<String> messageLines,
  Map<String, dynamic> dataPayload,
) async {
  final notificationId = getNotificationId(roomId);

  List<String> formattedLines = [];
  try {
    final unreadMsgs =
        await LocalDatabaseHelper.instance.getUnreadMessagesForRoom(roomId);
    final ownerId = await LocalDatabaseHelper.instance.getActiveUserId();

    if (unreadMsgs.isNotEmpty) {
      for (final msg in unreadMsgs) {
        final int msgSenderId = msg['sender_id'] as int? ?? 0;
        final String payload = msg['payload'] as String? ?? '';
        if (ownerId != null && msgSenderId == ownerId) {
          formattedLines.add("You: $payload");
        } else {
          formattedLines.add(payload);
        }
      }
    }
  } catch (e) {
    print("Error loading unread messages for local notification: $e");
  }

  if (formattedLines.isEmpty) {
    formattedLines = messageLines;
  }

  final int count = formattedLines.length;
  final String latestBody = formattedLines.last;

  final List<AndroidNotificationAction> androidActions = [
    const AndroidNotificationAction(
      'action_reply',
      'Reply',
      inputs: [
        AndroidNotificationActionInput(
          label: 'Type message...',
        ),
      ],
      allowGeneratedReplies: true,
    ),
    const AndroidNotificationAction(
      'action_mark_read',
      'Mark as Read',
    ),
  ];

  final AndroidNotificationDetails androidNotificationDetails;
  if (count > 1) {
    androidNotificationDetails = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'Notifications for new messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      number: count,
      styleInformation: InboxStyleInformation(
        formattedLines,
        contentTitle: title,
        summaryText: '$count messages',
      ),
      actions: androidActions,
    );
  } else {
    androidNotificationDetails = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'Notifications for new messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      actions: androidActions,
    );
  }

  final DarwinNotificationDetails iosNotificationDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    threadIdentifier: roomId,
    categoryIdentifier: 'messages_category',
  );

  final NotificationDetails notificationDetails = NotificationDetails(
    android: androidNotificationDetails,
    iOS: iosNotificationDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    id: notificationId,
    title: title,
    body: latestBody,
    notificationDetails: notificationDetails,
    payload: jsonEncode(dataPayload),
  );
}

/// Cancels the notification for a given chat room.
Future<void> cancelLocalNotification(String roomId) async {
  final notificationId = getNotificationId(roomId);
  await flutterLocalNotificationsPlugin.cancel(id: notificationId);
}

/// Shows a connection or referral local notification with interactive action buttons.
Future<void> showConnectionLocalNotification({
  required String notificationId,
  required String type,
  required String title,
  required String body,
  required Map<String, dynamic> dataPayload,
}) async {
  final int notifId = getNotificationId(notificationId);

  // Determine actions based on type and note
  final String? note = dataPayload['note']?.toString();
  final bool isReferralRequest = type == 'referral' &&
      note != null &&
      (note.startsWith('[REFERRAL_REQUEST]') ||
          note.startsWith('[REFERRAL_REQUEST_ACTIONED]'));
  final bool isRequestActioned =
      note != null && note.startsWith('[REFERRAL_REQUEST_ACTIONED]');
  final bool isNormalReferral = type == 'referral' && !isReferralRequest;

  bool isAlreadyConnected = false;
  if (isNormalReferral) {
    try {
      final referredUserIdStr = dataPayload['referred_user_id']?.toString() ??
          dataPayload['target_id']?.toString();
      final referredUserId =
          referredUserIdStr != null ? int.tryParse(referredUserIdStr) : null;
      final activeUserId = await LocalDatabaseHelper.instance.getActiveUserId();
      if (referredUserId != null && activeUserId != null) {
        final client =
            SupabaseClient(SupabaseConfig.url, SupabaseConfig.serviceRoleKey);
        final id1 =
            activeUserId < referredUserId ? activeUserId : referredUserId;
        final id2 =
            activeUserId > referredUserId ? activeUserId : referredUserId;
        final res = await client
            .from('user_connections')
            .select()
            .eq('user_id_1', id1)
            .eq('user_id_2', id2)
            .maybeSingle();
        isAlreadyConnected = res != null;
      }
    } catch (e) {
      print(
          "Error checking connection status in showConnectionLocalNotification: $e");
    }
  }

  List<AndroidNotificationAction> androidActions = [];
  String iosCategory = 'messages_category';

  final bool isConnectionConfirmation =
      type == 'referral_connect' || type == 'vip_pass_key';
  final bool isPlanNotif = type == 'plan_invite' ||
      type == 'plan_update' ||
      type == 'plan_reminder_30' ||
      type == 'plan_reminder_start';
  final bool isTribeInvite = type == 'tribe_invite';
  final bool isTribeRequest = type == 'tribe_request';
  final bool isInformational = type == 'tribe_removed' ||
      type == 'tribe_approved' ||
      type == 'tribe_added';

  if (isTribeInvite) {
    androidActions = [
      const AndroidNotificationAction(
        'action_tribe_accept',
        'Accept',
      ),
      const AndroidNotificationAction(
        'action_tribe_decline',
        'Decline',
      ),
    ];
    iosCategory = 'tribe_invite_category';
  } else if (isTribeRequest) {
    androidActions = [
      const AndroidNotificationAction(
        'action_tribe_accept',
        'Accept',
      ),
      const AndroidNotificationAction(
        'action_tribe_decline',
        'Decline',
      ),
    ];
    iosCategory = 'tribe_request_category';
  } else if (type == 'plan_invite') {
    androidActions = [
      const AndroidNotificationAction(
        'action_plan_accept',
        'Accept',
      ),
      const AndroidNotificationAction(
        'action_plan_decline',
        'Decline',
        inputs: [
          AndroidNotificationActionInput(
            label: 'Reason for declining...',
          ),
        ],
      ),
    ];
    iosCategory = 'plan_invite_category';
  } else if (isConnectionConfirmation || isPlanNotif || isInformational) {
    androidActions = [];
    iosCategory = 'default_category';
  } else if (isReferralRequest) {
    if (!isRequestActioned) {
      androidActions = [
        const AndroidNotificationAction(
          'action_introduce',
          'Introduce',
        ),
        const AndroidNotificationAction(
          'action_ignore',
          'Ignore',
        ),
      ];
      iosCategory = 'referral_request_category';
    }
  } else if (isNormalReferral) {
    if (isAlreadyConnected) {
      androidActions = [
        const AndroidNotificationAction(
          'action_message',
          'Message',
        ),
        const AndroidNotificationAction(
          'action_ignore',
          'Ignore',
        ),
      ];
      iosCategory = 'referral_message_category';
    } else {
      androidActions = [
        const AndroidNotificationAction(
          'action_connect',
          'Connect',
        ),
        const AndroidNotificationAction(
          'action_ignore',
          'Ignore',
        ),
      ];
      iosCategory = 'referral_connect_category';
    }
  } else {
    androidActions = [
      const AndroidNotificationAction(
        'action_chat',
        'Chat',
      ),
      const AndroidNotificationAction(
        'action_ignore',
        'Ignore',
      ),
    ];
    iosCategory = 'connection_accept_category';
  }

  // Create a separate notification channel for connection updates so we don't mix them with DM messages
  const AndroidNotificationChannel connectionChannel =
      AndroidNotificationChannel(
    'connections_channel',
    'Connections',
    description: 'Notifications for connection requests and referrals',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // Ensure channel is registered
  try {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(connectionChannel);
  } catch (e) {
    print("Error creating connection channel: $e");
  }

  final androidDetails = AndroidNotificationDetails(
    connectionChannel.id,
    connectionChannel.name,
    channelDescription: connectionChannel.description,
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    showWhen: true,
    category: AndroidNotificationCategory.promo,
    actions: androidActions,
  );

  final iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    categoryIdentifier: iosCategory,
  );

  final details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  final Map<String, dynamic> fullPayload =
      Map<String, dynamic>.from(dataPayload);
  fullPayload['notification_id'] = notificationId;
  fullPayload['type'] = type;
  if (!fullPayload.containsKey('is_connection_notification')) {
    fullPayload['is_connection_notification'] = true;
  }

  await flutterLocalNotificationsPlugin.show(
    id: notifId,
    title: title,
    body: body,
    notificationDetails: details,
    payload: jsonEncode(fullPayload),
  );
  print("PushNotifications: Connection notification displayed. ID: $notifId");
}

String? pendingNotificationPayload;
int? targetChatSenderId;
bool targetOpenNotificationsPage = false;
String? targetTribeChatId;
String? targetTribeName;

void handleLocalNotificationClickPayload(String payload) {
  try {
    final data = jsonDecode(payload);
    final action = data['action'] as String?;
    if (action == 'complete_profile') {
      appShellKey.currentState?.setSelectedIndex(4);
      return;
    }
    if (action == 'new_pulse') {
      appShellKey.currentState?.setSelectedIndex(0);
      return;
    }
    if (action == 'feed_notification') {
      final rootPostId =
          data['root_post_id']?.toString() ?? data['post_id']?.toString() ?? '';
      final postId = data['post_id']?.toString() ?? '';
      if (rootPostId.isNotEmpty) {
        appShellKey.currentState?.setSelectedIndex(0);
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (routeContext) => ThreadDetailPage(
              rootPostId: rootPostId,
              highlightPostId: postId.isNotEmpty ? postId : rootPostId,
            ),
          ),
        );
      }
      return;
    }
    if (action == 'tribe_message' ||
        action == 'tribe_added' ||
        data['real_type'] == 'tribe_added') {
      final tribeId = data['tribe_id'] as String?;
      final tribeName = data['tribe_name'] as String? ?? 'Mafia';
      if (tribeId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (routeContext) =>
                TribeChatPage(tribeId: tribeId, tribeName: tribeName),
          ),
        );
      }
      return;
    }
    if (action == 'connection_notification') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (routeContext) => const NotificationPage(),
        ),
      );
      return;
    }
    final senderIdStr = data['sender_id'] as String?;
    if (senderIdStr != null) {
      final senderId = int.tryParse(senderIdStr);
      if (senderId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (routeContext) =>
                IndividualChatPage(otherUserId: senderId),
          ),
        );
      }
    }
  } catch (e) {
    print("Error handling local notification click payload: $e");
  }
}

@pragma('vm:entry-point')
Future<void> onNotificationActionReceived(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  final String? actionId = response.actionId;
  final String? payload = response.payload;
  print(
      "PushNotificationsAction: Action received. ID: $actionId, payload: $payload");
  if (payload == null) return;

  try {
    final Map<String, dynamic> data = jsonDecode(payload);
    AnalyticsService.logEvent(
      name: 'push_action_executed',
      parameters: {
        'action_id': actionId ?? 'default',
        'category': (data['action'] ?? 'notification').toString(),
      },
    );
    final client =
        SupabaseClient(SupabaseConfig.url, SupabaseConfig.serviceRoleKey);

    final isTribeMessage = data['action'] == 'tribe_message';
    if (isTribeMessage) {
      if (actionId == 'action_tribe_reply') {
        final String? replyText = response.input;
        print(
            "PushNotificationsAction: Tribe Direct Reply triggered. Text: $replyText");
        if (replyText != null && replyText.trim().isNotEmpty) {
          final String? tribeId = data['tribe_id']?.toString();
          final senderIdStr = data['sender_id']?.toString();
          if (tribeId != null && senderIdStr != null) {
            final ownerId =
                await LocalDatabaseHelper.instance.getActiveUserId();
            if (ownerId != null) {
              final String newMessageId = const Uuid().v4();
              final String createdAt = DateTime.now().toUtc().toIso8601String();

              try {
                await client.from('tribe_messages').insert({
                  'id': newMessageId,
                  'tribe_id': tribeId,
                  'sender_id': ownerId,
                  'content': replyText.trim(),
                  'message_type': 'text',
                  'created_at': createdAt,
                  'updated_at': createdAt,
                });
                print(
                    "PushNotificationsAction: Tribe message sent to Supabase successfully");
              } catch (supabaseError) {
                print(
                    "PushNotificationsAction: Supabase insert error for tribe message: $supabaseError");
              }

              int count = 1;
              List<String> lines = [];
              try {
                final prefs = await SharedPreferences.getInstance();
                final key = 'unread_tribe_messages_$tribeId';
                lines = prefs.getStringList(key) ?? [];
                lines.add("You: ${replyText.trim()}");
                await prefs.setStringList(key, lines);
                count = lines.length;
              } catch (e) {
                print(
                    "PushNotificationsAction: Error updating SharedPreferences on reply: $e");
              }

              try {
                final tribeName = data['tribe_name']?.toString() ?? 'Mafia';
                const AndroidNotificationChannel tribeChannel =
                    AndroidNotificationChannel(
                  'tribe_messages_channel',
                  'Mafia Messages',
                  description: 'Notifications for Mafia group chat messages',
                  importance: Importance.max,
                );

                await flutterLocalNotificationsPlugin
                    .resolvePlatformSpecificImplementation<
                        AndroidFlutterLocalNotificationsPlugin>()
                    ?.createNotificationChannel(tribeChannel);

                final androidDetails = AndroidNotificationDetails(
                  tribeChannel.id,
                  tribeChannel.name,
                  channelDescription: tribeChannel.description,
                  importance: Importance.max,
                  priority: Priority.high,
                  showWhen: true,
                  number: count,
                  category: AndroidNotificationCategory.message,
                  styleInformation: count > 1
                      ? InboxStyleInformation(
                          lines,
                          contentTitle: "New Messages in $tribeName",
                          summaryText: '$count messages',
                        )
                      : null,
                  actions: [
                    const AndroidNotificationAction(
                      'action_tribe_reply',
                      'Reply',
                      inputs: [
                        AndroidNotificationActionInput(
                          label: 'Type message...',
                        ),
                      ],
                      allowGeneratedReplies: true,
                    ),
                  ],
                );

                final iosDetails = DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                  threadIdentifier: tribeId,
                  categoryIdentifier: 'tribe_message_category',
                );

                final details = NotificationDetails(
                  android: androidDetails,
                  iOS: iosDetails,
                );

                final Map<String, dynamic> fullPayload = {
                  'action': 'tribe_message',
                  'message_id': newMessageId,
                  'tribe_id': tribeId,
                  'tribe_name': tribeName,
                  'sender_id': senderIdStr,
                  'sender_name': data['sender_name'] ?? 'New Message',
                  'payload': replyText.trim(),
                  'is_connection_notification': false,
                };

                final notifId = getNotificationId(tribeId);
                await flutterLocalNotificationsPlugin.show(
                  id: notifId,
                  title: count > 1
                      ? "New Messages in $tribeName"
                      : "New Message in $tribeName",
                  body: count > 1 ? lines.last : "You: ${replyText.trim()}",
                  notificationDetails: details,
                  payload: jsonEncode(fullPayload),
                );
                print(
                    "PushNotificationsAction: Updated local notification with reply. ID: $notifId");
              } catch (e) {
                print(
                    "PushNotificationsAction: Error updating local notification tray on reply: $e");
              }
            }
          }
        }
      }
      return;
    }

    final isConnectionNotif = data['is_connection_notification'] == true;

    if (isConnectionNotif) {
      final String? notificationId =
          data['notification_id']?.toString() ?? data['id']?.toString();
      if (notificationId == null) {
        print(
            "PushNotificationsAction: Missing notificationId in connection notification payload");
        return;
      }
      final int notifId = getNotificationId(notificationId);

      try {
        if (actionId == 'action_ignore') {
          print(
              "PushNotificationsAction: Ignore action triggered for notification: $notificationId");
          await client
              .from('connection_notifications')
              .update({'is_seen': true}).eq('id', notificationId);
        } else if (actionId == 'action_connect') {
          print("PushNotificationsAction: Connect action triggered");
          final myUserId = await LocalDatabaseHelper.instance.getActiveUserId();
          final referredUserIdStr = data['referred_user_id']?.toString() ??
              data['target_id']?.toString();
          final referredUserId = referredUserIdStr != null
              ? int.tryParse(referredUserIdStr)
              : null;
          if (myUserId != null && referredUserId != null) {
            final int id1 =
                myUserId < referredUserId ? myUserId : referredUserId;
            final int id2 =
                myUserId > referredUserId ? myUserId : referredUserId;

            // Fetch other user's default_card_visibility from Supabase
            String referredUserDefaultCard = 'casual';
            try {
              final otherProfileRes = await client
                  .from('profiles')
                  .select('default_card_visibility')
                  .eq('id', referredUserId)
                  .maybeSingle();
              if (otherProfileRes != null &&
                  otherProfileRes['default_card_visibility'] != null) {
                referredUserDefaultCard =
                    otherProfileRes['default_card_visibility'].toString();
                if (referredUserDefaultCard == 'both') {
                  referredUserDefaultCard = 'casual';
                }
              }
            } catch (fetchErr) {
              print(
                  "PushNotificationsAction: Error fetching other user profile: $fetchErr");
            }

            final prefs = await SharedPreferences.getInstance();
            final String defaultCard =
                prefs.getString('default_card_visibility') ?? 'casual';

            String u1Share = 'casual';
            String u2Share = 'casual';

            if (myUserId < referredUserId) {
              u1Share = defaultCard;
              u2Share = referredUserDefaultCard;
            } else {
              u1Share = referredUserDefaultCard;
              u2Share = defaultCard;
            }

            await client.from('user_connections').upsert({
              'user_id_1': id1,
              'user_id_2': id2,
              'user_1_shared_card': u1Share,
              'user_2_shared_card': u2Share,
            });

            await client.from('connection_notifications').insert([
              {
                'user_id': myUserId,
                'other_user_id': referredUserId,
                'type': 'referral_connect',
                'is_seen': false,
              },
              {
                'user_id': referredUserId,
                'other_user_id': myUserId,
                'type': 'referral_connect',
                'is_seen': false,
              }
            ]);

            await client
                .from('connection_notifications')
                .update({'is_seen': true}).eq('id', notificationId);
          }
        } else if (actionId == 'action_introduce') {
          final String? noteInput = response.input?.trim();
          print(
              "PushNotificationsAction: Introduce action triggered. Note: $noteInput");

          final myUserId = await LocalDatabaseHelper.instance.getActiveUserId();
          final actorIdStr =
              data['actor_id']?.toString() ?? data['other_user_id']?.toString();
          final actorId = actorIdStr != null ? int.tryParse(actorIdStr) : null;
          final referredUserIdStr = data['referred_user_id']?.toString() ??
              data['target_id']?.toString();
          final referredUserId = referredUserIdStr != null
              ? int.tryParse(referredUserIdStr)
              : null;

          if (myUserId != null && actorId != null && referredUserId != null) {
            final String targetName = data['referred_user_name']?.toString() ??
                data['target_name']?.toString() ??
                'there';
            final String requesterName = data['actor_name']?.toString() ??
                data['other_user_name']?.toString() ??
                'someone';
            final String noteToSend = (noteInput != null &&
                    noteInput.isNotEmpty)
                ? noteInput
                : "Hey $targetName, I'd like to introduce you to $requesterName.";

            await client.from('connection_notifications').insert({
              'user_id': referredUserId,
              'other_user_id': myUserId,
              'referred_user_id': actorId,
              'type': 'referral',
              'note': noteToSend,
              'is_seen': false,
            });

            final currentNote = data['note']?.toString() ?? '';
            final actionedNote = currentNote.replaceFirst(
                '[REFERRAL_REQUEST]', '[REFERRAL_REQUEST_ACTIONED]');
            await client.from('connection_notifications').update({
              'note': actionedNote.isNotEmpty
                  ? actionedNote
                  : '[REFERRAL_REQUEST_ACTIONED]',
              'is_seen': true,
            }).eq('id', notificationId);
          }
        } else if (actionId == 'action_plan_accept') {
          print("PushNotificationsAction: Plan Accept action triggered");
          final myUserId = await LocalDatabaseHelper.instance.getActiveUserId();
          final planId =
              data['plan_id']?.toString() ?? data['note']?.toString();
          print(
              "PushNotificationsAction: myUserId: $myUserId, planId: $planId");
          if (myUserId != null && planId != null) {
            final inviteRes = await client
                .from('plan_invites')
                .select('id')
                .eq('plan_id', planId)
                .eq('invitee_id', myUserId)
                .maybeSingle();

            if (inviteRes != null && inviteRes['id'] != null) {
              final inviteId = inviteRes['id'] as String;
              await client.from('plan_invites').update({
                'status': 'accepted',
                'responded_at': DateTime.now().toUtc().toIso8601String(),
              }).eq('id', inviteId);
            }

            await client
                .from('connection_notifications')
                .update({'is_seen': true}).eq('id', notificationId);
          }
        } else if (actionId == 'action_plan_decline') {
          final String? declineReason = response.input?.trim();
          print(
              "PushNotificationsAction: Plan Decline action triggered. Reason: $declineReason");
          final myUserId = await LocalDatabaseHelper.instance.getActiveUserId();
          final planId =
              data['plan_id']?.toString() ?? data['note']?.toString();
          print(
              "PushNotificationsAction: myUserId: $myUserId, planId: $planId");
          if (myUserId != null && planId != null) {
            final inviteRes = await client
                .from('plan_invites')
                .select('id')
                .eq('plan_id', planId)
                .eq('invitee_id', myUserId)
                .maybeSingle();

            if (inviteRes != null && inviteRes['id'] != null) {
              final inviteId = inviteRes['id'] as String;
              await client.from('plan_invites').update({
                'status': 'declined',
                'decline_reason': declineReason,
                'responded_at': DateTime.now().toUtc().toIso8601String(),
              }).eq('id', inviteId);
            }

            await client
                .from('connection_notifications')
                .update({'is_seen': true}).eq('id', notificationId);
          }
        } else if (actionId == 'action_tribe_accept') {
          print("PushNotificationsAction: Tribe Accept action triggered");
          final myUserId = await LocalDatabaseHelper.instance.getActiveUserId();

          String? tribeId;
          String? realType;
          final noteStr = data['note']?.toString();
          if (noteStr != null && noteStr.startsWith('{')) {
            try {
              final parsed = jsonDecode(noteStr);
              tribeId = parsed['tribe_id']?.toString();
              realType = parsed['real_type']?.toString();
            } catch (_) {}
          }

          print(
              "PushNotificationsAction: myUserId: $myUserId, tribeId: $tribeId, realType: $realType");

          if (myUserId != null && tribeId != null) {
            final nowStr = DateTime.now().toUtc().toIso8601String();

            if (realType == 'tribe_request') {
              final requesterIdStr = data['actor_id']?.toString() ??
                  data['other_user_id']?.toString();
              final requesterId =
                  requesterIdStr != null ? int.tryParse(requesterIdStr) : null;
              if (requesterId != null) {
                final existingReq = await client
                    .from('tribe_members')
                    .select('status')
                    .eq('tribe_id', tribeId)
                    .eq('user_id', requesterId)
                    .maybeSingle();

                if (existingReq == null || existingReq['status'] != 'active') {
                  final rolesRes = await client
                      .from('tribe_roles')
                      .select('id')
                      .eq('tribe_id', tribeId)
                      .eq('is_default', true)
                      .maybeSingle();
                  final defaultRoleId =
                      rolesRes != null ? rolesRes['id'] as String? : null;
                  if (defaultRoleId != null) {
                    await client
                        .from('tribe_members')
                        .update({
                          'status': 'active',
                          'role_id': defaultRoleId,
                          'joined_at': nowStr,
                          'updated_at': nowStr,
                        })
                        .eq('tribe_id', tribeId)
                        .eq('user_id', requesterId);

                    await client.from('tribe_activity_log').insert({
                      'tribe_id': tribeId,
                      'actor_id': requesterId,
                      'action_type': 'joined',
                      'created_at': nowStr,
                    });

                    final tribeRes = await client
                        .from('tribes')
                        .select('name')
                        .eq('id', tribeId)
                        .maybeSingle();
                    final tribeName = tribeRes != null
                        ? tribeRes['name']?.toString() ?? 'Tribe'
                        : 'Tribe';
                    await client.from('connection_notifications').insert({
                      'user_id': requesterId,
                      'other_user_id': myUserId,
                      'type': 'referral',
                      'note': jsonEncode({
                        'tribe_id': tribeId,
                        'tribe_name': tribeName,
                        'real_type': 'tribe_approved'
                      }),
                      'is_seen': false,
                    });
                  }
                }
              }
            } else {
              final existingMem = await client
                  .from('tribe_members')
                  .select('status')
                  .eq('tribe_id', tribeId)
                  .eq('user_id', myUserId)
                  .maybeSingle();

              if (existingMem == null || existingMem['status'] != 'active') {
                await client
                    .from('tribe_members')
                    .update({
                      'status': 'active',
                      'joined_at': nowStr,
                      'updated_at': nowStr,
                    })
                    .eq('tribe_id', tribeId)
                    .eq('user_id', myUserId);

                await client.from('tribe_activity_log').insert({
                  'tribe_id': tribeId,
                  'actor_id': myUserId,
                  'action_type': 'joined',
                  'created_at': nowStr,
                });
              }
            }

            await client.from('connection_notifications').update({
              'is_seen': true,
            }).eq('id', notificationId);
          }
        } else if (actionId == 'action_tribe_decline') {
          print("PushNotificationsAction: Tribe Decline action triggered");
          final myUserId = await LocalDatabaseHelper.instance.getActiveUserId();

          String? tribeId;
          String? realType;
          final noteStr = data['note']?.toString();
          if (noteStr != null && noteStr.startsWith('{')) {
            try {
              final parsed = jsonDecode(noteStr);
              tribeId = parsed['tribe_id']?.toString();
              realType = parsed['real_type']?.toString();
            } catch (_) {}
          }

          print(
              "PushNotificationsAction: myUserId: $myUserId, tribeId: $tribeId, realType: $realType");

          if (myUserId != null && tribeId != null) {
            final nowStr = DateTime.now().toUtc().toIso8601String();

            final targetId = realType == 'tribe_request'
                ? (int.tryParse(data['actor_id']?.toString() ??
                        data['other_user_id']?.toString() ??
                        '') ??
                    myUserId)
                : myUserId;

            await client
                .from('tribe_members')
                .update({
                  'status': 'declined',
                  'updated_at': nowStr,
                })
                .eq('tribe_id', tribeId)
                .eq('user_id', targetId);

            await client.from('tribe_activity_log').insert({
              'tribe_id': tribeId,
              'actor_id': myUserId,
              'action_type': 'declined_invite',
              'created_at': nowStr,
            });

            await client.from('connection_notifications').update({
              'is_seen': true,
            }).eq('id', notificationId);
          }
        } else if (actionId == 'action_chat' || actionId == 'action_message') {
          print("PushNotificationsAction: Chat/Message action triggered");
          final referredUserIdStr = data['referred_user_id']?.toString() ??
              data['target_id']?.toString() ??
              data['other_user_id']?.toString();
          final referredUserId = referredUserIdStr != null
              ? int.tryParse(referredUserIdStr)
              : null;
          if (referredUserId != null) {
            targetChatSenderId = referredUserId;
          }

          await client
              .from('connection_notifications')
              .update({'is_seen': true}).eq('id', notificationId);
        }
      } catch (e) {
        print("PushNotificationsAction: Error handling action $actionId: $e");
      } finally {
        print(
            "PushNotificationsAction: Canceling/removing notification ID $notifId from tray");
        await flutterLocalNotificationsPlugin.cancel(id: notifId);
      }
      return;
    }

    final String? roomId = data['room_id']?.toString();
    final String? senderIdStr = data['sender_id']?.toString();
    if (roomId == null || senderIdStr == null) {
      print(
          "PushNotificationsAction: Missing roomId or senderIdStr in payload");
      return;
    }

    final senderId = int.tryParse(senderIdStr);
    if (senderId == null) {
      print("PushNotificationsAction: Invalid senderId format");
      return;
    }

    final notificationId = getNotificationId(roomId);

    if (actionId == 'action_mark_read') {
      print(
          "PushNotificationsAction: Mark as read triggered for room: $roomId, sender: $senderId");

      // 1. Update local DB
      final db = await LocalDatabaseHelper.instance.database;
      final ownerId = await LocalDatabaseHelper.instance.getActiveUserId() ?? 0;
      final localUpdated = await db.update(
        'messages',
        {'status': 'read'},
        where: 'room_id = ? AND owner_id = ? AND sender_id = ?',
        whereArgs: [roomId, ownerId, senderId],
      );
      print(
          "PushNotificationsAction: Local DB updated. Rows affected: $localUpdated");

      // 2. Update remote Supabase messages status to 'read'
      try {
        await client
            .from('messages')
            .update({'status': 'read'})
            .eq('room_id', roomId)
            .eq('sender_id', senderId)
            .inFilter('status', ['sent', 'delivered']);
        print(
            "PushNotificationsAction: Supabase messages marked read successfully");
      } catch (supabaseError) {
        print(
            "PushNotificationsAction: Supabase mark read error: $supabaseError");
      }

      // 3. Cancel the notification tray entry
      await flutterLocalNotificationsPlugin.cancel(id: notificationId);
      print("PushNotificationsAction: Notification tray entry cancelled");

      // 4. Delay tear-down of the isolate to allow connection sockets to fully flush
      await Future.delayed(const Duration(milliseconds: 500));
    } else if (actionId == 'action_reply') {
      final String? replyText = response.input;
      print(
          "PushNotificationsAction: Direct Reply triggered. Text: $replyText");
      if (replyText == null || replyText.trim().isEmpty) return;

      final ownerId = await LocalDatabaseHelper.instance.getActiveUserId();
      if (ownerId == null) {
        print("PushNotificationsAction: Owner ID not found. Cannot reply.");
        return;
      }

      // Generate a unique message ID
      final String newMessageId = const Uuid().v4();
      final String createdAt = DateTime.now().toUtc().toIso8601String();

      // 1. Insert message into local SQLite database as status: 'sent'
      try {
        await LocalDatabaseHelper.instance.insertMessage(
          newMessageId,
          roomId,
          ownerId,
          replyText.trim(),
          status: 'sent',
          createdAt: createdAt,
        );
        print("PushNotificationsAction: Message saved locally");
      } catch (dbError) {
        print("PushNotificationsAction: Database save error: $dbError");
      }

      // 2. Push the new message row directly to the Supabase 'messages' table
      try {
        await client.from('messages').insert({
          'id': newMessageId,
          'room_id': roomId,
          'sender_id': ownerId,
          'payload': replyText.trim(),
          'status': 'sent',
          'created_at': createdAt,
          'updated_at': createdAt,
        });
        print("PushNotificationsAction: Message sent to Supabase successfully");
      } catch (supabaseError) {
        print("PushNotificationsAction: Supabase insert error: $supabaseError");
      }

      // 3. Mark incoming messages in this room from senderId as read locally
      try {
        final db = await LocalDatabaseHelper.instance.database;
        final localUpdated = await db.update(
          'messages',
          {'status': 'read'},
          where: 'room_id = ? AND owner_id = ? AND sender_id = ?',
          whereArgs: [roomId, ownerId, senderId],
        );
        print(
            "PushNotificationsAction: Local DB updated on reply. Rows affected: $localUpdated");
      } catch (dbUpdateError) {
        print(
            "PushNotificationsAction: Error updating local DB on reply: $dbUpdateError");
      }

      // 4. Mark incoming messages in this room from senderId as read in Supabase
      try {
        await client
            .from('messages')
            .update({'status': 'read'})
            .eq('room_id', roomId)
            .eq('sender_id', senderId)
            .inFilter('status', ['sent', 'delivered']);
        print(
            "PushNotificationsAction: Supabase messages marked read successfully on reply");
      } catch (supabaseError) {
        print(
            "PushNotificationsAction: Supabase mark read error on reply: $supabaseError");
      }

      // 5. Cancel the notification tray entry
      await flutterLocalNotificationsPlugin.cancel(id: notificationId);
      print(
          "PushNotificationsAction: Direct Reply finished. Notification dismissed.");

      // 6. Delay tear-down of the isolate to allow connection sockets to fully flush
      await Future.delayed(const Duration(milliseconds: 500));
    }
  } catch (e) {
    print("Error handling remote notification action in background: $e");
  }
}

List<DarwinNotificationCategory> buildDarwinNotificationCategories() {
  return [
    DarwinNotificationCategory(
      'messages_category',
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.text(
          'action_reply',
          'Reply',
          buttonTitle: 'Send',
          placeholder: 'Type message...',
        ),
        DarwinNotificationAction.plain(
          'action_mark_read',
          'Mark as Read',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.destructive,
          },
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    ),
    DarwinNotificationCategory(
      'referral_request_category',
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain(
          'action_introduce',
          'Introduce',
        ),
        DarwinNotificationAction.plain(
          'action_ignore',
          'Ignore',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.destructive,
          },
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    ),
    DarwinNotificationCategory(
      'referral_connect_category',
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain(
          'action_connect',
          'Connect',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.foreground,
          },
        ),
        DarwinNotificationAction.plain(
          'action_ignore',
          'Ignore',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.destructive,
          },
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    ),
    DarwinNotificationCategory(
      'referral_message_category',
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain(
          'action_message',
          'Message',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.foreground,
          },
        ),
        DarwinNotificationAction.plain(
          'action_ignore',
          'Ignore',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.destructive,
          },
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    ),
    DarwinNotificationCategory(
      'connection_accept_category',
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain(
          'action_chat',
          'Chat',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.foreground,
          },
        ),
        DarwinNotificationAction.plain(
          'action_ignore',
          'Ignore',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.destructive,
          },
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    ),
    DarwinNotificationCategory(
      'plan_invite_category',
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain(
          'action_plan_accept',
          'Accept',
        ),
        DarwinNotificationAction.text(
          'action_plan_decline',
          'Decline',
          buttonTitle: 'Decline',
          placeholder: 'Reason for declining...',
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    ),
    DarwinNotificationCategory(
      'tribe_invite_category',
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain(
          'action_tribe_accept',
          'Accept',
        ),
        DarwinNotificationAction.plain(
          'action_tribe_decline',
          'Decline',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.destructive,
          },
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    ),
    DarwinNotificationCategory(
      'tribe_request_category',
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain(
          'action_tribe_accept',
          'Accept',
        ),
        DarwinNotificationAction.plain(
          'action_tribe_decline',
          'Decline',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.destructive,
          },
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    ),
  ];
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase safely
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print("Error initializing Firebase in background: $e");
  }

  // 2. Initialize flutter_local_notifications & register channel safely
  try {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final List<DarwinNotificationCategory> darwinNotificationCategories =
        buildDarwinNotificationCategories();

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      notificationCategories: darwinNotificationCategories,
    );
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveBackgroundNotificationResponse: onNotificationActionReceived,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(notificationChannel);
  } catch (e) {
    print("Error initializing local notifications in background: $e");
  }

  final data = message.data;
  final action = data['action'] as String?;
  final messageId = data['message_id'] as String?;

  print(
      "PushNotifications: Background message received. action: $action, message_id: $messageId");

  if (action == 'new_message') {
    final roomId = data['room_id'] as String?;
    final senderIdStr = data['sender_id'] as String?;
    final payload = data['payload'] as String?;

    if (messageId != null &&
        roomId != null &&
        senderIdStr != null &&
        payload != null) {
      final senderId = int.tryParse(senderIdStr);
      if (senderId != null) {
        // 1. Save to local SQLite safely
        try {
          await LocalDatabaseHelper.instance.insertMessage(
            messageId,
            roomId,
            senderId,
            payload,
            status: 'delivered',
          );
          print("PushNotifications: Background message saved to database.");
        } catch (e) {
          print(
              "PushNotifications: Error saving message to database in background: $e");
        }

        // 2. Add Missing Supabase Status Acknowledgment in the Background Handler
        try {
          final client =
              SupabaseClient(SupabaseConfig.url, SupabaseConfig.serviceRoleKey);
          await client
              .from('messages')
              .update({'status': 'delivered'}).eq('id', messageId);
          print(
              "PushNotifications: Background delivery status acknowledged in Supabase for $messageId.");
        } catch (e) {
          print(
              "PushNotifications: Error updating remote Supabase status in background: $e");
        }

        // 3. Show notification
        try {
          final activeUserId =
              await LocalDatabaseHelper.instance.getActiveUserId();
          if (activeUserId != null && senderId == activeUserId) {
            print(
                "PushNotifications: Received own message in background FCM. Ignoring notification.");
            return;
          }

          List<String> messageLines = [];
          bool isFallback = false;
          try {
            final unreadRows = await LocalDatabaseHelper.instance
                .getUnreadMessagesForRoomBySender(roomId, senderId);
            messageLines =
                unreadRows.map((r) => r['payload'] as String).toList();
            if (messageLines.isEmpty) {
              isFallback = true;
            }
          } catch (dbError) {
            print(
                "PushNotifications: Database read failed in background: $dbError");
            isFallback = true;
          }

          final senderName = data['sender_name'] as String? ?? 'New Message';
          if (isFallback) {
            await showLocalNotification(
              roomId, // Collapse by roomId so notifications stay in the same tray
              senderName,
              [payload],
              {
                'sender_id': senderIdStr,
                'room_id': roomId,
                'message_id': messageId,
                'sender_name': senderName,
              },
            );
            print(
                "PushNotifications: Background fallback notification displayed for roomId: $roomId.");
          } else {
            await showLocalNotification(
              roomId,
              senderName,
              messageLines,
              {
                'sender_id': senderIdStr,
                'room_id': roomId,
                'sender_name': senderName,
              },
            );
            print(
                "PushNotifications: Background local notification displayed with ${messageLines.length} lines.");
          }
        } catch (e) {
          print(
              "PushNotifications: Error showing local notification in background: $e");
        }
      }
    }
  } else if (action == 'delete_message') {
    if (messageId != null) {
      try {
        final localMsg =
            await LocalDatabaseHelper.instance.getMessageById(messageId);
        if (localMsg != null) {
          final roomId = localMsg['room_id'] as String?;
          final senderId = localMsg['sender_id'] as int?;

          // Delete from SQLite first
          final localStatus = localMsg['status'] as String?;
          if (localStatus != 'read') {
            await LocalDatabaseHelper.instance.deleteMessage(messageId);
            print("PushNotifications: Background message deleted from SQLite.");
          }

          // Rebuild or cancel the notification based on remaining unread messages
          if (roomId != null && senderId != null) {
            final remaining = await LocalDatabaseHelper.instance
                .getUnreadMessagesForRoomBySender(roomId, senderId);
            if (remaining.isEmpty) {
              await cancelLocalNotification(roomId);
              print(
                  "PushNotifications: Background notification cancelled — no remaining unread for room $roomId.");
            } else {
              final List<String> remainingLines =
                  remaining.map((r) => r['payload'] as String).toList();
              // We don't have the sender name in the background handler here,
              // so fetch it from the first remaining message's sender_id via a
              // simple title. The notification title stays unchanged since the
              // system reuses the existing tray slot.
              await showLocalNotification(
                roomId,
                'Message', // title — the existing tray slot keeps its original title
                remainingLines,
                {
                  'sender_id': senderId.toString(),
                  'room_id': roomId,
                },
              );
              print(
                  "PushNotifications: Background notification rebuilt with ${remainingLines.length} remaining messages.");
            }
          }
        }
      } catch (e) {
        print(
            "PushNotifications: Error handling background message delete: $e");
      }
    }
  } else if (action == 'tribe_message') {
    final tribeId = data['tribe_id']?.toString();
    final senderIdStr = data['sender_id']?.toString();
    final payload = data['payload']?.toString();
    final tribeName = data['tribe_name']?.toString() ?? 'Mafia';
    final senderName = data['sender_name']?.toString() ?? 'New Message';

    if (messageId != null &&
        tribeId != null &&
        senderIdStr != null &&
        payload != null) {
      final senderId = int.tryParse(senderIdStr);
      if (senderId != null) {
        try {
          final activeUserId =
              await LocalDatabaseHelper.instance.getActiveUserId();
          if (activeUserId != null && senderId == activeUserId) {
            print(
                "PushNotifications: Received own Mafia message in background. Ignoring.");
            return;
          }

          // Use tribeId for generating a stable notification ID
          final int notifId = getNotificationId(tribeId);

          // Track unread messages in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          final key = 'unread_tribe_messages_$tribeId';
          List<String> lines = prefs.getStringList(key) ?? [];
          lines.add("$senderName: $payload");
          await prefs.setStringList(key, lines);

          final count = lines.length;

          const AndroidNotificationChannel tribeChannel =
              AndroidNotificationChannel(
            'tribe_messages_channel',
            'Mafia Messages',
            description: 'Notifications for Mafia group chat messages',
            importance: Importance.max,
          );

          await flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(tribeChannel);

          final androidDetails = AndroidNotificationDetails(
            tribeChannel.id,
            tribeChannel.name,
            channelDescription: tribeChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            number: count,
            category: AndroidNotificationCategory.message,
            styleInformation: count > 1
                ? InboxStyleInformation(
                    lines,
                    contentTitle: "New Messages in $tribeName",
                    summaryText: '$count messages',
                  )
                : null,
            actions: [
              const AndroidNotificationAction(
                'action_tribe_reply',
                'Reply',
                inputs: [
                  AndroidNotificationActionInput(
                    label: 'Type message...',
                  ),
                ],
                allowGeneratedReplies: true,
              ),
            ],
          );

          final iosDetails = DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            threadIdentifier: tribeId,
            categoryIdentifier: 'tribe_message_category',
          );

          final details = NotificationDetails(
            android: androidDetails,
            iOS: iosDetails,
          );

          final Map<String, dynamic> fullPayload = {
            'action': 'tribe_message',
            'message_id': messageId,
            'tribe_id': tribeId,
            'tribe_name': tribeName,
            'sender_id': senderIdStr,
            'sender_name': senderName,
            'payload': payload,
            'is_connection_notification': false,
          };

          await flutterLocalNotificationsPlugin.show(
            id: notifId,
            title: count > 1
                ? "New Messages in $tribeName"
                : "New Message in $tribeName",
            body: count > 1 ? lines.last : "$senderName: $payload",
            notificationDetails: details,
            payload: jsonEncode(fullPayload),
          );
          print(
              "PushNotifications: Mafia message background notification displayed. ID: $notifId");
        } catch (e) {
          print(
              "PushNotifications: Error showing local Mafia notification in background: $e");
        }
      }
    }
  } else if (action == 'connection_notification' ||
      action == 'feed_notification') {
    if (message.notification != null) {
      print(
          "PushNotifications: System notification already presented by FCM OS. Skipping duplicate local notification.");
      return;
    }
    final notificationId =
        data['notification_id']?.toString() ?? data['id']?.toString();
    if (notificationId != null) {
      try {
        final client =
            SupabaseClient(SupabaseConfig.url, SupabaseConfig.serviceRoleKey);
        final notifRow = await client
            .from('connection_notifications')
            .select(
                '*, other_user:profiles!other_user_id(id, name, avatar_url, profession), referred_user:profiles!referred_user_id(id, name, avatar_url, profession)')
            .eq('id', notificationId)
            .maybeSingle();

        if (notifRow != null) {
          var type = notifRow['type']?.toString() ?? 'referral';
          final note = notifRow['note']?.toString();
          if (note != null && note.startsWith('{')) {
            try {
              final parsed = jsonDecode(note);
              if (parsed['real_type'] != null) {
                type = parsed['real_type'].toString();
              }
            } catch (_) {}
          }

          final actor = notifRow['other_user'] as Map<String, dynamic>? ?? {};
          final actorName = actor['name']?.toString() ?? 'Someone';
          final referred =
              notifRow['referred_user'] as Map<String, dynamic>? ?? {};
          final referredName = referred['name']?.toString() ?? 'Someone';

          String title = "New Connection";
          String body = "You have a new update.";

          if (type == "vip_pass_key") {
            title = "New Connection";
            body = "$actorName connected via Private Key";
          } else if (type == "referral_connect") {
            title = "New Connection";
            body = "$actorName connected via Referral";
          } else if (type == "referral") {
            final isRequest = note != null &&
                (note.startsWith("[REFERRAL_REQUEST]") ||
                    note.startsWith("[REFERRAL_REQUEST_ACTIONED]"));
            if (isRequest) {
              title = "Introduction Request";
              body = "$actorName asked to be introduced to $referredName";
            } else {
              title = "New Referral";
              body = "$actorName referred $referredName to you";
            }
          } else if (type == "plan_invite" ||
              type == "plan_update" ||
              type == "plan_reminder_30" ||
              type == "plan_reminder_start" ||
              type == "tribe_invite" ||
              type == "tribe_request" ||
              type == "tribe_approved" ||
              type == "tribe_message" ||
              type == "tribe_removed") {
            String planId = note ?? '';
            List<String> changedFields = [];
            if (note != null && note.startsWith('{')) {
              try {
                final parsed = jsonDecode(note);
                planId = parsed['plan_id']?.toString() ?? '';
                if (parsed['changed_fields'] is List) {
                  changedFields = List<String>.from(parsed['changed_fields']);
                }
              } catch (e) {
                print("Error parsing note JSON in background push: $e");
              }
            }

            String planTitle = "Plan";
            String startsAtText = "";
            if (planId.isNotEmpty) {
              try {
                final planRow = await client
                    .from('plans')
                    .select('title, starts_at')
                    .eq('id', planId)
                    .maybeSingle();
                if (planRow != null) {
                  if (planRow['title'] != null) {
                    planTitle = planRow['title'].toString();
                  }
                  final startsAtStr = planRow['starts_at'] as String?;
                  if (startsAtStr != null) {
                    try {
                      final dt = DateTime.parse(startsAtStr);
                      final diff = dt.difference(DateTime.now());
                      if (diff.isNegative) {
                        startsAtText = "now";
                      } else {
                        final days = diff.inDays;
                        final hours = diff.inHours % 24;
                        final minutes = diff.inMinutes % 60;
                        final seconds = diff.inSeconds % 60;

                        String pad(int n) => n.toString().padLeft(2, '0');

                        if (days > 0) {
                          startsAtText =
                              "in ${days}d:${pad(hours)}h:${pad(minutes)}m:${pad(seconds)}s";
                        } else if (hours > 0) {
                          startsAtText =
                              "in ${pad(hours)}h:${pad(minutes)}m:${pad(seconds)}s";
                        } else {
                          startsAtText = "in ${pad(minutes)}m:${pad(seconds)}s";
                        }
                      }
                    } catch (e) {
                      print("Error formatting starts_at: $e");
                    }
                  }
                }
              } catch (e) {
                print("Error fetching plan details for push: $e");
              }
            }
            if (type == "plan_invite") {
              title = "New Plan Invitation";
              body = "$actorName invited you to join \"$planTitle\"";
            } else if (type == "plan_update") {
              title = "Plan Updated";
              String changeDesc = "";
              if (changedFields.isNotEmpty) {
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
                final labels =
                    changedFields.map((f) => labelsMap[f] ?? f).toList();
                changeDesc = " (changed: ${labels.join(', ')})";
              }
              body = "$actorName updated the plan \"$planTitle\"$changeDesc";
            } else if (type == "plan_reminder_30") {
              title = "Upcoming Plan Reminder";
              final timeSuffix =
                  startsAtText.isNotEmpty ? " $startsAtText" : " in 30 minutes";
              body = "\"$planTitle\" starts$timeSuffix";
            } else if (type == "plan_reminder_start") {
              title = "Plan Starting Now";
              body = "\"$planTitle\" is starting now!";
            } else if (type == "tribe_added") {
              String tribeName = "a Mafia";
              if (note != null && note.startsWith('{')) {
                try {
                  final parsed = jsonDecode(note);
                  tribeName = parsed['tribe_name']?.toString() ?? "a Mafia";
                } catch (_) {}
              }
              title = "Added to $tribeName";
              body = "$actorName added you to \"$tribeName\"";
            } else if (type == "tribe_invite") {
              String tribeName = "a Mafia";
              if (note != null && note.startsWith('{')) {
                try {
                  final parsed = jsonDecode(note);
                  tribeName = parsed['tribe_name']?.toString() ?? "a Mafia";
                } catch (_) {}
              }
              title = "Mafia Invitation";
              body = "$actorName invited you to join \"$tribeName\"";
            } else if (type == "tribe_request") {
              String tribeName = "a Mafia";
              if (note != null && note.startsWith('{')) {
                try {
                  final parsed = jsonDecode(note);
                  tribeName = parsed['tribe_name']?.toString() ?? "a Mafia";
                } catch (_) {}
              }
              title = "Mafia Request";
              body = "$actorName requested to join \"$tribeName\"";
            } else if (type == "tribe_approved") {
              String tribeName = "a Mafia";
              if (note != null && note.startsWith('{')) {
                try {
                  final parsed = jsonDecode(note);
                  tribeName = parsed['tribe_name']?.toString() ?? "a Mafia";
                } catch (_) {}
              }
              title = "Mafia Approved";
              body = "Your request to join \"$tribeName\" was approved";
            } else if (type == "tribe_message") {
              String tribeName = "Mafia";
              String message = "";
              if (note != null && note.startsWith('{')) {
                try {
                  final parsed = jsonDecode(note);
                  tribeName = parsed['tribe_name']?.toString() ?? "Mafia";
                  message = parsed['message']?.toString() ?? "";
                } catch (_) {}
              }
              title = "New Message in $tribeName";
              body = "$actorName: $message";
            } else if (type == "tribe_removed") {
              String tribeName = "a Mafia";
              if (note != null && note.startsWith('{')) {
                try {
                  final parsed = jsonDecode(note);
                  tribeName = parsed['tribe_name']?.toString() ?? "a Mafia";
                } catch (_) {}
              }
              title = "Removed from Mafia";
              body = "You were removed from \"$tribeName\"";
            } else if (type == "feed_reply_mention") {
              title = "New Reply & Mention";
              body =
                  "$actorName replied to your post and mentioned you on their post.";
            } else if (type == "feed_reply") {
              title = "New Reply";
              body = "$actorName replied to your post.";
            } else if (type == "feed_mention") {
              title = "New Mention";
              body = "$actorName mentioned you on their post.";
            } else if (type == "feed_post") {
              title = "New Post";
              body = "$actorName shared a new post with your network.";
            } else if (type == "feed_connection_reply") {
              String parentAuthorName = "a post";
              if (note != null && note.startsWith('{')) {
                try {
                  final parsed = jsonDecode(note);
                  parentAuthorName = parsed['parent_author_name']?.toString() ?? "a post";
                } catch (_) {}
              }
              title = "$actorName joined a conversation";
              body = "$actorName replied to $parentAuthorName, tap to join the conversation.";
            }
          } else {
            title = "New Connection";
            body = "$actorName connected with you";
          }

          await showConnectionLocalNotification(
            notificationId: notificationId,
            type: type,
            title: title,
            body: body,
            dataPayload: notifRow,
          );
        }
      } catch (e) {
        print(
            "PushNotifications: Error handling background connection_notification: $e");
      }
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Explicitly configure native AudioSession via audio_session package to mix with other apps
  try {
    final audioSession = await session.AudioSession.instance;
    await audioSession.configure(session.AudioSessionConfiguration(
      avAudioSessionCategory: session.AVAudioSessionCategory.ambient,
      avAudioSessionCategoryOptions:
          session.AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: session.AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy:
          session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
      androidAudioAttributes: const session.AndroidAudioAttributes(
        contentType: session.AndroidAudioContentType.sonification,
        usage: session.AndroidAudioUsage.assistanceSonification,
      ),
      androidAudioFocusGainType:
          session.AndroidAudioFocusGainType.gainTransientMayDuck,
    ));
    print("AudioSession: Configured native ambient mixing successfully.");
  } catch (e) {
    print("AudioSession: Error configuring native audio session: $e");
  }

  tz_latest.initializeTimeZones();
  try {
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    final timeZoneName = timezoneInfo.identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    print("Timezone: Local location set to $timeZoneName");
  } catch (e) {
    print("Timezone: Error setting local timezone location: $e");
    // Fallback to UTC if device timezone lookup fails
    try {
      tz.setLocalLocation(tz.getLocation('UTC'));
    } catch (_) {}
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.serviceRoleKey,
    // authCallbackUrlScheme: 'connectapp',
  );

  // Initialize Linkrunner SDK for deferred deep linking & referrals
  await LinkrunnerService.initialize();

  // Initialize flutter_local_notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final List<DarwinNotificationCategory> darwinNotificationCategories =
      buildDarwinNotificationCategories();

  final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    notificationCategories: darwinNotificationCategories,
  );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.actionId != null) {
        onNotificationActionReceived(response);
        return;
      }
      final payload = response.payload;
      if (payload != null) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          handleLocalNotificationClickPayload(payload);
        } else {
          pendingNotificationPayload = payload;
          try {
            final data = jsonDecode(payload);
            final action = data['action'] as String?;
            if (action == 'tribe_message' ||
                action == 'tribe_added' ||
                data['real_type'] == 'tribe_added') {
              targetTribeChatId = data['tribe_id']?.toString();
              targetTribeName = data['tribe_name']?.toString() ?? 'Mafia';
            } else if (action == 'connection_notification') {
              targetOpenNotificationsPage = true;
            } else {
              final senderIdStr = data['sender_id'] as String?;
              if (senderIdStr != null) {
                targetChatSenderId = int.tryParse(senderIdStr);
              }
            }
          } catch (e) {
            print("Error parsing local notification payload on startup: $e");
          }
        }
      }
    },
    onDidReceiveBackgroundNotificationResponse: onNotificationActionReceived,
  );

  // Explicitly create the Android notification channel
  try {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(notificationChannel);
  } catch (e) {
    print("Error creating notification channel on startup: $e");
  }

  // Check for initial launch notification
  try {
    final localDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (localDetails?.didNotificationLaunchApp ?? false) {
      final localPayload = localDetails?.notificationResponse?.payload;
      if (localPayload != null) {
        try {
          final data = jsonDecode(localPayload);
          final action = data['action'] as String?;
          if (action == 'tribe_message' ||
              action == 'tribe_added' ||
              data['real_type'] == 'tribe_added') {
            targetTribeChatId = data['tribe_id']?.toString();
            targetTribeName = data['tribe_name']?.toString() ?? 'Mafia';
          } else if (action == 'connection_notification') {
            targetOpenNotificationsPage = true;
          } else {
            final senderIdStr = data['sender_id'] as String?;
            if (senderIdStr != null) {
              targetChatSenderId = int.tryParse(senderIdStr);
            }
          }
        } catch (e) {
          print("Error parsing local notification payload on startup: $e");
        }
      }
    }

    final fcmMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (fcmMessage != null) {
      final data = fcmMessage.data;
      final action = data['action'] as String?;
      if (action == 'tribe_message' ||
          action == 'tribe_added' ||
          data['real_type'] == 'tribe_added') {
        targetTribeChatId = data['tribe_id']?.toString();
        targetTribeName = data['tribe_name']?.toString() ?? 'Mafia';
      } else if (action == 'connection_notification') {
        targetOpenNotificationsPage = true;
      } else {
        final senderIdStr = data['sender_id'] as String?;
        if (senderIdStr != null) {
          targetChatSenderId = int.tryParse(senderIdStr);
        }
      }
    }
  } catch (e) {
    print("Error checking launch notifications in main(): $e");
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(
            profileRepository: SupabaseProfileRepository(),
          )
            ..loadBackgroundBlurPref()
            ..loadDefaultCardVisibilityPref(),
        ),
        ChangeNotifierProxyProvider<ProfileProvider, PlansProvider>(
          create: (_) => PlansProvider(
            plansRepository: SupabasePlansRepository(),
          ),
          update: (_, profileProvider, plansProvider) {
            plansProvider!.updateUserId(profileProvider.userId);
            return plansProvider;
          },
        ),
        ChangeNotifierProxyProvider<ProfileProvider, ConnectionProvider>(
          create: (_) => ConnectionProvider(
            connectionRepository: SupabaseConnectionRepository(),
            notificationRepository: SupabaseNotificationRepository(),
          ),
          update: (_, profileProvider, connectionProvider) {
            connectionProvider!.updateUserId(profileProvider.userId);
            return connectionProvider;
          },
        ),
        ChangeNotifierProxyProvider<ProfileProvider, NotificationProvider>(
          create: (_) => NotificationProvider(
            notificationRepository: SupabaseNotificationRepository(),
          ),
          update: (_, profileProvider, notificationProvider) {
            notificationProvider!.updateUserId(profileProvider.userId);
            return notificationProvider;
          },
        ),
        ChangeNotifierProxyProvider2<ProfileProvider, ConnectionProvider,
            ChatProvider>(
          create: (_) => ChatProvider(
            chatRepository: SupabaseChatRepository(
              localDb: LocalDatabaseHelper.instance,
            ),
          ),
          update: (_, profileProvider, connectionProvider, chatProvider) {
            chatProvider!.updateFromProviders(
              profileProvider.userId,
              connectionProvider.connections,
            );
            return chatProvider;
          },
        ),
        ChangeNotifierProxyProvider<ConnectionProvider, NetworkProvider>(
          create: (_) => NetworkProvider(
            networkRepository: SupabaseNetworkRepository(),
          ),
          update: (_, connectionProvider, networkProvider) {
            networkProvider!.updateFromConnectionProvider(
              connectionProvider.userId,
              connectionProvider.connections.length,
              connectionProvider.state is UserConnectionLoaded,
            );
            return networkProvider;
          },
        ),
        ChangeNotifierProxyProvider<ProfileProvider, TribeProvider>(
          create: (_) => TribeProvider(
            tribeRepository: SupabaseTribeRepository(),
            notificationRepository: SupabaseNotificationRepository(),
          ),
          update: (_, profileProvider, tribeProvider) {
            tribeProvider!.updateUserId(profileProvider.userId);
            return tribeProvider;
          },
        ),
        ChangeNotifierProxyProvider2<ProfileProvider, ConnectionProvider,
            PulseProvider>(
          create: (_) => PulseProvider(
            pulseRepository: SupabasePulseRepository(),
          ),
          update: (_, profileProvider, connectionProvider, pulseProvider) {
            pulseProvider!.updateFromProviders(
              profileProvider.userId,
              connectionProvider.connections,
            );
            return pulseProvider;
          },
        ),
        ChangeNotifierProxyProvider<ProfileProvider, FeedProvider>(
          create: (_) => FeedProvider(
            repository: SupabaseFeedRepository(),
          ),
          update: (_, profileProvider, feedProvider) {
            feedProvider!.updateViewerId(profileProvider.userId);
            return feedProvider;
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        builder: (context, child) {
          return Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: context.ambientCanvasGradient,
                  ),
                ),
              ),
              if (child != null) Positioned.fill(child: child),
            ],
          );
        },
        onGenerateRoute: (settings) {
          if (settings.name != null) {
            final name = settings.name!;
            final isAuthCallback = (name.startsWith('/login-callback') ||
                    name.contains('code=')) &&
                !name.contains('referrer=') &&
                !name.contains('MNDL-') &&
                !name.contains('invite_code=');

            if (isAuthCallback) {
              return MaterialPageRoute(
                builder: (context) => Scaffold(
                  backgroundColor: context.canvasBackground,
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(context.accentPrimary),
                    ),
                  ),
                ),
              );
            }

            // Absorb referral / invite deep link routes silently.
            // The link params are already handled by LinkrunnerService & ShareReceiverService.
            if (name.contains('referrer=') ||
                name.contains('MNDL-') ||
                name.contains('invite_code=')) {
              // Both warm start and cold start: absorb the deep link route silently.
              // LinkrunnerService has already extracted and saved the URL params.
              // The home AuthGate handles auth → AppShellGate → referral modal flow.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                navigatorKey.currentState?.maybePop();
              });
              return MaterialPageRoute(
                builder: (_) => const SizedBox.shrink(),
                settings: settings,
              );
            }
          }
          return null;
        },
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Stable key so Flutter reuses the same AppShellGate across StreamBuilder rebuilds.
  final GlobalKey _appShellGateKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: context.canvasBackground,
            body: Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(context.accentPrimary),
              ),
            ),
          );
        }

        final currentSession = Supabase.instance.client.auth.currentSession;
        final session = snapshot.data?.session ?? currentSession;
        final event = snapshot.data?.event;

        if (session != null) {
          AnalyticsService.setUserId(session.user.id);
        } else {
          AnalyticsService.setUserId(null);
        }

        if (event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordScreen();
        }

        if (session != null) {
          return AppShellGate(key: _appShellGateKey);
        }

        final profileProvider =
            Provider.of<ProfileProvider>(context, listen: false);
        final initialIsSignIn = !profileProvider.showSignUpNext;
        profileProvider.showSignUpNext = false;

        return AuthScreen(initialIsSignIn: initialIsSignIn);
      },
    );
  }
}

class AppShellGate extends StatefulWidget {
  const AppShellGate({super.key});

  @override
  State<AppShellGate> createState() => _AppShellGateState();
}

class _AppShellGateState extends State<AppShellGate> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initUser();
    });
  }

  Future<void> _initUser() async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    try {
      // Step 1: Ensure a profile row exists (creates default if brand new user).
      // This also sets profileProvider.userId internally — no second call needed.
      await profileProvider.ensureProfileExists();

      final userId = profileProvider.userId;

      if (userId != null) {
        // Step 2: Load full profile fields (name, email, phone, etc.)
        await profileProvider.loadProfile(userId);
        await connectionProvider.fetchConnections();

        AnalyticsService.setUserProperties(
          connectionCount: connectionProvider.connections.length,
          profileCompletionPct: profileProvider.profileCompletionPct,
        );
      }

      // ── Show the UI immediately after profile data is ready ──
      // Chat rooms, push tokens, and unread counts load in the background.
      if (mounted) setState(() => _initialized = true);

      // App has fully booted and UI is rendered! Now run referral invite check safely.
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            LinkrunnerService.consumeWasColdStartDeepLink();
            ReferralConnectionModal.checkAndShowPrompt(
              context,
              isExplicitLinkClick: true,
            );
          }
        });
      }

      if (targetOpenNotificationsPage) {
        targetOpenNotificationsPage = false;
        pendingNotificationPayload = null;

        navigatorKey.currentState?.push(
          PageRouteBuilder(
            pageBuilder: (context, anim, secAnim) => const NotificationPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      } else if (targetTribeChatId != null) {
        final tribeId = targetTribeChatId!;
        final tribeName = targetTribeName ?? 'Mafia';
        targetTribeChatId = null;
        targetTribeName = null;
        pendingNotificationPayload = null;

        navigatorKey.currentState?.push(
          PageRouteBuilder(
            pageBuilder: (context, anim, secAnim) =>
                TribeChatPage(tribeId: tribeId, tribeName: tribeName),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      } else if (targetChatSenderId != null) {
        final targetId = targetChatSenderId!;
        targetChatSenderId = null;
        pendingNotificationPayload = null;

        navigatorKey.currentState?.push(
          PageRouteBuilder(
            pageBuilder: (context, anim, secAnim) =>
                IndividualChatPage(otherUserId: targetId),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }

      // Step 3 (background): Load chat + notifications without blocking the UI.
      if (userId != null) {
        Future.microtask(() async {
          await chatProvider.loadChatRooms();
          if (mounted) await _setupPushNotifications(chatProvider);
          await chatProvider.updateUnreadCount();
        });
      }
    } catch (e) {
      print("Error in AppShellGate initialization: $e");
    } finally {
      // Safety net: always show the UI even if something threw.
      if (mounted && !_initialized) {
        setState(() => _initialized = true);
      }
    }
  }

  Future<void> _setupPushNotifications(ChatProvider provider) async {
    print("PushNotifications: Initializing...");
    try {
      final messaging = FirebaseMessaging.instance;

      // Request notification permissions for Android 13+ and iOS
      print("PushNotifications: Requesting permission...");
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print(
          "PushNotifications: Authorization status is ${settings.authorizationStatus}");

      // Disable automatic system-level foreground notification presentation.
      // We manually control notification display via showLocalNotification()
      // inside the onMessage handler. Leaving these enabled causes duplicate
      // notifications on certain Android OEM skins and iOS.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      // Fetch the token (FCM can generate tokens on Android even if notification permission is denied)
      print("PushNotifications: Fetching FCM token...");
      try {
        String? token;
        if (Platform.isIOS) {
          int retries = 0;
          while (retries < 5) {
            final apnsToken = await messaging.getAPNSToken();
            if (apnsToken != null) break;
            await Future.delayed(const Duration(milliseconds: 1000));
            retries++;
          }
          token = await messaging.getToken();
        } else {
          token = await messaging.getToken();
        }

        if (token != null) {
          print("PushNotifications: FCM token retrieved successfully: $token");
          await provider.updatePushToken(token);
        } else {
          print("PushNotifications: FCM token is null.");
        }
      } catch (e) {
        print("PushNotifications: Error retrieving initial FCM token: $e");
      }

      // Listen for token updates and upsert them
      messaging.onTokenRefresh.listen((newToken) async {
        print("PushNotifications: FCM token refreshed: $newToken");
        await provider.updatePushToken(newToken);
      });

      // Request permission for local notifications (needed for Android 13+ and iOS)
      if (Platform.isIOS) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      } else if (Platform.isAndroid) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      // Listen to foreground FCM messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        print(
            "PushNotifications: Foreground message received: ${message.messageId}");
        try {
          final data = message.data;
          final action = data['action'] as String?;
          final messageId = data['message_id'] as String?;

          if (action == 'new_message') {
            final roomId = data['room_id'] as String?;
            final senderIdStr = data['sender_id'] as String?;
            final senderName = data['sender_name'] as String? ?? 'New Message';
            final payload = data['payload'] as String?;

            if (messageId != null &&
                roomId != null &&
                senderIdStr != null &&
                payload != null) {
              final senderId = int.tryParse(senderIdStr);
              if (senderId != null) {
                // 1. Save to local SQLite
                final isCurrentRoom = provider.activeRoomId == roomId;
                try {
                  await LocalDatabaseHelper.instance.insertMessage(
                    messageId,
                    roomId,
                    senderId,
                    payload,
                    status: isCurrentRoom ? 'read' : 'delivered',
                  );
                  print(
                      "PushNotifications: Foreground message inserted to SQLite.");
                } catch (e) {
                  print(
                      "PushNotifications: Error inserting message in foreground SQLite: $e");
                }

                // 2. Acknowledge delivery
                try {
                  await provider.acknowledgeDelivery(messageId,
                      isActiveInChat: isCurrentRoom);
                  print(
                      "PushNotifications: Foreground message delivery status updated in Supabase via provider.");
                } catch (e) {
                  print(
                      "PushNotifications: Error acknowledging delivery in foreground: $e");
                }

                // 3. Update providers so UI updates immediately
                try {
                  await provider.updateLastMessageForRoom(roomId);
                  await provider.refreshActiveRoomMessages();
                  await provider.updateUnreadCount();
                } catch (e) {
                  print("PushNotifications: Error updating providers: $e");
                }

                // 4. Show notification ONLY if the user is NOT actively in the chat room
                if (!isCurrentRoom) {
                  try {
                    final activeUserId =
                        await LocalDatabaseHelper.instance.getActiveUserId();
                    if (activeUserId == null || senderId != activeUserId) {
                      showInAppMessageBanner(
                        messageId: messageId,
                        roomId: roomId,
                        senderId: senderId,
                        senderName: senderName,
                        avatarUrl: data['sender_avatar']?.toString() ?? '',
                        message: payload,
                      );
                    }
                  } catch (e) {
                    print(
                        "PushNotifications: Error showing in-app notification banner in foreground: $e");
                  }
                }
              }
            }
          } else if (action == 'delete_message') {
            if (messageId != null) {
              try {
                final localMsg = await LocalDatabaseHelper.instance
                    .getMessageById(messageId);
                if (localMsg != null) {
                  final roomId = localMsg['room_id'] as String?;
                  final senderId = localMsg['sender_id'] as int?;
                  final activeUserId =
                      await LocalDatabaseHelper.instance.getActiveUserId();

                  if (senderId != null &&
                      activeUserId != null &&
                      senderId == activeUserId) {
                    // Outgoing message sent by me: deletion from Supabase store-and-forward means recipient read it!
                    await LocalDatabaseHelper.instance
                        .updateMessageStatus(messageId, 'read');
                    print(
                        "PushNotifications: Foreground outgoing message updated to read in SQLite.");
                  } else {
                    final localStatus = localMsg['status'] as String?;
                    if (localStatus != 'read') {
                      await LocalDatabaseHelper.instance
                          .deleteMessage(messageId);
                      print(
                          "PushNotifications: Foreground message deleted from SQLite.");
                    }
                  }

                  // Rebuild or cancel the notification based on remaining unread messages
                  if (roomId != null && senderId != null) {
                    final remaining = await LocalDatabaseHelper.instance
                        .getUnreadMessagesForRoomBySender(roomId, senderId);
                    if (remaining.isEmpty) {
                      await cancelLocalNotification(roomId);
                      print(
                          "PushNotifications: Foreground notification cancelled — no remaining unread for room $roomId.");
                    } else {
                      final List<String> remainingLines =
                          remaining.map((r) => r['payload'] as String).toList();
                      final senderName =
                          data['sender_name'] as String? ?? 'Message';
                      await showLocalNotification(
                        roomId,
                        senderName,
                        remainingLines,
                        {
                          'sender_id': senderId.toString(),
                          'room_id': roomId,
                        },
                      );
                      print(
                          "PushNotifications: Foreground notification rebuilt with ${remainingLines.length} remaining messages.");
                    }
                  }
                }
              } catch (e) {
                print(
                    "PushNotifications: Error handling foreground message delete: $e");
              }

              // Update providers so UI updates
              try {
                await provider.refreshActiveRoomMessages();
                await provider.updateUnreadCount();
              } catch (e) {
                print(
                    "PushNotifications: Error updating providers after delete: $e");
              }
            }
          } else if (action == 'tribe_message') {
            final tribeId = data['tribe_id']?.toString();
            final senderIdStr = data['sender_id']?.toString();
            final payload = data['payload']?.toString();
            final tribeName = data['tribe_name']?.toString() ?? 'Mafia';
            final senderName = data['sender_name']?.toString() ?? 'New Message';
            final senderAvatar = data['sender_avatar']?.toString() ?? '';

            if (messageId != null &&
                tribeId != null &&
                senderIdStr != null &&
                payload != null) {
              final senderId = int.tryParse(senderIdStr);
              if (senderId != null) {
                if (!mounted) return;
                final tribeProvider =
                    Provider.of<TribeProvider>(context, listen: false);
                final isCurrentTribe = tribeProvider.activeTribeId == tribeId;

                if (!isCurrentTribe) {
                  try {
                    final activeUserId =
                        await LocalDatabaseHelper.instance.getActiveUserId();
                    if (activeUserId != null && senderId == activeUserId) {
                      print(
                          "PushNotifications: Foreground received own Mafia message. Skipping banner.");
                      return;
                    }

                    final overlayState = navigatorKey.currentState?.overlay;
                    if (overlayState != null) {
                      InAppNotificationBanner.show(
                        overlayState: overlayState,
                        senderId: senderId,
                        senderName: "New Message in $tribeName",
                        avatarUrl: senderAvatar,
                        message: "$senderName: $payload",
                        onTap: () {
                          navigatorKey.currentState?.push(
                            MaterialPageRoute(
                              builder: (routeContext) => TribeChatPage(
                                  tribeId: tribeId, tribeName: tribeName),
                            ),
                          );
                        },
                      );
                      print(
                          "PushNotifications: Foreground in-app Mafia notification banner displayed.");
                    }
                  } catch (e) {
                    print(
                        "PushNotifications: Error showing in-app Mafia banner: $e");
                  }
                }
              }
            }
          } else if (action == 'connection_notification') {
            final notificationId =
                data['notification_id']?.toString() ?? data['id']?.toString();
            if (notificationId != null) {
              try {
                final client = SupabaseClient(
                    SupabaseConfig.url, SupabaseConfig.serviceRoleKey);
                final notifRow = await client
                    .from('connection_notifications')
                    .select(
                        '*, other_user:profiles!other_user_id(id, name, avatar_url, profession), referred_user:profiles!referred_user_id(id, name, avatar_url, profession)')
                    .eq('id', notificationId)
                    .maybeSingle();

                if (notifRow != null) {
                  var type = notifRow['type']?.toString() ?? 'referral';
                  final note = notifRow['note']?.toString();
                  if (note != null && note.startsWith('{')) {
                    try {
                      final parsed = jsonDecode(note);
                      if (parsed['real_type'] != null) {
                        type = parsed['real_type'].toString();
                      }
                    } catch (_) {}
                  }

                  final actor =
                      notifRow['other_user'] as Map<String, dynamic>? ?? {};
                  final actorName = actor['name']?.toString() ?? 'Someone';
                  final actorAvatar = actor['avatar_url']?.toString() ?? '';
                  final actorId = actor['id'] as int? ?? 0;
                  final referred =
                      notifRow['referred_user'] as Map<String, dynamic>? ?? {};
                  final referredName =
                      referred['name']?.toString() ?? 'Someone';

                  String title = "New Connection";
                  String body = "You have a new update.";

                  if (type == "vip_pass_key") {
                    title = "New Connection";
                    body = "$actorName connected via Private Key";
                  } else if (type == "referral_connect") {
                    title = "New Connection";
                    body = "$actorName connected via Referral";
                  } else if (type == "referral") {
                    final isRequest = note != null &&
                        (note.startsWith("[REFERRAL_REQUEST]") ||
                            note.startsWith("[REFERRAL_REQUEST_ACTIONED]"));
                    if (isRequest) {
                      title = "Introduction Request";
                      body =
                          "$actorName asked to be introduced to $referredName";
                    } else {
                      title = "New Referral";
                      body = "$actorName referred $referredName to you";
                    }
                  } else if (type == "plan_invite" ||
                      type == "plan_update" ||
                      type == "plan_reminder_30" ||
                      type == "plan_reminder_start" ||
                      type == "tribe_invite" ||
                      type == "tribe_request" ||
                      type == "tribe_approved" ||
                      type == "tribe_message" ||
                      type == "tribe_removed") {
                    String planId = note ?? '';
                    List<String> changedFields = [];
                    if (note != null && note.startsWith('{')) {
                      try {
                        final parsed = jsonDecode(note);
                        planId = parsed['plan_id']?.toString() ?? '';
                        if (parsed['changed_fields'] is List) {
                          changedFields =
                              List<String>.from(parsed['changed_fields']);
                        }
                      } catch (e) {
                        print("Error parsing note JSON in foreground push: $e");
                      }
                    }

                    String planTitle = "Plan";
                    String startsAtText = "";
                    if (planId.isNotEmpty) {
                      try {
                        final planRow = await client
                            .from('plans')
                            .select('title, starts_at')
                            .eq('id', planId)
                            .maybeSingle();
                        if (planRow != null) {
                          if (planRow['title'] != null) {
                            planTitle = planRow['title'].toString();
                          }
                          final startsAtStr = planRow['starts_at'] as String?;
                          if (startsAtStr != null) {
                            try {
                              final dt = DateTime.parse(startsAtStr);
                              final diff = dt.difference(DateTime.now());
                              if (diff.isNegative) {
                                startsAtText = "now";
                              } else {
                                final days = diff.inDays;
                                final hours = diff.inHours % 24;
                                final minutes = diff.inMinutes % 60;
                                final seconds = diff.inSeconds % 60;

                                String pad(int n) =>
                                    n.toString().padLeft(2, '0');

                                if (days > 0) {
                                  startsAtText =
                                      "in ${days}d:${pad(hours)}h:${pad(minutes)}m:${pad(seconds)}s";
                                } else if (hours > 0) {
                                  startsAtText =
                                      "in ${pad(hours)}h:${pad(minutes)}m:${pad(seconds)}s";
                                } else {
                                  startsAtText =
                                      "in ${pad(minutes)}m:${pad(seconds)}s";
                                }
                              }
                            } catch (e) {
                              print("Error formatting starts_at: $e");
                            }
                          }
                        }
                      } catch (e) {
                        print("Error fetching plan details for push: $e");
                      }
                    }
                    if (type == "plan_invite") {
                      title = "New Plan Invitation";
                      body = "$actorName invited you to join \"$planTitle\"";
                    } else if (type == "plan_update") {
                      title = "Plan Updated";
                      String changeDesc = "";
                      if (changedFields.isNotEmpty) {
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
                        final labels = changedFields
                            .map((f) => labelsMap[f] ?? f)
                            .toList();
                        changeDesc = " (changed: ${labels.join(', ')})";
                      }
                      body =
                          "$actorName updated the plan \"$planTitle\"$changeDesc";
                    } else if (type == "plan_reminder_30") {
                      title = "Upcoming Plan Reminder";
                      final timeSuffix = startsAtText.isNotEmpty
                          ? " $startsAtText"
                          : " in 30 minutes";
                      body = "\"$planTitle\" starts$timeSuffix";
                    } else if (type == "plan_reminder_start") {
                      title = "Plan Starting Now";
                      body = "\"$planTitle\" is starting now!";
                    } else if (type == "tribe_invite") {
                      String tribeName = "a Mafia";
                      if (note != null && note.startsWith('{')) {
                        try {
                          final parsed = jsonDecode(note);
                          tribeName =
                              parsed['tribe_name']?.toString() ?? "a Mafia";
                        } catch (_) {}
                      }
                      title = "Mafia Invitation";
                      body = "$actorName invited you to join \"$tribeName\"";
                    } else if (type == "tribe_message") {
                      String tribeName = "Mafia";
                      String message = "";
                      if (note != null && note.startsWith('{')) {
                        try {
                          final parsed = jsonDecode(note);
                          tribeName =
                              parsed['tribe_name']?.toString() ?? "Mafia";
                          message = parsed['message']?.toString() ?? "";
                        } catch (_) {}
                      }
                      title = "New Message in $tribeName";
                      body = "$actorName: $message";
                    } else if (type == "tribe_removed") {
                      String tribeName = "a Mafia";
                      if (note != null && note.startsWith('{')) {
                        try {
                          final parsed = jsonDecode(note);
                          tribeName =
                              parsed['tribe_name']?.toString() ?? "a Mafia";
                        } catch (_) {}
                      }
                      title = "Removed from Mafia";
                      body = "You were removed from \"$tribeName\"";
                    } else if (type == "tribe_request") {
                      String tribeName = "a Mafia";
                      if (note != null && note.startsWith('{')) {
                        try {
                          final parsed = jsonDecode(note);
                          tribeName =
                              parsed['tribe_name']?.toString() ?? "a Mafia";
                        } catch (_) {}
                      }
                      title = "Mafia Request";
                      body = "$actorName requested to join \"$tribeName\"";
                    } else if (type == "tribe_approved") {
                      String tribeName = "a Mafia";
                      if (note != null && note.startsWith('{')) {
                        try {
                          final parsed = jsonDecode(note);
                          tribeName =
                              parsed['tribe_name']?.toString() ?? "a Mafia";
                        } catch (_) {}
                      }
                      title = "Mafia Approved";
                      body = "Your request to join \"$tribeName\" was approved";
                    } else if (type == "feed_reply_mention") {
                      title = "New Reply & Mention";
                      body =
                          "$actorName replied to your post and mentioned you on their post.";
                    } else if (type == "feed_reply") {
                      title = "New Reply";
                      body = "$actorName replied to your post.";
                    } else if (type == "feed_mention") {
                      title = "New Mention";
                      body = "$actorName mentioned you on their post.";
                    } else if (type == "feed_post") {
                      title = "New Post";
                      body = "$actorName shared a new post with your network.";
                    } else if (type == "feed_connection_reply") {
                      String parentAuthorName = "a post";
                      if (note != null && note.startsWith('{')) {
                        try {
                          final parsed = jsonDecode(note);
                          parentAuthorName = parsed['parent_author_name']?.toString() ?? "a post";
                        } catch (_) {}
                      }
                      title = "$actorName joined a conversation";
                      body = "$actorName replied to $parentAuthorName, tap to join the conversation.";
                    }
                  } else {
                    title = "New Connection";
                    body = "$actorName connected with you";
                  }

                  final overlayState = navigatorKey.currentState?.overlay;
                  if (overlayState != null) {
                    InAppNotificationBanner.show(
                      overlayState: overlayState,
                      senderId: actorId,
                      senderName: title,
                      avatarUrl: actorAvatar,
                      message: body,
                      onTap: () {
                        navigatorKey.currentState?.push(
                          MaterialPageRoute(
                            builder: (routeContext) => const NotificationPage(),
                          ),
                        );
                      },
                    );
                    print(
                        "PushNotifications: Foreground connection notification banner displayed.");
                  }
                }
              } catch (e) {
                print(
                    "PushNotifications: Error showing foreground connection_notification: $e");
              }
            }
          } else if (action == 'feed_notification') {
            final actorAvatar = data['actor_avatar']?.toString() ?? '';
            final title = data['title']?.toString() ?? 'Network Feed Update';
            final body = data['body']?.toString() ?? '';
            final rootPostId = data['root_post_id']?.toString() ??
                data['post_id']?.toString() ??
                '';
            final postId = data['post_id']?.toString() ?? '';

            final overlayState = navigatorKey.currentState?.overlay;
            if (overlayState != null && rootPostId.isNotEmpty) {
              InAppNotificationBanner.show(
                overlayState: overlayState,
                senderId: 0,
                senderName: title,
                avatarUrl: actorAvatar,
                message: body,
                onTap: () {
                  appShellKey.currentState?.setSelectedIndex(0);
                  navigatorKey.currentState?.popUntil((route) => route.isFirst);
                  navigatorKey.currentState?.push(
                    MaterialPageRoute(
                      builder: (routeContext) => ThreadDetailPage(
                        rootPostId: rootPostId,
                        highlightPostId:
                            postId.isNotEmpty ? postId : rootPostId,
                      ),
                    ),
                  );
                },
              );
              print(
                  "PushNotifications: Foreground feed notification banner displayed.");
            }
          }
        } catch (e) {
          print("PushNotifications: Error in foreground message handler: $e");
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print(
            "PushNotifications: Notification tapped in background state: ${message.messageId}");
        handleLocalNotificationClickPayload(jsonEncode(message.data));
      });
    } catch (e) {
      print("PushNotifications: Error setting up push notifications: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        backgroundColor: context.canvasBackground,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(context.accentPrimary),
          ),
        ),
      );
    }
    return AppShell(key: appShellKey);
  }
}

final GlobalKey<AppShellState> appShellKey = GlobalKey<AppShellState>();

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  StreamSubscription? _shareSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      const CircleFeedPage(), // index 0 — Home (Circle Feed)
      const DirectMessagesHubPage(), // index 1 — Message (Chats)
      const OtherProfilesPage(), // index 2 — Mandal / Connections
      const YourNetworkPage(), // index 3 — Your Network
      const YetToBeBuiltProfilePage(), // index 4 — My Card
    ];
    _setupNotificationTapListeners();
    _initShareReceiver();
  }

  void _initShareReceiver() {
    ShareReceiverService.instance.init();
    _shareSubscription =
        ShareReceiverService.instance.onSharedContent.listen((content) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final String rawText = content.fullText;
        String? url = content.extractedUrl;

        final bool isInvite = rawText.contains('referrer=') ||
            rawText.contains('referrer_id=') ||
            rawText.contains('invite_code=') ||
            rawText.contains('MNDL-') ||
            (url != null &&
                (url.contains('referrer=') ||
                    url.contains('invite_code=') ||
                    url.contains('MNDL-')));

        final navContext = navigatorKey.currentContext;

        if (isInvite) {
          final String linkStr = url ?? rawText;
          final uri = Uri.tryParse(linkStr);
          if (uri != null) {
            final String? referrer = uri.queryParameters['referrer'] ??
                uri.queryParameters['referrer_id'] ??
                uri.queryParameters['sender_id'];
            final String? code = uri.queryParameters['invite_code'] ??
                uri.queryParameters['code'] ??
                uri.queryParameters['key'] ??
                uri.queryParameters['private_key'];
            if (referrer != null && referrer.isNotEmpty) {
              LinkrunnerService.savePendingReferrerId(referrer);
            }
            if (code != null && code.isNotEmpty) {
              LinkrunnerService.savePendingInviteCode(code);
            }
          }

          if (navContext != null && appShellKey.currentState != null) {
            ReferralConnectionModal.checkAndShowPrompt(
              navContext,
              isExplicitLinkClick: true,
            );
          }
          return;
        }

        setSelectedIndex(0);
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
        if (navContext != null) {
          // Extract URL and strip it from the text so the compose sheet
          // never receives the raw URL inside initialText.
          final urlRegex = RegExp(r'https?://\S+', caseSensitive: false);
          if (url == null || url.trim().isEmpty) {
            url = urlRegex.firstMatch(rawText)?.group(0);
          }
          final String cleanText = rawText.replaceAll(urlRegex, '').trim();

          CircleFeedPage.openComposeSheet(
            navContext,
            initialText: cleanText.isNotEmpty ? cleanText : null,
            initialUrl: url,
          );
        }
      });
    });
  }

  Future<void> _handleDismissProfileNudge() async {
    setState(() {
      _dismissedProfileNudge = true;
    });
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    await profileProvider.dismissProfileNudge();
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground — catch any status changes that happened
      // while the app was backgrounded or the Realtime socket was sleeping
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (profileProvider.userId != null) {
        chatProvider.syncOutgoingMessageStatuses();
        chatProvider.fetchPendingMessages();
      }
    }
  }

  void _setupNotificationTapListeners() {
    // Handle notification click when app is in background but still running
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });

    // Handle foreground message (when user is actively on the app during trigger time)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final action = message.data['action'] as String?;
      if (action == 'complete_profile') {
        if (mounted) {
          final profileProvider =
              Provider.of<ProfileProvider>(context, listen: false);
          profileProvider.resetNudgeDismissalLocal();
          setState(() {
            _dismissedProfileNudge = false;
          });
        }
      }
    });
  }

  void _handleNotificationClick(RemoteMessage message) {
    handleLocalNotificationClickPayload(jsonEncode(message.data));
  }

  void setSelectedIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  bool _dismissedProfileNudge = false;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.canvasBackground,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          Positioned(
            top: topPadding + 6,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              offset:
                  _dismissedProfileNudge ? const Offset(0, -1.2) : Offset.zero,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              child: AnimatedOpacity(
                opacity: _dismissedProfileNudge ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring: _dismissedProfileNudge,
                  child: ProfileNudgeBanner(
                    onOpenProfile: () {
                      setSelectedIndex(4);
                    },
                    onDismiss: _handleDismissProfileNudge,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildFloatingNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    if (isKeyboardOpen) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 10.0),
        child: Container(
          // Parent container holds the shadow so that ClipRRect does not clip it
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: GlassmorphicContainer(
            borderRadius: BorderRadius.circular(99),
            blurSigma: 15.0,
            glassColor: const Color(0xFF121316).withValues(alpha: 0.65),
            fallbackColor: const Color(0xFF121316),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
            child: SizedBox(
              height: 58,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(index: 0, icon: Icons.home_rounded),
                  _buildNavItem(
                      index: 1, icon: Icons.chat_bubble_outline_rounded),
                  _buildNavItem(index: 2, icon: Icons.people_outline_rounded),
                  _buildNavItem(index: 3, icon: Icons.search_rounded),
                  _buildNavItem(index: 4, icon: Icons.person_outline_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
  }) {
    final bool isActive = (_currentIndex == index);
    final Color itemColor = isActive ? Colors.white : const Color(0xFF8FA39E);
    final provider = Provider.of<ChatProvider>(context);
    final feedProvider = Provider.of<FeedProvider>(context);

    Widget iconWidget = Icon(
      icon,
      size: 24,
      color: itemColor,
    );

    // If it's the Message tab (index 1) and there are unread messages, overlay a red dot badge
    if (index == 1 && provider.totalUnreadCount > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444), // Vibrant Red
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    } else if (index == 0 && feedProvider.unseenCount > 0) {
      // If it's the Home / Circle Feed tab (index 0) and there are unseen posts, overlay an accent dot badge
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: context.accentPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    }

    return BounceTap(
      onTap: () {
        setState(() => _currentIndex = index);
      },
      scaleDown: 0.94,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 4),
            // Active state indicator dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? context.accentSecondary : Colors.transparent,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: context.accentPrimary.withValues(alpha: 0.8),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
