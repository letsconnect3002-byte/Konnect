import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class NotificationRepository {
  Future<List<Map<String, dynamic>>> getNotifications(int userId);
  Future<void> insertNotification({
    required int userId,
    required int otherUserId,
    required String type,
    String? note,
  });
  Future<void> insertReferralNotification({
    required int userId,
    required int otherUserId,
    required int referredUserId,
    String? note,
  });
  Future<void> markAsSeen(String notificationId);
  Future<void> updateNotificationNote(String notificationId, String newNote);
  Future<List<Map<String, dynamic>>> getSentReferralRequests(int senderUserId);
  Future<void> markAllAsSeen(int userId);
  Future<void> deleteNotification(String notificationId);
  Future<void> deleteNotificationsBetweenUsers(int idA, int idB);
  RealtimeChannel subscribeToNotifications(
      int userId, void Function(dynamic payload) callback);
  void removeChannel(RealtimeChannel channel);
}

class SupabaseNotificationRepository implements NotificationRepository {
  final SupabaseClient _client;

  SupabaseNotificationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    final response = await _client
        .from('connection_notifications')
        .select(
            '*, other_user:profiles!other_user_id(*), referred_user:profiles!referred_user_id(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final List<dynamic> rows = response as List;
    final List<Map<String, dynamic>> list =
        rows.map((row) => Map<String, dynamic>.from(row)).toList();

    // Parse JSON notes if they exist
    for (var n in list) {
      final noteStr = n['note'] as String?;
      if (noteStr != null && noteStr.startsWith('{')) {
        try {
          final parsed = jsonDecode(noteStr);
          n['parsed_plan_id'] = parsed['plan_id']?.toString();
          if (parsed['changed_fields'] is List) {
            n['changed_fields'] = List<String>.from(parsed['changed_fields']);
          }
          if (parsed['real_type'] != null) {
            n['type'] = parsed['real_type'].toString();
          }
        } catch (e) {
          print("Error parsing notification note JSON: $e");
        }
      }
    }

    // Batch load associated plans for plan_invite, plan_update, and reminders
    final planIds = list
        .where((n) =>
            (n['type'] == 'plan_invite' ||
                n['type'] == 'plan_update' ||
                n['type'] == 'plan_reminder_30' ||
                n['type'] == 'plan_reminder_start') &&
            (n['parsed_plan_id'] != null || n['note'] != null))
        .map((n) => (n['parsed_plan_id'] ?? n['note']) as String)
        .toSet()
        .toList();

    if (planIds.isNotEmpty) {
      try {
        // 1. Batch load plans
        final plansResponse = await _client
            .from('plans')
            .select('*, creator:profiles!creator_id(id, name, avatar_url)')
            .inFilter('id', planIds);

        final plansList = plansResponse as List;
        final plansMap = {
          for (var p in plansList) p['id'] as String: Map<String, dynamic>.from(p)
        };

        // 2. Batch load invite statuses
        final invitesResponse = await _client
            .from('plan_invites')
            .select('plan_id, status')
            .eq('invitee_id', userId)
            .inFilter('plan_id', planIds);

        final invitesList = invitesResponse as List;
        final invitesMap = {
          for (var i in invitesList) i['plan_id'] as String: i['status'] as String
        };

        for (var n in list) {
          if (n['type'] == 'plan_invite' ||
              n['type'] == 'plan_update' ||
              n['type'] == 'plan_reminder_30' ||
              n['type'] == 'plan_reminder_start') {
            n['plan_loaded'] = true;
            final pid = (n['parsed_plan_id'] ?? n['note']) as String?;
            if (pid != null) {
              if (plansMap.containsKey(pid)) {
                n['plan'] = plansMap[pid];
              }
              if (invitesMap.containsKey(pid)) {
                n['invite_status'] = invitesMap[pid];
              }
            }
          }
        }
      } catch (e) {
        print("Error batch fetching plans/invites for notifications: $e");
      }
    }

    return list;
  }

  @override
  Future<void> insertNotification({
    required int userId,
    required int otherUserId,
    required String type,
    String? note,
  }) async {
    await _client.from('connection_notifications').insert({
      'user_id': userId,
      'other_user_id': otherUserId,
      'type': type,
      'note': note,
      'is_seen': false,
    });
  }

  @override
  Future<void> insertReferralNotification({
    required int userId,
    required int otherUserId,
    required int referredUserId,
    String? note,
  }) async {
    await _client.from('connection_notifications').insert({
      'user_id': userId,
      'other_user_id': otherUserId,
      'referred_user_id': referredUserId,
      'type': 'referral',
      'note': note,
      'is_seen': false,
    });
  }

  @override
  Future<void> markAsSeen(String notificationId) async {
    await _client
        .from('connection_notifications')
        .update({'is_seen': true}).eq('id', notificationId);
  }

  @override
  Future<void> updateNotificationNote(String notificationId, String newNote) async {
    await _client
        .from('connection_notifications')
        .update({'note': newNote, 'is_seen': true}).eq('id', notificationId);
  }

  @override
  Future<List<Map<String, dynamic>>> getSentReferralRequests(int senderUserId) async {
    final response = await _client
        .from('connection_notifications')
        .select('id, user_id, referred_user_id, note, is_seen')
        .eq('other_user_id', senderUserId)
        .eq('type', 'referral');
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<void> markAllAsSeen(int userId) async {
    await _client
        .from('connection_notifications')
        .update({'is_seen': true})
        .eq('user_id', userId)
        .eq('is_seen', false);
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    await _client
        .from('connection_notifications')
        .delete()
        .eq('id', notificationId);
  }

  @override
  Future<void> deleteNotificationsBetweenUsers(int idA, int idB) async {
    // Delete normal connection notifications
    await _client
        .from('connection_notifications')
        .delete()
        .eq('user_id', idA)
        .eq('other_user_id', idB);
    await _client
        .from('connection_notifications')
        .delete()
        .eq('user_id', idB)
        .eq('other_user_id', idA);

    // Delete referral notifications where one is requester and other is target
    await _client
        .from('connection_notifications')
        .delete()
        .eq('other_user_id', idA)
        .eq('referred_user_id', idB);
    await _client
        .from('connection_notifications')
        .delete()
        .eq('other_user_id', idB)
        .eq('referred_user_id', idA);

    // Delete referral notifications where one is connector and other is target
    await _client
        .from('connection_notifications')
        .delete()
        .eq('user_id', idA)
        .eq('referred_user_id', idB);
    await _client
        .from('connection_notifications')
        .delete()
        .eq('user_id', idB)
        .eq('referred_user_id', idA);
  }

  @override
  RealtimeChannel subscribeToNotifications(
      int userId, void Function(dynamic payload) callback) {
    final channel = _client
        .channel('public:connection_notifications_user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'connection_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId.toString(),
          ),
          callback: callback,
        );
    channel.subscribe((status, [error]) {
      print(
          "Realtime notifications subscription status for user $userId: $status, error: $error");
    });
    return channel;
  }

  @override
  void removeChannel(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}
