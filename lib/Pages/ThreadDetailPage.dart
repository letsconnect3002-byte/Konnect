import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/feed_post.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Widgets/post_card.dart';
import 'package:connect/Widgets/threaded_comment_tree.dart';
import 'package:connect/services/analytics_service.dart';

class _MentionTextEditingController extends TextEditingController {
  Color accentColor;
  List<String> connectionNames;

  _MentionTextEditingController({
    required this.accentColor,
    required this.connectionNames,
    String? text,
  }) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final textVal = text;
    if (textVal.isEmpty) {
      return TextSpan(style: style);
    }

    final sortedNames = List<String>.from(connectionNames)
      ..sort((a, b) => b.length.compareTo(a.length));
    final escapedNames = sortedNames.map((n) => RegExp.escape(n)).join('|');

    final String pattern = escapedNames.isNotEmpty
        ? r'@(' + escapedNames + r'|[A-Za-z0-9_\-\.]+)'
        : r'@[A-Za-z0-9_\-\.]+';

    final RegExp mentionRegex = RegExp(pattern, caseSensitive: false);
    final matches = mentionRegex.allMatches(textVal);

    final List<InlineSpan> children = [];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        children.add(TextSpan(
          text: textVal.substring(lastIndex, match.start),
          style: style,
        ));
      }

      children.add(TextSpan(
        text: match.group(0),
        style: style?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ) ??
            TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
      ));

      lastIndex = match.end;
    }

    if (lastIndex < textVal.length) {
      children.add(TextSpan(
        text: textVal.substring(lastIndex),
        style: style,
      ));
    }

    return TextSpan(style: style, children: children);
  }
}

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
  late final _MentionTextEditingController _replyController;
  final FocusNode _replyFocusNode = FocusNode();
  bool _isLoading = true;
  List<FeedPost> _threadPosts = [];
  FeedPost? _replyingToTarget;
  bool _hasSetInitialReplyTarget = false;
  bool _isSubmitting = false;
  RealtimeChannel? _threadChannel;

  late String _currentRootPostId;
  String? _highlightedPostId;
  Timer? _highlightTimer;
  final Map<String, GlobalKey> _itemKeys = {};

  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _currentRootPostId = widget.rootPostId;
    _replyController = _MentionTextEditingController(
      accentColor: const Color(0xFF6366F1),
      connectionNames: [],
    );
    _replyController.addListener(() {
      if (mounted) setState(() {});
    });
    _highlightedPostId = widget.highlightPostId;
    _loadThread();
    _subscribeToThreadRealtime();
    AnalyticsService.logEvent(
      name: 'thread_opened',
      parameters: {'root_post_id': widget.rootPostId},
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    final names = connectionProvider.connections
        .map((c) => (c['name'] ?? '').toString().trim())
        .where((n) => n.isNotEmpty)
        .toList();
    _replyController.connectionNames = names;
    _replyController.accentColor = context.accentPrimary;
  }

  void _subscribeToThreadRealtime() {
    final client = Supabase.instance.client;
    if (_threadChannel != null) {
      client.removeChannel(_threadChannel!);
      _threadChannel = null;
    }

    _threadChannel = client.channel('thread:$_currentRootPostId');

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
            value: _currentRootPostId,
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
            value: _currentRootPostId,
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
    _replyFocusNode.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    final currentRequestId = ++_loadRequestId;
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    try {
      var posts = await feedProvider.fetchThread(_currentRootPostId);

      // If a nested reply was highlighted, resolve its immediate parent as the sub-thread root
      if (widget.highlightPostId != null &&
          widget.highlightPostId!.isNotEmpty &&
          widget.highlightPostId != _currentRootPostId) {
        final targetPost =
            posts.where((p) => p.id == widget.highlightPostId).firstOrNull;

        if (targetPost != null &&
            targetPost.replyToPostId != null &&
            targetPost.replyToPostId!.isNotEmpty &&
            targetPost.replyToPostId != _currentRootPostId) {
          final parentId = targetPost.replyToPostId!;
          final subPosts = await feedProvider.fetchThread(parentId);
          if (subPosts.isNotEmpty) {
            posts = subPosts;
            _currentRootPostId = parentId;
          }
        }
      }

      if (mounted && currentRequestId == _loadRequestId) {
        setState(() {
          _threadPosts = posts;
          _isLoading = false;
          if (!_hasSetInitialReplyTarget && _threadPosts.isNotEmpty) {
            _hasSetInitialReplyTarget = true;
            if (widget.focusReplyToPostId != null) {
              final targetPost = _threadPosts
                  .where((p) => p.id == widget.focusReplyToPostId)
                  .firstOrNull;
              _replyingToTarget = targetPost ?? _threadPosts.first;
            } else if (_highlightedPostId != null) {
              final targetPost = _threadPosts
                  .where((p) => p.id == _highlightedPostId)
                  .firstOrNull;
              _replyingToTarget = targetPost ?? _threadPosts.first;
            } else {
              _replyingToTarget = _threadPosts.first;
            }
          }
        });

        // If a target post highlight is requested, scroll to it & fade highlight after 3.0s
        final targetId = _highlightedPostId;
        if (targetId != null && targetId.isNotEmpty) {
          _highlightTimer?.cancel();
          _highlightTimer = Timer(const Duration(milliseconds: 3000), () {
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
    } else if (retryCount < 8) {
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
      visibility: target.visibility,
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
        visibility: target.visibility,
      );
      AnalyticsService.logEvent(
        name: 'thread_reply_submitted',
        parameters: {
          'root_post_id': _currentRootPostId,
          'reply_to_post_id': target.id,
          'is_nested': target.id != _currentRootPostId ? 1 : 0,
          'visibility': target.visibility,
          'char_count': text.length,
        },
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

    final rootId = _currentRootPostId;
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
    final activeRepliesCount = _threadPosts.where((p) => p.id != _currentRootPostId && !p.isDeleted).length;
    final commentTrees = _buildThreadTrees();

    final connectionProvider = Provider.of<ConnectionProvider>(context);
    final connections = connectionProvider.connections;

    // Mention detection
    final replyText = _replyController.text;
    final cursorPos = _replyController.selection.baseOffset;
    String mentionQuery = '';
    int atIndex = -1;
    List<Map<String, dynamic>> mentionSuggestions = [];

    if (cursorPos > 0 && cursorPos <= replyText.length) {
      final textBeforeCursor = replyText.substring(0, cursorPos);
      atIndex = textBeforeCursor.lastIndexOf('@');
      if (atIndex != -1) {
        if (atIndex == 0 ||
            RegExp(r'\s').hasMatch(textBeforeCursor[atIndex - 1])) {
          mentionQuery = textBeforeCursor.substring(atIndex + 1);
          if (!mentionQuery.contains('\n')) {
            final q = mentionQuery.toLowerCase();
            mentionSuggestions = connections
                .where((c) {
                  final name = (c['name'] ?? '').toString().toLowerCase();
                  return name.contains(q);
                })
                .take(5)
                .toList();
          }
        }
      }
    }

    void insertMention(Map<String, dynamic> conn) {
      HapticFeedback.lightImpact();
      final name = conn['name']?.toString() ?? 'User';
      final String replacement = "@$name ";
      final String currentText = _replyController.text;
      final String newText =
          currentText.replaceRange(atIndex, cursorPos, replacement);
      _replyController.text = newText;
      final newCursorPos = atIndex + replacement.length;
      _replyController.selection =
          TextSelection.collapsed(offset: newCursorPos);
      setState(() {});
    }

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
                                  _replyFocusNode.requestFocus();
                                },
                                onCommentTap: () {
                                  setState(() {
                                    _replyingToTarget = rootPost;
                                  });
                                  _replyFocusNode.requestFocus();
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
                                      _replyFocusNode.requestFocus();
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
                                      _replyFocusNode.requestFocus();
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
                      if (mentionSuggestions.isNotEmpty) ...[
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: context.surfaceSecondary,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                  color: context.accentPrimary.withValues(alpha: 0.4)),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: mentionSuggestions.length,
                              separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.06)),
                              itemBuilder: (context, idx) {
                                final conn = mentionSuggestions[idx];
                                final name = conn['name']?.toString() ?? 'User';
                                final avatarUrl = conn['avatarUrl']?.toString() ??
                                    conn['avatar_url']?.toString() ??
                                    '';
                                final profession =
                                    conn['profession']?.toString() ?? '';

                                return ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: context.accentPrimary,
                                    backgroundImage: avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl.isEmpty
                                        ? Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                fontSize: 12, color: Colors.white))
                                        : null,
                                  ),
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: profession.isNotEmpty
                                      ? Text(
                                          profession,
                                          style: TextStyle(
                                              color: context.textMuted,
                                              fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : null,
                                  onTap: () => insertMention(conn),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
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
                              focusNode: _replyFocusNode,
                              maxLines: null,
                              maxLength: 500,
                              style: TextStyle(color: context.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: "Post your reply... Use @ to mention",
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
