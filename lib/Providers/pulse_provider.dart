import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Models/pulse.dart';
import 'package:connect/Repositories/pulse_repository.dart';

class PulseProvider with ChangeNotifier {
  final PulseRepository _pulseRepository;

  PulseProvider({PulseRepository? pulseRepository})
      : _pulseRepository = pulseRepository ?? SupabasePulseRepository();

  int? _myUserId;
  int? get myUserId => _myUserId;

  List<int> _connectionIds = [];
  List<int> get connectionIds => _connectionIds;

  List<PulseTag> _tags = [];
  List<PulseTag> get tags => _tags;

  UserPulse? _myPulse;
  UserPulse? get myPulse => _myPulse;

  List<UserPulse> _connectionPulses = [];
  List<Map<String, dynamic>> _connections = [];

  List<UserPulse> get connectionPulses {
    return _connectionPulses.where((pulse) {
      final conn = _connections.firstWhere(
        (c) => c['id'] == pulse.userId,
        orElse: () => <String, dynamic>{},
      );
      if (conn.isEmpty) return false;

      final sharedCard = (conn['shared_card'] ?? 'both').toString().toLowerCase();
      final visibility = pulse.visibility.toLowerCase();

      if (visibility == 'both') return true;
      if (visibility == 'casual') {
        return sharedCard == 'casual' || sharedCard == 'both';
      }
      if (visibility == 'professional') {
        return sharedCard == 'professional' || sharedCard == 'both';
      }
      return false;
    }).toList();
  }

  bool _isLoadingTags = false;
  bool get isLoadingTags => _isLoadingTags;

  bool _isLoadingFeed = false;
  bool get isLoadingFeed => _isLoadingFeed;

  bool _isPublishing = false;
  bool get isPublishing => _isPublishing;

  final Map<String, List<PulseUpdate>> _cachedUpdates = {};
  Map<String, List<PulseUpdate>> get cachedUpdates => _cachedUpdates;

  RealtimeChannel? _pulsesSubscription;
  RealtimeChannel? _updatesSubscription;

  void updateFromProviders(int? myUserId, List<Map<String, dynamic>> connections) {
    _connections = connections;
    final newConnectionIds = connections.map((c) => c['id'] as int).toList();
    bool shouldReload = false;

    if (_myUserId != myUserId) {
      _myUserId = myUserId;
      shouldReload = true;
      if (_myUserId != null) {
        _subscribeToRealtime();
      } else {
        _unsubscribeFromRealtime();
        _myPulse = null;
        _connectionPulses = [];
      }
    }

    if (!_compareLists(_connectionIds, newConnectionIds)) {
      _connectionIds = newConnectionIds;
      shouldReload = true;
    }

    if (shouldReload && _myUserId != null) {
      loadTags();
      loadMyPulse();
      loadFeed();
    }
  }

  bool _compareLists(List<int> l1, List<int> l2) {
    if (l1.length != l2.length) return false;
    for (int i = 0; i < l1.length; i++) {
      if (l1[i] != l2[i]) return false;
    }
    return true;
  }

  void _subscribeToRealtime() {
    _unsubscribeFromRealtime();
    final client = Supabase.instance.client;

    _pulsesSubscription = client.channel('public:user_pulses_channel')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_pulses',
        callback: (payload) async {
          debugPrint("[PulseProvider] Realtime user_pulses change: ${payload.eventType}");
          // 500ms delay ensures pulse_hidden_users writes complete before we fetch feed
          await Future.delayed(const Duration(milliseconds: 500));
          _refreshFeedAndMyPulseSilent();
        },
      )
      ..subscribe();

