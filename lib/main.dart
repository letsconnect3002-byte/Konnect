import 'dart:ui';

import 'package:connect/Config/supabase_config.dart';
import 'package:connect/Pages/OtherProfilesPage.dart';
import 'package:connect/Pages/ProfilePage.dart';
import 'package:connect/Pages/DirectMessagesHubPage.dart';
import 'package:connect/Pages/yet_to_be_built_profile_page.dart';
import 'package:connect/Providers/ProfileProvider.dart';
import 'package:connect/Providers/ProviderSQL.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:connect/Pages/AuthScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.serviceRoleKey,
  );
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

class _AppShellState extends State<_AppShell> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
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
                      index: 1, icon: Icons.chat_bubble_rounded, isImageIcon: false),
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
    final String label = const ["Home", "Chats", "Circle", "Identity"][index];
    final Color itemColor = isActive ? Colors.white : const Color(0xFF5C5E78);

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
              child: isImageIcon
                  ? ImageIcon(
                      const AssetImage("assets/icons/Connect Icon2.png"),
                      size: 24,
                      color: itemColor,
                    )
                  : Icon(
                      icon,
                      size: 24,
                      color: itemColor,
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
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
