import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';

abstract class TribeRepository {
  Future<Map<String, dynamic>> createTribe(
      Map<String, dynamic> tribeData,
      List<Map<String, dynamic>> rolesData,
      Map<String, dynamic> creatorMemberData);
  Future<void> updateTribe(String tribeId, Map<String, dynamic> updates);
  Future<void> deleteTribe(String tribeId);
  Future<Map<String, dynamic>?> getTribeById(String tribeId);
  Future<Map<String, dynamic>?> getTribeByInviteCode(String inviteCode);
  Future<List<Map<String, dynamic>>> getMyTribes(int userId);
  Future<List<Map<String, dynamic>>> searchPublicTribes(String query);

  // Roles
  Future<List<Map<String, dynamic>>> getTribeRoles(String tribeId);
  Future<Map<String, dynamic>> createTribeRole(Map<String, dynamic> roleData);
  Future<void> updateTribeRole(String roleId, Map<String, dynamic> updates);
  Future<void> deleteTribeRole(String roleId);

  // Members
  Future<List<Map<String, dynamic>>> getTribeMembers(String tribeId);
  Future<Map<String, dynamic>?> getTribeMember(String tribeId, int userId);
  Future<Map<String, dynamic>> insertTribeMember(
      Map<String, dynamic> memberData);
  Future<void> updateTribeMemberStatus(String tribeId, int userId,
      Map<String, dynamic> updates, Map<String, dynamic> activityLogData);
  Future<void> changeMemberRole(String tribeId, int userId, String? roleId,
      Map<String, dynamic> updates, Map<String, dynamic> activityLogData);
  Future<int> getActiveMembersCount(String tribeId);

  // Messages
  Future<List<Map<String, dynamic>>> getTribeMessages(String tribeId);
  Future<Map<String, dynamic>> insertTribeMessage(
      Map<String, dynamic> messageData);
  Future<void> softDeleteTribeMessage(String messageId);
  Future<void> updateTribeMessage(String messageId, String newContent);

  // Moderation
  Future<void> reportTribeMessage({
    required int reporterId,
    required int reportedUserId,
    String? messageId,
    String? messageContent,
    required String reason,
    String? additionalDetails,
  });
  Future<void> blockUserInTribe({required int blockerId, required int blockedId});
  Future<Set<int>> getBlockedUserIds(int userId);

  // Activity Log
  Future<List<Map<String, dynamic>>> getTribeActivityLog(String tribeId);
  Future<void> insertTribeActivityLog(Map<String, dynamic> logData);

  // Realtime Subscriptions
  RealtimeChannel subscribeToTribeMessages(
      String tribeId, void Function(dynamic payload) callback);
  RealtimeChannel subscribeToTribeMembers(
      String tribeId, void Function(dynamic payload) callback);
  RealtimeChannel subscribeToTribeActivity(
      String tribeId, void Function(dynamic payload) callback);
  RealtimeChannel subscribeToUserMemberships(
      int userId, void Function(dynamic payload) callback);
  void removeChannel(RealtimeChannel channel);
}

class SupabaseTribeRepository implements TribeRepository {
  final SupabaseClient _client;

  SupabaseTribeRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<Map<String, dynamic>> createTribe(
    Map<String, dynamic> tribeData,
    List<Map<String, dynamic>> rolesData,
    Map<String, dynamic> creatorMemberData,
  ) async {
    // 1. Insert into tribes
    final tribeResponse =
        await _client.from('tribes').insert(tribeData).select().single();
    final tribeId = tribeResponse['id'] as String;

    try {
      // 2. Insert roles
      final rolesToInsert = rolesData.map((role) {
        final newRole = Map<String, dynamic>.from(role);
        newRole['tribe_id'] = tribeId;
        return newRole;
      }).toList();

      final rolesResponse =
          await _client.from('tribe_roles').insert(rolesToInsert).select();

      // Find Don role id to assign to creator
      final donRole = (rolesResponse as List).firstWhereOrNull(
        (r) => r['slug'] == 'don',
      );
      if (donRole == null) {
        throw Exception("Don role could not be seeded.");
      }

      // 3. Insert creator as member
      final memberToInsert = Map<String, dynamic>.from(creatorMemberData);
      memberToInsert['tribe_id'] = tribeId;
      memberToInsert['role_id'] = donRole['id'];

      await _client.from('tribe_members').insert(memberToInsert);

      return Map<String, dynamic>.from(tribeResponse);
    } catch (e) {
      // Cleanup: delete the created tribe row to prevent zombie state
      try {
        await _client.from('tribes').delete().eq('id', tribeId);
      } catch (cleanupErr) {
        print("Tribe creation cleanup failed: $cleanupErr");
      }
      rethrow;
    }
  }

