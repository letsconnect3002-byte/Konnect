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
  Future<void> sendDirectConnectionRequest({
    required int toUserId,
    required int fromUserId,
    required String sharedCard,
    String? note,
  });
  Future<bool> hasPendingDirectConnectionRequest({
    required int fromUserId,
    required int toUserId,
  });
  Future<List<int>> getSentDirectRequestUserIds(int fromUserId);
  Future<void> sendFeedNotification({
    required int recipientUserId,
    required int actorUserId,
    required String type,
    required String postId,
    required String rootPostId,
    String? parentAuthorName,
    String? replySnippet,
    bool isAnonymous = false,
    String? actorName,
  });
  Future<void> sendBatchFeedNotifications({
    required List<int> recipientUserIds,
    required int actorUserId,
    required String type,
    required String postId,
    required String rootPostId,
    String? parentAuthorName,
    String? replySnippet,
    bool isAnonymous = false,
    String? actorName,
  });
  Future<Set<int>> getRecentNotifiedUserIdsForThread({
    required String rootPostId,
    required List<int> candidateUserIds,
  });
  Future<void> markAsSeen(String notificationId);
  Future<void> updateNotificationNote(String notificationId, String newNote);
  Future<List<Map<String, dynamic>>> getSentReferralRequests(int senderUserId);
  Future<void> markAllAsSeen(int userId);
  Future<void> deleteNotification(String notificationId);
  Future<void> deleteNotificationsBetweenUsers(int idA, int idB);
  Future<void> markTribeNotificationActioned({
    required int recipientUserId,
    required int otherUserId,
    required String tribeId,
    required String newRealType,
  });
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
  Future<void> sendDirectConnectionRequest({
    required int toUserId,
    required int fromUserId,
    required String sharedCard,
    String? note,
  }) async {
    final payload = {
      'card': sharedCard,
      if (note != null && note.trim().isNotEmpty) 'message': note.trim(),
    };
    await _client.from('connection_notifications').insert({
      'user_id': toUserId,
      'other_user_id': fromUserId,
      'type': 'direct_connection_request',
      'note': jsonEncode(payload),
      'is_seen': false,
    });
  }

  @override
  Future<bool> hasPendingDirectConnectionRequest({
    required int fromUserId,
    required int toUserId,
  }) async {
    final response = await _client
        .from('connection_notifications')
        .select('id')
        .eq('user_id', toUserId)
        .eq('other_user_id', fromUserId)
        .eq('type', 'direct_connection_request')
        .limit(1);
    return (response as List).isNotEmpty;
  }

  @override
  Future<List<int>> getSentDirectRequestUserIds(int fromUserId) async {
    try {
      final response = await _client
          .from('connection_notifications')
          .select('user_id')
          .eq('other_user_id', fromUserId)
          .eq('type', 'direct_connection_request');
      final list = response as List;
      return list
          .map((item) => item['user_id'])
          .where((id) => id != null)
          .map((id) => id is int ? id : int.tryParse(id.toString()) ?? 0)
          .where((id) => id > 0)
          .toSet()
          .toList();
    } catch (e) {
      print("Error getting sent direct request user IDs: $e");
      return [];
    }
  }

  @override
  Future<void> sendFeedNotification({
    required int recipientUserId,
    required int actorUserId,
    required String type,
    required String postId,
    required String rootPostId,
    String? parentAuthorName,
    String? replySnippet,
    bool isAnonymous = false,
    String? actorName,
  }) async {
    if (recipientUserId == actorUserId) return;

    final Map<String, dynamic> noteMap = {
      'real_type': type,
      'post_id': postId,
      'root_post_id': rootPostId,
    };
    if (isAnonymous) {
      noteMap['is_anonymous'] = true;
      if (actorName != null && actorName.isNotEmpty) {
        noteMap['actor_name'] = actorName;
      }
    }
    if (parentAuthorName != null && parentAuthorName.isNotEmpty) {
      noteMap['parent_author_name'] = parentAuthorName;
    }
    if (replySnippet != null && replySnippet.isNotEmpty) {
      noteMap['reply_snippet'] = replySnippet;
    }

    final noteJson = jsonEncode(noteMap);

    await _client.from('connection_notifications').insert({
      'user_id': recipientUserId,
      'other_user_id': actorUserId,
      'type': type,
      'note': noteJson,
      'is_seen': false,
    });
  }

  @override
  Future<void> sendBatchFeedNotifications({
    required List<int> recipientUserIds,
    required int actorUserId,
    required String type,
    required String postId,
    required String rootPostId,
    String? parentAuthorName,
    String? replySnippet,
    bool isAnonymous = false,
    String? actorName,
  }) async {
    if (recipientUserIds.isEmpty) return;

    final Map<String, dynamic> noteMap = {
      'real_type': type,
      'post_id': postId,
      'root_post_id': rootPostId,
    };
    if (isAnonymous) {
      noteMap['is_anonymous'] = true;
      if (actorName != null && actorName.isNotEmpty) {
        noteMap['actor_name'] = actorName;
      }
    }
    if (parentAuthorName != null && parentAuthorName.isNotEmpty) {
      noteMap['parent_author_name'] = parentAuthorName;
    }
    if (replySnippet != null && replySnippet.isNotEmpty) {
      noteMap['reply_snippet'] = replySnippet;
    }
    final noteJson = jsonEncode(noteMap);

    final rows = recipientUserIds
        .where((id) => id != actorUserId)
        .map((recipientId) => {
              'user_id': recipientId,
              'other_user_id': actorUserId,
              'type': type,
              'note': noteJson,
              'is_seen': false,
            })
        .toList();

    if (rows.isNotEmpty) {
      await _client.from('connection_notifications').insert(rows);
    }
  }

  @override
  Future<Set<int>> getRecentNotifiedUserIdsForThread({
    required String rootPostId,
    required List<int> candidateUserIds,
  }) async {
    if (candidateUserIds.isEmpty) return {};
    try {
      final since = DateTime.now().subtract(const Duration(hours: 24)).toUtc().toIso8601String();
      final res = await _client
          .from('connection_notifications')
          .select('user_id')
          .inFilter('user_id', candidateUserIds)
          .like('note', '%"root_post_id":"$rootPostId"%')
          .gte('created_at', since);
      final list = res as List;
      return list
          .map((r) => r['user_id'] is int ? r['user_id'] as int : int.tryParse(r['user_id']?.toString() ?? ''))
          .whereType<int>()
          .toSet();
    } catch (_) {
      return {};
    }
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
  Future<void> markTribeNotificationActioned({
    required int recipientUserId,
    required int otherUserId,
    required String tribeId,
    required String newRealType,
  }) async {
    // Find the matching tribe_request/tribe_invite notification
    final rows = await _client
        .from('connection_notifications')
        .select('id, note')
        .eq('user_id', recipientUserId)
        .eq('other_user_id', otherUserId)
        .eq('type', 'referral')
        .order('created_at', ascending: false);

    for (final row in rows) {
      final noteStr = row['note'] as String?;
      if (noteStr == null || !noteStr.startsWith('{')) continue;
      try {
        final parsed = jsonDecode(noteStr) as Map<String, dynamic>;
        if (parsed['tribe_id']?.toString() == tribeId &&
            (parsed['real_type'] == 'tribe_request' ||
             parsed['real_type'] == 'tribe_invite')) {
          // Update real_type to the actioned variant
          parsed['real_type'] = newRealType;
          final updatedNote = jsonEncode(parsed);
          await _client
              .from('connection_notifications')
              .update({'note': updatedNote, 'is_seen': true})
              .eq('id', row['id']);
          break; // Only update the first matching notification
        }
      } catch (_) {}
    }
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
