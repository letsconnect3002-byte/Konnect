import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Models/custom_network.dart';
import 'package:connect/Repositories/custom_network_repository.dart';

class CustomNetworkProvider with ChangeNotifier {
  final CustomNetworkRepository _repository;

  CustomNetworkProvider({CustomNetworkRepository? repository})
      : _repository = repository ?? SupabaseCustomNetworkRepository();

  int? _userId;
  int? get userId => _userId;

  List<CustomNetwork> _myNetworks = [];
  List<CustomNetwork> get myNetworks => _myNetworks;

  CustomNetwork? _activeCustomNetwork;
  CustomNetwork? get activeCustomNetwork => _activeCustomNetwork;

  List<CustomNetworkMember> _activeNetworkMembers = [];
  List<CustomNetworkMember> get activeNetworkMembers => _activeNetworkMembers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMembers = false;
  bool get isLoadingMembers => _isLoadingMembers;

  RealtimeChannel? _realtimeChannel;

  final StreamController<CustomNetwork> _onMembershipLostController =
      StreamController<CustomNetwork>.broadcast();
  Stream<CustomNetwork> get onMembershipLost =>
      _onMembershipLostController.stream;

  void updateUserId(int? newUserId) {
    if (_userId == newUserId) return;
    _userId = newUserId;
    if (_userId != null) {
      fetchMyNetworks();
      _setupRealtimeSubscription();
    } else {
      _myNetworks = [];
      _activeCustomNetwork = null;
      _activeNetworkMembers = [];
      _cleanupSubscription();
      notifyListeners();
    }
  }

  void _setupRealtimeSubscription() {
    _cleanupSubscription();
    if (_userId == null) return;
    _realtimeChannel = _repository.subscribeToNetworks(
      userId: _userId!,
      onNetworkChanged: () {
        fetchMyNetworks();
        if (_activeCustomNetwork != null) {
          loadActiveNetworkMembers();
        }
      },
    );
  }

