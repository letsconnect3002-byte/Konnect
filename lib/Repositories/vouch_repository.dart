import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Models/vouch_model.dart';

abstract class VouchRepository {
  Future<List<UserVouch>> getVouchesForUser(int voucheeId);
  Future<bool> hasUserVouched({required int voucherId, required int voucheeId});
  Future<String?> getVouchStatusBetween({required int voucherId, required int voucheeId});
  Future<UserVouch> createVouch({
    required int voucherId,
    required int voucheeId,
    required String statement,
    required String feedScope,
    String? announcementPostId,
    String? relationshipType,
    List<String>? privateIntents,
    String? optionalNote,
  });
  Future<void> updateVouchStatus({required String vouchId, required String status});
  Future<int> getVouchCount(int voucheeId);
  Future<List<String>> getMutualIntents({required int userId1, required int userId2});
  Future<List<String>> deleteVouchesBetween({required int userId1, required int userId2});
}

class SupabaseVouchRepository implements VouchRepository {
  final SupabaseClient _client;

  SupabaseVouchRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<UserVouch>> getVouchesForUser(int voucheeId) async {
    try {
      final response = await _client
          .from('user_vouches')
          .select('*, profiles!voucher_id(name, avatar_url, profession, company)')
          .eq('vouchee_id', voucheeId)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);

      final List rows = response as List;
      return rows.map((json) => UserVouch.fromJson(Map<String, dynamic>.from(json))).toList();
    } catch (e) {
      debugPrint("Error fetching vouches for user $voucheeId: $e");
      return [];
    }
  }

  @override
  Future<bool> hasUserVouched({required int voucherId, required int voucheeId}) async {
    try {
      final response = await _client
          .from('user_vouches')
          .select('id')
          .eq('voucher_id', voucherId)
          .eq('vouchee_id', voucheeId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint("Error checking if user $voucherId vouched for $voucheeId: $e");
      return false;
    }
  }

  @override
  Future<String?> getVouchStatusBetween({required int voucherId, required int voucheeId}) async {
    try {
      final response = await _client
          .from('user_vouches')
          .select('status')
          .eq('voucher_id', voucherId)
          .eq('vouchee_id', voucheeId)
          .maybeSingle();

      if (response != null && response['status'] != null) {
        return response['status'].toString();
      }
      return null;
    } catch (e) {
      debugPrint("Error getting vouch status between $voucherId and $voucheeId: $e");
      return null;
    }
  }

  @override
  Future<void> updateVouchStatus({required String vouchId, required String status}) async {
    await _client
        .from('user_vouches')
        .update({'status': status})
        .eq('id', vouchId);
  }

  @override
  Future<UserVouch> createVouch({
    required int voucherId,
    required int voucheeId,
    required String statement,
    required String feedScope,
    String? announcementPostId,
    String? relationshipType,
    List<String>? privateIntents,
    String? optionalNote,
  }) async {
    final Map<String, dynamic> insertData = {
      'voucher_id': voucherId,
      'vouchee_id': voucheeId,
      'statement': statement,
      'feed_scope': feedScope,
      if (announcementPostId != null) 'announcement_post_id': announcementPostId,
      if (relationshipType != null) 'relationship_type': relationshipType,
      if (privateIntents != null && privateIntents.isNotEmpty) 'private_intents': privateIntents,
      if (optionalNote != null) 'optional_note': optionalNote,
    };

    final response = await _client
        .from('user_vouches')
        .insert(insertData)
        .select('*, profiles!voucher_id(name, avatar_url, profession, company)')
        .single();

    return UserVouch.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<int> getVouchCount(int voucheeId) async {
    try {
      final count = await _client
          .from('user_vouches')
          .count(CountOption.exact)
          .eq('vouchee_id', voucheeId)
          .eq('status', 'accepted');

      return count;
    } catch (e) {
      debugPrint("Error getting vouch count for user $voucheeId: $e");
      return 0;
    }
  }

  @override
  Future<List<String>> getMutualIntents({required int userId1, required int userId2}) async {
    try {
      final response = await _client.rpc('get_mutual_intents', params: {
        'p_user_a': userId1,
        'p_user_b': userId2,
      });
      if (response is List) {
        return response.map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching mutual intents: $e");
      return [];
    }
  }

  @override
  Future<List<String>> deleteVouchesBetween({required int userId1, required int userId2}) async {
    final Set<String> postIdsToDelete = {};
    try {
      // 1. Find all announcement posts explicitly recorded in user_vouches
      final rows = await _client
          .from('user_vouches')
          .select('id, announcement_post_id')
          .or('and(voucher_id.eq.$userId1,vouchee_id.eq.$userId2),and(voucher_id.eq.$userId2,vouchee_id.eq.$userId1)');

      for (final r in rows) {
        final pid = r['announcement_post_id']?.toString();
        if (pid != null && pid.isNotEmpty) {
          postIdsToDelete.add(pid);
        }
      }

      // 2. Also search posts authored by either user containing vouch statements for the other
      try {
        final profiles = await _client
            .from('profiles')
            .select('id, name, handle')
            .inFilter('id', [userId1, userId2]);

        String? name1, handle1, name2, handle2;
        for (final p in profiles) {
          final pId = p['id'];
          if (pId == userId1) {
            name1 = p['name']?.toString().trim();
            handle1 = p['handle']?.toString().trim();
          } else if (pId == userId2) {
            name2 = p['name']?.toString().trim();
            handle2 = p['handle']?.toString().trim();
          }
        }

        final recentVouchPosts = await _client
            .from('posts')
            .select('id, author_id, content')
            .inFilter('author_id', [userId1, userId2])
            .ilike('content', '%Vouched for @%');

        for (final p in recentVouchPosts) {
          final content = p['content']?.toString() ?? '';
          final authorId = p['author_id'];
          final pid = p['id']?.toString();
          if (pid == null || pid.isEmpty) continue;

          if (authorId == userId1) {
            if ((name2 != null && name2.isNotEmpty && content.contains(name2)) ||
                (handle2 != null && handle2.isNotEmpty && content.contains(handle2))) {
              postIdsToDelete.add(pid);
            }
          }
          if (authorId == userId2) {
            if ((name1 != null && name1.isNotEmpty && content.contains(name1)) ||
                (handle1 != null && handle1.isNotEmpty && content.contains(handle1))) {
              postIdsToDelete.add(pid);
            }
          }
        }
      } catch (e) {
        debugPrint("Error checking content-matched vouch announcement posts: $e");
      }

      // 3. To avoid FK constraint failure (user_vouches_announcement_post_id_fkey), null out foreign key first
      try {
        await _client
            .from('user_vouches')
            .update({'announcement_post_id': null})
            .or('and(voucher_id.eq.$userId1,vouchee_id.eq.$userId2),and(voucher_id.eq.$userId2,vouchee_id.eq.$userId1)');
      } catch (e) {
        debugPrint("Error nulling announcement_post_id in user_vouches: $e");
      }

      // 4. Delete mutual vouches from user_vouches
      try {
        await _client
            .from('user_vouches')
            .delete()
            .or('and(voucher_id.eq.$userId1,vouchee_id.eq.$userId2),and(voucher_id.eq.$userId2,vouchee_id.eq.$userId1)');
        debugPrint("Successfully deleted user_vouches between $userId1 and $userId2");
      } catch (e) {
        debugPrint("Error deleting user_vouches between $userId1 and $userId2: $e");
      }

      // 5. Delete or soft-delete the announcement posts
      if (postIdsToDelete.isNotEmpty) {
        final idsList = postIdsToDelete.toList();
        // A. Soft-delete first: sets is_deleted = true immediately hiding it from all feeds
        try {
          await _client
              .from('posts')
              .update({'is_deleted': true})
              .inFilter('id', idsList);
        } catch (e) {
          debugPrint("Error soft-deleting vouch posts: $e");
        }

        // B. Soft-delete any replies to the announcement posts
        try {
          await _client
              .from('posts')
              .update({'is_deleted': true})
              .inFilter('reply_to_post_id', idsList);
        } catch (e) {
          debugPrint("Error soft-deleting vouch post replies: $e");
        }
      }

      debugPrint("Successfully deleted vouches and posts between $userId1 and $userId2");
      return postIdsToDelete.toList();
    } catch (e) {
      debugPrint("Error deleting vouches between $userId1 and $userId2: $e");
      return postIdsToDelete.toList();
    }
  }
}
