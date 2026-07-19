import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Models/pulse.dart';

abstract class PulseRepository {
  Future<List<PulseTag>> fetchActivePulseTags();
  Future<UserPulse?> fetchUserPulse(int userId);
  Future<List<UserPulse>> fetchActivePulsesForConnections(int myUserId, List<int> connectionIds);
  Future<UserPulse> publishPulse({
    required int userId,
    required int tagId,
    required String pulseType,
    String? text,
    required String visibility,
    List<int>? hiddenUserIds,
    required int durationHours,
  });
  Future<void> deletePulse(String pulseId);
  Future<PulseUpdate> addPulseUpdate(String pulseId, String text);
  Future<List<PulseUpdate>> fetchPulseUpdates(String pulseId);
}

class SupabasePulseRepository implements PulseRepository {
  final SupabaseClient _client;

  SupabasePulseRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<PulseTag>> fetchActivePulseTags() async {
    final response = await _client
        .from('pulse_tags')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    final List<dynamic> rows = response;
    return rows.map((r) => PulseTag.fromJson(r)).toList();
  }

  @override
  Future<UserPulse?> fetchUserPulse(int userId) async {
    final response = await _client
        .from('user_pulses')
        .select('*, profiles(*), pulse_tags(*)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .maybeSingle();

    if (response == null) return null;
    return UserPulse.fromJson(response);
  }

  @override
  Future<List<UserPulse>> fetchActivePulsesForConnections(
      int myUserId, List<int> connectionIds) async {
    if (connectionIds.isEmpty) return [];

    debugPrint("[PulseRepository] fetchActivePulsesForConnections: myUserId=$myUserId, connectionIds=$connectionIds");

    final response = await _client
        .from('user_pulses')
        .select('*, profiles(*), pulse_tags(*), pulse_hidden_users(hidden_user_id)')
        .inFilter('user_id', connectionIds)
        .eq('status', 'active')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String());

    final List<dynamic> rows = response;
    debugPrint("[PulseRepository] Raw response rows: $rows");

    final pulses = rows.map((row) {
      final pulse = UserPulse.fromJson(row);
      debugPrint("[PulseRepository] Parsed pulse ID=${pulse.id}, userId=${pulse.userId}, hiddenUserIds=${pulse.hiddenUserIds}");
      return pulse;
    }).toList();

    final filtered = pulses.where((pulse) {
      final isExcluded = pulse.hiddenUserIds.contains(myUserId);
      debugPrint("[PulseRepository] Filtering pulse ID=${pulse.id}, isExcluded=$isExcluded (myUserId=$myUserId in ${pulse.hiddenUserIds})");
      return !isExcluded;
    }).toList();

    debugPrint("[PulseRepository] Return filtered list size: ${filtered.length}");
    return filtered;
  }

  @override
  Future<UserPulse> publishPulse({
    required int userId,
    required int tagId,
    required String pulseType,
    String? text,
    required String visibility,
    List<int>? hiddenUserIds,
    required int durationHours,
  }) async {
    final response = await _client.rpc('publish_pulse', params: {
      'p_user_id': userId,
      'p_tag_id': tagId,
      'p_pulse_type': pulseType,
      'p_text': text,
      'p_visibility': visibility,
      'p_duration_hours': durationHours,
      'p_hidden_user_ids': hiddenUserIds ?? [],
    });

    final Map<String, dynamic> row = response as Map<String, dynamic>;
    return UserPulse.fromJson(row);
  }

  @override
  Future<void> deletePulse(String pulseId) async {
    // Delete dependent tables first in case cascading constraint is missing
    await _client.from('pulse_updates').delete().eq('pulse_id', pulseId);
    await _client.from('pulse_hidden_users').delete().eq('pulse_id', pulseId);
    await _client.from('user_pulses').delete().eq('id', pulseId);
  }

  @override
  Future<PulseUpdate> addPulseUpdate(String pulseId, String text) async {
    final response = await _client.from('pulse_updates').insert({
      'pulse_id': pulseId,
      'text': text,
    }).select().single();

    return PulseUpdate.fromJson(response);
  }

  @override
  Future<List<PulseUpdate>> fetchPulseUpdates(String pulseId) async {
    final response = await _client
        .from('pulse_updates')
        .select()
        .eq('pulse_id', pulseId)
        .order('created_at', ascending: false);

    final List<dynamic> rows = response;
    return rows.map((r) => PulseUpdate.fromJson(r)).toList();
  }
}
