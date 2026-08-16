import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:connect/Models/feed_post.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Widgets/post_card.dart';

/// Data model representing a single comment node within a thread hierarchy.
class CommentNode {
  final String id;
  final int authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String content;
  final String timestamp;
  final int degree;
  final int replyCount;
  final bool isDeleted;
  final String? replyToName;
  final FeedPost?
      post; // Reference to original FeedPost for full PostCard rendering
  final List<CommentNode> replies;

  const CommentNode({
    required this.id,
    this.authorId = 0,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.content,
    required this.timestamp,
    this.degree = 0,
    this.replyCount = 0,
    this.isDeleted = false,
    this.replyToName,
    this.post,
    this.replies = const [],
  });

  CommentNode copyWith({
    String? id,
    int? authorId,
    String? authorName,
    String? authorAvatarUrl,
    String? content,
    String? timestamp,
    int? degree,
    int? replyCount,
    bool? isDeleted,
    String? replyToName,
    FeedPost? post,
    List<CommentNode>? replies,
  }) {
    return CommentNode(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      degree: degree ?? this.degree,
      replyCount: replyCount ?? this.replyCount,
      isDeleted: isDeleted ?? this.isDeleted,
      replyToName: replyToName ?? this.replyToName,
      post: post ?? this.post,
      replies: replies ?? this.replies,
    );
  }
}

/// CustomPainter that renders continuous vertical thread lines with smooth 90-degree
/// quadratic bezier curves branching toward child reply avatars (Instagram Threads / Reddit style).
class ThreadLinePainter extends CustomPainter {
  final double parentAvatarRadius;
  final double childAvatarRadius;
  final double indentationWidth;
  final double parentLeftPadding;
  final Color lineColor;
  final double strokeWidth;
  final double curveRadius;
  final List<double> childAvatarCenterYOffsets;
  final List<double> childAvatarLeftXs;
  final bool isLastChildChain;
  final bool isRootNode;
  final double parentCenterX;
  final double parentAvatarBottomY;

