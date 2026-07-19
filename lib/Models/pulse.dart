class PulseTag {
  final int id;
  final String name;
  final String type; // 'status' or 'ask'
  final String? icon;
  final String? color;
  final String? placeholder;
  final int defaultDurationHours;
  final bool allowFollowups;
  final int sortOrder;
  final bool isActive;
  final String? actionType;
  final DateTime createdAt;

  PulseTag({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.placeholder,
    required this.defaultDurationHours,
    required this.allowFollowups,
    required this.sortOrder,
    required this.isActive,
    this.actionType,
    required this.createdAt,
  });

  factory PulseTag.fromJson(Map<String, dynamic> json) {
    return PulseTag(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'status',
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      placeholder: json['placeholder'] as String?,
      defaultDurationHours: json['default_duration_hours'] as int? ?? 8,
      allowFollowups: json['allow_followups'] == true,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] == true,
      actionType: json['action_type'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString()).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
      'placeholder': placeholder,
      'default_duration_hours': defaultDurationHours,
      'allow_followups': allowFollowups,
      'sort_order': sortOrder,
      'is_active': isActive,
      'action_type': actionType,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

class UserPulse {
  final String id;
  final int userId;
  final int pulseTagId;
  final String pulseType;
  final String? text;
  final String visibility; // 'casual', 'professional', 'both'
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final String userName;
  final String userProfession;
  final String userAvatarUrl;
  final String userCompany;
  final PulseTag? tag;
  final List<int> hiddenUserIds;

  UserPulse({
    required this.id,
    required this.userId,
    required this.pulseTagId,
    required this.pulseType,
    this.text,
    required this.visibility,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.userName = '',
    this.userProfession = '',
    this.userAvatarUrl = '',
    this.userCompany = '',
    this.tag,
    this.hiddenUserIds = const [],
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory UserPulse.fromJson(Map<String, dynamic> json) {
    // Check if tag relation is parsed
    PulseTag? tag;
    if (json['pulse_tags'] != null) {
      tag = PulseTag.fromJson(json['pulse_tags'] as Map<String, dynamic>);
    } else if (json['tag'] != null) {
      tag = PulseTag.fromJson(json['tag'] as Map<String, dynamic>);
    }

    // Extract profile values
    final profile = json['profiles'] as Map<String, dynamic>?;
    final userName = profile != null ? (profile['name'] as String? ?? '') : (json['user_name'] as String? ?? '');
    final userProfession = profile != null ? (profile['profession'] as String? ?? '') : (json['user_profession'] as String? ?? '');
    final userAvatarUrl = profile != null ? (profile['avatar_url'] as String? ?? '') : (json['user_avatar_url'] as String? ?? '');
    final userCompany = profile != null ? (profile['company'] as String? ?? '') : (json['user_company'] as String? ?? '');

    final List<dynamic>? hiddenList = json['pulse_hidden_users'] as List<dynamic>?;
    final List<int> hiddenUserIds = hiddenList != null
        ? hiddenList.map((h) => (h['hidden_user_id'] as num).toInt()).toList()
        : <int>[];

    return UserPulse(
      id: json['id'] as String,
      userId: json['user_id'] as int,
      pulseTagId: json['pulse_tag_id'] as int,
      pulseType: json['pulse_type'] as String? ?? 'status',
      text: json['text'] as String?,
      visibility: json['visibility'] as String? ?? 'both',
      status: json['status'] as String? ?? 'active',
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'].toString()).toLocal()
          : DateTime.now().add(const Duration(hours: 8)),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString()).toLocal()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString()).toLocal()
          : DateTime.now(),
      userName: userName,
      userProfession: userProfession,
      userAvatarUrl: userAvatarUrl,
      userCompany: userCompany,
      tag: tag,
      hiddenUserIds: hiddenUserIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'pulse_tag_id': pulseTagId,
      'pulse_type': pulseType,
      'text': text,
      'visibility': visibility,
      'status': status,
      'expires_at': expiresAt.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'user_name': userName,
      'user_profession': userProfession,
      'user_avatar_url': userAvatarUrl,
      'user_company': userCompany,
      'tag': tag?.toJson(),
    };
  }

  UserPulse copyWith({
    String? id,
    int? userId,
    int? pulseTagId,
    String? pulseType,
    String? text,
    String? visibility,
    String? status,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userProfession,
    String? userAvatarUrl,
    String? userCompany,
    PulseTag? tag,
  }) {
    return UserPulse(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      pulseTagId: pulseTagId ?? this.pulseTagId,
      pulseType: pulseType ?? this.pulseType,
      text: text ?? this.text,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userProfession: userProfession ?? this.userProfession,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      userCompany: userCompany ?? this.userCompany,
      tag: tag ?? this.tag,
    );
  }
}

class PulseUpdate {
  final String id;
  final String pulseId;
  final String text;
  final DateTime createdAt;

  PulseUpdate({
    required this.id,
    required this.pulseId,
    required this.text,
    required this.createdAt,
  });

  factory PulseUpdate.fromJson(Map<String, dynamic> json) {
    return PulseUpdate(
      id: json['id'] as String,
      pulseId: json['pulse_id'] as String,
      text: json['text'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString()).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pulse_id': pulseId,
      'text': text,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
