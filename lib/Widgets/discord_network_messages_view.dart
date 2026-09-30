import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/feed_post.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Pages/ThreadDetailPage.dart';
import 'package:connect/Widgets/anonymous_avatar.dart';
import 'package:connect/Widgets/user_profile_modal.dart';
import 'package:connect/Widgets/link_preview_card.dart';
import 'package:connect/Widgets/pulse_row_widget.dart';
import 'package:connect/services/analytics_service.dart';

/// Discord-inspired Realtime Linear Messaging UI for Networks (Global, Network, Inner Circle, & Custom Networks).
///
/// Features:
/// - Reverse scroll message timeline (newest at bottom, auto-pinned).
/// - Discord message grouping (consecutive messages from same author within 5m are compact).
/// - Author avatar with degree / role badge, timestamp, and profile modal tap.
/// - Rich clickable links & automatic link preview cards.
/// - Discord-style thread pill (`🧵 N replies >`) on messages that have active threads,
///   opening [ThreadDetailPage] directly.
/// - Discord reaction pills (+ quick reaction picker on long-press).
/// - Pinned bottom message composer with dynamic `#channel-name` placeholder,
///   optional anonymous toggle (when allowed), and optimistic sending.
class DiscordNetworkMessagesView extends StatefulWidget {
  final VoidCallback? onSwitchToThreads;

  const DiscordNetworkMessagesView({
    super.key,
    this.onSwitchToThreads,
  });

  @override
  State<DiscordNetworkMessagesView> createState() =>
      _DiscordNetworkMessagesViewState();
}

