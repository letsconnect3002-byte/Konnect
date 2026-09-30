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
import 'package:connect/Widgets/anonymous_avatar.dart';
import 'package:connect/Widgets/discord_network_view_toggle.dart';
import 'package:connect/Widgets/user_profile_modal.dart';
import 'package:connect/Widgets/link_preview_card.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/Widgets/referral_intro_sheet.dart';
import 'package:connect/Widgets/direct_connection_sheet.dart';

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

  /// If provided, isolates this post as the head of an independent sub-thread.
  final String? independentPostId;

  /// True if pushed from another ThreadDetailPage
  final bool openedFromThread;

  const ThreadDetailPage({
    super.key,
    required this.rootPostId,
    this.highlightPostId,
    this.focusReplyToPostId,
    this.independentPostId,
    this.openedFromThread = false,
  });

  @override
  State<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends State<ThreadDetailPage> {
  late final _MentionTextEditingController _replyController;
  final FocusNode _replyFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _focusedPostKey = GlobalKey();
  bool _hasScrolledToFocusedPost = false;
  bool _isLoading = true;
  List<FeedPost> _threadPosts = [];
  List<FeedPost> _parentPosts = [];
  FeedPost? _replyingToTarget;
  bool _hasSetInitialReplyTarget = false;
  bool _isSubmitting = false;
  bool _isAnonymousReply = false;
  RealtimeChannel? _threadChannel;
  StreamSubscription? _postUpdateSub;

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
      accentColor: const Color(0xFFFFFFFF),
      connectionNames: [],
    );
    _replyController.addListener(() {
      if (mounted) setState(() {});
    });
    _highlightedPostId = null;
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
    _replyController.accentColor = context.accentSecondary;
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
      } else {
        final pIndex = _parentPosts.indexWhere((p) => p.id == targetPostId);
        if (pIndex != -1) {
          final feedProvider = Provider.of<FeedProvider>(context, listen: false);
          final vId = feedProvider.viewerId;
          final updatedPost = applyReactionDelta(
            _parentPosts[pIndex],
            eventType: eventType,
            newRecord: newRecord,
            oldRecord: oldRecord,
            viewerId: vId,
          );
          feedProvider.registerPost(updatedPost);
          setState(() {
            _parentPosts[pIndex] = updatedPost;
          });
        }
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
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'reply_to_post_id',
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

    _postUpdateSub?.cancel();
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    _postUpdateSub = feedProvider.postUpdateStream.listen((payload) {
      if (!mounted) return;
      final table = payload['table']?.toString();
      final eventType = payload['eventType']?.toString().toLowerCase() ?? '';
      final newRecord = Map<String, dynamic>.from(payload['new'] ?? {});
      final oldRecord = Map<String, dynamic>.from(payload['old'] ?? {});

      if (table == 'posts') {
        final targetId = (newRecord['id'] ?? oldRecord['id'])?.toString() ?? '';
        final rootId = (newRecord['root_post_id'] ?? oldRecord['root_post_id'])?.toString();
        final replyToId = (newRecord['reply_to_post_id'] ?? oldRecord['reply_to_post_id'])?.toString();

        final bool isRelated = targetId == _currentRootPostId ||
            rootId == _currentRootPostId ||
            replyToId == _currentRootPostId ||
            _threadPosts.any((p) => p.id == targetId || p.id == rootId || p.id == replyToId) ||
            _parentPosts.any((p) => p.id == targetId);

        if (isRelated) {
          if (eventType == 'insert' || eventType == 'delete') {
            _loadThread();
          } else if (eventType == 'update') {
            final index = _threadPosts.indexWhere((p) => p.id == targetId);
            final pIndex = _parentPosts.indexWhere((p) => p.id == targetId);
            if (index != -1 || pIndex != -1) {
              final int? replyCount = newRecord['reply_count'] is int
                  ? newRecord['reply_count'] as int
                  : int.tryParse(newRecord['reply_count']?.toString() ?? '');
              final rawCounts = newRecord['reaction_counts'];
              final Map<String, int> updatedCounts = {};
              if (rawCounts is Map) {
                rawCounts.forEach((k, v) {
                  final c = (v is num) ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? 0);
                  if (c > 0) updatedCounts[k.toString()] = c;
                });
              }
              setState(() {
                if (index != -1) {
                  _threadPosts[index] = _threadPosts[index].copyWith(
                    reactionCounts: updatedCounts.isNotEmpty ? updatedCounts : _threadPosts[index].reactionCounts,
                    replyCount: replyCount ?? _threadPosts[index].replyCount,
                    activeReplyCount: replyCount ?? _threadPosts[index].activeReplyCount,
                  );
                }
                if (pIndex != -1) {
                  _parentPosts[pIndex] = _parentPosts[pIndex].copyWith(
                    reactionCounts: updatedCounts.isNotEmpty ? updatedCounts : _parentPosts[pIndex].reactionCounts,
                    replyCount: replyCount ?? _parentPosts[pIndex].replyCount,
                    activeReplyCount: replyCount ?? _parentPosts[pIndex].activeReplyCount,
                  );
                }
              });
            } else {
              _loadThread();
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _postUpdateSub?.cancel();
    if (_threadChannel != null) {
      Supabase.instance.client.removeChannel(_threadChannel!);
    }
    _replyFocusNode.dispose();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    final currentRequestId = ++_loadRequestId;
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    try {
      final rawPosts = await feedProvider.fetchThread(widget.rootPostId);
      List<FeedPost> posts = rawPosts;
      List<FeedPost> parents = [];

      // Determine what is the focused target post
      FeedPost? targetPost;
      if (widget.independentPostId != null &&
          widget.independentPostId!.isNotEmpty &&
          rawPosts.isNotEmpty) {
        targetPost =
            rawPosts.where((p) => p.id == widget.independentPostId).firstOrNull;
      } else if (widget.highlightPostId != null &&
          widget.highlightPostId!.isNotEmpty &&
          widget.highlightPostId != widget.rootPostId &&
          rawPosts.isNotEmpty) {
        final hlPost =
            rawPosts.where((p) => p.id == widget.highlightPostId).firstOrNull;
        if (hlPost != null &&
            hlPost.replyToPostId != null &&
            hlPost.replyToPostId!.isNotEmpty &&
            hlPost.replyToPostId != rawPosts.first.id) {
          targetPost = rawPosts.where((p) => p.id == hlPost.replyToPostId).firstOrNull;
        }
      }

      // 1. Explicit or highlighted independent sub-thread requested
      if (targetPost != null) {
        // Trace ancestor parents of targetPost up to root
        String? curParentId = targetPost.replyToPostId;
        final Set<String> visitedParentIds = {targetPost.id};
        while (curParentId != null && curParentId.isNotEmpty && !visitedParentIds.contains(curParentId)) {
          visitedParentIds.add(curParentId);
          FeedPost? parent = rawPosts.where((p) => p.id == curParentId).firstOrNull;
          parent ??= feedProvider.getPostById(curParentId);
          if (parent == null) {
            try {
              parent = await feedProvider.fetchPostById(curParentId);
            } catch (_) {}
          }
          if (parent != null) {
            parents.insert(0, parent); // Root at index 0, immediate parent at the end
            curParentId = parent.replyToPostId;
          } else {
            break;
          }
        }

        final Set<String> subThreadIds = {targetPost.id};
        bool addedMore = true;
        while (addedMore) {
          addedMore = false;
          for (final p in rawPosts) {
            if (p.replyToPostId != null &&
                subThreadIds.contains(p.replyToPostId) &&
                !subThreadIds.contains(p.id)) {
              subThreadIds.add(p.id);
              addedMore = true;
            }
          }
        }

        final List<FeedPost> subPosts = [targetPost];
        for (final p in rawPosts) {
          if (p.id != targetPost.id && subThreadIds.contains(p.id)) {
            subPosts.add(p);
          }
        }
        posts = subPosts;
        _currentRootPostId = targetPost.id;
      } else if (rawPosts.isNotEmpty &&
          rawPosts.first.replyToPostId != null &&
          rawPosts.first.replyToPostId!.isNotEmpty) {
        // The root post itself is a reply to an external parent post!
        final root = rawPosts.first;
        String? curParentId = root.replyToPostId;
        final Set<String> visitedParentIds = {root.id};
        while (curParentId != null && curParentId.isNotEmpty && !visitedParentIds.contains(curParentId)) {
          visitedParentIds.add(curParentId);
          FeedPost? parent = rawPosts.where((p) => p.id == curParentId).firstOrNull;
          parent ??= feedProvider.getPostById(curParentId);
          if (parent == null) {
            try {
              parent = await feedProvider.fetchPostById(curParentId);
            } catch (_) {}
          }
          if (parent != null) {
            parents.insert(0, parent);
            curParentId = parent.replyToPostId;
          } else {
            break;
          }
        }
      }

      if (mounted && currentRequestId == _loadRequestId) {
        setState(() {
          _threadPosts = posts;
          _parentPosts = parents;
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

        // If a target post highlight is requested, scroll to it & subtly fade highlight
        final targetId = widget.highlightPostId;
        if (targetId != null && targetId.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted) {
                _scrollToHighlightedPost(targetId);
              }
            });
          });
        }

        // Align focused reply post at the top so parent posts are revealed when pulling down / scrolling up
        if (!_hasScrolledToFocusedPost && _parentPosts.isNotEmpty && widget.highlightPostId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToFocusedPost();
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

  void _scrollToFocusedPost({int retryCount = 0}) {
    if (!mounted || _hasScrolledToFocusedPost) return;
    if (_parentPosts.isEmpty) {
      _hasScrolledToFocusedPost = true;
      return;
    }
    final ctx = _focusedPostKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: Duration.zero,
        alignment: 0.0,
      );
      _hasScrolledToFocusedPost = true;
    } else if (retryCount < 10) {
      Future.delayed(const Duration(milliseconds: 30), () {
        if (mounted && !_hasScrolledToFocusedPost) {
          _scrollToFocusedPost(retryCount: retryCount + 1);
        }
      });
    }
  }

  void _scrollToHighlightedPost(String targetId, {int retryCount = 0}) {
    if (retryCount == 0) {
      HapticFeedback.lightImpact();
      if (mounted) {
        setState(() {
          _highlightedPostId = targetId;
        });

        _highlightTimer?.cancel();
        _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
          if (mounted && _highlightedPostId == targetId) {
            setState(() {
              _highlightedPostId = null;
            });
          }
        });
      }
    }

    final targetKey = _itemKeys[targetId];
    if (targetKey != null && targetKey.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey.currentContext!,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
    } else if (retryCount < 12) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollToHighlightedPost(targetId, retryCount: retryCount + 1);
        }
      });
    }
  }

  void _handleReactionToggle(String postId, String selectedKey) {
    FeedPost updateReactions(FeedPost oldPost) {
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

      return oldPost.copyWith(
        userReaction: newUserReaction,
        nullifyUserReaction: newUserReaction == null,
        reactionCounts: newCounts,
      );
    }

    setState(() {
      final idx = _threadPosts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        _threadPosts[idx] = updateReactions(_threadPosts[idx]);
      } else {
        final pIdx = _parentPosts.indexWhere((p) => p.id == postId);
        if (pIdx != -1) {
          _parentPosts[pIdx] = updateReactions(_parentPosts[pIdx]);
        }
      }
    });

    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    feedProvider.toggleReaction(postId, reactionType: selectedKey).then((res) {
      if (res != null && mounted) {
        setState(() {
          final serverReaction = res['user_reaction']?.toString();
          final Map<String, int> serverCounts =
              Map<String, int>.from(res['reaction_counts'] as Map? ?? {});

          final idx = _threadPosts.indexWhere((p) => p.id == postId);
          if (idx != -1) {
            _threadPosts[idx] = _threadPosts[idx].copyWith(
              userReaction: serverReaction,
              nullifyUserReaction: serverReaction == null,
              reactionCounts: serverCounts,
            );
          } else {
            final pIdx = _parentPosts.indexWhere((p) => p.id == postId);
            if (pIdx != -1) {
              _parentPosts[pIdx] = _parentPosts[pIdx].copyWith(
                userReaction: serverReaction,
                nullifyUserReaction: serverReaction == null,
                reactionCounts: serverCounts,
              );
            }
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
    final bool isAnonAllowed = !(feedProvider.isCustomNetworkActive &&
        !feedProvider.activeCustomNetwork!.allowAnonymous);
    final bool useAnonymous = isAnonAllowed && _isAnonymousReply;
    final String authorName = useAnonymous
        ? (profileProvider.anonName.isNotEmpty
            ? profileProvider.anonName
            : 'Anonymous')
        : profileProvider.name;
    final String authorAvatarUrl =
        useAnonymous ? '' : profileProvider.avatarUrl;

    final String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempPost = FeedPost(
      id: tempId,
      authorId: profileProvider.userId ?? 0,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      content: text,
      createdAt: DateTime.now(),
      replyCount: 0,
      degree: 0,
      replyToPostId: target.id,
      visibility: target.visibility,
      isAnonymous: useAnonymous,
      networkId: target.networkId,
      feedScope: target.feedScope,
    );

    // Optimistic UI addition
    setState(() {
      _threadPosts.add(tempPost);
      _replyController.clear();
    });

    try {
      final realPost = await feedProvider.createPost(
        text,
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        replyToPostId: target.id,
        connections: connectionProvider.connections,
        visibility: target.visibility,
        isAnonymous: useAnonymous,
        networkId: target.networkId,
        feedScope: target.feedScope,
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
    final parentInChain = _parentPosts.where((p) => p.id == parentId).firstOrNull;
    if (parentInChain != null) return parentInChain.authorName;
    final parent = _threadPosts.where((p) => p.id == parentId).firstOrNull;
    return parent?.authorName;
  }

  int _countTotalActiveDescendants(FeedPost post, Map<String, List<FeedPost>> childrenMap) {
    final children = childrenMap[post.id] ?? [];
    int count = 0;
    for (final child in children) {
      if (!child.isDeleted) {
        count += 1 + _countTotalActiveDescendants(child, childrenMap);
      }
    }
    return count;
  }

  CommentNode _buildNode(FeedPost post, Map<String, List<FeedPost>> childrenMap) {
    final children = childrenMap[post.id] ?? [];
    final totalActiveDescendants = _countTotalActiveDescendants(post, childrenMap);
    final effectiveReplyCount = totalActiveDescendants;
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
      isAnonymous: post.isAnonymous,
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

    final feedProvider = Provider.of<FeedProvider>(context);
    final viewMode = feedProvider.networkViewMode;

    return Scaffold(
      backgroundColor: context.canvasBackground,
      appBar: AppBar(
        backgroundColor: context.canvasBackground,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Thread",
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            if (_threadPosts.isNotEmpty)
              Text(
                "Started by @${_threadPosts.first.isAnonymous ? 'Anonymous' : _threadPosts.first.authorName}",
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: DiscordNetworkViewToggle(
                mode: viewMode,
                onChanged: (newMode) {
                  feedProvider.setNetworkViewMode(newMode);
                  Provider.of<ProfileProvider>(context, listen: false)
                      .setIsChatView(newMode == NetworkViewMode.messages);
                  AnalyticsService.logEvent(
                    name: 'thread_view_mode_changed',
                    parameters: {'mode': newMode.name},
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: viewMode == NetworkViewMode.messages
                  ? KeyedSubtree(
                      key: const ValueKey('thread_chat_view'),
                      child: _buildThreadChatView(
                        context,
                        feedProvider,
                        mentionSuggestions,
                        insertMention,
                      ),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('thread_tree_view'),
                      child: _buildThreadTreeView(
                        context,
                        feedProvider,
                        commentTrees,
                        activeRepliesCount,
                        mentionSuggestions,
                        insertMention,
                      ),
                    ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // CHAT UI VIEW (Discord-style linear thread conversation)
  // ─────────────────────────────────────────────────────────

  Widget _buildThreadChatView(
    BuildContext context,
    FeedProvider feedProvider,
    List<Map<String, dynamic>> mentionSuggestions,
    void Function(Map<String, dynamic>) insertMention,
  ) {
    if (_threadPosts.isEmpty) {
      return Center(
        child: Text(
          "Thread not found",
          style: TextStyle(color: context.textSecondary),
        ),
      );
    }

    final rootPost = _threadPosts.first;
    final activeReplies = _threadPosts
        .sublist(1)
        .where((p) => !p.isDeleted)
        .toList();
    // Sort replies chronologically: oldest to newest
    activeReplies.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final bool isAnonAllowed = !(feedProvider.isCustomNetworkActive &&
        !feedProvider.activeCustomNetwork!.allowAnonymous);

    return Column(
      children: [
        // Scrollable Message Timeline
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Ancestor Parent Strip if this is a sub-thread
                if (_parentPosts.isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      final parent = _parentPosts.last;
                      final urlRegex =
                          RegExp(r'https?://[^\s]+', caseSensitive: false);
                      final cleanParentContent =
                          parent.content.replaceAll(urlRegex, '').trim();
                      final displayContent = cleanParentContent.isNotEmpty
                          ? cleanParentContent
                          : parent.content.trim();

                      return BounceTap(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (parent.id == widget.rootPostId &&
                              widget.independentPostId != null &&
                              widget.openedFromThread &&
                              Navigator.canPop(context)) {
                            Navigator.pop(context, parent.id);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ThreadDetailPage(
                                  rootPostId: widget.rootPostId,
                                  independentPostId:
                                      parent.id == widget.rootPostId
                                          ? null
                                          : parent.id,
                                  focusReplyToPostId: parent.id,
                                  highlightPostId: parent.id,
                                  openedFromThread: true,
                                ),
                              ),
                            ).then((result) {
                              if (result is String && mounted) {
                                Future.delayed(const Duration(milliseconds: 120), () {
                                  if (mounted) {
                                    _scrollToHighlightedPost(result);
                                  }
                                });
                              }
                            });
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.turn_left_rounded,
                                      size: 15, color: context.accentSecondary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Sub-thread of ${parent.isAnonymous ? 'Anonymous' : (parent.authorName.isNotEmpty ? parent.authorName : 'User')}",
                                      style: TextStyle(
                                        color: context.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Inter',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (displayContent.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.only(left: 23),
                                  child: Text(
                                    displayContent,
                                    style: TextStyle(
                                      color: context.textMuted,
                                      fontSize: 12,
                                      height: 1.35,
                                      fontFamily: 'Inter',
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],

                // 2. Thread Topic Card (Original Post Starter)
                _buildThreadTopicCard(context, rootPost),

                // 3. Conversation Divider
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                          activeReplies.isEmpty
                              ? "NO REPLIES YET"
                              : "${activeReplies.length} ${activeReplies.length == 1 ? 'REPLY' : 'REPLIES'}",
                          style: TextStyle(
                            color: context.textSecondary.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            fontFamily: 'Inter',
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
                ),

                // 4. Thread Replies List or Empty State
                if (activeReplies.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: context.accentPrimary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.accentPrimary.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 26,
                            color: context.accentPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          "Start the conversation!",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Send a message below to join the discussion.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                            height: 1.35,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ...activeReplies.map((reply) {
                    return _buildThreadChatMessageTile(context, reply, rootPost);
                  }),
                ],
              ],
            ),
          ),
        ),

        // 5. Pinned Bottom Chat Composer
        _buildThreadChatBottomComposer(
          context,
          rootPost,
          isAnonAllowed,
          mentionSuggestions,
          insertMention,
        ),
      ],
    );
  }

  Widget _buildThreadTopicCard(BuildContext context, FeedPost rootPost) {
    final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final match = urlRegex.firstMatch(rootPost.content);
    final String? attachedUrl = match?.group(0);
    final String cleanContent = attachedUrl != null
        ? rootPost.content.replaceAll(urlRegex, '').trim()
        : rootPost.content.trim();
    final bool isHighlighted = _highlightedPostId == rootPost.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      key: _itemKeys.putIfAbsent(rootPost.id, () => GlobalKey()),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.white.withValues(alpha: 0.09)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.transparent,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Info & Time
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _openUserProfile(context, rootPost),
                child: rootPost.isAnonymous
                    ? AnonymousAvatar(
                        seed: rootPost.authorId.toString(),
                        radius: 19,
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
                        child: (rootPost.authorAvatarUrl.isNotEmpty &&
                                rootPost.authorAvatarUrl.startsWith('http'))
                            ? Image.network(
                                rootPost.authorAvatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildAvatarFallback(rootPost.authorName),
                              )
                            : _buildAvatarFallback(rootPost.authorName),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: () => _openUserProfile(context, rootPost),
                            child: Text(
                              rootPost.isAnonymous
                                  ? 'Anonymous'
                                  : (rootPost.authorName.isNotEmpty
                                      ? rootPost.authorName
                                      : 'User'),
                              style: TextStyle(
                                color: rootPost.degree == 0
                                    ? context.accentPrimary
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                fontFamily: 'Inter',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildDegreeBadge(context, rootPost),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimeAgo(rootPost.createdAt),
                          style: TextStyle(
                            color: context.textMuted.withValues(alpha: 0.7),
                            fontSize: 11.5,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    if (rootPost.authorProfession != null &&
                        rootPost.authorProfession!.trim().isNotEmpty &&
                        !rootPost.isAnonymous &&
                        !rootPost.isDeleted) ...[
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () => _openUserProfile(context, rootPost),
                        child: Text(
                          rootPost.authorProfession!.trim(),
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11.5,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Post Content (raw URL stripped, only preview shown)
          if (cleanContent.isNotEmpty)
            SelectableText(
              cleanContent,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.42,
                fontFamily: 'Inter',
                letterSpacing: -0.1,
              ),
            ),

          // Attached Link Preview
          if (attachedUrl != null && attachedUrl.isNotEmpty) ...[
            if (cleanContent.isNotEmpty) const SizedBox(height: 10),
            LinkPreviewCard(url: attachedUrl),
          ],

          const SizedBox(height: 12),

          // Reactions (if any)
          if (rootPost.reactionCounts.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildReactionsRow(context, rootPost),
          ],

          // Actions Row (left-aligned)
          const SizedBox(height: 6),
          Row(
            children: [
              // Reaction Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showReactionPicker(context, rootPost);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_reaction_outlined,
                          size: 13, color: context.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        "React",
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Reply Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _replyingToTarget = rootPost;
                  });
                  _replyFocusNode.requestFocus();
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.reply_rounded,
                          size: 13, color: context.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        "Reply",
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _buildConnectButton(context, rootPost),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThreadChatMessageTile(
    BuildContext context,
    FeedPost reply,
    FeedPost rootPost,
  ) {
    final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final match = urlRegex.firstMatch(reply.content);
    final String? attachedUrl = match?.group(0);
    final String cleanReplyText = attachedUrl != null
        ? reply.content.replaceAll(urlRegex, '').trim()
        : reply.content.trim();
    final bool isMe = reply.degree == 0;
    final bool isHighlighted = _highlightedPostId == reply.id;

    // Check if replying to someone specific
    FeedPost? replyTargetPost;
    if (reply.replyToPostId != null &&
        reply.replyToPostId!.isNotEmpty &&
        reply.replyToPostId != rootPost.id) {
      replyTargetPost = _threadPosts
          .where((p) => p.id == reply.replyToPostId)
          .firstOrNull;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      key: _itemKeys.putIfAbsent(reply.id, () => GlobalKey()),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.white.withValues(alpha: 0.09)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.transparent,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Discord Reply Quote Header (if replying to another comment)
          if (replyTargetPost != null) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _scrollToHighlightedPost(replyTargetPost!.id),
              child: Padding(
                padding: const EdgeInsets.only(left: 44, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.reply_rounded,
                        size: 13, color: context.accentPrimary),
                    const SizedBox(width: 4),
                    Text(
                      "Replying to @${replyTargetPost.isAnonymous ? 'Anonymous' : replyTargetPost.authorName}: ",
                      style: TextStyle(
                        color: context.accentPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Flexible(
                      child: Text(
                        _truncateContent(replyTargetPost.content, 35),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 11,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Message Row: Avatar + Content
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              GestureDetector(
                onTap: () => _openUserProfile(context, reply),
                child: reply.isAnonymous
                    ? AnonymousAvatar(
                        seed: reply.authorId.toString(),
                        radius: 17,
                      )
                    : Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.surfaceSecondary,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (reply.authorAvatarUrl.isNotEmpty &&
                                reply.authorAvatarUrl.startsWith('http'))
                            ? Image.network(
                                reply.authorAvatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildAvatarFallback(reply.authorName),
                              )
                            : _buildAvatarFallback(reply.authorName),
                      ),
              ),
              const SizedBox(width: 10),

              // Message Content & Actions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author Header Row
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: () => _openUserProfile(context, reply),
                            child: Text(
                              reply.isAnonymous
                                  ? 'Anonymous'
                                  : (reply.authorName.isNotEmpty
                                      ? reply.authorName
                                      : 'User'),
                              style: TextStyle(
                                color:
                                    isMe ? context.accentPrimary : Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildDegreeBadge(context, reply),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimeAgo(reply.createdAt),
                          style: TextStyle(
                            color: context.textMuted.withValues(alpha: 0.65),
                            fontSize: 11,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    if (reply.authorProfession != null &&
                        reply.authorProfession!.trim().isNotEmpty &&
                        !reply.isAnonymous &&
                        !reply.isDeleted) ...[
                      const SizedBox(height: 1.5),
                      GestureDetector(
                        onTap: () => _openUserProfile(context, reply),
                        child: Text(
                          reply.authorProfession!.trim(),
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

                    // Chat Message Content (no grey background, no white border, raw URL stripped)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _replyingToTarget = reply;
                        });
                        _replyFocusNode.requestFocus();
                      },
                      onLongPress: () => _showReactionPicker(context, reply),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (cleanReplyText.isNotEmpty)
                              SelectableText(
                                cleanReplyText,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 14.5,
                                  height: 1.35,
                                  fontFamily: 'Inter',
                                  letterSpacing: -0.1,
                                ),
                              ),
                            if (attachedUrl != null &&
                                attachedUrl.isNotEmpty) ...[
                              if (cleanReplyText.isNotEmpty)
                                const SizedBox(height: 6),
                              LinkPreviewCard(url: attachedUrl),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Reactions (if any)
                    if (reply.reactionCounts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildReactionsRow(context, reply),
                    ],

                    // Actions Row (left-aligned)
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Reaction Button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showReactionPicker(context, reply);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_reaction_outlined,
                                    size: 13, color: context.textMuted),
                                const SizedBox(width: 3),
                                Text(
                                  "React",
                                  style: TextStyle(
                                    color: context.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Reply Button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _replyingToTarget = reply;
                            });
                            _replyFocusNode.requestFocus();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.reply_rounded,
                                    size: 13, color: context.textMuted),
                                const SizedBox(width: 3),
                                Text(
                                  "Reply",
                                  style: TextStyle(
                                    color: context.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        _buildConnectButton(context, reply),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThreadChatBottomComposer(
    BuildContext context,
    FeedPost rootPost,
    bool allowAnonymous,
    List<Map<String, dynamic>> mentionSuggestions,
    void Function(Map<String, dynamic>) insertMention,
  ) {
    final target = _replyingToTarget ?? rootPost;
    final bool isReplyingToSubMessage = target.id != rootPost.id;

    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mention suggestions list (if typing @)
          if (mentionSuggestions.isNotEmpty) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              margin: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: context.surfaceSecondary,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: context.accentPrimary.withValues(alpha: 0.35),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: mentionSuggestions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  itemBuilder: (context, idx) {
                    final conn = mentionSuggestions[idx];
                    final name = conn['name']?.toString() ?? 'User';
                    final avatarUrl = conn['avatarUrl']?.toString() ??
                        conn['avatar_url']?.toString() ??
                        '';
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: CircleAvatar(
                        radius: 13,
                        backgroundColor: context.accentPrimary,
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white),
                              )
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
                      onTap: () => insertMention(conn),
                    );
                  },
                ),
              ),
            ),
          ],

          // Target Reply Banner (if targeting someone specific)
          if (isReplyingToSubMessage) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.accentPrimary.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply_rounded,
                      size: 13, color: context.accentPrimary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Replying to @${target.isAnonymous ? 'Anonymous' : target.authorName}: \"${_truncateContent(target.content, 28)}\"",
                      style: TextStyle(
                        color: context.accentPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyingToTarget = rootPost;
                      });
                    },
                    child: Icon(Icons.close_rounded,
                        size: 15, color: context.textMuted),
                  ),
                ],
              ),
            ),
          ],

          // Bottom Input Row: (Anonymous toggle if allowed) + Input + Send Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Anonymous mode toggle
              if (allowAnonymous) ...[
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isAnonymousReply = !_isAnonymousReply;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isAnonymousReply
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                          : context.surfaceSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isAnonymousReply
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isAnonymousReply
                              ? Icons.masks_rounded
                              : Icons.person_rounded,
                          size: 15,
                          color: _isAnonymousReply
                              ? const Color(0xFFF59E0B)
                              : context.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isAnonymousReply ? "Anon" : "Self",
                          style: TextStyle(
                            color: _isAnonymousReply
                                ? const Color(0xFFF59E0B)
                                : context.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Text Field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.surfaceSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _replyController,
                    focusNode: _replyFocusNode,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                    decoration: InputDecoration(
                      hintText: isReplyingToSubMessage
                          ? "Reply to @${target.isAnonymous ? 'Anonymous' : target.authorName}..."
                          : "Reply in thread...",
                      hintStyle: TextStyle(
                        color: context.textMuted.withValues(alpha: 0.7),
                        fontSize: 13.5,
                        fontFamily: 'Inter',
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    onSubmitted: (_) => _submitReply(),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send Button
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _replyController,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;

                  return GestureDetector(
                    onTap: hasText && !_isSubmitting ? _submitReply : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: hasText
                            ? context.accentPrimary
                            : context.surfaceSecondary,
                        shape: BoxShape.circle,
                        boxShadow: hasText
                            ? [
                                BoxShadow(
                                  color: context.accentPrimary
                                      .withValues(alpha: 0.35),
                                  blurRadius: 8,
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
                                  color:
                                      hasText ? Colors.black : Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.arrow_upward_rounded,
                                size: 19,
                                color:
                                    hasText ? Colors.black : context.textMuted,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // THREAD TREE VIEW (Classic hierarchical comment tree view)
  // ─────────────────────────────────────────────────────────

  Widget _buildThreadTreeView(
    BuildContext context,
    FeedProvider feedProvider,
    List<CommentNode> commentTrees,
    int activeRepliesCount,
    List<Map<String, dynamic>> mentionSuggestions,
    void Function(Map<String, dynamic>) insertMention,
  ) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Ancestor Parent Posts connected with thread lines (Twitter/X style)
                if (_parentPosts.isNotEmpty) ...[
                  ..._parentPosts.asMap().entries.map((entry) {
                    final int idx = entry.key;
                    final FeedPost parent = entry.value;
                    final bool showTop = (idx > 0);
                    final String? repName =
                        _resolveParentAuthorName(parent.replyToPostId);

                    return Container(
                      key: _itemKeys.putIfAbsent(
                          parent.id, () => GlobalKey()),
                      child: PostCard(
                        post: parent,
                        isThreadView: true,
                        showTopConnector: showTop,
                        showBottomConnector: true,
                        replyToName: repName,
                        onReactionToggle: _handleReactionToggle,
                        onTap: () {
                          if (parent.id == widget.rootPostId &&
                              widget.independentPostId != null &&
                              widget.openedFromThread &&
                              Navigator.canPop(context)) {
                            Navigator.pop(context, parent.id);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ThreadDetailPage(
                                  rootPostId: widget.rootPostId,
                                  independentPostId:
                                      parent.id == widget.rootPostId
                                          ? null
                                          : parent.id,
                                  focusReplyToPostId: parent.id,
                                  highlightPostId: parent.id,
                                  openedFromThread: true,
                                ),
                              ),
                            ).then((result) {
                              if (result is String && mounted) {
                                Future.delayed(const Duration(milliseconds: 120), () {
                                  if (mounted) {
                                    _scrollToHighlightedPost(result);
                                  }
                                });
                              }
                            });
                          }
                        },
                        onCommentTap: () {
                          setState(() {
                            _replyingToTarget = parent;
                          });
                          _replyFocusNode.requestFocus();
                        },
                      ),
                    );
                  }),
                ],

                // 2. Focused Main Post
                if (_threadPosts.isNotEmpty) ...[
                  Builder(builder: (context) {
                    final rootPost = _threadPosts.first;
                    final bool isSelected =
                        (_replyingToTarget?.id == rootPost.id);
                    final bool isHighlighted =
                        (rootPost.id == _highlightedPostId);

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

                    final bool hasParents = _parentPosts.isNotEmpty;
                    _itemKeys[rootPost.id] = _focusedPostKey;

                    return Container(
                      key: _focusedPostKey,
                      child: PostCard(
                        post: rootPostWithActiveCount,
                        isThreadView: hasParents,
                        showTopConnector: hasParents,
                        showBottomConnector: false,
                        isSelectedTarget: isSelected,
                        isHighlighted: isHighlighted,
                        replyToName: null,
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
                          _replyFocusNode.requestFocus();
                        },
                      ),
                    );
                  }),

                  Divider(
                      color: Colors.white.withValues(alpha: 0.08), height: 1),

                  // 2. Separate Replies Header
                  if (activeRepliesCount > 0)
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 16, top: 16, bottom: 12),
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
                          indentationWidth: 32.0,
                          parentLeftPadding: 16.0,
                          lineColor: const Color(0xFF3E414D),
                          strokeWidth: 1.8,
                          curveRadius: 12.0,
                          initialExpandPostId: _highlightedPostId,
                          itemKeys: _itemKeys,
                          allowNestedExpansion: false,
                          onReactionToggle: _handleReactionToggle,
                          onReplyTap: (node) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ThreadDetailPage(
                                  rootPostId: widget.rootPostId,
                                  independentPostId: node.id,
                                  focusReplyToPostId: node.id,
                                  openedFromThread: true,
                                ),
                              ),
                            ).then((result) {
                              if (result is String && mounted) {
                                Future.delayed(const Duration(milliseconds: 120), () {
                                  if (mounted) {
                                    _scrollToHighlightedPost(result);
                                  }
                                });
                              }
                            });
                          },
                          onCommentTap: (node) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ThreadDetailPage(
                                  rootPostId: widget.rootPostId,
                                  independentPostId: node.id,
                                  focusReplyToPostId: node.id,
                                  openedFromThread: true,
                                ),
                              ),
                            ).then((result) {
                              if (result is String && mounted) {
                                Future.delayed(const Duration(milliseconds: 120), () {
                                  if (mounted) {
                                    _scrollToHighlightedPost(result);
                                  }
                                });
                              }
                            });
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
            border: Border(
                top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08))),
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
                          color: context.accentPrimary
                              .withValues(alpha: 0.4)),
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
                                        fontSize: 12,
                                        color: Colors.white))
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
                          style: TextStyle(
                              color: context.accentSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _replyingToTarget = _threadPosts.isNotEmpty
                                ? _threadPosts.first
                                : null;
                          });
                        },
                        child: Icon(Icons.close_rounded,
                            size: 14, color: context.textMuted),
                      ),
                    ],
                  ),
                ),
              Consumer2<ProfileProvider, FeedProvider>(
                builder: (context, profileProvider, feedProvider, _) {
                  final bool isAnonAllowed =
                      !(feedProvider.isCustomNetworkActive &&
                          !feedProvider.activeCustomNetwork!.allowAnonymous);
                  final effectiveAnon =
                      isAnonAllowed && _isAnonymousReply;
                  final currentName = effectiveAnon
                      ? (profileProvider.anonName.isNotEmpty
                          ? profileProvider.anonName
                          : "Anonymous")
                      : (profileProvider.name.isNotEmpty
                          ? profileProvider.name
                          : "You");

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: effectiveAnon
                          ? context.accentPrimary
                              .withValues(alpha: 0.12)
                          : context.surfaceSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: effectiveAnon
                            ? context.accentPrimary
                                .withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.06),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        effectiveAnon
                            ? AnonymousAvatar(
                                seed: (profileProvider.userId ?? 0)
                                    .toString(),
                                radius: 12,
                              )
                            : CircleAvatar(
                                radius: 12,
                                backgroundColor:
                                    context.surfaceSecondary,
                                backgroundImage: profileProvider
                                        .avatarUrl.isNotEmpty
                                    ? NetworkImage(
                                        profileProvider.avatarUrl)
                                    : null,
                                child: profileProvider.avatarUrl.isEmpty
                                    ? Text(
                                        profileProvider.name.isNotEmpty
                                            ? profileProvider.name[0]
                                                .toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white),
                                      )
                                    : null,
                              ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 12),
                              children: [
                                const TextSpan(text: "Replying as "),
                                TextSpan(
                                  text: currentName,
                                  style: TextStyle(
                                    color: effectiveAnon
                                        ? context.accentSecondary
                                        : context.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: effectiveAnon
                                      ? " • Anonymous"
                                      : (isAnonAllowed
                                          ? " • Real Profile"
                                          : " • Real Identity Only"),
                                  style: TextStyle(
                                    color: effectiveAnon
                                        ? context.accentSecondary
                                            .withValues(alpha: 0.8)
                                        : context.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isAnonAllowed)
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _isAnonymousReply = !_isAnonymousReply;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: effectiveAnon
                                    ? context.accentPrimary
                                        .withValues(alpha: 0.25)
                                    : Colors.white
                                        .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: effectiveAnon
                                      ? context.accentPrimary
                                          .withValues(alpha: 0.4)
                                      : Colors.white
                                          .withValues(alpha: 0.1),
                                  width: 0.6,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    effectiveAnon
                                        ? Icons.visibility_off_rounded
                                        : Icons.person_rounded,
                                    size: 13,
                                    color: effectiveAnon
                                        ? context.accentSecondary
                                        : context.textPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    effectiveAnon
                                        ? "Go Real Profile"
                                        : "Go Anonymous",
                                    style: TextStyle(
                                      color: effectiveAnon
                                          ? context.accentSecondary
                                          : context.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
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
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      focusNode: _replyFocusNode,
                      maxLines: null,
                      maxLength: 500,
                      style: TextStyle(
                          color: context.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _isAnonymousReply
                            ? "Post anonymous reply..."
                            : "Post your reply... Use @ to mention",
                        hintStyle: TextStyle(
                            color: context.textMuted, fontSize: 13),
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
                      final isValid = textLength > 0 &&
                          textLength <= 500 &&
                          !_isSubmitting;

                      return IconButton(
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : Icon(Icons.send_rounded,
                                color: isValid
                                    ? Colors.white
                                    : context.textMuted),
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
    );
  }

  // ─────────────────────────────────────────────────────────
  // SHARED CHAT HELPERS
  // ─────────────────────────────────────────────────────────

  void _showReactionPicker(BuildContext context, FeedPost post) {
    HapticFeedback.lightImpact();
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
                      _handleReactionToggle(post.id, e.key);
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
                leading: const Icon(Icons.reply_rounded,
                    color: Colors.white, size: 22),
                title: const Text(
                  "Reply to Message",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _replyingToTarget = post;
                  });
                  _replyFocusNode.requestFocus();
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

  Widget _buildReactionsRow(BuildContext context, FeedPost post) {
    if (post.reactionCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...post.reactionCounts.entries.map((entry) {
          final emojiKey = entry.key;
          final count = entry.value;
          if (count <= 0) return const SizedBox.shrink();

          final emoji = FeedPost.reactionEmojiMap[emojiKey] ?? '❤️';
          final isSelected = post.userReaction == emojiKey;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _handleReactionToggle(post.id, emojiKey);
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
        }),
      ],
    );
  }

  Widget _buildConnectButton(BuildContext context, FeedPost post) {
    if (post.isDeleted) return const SizedBox.shrink();

    final int? myUserId =
        Provider.of<ProfileProvider>(context, listen: false).userId;
    if (post.degree == 0 || (myUserId != null && post.authorId == myUserId)) {
      return const SizedBox.shrink();
    }

    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    if (connectionProvider.connections.any((c) => c['id'] == post.authorId)) {
      return const SizedBox.shrink();
    }

    if (post.degree != -1 && post.degree < 2) {
      return const SizedBox.shrink();
    }

    final notifProvider = Provider.of<NotificationProvider>(context);
    final bool isDirectRequest = post.degree == -1;
    final bool isRequestSent =
        isDirectRequest && notifProvider.hasSentDirectRequest(post.authorId);

    void handleConnectTap() {
      if (isRequestSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Direct request already sent to ${post.authorName}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (isDirectRequest) {
        DirectConnectionSheet.show(
          context: context,
          targetUserId: post.authorId,
          targetUserName: post.authorName,
          targetUserAvatar: post.isAnonymous ? '' : post.authorAvatarUrl,
          isAnonymous: post.isAnonymous,
        );
      } else {
        ReferralIntroSheet.show(
          context: context,
          targetUserId: post.authorId,
          targetUserName: post.authorName,
          degree: post.degree,
        );
      }
    }

    return BounceTap(
      onTap: handleConnectTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        decoration: BoxDecoration(
          color: isRequestSent ? Colors.white.withValues(alpha: 0.05) : null,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isRequestSent
                ? Colors.white.withValues(alpha: 0.25)
                : context.accentPrimary.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRequestSent
                  ? Icons.done_rounded
                  : (isDirectRequest
                      ? Icons.send_rounded
                      : Icons.person_add_outlined),
              size: 12,
              color: isRequestSent ? Colors.white70 : context.accentPrimary,
            ),
            const SizedBox(width: 4),
            Text(
              isRequestSent
                  ? "Request Sent"
                  : (isDirectRequest ? "Direct Request" : "Connect"),
              style: TextStyle(
                color: isRequestSent ? Colors.white70 : context.accentPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDegreeBadge(BuildContext context, FeedPost post) {
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

  Widget _buildAvatarFallback(String name) {
    final letter = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  void _openUserProfile(BuildContext context, FeedPost post) {
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
}
