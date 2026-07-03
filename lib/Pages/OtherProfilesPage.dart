import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/chat_provider.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/Utils/profile_field_filter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:connect/Config/app_theme.dart';

class OtherProfilesPage extends StatefulWidget {
  const OtherProfilesPage({super.key});

  @override
  State<OtherProfilesPage> createState() => _OtherProfilesPageState();
}

class _OtherProfilesPageState extends State<OtherProfilesPage> {
  bool _isGridView =
      false; // true = Card View, false = List View (List is default)
  late ConnectionProvider connectionProvider;

  @override
  void initState() {
    super.initState();
    _loadDeletedProfiles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        connectionProvider =
            Provider.of<ConnectionProvider>(context, listen: false);
        setState(() {});
      }
    });
  }

  void _showReferBottomSheet(
      BuildContext context, Map<String, dynamic> targetProfile) {
    final provider = Provider.of<ConnectionProvider>(context, listen: false);
    final allConnections = provider.connections;

    // Filter out the referred user
    final eligibleConnections =
        allConnections.where((c) => c['id'] != targetProfile['id']).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusPremiumCard)),
      ),
      builder: (context) {
        return _ReferBottomSheet(
          targetProfile: targetProfile,
          eligibleConnections: eligibleConnections,
        );
      },
    );
  }

  Future<void> _loadDeletedProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('deleted_profile_ids') ?? [];
      // Profiles are stored in local preferences, no extra state needed
      print("Loaded ${list.length} deleted profile IDs locally.");
    } catch (e) {
      print("Error loading deleted profiles: $e");
    }
  }

  Future<void> _deleteProfileLocally(
      String id, ConnectionProvider provider) async {
    try {
      final intId = int.tryParse(id) ?? 0;
      await provider.deleteProfile(intId,
          onRoomCleanup: (profileId, roomId) async {
        await Provider.of<ChatProvider>(context, listen: false)
            .handleRoomCleanup(profileId, roomId);
      });
    } catch (e) {
      print("Error deleting profile locally: $e");
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context,
      Map<String, dynamic> connection, ConnectionProvider provider) async {
    final name = connection['name'] ?? 'this contact';
    final profileIdStr = (connection['id'] ?? '').toString();

    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: context.surfacePrimary,
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusPremiumCard),
              side: BorderSide(color: context.surfaceSecondary, width: 1.5)),
          title: Text(
            "Delete Connection",
            style: context.screenHeading.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to remove $name from your connections? This will permanently delete this connection and clear all chat history and text messages.",
            style: context.bodyText.copyWith(color: context.textSecondary),
          ),
          actions: [
            TextButton(
              child: Text("Cancel",
                  style: TextStyle(color: context.textSecondary)),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: const Text("Delete",
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                navigator.pop();
                try {
                  await _deleteProfileLocally(profileIdStr, provider);
                  if (!mounted) return;
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text("Connection and chat history deleted"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text("Error deleting connection: $e")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Return the actual avatar URL from the database, or empty if none
  String _getAvatarUrl(String name, String? existingUrl) {
    if (existingUrl != null &&
        existingUrl.isNotEmpty &&
        existingUrl.startsWith('http')) {
      return existingUrl;
    }
    return '';
  }

  String _getCompany(String name, String? existingCompany) {
    return existingCompany ?? '';
  }

  List<String> _getCardTypesForProfile(Map<String, dynamic> profile) {
    if (profile.containsKey('cardTypes')) {
      return List<String>.from(profile['cardTypes']);
    }

    final allTypes = <String>[];

    final hasInstagram = (profile['instagram'] ?? '').toString().isNotEmpty;
    final hasTwitter = (profile['twitter'] ?? '').toString().isNotEmpty;
    final hasCasualBio = (profile['bio'] ?? '').toString().isNotEmpty;

    final hasLinkedin = (profile['linkedin'] ?? '').toString().isNotEmpty;
    final hasCompany = (profile['company'] ?? '').toString().isNotEmpty;
    final hasEmail = (profile['email'] ?? '').toString().isNotEmpty;

    if (hasInstagram ||
        hasTwitter ||
        hasCasualBio ||
        (!hasLinkedin && !hasCompany)) {
      allTypes.add('casual');
    }
    if (hasLinkedin || hasCompany || hasEmail) {
      allTypes.add('professional');
    }

    if (allTypes.isEmpty) {
      allTypes.addAll(['casual', 'professional']);
    }

    return allTypes;
  }

  Widget _buildCardTypeBadges(Map<String, dynamic> profile) {
    final types = _getCardTypesForProfile(profile);

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        for (final type in types)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: context.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            ),
            child: Text(
              type.toUpperCase(),
              style: context.captionText.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCircularActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GlassmorphicButton(
      onPressed: onPressed,
      width: 44,
      height: 44,
      borderRadius: BorderRadius.circular(22),
      padding: EdgeInsets.zero,
      child: Icon(
        icon,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildToggleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.marginStandard, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "ALL CARDS",
            style: context.captionText.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: context.surfacePrimary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.surfaceSecondary, width: 1),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isGridView = true;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _isGridView
                          ? context.accentSecondary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      color: _isGridView ? Colors.white : context.textSecondary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isGridView = false;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 34,
                    decoration: BoxDecoration(
                      color: !_isGridView
                          ? context.accentSecondary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.view_list_rounded,
                      size: 18,
                      color:
                          !_isGridView ? Colors.white : context.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackAvatar(String name, double fontSize) {
    final monogram = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?";
    return Center(
      child: Text(
        monogram,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _buildCardItem(
      Map<String, dynamic> profileData, ConnectionProvider provider) {
    final name = profileData["name"] ?? "Unknown";
    final profession = profileData["profession"] ?? "";
    final String sharedCard =
        (profileData['sharedCard'] ?? profileData['shared_card'] ?? 'both')
            .toString();
    final String email = ProfileFieldFilter.getVisibleValue(
      'email',
      profileData["email"] ?? '',
      sharedCard,
      profileData['field_assignments'],
    );
    final String company = ProfileFieldFilter.getVisibleValue(
      'company',
      _getCompany(name, profileData["company"]),
      sharedCard,
      profileData['field_assignments'],
    );
    final avatarUrl = _getAvatarUrl(name, profileData["avatarUrl"]);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConnectionProfilePage(
              profileData: profileData,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppDimensions.marginStandard, vertical: 8),
        // decoration: BoxDecoration(
        //   color: context.surfacePrimary,
        //   borderRadius: BorderRadius.circular(AppDimensions.radiusPremiumCard),
        //   border: Border.all(
        //     color: context.surfaceSecondary.withValues(alpha: 0.5),
        //     width: 1.0,
        //   ),
        //   boxShadow: [
        //     BoxShadow(
        //       color: Colors.black.withValues(alpha: 0.3),
        //       blurRadius: 16,
        //       offset: const Offset(0, 8),
        //     ),
        //   ],
        // ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Avatar with refined Volt Green ring
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.accentPrimary.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(1.5),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.surfaceSecondary,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        (avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildFallbackAvatar(name, 22),
                              )
                            : _buildFallbackAvatar(name, 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: profession.isNotEmpty
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: context.cardTitle
                            .copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (profession.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          profession,
                          style: context.bodyText
                              .copyWith(color: context.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      _buildCardTypeBadges(profileData),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showDeleteConfirmation(context, profileData, provider);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: context.surfaceSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (company.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.business_center_rounded,
                          color: context.textSecondary, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        company,
                        style: context.bodyText
                            .copyWith(color: context.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (email.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.alternate_email_rounded,
                          color: context.textSecondary, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        email,
                        style: context.bodyText
                            .copyWith(color: context.textSecondary),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IndividualChatPage(
                            connectionData: profileData,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accentPrimary,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      "Message",
                      style: context.bodyText.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GlassmorphicButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showReferBottomSheet(context, profileData);
                    },
                    borderRadius: BorderRadius.circular(99),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      "Refer",
                      style: context.bodyText.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(
      Map<String, dynamic> profileData, ConnectionProvider provider) {
    final name = profileData["name"] ?? "Unknown";
    final profession = profileData["profession"] ?? "";
    final String sharedCard =
        (profileData['sharedCard'] ?? profileData['shared_card'] ?? 'both')
            .toString();
    final String company = ProfileFieldFilter.getVisibleValue(
      'company',
      _getCompany(name, profileData["company"]),
      sharedCard,
      profileData['field_assignments'],
    );
    final avatarUrl = _getAvatarUrl(name, profileData["avatarUrl"]);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConnectionProfilePage(
              profileData: profileData,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppDimensions.marginStandard, vertical: 0),
        // decoration: BoxDecoration(
        //   // color: context.surfacePrimary,
        //   borderRadius:
        //       BorderRadius.circular(AppDimensions.radiusPremiumCard / 1.5),
        //   border: Border.all(
        //       color: context.surfaceSecondary.withValues(alpha: 0.5), width: 1),
        // ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Avatar with refined Volt Green ring
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.accentPrimary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(1.0),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.surfaceSecondary,
                ),
                clipBehavior: Clip.antiAlias,
                child: (avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackAvatar(name, 16),
                      )
                    : _buildFallbackAvatar(name, 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: () {
                final subtitleText = profession.isNotEmpty && company.isNotEmpty
                    ? "$profession  •  $company"
                    : (profession.isNotEmpty ? profession : company);
                final hasSubtitle = subtitleText.isNotEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: context.bodyText
                          .copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasSubtitle) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitleText,
                        style: context.captionText
                            .copyWith(color: context.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                );
              }(),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showReferBottomSheet(context, profileData);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 4.0),
                    child: Icon(
                      Icons.share_rounded,
                      color: context.accentSecondary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showDeleteConfirmation(context, profileData, provider);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 4.0),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();
    final allProfiles = provider.connections;
    final count = allProfiles.length;

    return Scaffold(
      backgroundColor: context.canvasBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Premium Header
            Padding(
              padding: const EdgeInsets.fromLTRB(AppDimensions.marginStandard,
                  24, AppDimensions.marginStandard, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Mandal",
                        style: context.displayHeader,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$count ${count == 1 ? 'connection' : 'connections'}",
                        style: context.bodyText.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  // Back button (since this is now a pushed screen, not a tab)
                  if (Navigator.canPop(context))
                    _buildCircularActionButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
            ),
            // Toggle Switch Row
            _buildToggleRow(),
            // Connection Content list or loading
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: (provider.state is UserConnectionLoading)
                    ? Skeletonizer(
                        key: const ValueKey<String>('loading_state'),
                        enabled: true,
                        child: _buildSkeletonConnectionList(),
                      )
                    : allProfiles.isEmpty
                        ? Center(
                            key: const ValueKey<String>('empty_state'),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline_rounded,
                                  color: context.textMuted,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "No profiles available.",
                                  style: context.bodyText.copyWith(
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            key: ValueKey<bool>(_isGridView),
                            itemCount: allProfiles.length,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 100),
                            itemBuilder: (context, index) {
                              final item = allProfiles[index];
                              return _isGridView
                                  ? _buildCardItem(item, provider)
                                  : _buildListItem(item, provider);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonConnectionList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _isGridView ? 3 : 5,
      itemBuilder: (context, index) {
        if (_isGridView) {
          return Container(
            margin: const EdgeInsets.symmetric(
                horizontal: AppDimensions.marginStandard, vertical: 8),
            decoration: BoxDecoration(
              color: context.surfacePrimary,
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusPremiumCard),
              border: Border.all(color: context.surfaceSecondary),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white10,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: 120, height: 16, color: Colors.white),
                          const SizedBox(height: 6),
                          Container(width: 80, height: 12, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                    width: double.infinity, height: 14, color: Colors.white10),
                const SizedBox(height: 6),
                Container(width: 180, height: 14, color: Colors.white10),
              ],
            ),
          );
        } else {
          return Container(
            margin: const EdgeInsets.symmetric(
                horizontal: AppDimensions.marginStandard, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.surfacePrimary,
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusPremiumCard),
              border: Border.all(color: context.surfaceSecondary),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white10,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 100, height: 14, color: Colors.white),
                      const SizedBox(height: 6),
                      Container(width: 60, height: 10, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      },
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
  int? selectedConnectionId;
  final TextEditingController noteController = TextEditingController();
  bool isSending = false;

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
              "Refer ${widget.targetProfile['name'] ?? 'Connection'}",
              style: context.screenHeading.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Introduce them to another connection in your network.",
              style: context.bodyText.copyWith(
                color: context.textSecondary,
                fontSize: 12.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              "SELECT RECIPIENT",
              style: context.captionText.copyWith(
                color: context.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            if (widget.eligibleConnections.isEmpty)
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
                    final isSelected = selectedConnectionId == connId;
                    final name = conn['name'] ?? 'Unknown';
                    final avatar = _getAvatarUrl(name, conn['avatarUrl']);
                    final profession = conn['profession'] ?? '';

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          selectedConnectionId = connId;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.accentSecondary.withValues(alpha: 0.08)
                              : context.surfaceSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? context.accentSecondary
                                : context.surfaceSecondary,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: context.surfacePrimary,
                              backgroundImage: avatar.startsWith('http')
                                  ? NetworkImage(avatar)
                                  : null,
                              child: avatar.startsWith('http')
                                  ? null
                                  : Text(
                                      _getInitials(name),
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: context.accentSecondary,
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
                hintText: "Add a note to introduce them...",
                hintStyle: context.bodyText.copyWith(color: context.textMuted),
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
              ElevatedButton(
                onPressed: selectedConnectionId == null
                    ? null
                    : () async {
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
                          await notifProvider.sendReferral(
                            toUserId: selectedConnectionId!,
                            referredUserId: targetId,
                            note: noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim(),
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
                                    Text("Referral sent successfully!",
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
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accentSecondary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      context.surfaceSecondary.withValues(alpha: 0.5),
                  disabledForegroundColor: context.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusComponent),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: Text(
                  "Send Referral",
                  style: context.bodyText.copyWith(
                    fontWeight: FontWeight.bold,
                    color: selectedConnectionId == null
                        ? context.textMuted
                        : Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
