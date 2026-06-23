import 'dart:convert';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connect/firebase_options.dart';
import 'package:connect/Providers/LocalDatabaseHelper.dart';
import 'package:connect/Config/supabase_config.dart';
import 'package:connect/Pages/OtherProfilesPage.dart';
import 'package:connect/Pages/ProfilePage.dart';
import 'package:connect/Pages/DirectMessagesHubPage.dart';
import 'package:connect/Pages/yet_to_be_built_profile_page.dart';
import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:connect/Pages/MonkModePage.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/chat_provider.dart';
import 'package:connect/Repositories/profile_repository.dart';
import 'package:connect/Repositories/connection_repository.dart';
import 'package:connect/Repositories/chat_repository.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/Repositories/notification_repository.dart';
import 'package:connect/Providers/monk_mode_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:connect/Config/app_theme.dart';
import 'package:connect/Pages/AuthScreen.dart';
import 'package:connect/Pages/ResetPasswordScreen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
  final int count = messageLines.length;
  final String latestBody = messageLines.last;

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
        messageLines,
        contentTitle: title,
        summaryText: '$count new messages',
      ),
    );
  } else {
    androidNotificationDetails = const AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'Notifications for new messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
  }

  final DarwinNotificationDetails iosNotificationDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    threadIdentifier: roomId,
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

String? pendingNotificationPayload;
int? targetChatSenderId;

