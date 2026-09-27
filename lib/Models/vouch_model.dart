class UserVouch {
  final String id;
  final int voucherId;
  final String voucherName;
  final String voucherAvatarUrl;
  final String voucherProfession;
  final String voucherCompany;
  final int voucheeId;
  final String statement;
  final String feedScope; // 'network', 'global', 'profile_only'
  final String? announcementPostId;
  final DateTime createdAt;

  const UserVouch({
    required this.id,
    required this.voucherId,
    required this.voucherName,
    required this.voucherAvatarUrl,
    required this.voucherProfession,
    required this.voucherCompany,
    required this.voucheeId,
    required this.statement,
    required this.feedScope,
    this.announcementPostId,
    required this.createdAt,
  });

  factory UserVouch.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final String vName = profile?['name']?.toString() ??
        json['voucher_name']?.toString() ??
        'A Member';
    final String vAvatar = profile?['avatar_url']?.toString() ??
        json['voucher_avatar_url']?.toString() ??
        '';
    final String vProfession = profile?['profession']?.toString() ??
        json['voucher_profession']?.toString() ??
        '';
    final String vCompany = profile?['company']?.toString() ??
        json['voucher_company']?.toString() ??
        '';

    DateTime parsedDate;
    try {
      parsedDate = json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return UserVouch(
      id: json['id']?.toString() ?? '',
      voucherId: (json['voucher_id'] is int)
          ? json['voucher_id'] as int
          : (int.tryParse(json['voucher_id']?.toString() ?? '0') ?? 0),
      voucherName: vName,
      voucherAvatarUrl: vAvatar,
      voucherProfession: vProfession,
      voucherCompany: vCompany,
      voucheeId: (json['vouchee_id'] is int)
          ? json['vouchee_id'] as int
          : (int.tryParse(json['vouchee_id']?.toString() ?? '0') ?? 0),
      statement: json['statement']?.toString() ?? '',
      feedScope: json['feed_scope']?.toString() ?? 'network',
      announcementPostId: json['announcement_post_id']?.toString(),
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'voucher_id': voucherId,
      'vouchee_id': voucheeId,
      'statement': statement,
      'feed_scope': feedScope,
      'announcement_post_id': announcementPostId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
