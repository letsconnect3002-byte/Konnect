import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ConnectionRepository {
  Future<List<Map<String, dynamic>>> getOtherProfiles(int myUserId);
  Future<void> saveOtherProfileData(Map<String, dynamic> data);
  Future<bool> connectionExists(int id1, int id2);
  Future<void> connectUsers(int id1, int id2, String u1Share, String u2Share);
  Future<void> updateConnectionAccess(int id1, int id2, String columnToUpdate, String newAccessType);
  Future<void> disconnectUsers(int id1, int id2);
  Future<Map<String, dynamic>?> redeemInviteCode(String code);
  Future<void> markInviteCodeAsUsed(String id);
  Future<void> markInviteCodeAsUsedByCode(String code);
  Future<String?> getInviteCodeUserAction(String code, int userId);
  Future<void> recordInviteCodeAction(String code, int userId, String action);
  Future<void> deleteMyProfile(int id);
  Future<String?> resolveRoomId(int myUserId, int otherUserId);
  RealtimeChannel subscribeToConnections(void Function(dynamic payload) callback);
  void removeChannel(RealtimeChannel channel);
}

class SupabaseConnectionRepository implements ConnectionRepository {
  final SupabaseClient _client;

  SupabaseConnectionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> getOtherProfiles(int myUserId) async {
    final response = await _client
        .from('user_connections')
        .select('user_id_1, user_id_2, user_1_shared_card, user_2_shared_card')
        .or('user_id_1.eq.$myUserId,user_id_2.eq.$myUserId');

    final List<dynamic> rows = response as List;
    if (rows.isEmpty) {
      return [];
    }

    final Map<int, String> sharedCardLookup = {};
    final Map<int, String> mySharedCardLookup = {};
    final List<int> connectedIds = [];

    for (final row in rows) {
      final int id1 = row['user_id_1'] as int;
      final int id2 = row['user_id_2'] as int;
      final int otherId = (id1 == myUserId) ? id2 : id1;
      connectedIds.add(otherId);

      if (id1 == myUserId) {
        mySharedCardLookup[otherId] = (row['user_1_shared_card'] ?? 'casual').toString();
        sharedCardLookup[otherId] = (row['user_2_shared_card'] ?? 'casual').toString();
      } else {
        mySharedCardLookup[otherId] = (row['user_2_shared_card'] ?? 'casual').toString();
        sharedCardLookup[otherId] = (row['user_1_shared_card'] ?? 'casual').toString();
      }
    }

    if (connectedIds.isEmpty) {
      return [];
    }

    final profilesResponse = await _client
        .from('profiles')
        .select()
        .filter('id', 'in', '(${connectedIds.join(",")})');

    final List<dynamic> profileRows = profilesResponse as List;

    return profileRows.map((row) {
      final int profileId = row['id'] as int;
      return {
        'id': profileId,
        'name': row['name'] ?? '',
        'profession': row['profession'] ?? '',
        'email': row['email'] ?? '',
        'professionalEmail': row['professional_email'] ?? '',
        'phoneNumber': row['phone_number'] ?? '',
        'professionalPhoneNumber': row['professional_phone_number'] ?? '',
        'instagram': row['instagram'] ?? '',
        'linkedin': row['linkedin'] ?? '',
        'twitter': row['twitter'] ?? '',
        'isMyProfile': row['is_my_profile'] == true,
        'created_at': row['created_at'],
        'company': row['company'] ?? '',
        'avatarUrl': row['avatar_url'] ?? '',
        'bio': row['bio'] ?? '',
        'professionalBio': row['professional_bio'] ?? '',
        'showProfileToConnections': row['show_profile_to_connections'] == true,
        'cardTypes': row['card_types'] != null
            ? List<String>.from(row['card_types'] as List)
            : <String>[],
        'connection_profile_id': profileId,
        'shared_card': sharedCardLookup[profileId] ?? 'casual',
        'my_shared_card': mySharedCardLookup[profileId] ?? 'casual',
        'field_assignments': row['field_assignments'],
      };
    }).toList();
  }

  @override
  Future<void> saveOtherProfileData(Map<String, dynamic> data) async {
    await _client.from('profiles').insert(data);
  }

  @override
  Future<bool> connectionExists(int id1, int id2) async {
    final response = await _client
        .from('user_connections')
        .select('user_id_1, user_id_2')
        .eq('user_id_1', id1)
        .eq('user_id_2', id2)
        .maybeSingle();
    return response != null;
  }

  @override
  Future<void> connectUsers(int id1, int id2, String u1Share, String u2Share) async {
    await _client.from('user_connections').upsert({
      'user_id_1': id1,
      'user_id_2': id2,
      'user_1_shared_card': u1Share,
      'user_2_shared_card': u2Share,
    });
  }

