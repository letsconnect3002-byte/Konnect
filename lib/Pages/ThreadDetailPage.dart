import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/feed_post.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Widgets/post_card.dart';
import 'package:connect/Widgets/threaded_comment_tree.dart';

class ThreadDetailPage extends StatefulWidget {
  final String rootPostId;
  final String? highlightPostId;
  /// If provided, the reply input will initially target this post ID
  /// instead of the root post.
  final String? focusReplyToPostId;

  const ThreadDetailPage({
    super.key,
    required this.rootPostId,
    this.highlightPostId,
    this.focusReplyToPostId,
  });

  @override
  State<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends State<ThreadDetailPage> {
  final TextEditingController _replyController = TextEditingController();
  bool _isLoading = true;
  List<FeedPost> _threadPosts = [];
  FeedPost? _replyingToTarget;
  bool _hasSetInitialReplyTarget = false;
  bool _isSubmitting = false;
  RealtimeChannel? _threadChannel;

  String? _highlightedPostId;
  Timer? _highlightTimer;
  final Map<String, GlobalKey> _itemKeys = {};

  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _highlightedPostId = widget.highlightPostId;
    _loadThread();
    _subscribeToThreadRealtime();
  }

  void _subscribeToThreadRealtime() {
    final client = Supabase.instance.client;
    if (_threadChannel != null) {
      client.removeChannel(_threadChannel!);
      _threadChannel = null;
    }

    _threadChannel = client.channel('thread:${widget.rootPostId}');

    void handleReactionChange(String eventType, Map<String, dynamic> newRecord,
        Map<String, dynamic> oldRecord) {
      if (!mounted) return;
      final String targetPostId = newRecord['post_id']?.toString() ??
          oldRecord['post_id']?.toString() ??
          '';

      if (targetPostId.isEmpty) return;

      final index = _threadPosts.indexWhere((p) => p.id == targetPostId);
      if (index != -1) {
        final feedProvider = Provider.of<FeedProvider>(context, listen: false);
        final vId = feedProvider.viewerId;
        final updatedPost = applyReactionDelta(
          _threadPosts[index],
          eventType: eventType,
          newRecord: newRecord,
          oldRecord: oldRecord,
          viewerId: vId,
        );
        feedProvider.registerPost(updatedPost);
        setState(() {
          _threadPosts[index] = updatedPost;
        });
      }
    }

    _threadChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.rootPostId,
          ),
          callback: (payload) {
            if (mounted) _loadThread();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'root_post_id',
            value: widget.rootPostId,
          ),
          callback: (payload) {
            if (mounted) _loadThread();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'post_reactions',
          callback: (payload) {
            handleReactionChange(
              'INSERT',
              Map<String, dynamic>.from(payload.newRecord),
              Map<String, dynamic>.from(payload.oldRecord),
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'post_reactions',
          callback: (payload) {
            handleReactionChange(
              'UPDATE',
              Map<String, dynamic>.from(payload.newRecord),
              Map<String, dynamic>.from(payload.oldRecord),
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'post_reactions',
          callback: (payload) {
            handleReactionChange(
              'DELETE',
              Map<String, dynamic>.from(payload.newRecord),
              Map<String, dynamic>.from(payload.oldRecord),
            );
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    if (_threadChannel != null) {
      Supabase.instance.client.removeChannel(_threadChannel!);
    }
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    final currentRequestId = ++_loadRequestId;
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    try {
      final posts = await feedProvider.fetchThread(widget.rootPostId);
      if (mounted && currentRequestId == _loadRequestId) {
        setState(() {
          _threadPosts = posts;
          _isLoading = false;
          if (!_hasSetInitialReplyTarget && _threadPosts.isNotEmpty) {
            _hasSetInitialReplyTarget = true;
            // If a specific reply target was requested, find it in the thread
            if (widget.focusReplyToPostId != null) {
              final targetPost = _threadPosts
                  .where((p) => p.id == widget.focusReplyToPostId)
                  .firstOrNull;
              _replyingToTarget = targetPost ?? _threadPosts.first;
            } else {
              _replyingToTarget = _threadPosts.first; // Default reply to root post
            }
          }
        });

        // If a target post highlight is requested, scroll to it & fade highlight after 2.5s
        final targetId = _highlightedPostId;
        if (targetId != null && targetId.isNotEmpty) {
          _highlightTimer?.cancel();
          _highlightTimer = Timer(const Duration(milliseconds: 2500), () {
            if (mounted) {
              setState(() {
                _highlightedPostId = null;
              });
            }
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToHighlightedPost(targetId);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToHighlightedPost(String targetId, {int retryCount = 0}) {
    final targetKey = _itemKeys[targetId];
    if (targetKey != null && targetKey.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        alignment: 0.3,
      );
    } else if (retryCount < 5) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) {
          _scrollToHighlightedPost(targetId, retryCount: retryCount + 1);
        }
      });
    }
  }

  void _handleReactionToggle(String postId, String selectedKey) {
    setState(() {
      final idx = _threadPosts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        final oldPost = _threadPosts[idx];
        final String? oldUserReaction = oldPost.userReaction;
        final Map<String, int> newCounts =
            Map<String, int>.from(oldPost.reactionCounts);

        String? newUserReaction;
        if (oldUserReaction == selectedKey) {
          newUserReaction = null;
          if (newCounts.containsKey(selectedKey)) {
            final c = newCounts[selectedKey]!;
            if (c <= 1) {
              newCounts.remove(selectedKey);
            } else {
              newCounts[selectedKey] = c - 1;
            }
          }
        } else {
          if (oldUserReaction != null && newCounts.containsKey(oldUserReaction)) {
            final c = newCounts[oldUserReaction]!;
            if (c <= 1) {
              newCounts.remove(oldUserReaction);
            } else {
              newCounts[oldUserReaction] = c - 1;
            }
          }
          newUserReaction = selectedKey;
          newCounts[selectedKey] = (newCounts[selectedKey] ?? 0) + 1;
        }

        _threadPosts[idx] = oldPost.copyWith(
          userReaction: newUserReaction,
          nullifyUserReaction: newUserReaction == null,
          reactionCounts: newCounts,
        );
      }
    });

    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    feedProvider.toggleReaction(postId, reactionType: selectedKey).then((res) {
      if (res != null && mounted) {
        setState(() {
          final idx = _threadPosts.indexWhere((p) => p.id == postId);
          if (idx != -1) {
            final serverReaction = res['user_reaction']?.toString();
            final Map<String, int> serverCounts =
                Map<String, int>.from(res['reaction_counts'] as Map? ?? {});
            _threadPosts[idx] = _threadPosts[idx].copyWith(
              userReaction: serverReaction,
              nullifyUserReaction: serverReaction == null,
              reactionCounts: serverCounts,
            );
          }
        });
      }
    });
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }

  String _truncateContent(String content, int maxLen) {
    final trimmed = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.isEmpty) return '...';
    if (trimmed.length <= maxLen) return trimmed;
    // Try to break at last space within maxLen
    final lastSpace = trimmed.lastIndexOf(' ', maxLen);
    if (lastSpace > 0) {
      return '${trimmed.substring(0, lastSpace)}...';
    }
    return '${trimmed.substring(0, maxLen)}...';
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || text.length > 500 || _isSubmitting) return;

    final target = _replyingToTarget ?? (_threadPosts.isNotEmpty ? _threadPosts.first : null);
    if (target == null) return;

    setState(() {
      _isSubmitting = true;
    });

    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);

    final String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempPost = FeedPost(
      id: tempId,
      authorId: profileProvider.userId ?? 0,
      authorName: profileProvider.name,
      authorAvatarUrl: profileProvider.avatarUrl,
      content: text,
      createdAt: DateTime.now(),
      replyCount: 0,
      degree: 0,
      replyToPostId: target.id,
    );

    // Optimistic UI addition
    setState(() {
      _threadPosts.add(tempPost);
      _replyController.clear();
    });

    try {
      final realPost = await feedProvider.createPost(
        text,
        authorName: profileProvider.name,
        authorAvatarUrl: profileProvider.avatarUrl,
        replyToPostId: target.id,
        connections: connectionProvider.connections,
      );

      if (mounted) {
        setState(() {
          final index = _threadPosts.indexWhere((p) => p.id == tempId);
          if (index != -1) {
            _threadPosts[index] = realPost.copyWith(replyToPostId: target.id);
          }
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _threadPosts.removeWhere((p) => p.id == tempId);
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to send reply."), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String? _resolveParentAuthorName(String? parentId) {
    if (parentId == null || parentId.isEmpty) return null;
    final parent = _threadPosts.firstWhere(
      (p) => p.id == parentId,
      orElse: () => FeedPost(
        id: '',
        authorId: 0,
        authorName: '',
        authorAvatarUrl: '',
        content: '',
        createdAt: DateTime.now(),
        replyCount: 0,
        degree: 0,
      ),
    );
    return parent.id.isNotEmpty ? parent.authorName : null;
  }

  CommentNode _buildNode(FeedPost post, Map<String, List<FeedPost>> childrenMap) {
    final children = childrenMap[post.id] ?? [];
    final activeChildCount = children.where((c) => !c.isDeleted).length;
    final effectiveReplyCount = activeChildCount;
    final updatedPost = post.copyWith(
      replyCount: effectiveReplyCount,
      activeReplyCount: effectiveReplyCount,
    );

    final String? replyToName = post.replyToPostId != null
        ? _resolveParentAuthorName(post.replyToPostId)
        : null;

    return CommentNode(
      id: post.id,
      authorId: post.authorId,
      authorName: post.authorName,
      authorAvatarUrl: post.authorAvatarUrl,
      content: post.isDeleted ? "This post was removed" : post.content,
      timestamp: _formatTimeAgo(post.createdAt),
      degree: post.degree,
      replyCount: effectiveReplyCount,
      isDeleted: post.isDeleted,
      replyToName: replyToName,
      post: updatedPost,
      replies: children.map((c) => _buildNode(c, childrenMap)).toList(),
    );
  }

  List<CommentNode> _buildThreadTrees() {
    if (_threadPosts.length <= 1) return [];

    final rootId = widget.rootPostId;
    final activeReplyPosts = _threadPosts.sublist(1).where((p) => !p.isDeleted).toList();
    if (activeReplyPosts.isEmpty) return [];

    final Map<String, List<FeedPost>> childrenMap = {};

    for (final post in activeReplyPosts) {
      final String parentId;
      if (post.replyToPostId != null && post.replyToPostId!.isNotEmpty) {
        parentId = post.replyToPostId!;
      } else {
        parentId = rootId;
      }
      childrenMap.putIfAbsent(parentId, () => []).add(post);
    }

    final topLevelReplies = childrenMap[rootId] ?? activeReplyPosts.where((p) => p.replyToPostId == null || p.replyToPostId == rootId).toList();
    return topLevelReplies.map((p) => _buildNode(p, childrenMap)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final activeRepliesCount = _threadPosts.where((p) => p.id != widget.rootPostId && !p.isDeleted).length;
    final commentTrees = _buildThreadTrees();

    return Scaffold(
      backgroundColor: context.canvasBackground,
      appBar: AppBar(
        backgroundColor: context.canvasBackground,
        elevation: 0,
        title: Text("Thread", style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Standalone Top Main Post
                        if (_threadPosts.isNotEmpty) ...[
                          Builder(builder: (context) {
                            final rootPost = _threadPosts.first;
                            final bool isSelected = (_replyingToTarget?.id == rootPost.id);
                            final bool isHighlighted = (rootPost.id == _highlightedPostId);

                            final rootPostWithActiveCount = FeedPost(
                              id: rootPost.id,
                              authorId: rootPost.authorId,
                              authorName: rootPost.authorName,
                              authorAvatarUrl: rootPost.authorAvatarUrl,
                              content: rootPost.content,
                              createdAt: rootPost.createdAt,
                              replyCount: activeRepliesCount,
                              degree: rootPost.degree,
                              isDeleted: rootPost.isDeleted,
                              replyToPostId: rootPost.replyToPostId,
                              userReaction: rootPost.userReaction,
                              reactionCounts: rootPost.reactionCounts,
                            );

                            return Container(
                              key: _itemKeys.putIfAbsent(rootPost.id, () => GlobalKey()),
                              child: PostCard(
                                post: rootPostWithActiveCount,
                                isThreadView: false,
                                isSelectedTarget: isSelected,
                                isHighlighted: isHighlighted,
                                onReactionToggle: _handleReactionToggle,
                                onTap: () {
                                  setState(() {
                                    _replyingToTarget = rootPost;
                                  });
                                },
                                onCommentTap: () {
                                  setState(() {
                                    _replyingToTarget = rootPost;
                                  });
                                },
                              ),
                            );
                          }),

                          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

                          // 2. Separate Replies Header
                          if (activeRepliesCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 16, top: 16, bottom: 12),
                              child: Text(
                                "Replies ($activeRepliesCount)",
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],

                        // 3. Separate Replies List (ThreadedCommentTree for top-level replies and their children)
                        if (commentTrees.isNotEmpty)
                          Column(
                            children: commentTrees.map((treeNode) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12.0),
                                child: ThreadedCommentTree(
                                  comment: treeNode,
                                  parentAvatarRadius: 18.0,
                                  childAvatarRadius: 14.0,
                                  indentationWidth: 48.0,
                                  parentLeftPadding: 16.0,
                                  lineColor: const Color(0xFF3E414D),
                                  strokeWidth: 1.8,
                                  curveRadius: 12.0,
                                  initialExpandPostId: _highlightedPostId,
                                  itemKeys: _itemKeys,
                                  allowNestedExpansion: false,
                                  onReactionToggle: _handleReactionToggle,
                                  onReplyTap: (node) {
                                    if (node.replyCount > 0 || node.replies.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ThreadDetailPage(
                                            rootPostId: node.id,
                                            highlightPostId: node.id,
                                            focusReplyToPostId: node.id,
                                          ),
                                        ),
                                      );
                                    } else {
                                      final targetPost = node.post ?? _threadPosts.firstWhere(
                                        (p) => p.id == node.id,
                                        orElse: () => FeedPost(
                                          id: node.id,
                                          authorId: node.authorId,
                                          authorName: node.authorName,
                                          authorAvatarUrl: node.authorAvatarUrl,
                                          content: node.content,
                                          createdAt: DateTime.now(),
                                          replyCount: node.replyCount,
                                          degree: node.degree,
                                        ),
                                      );
                                      setState(() {
                                        _replyingToTarget = targetPost;
                                      });
                                    }
                                  },
                                  onCommentTap: (node) {
                                    if (node.replyCount > 0 || node.replies.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ThreadDetailPage(
                                            rootPostId: node.id,
                                            highlightPostId: node.id,
                                            focusReplyToPostId: node.id,
                                          ),
                                        ),
                                      );
                                    } else {
                                      final targetPost = node.post ?? _threadPosts.firstWhere(
                                        (p) => p.id == node.id,
                                        orElse: () => FeedPost(
                                          id: node.id,
                                          authorId: node.authorId,
                                          authorName: node.authorName,
                                          authorAvatarUrl: node.authorAvatarUrl,
                                          content: node.content,
                                          createdAt: DateTime.now(),
                                          replyCount: node.replyCount,
                                          degree: node.degree,
                                        ),
                                      );
                                      setState(() {
                                        _replyingToTarget = targetPost;
                                      });
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),

                // Inline Reply Bar
                Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 10,
                    bottom: 10 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfacePrimary,
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyingToTarget != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  "Replying to @${_replyingToTarget!.authorName} for \"${_truncateContent(_replyingToTarget!.content, 30)}\"",
                                  style: TextStyle(color: context.accentSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _replyingToTarget = _threadPosts.isNotEmpty ? _threadPosts.first : null;
                                  });
                                },
                                child: Icon(Icons.close_rounded, size: 14, color: context.textMuted),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _replyController,
                              maxLines: null,
                              maxLength: 500,
                              style: TextStyle(color: context.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: "Post your reply...",
                                hintStyle: TextStyle(color: context.textMuted, fontSize: 13),
                                counterText: "",
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _replyController,
                            builder: (context, value, child) {
                              final textLength = value.text.trim().length;
                              final isValid = textLength > 0 && textLength <= 500 && !_isSubmitting;

                              return IconButton(
                                icon: _isSubmitting
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Icon(Icons.send_rounded, color: isValid ? context.accentPrimary : context.textMuted),
                                onPressed: isValid ? _submitReply : null,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