class _DiscordNetworkMessagesViewState
    extends State<DiscordNetworkMessagesView> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _isSubmitting = false;
  bool _isAnonymous = false;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getChannelName(FeedProvider feedProvider) {
    if (feedProvider.isCustomNetworkActive &&
        feedProvider.activeCustomNetwork != null) {
      return feedProvider.activeCustomNetwork!.name
          .toLowerCase()
          .replaceAll(' ', '-');
    }
    switch (feedProvider.feedFilter) {
      case FeedFilter.global:
        return 'global';
      case FeedFilter.innerCircle:
        return 'inner-circle';
      case FeedFilter.fullNetwork:
        return 'network';
    }
  }

  String _getChannelDisplayName(FeedProvider feedProvider) {
    if (feedProvider.isCustomNetworkActive &&
        feedProvider.activeCustomNetwork != null) {
      return feedProvider.activeCustomNetwork!.name;
    }
    switch (feedProvider.feedFilter) {
      case FeedFilter.global:
        return 'Global Circle';
      case FeedFilter.innerCircle:
        return 'Inner Circle (1st Degree)';
      case FeedFilter.fullNetwork:
        return 'Full Network (1st & 2nd Degree)';
    }
  }

  bool _isAnonymousAllowed(FeedProvider feedProvider) {
    if (feedProvider.isCustomNetworkActive &&
        feedProvider.activeCustomNetwork != null) {
      return feedProvider.activeCustomNetwork!.allowAnonymous;
    }
    return feedProvider.feedFilter == FeedFilter.global;
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);

    final activeCustomNet = feedProvider.activeCustomNetwork;
    final isCustomActive = feedProvider.isCustomNetworkActive;
    final bool isGlobal = feedProvider.feedFilter == FeedFilter.global;
    final bool isInnerCircle =
        feedProvider.feedFilter == FeedFilter.innerCircle;
    final String? currentScope = isCustomActive
        ? null
        : (isGlobal ? 'global' : (isInnerCircle ? 'inner_circle' : 'network'));

    final effectiveAnonymous =
        _isAnonymousAllowed(feedProvider) ? _isAnonymous : false;

    setState(() {
      _isSubmitting = true;
    });

    HapticFeedback.lightImpact();
    _textController.clear();

    try {
      await feedProvider.createPost(
        text,
        authorName: profileProvider.name,
        authorAvatarUrl: profileProvider.avatarUrl,
        connections: connectionProvider.connections,
        isAnonymous: effectiveAnonymous,
        networkId: activeCustomNet?.id,
        feedScope: currentScope,
      );

      AnalyticsService.logEvent(
        name: 'discord_message_sent',
        parameters: {
          'scope': currentScope ?? 'custom_network',
          'is_anonymous': effectiveAnonymous,
        },
      );

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutQuad,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  static String _formatMessageTime(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';

    if (isToday) return 'Today at $timeStr';
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday at $timeStr';
    }
    return '${dt.day}/${dt.month}/${dt.year} $timeStr';
  }

  static String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday';
    }
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context);
    final displayedPosts = feedProvider.displayedPosts;
    final channelName = _getChannelName(feedProvider);
    final channelDisplayName = _getChannelDisplayName(feedProvider);
    final bool allowAnonymous = _isAnonymousAllowed(feedProvider);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardOpen = bottomInset > 0;

    return Column(
      children: [
        // Message Timeline
        Expanded(
          child: displayedPosts.isEmpty
              ? _buildEmptyChannelState(context, channelDisplayName)
              : ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  itemCount: displayedPosts.length + 1,
                  itemBuilder: (context, index) {
                    // Top of channel: Pulse / Stories Row
                    if (index == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: PulseRowWidget(),
                      );
                    }

                    final postIndex = index - 1;
                    final post = displayedPosts[postIndex];
                    final newerPostAbove = (postIndex > 0)
                        ? displayedPosts[postIndex - 1]
                        : null;

                    final bool showDateHeader = newerPostAbove == null ||
                        !_isSameDay(newerPostAbove.createdAt, post.createdAt);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDateHeader)
                          _buildDateDivider(context, post.createdAt),
                        _DiscordMessageTile(
                          key: ValueKey('discord_msg_${post.id}'),
                          post: post,
                          isGrouped: false,
                          onOpenThread: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ThreadDetailPage(rootPostId: post.id),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
        ),

        // Pinned Bottom Composer (Discord-style)
        Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            4,
            12,
            isKeyboardOpen ? 8.0 : 78.0,
          ),
          child: _buildBottomComposer(context, channelName, allowAnonymous),
        ),
      ],
    );
  }

  Widget _buildDateDivider(BuildContext context, DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDateHeader(date),
              style: TextStyle(
                color: context.textSecondary.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChannelState(
    BuildContext context,
    String channelDisplayName,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            const PulseRowWidget(),
            const SizedBox(height: 40),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: context.accentPrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.accentPrimary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 34,
                color: context.accentPrimary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "No messages yet",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Start the conversation in $channelDisplayName by sending a message below, or switch to Threads view.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13.5,
                height: 1.4,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 20),
            if (widget.onSwitchToThreads != null)
              OutlinedButton.icon(
                onPressed: widget.onSwitchToThreads,
                icon: const Icon(Icons.forum_rounded, size: 16),
                label: const Text(
                  "Switch to Threads View",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomComposer(
    BuildContext context,
    String channelName,
    bool allowAnonymous,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Anonymous mode toggle if allowed
          if (allowAnonymous) ...[
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isAnonymous = !_isAnonymous;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isAnonymous
                          ? "Anonymous mode ON (posting with masked identity)"
                          : "Anonymous mode OFF (posting as yourself)",
                    ),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _isAnonymous
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isAnonymous
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.masks_rounded,
                  size: 19,
                  color: _isAnonymous
                      ? const Color(0xFFF59E0B)
                      : context.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],

          // Text Input Box
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              maxLines: 4,
              minLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontFamily: 'Inter',
              ),
              cursorColor: context.accentPrimary,
              decoration: InputDecoration(
                hintText: _isAnonymous
                    ? "Message #$channelName anonymously..."
                    : "Message #$channelName",
                hintStyle: TextStyle(
                  color: context.textMuted.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),

          const SizedBox(width: 6),

          // Send Button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textController,
            builder: (context, value, _) {
              final hasContent = value.text.trim().isNotEmpty;

              return GestureDetector(
                onTap: hasContent && !_isSubmitting ? _sendMessage : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hasContent
                        ? context.accentPrimary
                        : context.surfaceSecondary,
                    shape: BoxShape.circle,
                    boxShadow: hasContent
                        ? [
                            BoxShadow(
                              color: context.accentPrimary
                                  .withValues(alpha: 0.35),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _isSubmitting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: hasContent ? Colors.black : Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.arrow_upward_rounded,
                            size: 20,
                            color: hasContent ? Colors.black : context.textMuted,
                          ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A Discord-style message item representing a post in the channel stream.
class _DiscordMessageTile extends StatelessWidget {
  final FeedPost post;
  final bool isGrouped;
  final VoidCallback onOpenThread;

  const _DiscordMessageTile({
    super.key,
    required this.post,
    required this.isGrouped,
    required this.onOpenThread,
  });

  void _showReactionPicker(BuildContext context) {
    HapticFeedback.lightImpact();
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    final emojis = FeedPost.reactionEmojiMap.entries.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: emojis.map((e) {
                  final isSelected = post.userReaction == e.key;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      feedProvider.toggleReaction(post.id, reactionType: e.key);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.accentPrimary.withValues(alpha: 0.2)
                            : context.surfaceSecondary,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: context.accentPrimary,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Text(
                        e.value,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.alt_route_rounded,
                    color: Colors.white, size: 22),
                title: const Text(
                  "Reply in Thread",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onOpenThread();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded,
                    color: Colors.white70, size: 20),
                title: const Text(
                  "Copy Text",
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Inter',
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: post.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Message copied to clipboard"),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openUserProfile(BuildContext context) {
    if (post.isDeleted || post.isAnonymous) return;
    UserProfileModal.show(
      context,
      userId: post.authorId,
      userName: post.authorName,
      avatarUrl: post.authorAvatarUrl,
      degree: post.degree,
      scope: post.feedScope,
    );
  }

  @override
  Widget build(BuildContext context) {
    final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final match = urlRegex.firstMatch(post.content);
    final String? attachedUrl = match?.group(0);
    final String cleanText = attachedUrl != null
        ? post.content.replaceAll(urlRegex, '').trim()
        : post.content.trim();

    return InkWell(
      onLongPress: () => _showReactionPicker(context),
      splashColor: Colors.white.withValues(alpha: 0.03),
      highlightColor: Colors.white.withValues(alpha: 0.02),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.only(
          top: isGrouped ? 3.0 : 10.0,
          bottom: 3.0,
          left: 4.0,
          right: 4.0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar (or spacing if grouped)
            if (!isGrouped) ...[
              GestureDetector(
                onTap: () => _openUserProfile(context),
                child: post.isAnonymous
                    ? AnonymousAvatar(
                        seed: post.authorId.toString(),
                        radius: 19.0,
                      )
                    : Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.surfaceSecondary,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (post.authorAvatarUrl.isNotEmpty &&
                                post.authorAvatarUrl.startsWith('http'))
                            ? Image.network(
                                post.authorAvatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildFallback(),
                              )
                            : _buildFallback(),
                      ),
              ),
              const SizedBox(width: 12),
            ] else ...[
              const SizedBox(width: 50), // Indent to align with text above
            ],

            // Message Body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header (only for non-grouped messages)
                  if (!isGrouped) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: () => _openUserProfile(context),
                            child: Text(
                              post.isAnonymous
                                  ? 'Anonymous'
                                  : (post.authorName.isNotEmpty
                                      ? post.authorName
                                      : 'User'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: post.degree == 0
                                    ? context.accentPrimary
                                    : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildDegreeBadge(context),
                        const SizedBox(width: 8),
                        Text(
                          _DiscordNetworkMessagesViewState._formatMessageTime(
                              post.createdAt),
                          style: TextStyle(
                            color: context.textMuted.withValues(alpha: 0.65),
                            fontSize: 11,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    if (post.authorProfession != null &&
                        post.authorProfession!.trim().isNotEmpty &&
                        !post.isAnonymous &&
                        !post.isDeleted) ...[
                      const SizedBox(height: 1.5),
                      GestureDetector(
                        onTap: () => _openUserProfile(context),
                        child: Text(
                          post.authorProfession!.trim(),
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                  ],

                  // Content text & Link preview (No background box, raw URL stripped)
                  GestureDetector(
                    onTap: onOpenThread,
                    onLongPress: () => _showReactionPicker(context),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cleanText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 2),
                            child: SelectableText(
                              cleanText,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 14.5,
                                height: 1.35,
                                fontFamily: 'Inter',
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        if (attachedUrl != null &&
                            attachedUrl.isNotEmpty) ...[
                          if (cleanText.isNotEmpty) const SizedBox(height: 6),
                          LinkPreviewCard(url: attachedUrl),
                        ],
                      ],
                    ),
                  ),

                  // Reaction badges
                  if (post.reactionCounts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _buildReactionsRow(context),
                  ],

                  // Discord Thread Pill (if this post has active replies)
                  if (post.activeReplyCount > 0) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: onOpenThread,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: context.surfacePrimary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: context.accentPrimary.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.forum_rounded,
                              size: 13,
                              color: context.accentPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "${post.activeReplyCount} ${post.activeReplyCount == 1 ? 'reply' : 'replies'}",
                              style: TextStyle(
                                color: context.accentPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "View in chat",
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 11,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: context.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback() {
    final letter = post.authorName.isNotEmpty
        ? post.authorName.substring(0, 1).toUpperCase()
        : '?';
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDegreeBadge(BuildContext context) {
    if (post.isAnonymous) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: const Text(
          "Anon",
          style: TextStyle(
            color: Color(0xFFF59E0B),
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final Color greyColor = context.textMuted.withValues(alpha: 0.7);

    if (post.degree == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Text(
          "YOU",
          style: TextStyle(
            color: greyColor,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      );
    }

    String label = "${post.degree}°";
    if (post.degree == 1) {
      label = "1st";
    } else if (post.degree == 2) {
      label = "2nd";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: greyColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _buildReactionsRow(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: post.reactionCounts.entries.map((entry) {
        final emojiKey = entry.key;
        final count = entry.value;
        if (count <= 0) return const SizedBox.shrink();

        final emoji = FeedPost.reactionEmojiMap[emojiKey] ?? '❤️';
        final isSelected = post.userReaction == emojiKey;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            feedProvider.toggleReaction(post.id, reactionType: emojiKey);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.accentPrimary.withValues(alpha: 0.18)
                  : context.surfacePrimary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? context.accentPrimary.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? context.accentPrimary : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
