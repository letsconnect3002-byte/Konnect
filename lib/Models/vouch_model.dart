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
  final String? relationshipType;
  final String? contextTag;
  final String? optionalNote;
  final List<String> privateIntents;
  final String status;

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
    this.relationshipType,
    this.contextTag,
    this.optionalNote,
    this.privateIntents = const [],
    this.status = 'accepted',
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

    final rawStatement = json['statement']?.toString() ?? '';

    // Parse structured data from dedicated columns or statement buffer
    String? relType = json['relationship_type']?.toString();
    String? ctxTag = json['context_tag']?.toString();
    String? optNote = json['optional_note']?.toString();
    List<String> parsedIntents = [];

    if (json['private_intents'] is List) {
      parsedIntents = (json['private_intents'] as List)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    if (relType == null && rawStatement.contains('REL:[')) {
      try {
        final relMatch = RegExp(r'REL:\[(.*?)\]').firstMatch(rawStatement);
        if (relMatch != null) {
          relType = relMatch.group(1);
        }
      } catch (_) {}
    }

    if (ctxTag == null && rawStatement.contains('TAG:[')) {
      try {
        final tagMatch = RegExp(r'TAG:\[(.*?)\]').firstMatch(rawStatement);
        if (tagMatch != null) {
          ctxTag = tagMatch.group(1);
        }
      } catch (_) {}
    }

    if (parsedIntents.isEmpty && rawStatement.contains('INTENTS:[')) {
      try {
        final intentMatch = RegExp(r'INTENTS:\[(.*?)\]').firstMatch(rawStatement);
        if (intentMatch != null) {
          parsedIntents = intentMatch
              .group(1)!
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }

    if (optNote == null && rawStatement.contains('NOTE:[')) {
      try {
        final noteMatch = RegExp(r'NOTE:\[(.*?)\]', dotAll: true).firstMatch(rawStatement);
        if (noteMatch != null) {
          optNote = noteMatch.group(1);
        }
      } catch (_) {}
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
      statement: rawStatement,
      feedScope: json['feed_scope']?.toString() ?? 'network',
      announcementPostId: json['announcement_post_id']?.toString(),
      createdAt: parsedDate,
      relationshipType: relType,
      contextTag: ctxTag,
      optionalNote: optNote,
      privateIntents: parsedIntents,
      status: json['status']?.toString() ?? 'accepted',
    );
  }

  /// Clean display statement or formatted summary
  String get displayStatement {
    if (relationshipType != null && relationshipType!.isNotEmpty) {
      final buffer = StringBuffer();
      buffer.write(relationshipType);
      if (contextTag != null && contextTag!.isNotEmpty) {
        buffer.write(' • $contextTag');
      }
      if (optionalNote != null && optionalNote!.trim().isNotEmpty) {
        buffer.write('\n\n"${optionalNote!.trim()}"');
      }
      return buffer.toString();
    }
    final clean = statement
        .replaceAll(RegExp(r'INTENTS:\[.*?\]'), '')
        .replaceAll(RegExp(r'REL:\[.*?\]'), '')
        .replaceAll(RegExp(r'TAG:\[.*?\]'), '')
        .trim();
    return clean.isNotEmpty ? clean : (relationshipType ?? 'Vouched');
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
      'relationship_type': relationshipType,
      'private_intents': privateIntents,
      'optional_note': optionalNote,
      'status': status,
    };
  }
}