void handleLocalNotificationClickPayload(String payload) {
  try {
    final data = jsonDecode(payload);
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

Future<bool> _isUserMutedUnderMonkMode(int senderId) async {
  try {
    final settings = await LocalDatabaseHelper.instance.getMonkModeSettings();
    final bool enabled = settings['enabled'] as bool? ?? false;
    if (!enabled) return false;

    final String? deactivateAtStr = settings['deactivate_at'] as String?;
    if (deactivateAtStr != null) {
      final deactivateAt = DateTime.tryParse(deactivateAtStr)?.toLocal();
      if (deactivateAt != null && DateTime.now().isAfter(deactivateAt)) {
        return false;
      }
    }

    final List<int> blockedIds =
        List<int>.from(settings['blocked_ids'] as List? ?? []);
    return blockedIds.contains(senderId);
  } catch (e) {
    print("Error checking monk mode status: $e");
    return false;
  }
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
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
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
          final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.serviceRoleKey);
          await client.from('messages').update({'status': 'delivered'}).eq('id', messageId);
          print("PushNotifications: Background delivery status acknowledged in Supabase for $messageId.");
        } catch (e) {
          print("PushNotifications: Error updating remote Supabase status in background: $e");
        }

        // 3. Show notification if sender is not muted
        try {
          final isMuted = await _isUserMutedUnderMonkMode(senderId);
          if (!isMuted) {
            List<String> messageLines = [];
            bool isFallback = false;
            try {
              final unreadRows = await LocalDatabaseHelper.instance
                  .getUnreadMessagesForRoomBySender(roomId, senderId);
              messageLines = unreadRows.map((r) => r['payload'] as String).toList();
              if (messageLines.isEmpty) {
                isFallback = true;
              }
            } catch (dbError) {
              print("PushNotifications: Database read failed in background: $dbError");
              isFallback = true;
            }

            final senderName = data['sender_name'] as String? ?? 'New Message';
            if (isFallback) {
              await showLocalNotification(
                messageId, // Using messageId instead of roomId so it's individual and doesn't collapse
                senderName,
                [payload],
                {
                  'sender_id': senderIdStr,
                  'room_id': roomId,
                  'message_id': messageId,
                },
              );
              print("PushNotifications: Background fallback notification displayed for messageId: $messageId.");
            } else {
              await showLocalNotification(
                roomId,
                senderName,
                messageLines,
                {
                  'sender_id': senderIdStr,
                  'room_id': roomId,
                },
              );
              print("PushNotifications: Background local notification displayed with ${messageLines.length} lines.");
            }
          } else {
            print(
                "PushNotifications: Background notification suppressed because sender $senderId is muted.");
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
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.serviceRoleKey,
    // authCallbackUrlScheme: 'connectapp',
  );

  // Initialize flutter_local_notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      final payload = response.payload;
      if (payload != null) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          handleLocalNotificationClickPayload(payload);
        } else {
          pendingNotificationPayload = payload;
          try {
            final data = jsonDecode(payload);
            final senderIdStr = data['sender_id'] as String?;
            if (senderIdStr != null) {
              targetChatSenderId = int.tryParse(senderIdStr);
            }
          } catch (e) {
            print("Error parsing local notification payload on startup: $e");
          }
        }
      }
    },
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
        final data = jsonDecode(localPayload);
        final senderIdStr = data['sender_id'] as String?;
        if (senderIdStr != null) {
          targetChatSenderId = int.tryParse(senderIdStr);
        }
      }
    }

    final fcmMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (fcmMessage != null) {
      final data = fcmMessage.data;
      final senderIdStr = data['sender_id'] as String?;
      if (senderIdStr != null) {
        targetChatSenderId = int.tryParse(senderIdStr);
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
          )..loadBackgroundBlurPref(),
        ),
        ChangeNotifierProxyProvider<ProfileProvider, MonkModeProvider>(
          create: (_) => MonkModeProvider(),
          update: (_, profileProvider, monkModeProvider) {
            monkModeProvider!.updateProfileProvider(profileProvider);
            return monkModeProvider;
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
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        builder: (context, child) {
          final profileProvider = Provider.of<ProfileProvider>(context);
          final blurEnabled = profileProvider.blurBackground;

          Widget backgroundGradient = Container(
            decoration: BoxDecoration(
              gradient: context.felineBackgroundGradient,
            ),
          );

          if (blurEnabled) {
            backgroundGradient = ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: context.felineBackgroundGradient,
                ),
              ),
            );
          }

          return Stack(
            children: [
              Positioned.fill(child: backgroundGradient),
              if (child != null) Positioned.fill(child: child),
            ],
          );
        },
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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

        final session = snapshot.data?.session;
        final event = snapshot.data?.event;

        if (event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordScreen();
        }

        if (session != null) {
          return const AppShellGate();
        }

        return const AuthScreen();
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
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    try {
      // Step 1: Ensure a profile row exists (creates default if brand new user).
      // This also sets profileProvider.userId internally — no second call needed.
      await profileProvider.ensureProfileExists();

      final userId = profileProvider.userId;

      if (userId != null) {
        // Step 2: Load full profile fields (name, email, phone, etc.)
        await profileProvider.loadProfile(userId);
      }

      // ── Show the UI immediately after profile data is ready ──
      // Chat rooms, push tokens, and unread counts load in the background.
      if (mounted) setState(() => _initialized = true);

      if (targetChatSenderId != null) {
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
        alert: true,
        badge: true,
        sound: true,
      );

      // Fetch the token (FCM can generate tokens on Android even if notification permission is denied)
      print("PushNotifications: Fetching FCM token...");
      final token = await messaging.getToken();
      if (token != null) {
        print("PushNotifications: FCM token retrieved successfully: $token");
        await provider.updatePushToken(token);
      } else {
        print("PushNotifications: FCM token is null.");
      }

      // Listen for token updates and upsert them
      messaging.onTokenRefresh.listen((newToken) async {
        print("PushNotifications: FCM token refreshed: $newToken");
        await provider.updatePushToken(newToken);
      });

      // Request permission for local notifications (needed for Android 13+)
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

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
                    final isMuted = await _isUserMutedUnderMonkMode(senderId);
                    if (isMuted) {
                      print(
                          "PushNotifications: Foreground notification suppressed because sender $senderId is muted.");
                    } else {
                      List<String> messageLines = [];
                      bool isFallback = false;
                      try {
                        final unreadRows = await LocalDatabaseHelper.instance
                            .getUnreadMessagesForRoomBySender(roomId, senderId);
                        messageLines = unreadRows.map((r) => r['payload'] as String).toList();
                        if (messageLines.isEmpty) {
                          isFallback = true;
                        }
                      } catch (dbError) {
                        print("PushNotifications: Database read failed in foreground: $dbError");
                        isFallback = true;
                      }

                      if (isFallback) {
                        await showLocalNotification(
                          messageId, // Using messageId instead of roomId so it's individual and doesn't collapse
                          senderName,
                          [payload],
                          {
                            'sender_id': senderIdStr,
                            'room_id': roomId,
                            'message_id': messageId,
                          },
                        );
                        print("PushNotifications: Foreground local fallback notification displayed for messageId: $messageId.");
                      } else {
                        await showLocalNotification(
                          roomId,
                          senderName,
                          messageLines,
                          {
                            'sender_id': senderIdStr,
                            'room_id': roomId,
                          },
                        );
                        print(
                            "PushNotifications: Foreground local notification displayed with ${messageLines.length} lines.");
                      }
                    }
                  } catch (e) {
                    print(
                        "PushNotifications: Error showing local notification in foreground: $e");
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

                  // Delete from SQLite first
                  final localStatus = localMsg['status'] as String?;
                  if (localStatus != 'read') {
                    await LocalDatabaseHelper.instance.deleteMessage(messageId);
                    print(
                        "PushNotifications: Foreground message deleted from SQLite.");
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
          }
        } catch (e) {
          print("PushNotifications: Error in foreground message handler: $e");
        }
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
    return const _AppShell();
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      ProfilePage(
        onSetUpProfile: () {
          setState(() {
            _currentIndex = 3;
          });
        },
      ),
      const DirectMessagesHubPage(),
      const OtherProfilesPage(),
      const YetToBeBuiltProfilePage(),
      const MonkModePage(),
    ];
    _setupNotificationTapListeners();
  }

  @override
  void dispose() {
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
  }

  void _handleNotificationClick(RemoteMessage message) {
    final data = message.data;
    final senderIdStr = data['sender_id'] as String?;

    if (senderIdStr != null) {
      final senderId = int.tryParse(senderIdStr);
      if (senderId != null) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IndividualChatPage(otherUserId: senderId),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.canvasBackground,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
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
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 10.0),
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
                  _buildNavItem(index: 0, icon: Icons.home_outlined),
                  _buildNavItem(
                      index: 1, icon: Icons.chat_bubble_outline_rounded),
                  _buildNavItem(index: 2, icon: Icons.search_rounded),
                  _buildNavItem(index: 4, icon: Icons.self_improvement_rounded),
                  _buildNavItem(index: 3, icon: Icons.person_outline_rounded),
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

    Widget iconWidget = Icon(
      icon,
      size: 24,
      color: itemColor,
    );

    // If it's the Chats tab (index 1) and there are unread messages, overlay a red dot badge
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
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(height: 4),
          // Active state indicator dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? const Color(0xFFCEF143) : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