  @override
  Future<void> updateConnectionAccess(int id1, int id2, String columnToUpdate, String newAccessType) async {
    await _client
        .from('user_connections')
        .update({columnToUpdate: newAccessType})
        .eq('user_id_1', id1)
        .eq('user_id_2', id2);
  }

  @override
  Future<void> disconnectUsers(int id1, int id2) async {
    await _client
        .from('user_connections')
        .delete()
        .eq('user_id_1', id1)
        .eq('user_id_2', id2);
  }

  @override
  Future<Map<String, dynamic>?> redeemInviteCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    final row = await _client
        .from('invite_codes')
        .select()
        .ilike('code', cleanCode)
        .maybeSingle();

    if (row == null) return null;

    final keyType = row['key_type']?.toString() ?? 'single_use';
    if (keyType == 'group_24h') {
      final expiresAtStr = row['expires_at']?.toString();
      if (expiresAtStr != null) {
        final expiresAt = DateTime.parse(expiresAtStr);
        if (DateTime.now().toUtc().isAfter(expiresAt.toUtc())) {
          return {'expired': true, ...row};
        }
      }
      return row;
    } else {
      final isUsed = row['is_used'] == true;
      if (isUsed) {
        return {'already_used': true, ...row};
      }
      return row;
    }
  }

  @override
  Future<void> markInviteCodeAsUsed(String id) async {
    try {
      final row = await _client
          .from('invite_codes')
          .select('key_type, uses_count')
          .eq('id', id)
          .maybeSingle();

      final keyType = row?['key_type']?.toString() ?? 'single_use';
      final currentUses = (row?['uses_count'] as int?) ?? 0;

      if (keyType == 'single_use') {
        await _client
            .from('invite_codes')
            .update({
              'is_used': true,
              'uses_count': currentUses + 1,
            })
            .eq('id', id);
      } else {
        await _client
            .from('invite_codes')
            .update({
              'uses_count': currentUses + 1,
            })
            .eq('id', id);
      }
    } catch (e) {
      debugPrint('[ConnectionRepository] Error marking invite code as used: $e');
    }
  }

  @override
  Future<void> markInviteCodeAsUsedByCode(String code) async {
    try {
      final cleanCode = code.trim().toUpperCase();
      final row = await _client
          .from('invite_codes')
          .select('id')
          .ilike('code', cleanCode)
          .maybeSingle();

      if (row != null) {
        await markInviteCodeAsUsed(row['id'] as String);
      }
    } catch (e) {
      debugPrint('[ConnectionRepository] Error marking invite code by code: $e');
    }
  }

  @override
  Future<String?> getInviteCodeUserAction(String code, int userId) async {
    try {
      final cleanCode = code.trim().toUpperCase();
      final row = await _client
          .from('invite_code_redemptions')
          .select('action')
          .ilike('code', cleanCode)
          .eq('user_id', userId)
          .maybeSingle();

      return row?['action'] as String?;
    } catch (e) {
      debugPrint('[ConnectionRepository] Error querying invite code redemption action: $e');
      return null;
    }
  }

  @override
  Future<void> recordInviteCodeAction(String code, int userId, String action) async {
    try {
      final cleanCode = code.trim().toUpperCase();
      await _client.from('invite_code_redemptions').upsert(
        {
          'code': cleanCode,
          'user_id': userId,
          'action': action,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'code,user_id',
      );
      debugPrint('[ConnectionRepository] Recorded invite code action: $cleanCode by user $userId as $action');
    } catch (e) {
      debugPrint('[ConnectionRepository] Error recording invite code action: $e');
    }
  }

  @override
  Future<void> deleteMyProfile(int id) async {
    await _client.from('profiles').delete().eq('id', id);
  }

  @override
  Future<String?> resolveRoomId(int myUserId, int otherUserId) async {
    final myRooms = await _client
        .from('room_participants')
        .select('room_id')
        .eq('user_id', myUserId);
    final List<String> roomIds = (myRooms as List).map((r) => r['room_id'] as String).toList();
    if (roomIds.isNotEmpty) {
      final common = await _client
          .from('room_participants')
          .select('room_id, chat_rooms!inner(type)')
          .eq('user_id', otherUserId)
          .eq('chat_rooms.type', 'direct')
          .filter('room_id', 'in', '(${roomIds.join(",")})')
          .limit(1)
          .maybeSingle();
      if (common != null) {
        return common['room_id'] as String;
      }
    }
    return null;
  }

  @override
  RealtimeChannel subscribeToConnections(void Function(dynamic payload) callback) {
    final channel = _client
        .channel('public:user_connections_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_connections',
          callback: callback,
        );
    channel.subscribe();
    return channel;
  }

  @override
  void removeChannel(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}
