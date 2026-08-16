import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/feed_post.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:connect/Widgets/referral_intro_sheet.dart';
import 'package:connect/Widgets/post_engagement_bar.dart';
import 'package:connect/Widgets/link_preview_card.dart';

class PostCard extends StatelessWidget {
  final FeedPost post;
  final VoidCallback? onTap;
  final VoidCallback? onCommentTap;
  final bool isThreadView;
  final bool showTopConnector;
  final bool showBottomConnector;
  final bool isSelectedTarget;
  final bool isHighlighted;
  final String? replyToName;
  final Key? avatarKey;
  final bool showBottomBorder;
  final Function(String postId, String reactionKey)? onReactionToggle;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onCommentTap,
    this.isThreadView = false,
    this.showTopConnector = false,
    this.showBottomConnector = false,
    this.isSelectedTarget = false,
    this.isHighlighted = false,
    this.replyToName,
    this.avatarKey,
    this.showBottomBorder = true,
    this.onReactionToggle,
  });

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }

  void _showOptions(BuildContext context, int myUserId) {
    final isMe = (post.authorId == myUserId);
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (isMe)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent),
                  title: const Text("Delete Post",
                      style: TextStyle(
                          color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await feedProvider.deletePost(post.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Post deleted")),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Error deleting post"),
                            backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                ),
              )
            else ...[
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading:
                      const Icon(Icons.flag_outlined, color: Colors.amberAccent),
                  title: Text("Report Content",
                      style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReportDialog(context, feedProvider);
                  },
                ),
              ),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(Icons.block_rounded,
                      color: Colors.redAccent),
                  title: Text("Block ${post.authorName}",
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showBlockUserDialog(
                        context, feedProvider, connectionProvider);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBlockUserDialog(BuildContext context, FeedProvider feedProvider,
      ConnectionProvider connectionProvider) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.surfacePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Block ${post.authorName}?",
            style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: Text(
          "You will no longer see posts, comments, or profile details from ${post.authorName}.",
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text("Cancel", style: TextStyle(color: context.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await connectionProvider.blockUser(post.authorId);
                feedProvider.removePostsByAuthor(post.authorId);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text("${post.authorName} has been blocked.")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Failed to block user."),
                      backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text("Block User",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, FeedProvider feedProvider) {
    final controller = TextEditingController();
    String selectedReason = 'Spam';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.surfacePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Report Post",
            style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Select a reason for reporting this post:",
                style: TextStyle(color: context.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, setDialogState) => DropdownButton<String>(
                value: selectedReason,
                dropdownColor: context.surfaceSecondary,
                isExpanded: true,
                style: TextStyle(color: context.textPrimary),
                items: ['Spam', 'Harassment', 'Inappropriate Content', 'Other']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedReason = val);
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: TextStyle(color: context.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Additional details (optional)...",
                hintStyle: TextStyle(color: context.textMuted, fontSize: 12),
                filled: true,
                fillColor: context.surfaceSecondary,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text("Cancel", style: TextStyle(color: context.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: context.accentPrimary),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await feedProvider.reportPost(
                  postId: post.id,
                  reportedUserId: post.authorId,
                  reason: selectedReason,
                  additionalDetails: controller.text.trim(),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          "Report submitted. Thank you for keeping Jana safe.")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Failed to submit report."),
                      backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text("Submit",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDegreeBadge(BuildContext context, {bool isMe = false}) {
    String text = "";
    if (isMe || post.degree == 0) {
      text = "You";
    } else if (post.degree == 1) {
      text = "1°";
    } else if (post.degree == 2) {
      text = "2°";
    } else {
      text = "3°";
    }

    return Text(
      text,
      style: TextStyle(
        color: context.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (post.isDeleted) {
      return const SizedBox.shrink();
    }

    final profileProvider = Provider.of<ProfileProvider>(context);
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    final connProvider =
        Provider.of<ConnectionProvider>(context, listen: false);

    final myUserId = profileProvider.userId ??
        feedProvider.viewerId ??
        connProvider.userId ??
        0;
    final myName = profileProvider.name.trim().toLowerCase();
    final postName = post.authorName.trim().toLowerCase();

    final isMe = post.degree == 0 ||
        (myUserId != 0 && post.authorId == myUserId) ||
        (myName.isNotEmpty &&
            postName.isNotEmpty &&
            (myName == postName ||
                myName.contains(postName) ||
                postName.contains(myName)));

    final rawAvatar = CircleAvatar(
      radius: 18,
      backgroundColor: post.isDeleted
          ? Colors.white.withValues(alpha: 0.08)
          : context.surfaceSecondary,
      backgroundImage: (!post.isDeleted && post.authorAvatarUrl.isNotEmpty)
          ? NetworkImage(post.authorAvatarUrl)
          : null,
      child: post.isDeleted
          ? Icon(Icons.remove_circle_outline_rounded,
              size: 16, color: context.textMuted)
          : (post.authorAvatarUrl.isEmpty
              ? Text(
                  post.authorName.isNotEmpty
                      ? post.authorName.substring(0, 1).toUpperCase()
                      : "?",
                  style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                )
              : null),
    );

    final avatarWidget = avatarKey != null
        ? KeyedSubtree(key: avatarKey, child: rawAvatar)
        : rawAvatar;

    if (isThreadView) {
      return InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.03),
        highlightColor: Colors.white.withValues(alpha: 0.02),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isHighlighted
                ? context.accentPrimary.withValues(alpha: 0.08)
                : (isSelectedTarget
                    ? context.accentPrimary.withValues(alpha: 0.05)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(16),
            border: isHighlighted
                ? Border.all(
                    color: context.accentPrimary.withValues(alpha: 0.28),
                    width: 1.0)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Avatar & Continuous Vertical Thread Line
                SizedBox(
                  width: 36,
                  child: Column(
                    children: [
                      Container(
                        width: 2,
                        height: 8,
                        color: showTopConnector
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.transparent,
                      ),
                      avatarWidget,
                      Expanded(
                        child: Container(
                          width: 2,
                          color: showBottomConnector
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Right Column: Post Header & Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (replyToName != null && replyToName!.isNotEmpty) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(Icons.reply_rounded,
                                  size: 12, color: context.accentSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    text: "Replying to ",
                                    style: TextStyle(
                                        color: context.textMuted, fontSize: 11),
                                    children: [
                                      TextSpan(
                                        text: (myName.isNotEmpty &&
                                                replyToName!.trim().toLowerCase() ==
                                                    myName.toLowerCase())
                                            ? "@Me"
                                            : "@$replyToName",
                                        style: TextStyle(
                                          color: context.accentSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 2,
                                children: [
                                  Text(
                                    post.isDeleted
                                        ? "Deleted User"
                                        : post.authorName,
                                    style: TextStyle(
                                      color: post.isDeleted
                                          ? context.textMuted
                                          : context.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (!post.isDeleted)
                                    _buildDegreeBadge(context, isMe: isMe),
                                  Text(
                                    "• ${_formatTimeAgo(post.createdAt)}",
                                    style: TextStyle(
                                      color: context.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!post.isDeleted)
                              GestureDetector(
                                onTap: () => _showOptions(context, myUserId),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.more_vert_rounded,
                                      color: context.textMuted, size: 18),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        if (post.isDeleted)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              "This post was deleted",
                              style: TextStyle(
                                color: context.textMuted,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        else ...[
                          _FormattedPostContent(content: post.content),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              PostEngagementBar(
                                post: post,
                                onTap: onTap,
                                onCommentTap: onCommentTap,
                                onReactionToggle: onReactionToggle,
                              ),
                              const Spacer(),
                              if (post.degree >= 2 && !isMe) ...[
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    side: BorderSide(
                                        color: context.accentPrimary
                                            .withValues(alpha: 0.6)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(99)),
                                  ),
                                  icon: Icon(Icons.person_add_outlined,
                                      size: 14, color: context.accentPrimary),
                                  label: Text(
                                    "Connect",
                                    style: TextStyle(
                                      color: context.accentPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    ReferralIntroSheet.show(
                                      context: context,
                                      targetUserId: post.authorId,
                                      targetUserName: post.authorName,
                                      degree: post.degree,
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.03),
          highlightColor: Colors.white.withValues(alpha: 0.02),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? context.accentPrimary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(isHighlighted ? 16 : 0),
              border: Border.all(
                color: isHighlighted
                    ? context.accentPrimary.withValues(alpha: 0.28)
                    : Colors.transparent,
                width: 1.0,
              ),
            ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatarWidget,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyToName != null && replyToName!.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.reply_rounded,
                            size: 12, color: context.accentSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: "Replying to ",
                              style: TextStyle(
                                  color: context.textMuted, fontSize: 11),
                              children: [
                                TextSpan(
                                  text: (myName.isNotEmpty &&
                                          replyToName!.trim().toLowerCase() ==
                                              myName.toLowerCase())
                                      ? "@Me"
                                      : "@$replyToName",
                                  style: TextStyle(
                                    color: context.accentSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            Text(
                              post.isDeleted ? "Deleted User" : post.authorName,
                              style: TextStyle(
                                color: post.isDeleted
                                    ? context.textMuted
                                    : context.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!post.isDeleted)
                              _buildDegreeBadge(context, isMe: isMe),
                            Text(
                              "• ${_formatTimeAgo(post.createdAt)}",
                              style: TextStyle(
                                color: context.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!post.isDeleted)
                        GestureDetector(
                          onTap: () => _showOptions(context, myUserId),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.more_vert_rounded,
                                color: context.textMuted, size: 18),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (post.isDeleted)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        "This post was deleted",
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else ...[
                    _FormattedPostContent(content: post.content),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        PostEngagementBar(
                          post: post,
                          onTap: onTap,
                          onCommentTap: onCommentTap,
                          onReactionToggle: onReactionToggle,
                        ),
                        const Spacer(),
                        if (post.degree >= 2 && !isMe) ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(
                                  color: context.accentPrimary
                                      .withValues(alpha: 0.6)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(99)),
                            ),
                            icon: Icon(Icons.person_add_outlined,
                                size: 14, color: context.accentPrimary),
                            label: Text(
                              "Connect",
                              style: TextStyle(
                                color: context.accentPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ReferralIntroSheet.show(
                                context: context,
                                targetUserId: post.authorId,
                                targetUserName: post.authorName,
                                degree: post.degree,
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    if (showBottomBorder && !isHighlighted)
      Container(
        height: 1,
        color: Colors.white.withValues(alpha: 0.06),
      ),
  ],
);
  }
}

class _FormattedPostContent extends StatelessWidget {
  final String content;

  const _FormattedPostContent({required this.content});

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final String myName = profileProvider.name.trim();

    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    final connections = connectionProvider.connections;

    final Set<String> candidateNames = {};
    if (myName.isNotEmpty) {
      candidateNames.add(myName);
      final parts = myName.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) candidateNames.add(parts.first);
    }
    for (final c in connections) {
      final name = (c['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        candidateNames.add(name);
        final parts = name.split(RegExp(r'\s+'));
        if (parts.isNotEmpty) candidateNames.add(parts.first);
      }
    }

    try {
      final feedProvider = Provider.of<FeedProvider>(context, listen: false);
      for (final p in feedProvider.posts) {
        final name = p.authorName.trim();
        if (name.isNotEmpty) {
          candidateNames.add(name);
          final parts = name.split(RegExp(r'\s+'));
          if (parts.isNotEmpty) candidateNames.add(parts.first);
        }
      }
    } catch (_) {}

    final List<String> connectionNames = candidateNames.toList();

    // Sort longest names first so "Santosh patil" is matched before "Santosh"
    connectionNames.sort((a, b) => b.length.compareTo(a.length));

    final escapedNames = connectionNames.map((n) => RegExp.escape(n)).join('|');
    final String pattern = escapedNames.isNotEmpty
        ? r'@(' + escapedNames + r'|[A-Za-z0-9_\-\.]+)'
        : r'@[A-Za-z0-9_\-\.]+';

    final RegExp mentionRegex = RegExp(pattern, caseSensitive: false);

    final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final urlMatch = urlRegex.firstMatch(content);
    final String? detectedUrl = urlMatch?.group(0);

    // Strip raw URL strings from text display so only commentary and rich preview card are shown
    final String displayContent =
        detectedUrl != null ? content.replaceAll(urlRegex, '').trim() : content;

    final List<InlineSpan> spans = [];
    if (displayContent.isNotEmpty) {
      final matches = mentionRegex.allMatches(displayContent);

      int lastIndex = 0;
      for (final match in matches) {
        if (match.start > lastIndex) {
          spans.add(TextSpan(text: displayContent.substring(lastIndex, match.start)));
        }

        final String mentionText = match.group(0) ?? '';
        final String rawName = mentionText.startsWith('@')
            ? mentionText.substring(1).trim()
            : mentionText;

        final cleanMyName = myName.toLowerCase();
        final cleanRawName = rawName.toLowerCase();
        final bool isMe = cleanMyName.isNotEmpty &&
            (cleanRawName == cleanMyName ||
                cleanMyName.startsWith(cleanRawName) ||
                cleanRawName.startsWith(cleanMyName));

        final String displayMention = isMe ? "@Me" : mentionText;

        spans.add(
          TextSpan(
            text: displayMention,
            style: TextStyle(
              color: context.accentPrimary,
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                HapticFeedback.lightImpact();
                final matches = connections.where((c) {
                  final name = (c['name'] ?? '').toString().toLowerCase();
                  return name == rawName.toLowerCase();
                }).toList();

                if (matches.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ConnectionProfilePage(profileData: matches.first),
                    ),
                  );
                }
              },
          ),
        );

        lastIndex = match.end;
      }

      if (lastIndex < displayContent.length) {
        spans.add(TextSpan(text: displayContent.substring(lastIndex)));
      }

      if (spans.isEmpty) {
        spans.add(TextSpan(text: displayContent));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (displayContent.isNotEmpty) ...[
          RichText(
            text: TextSpan(
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                height: 1.45,
              ),
              children: spans,
            ),
          ),
          if (detectedUrl != null) const SizedBox(height: 8),
        ],
        if (detectedUrl != null) LinkPreviewCard(url: detectedUrl),
      ],
    );
  }
}
