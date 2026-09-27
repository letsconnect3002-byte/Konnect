import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Models/vouch_model.dart';

abstract class VouchRepository {
  Future<List<UserVouch>> getVouchesForUser(int voucheeId);
  Future<bool> hasUserVouched({required int voucherId, required int voucheeId});
  Future<UserVouch> createVouch({
    required int voucherId,
    required int voucheeId,
    required String statement,
    required String feedScope,
    String? announcementPostId,
  });
  Future<int> getVouchCount(int voucheeId);
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
  Future<UserVouch> createVouch({
    required int voucherId,
    required int voucheeId,
    required String statement,
    required String feedScope,
    String? announcementPostId,
  }) async {
    final Map<String, dynamic> insertData = {
      'voucher_id': voucherId,
      'vouchee_id': voucheeId,
      'statement': statement,
      'feed_scope': feedScope,
      if (announcementPostId != null) 'announcement_post_id': announcementPostId,
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
          .eq('vouchee_id', voucheeId);

      return count;
    } catch (e) {
      debugPrint("Error getting vouch count for user $voucheeId: $e");
      return 0;
    }
  }
}