  @override
  Future<void> updateTribe(String tribeId, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _client.from('tribes').update(updates).eq('id', tribeId);
  }

  @override
  Future<void> deleteTribe(String tribeId) async {
    await _client.from('tribes').delete().eq('id', tribeId);
  }

  @override
  Future<Map<String, dynamic>?> getTribeById(String tribeId) async {
    final response = await _client
        .from('tribes')
        .select('*, creator:profiles!creator_id(id, name, avatar_url)')
        .eq('id', tribeId)
        .maybeSingle();
    return response != null ? Map<String, dynamic>.from(response) : null;
  }

  @override
  Future<Map<String, dynamic>?> getTribeByInviteCode(String inviteCode) async {
    final response = await _client
        .from('tribes')
        .select('*, creator:profiles!creator_id(id, name, avatar_url)')
        .eq('invite_code', inviteCode)
        .maybeSingle();
    return response != null ? Map<String, dynamic>.from(response) : null;
  }

  @override
  Future<List<Map<String, dynamic>>> getMyTribes(int userId) async {
    final response = await _client
        .from('tribe_members')
        .select(
            '*, tribe:tribes(*, creator:profiles!creator_id(id, name, avatar_url)), role:tribe_roles(*)')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<List<Map<String, dynamic>>> searchPublicTribes(String query) async {
    var request = _client
        .from('tribes')
        .select('*, creator:profiles!creator_id(id, name, avatar_url)')
        .eq('visibility', 'public');
    if (query.isNotEmpty) {
      request = request.ilike('name', '%$query%');
    }
    final response = await request;
    return List<Map<String, dynamic>>.from(response as List);
  }

  // ── Roles ──
  @override
  Future<List<Map<String, dynamic>>> getTribeRoles(String tribeId) async {
    final response = await _client
        .from('tribe_roles')
        .select('*')
        .eq('tribe_id', tribeId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<Map<String, dynamic>> createTribeRole(
      Map<String, dynamic> roleData) async {
    final response =
        await _client.from('tribe_roles').insert(roleData).select().single();
    return Map<String, dynamic>.from(response);
  }

  @override
  Future<void> updateTribeRole(
      String roleId, Map<String, dynamic> updates) async {
    await _client.from('tribe_roles').update(updates).eq('id', roleId);
  }

  @override
  Future<void> deleteTribeRole(String roleId) async {
    await _client.from('tribe_roles').delete().eq('id', roleId);
  }

  // ── Members ──
  @override
  Future<List<Map<String, dynamic>>> getTribeMembers(String tribeId) async {
    final response = await _client
        .from('tribe_members')
        .select('*, profile:profiles!user_id(*), role:tribe_roles(*)')
        .eq('tribe_id', tribeId);
    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<Map<String, dynamic>?> getTribeMember(
      String tribeId, int userId) async {
    final response = await _client
        .from('tribe_members')
        .select('*, role:tribe_roles(*)')
        .eq('tribe_id', tribeId)
        .eq('user_id', userId)
        .maybeSingle();
    return response != null ? Map<String, dynamic>.from(response) : null;
  }

  @override
  Future<Map<String, dynamic>> insertTribeMember(
      Map<String, dynamic> memberData) async {
    final response = await _client
        .from('tribe_members')
        .insert(memberData)
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  @override
  Future<void> updateTribeMemberStatus(
    String tribeId,
    int userId,
    Map<String, dynamic> updates,
    Map<String, dynamic> activityLogData,
  ) async {
    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('tribe_members')
        .update(updates)
        .eq('tribe_id', tribeId)
        .eq('user_id', userId);
    await insertTribeActivityLog(activityLogData);
  }

  @override
  Future<void> changeMemberRole(
    String tribeId,
    int userId,
    String? roleId,
    Map<String, dynamic> updates,
    Map<String, dynamic> activityLogData,
  ) async {
    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('tribe_members')
        .update(updates)
        .eq('tribe_id', tribeId)
        .eq('user_id', userId);
    await insertTribeActivityLog(activityLogData);
  }

  @override
  Future<int> getActiveMembersCount(String tribeId) async {
    final response = await _client
        .from('tribe_members')
        .select('id')
        .eq('tribe_id', tribeId)
        .eq('status', 'active');
    return (response as List).length;
  }

  // ── Messages ──
  @override
  Future<List<Map<String, dynamic>>> getTribeMessages(String tribeId) async {
    final response = await _client
        .from('tribe_messages')
        .select(
            '*, sender:profiles!sender_id(id, name, avatar_url), reply_to:reply_to_message_id(*, sender:profiles!sender_id(id, name, avatar_url))')
        .eq('tribe_id', tribeId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<Map<String, dynamic>> insertTribeMessage(
      Map<String, dynamic> messageData) async {
    final response = await _client
        .from('tribe_messages')
        .insert(messageData)
        .select(
            '*, sender:profiles!sender_id(id, name, avatar_url), reply_to:reply_to_message_id(*, sender:profiles!sender_id(id, name, avatar_url))')
        .single();
    return Map<String, dynamic>.from(response);
  }

  @override
  Future<void> softDeleteTribeMessage(String messageId) async {
    final updates = {
      'is_deleted': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _client.from('tribe_messages').update(updates).eq('id', messageId);
  }

  @override
  Future<void> updateTribeMessage(String messageId, String newContent) async {
    final updates = {
      'content': newContent,
      'is_edited': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _client.from('tribe_messages').update(updates).eq('id', messageId);
  }

  // ── Activity Log ──
  @override
  Future<List<Map<String, dynamic>>> getTribeActivityLog(String tribeId) async {
    final response = await _client
        .from('tribe_activity_log')
        .select('*, actor:profiles!actor_id(id, name, avatar_url)')
        .eq('tribe_id', tribeId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<void> insertTribeActivityLog(Map<String, dynamic> logData) async {
    await _client.from('tribe_activity_log').insert(logData);
  }

  // ── Realtime Subscriptions ──
  @override
  RealtimeChannel subscribeToTribeMessages(
      String tribeId, void Function(dynamic payload) callback) {
    final channel =
        _client.channel('public:tribe_messages_$tribeId').onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'tribe_messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'tribe_id',
                value: tribeId,
              ),
              callback: callback,
            );
    channel.subscribe((status, [error]) {
      print(
          "Realtime tribe_messages subscription status: $status, error: $error");
    });
    return channel;
  }

  @override
  RealtimeChannel subscribeToTribeMembers(
      String tribeId, void Function(dynamic payload) callback) {
    final channel =
        _client.channel('public:tribe_members_$tribeId').onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'tribe_members',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'tribe_id',
                value: tribeId,
              ),
              callback: callback,
            );
    channel.subscribe((status, [error]) {
      print(
          "Realtime tribe_members subscription status: $status, error: $error");
    });
    return channel;
  }

  @override
  RealtimeChannel subscribeToTribeActivity(
      String tribeId, void Function(dynamic payload) callback) {
    final channel = _client
        .channel('public:tribe_activity_log_tribe_$tribeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tribe_activity_log',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tribe_id',
            value: tribeId,
          ),
          callback: callback,
        );
    channel.subscribe((status, [error]) {
      print(
          "Realtime tribe activity subscription status for tribe $tribeId: $status, error: $error");
    });
    return channel;
  }

  @override
  RealtimeChannel subscribeToUserMemberships(
      int userId, void Function(dynamic payload) callback) {
    final channel = _client
        .channel('public:tribe_members_user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tribe_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId.toString(),
          ),
          callback: callback,
        );
    channel.subscribe((status, [error]) {
      print(
          "Realtime user memberships subscription status for user $userId: $status, error: $error");
    });
    return channel;
  }

  @override
  void removeChannel(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }

  // ── Moderation ──

  @override
  Future<void> reportTribeMessage({
    required int reporterId,
    required int reportedUserId,
    String? messageId,
    String? messageContent,
    required String reason,
    String? additionalDetails,
  }) async {
    await _client.from('content_reports').insert({
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'message_id': messageId,
      'message_content': messageContent,
      'reason': reason,
      'additional_details': additionalDetails,
    });
  }

  @override
  Future<void> blockUserInTribe({required int blockerId, required int blockedId}) async {
    await _client.from('blocked_users').upsert({
      'blocker_id': blockerId,
      'blocked_id': blockedId,
    });
  }

  @override
  Future<Set<int>> getBlockedUserIds(int userId) async {
    final response = await _client
        .from('blocked_users')
        .select('blocked_id')
        .eq('blocker_id', userId);
    return (response as List)
        .map((row) => row['blocked_id'] as int)
        .toSet();
  }
}
