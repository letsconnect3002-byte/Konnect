import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Models/feed_post.dart';

abstract class FeedRepository {
  Future<List<FeedPost>> getFeed({
    required int viewerId,
    String bucket = 'unseen',
    DateTime? cursorCreatedAt,
    String? cursorPostId,
    int limit = 20,
  });

  Future<List<FeedPost>> getThread({
    required String rootPostId,
    int? viewerId,
  });

  Future<Map<String, dynamic>> toggleReaction({
    required String postId,
    required int userId,
    required String reactionType,
  });

  Future<FeedPost> createPost({
    required int authorId,
    required String content,
    String? replyToPostId,
  });

  Future<void> deletePost({
    required String postId,
    required int authorId,
  });

  Future<void> markPostsSeen({
    required int viewerId,
    required List<String> postIds,
  });

  Future<int> getUnseenCount({
    required int viewerId,
    int cap = 20,
  });

  Future<List<Map<String, dynamic>>> getMutualConnections({
    required int viewerId,
    required int targetId,
  });

  Future<void> reportPost({
    required int reporterId,
    required int reportedUserId,
    required String postId,
    required String reason,
    String? additionalDetails,
  });

  RealtimeChannel subscribeToPosts({
    required void Function(Map<String, dynamic> payload) onChange,
    void Function(RealtimeSubscribeStatus status, Object? error)? onStatusChange,
  });

  void unsubscribeChannel(RealtimeChannel channel);

  Future<FeedPost?> getPostById({
    required String postId,
    required int viewerId,
  });

  Future<Map<String, dynamic>> getPostsReactionSummaries({
    required List<String> postIds,
    required int viewerId,
  });
}

class SupabaseFeedRepository implements FeedRepository {
  final SupabaseClient _client;

  SupabaseFeedRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<FeedPost>> getFeed({
    required int viewerId,
    String bucket = 'unseen',
    DateTime? cursorCreatedAt,
    String? cursorPostId,
    int limit = 20,
  }) async {
    final Map<String, dynamic> params = {
      'p_viewer_id': viewerId,
      'p_bucket': bucket,
      'p_limit': limit,
    };

    if (cursorCreatedAt != null && cursorPostId != null) {
      params['p_cursor_created_at'] = cursorCreatedAt.toUtc().toIso8601String();
      params['p_cursor_post_id'] = cursorPostId;
    }

    final response = await _client.rpc('get_feed', params: params);
    final List list = response as List;
    return list.map((json) => FeedPost.fromRpcJson(Map<String, dynamic>.from(json))).toList();
  }

