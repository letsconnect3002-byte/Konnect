import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Models/feed_post.dart';
import 'package:connect/Models/app_error.dart';
import 'package:connect/Repositories/feed_repository.dart';
import 'package:connect/Repositories/notification_repository.dart';
import 'package:connect/Repositories/connection_repository.dart';

class FeedProvider with ChangeNotifier {
  final FeedRepository _repository;

  FeedProvider({FeedRepository? repository})
      : _repository = repository ?? SupabaseFeedRepository() {
    _startSeenFlushTimer();
  }

  int? _viewerId;
  int? get viewerId => _viewerId;

  RealtimeChannel? _realtimeChannel;
  Timer? _newPostPollTimer;

  final _postUpdateStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get postUpdateStream =>
      _postUpdateStreamController.stream;

  // --- Snapshot of the feed's top post ID when we last loaded ---
  // Used to detect whether new content exists without fetching full posts.
  String? _latestKnownPostId;

  List<FeedPost> _posts = [];
  List<FeedPost> get posts => List.unmodifiable(_posts);

  // Simple flag: "there are new posts you haven't seen"
  bool _hasNewPosts = false;
  bool get hasNewPosts => _hasNewPosts;

  String _currentBucket = 'unseen';
  String get currentBucket => _currentBucket;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  FeedPost? getPostById(String postId) {
    for (final p in _posts) {
      if (p.id == postId) return p;
    }
    return null;
  }

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasReachedEnd = false;
  bool get hasReachedEnd => _hasReachedEnd;

  bool _hasShownCaughtUpDivider = false;
  bool get hasShownCaughtUpDivider => _hasShownCaughtUpDivider;

  int _unseenCount = 0;
  int get unseenCount => _unseenCount;

  AppError? _error;
  AppError? get error => _error;

  final Set<String> _bufferedSeenPostIds = {};
  Timer? _seenFlushTimer;

  // -------------------------------------------------------
  //  Viewer ID management
  // -------------------------------------------------------

  void updateViewerId(int? id) {
    if (_viewerId != id) {
      _viewerId = id;
      if (id != null) {
        fetchInitialFeed();
        fetchUnseenCount();
        _subscribeToRealtime();
        _startNewPostPollTimer();
      } else {
        _unsubscribeRealtime();
        _stopNewPostPollTimer();
        _posts = [];
        _unseenCount = 0;
        _hasNewPosts = false;
        _latestKnownPostId = null;
        notifyListeners();
      }
    }
  }

  // -------------------------------------------------------
  //  "New post available" — apply action (full refresh)
  // -------------------------------------------------------

  Future<void> loadNewPosts() async {
    _hasNewPosts = false;
    notifyListeners();
    await fetchInitialFeed();
  }

  // -------------------------------------------------------
  //  Seen buffer
  // -------------------------------------------------------

