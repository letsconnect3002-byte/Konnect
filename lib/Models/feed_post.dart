import 'package:flutter/foundation.dart';

class FeedPost {
  final String id;
  final int authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String content;
  final DateTime createdAt;
  final int replyCount;
  final int activeReplyCount;
  final int degree; // 0 = self, 1 = direct, 2 = 2nd degree (mutual), 3 = 3rd degree
  final bool isDeleted;
  final String? replyToPostId;
  final String? userReaction;
  final Map<String, int> reactionCounts;
  final String visibility; // 'casual', 'professional', 'both'
  final bool isAnonymous;

  FeedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
    required this.replyCount,
    int? activeReplyCount,
    required this.degree,
    this.isDeleted = false,
    this.replyToPostId,
    this.userReaction,
    this.reactionCounts = const {},
    this.visibility = 'both',
    this.isAnonymous = false,
  }) : activeReplyCount = activeReplyCount ?? replyCount;


  bool get isGlobalUnconnected => degree == -1;
  bool get isConnectedInNetwork => degree >= 1 && degree <= 3;

  int get totalReactions {
    int total = 0;
    for (final count in reactionCounts.values) {
      total += count;
    }
    return total;
  }

  static const Map<String, String> reactionEmojiMap = {
    'like': '❤️',
    'fire': '🔥',
    'clap': '👏',
    'laugh': '😂',
    'mindblown': '🤯',
    'insight': '💡',
  };

  List<String> get topReactionEmojis {
    final sortedEntries = reactionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedEntries
        .take(3)
        .map((e) => reactionEmojiMap[e.key] ?? '❤️')
        .toList();
  }

  factory FeedPost.fromRpcJson(Map<String, dynamic> json) {
    Map<String, int> parsedReactionCounts = {};
    if (json['reaction_counts'] != null && json['reaction_counts'] is Map) {
      final map = json['reaction_counts'] as Map;
      map.forEach((key, value) {
        if (value is int) {
          parsedReactionCounts[key.toString()] = value;
        } else if (value != null) {
          parsedReactionCounts[key.toString()] =
              int.tryParse(value.toString()) ?? 0;
        }
      });
    }

    return FeedPost(
      id: json['post_id']?.toString() ?? json['id']?.toString() ?? '',
      authorId: json['author_id'] is int
          ? json['author_id'] as int
          : (int.tryParse(json['author_id']?.toString() ?? '') ?? 0),
      authorName: json['author_name']?.toString() ?? 'Anonymous',
      authorAvatarUrl: json['author_avatar_url']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString()).toLocal()
          : DateTime.now(),
      replyCount: json['reply_count'] is int
          ? json['reply_count'] as int
          : (int.tryParse(json['reply_count']?.toString() ?? '') ?? 0),
      activeReplyCount: json['active_reply_count'] is int
          ? json['active_reply_count'] as int
          : int.tryParse(json['active_reply_count']?.toString() ?? ''),
      degree: json['degree'] is int
          ? json['degree'] as int
          : (int.tryParse(json['degree']?.toString() ?? '') ?? -1),
      isDeleted: json['is_deleted'] == true,
      replyToPostId: json['reply_to_post_id']?.toString(),
      userReaction: json['user_reaction']?.toString(),
      reactionCounts: parsedReactionCounts,
      visibility: json['visibility']?.toString() ?? 'both',
      isAnonymous: json['is_anonymous'] == true,
    );
  }

  factory FeedPost.fromThreadRpcJson(Map<String, dynamic> json, {int degree = -1}) {
    Map<String, int> parsedReactionCounts = {};
    if (json['reaction_counts'] != null && json['reaction_counts'] is Map) {
      final map = json['reaction_counts'] as Map;
      map.forEach((key, value) {
        if (value is int) {
          parsedReactionCounts[key.toString()] = value;
        } else if (value != null) {
          parsedReactionCounts[key.toString()] =
              int.tryParse(value.toString()) ?? 0;
        }
      });
    }

    return FeedPost(
      id: json['post_id']?.toString() ?? json['id']?.toString() ?? '',
      authorId: json['author_id'] is int
          ? json['author_id'] as int
          : (int.tryParse(json['author_id']?.toString() ?? '') ?? 0),
      authorName: json['author_name']?.toString() ?? 'Anonymous',
      authorAvatarUrl: json['author_avatar_url']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString()).toLocal()
          : DateTime.now(),
      replyCount: json['reply_count'] is int
          ? json['reply_count'] as int
          : (int.tryParse(json['reply_count']?.toString() ?? '') ?? 0),
      activeReplyCount: json['active_reply_count'] is int
          ? json['active_reply_count'] as int
          : int.tryParse(json['active_reply_count']?.toString() ?? ''),
      degree: json['degree'] is int
          ? json['degree'] as int
          : (int.tryParse(json['degree']?.toString() ?? '') ?? degree),
      isDeleted: json['is_deleted'] == true,
      replyToPostId: json['reply_to_post_id']?.toString(),
      userReaction: json['user_reaction']?.toString(),
      reactionCounts: parsedReactionCounts,
      visibility: json['visibility']?.toString() ?? 'both',
      isAnonymous: json['is_anonymous'] == true,
    );
  }

  FeedPost copyWith({
    String? id,
    int? authorId,
    String? authorName,
    String? authorAvatarUrl,
    String? content,
    DateTime? createdAt,
    int? replyCount,
    int? activeReplyCount,
    int? degree,
    bool? isDeleted,
    String? replyToPostId,
    String? userReaction,
    bool nullifyUserReaction = false,
    Map<String, int>? reactionCounts,
    String? visibility,
    bool? isAnonymous,
  }) {
    final int newReplyCount = replyCount ?? this.replyCount;
    final int newActiveReplyCount = activeReplyCount ??
        (replyCount != null ? newReplyCount : this.activeReplyCount);
    return FeedPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      replyCount: newReplyCount,
      activeReplyCount: newActiveReplyCount,
      degree: degree ?? this.degree,
      isDeleted: isDeleted ?? this.isDeleted,
      replyToPostId: replyToPostId ?? this.replyToPostId,
      userReaction: nullifyUserReaction ? null : (userReaction ?? this.userReaction),
      reactionCounts: reactionCounts ?? this.reactionCounts,
      visibility: visibility ?? this.visibility,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedPost &&
        other.id == id &&
        other.authorId == authorId &&
        other.authorName == authorName &&
        other.authorAvatarUrl == authorAvatarUrl &&
        other.content == content &&
        other.createdAt == createdAt &&
        other.replyCount == replyCount &&
        other.activeReplyCount == activeReplyCount &&
        other.degree == degree &&
        other.isDeleted == isDeleted &&
        other.replyToPostId == replyToPostId &&
        other.userReaction == userReaction &&
        other.visibility == visibility &&
        other.isAnonymous == isAnonymous &&
        mapEquals(other.reactionCounts, reactionCounts);
  }

  @override
  int get hashCode => Object.hash(
        id,
        authorId,
        userReaction,
        replyCount,
        activeReplyCount,
        visibility,
        isAnonymous,
        Object.hashAll(reactionCounts.entries.map((e) => Object.hash(e.key, e.value))),
      );
}

