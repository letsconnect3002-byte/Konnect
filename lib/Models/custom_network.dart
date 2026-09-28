import 'package:flutter/material.dart';

class CustomNetwork {
  final String id;
  final int creatorId;
  final String name;
  final String? description;
  final String iconEmoji;
  final String colorHex;
  final bool isPrivate;
  final bool allowAnonymous;
  final DateTime createdAt;
  final int memberCount;
  final bool isMember;
  final bool isCreator;
  final String? pinnedPostId;

  const CustomNetwork({
    required this.id,
    required this.creatorId,
    required this.name,
    this.description,
    required this.iconEmoji,
    required this.colorHex,
    required this.isPrivate,
    required this.allowAnonymous,
    required this.createdAt,
    this.memberCount = 1,
    this.isMember = true,
    this.isCreator = false,
    this.pinnedPostId,
  });

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('0xFF$hex'));
      } else if (hex.length == 8) {
        return Color(int.parse('0x$hex'));
      }
    } catch (_) {}
    return const Color(0xFF3B82F6);
  }

  factory CustomNetwork.fromJson(Map<String, dynamic> json, {int? currentUserId}) {
    final creatorId = int.tryParse(json['creator_id']?.toString() ?? '0') ?? 0;
    final isCreator = currentUserId != null && currentUserId == creatorId;
    
    return CustomNetwork(
      id: json['id']?.toString() ?? '',
      creatorId: creatorId,
      name: json['name']?.toString() ?? 'Network',
      description: json['description']?.toString(),
      iconEmoji: json['icon_emoji']?.toString() ?? '🌐',
      colorHex: json['color_hex']?.toString() ?? '#3B82F6',
      isPrivate: json['is_private'] == true,
      allowAnonymous: json['allow_anonymous'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      memberCount: int.tryParse(json['member_count']?.toString() ?? '1') ?? 1,
      isMember: json['is_member'] == true || isCreator,
      isCreator: isCreator,
      pinnedPostId: json['pinned_post_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creator_id': creatorId,
      'name': name,
      'description': description,
      'icon_emoji': iconEmoji,
      'color_hex': colorHex,
      'is_private': isPrivate,
      'allow_anonymous': allowAnonymous,
      'created_at': createdAt.toIso8601String(),
      'pinned_post_id': pinnedPostId,
    };
  }

  CustomNetwork copyWith({
    String? id,
    int? creatorId,
    String? name,
    String? description,
    String? iconEmoji,
    String? colorHex,
    bool? isPrivate,
    bool? allowAnonymous,
    DateTime? createdAt,
    int? memberCount,
    bool? isMember,
    bool? isCreator,
    String? pinnedPostId,
    bool nullifyPinnedPostId = false,
  }) {
    return CustomNetwork(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      name: name ?? this.name,
      description: description ?? this.description,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      colorHex: colorHex ?? this.colorHex,
      isPrivate: isPrivate ?? this.isPrivate,
      allowAnonymous: allowAnonymous ?? this.allowAnonymous,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
      isMember: isMember ?? this.isMember,
      isCreator: isCreator ?? this.isCreator,
      pinnedPostId: nullifyPinnedPostId ? null : (pinnedPostId ?? this.pinnedPostId),
    );
  }
}

class CustomNetworkMember {
  final String id;
  final String networkId;
  final int userId;
  final int addedBy;
  final String role;
  final DateTime createdAt;
  final String name;
  final String avatarUrl;
  final String profession;

  const CustomNetworkMember({
    required this.id,
    required this.networkId,
    required this.userId,
    required this.addedBy,
    required this.role,
    required this.createdAt,
    required this.name,
    required this.avatarUrl,
    this.profession = '',
  });

  factory CustomNetworkMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return CustomNetworkMember(
      id: json['id']?.toString() ?? '',
      networkId: json['network_id']?.toString() ?? '',
      userId: int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      addedBy: int.tryParse(json['added_by']?.toString() ?? '0') ?? 0,
      role: json['role']?.toString() ?? 'member',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      name: profile?['name']?.toString() ?? json['name']?.toString() ?? 'User',
      avatarUrl: profile?['avatar_url']?.toString() ?? json['avatar_url']?.toString() ?? '',
      profession: profile?['profession']?.toString() ?? json['profession']?.toString() ?? '',
    );
  }
}
