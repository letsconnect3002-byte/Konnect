import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Config/feature_config.dart';
import 'package:provider/provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/Providers/network_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Widgets/network_map.dart';
import 'package:connect/Widgets/horizontal_connection_map.dart';
import 'package:connect/Utils/social_launcher.dart';
import 'dart:ui';

class YourNetworkPage extends StatefulWidget {
  const YourNetworkPage({super.key});

  @override
  State<YourNetworkPage> createState() => _YourNetworkPageState();
}

class _YourNetworkPageState extends State<YourNetworkPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int? _lastUserId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = Provider.of<ConnectionProvider>(context).userId;
    if (userId != null && userId != _lastUserId) {
      _lastUserId = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final networkProvider =
              Provider.of<NetworkProvider>(context, listen: false);
          networkProvider.loadStats(userId);
          networkProvider.loadNetwork(userId, reset: true);
        }
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final userId =
          Provider.of<ConnectionProvider>(context, listen: false).userId;
      if (userId != null) {
        Provider.of<NetworkProvider>(context, listen: false)
            .loadNetwork(userId);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showReferBottomSheet(
      BuildContext context, Map<String, dynamic> targetProfile) {
    HapticFeedback.mediumImpact();

    final String mutualNamesStr = targetProfile["mutual_names"] ?? "";
    final String mutualAvatarsStr = targetProfile["mutual_avatars"] ?? "";

    final List<String> mutualNames = mutualNamesStr
        .split(",")
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final List<String> mutualAvatarUrls = mutualAvatarsStr
        .split(",")
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    final realConnections = connectionProvider.connections;

    final List<Map<String, dynamic>> eligibleConnections = [];
    for (int i = 0; i < mutualNames.length; i++) {
      final name = mutualNames[i];
      var realConn = realConnections.firstWhere(
        (c) =>
            (c["name"] as String? ?? "").toLowerCase().trim() ==
            name.toLowerCase().trim(),
        orElse: () => <String, dynamic>{},
      );

      if (realConn.isEmpty) {
        realConn = realConnections.firstWhere(
          (c) => (c["name"] as String? ?? "")
              .toLowerCase()
              .contains(name.toLowerCase()),
          orElse: () => <String, dynamic>{},
        );
      }

      if (realConn.isNotEmpty) {
        eligibleConnections.add({
          "id": realConn["id"],
          "name": realConn["name"] ?? name,
          "profession": realConn["profession"] ?? "Connection",
          "avatarUrl": realConn["avatarUrl"] ??
              (i < mutualAvatarUrls.length ? mutualAvatarUrls[i] : ""),
          "avatar_url": realConn["avatarUrl"] ??
              (i < mutualAvatarUrls.length ? mutualAvatarUrls[i] : ""),
        });
      } else {
        print("Warning: Mutual connection profile not found for name: $name");
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusPremiumCard),
        ),
      ),
      builder: (context) {
        return _ReferBottomSheet(
          targetProfile: targetProfile,
          eligibleConnections: eligibleConnections,
        );
      },
    );
  }

  void _showProfilePreviewBottomSheet(
      BuildContext context, Map<String, dynamic> item) {
    HapticFeedback.mediumImpact();

    final int targetUserId = item["id"] ?? 0;
    final String name = item["name"] ?? '';
    final String profession = item["profession"] ?? '';
    final String company = item["company"] ?? '';
    final String avatarUrl = item["avatar_url"] ?? item["avatarUrl"] ?? '';
    final int degreeInt = item["degree"] is int
        ? item["degree"] as int
        : (int.tryParse(item["degree"]?.toString() ?? '') ?? 2);
    final String degree = degreeInt == 1 ? "1st" : (degreeInt == 2 ? "2nd" : "3rd");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            padding:
                const EdgeInsets.only(top: 8, bottom: 24, left: 24, right: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF16181C).withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.0,
              ),
            ),
            child: FutureBuilder<Map<String, dynamic>?>(
              future: () async {
                try {
                  final response = await Supabase.instance.client
                      .from('profiles')
                      .select('linkedin, twitter, instagram, spotify')
                      .eq('id', targetUserId)
                      .single();
                  return response as Map<String, dynamic>?;
                } catch (e) {
                  print("Error fetching profile preview: $e");
                  return null;
                }
              }(),
              builder: (context, snapshot) {
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting;
                final data = snapshot.data;

                final linkedin = data?['linkedin'] as String? ?? '';
                final twitter = data?['twitter'] as String? ?? '';
                final instagram = data?['instagram'] as String? ?? '';
                final spotify = data?['spotify'] as String? ?? '';

                final hasSocials = linkedin.isNotEmpty ||
                    twitter.isNotEmpty ||
                    instagram.isNotEmpty ||
                    spotify.isNotEmpty;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top drag handle
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Avatar + Degree Badge + Name + Title
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: degree == "2nd"
                                  ? const Color(0xFF3B82F6)
                                      .withValues(alpha: 0.4)
                                  : const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.4),
                              width: 2.0,
                            ),
                          ),
                          child: ClipOval(
                            child: avatarUrl.startsWith('http')
                                ? Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      color: context.surfaceSecondary,
                                      alignment: Alignment.center,
                                      child: Text(
                                        name.isNotEmpty
                                            ? name.substring(0, 1).toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: context.surfaceSecondary,
                                    alignment: Alignment.center,
                                    child: Text(
                                      name.isNotEmpty
                                          ? name.substring(0, 1).toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        fontFamily: 'Outfit',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: degree == "2nd"
                                          ? const Color(0xFF3B82F6)
                                              .withValues(alpha: 0.12)
                                          : const Color(0xFF8B5CF6)
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      degree,
                                      style: TextStyle(
                                        color: degree == "2nd"
                                            ? const Color(0xFF60A5FA)
                                            : const Color(0xFFA78BFA),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$profession • $company",
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.08),
                      height: 1,
                    ),
                    const SizedBox(height: 20),

                    // Socials Section
                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    else if (!hasSocials)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            "No social links added",
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 14,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (linkedin.isNotEmpty)
                            _buildSocialIcon(
                              'linkedin',
                              'assets/icons/linkedin.png',
                              linkedin,
                            ),
                          if (twitter.isNotEmpty)
                            _buildSocialIcon(
                              'twitter',
                              'assets/icons/twitter.png',
                              twitter,
                            ),
                          if (instagram.isNotEmpty)
                            _buildSocialIcon(
                              'instagram',
                              'assets/icons/instagram.png',
                              instagram,
                            ),
                          if (spotify.isNotEmpty)
                            _buildSocialIcon(
                              'spotify',
                              'assets/icons/spotify.png',
                              spotify,
                            ),
                        ],
                      ),
                    const SizedBox(height: 24),

                    // Close Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        foregroundColor: context.textPrimary,
                        surfaceTintColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Close",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSocialIcon(String platform, String assetPath, String input) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await SocialLauncher.launchSocialLink(context, platform, input);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Image.asset(
          assetPath,
          width: 24,
          height: 24,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.link,
            color: Colors.white70,
            size: 24,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final networkProvider = Provider.of<NetworkProvider>(context);
    final userId =
        Provider.of<ConnectionProvider>(context, listen: false).userId;
    final networkList = networkProvider.networkList;
    return Scaffold(
      backgroundColor: context.canvasBackground,
      body: SafeArea(
        child: networkProvider.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                ),
              )
            : SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 20, 26, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Your Network",
                            style: context.displayHeader.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "See who you can reach through your connections",
                            style: context.bodyText.copyWith(
                              color: context.textSecondary,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Visual Network Map
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 60),
                      child: NetworkMap(),
                    ),

                    // Unified Floating Content Container (overlaps map by 20px)
                    Transform.translate(
                      offset: const Offset(0, -20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.surfacePrimary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(38.0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 28),

                            // Inline Search Bar
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 26),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: context.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.04),
                                  ),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                child: Row(
                                  children: [
                                    Icon(Icons.search_rounded,
                                        size: 18, color: context.textMuted),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: (val) {
                                          if (userId != null) {
                                            networkProvider.search(userId, val);
                                          }
                                        },
                                        style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 13.5),
                                        decoration: InputDecoration(
                                          hintText:
                                              "Search by name, title, or company...",
                                          hintStyle: TextStyle(
                                              color: context.textMuted,
                                              fontSize: 13.5),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                    if (_searchController.text.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          if (userId != null) {
                                            networkProvider.search(userId, '');
                                          }
                                        },
                                        child: Icon(Icons.close_rounded,
                                            size: 16, color: context.textMuted),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Metrics Row
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 26),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: "Primary",
                                      count: networkProvider.primaryCount
                                          .toString(),
                                      ringColor: const Color(0xFF10B981),
                                      progressValue: 0.75,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: "Secondary",
                                      count: networkProvider.secondaryCount
                                          .toString(),
                                      ringColor: const Color(0xFF3B82F6),
                                      progressValue: 0.6,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: "Tertiary",
                                      count: networkProvider.tertiaryCount
                                          .toString(),
                                      ringColor: const Color(0xFF8B5CF6),
                                      progressValue: 0.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Sorted List Header Row
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 26),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "PEOPLE YOU CAN REACH",
                                    style: context.captionText.copyWith(
                                      color: context.textSecondary,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  // GestureDetector(
                                  //   onTap: () {
                                  //     HapticFeedback.lightImpact();
                                  //     final newSort =
                                  //         networkProvider.currentSort ==
                                  //                 "mutual"
                                  //             ? "name"
                                  //             : "mutual";
                                  //     if (userId != null) {
                                  //       networkProvider.setSort(
                                  //           userId, newSort);
                                  //     }
                                  //   },
                                  //   child: Row(
                                  //     children: [
                                  //       Text(
                                  //         "Sort: ${networkProvider.currentSort == "mutual" ? "Mutual" : "Name"}",
                                  //         style: context.captionText.copyWith(
                                  //           color: context.textSecondary,
                                  //           fontWeight: FontWeight.w600,
                                  //         ),
                                  //       ),
                                  //       const SizedBox(width: 4),
                                  //       Icon(
                                  //         Icons.keyboard_arrow_down_rounded,
                                  //         size: 14,
                                  //         color: context.textSecondary,
                                  //       ),
                                  //     ],
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // People List / Empty State
                            if (networkList.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Text(
                                    "No reachable connections found.",
                                    style: context.bodyText
                                        .copyWith(color: context.textMuted),
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 26),
                                child: Column(
                                  children: [
                                    for (var item in networkList)
                                      _buildConnectionCard(context, item),
                                    if (networkProvider.isLoadingMore)
                                      const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 16),
                                        child: Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.0,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Color(0xFF7C3AED)),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // Widget _buildHeaderButton({
  //   required IconData icon,
  //   required VoidCallback onPressed,
  // }) {
  //   return Container(
  //     width: 38,
  //     height: 38,
  //     decoration: BoxDecoration(
  //       color: context.surfacePrimary,
  //       shape: BoxShape.circle,
  //       border: Border.all(
  //         color: Colors.white.withValues(alpha: 0.04),
  //       ),
  //     ),
  //     child: IconButton(
  //       icon: Icon(icon, color: Colors.white70, size: 18),
  //       onPressed: onPressed,
  //       padding: EdgeInsets.zero,
  //       constraints: const BoxConstraints(),
  //     ),
  //   );
  // }

  Widget _buildMetricCard({
    required String title,
    required String count,
    required Color ringColor,
    required double progressValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          Text(
            title,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 10,
              fontFamily: 'Inter',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context, Map<String, dynamic> item) {
    final String name = item["name"] ?? '';
    final String profession = item["profession"] ?? '';
    final String company = item["company"] ?? '';
    final int degreeInt = item["degree"] is int
        ? item["degree"] as int
        : (int.tryParse(item["degree"]?.toString() ?? '') ?? 2);
    final String degree = degreeInt == 1 ? "1st" : (degreeInt == 2 ? "2nd" : "3rd");
    final int mutualCount = item["mutual_count"] ?? 0;
    final String mutualNames = item["mutual_names"] ?? '';
    final String mutualAvatarsStr = item["mutual_avatars"] ?? '';
    final String avatarUrl = item["avatar_url"] ?? item["avatarUrl"] ?? '';

    String getInitials(String n) {
      if (n.trim().isEmpty) return '?';
      final parts = n.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }

    final List<String> rawNames = mutualNames
        .split(",")
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final List<String> rawAvatars = mutualAvatarsStr
        .split(",")
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final List<Map<String, String>> mutuals = [];
    for (int i = 0; i < rawNames.length; i++) {
      final String mutualName = rawNames[i];
      final String mutualAvatar = i < rawAvatars.length ? rawAvatars[i] : '';
      mutuals.add({'name': mutualName, 'avatar': mutualAvatar});
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showProfilePreviewBottomSheet(context, item),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circle Profile Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                  ),
                  child: ClipOval(
                    child: avatarUrl.startsWith('http')
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: context.surfaceSecondary,
                              alignment: Alignment.center,
                              child: Text(
                                name.isNotEmpty
                                    ? name.substring(0, 1).toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: context.surfaceSecondary,
                            alignment: Alignment.center,
                            child: Text(
                              name.isNotEmpty
                                  ? name.substring(0, 1).toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name and Job details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                fontFamily: 'Outfit',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Connection Degree Badge (e.g. 2nd, 3rd)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: degree == "2nd"
                                  ? const Color(0xFF3B82F6)
                                      .withValues(alpha: 0.12)
                                  : const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              degree,
                              style: TextStyle(
                                color: degree == "2nd"
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFFA78BFA),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "$profession • $company",
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12.5,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Mutual connections section + Action button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Stacked avatars + text
              Expanded(
                child: Row(
                  children: [
                    // Stack of mutual connection initials/avatars
                    SizedBox(
                      width: 14.0 + (mutuals.length * 10),
                      height: 24,
                      child: Stack(
                        children: [
                          for (int i = 0; i < mutuals.length; i++)
                            Positioned(
                              left: i * 12.0,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.surfaceSecondary,
                                  border: Border.all(
                                    color: context
                                        .surfacePrimary, // Background color separation border
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: mutuals[i]['avatar']!
                                          .startsWith('http')
                                      ? Image.network(
                                          mutuals[i]['avatar']!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                            color: context.surfaceSecondary,
                                            alignment: Alignment.center,
                                            child: Text(
                                              getInitials(mutuals[i]['name']!),
                                              style: TextStyle(
                                                color: context.textPrimary,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: context.surfaceSecondary,
                                          alignment: Alignment.center,
                                          child: Text(
                                            getInitials(mutuals[i]['name']!),
                                            style: TextStyle(
                                              color: context.textPrimary,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Text explanation
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$mutualCount mutual connection${mutualCount == 1 ? '' : 's'}",
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            mutualNames,
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 10,
                              fontFamily: 'Inter',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right: Request Refer button
              GestureDetector(
                onTap: () => _showReferBottomSheet(context, item),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons
                            .ios_share_rounded, // matches standard 'Request Refer' icon from screen
                        color: context.textPrimary,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Request Refer",
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
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
      ),
    );
  }
}

class _ReferBottomSheet extends StatefulWidget {
  final Map<String, dynamic> targetProfile;
  final List<Map<String, dynamic>> eligibleConnections;

  const _ReferBottomSheet({
    required this.targetProfile,
    required this.eligibleConnections,
  });

  @override
  State<_ReferBottomSheet> createState() => _ReferBottomSheetState();
}

class _ReferBottomSheetState extends State<_ReferBottomSheet> {
  final Set<int> selectedConnectionIds = {};
  final TextEditingController noteController = TextEditingController();
  bool isSending = false;
  List<Map<String, dynamic>> sentRequests = [];
  bool isLoadingSent = true;

  @override
  void initState() {
    super.initState();
    _loadSentRequests();
  }

  Future<void> _loadSentRequests() async {
    try {
      final notifProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      final list = await notifProvider.getSentReferralRequests();
      if (mounted) {
        setState(() {
          sentRequests = list;
          isLoadingSent = false;
        });
      }
    } catch (e) {
      print("Error loading sent requests: $e");
      if (mounted) {
        setState(() {
          isLoadingSent = false;
        });
      }
    }
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  String _getAvatarUrl(String name, String? existingUrl) {
    if (existingUrl != null &&
        existingUrl.isNotEmpty &&
        existingUrl.startsWith('http')) {
      return existingUrl;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final targetId = widget.targetProfile['id'];

    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.marginStandard,
        right: AppDimensions.marginStandard,
        top: 24.0,
        bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Connect with ${widget.targetProfile['name'] ?? 'Connection'}",
              style: context.screenHeading.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Ask your mutual connections to introduce you to ${widget.targetProfile['name'] ?? 'this contact'}.",
              style: context.bodyText.copyWith(
                color: context.textSecondary,
                fontSize: 12.5,
              ),
              textAlign: TextAlign.center,
            ),
            HorizontalConnectionMap(
              selectedMutual: selectedConnectionIds.isNotEmpty
                  ? widget.eligibleConnections.firstWhere(
                      (c) => c['id'] == selectedConnectionIds.first,
                      orElse: () => widget.eligibleConnections.first,
                    )
                  : null,
              targetName: widget.targetProfile['name'] ?? 'Connection',
              targetAvatarUrl: widget.targetProfile['avatar_url'] ?? widget.targetProfile['avatarUrl'],
              degree: widget.targetProfile['degree'] is int
                  ? widget.targetProfile['degree'] as int
                  : 2,
            ),
            const SizedBox(height: 12),
            Text(
              "SELECT MUTUAL CONNECTIONS",
              style: context.captionText.copyWith(
                color: context.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            if (isLoadingSent)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                  ),
                ),
              )
            else if (widget.eligibleConnections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "You need at least one other connection to make a referral.",
                  style: context.bodyText.copyWith(
                    color: context.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.25,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.eligibleConnections.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final conn = widget.eligibleConnections[index];
                    final connId = conn['id'] as int;

                    final existingRequest = sentRequests.firstWhere(
                      (r) =>
                          r['user_id'] == connId &&
                          r['referred_user_id'] == targetId,
                      orElse: () => <String, dynamic>{},
                    );
                    final hasRequest = existingRequest.isNotEmpty;

                    String? requestStatus;
                    if (hasRequest) {
                      final note = existingRequest['note'] as String?;
                      if (note != null &&
                          note.startsWith('[REFERRAL_REQUEST_ACTIONED]')) {
                        requestStatus = "Intro Sent";
                      } else {
                        requestStatus = "Requested";
                      }
                    }

                    final isSelected = selectedConnectionIds.contains(connId);
                    final name = conn['name'] ?? 'Unknown';
                    final avatar = _getAvatarUrl(name, conn['avatarUrl']);
                    final profession = conn['profession'] ?? '';

                    return GestureDetector(
                      onTap: hasRequest
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (selectedConnectionIds.contains(connId)) {
                                  selectedConnectionIds.remove(connId);
                                } else {
                                  selectedConnectionIds.add(connId);
                                }
                              });
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: hasRequest
                              ? context.surfaceSecondary.withValues(alpha: 0.4)
                              : (isSelected
                                  ? context.accentSecondary
                                      .withValues(alpha: 0.08)
                                  : context.surfaceSecondary),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasRequest
                                ? Colors.transparent
                                : (isSelected
                                    ? context.accentSecondary
                                    : context.surfaceSecondary),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
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
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Center(
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
                                    style: context.bodyText.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : context.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (profession.isNotEmpty)
                                    Text(
                                      profession,
                                      style: context.captionText.copyWith(
                                        color: context.textSecondary,
                                        fontWeight: FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            if (hasRequest)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: requestStatus == "Intro Sent"
                                      ? const Color(0xFF059669)
                                          .withValues(alpha: 0.15)
                                      : const Color(0xFFD97706)
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  requestStatus ?? "",
                                  style: TextStyle(
                                    color: requestStatus == "Intro Sent"
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFFFBBF24),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              )
                            else
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isSelected
                                    ? context.accentSecondary
                                    : context.textMuted,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            Text(
              "LEAVE A NOTE (OPTIONAL)",
              style: context.captionText.copyWith(
                color: context.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              maxLines: 3,
              maxLength: 69,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              style: context.bodyText,
              cursorColor: context.accentSecondary,
              decoration: InputDecoration(
                hintText:
                    "Add a note asking for an introduction to ${widget.targetProfile['name'] ?? 'them'} (note is common for all selected recipients)...",
                hintStyle: context.bodyText
                    .copyWith(color: context.textMuted, fontSize: 13),
                filled: true,
                fillColor: context.surfaceSecondary,
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusComponent),
                  borderSide: BorderSide(color: context.surfaceSecondary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusComponent),
                  borderSide: BorderSide(color: context.accentSecondary),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isSending)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                  ),
                ),
              )
            else
              Builder(
                builder: (context) {
                  final int targetDegree = widget.targetProfile['degree'] is int
                      ? widget.targetProfile['degree'] as int
                      : 2;
                  final bool is3rdDegreeDisabled = targetDegree == 3 &&
                      !FeatureConfig.enable3rdDegreeInteraction;
                  final bool isButtonEnabled =
                      selectedConnectionIds.isNotEmpty && !is3rdDegreeDisabled;

                  return ElevatedButton(
                    onPressed: isButtonEnabled
                        ? () async {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              isSending = true;
                            });

                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            final textPrimaryColor = context.textPrimary;

                            try {
                              final notifProvider =
                                  Provider.of<NotificationProvider>(context,
                                      listen: false);
                              final noteText =
                                  noteController.text.trim().isEmpty
                                      ? null
                                      : noteController.text.trim();

                              // Send referral requests to all selected recipients in parallel
                              await Future.wait(
                                selectedConnectionIds.map(
                                    (toId) => notifProvider.sendReferralRequest(
                                          toUserId: toId,
                                          referredUserId: targetId,
                                          note: noteText,
                                        )),
                              );

                              if (mounted) {
                                navigator.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded,
                                            color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text("Introduction requests sent!",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: textPrimaryColor)),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF7C3AED),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(() {
                                  isSending = false;
                                });

                                String friendlyMessage =
                                    "Failed to send referral. Please try again.";
                                final errStr = e.toString();
                                if (errStr.contains("check constraint") ||
                                    errStr.contains("23514")) {
                                  friendlyMessage =
                                      "Failed to send: unsupported database constraint. Please contact support.";
                                } else if (errStr.contains("network") ||
                                    errStr.contains("SocketException")) {
                                  friendlyMessage =
                                      "Network error. Please check your internet connection.";
                                }

                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded,
                                            color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            friendlyMessage,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: textPrimaryColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accentSecondary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          context.surfaceSecondary.withValues(alpha: 0.5),
                      disabledForegroundColor: context.textMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusComponent),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Text(
                      is3rdDegreeDisabled
                          ? "3rd Degree Introductions — Coming Soon"
                          : "Request Introduction",
                      style: context.bodyText.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            !isButtonEnabled ? context.textMuted : Colors.white,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
