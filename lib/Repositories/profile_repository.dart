import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ProfileRepository {
  Future<List<Map<String, dynamic>>> checkMyProfileExists(String ownerId);
  Future<int> createDefaultProfile(
    String ownerId,
    String email,
    String name,
    String profession,
    String gender,
    Map<String, dynamic> fieldAssignments,
  );
  Future<List<Map<String, dynamic>>> fetchProfileIdsByOwner(String ownerId, bool isMyProfile);
  Future<List<Map<String, dynamic>>> fetchProfileIdsByEmail(String email);
  Future<Map<String, dynamic>?> loadProfile(int id);
  Future<int> insertProfile(Map<String, dynamic> data);
  Future<void> updateProfile(int id, Map<String, dynamic> data);
  Future<void> updateProfileField(int id, String dbField, dynamic value);
  Future<Map<String, dynamic>?> fetchProfileDataOnly(int id);
  Future<Map<String, dynamic>> fetchConnectionDetails(int myUserId, int idToFetch);
  Future<void> insertInviteCode(String code, int senderId, String sharedCardType);
}

class SupabaseProfileRepository implements ProfileRepository {
  final SupabaseClient _client;

  SupabaseProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> checkMyProfileExists(String ownerId) async {
    final response = await _client
        .from('profiles')
        .select('id')
        .eq('owner_id', ownerId)
        .eq('is_my_profile', true);
    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<int> createDefaultProfile(
    String ownerId,
    String email,
    String name,
    String profession,
    String gender,
    Map<String, dynamic> fieldAssignments,
  ) async {
    final response = await _client.from('profiles').insert({
      'owner_id': ownerId,
      'name': name,
      'profession': profession,
      'email': email,
      'gender': gender,
      'is_my_profile': true,
      'field_assignments': fieldAssignments,
      'show_profile_to_connections': true,
    }).select('id').single();
    return response['id'] as int;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchProfileIdsByOwner(String ownerId, bool isMyProfile) async {
    final response = await _client
        .from('profiles')
        .select('id')
        .eq('owner_id', ownerId)
        .eq('is_my_profile', isMyProfile);
    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchProfileIdsByEmail(String email) async {
    final response = await _client
        .from('profiles')
        .select('id')
        .eq('email', email);
    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<Map<String, dynamic>?> loadProfile(int id) async {
    return await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
  }

  @override
  Future<int> insertProfile(Map<String, dynamic> data) async {
    final response = await _client
        .from('profiles')
        .insert(data)
        .select('id')
        .single();
    return response['id'] as int;
  }

  @override
  Future<void> updateProfile(int id, Map<String, dynamic> data) async {
    await _client.from('profiles').update(data).eq('id', id);
  }

  @override
  Future<void> updateProfileField(int id, String dbField, dynamic value) async {
    await _client.from('profiles').update({
      dbField: value,
    }).eq('id', id);
  }

  @override
  Future<Map<String, dynamic>?> fetchProfileDataOnly(int id) async {
    return await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
  }

  @override
  Future<Map<String, dynamic>> fetchConnectionDetails(int myUserId, int idToFetch) async {
    final Map<String, dynamic> result = {
      'profile': null,
      'sharedCardPermission': 'both',
      'mySharedCardToThem': 'both',
    };

    final profileResponse = await _client
        .from('profiles')
        .select()
        .eq('id', idToFetch)
        .maybeSingle();

    result['profile'] = profileResponse;

    // Fetch sharedCardPermission from network_graph
    final connResponse = await _client
        .from('network_graph')
        .select('shared_card')
        .eq('primary_user_id', myUserId)
        .eq('connected_user_id', idToFetch)
        .maybeSingle();
    if (connResponse != null) {
      result['sharedCardPermission'] = connResponse['shared_card'] ?? 'both';
    }

    // Fetch mySharedCardToThem from user_connections
    final int id1 = myUserId < idToFetch ? myUserId : idToFetch;
    final int id2 = myUserId > idToFetch ? myUserId : idToFetch;
    final rawConn = await _client
        .from('user_connections')
        .select()
        .eq('user_id_1', id1)
        .eq('user_id_2', id2)
        .maybeSingle();
    if (rawConn != null) {
      if (myUserId < idToFetch) {
        result['mySharedCardToThem'] = rawConn['user_1_shared_card'] ?? 'both';
      } else {
        result['mySharedCardToThem'] = rawConn['user_2_shared_card'] ?? 'both';
      }
    }

    return result;
  }

  @override
  Future<void> insertInviteCode(String code, int senderId, String sharedCardType) async {
    await _client.from('invite_codes').insert({
      'code': code,
      'sender_id': senderId,
      'shared_card_type': sharedCardType,
      'is_used': false,
    });
  }
}
