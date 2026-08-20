import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/feed_post.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Widgets/reaction_picker_bar.dart';
import 'package:connect/services/analytics_service.dart';

class PostEngagementBar extends StatelessWidget {
  final FeedPost post;
  final VoidCallback? onTap;
  final VoidCallback? onCommentTap;
  final Function(String postId, String reactionKey)? onReactionToggle;

  const PostEngagementBar({
    super.key,
    required this.post,
    this.onTap,
    this.onCommentTap,
    this.onReactionToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, provider, child) {
        final livePost = provider.getPostById(post.id);
        final currentPost = livePost ?? post;

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ReactionButton(
              post: currentPost,
              onReactionToggle: onReactionToggle,
            ),
            const SizedBox(width: 8),
            _ReplyButton(
              post: currentPost,
              onTap: onCommentTap ?? onTap,
            ),
          ],
        );
      },
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final FeedPost post;
  final Function(String postId, String reactionKey)? onReactionToggle;

  const _ReactionButton({required this.post, this.onReactionToggle});

  void _showPicker(BuildContext context, GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final translation = renderBox.getTransformTo(null).getTranslation();
    final targetRect =
        renderBox.paintBounds.shift(Offset(translation.x, translation.y));

    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    ReactionPickerBar.show(
      context: context,
      targetRect: targetRect,
      activeReaction: post.userReaction,
      onSelectReaction: (selectedKey) {
        AnalyticsService.logEvent(
          name: 'post_reaction_selected',
          parameters: {
            'post_id': post.id,
            'reaction_key': selectedKey,
          },
        );
        if (onReactionToggle != null) {
          onReactionToggle!(post.id, selectedKey);
        } else {
          feedProvider.toggleReaction(post.id, reactionType: selectedKey);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey buttonKey = GlobalKey();

    final bool hasUserReaction = post.userReaction != null;
    final int totalCount = post.totalReactions;

    Widget iconWidget;
    if (hasUserReaction) {
      // 1. User has reacted -> Show ONLY their chosen reaction emoji replacing the default heart
      final myEmoji = FeedPost.reactionEmojiMap[post.userReaction] ?? '❤️';
      iconWidget = Text(myEmoji, style: const TextStyle(fontSize: 13));
    } else if (totalCount > 0 && post.topReactionEmojis.isNotEmpty) {
      // 2. User has NOT reacted, but others HAVE -> Playful floating emojis cluster
      final topEmojis = post.topReactionEmojis.take(3).toList();
      if (topEmojis.length == 1) {
        iconWidget = Transform.rotate(
          angle: -0.08,
          child: Text(topEmojis.first, style: const TextStyle(fontSize: 12.5)),
        );
      } else {
        final List<Offset> floatingOffsets = [
          const Offset(0, -1.5),
          const Offset(-3.5, 1.8),
          const Offset(-7.0, -1.8),
        ];
        final List<double> floatingAngles = [-0.12, 0.14, -0.10];

        iconWidget = SizedBox(
          height: 18,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(topEmojis.length, (i) {
              return Transform.translate(
                offset: floatingOffsets[i % floatingOffsets.length],
                child: Transform.rotate(
                  angle: floatingAngles[i % floatingAngles.length],
                  child: Text(topEmojis[i], style: const TextStyle(fontSize: 12.5)),
                ),
              );
            }),
          ),
        );
      }
    } else {
      // 3. Nobody has reacted yet -> Default heart outline icon
      iconWidget = Icon(
        Icons.favorite_border_rounded,
        size: 15,
        color: context.textSecondary,
      );
    }

    final BoxDecoration containerDecoration = hasUserReaction
        ? BoxDecoration(
            color: context.accentPrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.accentPrimary.withValues(alpha: 0.4),
              width: 1.0,
            ),
          )
        : (totalCount > 0
            ? BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 1.0,
                ),
              )
            : const BoxDecoration());

    final EdgeInsets containerPadding = hasUserReaction
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
        : (totalCount > 0
            ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3)
            : const EdgeInsets.only(top: 2, bottom: 2, right: 6));

    final double countFontSize = hasUserReaction ? 12.0 : 11.5;

    return GestureDetector(
      key: buttonKey,
      onTap: () {
        HapticFeedback.lightImpact();
        _showPicker(context, buttonKey);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(right: 8),
        padding: containerPadding,
        decoration: containerDecoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            iconWidget,
            if (totalCount > 0) ...[
              SizedBox(width: (!hasUserReaction && post.topReactionEmojis.length > 1) ? 3 : 4),
              Text(
                "$totalCount",
                style: TextStyle(
                  color: hasUserReaction
                      ? context.accentPrimary
                      : context.textSecondary,
                  fontSize: countFontSize,
                  fontWeight: hasUserReaction ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReplyButton extends StatelessWidget {
  final FeedPost post;
  final VoidCallback? onTap;

  const _ReplyButton({required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final int count = post.activeReplyCount > 0 ? post.activeReplyCount : post.replyCount;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 2, right: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 15,
              color: context.textSecondary,
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text(
                "$count",
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
