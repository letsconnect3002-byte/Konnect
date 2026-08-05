import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/chat_provider.dart';
import 'package:connect/Models/app_error.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/Pages/NotificationPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Widgets/connect_hub_bottom_sheet.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/tribe_provider.dart';
import 'package:connect/Pages/Tribe/TribeChatPage.dart';
import 'package:connect/Pages/Tribe/TribeCreatePage.dart';

class DirectMessagesHubPage extends StatefulWidget {
  const DirectMessagesHubPage({super.key});

  @override
  State<DirectMessagesHubPage> createState() => _DirectMessagesHubPageState();
}

class _DirectMessagesHubPageState extends State<DirectMessagesHubPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTab = 'casual';
  bool _isTabAutoSelected = false;

  @override
  void initState() {
    super.initState();
  }

  List<String> _getCardTypesForConnection(Map<String, dynamic> connection) {
    final sharedCard =
        (connection['my_shared_card'] ?? 'both').toString().toLowerCase();
    if (sharedCard == 'casual') {
      return ['casual'];
    } else if (sharedCard == 'professional') {
      return ['professional'];
    } else {
      return ['casual', 'professional'];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatMessageTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();

      final hour = dateTime.hour > 12
          ? dateTime.hour - 12
          : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      final timeStr = "$hour:$minute $period";

      if (dateTime.year == now.year &&
          dateTime.month == now.month &&
          dateTime.day == now.day) {
        return timeStr;
      }

      final yesterday = DateTime(now.year, now.month, now.day - 1);
      if (dateTime.year == yesterday.year &&
          dateTime.month == yesterday.month &&
          dateTime.day == yesterday.day) {
        return "Yesterday";
      }

      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    } catch (_) {
      return '';
    }
  }

  Future<void> _handleRefresh(BuildContext context) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final myUserId = profileProvider.userId;
    await Future.wait([
      connectionProvider.fetchConnections(silent: true),
      chatProvider.loadChatRooms(),
      if (myUserId != null) profileProvider.loadProfile(myUserId),
    ]);
  }

  String _getAvatarUrl(String name, String? existingUrl) {
    if (existingUrl != null &&
        existingUrl.isNotEmpty &&
        existingUrl.startsWith('http')) {
      return existingUrl;
    }
    return '';
  }

  Future<void> _showDeleteConfirmation(BuildContext context,
      Map<String, dynamic> connection, ConnectionProvider provider) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final isBlockedByMe = connection['isBlockedByMe'] == true;

    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return GlassmorphicAlertDialog(
          title: Text(
            "Manage Connection",
            style: context.screenHeading.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Text(
            isBlockedByMe
                ? "What action would you like to perform for ${connection['name'] ?? 'this contact'}? You can unblock them or disconnect entirely."
                : "What action would you like to perform for ${connection['name'] ?? 'this contact'}? Blocking will prevent them from contacting you, while deleting simply disconnects you.",
            style: context.bodyText.copyWith(color: context.textSecondary),
          ),
          actions: [
            TextButton(
              child: Text("Cancel",
                  style: TextStyle(color: context.textSecondary)),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: const Text("Report User",
                  style: TextStyle(
                      color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(dialogContext);
                _showReportUserDialog(context, connection, provider);
              },
            ),
            isBlockedByMe
                ? TextButton(
                    child: const Text("Unblock User",
                        style: TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      try {
                        await provider.unblockUser(connection['id']);
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text("User unblocked",
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        print("Error unblocking user: $e");
                      }
                    },
                  )
                : TextButton(
                    child: const Text("Block User",
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      try {
                        await provider.blockUser(connection['id']);
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text("User blocked",
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      } catch (e) {
                        print("Error blocking user: $e");
                      }
                    },
                  ),
            TextButton(
              child: const Text("Delete Connection",
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.normal)),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await provider.deleteProfile(connection['id'],
                      onRoomCleanup: (profileId, roomId) async {
                    await chatProvider.handleRoomCleanup(profileId, roomId);
                  });
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text("Connection removed",
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                } catch (e) {
                  print("Error deleting connection: $e");
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showReportUserDialog(BuildContext context,
      Map<String, dynamic> connection, ConnectionProvider provider) {
    final name = connection['name'] ?? 'this contact';
    final intId = connection['id'] as int? ?? 0;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    String selectedReason = 'Spam';
    final detailsController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return GlassmorphicAlertDialog(
              title: Text(
                "Report & Disconnect $name",
                style:
                    context.screenHeading.copyWith(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Please select the reason for reporting this user:",
                        style: context.bodyText
                            .copyWith(color: context.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      ...[
                        'Spam',
                        'Harassment or Abuse',
                        'Inappropriate Behavior',
                        'Other'
                      ].map((reason) {
                        final isSelected = selectedReason == reason;
                        return InkWell(
                          onTap: isSubmitting
                              ? null
                              : () {
                                  setStateBuilder(() {
                                    selectedReason = reason;
                                  });
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: isSelected
                                      ? context.accentPrimary
                                      : context.textMuted,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  reason,
                                  style: context.bodyText.copyWith(
                                    color: isSelected
                                        ? context.textPrimary
                                        : context.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      Text(
                        "Additional Details (Optional):",
                        style: context.bodyText
                            .copyWith(color: context.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: detailsController,
                        maxLines: 3,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          hintText: "Enter details here...",
                          hintStyle:
                              TextStyle(color: context.textMuted, fontSize: 13),
                          fillColor: context.surfaceSecondary,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: context.borderMuted),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: context.accentPrimary),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: context.bodyText,
                      ),
                    ],
                  ),
                ),
              ),
              actions: isSubmitting
                  ? [
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    ]
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text("Cancel",
                            style: TextStyle(color: context.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () async {
                          setStateBuilder(() {
                            isSubmitting = true;
                          });

                          try {
                            // 1. Report User
                            await chatProvider.reportMessage(
                              reportedUserId: intId,
                              reason: selectedReason,
                              additionalDetails:
                                  detailsController.text.trim().isEmpty
                                      ? null
                                      : detailsController.text.trim(),
                            );

                            // 2. Delete Connection
                            await provider.deleteProfile(intId,
                                onRoomCleanup: (profileId, roomId) async {
                              await chatProvider.handleRoomCleanup(
                                  profileId, roomId);
                            });

                            if (mounted) {
                              Navigator.of(dialogContext).pop();
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Connection deleted and contact reported."),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setStateBuilder(() {
                                isSubmitting = false;
                              });
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Could not file report. Please check your network and try again."),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text("Submit & Delete",
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final connectionProvider = Provider.of<ConnectionProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    final bool isMessagesLoading =
        connectionProvider.state is UserConnectionLoading ||
            chatProvider.state is ChatLoading;
    final connections = connectionProvider.connections;
    final myUserId = profileProvider.userId;

    // Dynamically auto-select tab on first load once connections are loaded
    if (!_isTabAutoSelected &&
        connectionProvider.state is UserConnectionLoaded) {
      _isTabAutoSelected = true;
      final casualList = connections
          .where((c) => _getCardTypesForConnection(c).contains('casual'))
          .toList();
      final professionalList = connections
          .where((c) => _getCardTypesForConnection(c).contains('professional'))
          .toList();

      if (casualList.isEmpty && professionalList.isNotEmpty) {
        _selectedTab = 'professional';
      } else if (professionalList.isEmpty && casualList.isNotEmpty) {
        _selectedTab = 'casual';
      } else {
        _selectedTab = 'casual';
      }
    }

    if (chatProvider.lastError != null) {
      final AppError error = chatProvider.lastError!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  "Could not retrieve messages. Please check your connection."),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
          chatProvider.clearError();
        }
      });
    }

    // Filter connections based on tab and query
    final filteredConnections = connections.where((c) {
      final cardTypes = _getCardTypesForConnection(c);
      if (!cardTypes.contains(_selectedTab)) {
        return false;
      }

      final name = (c['name'] ?? '').toString().toLowerCase();
      final profession = (c['profession'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || profession.contains(query);
    }).toList();

    // Sort dynamically by recent conversation (most recent on top)
    filteredConnections.sort((a, b) {
      final aRoomId = chatProvider.connectionRooms[a['id']];
      final bRoomId = chatProvider.connectionRooms[b['id']];

      final aMsg =
          aRoomId != null ? chatProvider.lastMessagesByRoom[aRoomId] : null;
      final bMsg =
          bRoomId != null ? chatProvider.lastMessagesByRoom[bRoomId] : null;

      debugPrint(
          "[DMHub] Sorting connection ${a['name']} (Room: $aRoomId, lastMsg: ${aMsg != null ? aMsg['payload'] : 'null'}) vs ${b['name']} (Room: $bRoomId, lastMsg: ${bMsg != null ? bMsg['payload'] : 'null'})");

      if (aMsg == null && bMsg == null) return 0;
      if (aMsg == null) return 1;
      if (bMsg == null) return -1;

      final aTime = DateTime.tryParse(aMsg['created_at'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse(bMsg['created_at'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bTime.compareTo(aTime);
    });

    return Scaffold(
      backgroundColor: context.canvasBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const GlassmorphicFlexibleSpace(showBorder: false),
        automaticallyImplyLeading: false,
        title: Text(
          'Messages',
          style: context.screenHeading,
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, child) {
              final unread = notifProvider.unreadCount;
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.surfacePrimary,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04)),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.notifications_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          if (unread > 0)
                            Positioned(
                              right: -1,
                              top: -1,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444), // Vibrant Red
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: context.surfacePrimary,
                                      width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 8,
                                  minHeight: 8,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppDimensions.marginStandard,
              right: AppDimensions.marginStandard,
              bottom: 10,
            ),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: context.surfacePrimary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.surfaceSecondary),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedTab = 'casual';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _selectedTab == 'casual'
                              ? context.accentSecondary
                              : Colors.transparent,
                          boxShadow: _selectedTab == 'casual'
                              ? [
                                  BoxShadow(
                                    color: context.accentSecondary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Casual",
                              style: TextStyle(
                                color: _selectedTab == 'casual'
                                    ? Colors.white
                                    : context.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Inter',
                              ),
                            ),
                            if (chatProvider.casualUnreadCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedTab = 'professional';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _selectedTab == 'professional'
                              ? context.accentPrimary
                              : Colors.transparent,
                          boxShadow: _selectedTab == 'professional'
                              ? [
                                  BoxShadow(
                                    color: context.accentPrimary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Professional",
                              style: TextStyle(
                                color: _selectedTab == 'professional'
                                    ? Colors.white
                                    : context.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Inter',
                              ),
                            ),
                            if (chatProvider.professionalUnreadCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedTab = 'tribes';
                        });
                        final tribeProvider =
                            Provider.of<TribeProvider>(context, listen: false);
                        if (tribeProvider.myTribes.isEmpty) {
                          tribeProvider.fetchMyTribes(silent: false);
                        } else {
                          tribeProvider.fetchMyTribes(silent: true);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _selectedTab == 'tribes'
                              ? context.accentSecondary
                              : Colors.transparent,
                          boxShadow: _selectedTab == 'tribes'
                              ? [
                                  BoxShadow(
                                    color: context.accentSecondary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Mafias",
                              style: TextStyle(
                                color: _selectedTab == 'tribes'
                                    ? Colors.white
                                    : context.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedTab == 'tribes') ...[
            Expanded(child: _buildTribesTabBody(context)),
          ] else ...[
            // 1. Search Box
            Padding(
              padding: const EdgeInsets.only(
                  left: AppDimensions.marginStandard,
                  right: AppDimensions.marginStandard,
                  top: 12,
                  bottom: 0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: context.surfaceSecondary,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusComponent),
                  border: Border.all(color: context.surfaceSecondary),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        color: context.textMuted, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: context.bodyText
                            .copyWith(color: context.textPrimary),
                        cursorColor: context.accentSecondary,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: 'Search connections...',
                          hintStyle: context.bodyText.copyWith(
                            color: context.textMuted,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _handleRefresh(context),
                color: context.accentSecondary,
                backgroundColor: context.surfaceSecondary,
                child: isMessagesLoading
                    ? Skeletonizer(
                        enabled: true,
                        child: _buildSkeletonChatRooms(),
                      )
                    : (connections.isEmpty && _searchQuery.isEmpty)
                        ? _buildOnboardingHeroCard(context)
                        : filteredConnections.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.5,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _searchQuery.isEmpty
                                                ? Icons
                                                    .chat_bubble_outline_rounded
                                                : Icons.search_off_rounded,
                                            color: context.textMuted,
                                            size: 40,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _searchQuery.isEmpty
                                                ? "No ${_selectedTab == 'casual' ? 'casual' : 'professional'} conversations yet"
                                                : "No results match your search",
                                            style: context.bodyText.copyWith(
                                              color: context.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(
                                    left: AppDimensions.marginStandard,
                                    right: AppDimensions.marginStandard,
                                    top: 8,
                                    bottom: 100),
                                itemCount: filteredConnections.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 5.0),
                                itemBuilder: (context, index) {
                                  final connection = filteredConnections[index];
                                  final name = connection['name'] ?? 'Unknown';
                                  final avatar = _getAvatarUrl(
                                      name,
                                      connection['avatarUrl'] ??
                                          connection['avatar_url']);

                                  final roomId = chatProvider
                                      .connectionRooms[connection['id']];

                                  final lastMsg = roomId != null
                                      ? chatProvider.lastMessagesByRoom[roomId]
                                      : null;

                                  final String lastMessageText = lastMsg != null
                                      ? lastMsg['payload'] ?? ''
                                      : '';

                                  final String msgTime = lastMsg != null
                                      ? _formatMessageTime(
                                          lastMsg['created_at'] as String?)
                                      : '';

                                  final bool isUnread = lastMsg != null &&
                                      lastMsg['sender_id'] != myUserId &&
                                      lastMsg['status'] != 'read';

                                  final bool isTyping = roomId != null &&
                                      chatProvider.isRoomTyping(roomId);

                                  final draft = chatProvider
                                      .getDraft(connection['id'] as int? ?? 0);

                                  return Container(
                                    // decoration: BoxDecoration(
                                    //   color: context.surfacePrimary,
                                    //   borderRadius: BorderRadius.circular(
                                    //       AppDimensions.radiusPremiumCard / 1.5),
                                    //   border: Border.all(
                                    //     color: context.surfaceSecondary
                                    //         .withValues(alpha: 0.5),
                                    //     width: 1.0,
                                    //   ),
                                    // ),
                                    child: Material(
                                      color: Colors.transparent,
                                      clipBehavior: Clip.antiAlias,
                                      borderRadius: BorderRadius.circular(
                                          AppDimensions.radiusPremiumCard),
                                      child: ListTile(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  IndividualChatPage(
                                                      connectionData:
                                                          connection),
                                            ),
                                          );
                                        },
                                        onLongPress: () {
                                          HapticFeedback.mediumImpact();
                                          _showDeleteConfirmation(context,
                                              connection, connectionProvider);
                                        },
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 0),
                                        leading: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                          ),
                                          child: ClipOval(
                                            child: avatar.isNotEmpty
                                                ? Image.network(
                                                    avatar,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                            error,
                                                            stackTrace) =>
                                                        Container(
                                                      color: context
                                                          .surfaceSecondary,
                                                      alignment:
                                                          Alignment.center,
                                                      child: Text(
                                                        name.isNotEmpty
                                                            ? name
                                                                .substring(0, 1)
                                                                .toUpperCase()
                                                            : "?",
                                                        style: TextStyle(
                                                            color: context
                                                                .textPrimary,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 15),
                                                      ),
                                                    ),
                                                  )
                                                : Container(
                                                    color: context
                                                        .surfaceSecondary,
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      name.isNotEmpty
                                                          ? name
                                                              .substring(0, 1)
                                                              .toUpperCase()
                                                          : "?",
                                                      style: TextStyle(
                                                          color: context
                                                              .textPrimary,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        title: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      name,
                                                      style: context.cardTitle
                                                          .copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            context.textPrimary,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                  if (connection[
                                                          'isBlockedByMe'] ==
                                                      true) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.redAccent
                                                            .withValues(
                                                                alpha: 0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                        border: Border.all(
                                                            color: Colors
                                                                .redAccent
                                                                .withValues(
                                                                    alpha: 0.4),
                                                            width: 0.5),
                                                      ),
                                                      child: const Text(
                                                        "Blocked",
                                                        style: TextStyle(
                                                          color:
                                                              Colors.redAccent,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            if (msgTime.isNotEmpty &&
                                                connection['isBlocked'] !=
                                                    true) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                msgTime,
                                                style: context.captionText
                                                    .copyWith(
                                                  color: isUnread
                                                      ? context.accentSecondary
                                                      : context.textMuted,
                                                  fontWeight: isUnread
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        subtitle:
                                            connection['isBlockedByMe'] == true
                                                ? Text(
                                                    "Blocked contact",
                                                    style: context.bodyText
                                                        .copyWith(
                                                      color: Colors.redAccent
                                                          .withValues(
                                                              alpha: 0.7),
                                                      fontSize: 12.5,
                                                    ),
                                                  )
                                                : connection['hasBlockedMe'] ==
                                                        true
                                                    ? Text(
                                                        "Unavailable",
                                                        style: context.bodyText
                                                            .copyWith(
                                                          color: Colors
                                                              .redAccent
                                                              .withValues(
                                                                  alpha: 0.7),
                                                          fontSize: 12.5,
                                                        ),
                                                      )
                                                    : lastMessageText.isEmpty &&
                                                            !isTyping &&
                                                            (draft == null ||
                                                                draft.isEmpty)
                                                        ? null
                                                        : Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 4.0),
                                                            child: Row(
                                                              children: [
                                                                Expanded(
                                                                  child: isTyping
                                                                      ? Text(
                                                                          "typing...",
                                                                          maxLines:
                                                                              1,
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                          style: context
                                                                              .bodyText
                                                                              .copyWith(
                                                                            color:
                                                                                context.accentSecondary,
                                                                            fontSize:
                                                                                12.5,
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                            fontStyle:
                                                                                FontStyle.italic,
                                                                          ),
                                                                        )
                                                                      : (draft != null && draft.isNotEmpty)
                                                                          ? RichText(
                                                                              maxLines: 1,
                                                                              overflow: TextOverflow.ellipsis,
                                                                              text: TextSpan(
                                                                                children: [
                                                                                  const TextSpan(
                                                                                    text: "Draft: ",
                                                                                    style: TextStyle(
                                                                                      color: Colors.blueAccent,
                                                                                      fontWeight: FontWeight.bold,
                                                                                      fontSize: 12.5,
                                                                                      fontFamily: 'Inter',
                                                                                    ),
                                                                                  ),
                                                                                  TextSpan(
                                                                                    text: draft,
                                                                                    style: TextStyle(
                                                                                      color: context.textSecondary,
                                                                                      fontSize: 12.5,
                                                                                      fontFamily: 'Inter',
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                            )
                                                                          : Text(
                                                                              lastMessageText,
                                                                              maxLines: 1,
                                                                              overflow: TextOverflow.ellipsis,
                                                                              style: context.bodyText.copyWith(
                                                                                color: isUnread ? context.textPrimary : context.textSecondary,
                                                                                fontSize: 12.5,
                                                                                fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                                                              ),
                                                                            ),
                                                                ),
                                                                if (isUnread)
                                                                  Container(
                                                                    margin: const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            8),
                                                                    width: 8,
                                                                    height: 8,
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: context
                                                                          .accentSecondary,
                                                                      shape: BoxShape
                                                                          .circle,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
          heroTag: 'dm_hub_fab',
          onPressed: () {
            HapticFeedback.mediumImpact();
            if (_selectedTab == 'tribes') {
              _showTribeActionsDialog(context);
            } else {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const ConnectHubBottomSheet(),
              );
            }
          },
          backgroundColor: context.accentSecondary,
          elevation: 8,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingHeroCard(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.marginStandard,
        vertical: 24,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height / 2,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium hero card
            Container(
              padding: const EdgeInsets.all(28),
              // decoration: BoxDecoration(
              //   color: context.surfacePrimary,
              //   borderRadius:
              //       BorderRadius.circular(AppDimensions.radiusPremiumCard),
              //   border: Border.all(
              //     color: Colors.white.withValues(alpha: 0.06),
              //     width: 1.0,
              //   ),
              //   boxShadow: [
              //     BoxShadow(
              //       color: context.accentSecondary.withValues(alpha: 0.08),
              //       blurRadius: 40,
              //       spreadRadius: 0,
              //       offset: const Offset(0, 12),
              //     ),
              //   ],
              // ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon container with glow
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.accentSecondary.withValues(alpha: 0.1),
                      boxShadow: [
                        BoxShadow(
                          color:
                              context.accentSecondary.withValues(alpha: 0.15),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: context.accentSecondary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Start Private Messaging",
                    style: context.screenHeading.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Connect with a friend by scanning their QR code or sharing your Private Key to begin.",
                    style: context.bodyText.copyWith(
                      color: context.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  // Primary CTA
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const ConnectHubBottomSheet(),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: const Text("Open Connect Hub"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accentSecondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusComponent),
                        ),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Secondary hint
            Text(
              "Tap + below to connect anytime",
              style: context.captionText.copyWith(
                color: context.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTribesTabBody(BuildContext context) {
    final provider = Provider.of<TribeProvider>(context);

    final tribes = provider.myTribes;

    // Only show active tribes -- invites are handled in the global Notification page
    final activeTribes = tribes.where((t) => t['status'] == 'active').toList();
    final bool isLoading =
        (provider.state is TribeLoading || provider.state is TribeInitial) &&
            activeTribes.isEmpty;

    return RefreshIndicator(
      onRefresh: () => provider.fetchMyTribes(silent: true),
      color: context.accentSecondary,
      backgroundColor: context.surfaceSecondary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
        children: [
          // ── Active Tribes Section ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Your Mafias",
                  style:
                      context.cardTitle.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            _buildTribesSkeleton(context)
          else if (activeTribes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.house_rounded,
                        color: context.textMuted, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      "You are not in any Mafia yet.",
                      style:
                          context.bodyText.copyWith(color: context.textMuted),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const TribeCreatePage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accentSecondary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Create a Mafia"),
                    ),
                  ],
                ),
              ),
            )
          else
            ...activeTribes.map((item) {
              final tribe = item['tribe'] as Map<String, dynamic>? ?? {};
              final name = tribe['name'] ?? 'Mafia';
              final desc = tribe['description'] ?? '';
              final role = item['role'] as Map<String, dynamic>? ?? {};

              return Card(
                color: Colors.transparent,
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(6),
                  leading: () {
                    final avatarUrl = tribe['avatar_url']?.toString() ?? '';
                    return Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color:
                                context.accentSecondary.withValues(alpha: 0.35),
                            width: 1.5),
                        color: context.surfaceSecondary,
                        image: avatarUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(avatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: avatarUrl.isEmpty
                          ? const Icon(Icons.group_rounded,
                              size: 20, color: Colors.white70)
                          : null,
                    );
                  }(),
                  title: Row(
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              context.accentSecondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          role['name'] ?? 'Member',
                          style: TextStyle(
                              color: context.accentSecondary,
                              fontSize: 8,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      desc.isEmpty ? 'No description' : desc,
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white24, size: 16),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TribeChatPage(
                            tribeId: tribe['id'] as String, tribeName: name),
                      ),
                    );
                  },
                  onLongPress: () {
                    final roleSlug = role['slug']?.toString();
                    if (roleSlug == 'don') {
                      HapticFeedback.heavyImpact();
                      _showDeleteTribeConfirmDialog(
                          context, tribe['id'] as String, name);
                    }
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showTribeActionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: GlassmorphicContainer(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Mafia Actions",
                        style: context.screenHeading.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.group_add_rounded,
                        color: Colors.white),
                    title: const Text("Create a Mafia",
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const TribeCreatePage()),
                      );
                    },
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.qr_code_scanner_rounded,
                        color: Colors.white),
                    title: const Text("Join Mafia with Code",
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _showJoinWithCodeDialog(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showJoinWithCodeDialog(BuildContext context) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: GlassmorphicContainer(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Join Mafia",
                    style: context.screenHeading
                        .copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Invite Code",
                    labelStyle:
                        TextStyle(color: context.textSecondary, fontSize: 13),
                    hintText: "Enter code here",
                    hintStyle:
                        TextStyle(color: context.textMuted, fontSize: 13),
                    fillColor: context.surfaceSecondary,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.borderMuted),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.borderMuted),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.accentSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: const Text("Cancel",
                          style: TextStyle(color: Colors.white70)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accentSecondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Join",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final code = codeController.text.trim();
                        if (code.isEmpty) return;

                        final provider =
                            Provider.of<TribeProvider>(context, listen: false);
                        try {
                          await provider.joinTribeWithInviteCode(code);
                          navigator.pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Successfully joined Mafia!"),
                                backgroundColor: Colors.green),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "Could not join Mafia. Please check the code and try again."),
                                backgroundColor: Colors.redAccent),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteTribeConfirmDialog(
      BuildContext context, String tribeId, String tribeName) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: GlassmorphicContainer(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Delete Mafia",
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const SizedBox(height: 12),
                Text(
                    "Are you sure you want to permanently delete \"$tribeName\"? This action is irreversible.",
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: const Text("Cancel",
                          style: TextStyle(color: Colors.white70)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Delete",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final provider =
                            Provider.of<TribeProvider>(context, listen: false);
                        try {
                          await provider.deleteTribe(tribeId);
                          navigator.pop();
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                                content: Text(
                                    "Mafia \"$tribeName\" deleted successfully.")),
                          );
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "Could not delete Mafia. Please try again.")),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonChatRooms() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.marginStandard, vertical: 8),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: 12.0),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: context.surfacePrimary,
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusPremiumCard),
            border: Border.all(
                color: context.surfaceSecondary.withValues(alpha: 0.5)),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white10,
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 100, height: 14, color: Colors.white),
                Container(width: 40, height: 10, color: Colors.white),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                  width: double.infinity, height: 12, color: Colors.white10),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTribesSkeleton(BuildContext context) {
    return Column(
      children: List.generate(4, (index) {
        return Card(
          color: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: const _ShimmerBox(
              width: 46,
              height: 46,
              shape: BoxShape.circle,
            ),
            title: Row(
              children: [
                const _ShimmerBox(
                  width: 120,
                  height: 14,
                  borderRadius: 4,
                ),
                const SizedBox(width: 8),
                const _ShimmerBox(
                  width: 40,
                  height: 10,
                  borderRadius: 3,
                ),
              ],
            ),
            subtitle: const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: _ShimmerBox(
                width: double.infinity,
                height: 12,
                borderRadius: 4,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.15),
              size: 14,
            ),
          ),
        );
      }),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 4.0,
    this.shape = BoxShape.rectangle,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.35, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              shape: widget.shape,
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: widget.shape == BoxShape.circle
                  ? null
                  : BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}
