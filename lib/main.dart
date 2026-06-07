import 'dart:ui';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connect/firebase_options.dart';
import 'package:connect/Providers/LocalDatabaseHelper.dart';
import 'package:connect/Config/supabase_config.dart';
import 'package:connect/Pages/OtherProfilesPage.dart';
import 'package:connect/Pages/ProfilePage.dart';
import 'package:connect/Pages/DirectMessagesHubPage.dart';
import 'package:connect/Pages/yet_to_be_built_profile_page.dart';
import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/chat_provider.dart';
import 'package:connect/Repositories/profile_repository.dart';
import 'package:connect/Repositories/connection_repository.dart';
import 'package:connect/Repositories/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:connect/Pages/AuthScreen.dart';
import 'package:connect/Pages/ResetPasswordScreen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel notificationChannel =
    AndroidNotificationChannel(
  'messages_channel', // id
  'Messages', // name
  description: 'Notifications for new messages', // description
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

int getNotificationId(String messageId) {
  try {
    final hex = messageId.replaceAll('-', '').substring(0, 8);
    return int.parse(hex, radix: 16) & 0x7FFFFFFF;
  } catch (e) {
    print("Error parsing UUID for notification ID: $e");
    return messageId.hashCode & 0x7FFFFFFF;
  }
}

Future<void> showLocalNotification(String messageId, String title, String body,
    Map<String, dynamic> dataPayload) async {
  final notificationId = getNotificationId(messageId);

  const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
    'messages_channel',
    'Messages',
    channelDescription: 'Notifications for new messages',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const DarwinNotificationDetails iosNotificationDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidNotificationDetails,
    iOS: iosNotificationDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    id: notificationId,
    title: title,
    body: body,
    notificationDetails: notificationDetails,
    payload: jsonEncode(dataPayload),
  );
}

Future<void> cancelLocalNotification(String messageId) async {
  final notificationId = getNotificationId(messageId);
  await flutterLocalNotificationsPlugin.cancel(id: notificationId);
}

String? pendingNotificationPayload;