  void _cleanupSubscription() {
    if (_realtimeChannel != null) {
      _repository.unsubscribeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }

  Future<void> fetchMyNetworks() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final networks = await _repository.getMyNetworks(_userId!);
      _myNetworks = networks;

      // Update active network if it still exists
      if (_activeCustomNetwork != null) {
        final match = networks.where((n) => n.id == _activeCustomNetwork!.id);
        if (match.isNotEmpty) {
          _activeCustomNetwork = match.first;
        } else {
          final lostNetwork = _activeCustomNetwork!;
          _activeCustomNetwork = null;
          _activeNetworkMembers = [];
          _onMembershipLostController.add(lostNetwork);
        }
      }
    } catch (e) {
      debugPrint('[CustomNetworkProvider] Error fetching networks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectCustomNetwork(CustomNetwork? network) {
    _activeCustomNetwork = network;
    _activeNetworkMembers = [];
    notifyListeners();

    if (network != null) {
      loadActiveNetworkMembers();
    }
  }

  Future<void> loadActiveNetworkMembers() async {
    if (_activeCustomNetwork == null) return;
    _isLoadingMembers = true;
    notifyListeners();

    try {
      final members = await _repository.getNetworkMembers(_activeCustomNetwork!.id);
      _activeNetworkMembers = members;
      
      // Sync member count
      if (_activeCustomNetwork != null && _activeCustomNetwork!.memberCount != members.length) {
        _activeCustomNetwork = _activeCustomNetwork!.copyWith(memberCount: members.length);
        final index = _myNetworks.indexWhere((n) => n.id == _activeCustomNetwork!.id);
        if (index != -1) {
          _myNetworks[index] = _activeCustomNetwork!;
        }
      }
    } catch (e) {
      debugPrint('[CustomNetworkProvider] Error loading members: $e');
    } finally {
      _isLoadingMembers = false;
      notifyListeners();
    }
  }

  /// Create a new network with creator configurations (name, isPrivate, allowAnonymous, iconEmoji, colorHex).
  Future<CustomNetwork> createNetwork({
    required String name,
    String? description,
    required String iconEmoji,
    required String colorHex,
    required bool isPrivate,
    required bool allowAnonymous,
    List<int> initialMemberIds = const [],
  }) async {
    final uid = _userId;
    if (uid == null) {
      throw Exception('User is not authenticated');
    }

    try {
      final newNetwork = await _repository.createNetwork(
        creatorId: uid,
        name: name,
        description: description,
        iconEmoji: iconEmoji,
        colorHex: colorHex,
        isPrivate: isPrivate,
        allowAnonymous: allowAnonymous,
        initialMemberIds: initialMemberIds,
      );

      _myNetworks.insert(0, newNetwork);
      _activeCustomNetwork = newNetwork;
      notifyListeners();

      loadActiveNetworkMembers();
      return newNetwork;
    } catch (e) {
      debugPrint('[CustomNetworkProvider] Error creating network: $e');
      rethrow;
    }
  }

  /// Mafia-style direct add: immediately adds a connection without needing an invite or approval.
  Future<void> addMemberDirectly(int memberUserId) async {
    final net = _activeCustomNetwork;
    final uid = _userId;
    if (net == null || uid == null) return;

    try {
      await _repository.addMemberDirectly(
        networkId: net.id,
        userId: memberUserId,
        addedBy: uid,
        networkName: net.name,
      );
      await loadActiveNetworkMembers();
    } catch (e) {
      debugPrint('[CustomNetworkProvider] Error adding member: $e');
      rethrow;
    }
  }

  /// Batch add members directly
  Future<void> addMembersBatch(List<int> memberUserIds) async {
    final net = _activeCustomNetwork;
    final uid = _userId;
    if (net == null || uid == null || memberUserIds.isEmpty) return;

    try {
      await _repository.addMembersBatch(
        networkId: net.id,
        userIds: memberUserIds,
        addedBy: uid,
        networkName: net.name,
      );
      await loadActiveNetworkMembers();
    } catch (e) {
      debugPrint('[CustomNetworkProvider] Error batch adding members: $e');
      rethrow;
    }
  }

  /// Check if a user is already a member of active network
  bool isMemberOfActiveNetwork(int userId) {
    return _activeNetworkMembers.any((m) => m.userId == userId);
  }

  /// Remove a member from the network (or leave network if self).
  Future<void> removeMember(int memberUserId, {String? networkId}) async {
    final netId = networkId ?? _activeCustomNetwork?.id;
    if (netId == null) return;

    try {
      await _repository.removeMember(
        networkId: netId,
        userId: memberUserId,
      );

      // Optimistically remove from _activeNetworkMembers
      _activeNetworkMembers.removeWhere((m) => m.userId == memberUserId);

      // Sync member count
      if (_activeCustomNetwork != null && _activeCustomNetwork!.id == netId) {
        _activeCustomNetwork = _activeCustomNetwork!.copyWith(
          memberCount: _activeNetworkMembers.length,
        );
        final index = _myNetworks.indexWhere((n) => n.id == netId);
        if (index != -1) {
          _myNetworks[index] = _activeCustomNetwork!;
        }
      }

      // If current user removed themselves (left network)
      if (_userId != null && memberUserId == _userId) {
        _myNetworks.removeWhere((n) => n.id == netId);
        if (_activeCustomNetwork?.id == netId) {
          _activeCustomNetwork = null;
          _activeNetworkMembers = [];
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[CustomNetworkProvider] Error removing member: $e');
      rethrow;
    }
  }

  /// Pin or unpin a post in a custom network (creator only)
  Future<void> pinPost(String networkId, String? postId) async {
    try {
      await _repository.updatePinnedPost(networkId: networkId, postId: postId);
      updatePinnedPostLocally(networkId, postId);
    } catch (e) {
      debugPrint('[CustomNetworkProvider] Error pinning post: $e');
      rethrow;
    }
  }

  /// Update pinned post in local state optimistically
  void updatePinnedPostLocally(String networkId, String? postId) {
    if (_activeCustomNetwork != null && _activeCustomNetwork!.id == networkId) {
      _activeCustomNetwork = _activeCustomNetwork!.copyWith(
        pinnedPostId: postId,
        nullifyPinnedPostId: postId == null,
      );
    }
    final index = _myNetworks.indexWhere((n) => n.id == networkId);
    if (index != -1) {
      _myNetworks[index] = _myNetworks[index].copyWith(
        pinnedPostId: postId,
        nullifyPinnedPostId: postId == null,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _cleanupSubscription();
    _onMembershipLostController.close();
    super.dispose();
  }
}