  void _startSeenFlushTimer() {
    _seenFlushTimer?.cancel();
    _seenFlushTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      flushSeenBuffer();
    });
  }

  Future<void> flushSeenBuffer() async {
    final vId = _viewerId;
    if (vId == null || _bufferedSeenPostIds.isEmpty) return;

    final List<String> idsToFlush = _bufferedSeenPostIds.toList();
    _bufferedSeenPostIds.clear();

    try {
      await _repository.markPostsSeen(viewerId: vId, postIds: idsToFlush);
      fetchUnseenCount();
    } catch (e) {
      debugPrint("[FeedProvider] Error flushing seen posts: $e");
    }
  }

  void markPostSeenLocally(String postId) {
    if (postId.isEmpty) return;
    _bufferedSeenPostIds.add(postId);
  }

  // -------------------------------------------------------
  //  Unseen count
  // -------------------------------------------------------

  Future<void> fetchUnseenCount() async {
    final vId = _viewerId;
    if (vId == null) return;
    try {
      _unseenCount = await _repository.getUnseenCount(viewerId: vId);
      notifyListeners();
    } catch (e) {
      debugPrint("[FeedProvider] Error fetching unseen count: $e");
    }
  }

  // -------------------------------------------------------
  //  Initial feed load
  // -------------------------------------------------------

  Future<void> fetchInitialFeed({bool silent = false}) async {
    final vId = _viewerId;
    if (vId == null) return;

    if (_realtimeChannel == null) {
      _subscribeToRealtime();
    }

    if (!silent) {
      _isLoading = true;
      _error = null;
      _hasNewPosts = false;
      notifyListeners();
    }

    try {
      final fetched = await _repository.getFeed(
        viewerId: vId,
        bucket: 'unseen',
        limit: 20,
      );

      final List<FeedPost> updatedPosts = List.from(fetched);
      bool newHasReachedEnd = false;
      bool newHasShownCaughtUpDivider = false;
      String newBucket = 'unseen';

      if (fetched.length < 20) {
        if (updatedPosts.isNotEmpty) {
          newHasShownCaughtUpDivider = true;
        }
        newBucket = 'seen';
        final seenFetched = await _repository.getFeed(
          viewerId: vId,
          bucket: 'seen',
          limit: 20,
        );
        updatedPosts.addAll(seenFetched);
        if (seenFetched.length < 20) {
          newHasReachedEnd = true;
        }
      }

      _currentBucket = newBucket;
      _hasReachedEnd = newHasReachedEnd;
      _hasShownCaughtUpDivider = newHasShownCaughtUpDivider;
      _posts = updatedPosts;

      // Snapshot the latest post ID for change detection
      if (_posts.isNotEmpty) {
        _latestKnownPostId = _posts.first.id;
      }

      // Bulk-mark all loaded posts as seen so the badge clears
      final postIdsToMark = _posts
          .where((p) => !p.id.startsWith('temp_'))
          .map((p) => p.id)
          .toList();
      if (postIdsToMark.isNotEmpty) {
        _repository.markPostsSeen(viewerId: vId, postIds: postIdsToMark).then((_) {
          fetchUnseenCount();
        }).catchError((e) {
          debugPrint("[FeedProvider] Error marking posts seen: $e");
        });
      }
    } catch (e) {
      debugPrint("[FeedProvider] Error loading initial feed: $e");
      if (!silent) {
        _error = AppError.from(e);
      }
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      _unseenCount = 0; // Clear badge immediately in the UI
      notifyListeners();
    }
  }

  // -------------------------------------------------------
  //  Pagination
  // -------------------------------------------------------

  Future<void> fetchNextPage() async {
    final vId = _viewerId;
    if (vId == null || _isLoadingMore || _hasReachedEnd || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      DateTime? cursorCreatedAt;
      String? cursorPostId;

      if (_posts.isNotEmpty) {
        final lastPost = _posts.lastWhere((p) => !p.id.startsWith('temp_'), orElse: () => _posts.last);
        cursorCreatedAt = lastPost.createdAt;
        cursorPostId = lastPost.id;
      }

      if (_currentBucket == 'unseen') {
        final fetched = await _repository.getFeed(
          viewerId: vId,
          bucket: 'unseen',
          cursorCreatedAt: cursorCreatedAt,
          cursorPostId: cursorPostId,
          limit: 20,
        );

        _posts.addAll(fetched);

        if (fetched.length < 20) {
          _hasShownCaughtUpDivider = true;
          _currentBucket = 'seen';
          final seenFetched = await _repository.getFeed(
            viewerId: vId,
            bucket: 'seen',
            limit: 20,
          );
          _posts.addAll(seenFetched);
          if (seenFetched.length < 20) {
            _hasReachedEnd = true;
          }
        }
      } else {
        final fetched = await _repository.getFeed(
          viewerId: vId,
          bucket: 'seen',
          cursorCreatedAt: cursorCreatedAt,
          cursorPostId: cursorPostId,
          limit: 20,
        );

        _posts.addAll(fetched);

        if (fetched.length < 20) {
          _hasReachedEnd = true;
        }
      }
    } catch (e) {
      debugPrint("[FeedProvider] Error loading next feed page: $e");
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------
  //  Post creation
  // -------------------------------------------------------

  Future<FeedPost> createPost(
    String content, {
    String? authorName,
    String? authorAvatarUrl,
    String? replyToPostId,
    List<Map<String, dynamic>>? connections,
  }) async {
    final vId = _viewerId;
    if (vId == null || content.trim().isEmpty) {
      throw Exception("User not authenticated or content empty");
    }

    final String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempPost = FeedPost(
      id: tempId,
      authorId: vId,
      authorName: authorName ?? 'User',
      authorAvatarUrl: authorAvatarUrl ?? '',
      content: content.trim(),
      createdAt: DateTime.now(),
      replyCount: 0,
      degree: 0,
      replyToPostId: replyToPostId,
    );

    if (replyToPostId == null) {
      _posts.insert(0, tempPost);
      notifyListeners();
    }

    try {
      final realPost = await _repository.createPost(
        authorId: vId,
        content: content.trim(),
        replyToPostId: replyToPostId,
      );

      if (replyToPostId == null) {
        final index = _posts.indexWhere((p) => p.id == tempId);
        if (index != -1) {
          _posts[index] = realPost;
          // Update snapshot so we don't flag our own post as "new"
          _latestKnownPostId = realPost.id;
          notifyListeners();
        }
      }

      // Dispatch notifications for mentions and/or reply
      await _dispatchPostNotifications(
        authorId: vId,
        createdPost: realPost,
        replyToPostId: replyToPostId,
        connections: connections,
      );

      return realPost;
    } catch (e) {
      debugPrint("[FeedProvider] Error creating post: $e");
      if (replyToPostId == null) {
        _posts.removeWhere((p) => p.id == tempId);
        _error = AppError.from(e);
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> _dispatchPostNotifications({
    required int authorId,
    required FeedPost createdPost,
    required String? replyToPostId,
    List<Map<String, dynamic>>? connections,
  }) async {
    try {
      final NotificationRepository notifRepo = SupabaseNotificationRepository();

      int? parentAuthorId;
      String rootPostId = createdPost.id;

      if (replyToPostId != null) {
        try {
          final parentRes = await Supabase.instance.client
              .from('posts')
              .select('author_id, reply_to_post_id')
              .eq('id', replyToPostId)
              .maybeSingle();

          if (parentRes != null) {
            parentAuthorId = parentRes['author_id'] as int?;
            String currentCheckId = replyToPostId;
            while (true) {
              final checkRes = await Supabase.instance.client
                  .from('posts')
                  .select('id, reply_to_post_id')
                  .eq('id', currentCheckId)
                  .maybeSingle();
              if (checkRes != null && checkRes['reply_to_post_id'] != null) {
                currentCheckId = checkRes['reply_to_post_id'].toString();
              } else {
                rootPostId = currentCheckId;
                break;
              }
            }
          }
        } catch (e) {
          debugPrint("[FeedProvider] Error fetching parent post details: $e");
        }
      }

      // Fetch fallback connections if empty
      List<Map<String, dynamic>> targetConnections = connections ?? [];
      if (targetConnections.isEmpty) {
        try {
          final connRepo = SupabaseConnectionRepository();
          targetConnections = await connRepo.getOtherProfiles(authorId);
        } catch (e) {
          debugPrint("[FeedProvider] Error fetching fallback connections: $e");
        }
      }

      final Set<int> mentionedUserIds = {};
      final contentLower = createdPost.content.toLowerCase();

      // 1. Match against user's connections
      for (final conn in targetConnections) {
        final fullName = (conn['name'] ?? '').toString().trim().toLowerCase();
        final firstName = fullName.split(' ').first;
        final cId = conn['id'] is int
            ? conn['id'] as int
            : int.tryParse(conn['id']?.toString() ?? '');

        if (fullName.isNotEmpty && cId != null && cId != authorId) {
          if (contentLower.contains('@$fullName') ||
              (firstName.length >= 2 && contentLower.contains('@$firstName'))) {
            mentionedUserIds.add(cId);
          }
        }
      }

      // 2. Fallback DB lookup for any @Mention tokens if no connection matched
      if (contentLower.contains('@')) {
        final RegExp mentionTokenRegex = RegExp(r'@([A-Za-z0-9_\-\.\s]{2,30})');
        final matches = mentionTokenRegex.allMatches(createdPost.content);
        for (final match in matches) {
          final rawMention = match.group(1)?.trim();
          if (rawMention != null && rawMention.isNotEmpty) {
            try {
              final profileRes = await Supabase.instance.client
                  .from('profiles')
                  .select('id')
                  .ilike('name', '%$rawMention%')
                  .neq('id', authorId)
                  .limit(3);

              final List<dynamic> profileList = profileRes as List;
              for (final row in profileList) {
                final pId = row['id'] is int
                    ? row['id'] as int
                    : int.tryParse(row['id']?.toString() ?? '');
                if (pId != null) {
                  mentionedUserIds.add(pId);
                }
              }
            } catch (e) {
              debugPrint("[FeedProvider] DB profile mention lookup error: $e");
            }
          }
        }
      }

      // 3. Send Reply / Mention notifications
      if (parentAuthorId != null && parentAuthorId != authorId) {
        final isMentioned = mentionedUserIds.contains(parentAuthorId);
        final String notifType = isMentioned ? 'feed_reply_mention' : 'feed_reply';

        await notifRepo.sendFeedNotification(
          recipientUserId: parentAuthorId,
          actorUserId: authorId,
          type: notifType,
          postId: createdPost.id,
          rootPostId: rootPostId,
        );

        mentionedUserIds.remove(parentAuthorId);
      }

      for (final recipientId in mentionedUserIds) {
        await notifRepo.sendFeedNotification(
          recipientUserId: recipientId,
          actorUserId: authorId,
          type: 'feed_mention',
          postId: createdPost.id,
          rootPostId: rootPostId,
        );
      }

      // 4. Send New Post notification to all connected users when creating a top-level post
      if (replyToPostId == null) {
        final Set<int> notifiedUserIds = {authorId, ...mentionedUserIds};
        if (parentAuthorId != null) notifiedUserIds.add(parentAuthorId);

        for (final conn in targetConnections) {
          final cId = conn['id'] is int
              ? conn['id'] as int
              : int.tryParse(conn['id']?.toString() ?? '');

          if (cId != null && !notifiedUserIds.contains(cId)) {
            notifiedUserIds.add(cId);
            await notifRepo.sendFeedNotification(
              recipientUserId: cId,
              actorUserId: authorId,
              type: 'feed_post',
              postId: createdPost.id,
              rootPostId: createdPost.id,
            );
          }
        }
      }
    } catch (e) {
      debugPrint("[FeedProvider] Error dispatching post notifications: $e");
    }
  }

  // -------------------------------------------------------
  //  Post deletion
  // -------------------------------------------------------

  Future<void> deletePost(String postId) async {
    final vId = _viewerId;
    if (vId == null) return;

    try {
      await _repository.deletePost(postId: postId, authorId: vId);
      _posts.removeWhere((p) => p.id == postId);
      notifyListeners();
    } catch (e) {
      debugPrint("[FeedProvider] Error deleting post: $e");
      rethrow;
    }
  }

  // -------------------------------------------------------
  //  Reporting
  // -------------------------------------------------------

  Future<void> reportPost({
    required String postId,
    required int reportedUserId,
    required String reason,
    String? additionalDetails,
  }) async {
    final vId = _viewerId;
    if (vId == null) return;

    await _repository.reportPost(
      reporterId: vId,
      reportedUserId: reportedUserId,
      postId: postId,
      reason: reason,
      additionalDetails: additionalDetails,
    );

    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  void removePostsByAuthor(int authorId) {
    _posts.removeWhere((p) => p.authorId == authorId);
    notifyListeners();
  }

  // -------------------------------------------------------
  //  Reactions
  // -------------------------------------------------------

  Future<Map<String, dynamic>?> toggleReaction(String postId, {String reactionType = 'like'}) async {
    final vId = _viewerId;
    if (vId == null) return null;

    final index = _posts.indexWhere((p) => p.id == postId);
    FeedPost? oldPost;
    if (index != -1) {
      oldPost = _posts[index];
      final String? oldUserReaction = oldPost.userReaction;
      final Map<String, int> newCounts = Map<String, int>.from(oldPost.reactionCounts);

      String? newUserReaction;
      if (oldUserReaction == reactionType) {
        // Toggle off
        newUserReaction = null;
        if (newCounts.containsKey(reactionType)) {
          final current = newCounts[reactionType]!;
          if (current <= 1) {
            newCounts.remove(reactionType);
          } else {
            newCounts[reactionType] = current - 1;
          }
        }
      } else {
        // Switch or add reaction
        if (oldUserReaction != null && newCounts.containsKey(oldUserReaction)) {
          final prevCount = newCounts[oldUserReaction]!;
          if (prevCount <= 1) {
            newCounts.remove(oldUserReaction);
          } else {
            newCounts[oldUserReaction] = prevCount - 1;
          }
        }
        newUserReaction = reactionType;
        newCounts[reactionType] = (newCounts[reactionType] ?? 0) + 1;
      }

      _posts[index] = oldPost.copyWith(
        userReaction: newUserReaction,
        nullifyUserReaction: newUserReaction == null,
        reactionCounts: newCounts,
      );
      notifyListeners();
    }

    try {
      final res = await _repository.toggleReaction(
        postId: postId,
        userId: vId,
        reactionType: reactionType,
      );

      final serverUserReaction = res['user_reaction']?.toString();
      final Map<String, int> serverCounts = {};
      if (res['reaction_counts'] is Map) {
        (res['reaction_counts'] as Map).forEach((k, v) {
          final c = v is int ? v : (int.tryParse(v?.toString() ?? '') ?? 0);
          if (c > 0) serverCounts[k.toString()] = c;
        });
      }

      final currIdx = _posts.indexWhere((p) => p.id == postId);
      if (currIdx != -1) {
        _posts[currIdx] = _posts[currIdx].copyWith(
          userReaction: serverUserReaction,
          nullifyUserReaction: serverUserReaction == null,
          reactionCounts: serverCounts,
        );
        notifyListeners();
      }
      return {
        'user_reaction': serverUserReaction,
        'reaction_counts': serverCounts,
      };
    } catch (e) {
      debugPrint("[FeedProvider] Error toggling reaction: $e");
      if (oldPost != null) {
        final rollbackIdx = _posts.indexWhere((p) => p.id == postId);
        if (rollbackIdx != -1) {
          _posts[rollbackIdx] = oldPost;
          notifyListeners();
        }
      }
      return null;
    }
  }

  // -------------------------------------------------------
  //  Thread + mutual connections
  // -------------------------------------------------------

  Future<List<FeedPost>> fetchThread(String rootPostId) async {
    return await _repository.getThread(rootPostId: rootPostId, viewerId: _viewerId);
  }

  Future<List<Map<String, dynamic>>> fetchMutualConnections(int targetId) async {
    final vId = _viewerId;
    if (vId == null) return [];
    return await _repository.getMutualConnections(viewerId: vId, targetId: targetId);
  }

  // -------------------------------------------------------
  //  REALTIME — lightweight trigger (just sets flag)
  // -------------------------------------------------------

  void _subscribeToRealtime() {
    _unsubscribeRealtime();
    final vId = _viewerId;
    if (vId == null) return;

    _realtimeChannel = _repository.subscribeToPosts(
      onChange: (payload) => _handleRealtimeEvent(payload),
    );
    debugPrint("[FeedProvider] Realtime channel subscribed");
  }

  void _unsubscribeRealtime() {
    if (_realtimeChannel != null) {
      _repository.unsubscribeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }

  Future<void> _handleRealtimeEvent(Map<String, dynamic> payload) async {
    final vId = _viewerId;
    if (vId == null) return;

    final String table = payload['table']?.toString() ?? 'posts';
    final String eventType = payload['eventType']?.toString() ?? '';
    final Map<String, dynamic> newRecord = Map<String, dynamic>.from(payload['new'] ?? {});
    final Map<String, dynamic> oldRecord = Map<String, dynamic>.from(payload['old'] ?? {});

    debugPrint("[FeedProvider] Realtime event ($table): $eventType");

    // Broadcast all posts table events to stream listeners (thread widgets)
    _postUpdateStreamController.add(payload);

    if (table == 'post_reactions') {
      _handleReactionRealtimeEvent(
        eventType: eventType,
        newRecord: newRecord,
        oldRecord: oldRecord,
        viewerId: vId,
      );
      return;
    }

    if (table == 'blocked_users') {
      _handleBlockedUsersRealtimeEvent(
        eventType: eventType,
        newRecord: newRecord,
        oldRecord: oldRecord,
        viewerId: vId,
      );
      return;
    }

    if (table == 'user_connections') {
      _handleUserConnectionsRealtimeEvent(
        eventType: eventType,
        newRecord: newRecord,
        oldRecord: oldRecord,
        viewerId: vId,
      );
      return;
    }

    if (eventType == 'insert') {
      final int? authorId = newRecord['author_id'] is int
          ? newRecord['author_id'] as int
          : int.tryParse(newRecord['author_id']?.toString() ?? '');
      final String? replyToPostId = newRecord['reply_to_post_id']?.toString();

      // A top-level post from someone else → flag new posts
      if (replyToPostId == null && authorId != null && authorId != vId) {
        if (!_hasNewPosts) {
          _hasNewPosts = true;
          notifyListeners();
          debugPrint("[FeedProvider] New post flagged from author $authorId");
        }
      }

      // A reply to a post in our feed → update reply count inline
      if (replyToPostId != null) {
        final String rootPostId = newRecord['root_post_id']?.toString() ?? '';
        final rootIndex = _posts.indexWhere((p) => p.id == rootPostId);
        if (rootIndex != -1) {
          _posts[rootIndex] = _posts[rootIndex].copyWith(
            replyCount: _posts[rootIndex].replyCount + 1,
            activeReplyCount: _posts[rootIndex].activeReplyCount + 1,
          );
          notifyListeners();
        }
      }
    } else if (eventType == 'update') {
      final String postId = newRecord['id']?.toString() ?? '';
      final bool isDeleted = newRecord['is_deleted'] == true;

      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        // A top-level feed post was deleted
        if (isDeleted) {
          _posts.removeAt(index);
        } else {
          final int replyCount = newRecord['reply_count'] is int
              ? newRecord['reply_count'] as int
              : (int.tryParse(newRecord['reply_count']?.toString() ?? '') ?? _posts[index].replyCount);

          Map<String, int> reactionCounts = _posts[index].reactionCounts;
          if (newRecord['reaction_counts'] is Map) {
            reactionCounts = {};
            (newRecord['reaction_counts'] as Map).forEach((k, v) {
              final c = v is int ? v : (int.tryParse(v?.toString() ?? '') ?? 0);
              if (c > 0) reactionCounts[k.toString()] = c;
            });
          }

          _posts[index] = _posts[index].copyWith(
            replyCount: replyCount,
            reactionCounts: reactionCounts,
          );
        }
        notifyListeners();
      } else if (isDeleted) {
        // A reply was soft-deleted → decrement root post's activeReplyCount
        final String? rootPostId = newRecord['root_post_id']?.toString();
        if (rootPostId != null && rootPostId != postId) {
          final rootIndex = _posts.indexWhere((p) => p.id == rootPostId);
          if (rootIndex != -1) {
            final currentActive = _posts[rootIndex].activeReplyCount;
            _posts[rootIndex] = _posts[rootIndex].copyWith(
              activeReplyCount: currentActive > 0 ? currentActive - 1 : 0,
            );
            notifyListeners();
          }
        }
      }
    }
  }

  void _handleReactionRealtimeEvent({
    required String eventType,
    required Map<String, dynamic> newRecord,
    required Map<String, dynamic> oldRecord,
    required int viewerId,
  }) {
    final String postId =
        newRecord['post_id']?.toString() ?? oldRecord['post_id']?.toString() ?? '';
    final int? userId = newRecord['user_id'] is int
        ? newRecord['user_id'] as int
        : int.tryParse(
            newRecord['user_id']?.toString() ?? oldRecord['user_id']?.toString() ?? '');

    if (postId.isEmpty) return;

    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _posts[index];
    final Map<String, int> counts = Map<String, int>.from(post.reactionCounts);
    String? userReaction = post.userReaction;

    final String event = eventType.toLowerCase();

    if (userId == viewerId) {
      // Viewer's own reaction — counts are already correct from the
      // optimistic update + server response in toggleReaction().
      // Only sync the userReaction flag here.
      if (event == 'insert' || event == 'update') {
        userReaction = newRecord['reaction_type']?.toString();
      } else if (event == 'delete') {
        userReaction = null;
      }
    } else {
      // Another user's reaction — we need to adjust counts.
      if (event == 'insert') {
        final String reactionType =
            newRecord['reaction_type']?.toString() ?? 'like';
        counts[reactionType] = (counts[reactionType] ?? 0) + 1;
      } else if (event == 'delete') {
        final String reactionType = oldRecord['reaction_type']?.toString() ??
            newRecord['reaction_type']?.toString() ??
            'like';
        if (counts.containsKey(reactionType)) {
          final c = counts[reactionType]!;
          if (c <= 1) {
            counts.remove(reactionType);
          } else {
            counts[reactionType] = c - 1;
          }
        }
      } else if (event == 'update') {
        final String oldType = oldRecord['reaction_type']?.toString() ?? '';
        final String newType = newRecord['reaction_type']?.toString() ?? '';
        if (oldType.isNotEmpty && counts.containsKey(oldType)) {
          final c = counts[oldType]!;
          if (c <= 1) {
            counts.remove(oldType);
          } else {
            counts[oldType] = c - 1;
          }
        }
        if (newType.isNotEmpty) {
          counts[newType] = (counts[newType] ?? 0) + 1;
        }
      }
    }

    _posts[index] = post.copyWith(
      reactionCounts: counts,
      userReaction: userReaction,
      nullifyUserReaction: userReaction == null,
    );
    notifyListeners();
    debugPrint("[FeedProvider] Realtime reaction updated for post $postId");
  }

  void _handleBlockedUsersRealtimeEvent({
    required String eventType,
    required Map<String, dynamic> newRecord,
    required Map<String, dynamic> oldRecord,
    required int viewerId,
  }) {
    final event = eventType.toLowerCase();
    debugPrint("[FeedProvider] Realtime blocked_users event: $event, new: $newRecord, old: $oldRecord");

    if (event == 'insert') {
      final blockerId = newRecord['blocker_id'] is int
          ? newRecord['blocker_id'] as int
          : int.tryParse(newRecord['blocker_id']?.toString() ?? '');
      final blockedId = newRecord['blocked_id'] is int
          ? newRecord['blocked_id'] as int
          : int.tryParse(newRecord['blocked_id']?.toString() ?? '');

      if (blockerId == viewerId && blockedId != null) {
        removePostsByAuthor(blockedId);
      } else if (blockedId == viewerId && blockerId != null) {
        removePostsByAuthor(blockerId);
      }
    } else if (event == 'delete') {
      final blockerId = oldRecord['blocker_id'] is int
          ? oldRecord['blocker_id'] as int
          : int.tryParse(oldRecord['blocker_id']?.toString() ?? '');
      final blockedId = oldRecord['blocked_id'] is int
          ? oldRecord['blocked_id'] as int
          : int.tryParse(oldRecord['blocked_id']?.toString() ?? '');

      if (blockerId == null || blockerId == viewerId || blockedId == viewerId) {
        debugPrint("[FeedProvider] User unblocked in realtime. Silently refreshing feed...");
        fetchInitialFeed(silent: true);
      }
    }
  }

  void _handleUserConnectionsRealtimeEvent({
    required String eventType,
    required Map<String, dynamic> newRecord,
    required Map<String, dynamic> oldRecord,
    required int viewerId,
  }) {
    final event = eventType.toLowerCase();
    debugPrint("[FeedProvider] Realtime user_connections event: $event, new: $newRecord, old: $oldRecord");

    final int? u1 = (newRecord['user_id_1'] ?? oldRecord['user_id_1']) is int
        ? (newRecord['user_id_1'] ?? oldRecord['user_id_1']) as int
        : int.tryParse((newRecord['user_id_1'] ?? oldRecord['user_id_1'])?.toString() ?? '');
    final int? u2 = (newRecord['user_id_2'] ?? oldRecord['user_id_2']) is int
        ? (newRecord['user_id_2'] ?? oldRecord['user_id_2']) as int
        : int.tryParse((newRecord['user_id_2'] ?? oldRecord['user_id_2'])?.toString() ?? '');

    // If connection involves the current user or their extended network, silently refresh the feed
    debugPrint("[FeedProvider] Connection changed ($event: u1=$u1, u2=$u2, viewer=$viewerId). Refreshing feed...");
    fetchInitialFeed(silent: true);
  }

  // -------------------------------------------------------
  //  POLLING FALLBACK — check for new posts every 15 seconds
  // -------------------------------------------------------

  void _startNewPostPollTimer() {
    _stopNewPostPollTimer();
    _newPostPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkForNewPosts();
    });
  }

  void _stopNewPostPollTimer() {
    _newPostPollTimer?.cancel();
    _newPostPollTimer = null;
  }

  Future<void> _checkForNewPosts() async {
    final vId = _viewerId;
    if (vId == null || _hasNewPosts || _isLoading) return;

    try {
      // Lightweight check: fetch just 1 post from the unseen bucket
      final topPosts = await _repository.getFeed(
        viewerId: vId,
        bucket: 'unseen',
        limit: 1,
      );

      if (topPosts.isNotEmpty) {
        final newestId = topPosts.first.id;
        // If the newest post in the feed is different from what we have loaded
        if (_latestKnownPostId != null && newestId != _latestKnownPostId) {
          // Make sure it's not already in our loaded list
          if (!_posts.any((p) => p.id == newestId)) {
            _hasNewPosts = true;
            notifyListeners();
            debugPrint("[FeedProvider] Poll detected new post: $newestId");
          }
        }
      }
    } catch (e) {
      debugPrint("[FeedProvider] Poll check error: $e");
    }
  }

  // -------------------------------------------------------
  //  Dispose
  // -------------------------------------------------------

  @override
  void dispose() {
    _unsubscribeRealtime();
    _stopNewPostPollTimer();
    flushSeenBuffer();
    _seenFlushTimer?.cancel();
    _postUpdateStreamController.close();
    super.dispose();
  }
}