Future<void> handleLocalNotificationClickPayload(String payload) async {
  try {
    final data = jsonDecode(payload);
    final senderIdStr = data['sender_id'] as String?;
    if (senderIdStr != null) {
      final senderId = int.tryParse(senderIdStr);
      if (senderId != null) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          final provider =
              Provider.of<ProfileProvider>(context, listen: false);
          final profile = await provider.loadProfile(senderId);
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (routeContext) =>
                  IndividualChatPage(connectionData: profile),
            ),
          );
        }
      }
    }
  } catch (e) {
    print("Error handling local notification click payload: $e");
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
    final senderName = data['sender_name'] as String? ?? 'New Message';
    final payload = data['payload'] as String?;

    if (messageId != null &&
        roomId != null &&
        senderIdStr != null &&
        payload != null) {
      final senderId = int.tryParse(senderIdStr);
      if (senderId != null) {
        // 1. Show notification FIRST to guarantee delivery regardless of DB/Network outcomes
        try {
          await showLocalNotification(
            messageId,
            senderName,
            payload,
            {
              'sender_id': senderIdStr,
              'room_id': roomId,
            },
          );
          print(
              "PushNotifications: Background notification displayed successfully.");
        } catch (e) {
          print(
              "PushNotifications: Error displaying background notification: $e");
        }

        // 2. Save to local SQLite safely
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

        // 3. Acknowledge delivery to Supabase safely.
        // NOTE: This background handler runs in a separate background isolate. 
        // The main application state and initialized Supabase singleton are not shared or accessible here.
        // Therefore, we must instantiate a fresh, dedicated SupabaseClient using raw config keys 
        // to perform database mutations within the background isolate context.
        try {
          final client = SupabaseClient(
            SupabaseConfig.url,
            SupabaseConfig.serviceRoleKey,
          );
          await client
              .from('messages')
              .update({'status': 'delivered'}).eq('id', messageId);
          print(
              "PushNotifications: Background status update acknowledged to Supabase.");
        } catch (e) {
          print(
              "PushNotifications: Error acknowledging delivery in background: $e");
        }
      }
    }
  } else if (action == 'delete_message') {
    if (messageId != null) {
      // 1. Cancel notification FIRST
      try {
        await cancelLocalNotification(messageId);
        print(
            "PushNotifications: Background notification cancelled successfully.");
      } catch (e) {
        print(
            "PushNotifications: Error cancelling notification in background: $e");
      }

      // 2. Delete from SQLite if not read
      try {
        final localMsg =
            await LocalDatabaseHelper.instance.getMessageById(messageId);
        if (localMsg != null) {
          final localStatus = localMsg['status'] as String?;
          if (localStatus != 'read') {
            await LocalDatabaseHelper.instance.deleteMessage(messageId);
            print("PushNotifications: Background message deleted from SQLite.");
          }
        }
      } catch (e) {
        print(
            "PushNotifications: Error deleting message from SQLite in background: $e");
      }
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.serviceRoleKey,
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
          ),
        ),
        ChangeNotifierProxyProvider<ProfileProvider, ConnectionProvider>(
          create: (_) => ConnectionProvider(
            connectionRepository: SupabaseConnectionRepository(),
          ),
          update: (_, profileProvider, connectionProvider) {
            connectionProvider!.updateUserId(profileProvider.userId);
            return connectionProvider;
          },
        ),
        ChangeNotifierProxyProvider2<ProfileProvider, ConnectionProvider, ChatProvider>(
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
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF090A0F),
          canvasColor: const Color(0xFF090A0F),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF8B5CF6),
            surface: Color(0xFF13141F),
            error: Colors.redAccent,
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
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
          return const Scaffold(
            backgroundColor: Color(0xFF090A0F),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
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
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    try {
      await profileProvider.ensureProfileExists();
      final userId = await profileProvider.fetchAndSetUserId2(true);
      if (userId != null) {
        await profileProvider.loadProfile(userId);
        await chatProvider.loadChatRooms();
        await _setupPushNotifications(chatProvider);
        await chatProvider.updateUnreadCount();
      }
    } catch (e) {
      print("Error in AppShellGate initialization: $e");
    } finally {
      if (mounted) {
        setState(() {
          _initialized = true;
        });
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

      // Configure foreground notification presentation options
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
                  await provider.acknowledgeDelivery(messageId, isActiveInChat: isCurrentRoom);
                  print(
                      "PushNotifications: Foreground message delivery status updated in Supabase via provider.");
                } catch (e) {
                  print(
                      "PushNotifications: Error acknowledging delivery in foreground: $e");
                }

                // 3. Update providers so UI updates immediately
                try {
                  await provider.refreshActiveRoomMessages();
                  await provider.updateUnreadCount();
                } catch (e) {
                  print("PushNotifications: Error updating providers: $e");
                }

                // 4. Show notification ONLY if the user is NOT actively in the chat room
                if (!isCurrentRoom) {
                  try {
                    await showLocalNotification(
                      messageId,
                      senderName,
                      payload,
                      {
                        'sender_id': senderIdStr,
                        'room_id': roomId,
                      },
                    );
                    print(
                        "PushNotifications: Foreground local notification displayed successfully.");
                  } catch (e) {
                    print(
                        "PushNotifications: Error showing local notification in foreground: $e");
                  }
                }
              }
            }
          } else if (action == 'delete_message') {
            if (messageId != null) {
              // 1. Delete from SQLite if not read
              try {
                final localMsg = await LocalDatabaseHelper.instance
                    .getMessageById(messageId);
                if (localMsg != null) {
                  final localStatus = localMsg['status'] as String?;
                  if (localStatus != 'read') {
                    await LocalDatabaseHelper.instance.deleteMessage(messageId);
                    print(
                        "PushNotifications: Foreground message deleted from SQLite.");
                  }
                }
              } catch (e) {
                print(
                    "PushNotifications: Error deleting message from SQLite in foreground: $e");
              }

              // 2. Update providers so UI updates
              try {
                await provider.refreshActiveRoomMessages();
                await provider.updateUnreadCount();
              } catch (e) {
                print(
                    "PushNotifications: Error updating providers after delete: $e");
              }

              // 3. Cancel local notification
              try {
                await cancelLocalNotification(messageId);
                print(
                    "PushNotifications: Foreground notification cancelled successfully.");
              } catch (e) {
                print(
                    "PushNotifications: Error cancelling notification in foreground: $e");
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
      return const Scaffold(
        backgroundColor: Color(0xFF090A0F),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
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
    ];
    _setupNotificationTapListeners();

    // Check if there is a pending local notification click payload stored globally
    if (pendingNotificationPayload != null) {
      final payload = pendingNotificationPayload!;
      pendingNotificationPayload = null; // Clear immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleLocalNotificationClickPayload(payload);
      });
    }
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
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (profileProvider.userId != null) {
        chatProvider.syncOutgoingMessageStatuses();
        chatProvider.fetchPendingMessages();
      }
    }
  }

  void _setupNotificationTapListeners() {
    // 1. Handle notification click when app is in background but still running
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });

    // 2. Handle notification click when app was cold-started from terminated state
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationClick(message);
      }
    });

    // 3. Handle local notifications plugin launch details (cold start via local notification)
    flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails()
        .then((NotificationAppLaunchDetails? details) {
      if (details != null && details.didNotificationLaunchApp) {
        final payload = details.notificationResponse?.payload;
        if (payload != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            handleLocalNotificationClickPayload(payload);
          });
        }
      }
    });
  }

  Future<void> _handleNotificationClick(RemoteMessage message) async {
    final data = message.data;
    final senderIdStr = data['sender_id'] as String?;

    if (senderIdStr != null) {
      final senderId = int.tryParse(senderIdStr);
      if (senderId != null) {
        final provider = Provider.of<ProfileProvider>(context, listen: false);
        try {
          // Fetch the sender's profile details so we can construct connectionData
          final profile = await provider.loadProfile(senderId);
          if (mounted) {
            // Push IndividualChatPage with the fetched sender profile
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    IndividualChatPage(connectionData: profile),
              ),
            );
          }
        } catch (e) {
          print("Error handling notification tap redirection: $e");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildFloatingNavBar(),
    );
  }

  Widget _buildFloatingNavBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F101A).withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.03)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 65,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                      index: 0, icon: Icons.home_rounded, isImageIcon: false),
                  _buildNavItem(
                      index: 1,
                      icon: Icons.chat_bubble_rounded,
                      isImageIcon: false),
                  _buildNavItem(
                      index: 2,
                      icon: Icons.chat_bubble_rounded,
                      isImageIcon: true),
                  _buildNavItem(
                      index: 3,
                      icon: Icons.contact_mail_rounded,
                      isImageIcon: false),
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
    required bool isImageIcon,
  }) {
    final bool isActive = _currentIndex == index;
    final String label = const ["Home", "Chat", "Mandal", "My Card"][index];
    final Color itemColor = isActive ? Colors.white : const Color(0xFF5C5E78);
    final provider = Provider.of<ChatProvider>(context);

    Widget iconWidget = isImageIcon
        ? ImageIcon(
            const AssetImage("assets/icons/Mandala Icon 1.png"),
            size: 24,
            color: itemColor,
          )
        : Icon(
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
      child: SizedBox(
        width: 72,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? const Color(0xFF1A1B2E) : Colors.transparent,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color:
                              const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: iconWidget,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: itemColor,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
