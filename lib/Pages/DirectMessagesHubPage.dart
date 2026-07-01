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

    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return GlassmorphicAlertDialog(
          title: Text(
            "Delete Connection",
            style: context.screenHeading.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to remove ${connection['name'] ?? 'this contact'} from your connections?",
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
              content: Text("Error: ${error.message}"),
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
        flexibleSpace: const GlassmorphicFlexibleSpace(),
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
                                fontSize: 14,
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
                                fontSize: 14,
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
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      style:
                          context.bodyText.copyWith(color: context.textPrimary),
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
            child: isMessagesLoading
                ? Skeletonizer(
                    enabled: true,
                    child: _buildSkeletonChatRooms(),
                  )
                : (connections.isEmpty && _searchQuery.isEmpty)
                    ? _buildOnboardingHeroCard(context)
                    : filteredConnections.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _searchQuery.isEmpty
                                      ? Icons.chat_bubble_outline_rounded
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
                          )
                        : ListView.separated(
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
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation,
                                                  secondaryAnimation) =>
                                              IndividualChatPage(
                                                  connectionData: connection),
                                          transitionsBuilder: (context,
                                              animation,
                                              secondaryAnimation,
                                              child) {
                                            return SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(1.0, 0.0),
                                                end: Offset.zero,
                                              ).animate(CurvedAnimation(
                                                parent: animation,
                                                curve: Curves.easeOutCubic,
                                              )),
                                              child: child,
                                            );
                                          },
                                          transitionDuration:
                                              const Duration(milliseconds: 300),
                                          reverseTransitionDuration:
                                              const Duration(milliseconds: 250),
                                        ),
                                      );
                                    },
                                    onLongPress: () {
                                      HapticFeedback.mediumImpact();
                                      _showDeleteConfirmation(context,
                                          connection, connectionProvider);
                                    },
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 0),
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: avatar.isNotEmpty
                                            ? Image.network(avatar,
                                                fit: BoxFit.cover)
                                            : Container(
                                                color: context.surfaceSecondary,
                                                alignment: Alignment.center,
                                                child: Text(
                                                  name.isNotEmpty
                                                      ? name
                                                          .substring(0, 1)
                                                          .toUpperCase()
                                                      : "?",
                                                  style: TextStyle(
                                                      color:
                                                          context.textPrimary,
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
                                          child: Text(
                                            name,
                                            style: context.cardTitle.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: context.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        if (msgTime.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            msgTime,
                                            style: context.captionText.copyWith(
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
                                    subtitle: lastMessageText.isEmpty &&
                                            !isTyping
                                        ? null
                                        : Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4.0),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    isTyping
                                                        ? "typing..."
                                                        : lastMessageText,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: context.bodyText
                                                        .copyWith(
                                                      color: isTyping
                                                          ? context
                                                              .accentSecondary
                                                          : (isUnread
                                                              ? context
                                                                  .textPrimary
                                                              : context
                                                                  .textSecondary),
                                                      fontSize: 12.5,
                                                      fontWeight: isTyping ||
                                                              isUnread
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                      fontStyle: isTyping
                                                          ? FontStyle.italic
                                                          : FontStyle.normal,
                                                    ),
                                                  ),
                                                ),
                                                if (isUnread)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 8),
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: context
                                                          .accentSecondary,
                                                      shape: BoxShape.circle,
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
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const ConnectHubBottomSheet(),
            );
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

  Widget _buildSkeletonChatRooms() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
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
}
