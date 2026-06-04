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
import 'package:connect/Providers/ProfileProvider.dart';
import 'package:connect/Providers/ProviderSQL.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:connect/Pages/AuthScreen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase and Supabase in the background isolate
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.serviceRoleKey,
  );

  final data = message.data;
  final messageId = data['message_id'] as String?;
  final roomId = data['room_id'] as String?;
  final senderIdStr = data['sender_id'] as String?;
  final payload = data['payload'] as String?;

  if (messageId != null &&
      roomId != null &&
      senderIdStr != null &&
      payload != null) {
    final senderId = int.tryParse(senderIdStr);
    if (senderId != null) {
      // 1. Save to local SQLite
      await LocalDatabaseHelper.instance.insertMessage(
        messageId,
        roomId,
        senderId,
        payload,
        status: 'delivered',
      );

      // 2. Acknowledge delivery to Supabase
      try {
        await Supabase.instance.client
            .from('messages')
            .update({'status': 'delivered'}).eq('id', messageId);
      } catch (e) {
        print("Error acknowledging delivery in background: $e");
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

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider2()),
      ],
      child: MaterialApp(
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
    _initUser();
  }

  Future<void> _initUser() async {
    final provider = Provider.of<ProfileProvider2>(context, listen: false);
    try {
      await provider.ensureProfileExists();
      final userId = await provider.fetchAndSetUserId2(true);
      if (userId != -1) {
        final userData = await provider.loadProfile(userId);
        provider.setUserData(userData);
        await _setupPushNotifications(provider);
        await provider.updateUnreadCount();
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

  Future<void> _setupPushNotifications(ProfileProvider2 provider) async {
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
      final provider = Provider.of<ProfileProvider2>(context, listen: false);
      if (provider.userId != -1) {
        provider.syncOutgoingMessageStatuses();
        provider.fetchPendingMessages();
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
  }

  Future<void> _handleNotificationClick(RemoteMessage message) async {
    final data = message.data;
    final senderIdStr = data['sender_id'] as String?;

    if (senderIdStr != null) {
      final senderId = int.tryParse(senderIdStr);
      if (senderId != null) {
        final provider = Provider.of<ProfileProvider2>(context, listen: false);
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
                      index: 3, icon: Icons.person_rounded, isImageIcon: false),
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
    final String label = const ["Home", "Chats", "Circle", "My Profile"][index];
    final Color itemColor = isActive ? Colors.white : const Color(0xFF5C5E78);
    final provider = Provider.of<ProfileProvider2>(context);

    Widget iconWidget = isImageIcon
        ? ImageIcon(
            const AssetImage("assets/icons/Connect Icon2.png"),
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