  ThreadLinePainter({
    required this.parentAvatarRadius,
    required this.childAvatarRadius,
    required this.indentationWidth,
    required this.parentLeftPadding,
    required this.lineColor,
    required this.strokeWidth,
    required this.curveRadius,
    required this.childAvatarCenterYOffsets,
    required this.childAvatarLeftXs,
    required this.isLastChildChain,
    required this.isRootNode,
    required this.parentCenterX,
    required this.parentAvatarBottomY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    List<double> yOffsets = childAvatarCenterYOffsets;
    if (yOffsets.isEmpty && size.height > 0) {
      yOffsets = [24.0];
    }
    if (yOffsets.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 1. Y coordinate where vertical trunk starts: 6px gap below parent avatar bottom
    final double lineStartY = parentAvatarBottomY + 6.0;

    final double lastChildY = yOffsets.last;

    // 2. Calculate vertical trunk end Y coordinate: always terminate at the last child's curve
    final double mainTrunkEndY = lastChildY - curveRadius;

    // Draw central vertical trunk line from parent avatar bottom down to the last child curve
    if (mainTrunkEndY > lineStartY) {
      final trunkPath = Path()
        ..moveTo(parentCenterX, lineStartY)
        ..lineTo(parentCenterX, mainTrunkEndY);
      canvas.drawPath(trunkPath, paint);
    }

    // 3. Draw 90-degree curved elbow branches towards each child reply avatar Y-center
    for (int i = 0; i < yOffsets.length; i++) {
      final double childCenterY = yOffsets[i];
      final double childLeftX =
          (i < childAvatarLeftXs.length && childAvatarLeftXs[i] > 0)
              ? childAvatarLeftXs[i]
              : indentationWidth;
      final double targetChildX =
          childLeftX - 6.0; // 6px gap before child profile picture

      final branchPath = Path()
        ..moveTo(parentCenterX, childCenterY - curveRadius)
        ..quadraticBezierTo(
          parentCenterX,
          childCenterY, // Control point at elbow corner
          parentCenterX + curveRadius,
          childCenterY, // End of 90-degree curve
        )
        ..lineTo(targetChildX, childCenterY);

      canvas.drawPath(branchPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ThreadLinePainter oldDelegate) {
    return oldDelegate.parentAvatarRadius != parentAvatarRadius ||
        oldDelegate.childAvatarRadius != childAvatarRadius ||
        oldDelegate.indentationWidth != indentationWidth ||
        oldDelegate.parentLeftPadding != parentLeftPadding ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.curveRadius != curveRadius ||
        oldDelegate.childAvatarCenterYOffsets != childAvatarCenterYOffsets ||
        oldDelegate.childAvatarLeftXs != childAvatarLeftXs ||
        oldDelegate.isLastChildChain != isLastChildChain ||
        oldDelegate.isRootNode != isRootNode ||
        oldDelegate.parentCenterX != parentCenterX ||
        oldDelegate.parentAvatarBottomY != parentAvatarBottomY;
  }
}

/// A clean, modular, and recursive Flutter component replicating Instagram Threads reply UI.
class ThreadedCommentTree extends StatelessWidget {
  final CommentNode comment;
  final double parentAvatarRadius;
  final double childAvatarRadius;
  final double indentationWidth;
  final double parentLeftPadding;
  final Color lineColor;
  final double strokeWidth;
  final double curveRadius;
  final bool allowNestedExpansion;
  final String? initialExpandPostId;
  final Map<String, GlobalKey>? itemKeys;
  final void Function(CommentNode node)? onReplyTap;
  final void Function(CommentNode node)? onCommentTap;
  final Function(String postId, String reactionKey)? onReactionToggle;

  const ThreadedCommentTree({
    super.key,
    required this.comment,
    this.parentAvatarRadius = 18.0,
    this.childAvatarRadius = 14.0,
    this.indentationWidth = 48.0,
    this.parentLeftPadding = 16.0,
    this.lineColor = const Color(
        0x61FFFFFF), // Colors.white38 default for dark background visibility
    this.strokeWidth = 1.8,
    this.curveRadius = 12.0,
    this.allowNestedExpansion = true,
    this.initialExpandPostId,
    this.itemKeys,
    this.onReplyTap,
    this.onCommentTap,
    this.onReactionToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _ThreadNodeWidget(
      comment: comment,
      parentAvatarRadius: parentAvatarRadius,
      childAvatarRadius: childAvatarRadius,
      indentationWidth: indentationWidth,
      parentLeftPadding: parentLeftPadding,
      lineColor: lineColor,
      strokeWidth: strokeWidth,
      curveRadius: curveRadius,
      allowNestedExpansion: allowNestedExpansion,
      initialExpandPostId: initialExpandPostId,
      itemKeys: itemKeys,
      onReplyTap: onReplyTap,
      onCommentTap: onCommentTap,
      onReactionToggle: onReactionToggle,
      isRootNode: true,
      isLastChildChain: true,
    );
  }
}

class _ThreadNodeWidget extends StatefulWidget {
  final Key? avatarKey;
  final CommentNode comment;
  final double parentAvatarRadius;
  final double childAvatarRadius;
  final double indentationWidth;
  final double parentLeftPadding;
  final Color lineColor;
  final double strokeWidth;
  final double curveRadius;
  final bool allowNestedExpansion;
  final String? initialExpandPostId;
  final Map<String, GlobalKey>? itemKeys;
  final void Function(CommentNode node)? onReplyTap;
  final void Function(CommentNode node)? onCommentTap;
  final Function(String postId, String reactionKey)? onReactionToggle;
  final VoidCallback? onExpansionChanged;
  final bool isRootNode;
  final bool isLastChildChain;

  const _ThreadNodeWidget({
    super.key,
    this.avatarKey,
    required this.comment,
    required this.parentAvatarRadius,
    required this.childAvatarRadius,
    required this.indentationWidth,
    required this.parentLeftPadding,
    required this.lineColor,
    required this.strokeWidth,
    required this.curveRadius,
    required this.allowNestedExpansion,
    this.initialExpandPostId,
    this.itemKeys,
    required this.onReplyTap,
    this.onCommentTap,
    this.onReactionToggle,
    this.onExpansionChanged,
    required this.isRootNode,
    required this.isLastChildChain,
  });

  @override
  State<_ThreadNodeWidget> createState() => _ThreadNodeWidgetState();
}

class _ThreadNodeWidgetState extends State<_ThreadNodeWidget>
    with TickerProviderStateMixin {
  final GlobalKey _localAvatarKey = GlobalKey();
  final GlobalKey _customPaintKey = GlobalKey();
  final List<GlobalKey> _childAvatarKeys = [];
  List<double> _childAvatarCenterYOffsets = [];
  List<double> _childAvatarLeftXs = [];
  double _parentCenterX = 34.0;
  double _parentAvatarBottomY = 0.0;
  bool _isExpanded = false;
  Ticker? _syncTicker;
  static const _animDuration = Duration(milliseconds: 350);

  bool _hasDescendantWithId(CommentNode node, String? targetId) {
    if (targetId == null || targetId.isEmpty) return false;
    for (final child in node.replies) {
      if (child.id == targetId || _hasDescendantWithId(child, targetId)) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialExpandPostId != null &&
        (widget.comment.id == widget.initialExpandPostId ||
            _hasDescendantWithId(widget.comment, widget.initialExpandPostId))) {
      _isExpanded = true;
    }
    _updateKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _computeOffsets());
  }

  @override
  void dispose() {
    _syncTicker?.dispose();
    super.dispose();
  }

  /// Starts a per-frame sync loop that recomputes offsets every frame
  /// for the duration of the AnimatedSize animation, keeping thread
  /// lines perfectly aligned with the moving content.
  void _startAnimationFrameSync() {
    _syncTicker?.stop();
    _syncTicker?.dispose();
    _syncTicker = createTicker((elapsed) {
      if (!mounted) {
        _syncTicker?.stop();
        return;
      }
      _computeOffsets();
      widget.onExpansionChanged?.call();
      if (elapsed > _animDuration + const Duration(milliseconds: 50)) {
        _syncTicker?.stop();
      }
    });
    _syncTicker!.start();
  }

  @override
  void didUpdateWidget(covariant _ThreadNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.comment.replies.length != oldWidget.comment.replies.length) {
      _updateKeys();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _computeOffsets());
  }

  void _updateKeys() {
    _childAvatarKeys.clear();
    for (int i = 0; i < widget.comment.replies.length; i++) {
      _childAvatarKeys.add(GlobalKey());
    }
  }

  void _computeOffsets() {
    if (!mounted || widget.comment.replies.isEmpty) return;

    final RenderBox? customPaintBox =
        _customPaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (customPaintBox == null || !customPaintBox.hasSize) {
      if (_isExpanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _computeOffsets());
      }
      return;
    }

    double parentCenterX = widget.isRootNode
        ? (widget.parentLeftPadding + widget.parentAvatarRadius)
        : widget.parentAvatarRadius;
    double parentAvatarBottomY = -widget.parentAvatarRadius - 4.0;

    final GlobalKey activeKey =
        (widget.avatarKey as GlobalKey?) ?? _localAvatarKey;
    final RenderBox? parentAvatarBox =
        activeKey.currentContext?.findRenderObject() as RenderBox?;
    if (parentAvatarBox != null && parentAvatarBox.hasSize) {
      final avatarCenterGlobal = parentAvatarBox.localToGlobal(
          Offset(parentAvatarBox.size.width / 2, parentAvatarBox.size.height));
      final localPoint = customPaintBox.globalToLocal(avatarCenterGlobal);
      parentCenterX = localPoint.dx;
      parentAvatarBottomY = localPoint.dy;
    }

    final List<double> newYOffsets = [];
    final List<double> newLeftXs = [];

    for (final key in _childAvatarKeys) {
      final RenderBox? childAvatarBox =
          key.currentContext?.findRenderObject() as RenderBox?;
      if (childAvatarBox != null && childAvatarBox.hasSize) {
        final childLeftTopGlobal = childAvatarBox.localToGlobal(Offset.zero);
        final localLeftTop = customPaintBox.globalToLocal(childLeftTopGlobal);
        final centerY = localLeftTop.dy + (childAvatarBox.size.height / 2);
        final leftX = localLeftTop.dx;

        newYOffsets.add(centerY);
        newLeftXs.add(leftX);
      }
    }

    if (newYOffsets.isNotEmpty) {
      if (_childAvatarCenterYOffsets != newYOffsets ||
          _childAvatarLeftXs != newLeftXs ||
          _parentAvatarBottomY != parentAvatarBottomY ||
          _parentCenterX != parentCenterX) {
        setState(() {
          _childAvatarCenterYOffsets = newYOffsets;
          _childAvatarLeftXs = newLeftXs;
          _parentAvatarBottomY = parentAvatarBottomY;
          _parentCenterX = parentCenterX;
        });
      }
    }

    if (newYOffsets.length < widget.comment.replies.length && _isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _computeOffsets());
    }
  }

  Widget _buildShowRepliesRow(BuildContext context) {
    final List<String> avatarUrls = [];
    final List<String> authorNames = [];

    for (final child in widget.comment.replies) {
      if (!authorNames.contains(child.authorName)) {
        authorNames.add(child.authorName);
        avatarUrls.add(child.authorAvatarUrl);
      }
      if (avatarUrls.length >= 3) break;
    }

    final double stackWidth = avatarUrls.isEmpty
        ? 22.0
        : (22.0 + (avatarUrls.length - 1) * 12.0);

    final double leftPadding = widget.isRootNode
        ? widget.parentLeftPadding + 14.0
        : 14.0;

    return Padding(
      padding: EdgeInsets.only(left: leftPadding, top: 4.0, bottom: 8.0),
      child: InkWell(
        onTap: () {
          if (!widget.isRootNode && !widget.allowNestedExpansion) {
            widget.onCommentTap?.call(widget.comment);
            return;
          }
          setState(() {
            _isExpanded = true;
          });
          _startAnimationFrameSync();
        },
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Stack of overlapping mini avatars
              SizedBox(
                width: stackWidth,
                height: 22.0,
                child: Stack(
                  children: List.generate(avatarUrls.length, (i) {
                    final url = avatarUrls[i];
                    final name = authorNames[i];
                    return Positioned(
                      left: i * 12.0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).canvasColor,
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 9.5,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                          backgroundImage:
                              url.isNotEmpty ? NetworkImage(url) : null,
                          child: url.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 8.0),

              // Curved / down icon
              Icon(
                Icons.south_west_rounded,
                size: 13.0,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
              const SizedBox(width: 5.0),

              // Text
              Text(
                widget.comment.replies.length > 1
                    ? "Show ${widget.comment.replies.length} replies"
                    : "Show replies",
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65),
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasReplies = widget.comment.replies.isNotEmpty;
    final double currentRadius = widget.isRootNode
        ? widget.parentAvatarRadius
        : widget.childAvatarRadius;

    final itemKey = widget.itemKeys?.putIfAbsent(widget.comment.id, () => GlobalKey());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Parent / Current Comment Item
        KeyedSubtree(
          key: itemKey,
          child: _buildCommentItem(
            context: context,
            node: widget.comment,
            avatarRadius: currentRadius,
          ),
        ),

        // Replies Tree wrapped in AnimatedSize for smooth expansion/contraction animation
        if (hasReplies)
          AnimatedSize(
            duration: _animDuration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: KeyedSubtree(
              key: ValueKey(_isExpanded),
              child: !_isExpanded
                  ? _buildShowRepliesRow(context)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(
                          key: _customPaintKey,
                          painter: ThreadLinePainter(
                            parentAvatarRadius: currentRadius,
                            childAvatarRadius: widget.childAvatarRadius,
                            indentationWidth: widget.indentationWidth,
                            parentLeftPadding: widget.parentLeftPadding,
                            lineColor: widget.lineColor,
                            strokeWidth: widget.strokeWidth,
                            curveRadius: widget.curveRadius,
                            childAvatarCenterYOffsets: _childAvatarCenterYOffsets,
                            childAvatarLeftXs: _childAvatarLeftXs,
                            isLastChildChain: widget.isLastChildChain,
                            isRootNode: widget.isRootNode,
                            parentCenterX: _parentCenterX,
                            parentAvatarBottomY: _parentAvatarBottomY,
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(left: widget.indentationWidth),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(widget.comment.replies.length, (index) {
                                final childNode = widget.comment.replies[index];
                                final isLast = (index == widget.comment.replies.length - 1);

                                return _ThreadNodeWidget(
                                  key: ValueKey(childNode.id),
                                  avatarKey: _childAvatarKeys[index],
                                  comment: childNode,
                                  parentAvatarRadius: widget.parentAvatarRadius,
                                  childAvatarRadius: widget.childAvatarRadius,
                                  indentationWidth: widget.indentationWidth,
                                  parentLeftPadding: widget.parentLeftPadding,
                                  lineColor: widget.lineColor,
                                  strokeWidth: widget.strokeWidth,
                                  curveRadius: widget.curveRadius,
                                  allowNestedExpansion: widget.allowNestedExpansion,
                                  initialExpandPostId: widget.initialExpandPostId,
                                  itemKeys: widget.itemKeys,
                                  onReplyTap: widget.onReplyTap,
                                  onCommentTap: widget.onCommentTap,
                                  onReactionToggle: widget.onReactionToggle,
                                  onExpansionChanged: () {
                                    _startAnimationFrameSync();
                                  },
                                  isRootNode: false,
                                  isLastChildChain: isLast,
                                );
                              }),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            left: widget.isRootNode
                                ? widget.parentLeftPadding + 14.0
                                : widget.indentationWidth + 14.0,
                            top: 2.0,
                            bottom: 8.0,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isExpanded = false;
                              });
                              _startAnimationFrameSync();
                            },
                            borderRadius: BorderRadius.circular(12.0),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    size: 14.0,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    "Hide replies",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w600,
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
        if (widget.isRootNode)
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
      ],
    );
  }

  Widget _buildCommentItem({
    required BuildContext context,
    required CommentNode node,
    required double avatarRadius,
  }) {
    final Key activeKey = (widget.avatarKey as GlobalKey?) ?? _localAvatarKey;

    // 1. Full PostCard UI if original FeedPost reference is attached
    if (node.post != null) {
      final bool isHighlighted = (widget.initialExpandPostId == node.id);
      return PostCard(
        post: node.post!,
        isThreadView: false,
        isHighlighted: isHighlighted,
        avatarKey: activeKey,
        replyToName: node.replyToName,
        showBottomBorder: false,
        onTap: () => widget.onReplyTap?.call(node),
        onCommentTap: () => widget.onCommentTap?.call(node),
        onReactionToggle: widget.onReactionToggle,
      );
    }

    // 2. Custom Rich Card fallback layout with mentions and badges
    if (node.isDeleted) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(
        left: widget.isRootNode ? widget.parentLeftPadding : 0.0,
        right: 16.0,
        top: 6.0,
        bottom: 6.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Avatar wrapped with activeKey for RenderBox tracking
          KeyedSubtree(
            key: activeKey,
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor:
                  Theme.of(context).primaryColor.withValues(alpha: 0.2),
              backgroundImage: node.authorAvatarUrl.isNotEmpty
                  ? NetworkImage(node.authorAvatarUrl)
                  : null,
              child: node.authorAvatarUrl.isEmpty
                  ? Text(
                      node.authorName.isNotEmpty
                          ? node.authorName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: avatarRadius * 0.75,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10.0),

          // Comment Body
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (node.replyToName != null &&
                    node.replyToName!.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.reply_rounded,
                          size: 12,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Builder(builder: (context) {
                          final profileProvider = Provider.of<ProfileProvider>(context);
                          final myName = profileProvider.name.trim();
                          final bool isReplyingToMe = (myName.isNotEmpty &&
                              node.replyToName != null &&
                              node.replyToName!.trim().toLowerCase() == myName.toLowerCase());
                          return Text.rich(
                            TextSpan(
                              text: "Replying to ",
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                              children: [
                                TextSpan(
                                  text: isReplyingToMe ? "@Me" : "@${node.replyToName}",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                // Header (Author Name + Timestamp + Options)
                Row(
                  children: [
                    Text(
                      node.authorName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.0,
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    Builder(builder: (context) {
                      final profileProvider = Provider.of<ProfileProvider>(context);
                      final feedProvider = Provider.of<FeedProvider>(context, listen: false);
                      final myUserId = profileProvider.userId ?? feedProvider.viewerId ?? 0;
                      final myName = profileProvider.name.trim().toLowerCase();
                      final nodeName = node.authorName.trim().toLowerCase();
                      final isMe = (myUserId != 0 && node.authorId == myUserId) ||
                          (myName.isNotEmpty && nodeName.isNotEmpty && myName == nodeName);
                      final isAuthorMe = isMe || node.degree == 0;
                      final String badgeText = isAuthorMe
                          ? "You"
                          : (node.degree == 1
                              ? "1°"
                              : (node.degree == 2
                                  ? "2°"
                                  : (node.degree >= 3 ? "3°" : "")));

                      if (badgeText.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 11.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }),
                    Text(
                      "• ${node.timestamp}",
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                        fontSize: 12.0,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.more_horiz_rounded,
                      size: 16.0,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ],
                ),
                const SizedBox(height: 3.0),

                // Main Content Text
                Text(
                  node.content,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.9),
                    fontSize: 14.0,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6.0),

                // Reply Action
                GestureDetector(
                  onTap: () => (widget.onCommentTap ?? widget.onReplyTap)?.call(node),
                  child: Text(
                    "Reply",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
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
}
