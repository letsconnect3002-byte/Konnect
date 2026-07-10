import 'package:supabase_flutter/supabase_flutter.dart';

abstract class PlansRepository {
  Future<List<Map<String, dynamic>>> getMyPlans(int userId);
  Future<Map<String, dynamic>> createPlan(Map<String, dynamic> planData);
  Future<void> updatePlan(String planId, Map<String, dynamic> data);
  Future<void> deletePlan(String planId);
  Future<Map<String, dynamic>?> getPlanById(String planId);
  Future<List<Map<String, dynamic>>> getInvitesForPlan(String planId);
  Future<void> inviteUser({
    required String planId,
    required int inviterId,
    required int inviteeId,
  });
  Future<void> respondToInvite({
    required String inviteId,
    required String status,
    String? declineReason,
  });
  Future<void> logEdit({
    required String planId,
    required int editedBy,
    required Map<String, dynamic> changedFields,
  });
  Future<List<Map<String, dynamic>>> getEditsForPlan(String planId);
  RealtimeChannel subscribeToPlanInvites(
      int userId, void Function(dynamic payload) callback);
  RealtimeChannel subscribeToPlans(
      int userId, void Function(dynamic payload) callback);
  void removeChannel(RealtimeChannel channel);
}

class SupabasePlansRepository implements PlansRepository {
  final SupabaseClient _client;

  SupabasePlansRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> getMyPlans(int userId) async {
    // Get plans where user is the creator
    final createdPlans = await _client
        .from('plans')
        .select('*, creator:profiles!creator_id(id, name, avatar_url)')
        .eq('creator_id', userId)
        .order('starts_at', ascending: true);

    // Get plans where user is invited (accepted or pending)
    final invitedPlans = await _client
        .from('plan_invites')
        .select(
            'plan_id, status, plan:plans!plan_id(*, creator:profiles!creator_id(id, name, avatar_url))')
        .eq('invitee_id', userId)
        .inFilter('status', ['pending', 'accepted'])
        .order('created_at', ascending: false);

    // Merge and deduplicate
    final Map<String, Map<String, dynamic>> planMap = {};

    for (final row in createdPlans) {
      final id = row['id'] as String;
      planMap[id] = Map<String, dynamic>.from(row);
      planMap[id]!['my_status'] = 'creator';
    }

    for (final row in invitedPlans) {
      final plan = row['plan'];
      if (plan == null) continue;
      final id = plan['id'] as String;
      if (!planMap.containsKey(id)) {
        planMap[id] = Map<String, dynamic>.from(plan);
      }
      planMap[id]!['my_status'] = row['status'];
    }

    final plans = planMap.values.toList();
    plans.sort((a, b) {
      final aTime = DateTime.tryParse(a['starts_at'] ?? '') ?? DateTime(2099);
      final bTime = DateTime.tryParse(b['starts_at'] ?? '') ?? DateTime(2099);
      return aTime.compareTo(bTime);
    });

    return plans;
  }

  @override
  Future<Map<String, dynamic>> createPlan(Map<String, dynamic> planData) async {
    final response =
        await _client.from('plans').insert(planData).select().single();
    return Map<String, dynamic>.from(response);
  }

  @override
  Future<void> updatePlan(String planId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _client.from('plans').update(data).eq('id', planId);
  }

  @override
  Future<void> deletePlan(String planId) async {
    await _client.from('plans').delete().eq('id', planId);
  }

  @override
  Future<Map<String, dynamic>?> getPlanById(String planId) async {
    final response = await _client
        .from('plans')
        .select('*, creator:profiles!creator_id(id, name, avatar_url)')
        .eq('id', planId)
        .maybeSingle();
    return response != null ? Map<String, dynamic>.from(response) : null;
  }

  @override
  Future<List<Map<String, dynamic>>> getInvitesForPlan(String planId) async {
    final response = await _client
        .from('plan_invites')
        .select(
            '*, invitee:profiles!invitee_id(id, name, avatar_url), inviter:profiles!inviter_id(id, name, avatar_url)')
        .eq('plan_id', planId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(
        response.map((r) => Map<String, dynamic>.from(r)));
  }

  @override
  Future<void> inviteUser({
    required String planId,
    required int inviterId,
    required int inviteeId,
  }) async {
    await _client.from('plan_invites').upsert({
      'plan_id': planId,
      'inviter_id': inviterId,
      'invitee_id': inviteeId,
      'status': 'pending',
    });
  }

  @override
  Future<void> respondToInvite({
    required String inviteId,
    required String status,
    String? declineReason,
  }) async {
    final data = <String, dynamic>{
      'status': status,
      'responded_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (declineReason != null && declineReason.isNotEmpty) {
      data['decline_reason'] = declineReason;
    }
    await _client.from('plan_invites').update(data).eq('id', inviteId);
  }

  @override
  Future<void> logEdit({
    required String planId,
    required int editedBy,
    required Map<String, dynamic> changedFields,
  }) async {
    await _client.from('plan_edits').insert({
      'plan_id': planId,
      'edited_by': editedBy,
      'changed_fields': changedFields,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getEditsForPlan(String planId) async {
    final response = await _client
        .from('plan_edits')
        .select('*, editor:profiles!edited_by(id, name, avatar_url)')
        .eq('plan_id', planId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(
        response.map((r) => Map<String, dynamic>.from(r)));
  }

  @override
  RealtimeChannel subscribeToPlanInvites(
      int userId, void Function(dynamic payload) callback) {
    final channel = _client
        .channel('public:plan_invites_user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'plan_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'invitee_id',
            value: userId.toString(),
          ),
          callback: callback,
        );
    channel.subscribe((status, [error]) {
      print(
          "Realtime plan_invites subscription status for user $userId: $status, error: $error");
    });
    return channel;
  }

  @override
  RealtimeChannel subscribeToPlans(
      int userId, void Function(dynamic payload) callback) {
    final channel = _client
        .channel('public:plans_user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'plans',
          callback: callback,
        );
    channel.subscribe((status, [error]) {
      print(
          "Realtime plans subscription status for user $userId: $status, error: $error");
    });
    return channel;
  }

  @override
  void removeChannel(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}