  @override
  Future<List<FeedPost>> getThread({
    required String rootPostId,
    int? viewerId,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'p_root_post_id': rootPostId,
      };
      if (viewerId != null) {
        params['p_viewer_id'] = viewerId;
      }
      final response = await _client.rpc('get_thread', params: params);
      final List list = response as List;
      List<FeedPost> result = list.map((json) => FeedPost.fromThreadRpcJson(Map<String, dynamic>.from(json))).toList();

      if (result.isEmpty || (result.length == 1 && result.first.id == rootPostId)) {
        FeedPost? mainTargetPost = result.isNotEmpty ? result.first : null;
        if (mainTargetPost == null && viewerId != null) {
          mainTargetPost = await getPostById(postId: rootPostId, viewerId: viewerId);
        }

        if (mainTargetPost != null) {
          final rawReplies = await _client
              .from('posts')
              .select('*, profiles!author_id(name, avatar_url)')
              .or('root_post_id.eq.$rootPostId,reply_to_post_id.eq.$rootPostId')
              .order('created_at', ascending: true);

          final List<FeedPost> fetchedReplies = [];
          for (final row in (rawReplies as List)) {
            final String pId = row['id'].toString();
            if (pId != rootPostId) {
              final authorId = row['author_id'] is int
                  ? row['author_id'] as int
                  : (int.tryParse(row['author_id']?.toString() ?? '') ?? 0);
              final profile = row['profiles'] as Map<String, dynamic>?;

              fetchedReplies.add(FeedPost(
                id: pId,
                authorId: authorId,
                authorName: profile?['name']?.toString() ?? 'User',
                authorAvatarUrl: profile?['avatar_url']?.toString() ?? '',
                content: row['content']?.toString() ?? '',
                createdAt: row['created_at'] != null
                    ? DateTime.parse(row['created_at'].toString()).toLocal()
                    : DateTime.now(),
                replyCount: row['reply_count'] is int ? row['reply_count'] as int : (int.tryParse(row['reply_count']?.toString() ?? '') ?? 0),
                degree: (viewerId != null && authorId == viewerId) ? 0 : 3,
                isDeleted: row['is_deleted'] == true,
                replyToPostId: row['reply_to_post_id']?.toString(),
              ));
            }
          }

          result = [mainTargetPost, ...fetchedReplies];
        }
      }

      if (viewerId != null) {
        result = result.map((post) {
          if (post.authorId == viewerId) {
            return post.copyWith(degree: 0);
          }
          return post;
        }).toList();
      }

      return result;
    } catch (e) {
      debugPrint("[FeedRepository] Error fetching thread: $e");
      if (viewerId != null) {
        final fallbackPost = await getPostById(postId: rootPostId, viewerId: viewerId);
        if (fallbackPost != null) return [fallbackPost];
      }
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> toggleReaction({
    required String postId,
    required int userId,
    required String reactionType,
  }) async {
    final response = await _client.rpc('toggle_post_reaction', params: {
      'p_post_id': postId,
      'p_user_id': userId,
      'p_reaction_type': reactionType,
    });
    return Map<String, dynamic>.from(response as Map);
  }

  @override
  Future<FeedPost> createPost({
    required int authorId,
    required String content,
    String? replyToPostId,
  }) async {
    final Map<String, dynamic> insertData = {
      'author_id': authorId,
      'content': content,
    };
    if (replyToPostId != null && replyToPostId.isNotEmpty) {
      insertData['reply_to_post_id'] = replyToPostId;
      try {
        final parentRes = await _client
            .from('posts')
            .select('root_post_id')
            .eq('id', replyToPostId)
            .maybeSingle();
        final String? parentRootId = parentRes?['root_post_id']?.toString();
        insertData['root_post_id'] = (parentRootId != null && parentRootId.isNotEmpty)
            ? parentRootId
            : replyToPostId;
      } catch (_) {
        insertData['root_post_id'] = replyToPostId;
      }
    }

    final response = await _client.from('posts').insert(insertData).select().single();
    final Map<String, dynamic> row = Map<String, dynamic>.from(response);

    // Fetch author profile details
    final profileRes = await _client
        .from('profiles')
        .select('name, avatar_url')
        .eq('id', authorId)
        .maybeSingle();

    final String authorName = profileRes?['name']?.toString() ?? 'User';
    final String authorAvatarUrl = profileRes?['avatar_url']?.toString() ?? '';

    return FeedPost(
      id: row['id'].toString(),
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      content: row['content'].toString(),
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'].toString()).toLocal()
          : DateTime.now(),
      replyCount: int.tryParse(row['reply_count']?.toString() ?? '0') ?? 0,
      degree: 0, // Own post
      isDeleted: row['is_deleted'] == true,
      replyToPostId: row['reply_to_post_id']?.toString(),
    );
  }

  @override
  Future<void> deletePost({
    required String postId,
    required int authorId,
  }) async {
    await _client.from('posts').update({'is_deleted': true}).eq('id', postId).eq('author_id', authorId);
  }

  @override
  Future<void> markPostsSeen({
    required int viewerId,
    required List<String> postIds,
  }) async {
    if (postIds.isEmpty) return;
    await _client.rpc('mark_posts_seen', params: {
      'p_viewer_id': viewerId,
      'p_post_ids': postIds,
    });
  }

  @override
  Future<int> getUnseenCount({
    required int viewerId,
    int cap = 20,
  }) async {
    final response = await _client.rpc('get_unseen_count', params: {
      'p_viewer_id': viewerId,
      'p_cap': cap,
    });
    return (response as int?) ?? 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getMutualConnections({
    required int viewerId,
    required int targetId,
  }) async {
    final response = await _client.rpc('get_mutual_connections', params: {
      'p_viewer_id': viewerId,
      'p_target_id': targetId,
    });
    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<void> reportPost({
    required int reporterId,
    required int reportedUserId,
    required String postId,
    required String reason,
    String? additionalDetails,
  }) async {
    await _client.from('content_reports').insert({
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'post_id': postId,
      'reason': reason,
      'additional_details': additionalDetails,
    });
  }

  @override
  RealtimeChannel subscribeToPosts({
    required void Function(Map<String, dynamic> payload) onChange,
    void Function(RealtimeSubscribeStatus status, Object? error)? onStatusChange,
  }) {
    final channel = _client.channel('public:feed:${DateTime.now().millisecondsSinceEpoch}');
    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'posts',
        callback: (payload) {
          onChange({
            'table': 'posts',
            'eventType': payload.eventType.name,
            'new': payload.newRecord,
            'old': payload.oldRecord,
          });
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'post_reactions',
        callback: (payload) {
          onChange({
            'table': 'post_reactions',
            'eventType': payload.eventType.name,
            'new': payload.newRecord,
            'old': payload.oldRecord,
          });
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'blocked_users',
        callback: (payload) {
          onChange({
            'table': 'blocked_users',
            'eventType': payload.eventType.name,
            'new': payload.newRecord,
            'old': payload.oldRecord,
          });
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_connections',
        callback: (payload) {
          onChange({
            'table': 'user_connections',
            'eventType': payload.eventType.name,
            'new': payload.newRecord,
            'old': payload.oldRecord,
          });
        },
      )
      .subscribe((status, error) {
        onStatusChange?.call(status, error);
      });
    return channel;
  }

  @override
  void unsubscribeChannel(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }

  @override
  Future<Map<String, dynamic>> getPostsReactionSummaries({
    required List<String> postIds,
    required int viewerId,
  }) async {
    if (postIds.isEmpty) return {};
    try {
      final response = await _client.rpc('get_posts_reaction_summaries', params: {
        'p_post_ids': postIds,
        'p_viewer_id': viewerId,
      });
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {};
    } catch (e) {
      debugPrint("[FeedRepository] Error fetching reaction summaries: $e");
      return {};
    }
  }

  @override
  Future<FeedPost?> getPostById({
    required String postId,
    required int viewerId,
  }) async {
    try {
      final response = await _client
          .from('posts')
          .select('*, profiles!author_id(name, avatar_url)')
          .eq('id', postId)
          .maybeSingle();

      if (response == null) return null;

      final authorId = response['author_id'] is int
          ? response['author_id'] as int
          : (int.tryParse(response['author_id']?.toString() ?? '') ?? 0);

      int degree = (authorId == viewerId) ? 0 : 1;
      if (authorId != viewerId && viewerId != 0) {
        try {
          final reachRes = await _client.rpc('get_network_reach', params: {'p_user_id': viewerId});
          if (reachRes is List) {
            final match = reachRes.firstWhere(
              (item) {
                final rId = item['reachable_user_id'] is int
                    ? item['reachable_user_id'] as int
                    : (int.tryParse(item['reachable_user_id']?.toString() ?? '') ?? 0);
                return rId == authorId;
              },
              orElse: () => null,
            );
            if (match != null) {
              degree = match['degree'] is int
                  ? match['degree'] as int
                  : (int.tryParse(match['degree']?.toString() ?? '') ?? 1);
            }
          }
        } catch (_) {}
      }

      final profile = response['profiles'] as Map<String, dynamic>?;

      Map<String, int> reactionCounts = {};
      if (response['reaction_counts'] is Map) {
        (response['reaction_counts'] as Map).forEach((k, v) {
          final c = v is int ? v : (int.tryParse(v?.toString() ?? '') ?? 0);
          if (c > 0) reactionCounts[k.toString()] = c;
        });
      }

      return FeedPost(
        id: response['id'].toString(),
        authorId: authorId,
        authorName: profile?['name']?.toString() ?? 'User',
        authorAvatarUrl: profile?['avatar_url']?.toString() ?? '',
        content: response['content']?.toString() ?? '',
        createdAt: response['created_at'] != null
            ? DateTime.parse(response['created_at'].toString()).toLocal()
            : DateTime.now(),
        replyCount: response['reply_count'] is int
            ? response['reply_count'] as int
            : (int.tryParse(response['reply_count']?.toString() ?? '') ?? 0),
        degree: degree,
        isDeleted: response['is_deleted'] == true,
        replyToPostId: response['reply_to_post_id']?.toString(),
        reactionCounts: reactionCounts,
      );
    } catch (e) {
      return null;
    }
  }
}