    _updatesSubscription = client.channel('public:pulse_updates_channel')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'pulse_updates',
        callback: (payload) {
          debugPrint("[PulseProvider] Realtime pulse_updates change: ${payload.eventType}");
          final record = payload.newRecord;
          if (record.containsKey('pulse_id') && record['pulse_id'] != null) {
            final pulseId = record['pulse_id'] as String;
            _refreshUpdatesSilent(pulseId);
          }
        },
      )
      ..subscribe();
  }

  void _unsubscribeFromRealtime() {
    if (_pulsesSubscription != null) {
      Supabase.instance.client.removeChannel(_pulsesSubscription!);
      _pulsesSubscription = null;
    }
    if (_updatesSubscription != null) {
      Supabase.instance.client.removeChannel(_updatesSubscription!);
      _updatesSubscription = null;
    }
  }

  Future<void> loadTags() async {
    if (_tags.isNotEmpty) return; // Cache tags
    _isLoadingTags = true;
    notifyListeners();

    try {
      _tags = await _pulseRepository.fetchActivePulseTags();
    } catch (e) {
      debugPrint("[PulseProvider] Error fetching active tags: $e");
    } finally {
      _isLoadingTags = false;
      notifyListeners();
    }
  }

  Future<void> loadMyPulse() async {
    final userId = _myUserId;
    if (userId == null) return;

    try {
      _myPulse = await _pulseRepository.fetchUserPulse(userId);
      notifyListeners();
    } catch (e) {
      debugPrint("[PulseProvider] Error fetching my pulse: $e");
    }
  }

  Future<void> loadFeed() async {
    final userId = _myUserId;
    if (userId == null) return;

    _isLoadingFeed = true;
    notifyListeners();

    try {
      _connectionPulses = await _pulseRepository.fetchActivePulsesForConnections(userId, _connectionIds);
    } catch (e) {
      debugPrint("[PulseProvider] Error fetching connections pulse feed: $e");
    } finally {
      _isLoadingFeed = false;
      notifyListeners();
    }
  }

  Future<void> _refreshFeedAndMyPulseSilent() async {
    final userId = _myUserId;
    if (userId == null) return;
    try {
      final myPulseFuture = _pulseRepository.fetchUserPulse(userId);
      final feedFuture = _pulseRepository.fetchActivePulsesForConnections(userId, _connectionIds);
      final results = await Future.wait([myPulseFuture, feedFuture]);
      _myPulse = results[0] as UserPulse?;
      _connectionPulses = results[1] as List<UserPulse>;
      notifyListeners();
    } catch (e) {
      debugPrint("[PulseProvider] Silent pulse refresh error: $e");
    }
  }

  Future<void> _refreshUpdatesSilent(String pulseId) async {
    try {
      final updates = await _pulseRepository.fetchPulseUpdates(pulseId);
      _cachedUpdates[pulseId] = updates;
      notifyListeners();
    } catch (e) {
      debugPrint("[PulseProvider] Silent updates refresh error: $e");
    }
  }

  Future<void> publishPulse({
    required int tagId,
    required String pulseType,
    String? text,
    required String visibility,
    List<int>? hiddenUserIds,
    required int durationHours,
  }) async {
    final userId = _myUserId;
    if (userId == null) return;

    _isPublishing = true;
    notifyListeners();

    // Optimistic UI update
    final selectedTag = _tags.firstWhere((t) => t.id == tagId);
    final optimisticPulse = UserPulse(
      id: 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      pulseTagId: tagId,
      pulseType: pulseType,
      text: text,
      visibility: visibility,
      status: 'active',
      expiresAt: DateTime.now().add(Duration(hours: durationHours)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      userName: 'You',
      tag: selectedTag,
    );

    final previousPulse = _myPulse;
    _myPulse = optimisticPulse;
    notifyListeners();

    try {
      final actualPulse = await _pulseRepository.publishPulse(
        userId: userId,
        tagId: tagId,
        pulseType: pulseType,
        text: text,
        visibility: visibility,
        hiddenUserIds: hiddenUserIds,
        durationHours: durationHours,
      );
      _myPulse = actualPulse;
    } catch (e) {
      _myPulse = previousPulse;
      rethrow;
    } finally {
      _isPublishing = false;
      notifyListeners();
    }
  }

  Future<void> deletePulse(String pulseId) async {
    final previousPulse = _myPulse;
    _myPulse = null;
    notifyListeners();

    try {
      await _pulseRepository.deletePulse(pulseId);
    } catch (e) {
      _myPulse = previousPulse;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadUpdates(String pulseId) async {
    // Check if we already have cache to avoid double loading unless requested
    if (_cachedUpdates.containsKey(pulseId)) return;
    try {
      final updates = await _pulseRepository.fetchPulseUpdates(pulseId);
      _cachedUpdates[pulseId] = updates;
      notifyListeners();
    } catch (e) {
      debugPrint("[PulseProvider] Error fetching updates: $e");
    }
  }

  Future<void> addPulseUpdate(String pulseId, String text) async {
    // Optimistic Update
    final tempUpdate = PulseUpdate(
      id: 'temp_update_${DateTime.now().millisecondsSinceEpoch}',
      pulseId: pulseId,
      text: text,
      createdAt: DateTime.now(),
    );
    final list = _cachedUpdates[pulseId] ?? [];
    _cachedUpdates[pulseId] = [tempUpdate, ...list];
    notifyListeners();

    try {
      final actualUpdate = await _pulseRepository.addPulseUpdate(pulseId, text);
      // Replace optimistic update
      final currentList = _cachedUpdates[pulseId] ?? [];
      final idx = currentList.indexWhere((u) => u.id == tempUpdate.id);
      if (idx != -1) {
        currentList[idx] = actualUpdate;
        _cachedUpdates[pulseId] = List.from(currentList);
      }
      notifyListeners();
    } catch (e) {
      // Revert optimistic update
      final currentList = _cachedUpdates[pulseId] ?? [];
      currentList.removeWhere((u) => u.id == tempUpdate.id);
      _cachedUpdates[pulseId] = List.from(currentList);
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _unsubscribeFromRealtime();
    super.dispose();
  }
}
