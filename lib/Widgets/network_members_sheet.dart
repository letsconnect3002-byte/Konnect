import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/custom_network.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/custom_network_provider.dart';
import 'package:connect/Providers/feed_provider.dart';

class NetworkMembersSheet extends StatefulWidget {
  final CustomNetwork network;

  const NetworkMembersSheet({
    super.key,
    required this.network,
  });

  static Future<void> show(BuildContext context, CustomNetwork network) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NetworkMembersSheet(network: network),
    );
  }

  @override
  State<NetworkMembersSheet> createState() => _NetworkMembersSheetState();
}

class _NetworkMembersSheetState extends State<NetworkMembersSheet> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0; // 0 = Add Connections, 1 = Current Members
  final Set<int> _addingMemberIds = {};
  final Set<int> _removingMemberIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CustomNetworkProvider>(context, listen: false)
          .loadActiveNetworkMembers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRemoveMember(CustomNetworkMember member) async {
    final netProvider =
        Provider.of<CustomNetworkProvider>(context, listen: false);
    final currentUserId = netProvider.userId;
    final isMe = member.userId == currentUserId;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.borderSubtle),
          ),
          title: Text(
            isMe ? 'Leave Network' : 'Remove Member',
            style: AppTypography.screenHeading.copyWith(fontSize: 18),
          ),
          content: Text(
            isMe
                ? 'Are you sure you want to leave "${widget.network.name}"? You will lose access to this network\'s posts and discussions.'
                : 'Are you sure you want to remove ${member.name} from "${widget.network.name}"?',
            style: AppTypography.bodyText.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(
                isMe ? 'Leave' : 'Remove',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _removingMemberIds.add(member.userId));
    HapticFeedback.mediumImpact();

    try {
      await netProvider.removeMember(
        member.userId,
        networkId: widget.network.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isMe
                        ? 'You left ${widget.network.name}'
                        : '${member.name} removed from ${widget.network.name}',
                    style: AppTypography.bodyText.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E202C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
        );

        if (isMe) {
          final feedProvider =
              Provider.of<FeedProvider>(context, listen: false);
          if (feedProvider.activeCustomNetwork?.id == widget.network.id) {
            feedProvider.selectCustomNetwork(null);
          }
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error removing member: $e',
              style: AppTypography.bodyText.copyWith(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _removingMemberIds.remove(member.userId));
      }
    }
  }

  Future<void> _handleAddMemberDirectly(int userId) async {
    setState(() => _addingMemberIds.add(userId));
    HapticFeedback.mediumImpact();

    try {
      final netProvider =
          Provider.of<CustomNetworkProvider>(context, listen: false);
      await netProvider.addMemberDirectly(userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding member: $e',
                style: AppTypography.bodyText.copyWith(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _addingMemberIds.remove(userId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final netProvider = Provider.of<CustomNetworkProvider>(context);
    final connectionProvider = Provider.of<ConnectionProvider>(context);
    final currentMembers = netProvider.activeNetworkMembers;
    final myConnections = connectionProvider.connections;
    final currentMemberUserIds = currentMembers.map((m) => m.userId).toSet();

    final query = _searchController.text.trim().toLowerCase();

    // Filtered lists
    final filteredConnections = myConnections.where((c) {
      final name = (c['name']?.toString() ?? '').toLowerCase();
      return query.isEmpty || name.contains(query);
    }).toList();

    final filteredMembers = currentMembers.where((m) {
      final name = m.name.toLowerCase();
      return query.isEmpty || name.contains(query);
    }).toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: AppColors.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: AppColors.borderSubtle,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.85),
              blurRadius: 36,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Standard Apple Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.borderSubtle,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.network.iconEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.network.name,
                          style: AppTypography.screenHeading.copyWith(
                            fontSize: 18,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${currentMembers.length} members • ${widget.network.isPrivate ? "Private" : "Public"} Network',
                          style: AppTypography.captionText.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BounceTap(
                    scaleDown: 0.90,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.borderSubtle,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(
              height: 1,
              color: AppColors.borderSubtle,
            ),

            const SizedBox(height: 12),

            // Tabs: Add from Connections vs. Current Members (Apple HIG Segmented Controller)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.borderSubtle,
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: BounceTap(
                        scaleDown: 0.98,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTab = 0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _selectedTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+ Add Connections',
                            style: TextStyle(
                              color: _selectedTab == 0
                                  ? Colors.black
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: BounceTap(
                        scaleDown: 0.98,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTab = 1);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _selectedTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Members (${currentMembers.length})',
                            style: TextStyle(
                              color: _selectedTab == 1
                                  ? Colors.black
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Search Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.borderSubtle,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: AppTypography.bodyText,
                  decoration: InputDecoration(
                    hintText: _selectedTab == 0
                        ? 'Search connections to add directly...'
                        : 'Search network members...',
                    hintStyle: AppTypography.bodyText.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Direct Add Note banner (when on tab 0)
            if (_selectedTab == 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Direct Add: Connections you add get instant access with zero invite wait.',
                          style: AppTypography.captionText.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // List Content
            Expanded(
              child: _selectedTab == 0
                  // Tab 0: Add Connections
                  ? (filteredConnections.isEmpty
                      ? Center(
                          child: Text(
                            query.isEmpty
                                ? 'No 1st-degree connections found'
                                : 'No matching connections',
                            style: AppTypography.bodyText.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredConnections.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, idx) {
                            final conn = filteredConnections[idx];
                            final connId =
                                int.tryParse(conn['id']?.toString() ?? '0') ?? 0;
                            final name = conn['name']?.toString() ?? 'User';
                            final avatarUrl = conn['avatarUrl']?.toString() ??
                                conn['avatar_url']?.toString() ??
                                '';
                            final profession =
                                conn['profession']?.toString() ?? '';
                            final isAlreadyMember =
                                currentMemberUserIds.contains(connId);
                            final isAdding = _addingMemberIds.contains(connId);

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        AppColors.surfaceSecondary,
                                    backgroundImage: avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl.isEmpty
                                        ? Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: AppTypography.cardTitle.copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (profession.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            profession,
                                            style: AppTypography.captionText
                                                .copyWith(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  isAlreadyMember
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceHighlight,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: AppColors.borderSubtle),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check_rounded,
                                                  size: 13,
                                                  color: Colors.white),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Member',
                                                style: AppTypography.captionText
                                                    .copyWith(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : BounceTap(
                                          scaleDown: 0.92,
                                          onTap: isAdding
                                              ? null
                                              : () => _handleAddMemberDirectly(
                                                  connId),
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.15),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            child: isAdding
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.black,
                                                    ),
                                                  )
                                                : const Text(
                                                    '+ Add',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                ],
                              ),
                            );
                          },
                        ))
                  // Tab 1: Current Members
                  : (filteredMembers.isEmpty
                      ? Center(
                          child: Text(
                            query.isEmpty
                                ? 'No members found'
                                : 'No matching members',
                            style: AppTypography.bodyText.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredMembers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, idx) {
                            final member = filteredMembers[idx];
                            final isCreator = member.userId == widget.network.creatorId;
                            final isMe = member.userId == netProvider.userId;
                            final isCurrentUserCreator = widget.network.creatorId == netProvider.userId;
                            final canRemove = (isCurrentUserCreator && !isCreator) ||
                                (member.addedBy == netProvider.userId && !isCreator) ||
                                (isMe && !isCreator);
                            final isRemoving = _removingMemberIds.contains(member.userId);

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        AppColors.surfaceSecondary,
                                    backgroundImage: member.avatarUrl.isNotEmpty
                                        ? NetworkImage(member.avatarUrl)
                                        : null,
                                    child: member.avatarUrl.isEmpty
                                        ? Text(
                                            member.name.isNotEmpty
                                                ? member.name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                member.name,
                                                style: AppTypography.cardTitle
                                                    .copyWith(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              Text(
                                                '(You)',
                                                style: AppTypography
                                                    .captionText
                                                    .copyWith(
                                                  color: AppColors.textMuted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (member.profession.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            member.profession,
                                            style: AppTypography.captionText
                                                .copyWith(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (isCreator)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceHighlight,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.borderSubtle,
                                        ),
                                      ),
                                      child: const Text(
                                        'Creator',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else if (canRemove)
                                    BounceTap(
                                      scaleDown: 0.92,
                                      onTap: isRemoving
                                          ? null
                                          : () => _handleRemoveMember(member),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.redAccent
                                                .withValues(alpha: 0.3),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: isRemoving
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.redAccent,
                                                ),
                                              )
                                            : Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isMe
                                                        ? Icons.logout_rounded
                                                        : Icons
                                                            .person_remove_rounded,
                                                    size: 13,
                                                    color: Colors.redAccent,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isMe ? 'Leave' : 'Remove',
                                                    style: const TextStyle(
                                                      color: Colors.redAccent,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontFamily: 'Inter',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }
}
