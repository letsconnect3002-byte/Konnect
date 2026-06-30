import 'package:supabase_flutter/supabase_flutter.dart';

abstract class NetworkRepository {
  Future<Map<String, dynamic>> getNetworkStats(int userId);
  Future<List<Map<String, dynamic>>> getNetworkExpansion(
    int userId,
    int page,
    int limit,
    String search,
    String sort,
  );
}

class SupabaseNetworkRepository implements NetworkRepository {
  final SupabaseClient _client;

  SupabaseNetworkRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<Map<String, dynamic>> getNetworkStats(int userId) async {
    final response = await _client.rpc('get_network_stats', params: {
      'p_user_id': userId,
    });

    if (response == null) {
      return {
        'primary_count': 0,
        'secondary_count': 0,
        'tertiary_count': 0,
      };
    }

    final Map<String, dynamic> data;
    if (response is List && response.isNotEmpty) {
      data = response.first as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      data = response;
    } else {
      return {
        'primary_count': 0,
        'secondary_count': 0,
        'tertiary_count': 0,
      };
    }

    return {
      'primary_count': data['primary_count'] ?? 0,
      'secondary_count': data['secondary_count'] ?? 0,
      'tertiary_count': data['tertiary_count'] ?? 0,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getNetworkExpansion(
    int userId,
    int page,
    int limit,
    String search,
    String sort,
  ) async {
    final response = await _client.rpc('get_network_expansion', params: {
      'p_user_id': userId,
      'p_page': page,
      'p_limit': limit,
      'p_search': search,
      'p_sort': sort,
    });

    if (response == null) {
      return [];
    }

    final List<dynamic> rows = response as List;
    return rows.map((row) {
      final map = row as Map<String, dynamic>;
      return {
        'id': map['id'] ?? 0,
        'name': map['name'] ?? '',
        'profession': map['profession'] ?? '',
        'company': map['company'] ?? '',
        'avatar_url': map['avatar_url'] ?? '',
        'degree': map['degree'] ?? 2,
        'mutual_count': map['mutual_count'] ?? 0,
        'mutual_names': map['mutual_names'] ?? '',
        'mutual_avatars': map['mutual_avatars'] ?? '',
      };
    }).toList();
  }
}
