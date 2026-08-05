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
  }) : activeReplyCount = activeReplyCount ?? replyCount;


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
          : (int.tryParse(json['degree']?.toString() ?? '') ?? 0),
      isDeleted: json['is_deleted'] == true,
      replyToPostId: json['reply_to_post_id']?.toString(),
      userReaction: json['user_reaction']?.toString(),
      reactionCounts: parsedReactionCounts,
    );
  }

  factory FeedPost.fromThreadRpcJson(Map<String, dynamic> json, {int degree = 1}) {
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
      activeReplyCount: null,
      degree: degree,
      isDeleted: json['is_deleted'] == true,
      replyToPostId: json['reply_to_post_id']?.toString(),
      userReaction: json['user_reaction']?.toString(),
      reactionCounts: parsedReactionCounts,
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
  }) {
    return FeedPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      replyCount: replyCount ?? this.replyCount,
      activeReplyCount: activeReplyCount ?? this.activeReplyCount,
      degree: degree ?? this.degree,
      isDeleted: isDeleted ?? this.isDeleted,
      replyToPostId: replyToPostId ?? this.replyToPostId,
      userReaction: nullifyUserReaction ? null : (userReaction ?? this.userReaction),
      reactionCounts: reactionCounts ?? this.reactionCounts,
    );
  }
}