/// Pure delta function to apply realtime insert/update/delete events on post_reactions
/// consistently across all feed and thread components.
FeedPost applyReactionDelta(
  FeedPost post, {
  required String eventType,
  required Map<String, dynamic> newRecord,
  required Map<String, dynamic> oldRecord,
  int? viewerId,
}) {
  final event = eventType.toLowerCase();
  final int? eventUserId = newRecord['user_id'] is int
      ? newRecord['user_id'] as int
      : int.tryParse(newRecord['user_id']?.toString() ??
          oldRecord['user_id']?.toString() ??
          '');

  final Map<String, int> counts = Map<String, int>.from(post.reactionCounts);
  String? userReaction = post.userReaction;

  final bool isSelf = eventUserId != null && viewerId != null && eventUserId == viewerId;

  if (isSelf) {
    // Viewer's own reaction: counts are handled optimistically by toggleReaction()
    // and self-correct via server response. Only sync the userReaction indicator.
    if (event == 'insert' || event == 'update') {
      userReaction = newRecord['reaction_type']?.toString();
    } else if (event == 'delete') {
      userReaction = null;
    }
  } else {
    // Another user's reaction: adjust the reaction counts accordingly.
    if (event == 'insert') {
      final String reactionType =
          newRecord['reaction_type']?.toString() ?? 'like';
      counts[reactionType] = (counts[reactionType] ?? 0) + 1;
    } else if (event == 'delete') {
      final String reactionType = oldRecord['reaction_type']?.toString() ??
          newRecord['reaction_type']?.toString() ??
          'like';
      if (counts.containsKey(reactionType)) {
        final current = counts[reactionType]!;
        if (current <= 1) {
          counts.remove(reactionType);
        } else {
          counts[reactionType] = current - 1;
        }
      }
    } else if (event == 'update') {
      final String? oldReactionType = oldRecord['reaction_type']?.toString();
      final String newReactionType =
          newRecord['reaction_type']?.toString() ?? 'like';

      if (oldReactionType != null && counts.containsKey(oldReactionType)) {
        final prev = counts[oldReactionType]!;
        if (prev <= 1) {
          counts.remove(oldReactionType);
        } else {
          counts[oldReactionType] = prev - 1;
        }
      }
      counts[newReactionType] = (counts[newReactionType] ?? 0) + 1;
    }
  }

  return post.copyWith(
    reactionCounts: counts,
    userReaction: userReaction,
    nullifyUserReaction: userReaction == null,
  );
}

