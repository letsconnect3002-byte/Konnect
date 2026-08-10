import 'package:connect/Models/app_error.dart';
import 'package:connect/Repositories/connection_repository.dart';
import 'package:connect/Repositories/notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

sealed class UserConnectionState {}

class UserConnectionInitial extends UserConnectionState {}

class UserConnectionLoading extends UserConnectionState {}

class UserConnectionLoaded extends UserConnectionState {
  final List<Map<String, dynamic>> connections;
  UserConnectionLoaded(this.connections);
}

class UserConnectionError extends UserConnectionState {
  final AppError error;
  UserConnectionError(this.error);
}

class ConnectionProvider with ChangeNotifier {
  final ConnectionRepository _repository;
  final NotificationRepository _notificationRepository;

  ConnectionProvider({
    ConnectionRepository? connectionRepository,
    NotificationRepository? notificationRepository,
  })  : _repository = connectionRepository ?? SupabaseConnectionRepository(),
        _notificationRepository =
            notificationRepository ?? SupabaseNotificationRepository();

  int? _userId;
  int? get userId => _userId;

  RealtimeChannel? _connectionsSubscription;

  List<Map<String, dynamic>> _lastKnownConnections = [];

  UserConnectionState _state = UserConnectionInitial();
  UserConnectionState get state => _state;

  List<Map<String, dynamic>> get connections => _state is UserConnectionLoaded
      ? (_state as UserConnectionLoaded).connections
      : _lastKnownConnections;
  AppError? get lastError => _state is UserConnectionError
      ? (_state as UserConnectionError).error
      : null;

  void _setError(Object e) {
    _state = UserConnectionError(AppError.from(e));
    notifyListeners();
  }

  void _setLoadedState(List<Map<String, dynamic>> list) {
    _lastKnownConnections = list;
    _state = UserConnectionLoaded(list);
  }

  void clearError() {
    _state = UserConnectionLoaded(_lastKnownConnections);
    notifyListeners();
  }

  void updateUserId(int? newUserId) {
    if (_userId != newUserId) {
      _userId = newUserId;
      if (_userId != null) {
        subscribeToConnections();
      } else {
        unsubscribeFromConnections();
        _setLoadedState([]);
        notifyListeners();
      }
    }
  }

  // Helper to get or create a unique owner_id for this device
  Future<String> _getOrCreateOwnerId() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return session.user.id;
    }
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString('owner_id');
    if (storedId == null) {
      throw Exception("Owner ID not found and user not authenticated");
    }
    return storedId;
  }

  Future<List<Map<String, dynamic>>> getOtherProfiles() async {
    try {
      final myUserId = _userId;
      if (myUserId == null) {
        return [];
      }
      return await _repository.getOtherProfiles(myUserId);
    } catch (e) {
      print("Error fetching other profiles: $e");
      _setError(e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchConnections(
      {bool silent = false}) async {
    final myUserId = _userId;
    if (myUserId == null) {
      if (!silent) {
        _state = UserConnectionLoading();
        notifyListeners();
      }
      _setLoadedState([]);
      notifyListeners();
      return [];
    }

    if (!silent) {
      _state = UserConnectionLoading();
      notifyListeners();
    }

    try {
      final list = await getOtherProfiles();

      // Fetch user's blocked list (abusive users we blocked)
      final List<dynamic> blocks = await Supabase.instance.client
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', myUserId);
      final Set<int> blockedIds = blocks.map((b) => b['blocked_id'] as int).toSet();

      // Fetch list of users who blocked us
      final List<dynamic> blockedBy = await Supabase.instance.client
          .from('blocked_users')
          .select('blocker_id')
          .eq('blocked_id', myUserId);
      final Set<int> blockedByIds = blockedBy.map((b) => b['blocker_id'] as int).toSet();

      // Mark connection attributes
      for (final conn in list) {
        final id = conn['id'] as int? ?? 0;
        conn['isBlockedByMe'] = blockedIds.contains(id);
        conn['hasBlockedMe'] = blockedByIds.contains(id);
        conn['isBlocked'] = blockedIds.contains(id) || blockedByIds.contains(id);
      }

      _setLoadedState(list);
    } catch (e) {
      print("Error fetching connections/blocks: $e");
      _setError(e);
    }
    notifyListeners();
    return connections;
  }

  void subscribeToConnections() {
    if (_userId == null) return;
    unsubscribeFromConnections();

    _connectionsSubscription =
        _repository.subscribeToConnections((payload) async {
      print("Realtime connection change detected: ${payload.toString()}");
      await fetchConnections(silent: true);
    });

    fetchConnections();
  }

  void unsubscribeFromConnections() {
    if (_connectionsSubscription != null) {
      _repository.removeChannel(_connectionsSubscription!);
      _connectionsSubscription = null;
    }
  }

  @override
  void dispose() {
    unsubscribeFromConnections();
    super.dispose();
  }

  Future<void> saveOtherProfileData(
      bool isMyProfile, Map<String, dynamic> profileData,
      {int? connectionProfileId}) async {
    try {
      final ownerId = await _getOrCreateOwnerId();
      await _repository.saveOtherProfileData({
        'owner_id': ownerId,
        'name': profileData['name'] ?? '',
        'profession': profileData['profession'] ?? '',
        'email': profileData['email'] ?? '',
        'professional_email': profileData['professionalEmail'] ?? '',
        'phone_number': profileData['phoneNumber'] ?? '',
        'professional_phone_number':
            profileData['professionalPhoneNumber'] ?? '',
        'instagram': profileData['instagram'] ?? '',
        'linkedin': profileData['linkedin'] ?? '',
        'twitter': profileData['twitter'] ?? '',
        'is_my_profile': isMyProfile,
        'company': profileData['company'] ?? '',
        'bio': profileData['bio'] ?? '',
        'professional_bio': profileData['professionalBio'] ?? '',
        'avatar_url': profileData['avatarUrl'] ?? '',
        'show_profile_to_connections':
            profileData['showProfileToConnections'] == true ||
                profileData['showProfileToConnections'] == 'true',
        'card_types':
            profileData['cardTypes'] ?? profileData['card_types'] ?? [],
        'connection_profile_id': connectionProfileId ?? profileData['id'],
      });
      print("inserted scanned connection");
      notifyListeners();
    } catch (e) {
      print("Error saving scanned connection: $e");
      _setError(e);
    }
  }

  Future<void> connectUsers(int idA, int idB,
      {String? sharedCardByPresenter,
      String? sharedCardByScanner,
      String connectionType = 'qr_code'}) async {
    if (idA == idB) {
      print("Cannot connect a user to themselves");
      return;
    }
    final int id1 = idA < idB ? idA : idB;
    final int id2 = idA > idB ? idA : idB;

    final prefs = await SharedPreferences.getInstance();
    final String defaultCard =
        prefs.getString('default_card_visibility') ?? 'casual';

    String u1Share = 'casual';
    String u2Share = 'casual';

    if (idA < idB) {
      u1Share = sharedCardByScanner ?? defaultCard;
      u2Share = sharedCardByPresenter ?? 'casual';
    } else {
      u1Share = sharedCardByPresenter ?? 'casual';
      u2Share = sharedCardByScanner ?? defaultCard;
    }

    try {
      // Check if blocked by either user
      final blockCheck = await Supabase.instance.client
          .from('blocked_users')
          .select('id')
          .or('and(blocker_id.eq.$idA,blocked_id.eq.$idB),and(blocker_id.eq.$idB,blocked_id.eq.$idA)')
          .maybeSingle();

      if (blockCheck != null) {
        throw Exception("You cannot connect to this user due to a block.");
      }

      final bool alreadyConnected =
          await _repository.connectionExists(id1, id2);

      await _repository.connectUsers(id1, id2, u1Share, u2Share);
      print(
          "Successfully connected user $id1 and user $id2 (shares: $u1Share, $u2Share)");

      if (!alreadyConnected) {
        // Insert notifications for both users since this is a new connection
        try {
          await _notificationRepository.insertNotification(
            userId: idA,
            otherUserId: idB,
            type: connectionType,
          );
          await _notificationRepository.insertNotification(
            userId: idB,
            otherUserId: idA,
            type: connectionType,
          );
          print("Inserted connection notifications");
        } catch (notifErr) {
          print("Non-fatal error inserting notifications: $notifErr");
        }
      } else {
        print(
            "Connection already exists. Skipping insertion of duplicate notifications.");
      }

      await fetchConnections(silent: true);
      notifyListeners();
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }

  Future<void> updateConnectionAccess(
      int otherUserId, String newAccessType) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    final int id1 = myUserId < otherUserId ? myUserId : otherUserId;
    final int id2 = myUserId > otherUserId ? myUserId : otherUserId;

    final String columnToUpdate =
        myUserId < otherUserId ? 'user_1_shared_card' : 'user_2_shared_card';

    try {
      await _repository.updateConnectionAccess(
          id1, id2, columnToUpdate, newAccessType);
      print(
          "Updated connection access: $myUserId shares $newAccessType with $otherUserId");
      await fetchConnections(silent: true);
    } catch (e) {
      print("Error updating connection access: $e");
      _setError(e);
      rethrow;
    }
  }

  Future<void> disconnectUsers(int idA, int idB) async {
    final int id1 = idA < idB ? idA : idB;
    final int id2 = idA > idB ? idA : idB;
    try {
      await _repository.disconnectUsers(id1, id2);
      print("Successfully disconnected user $id1 and user $id2");

      // Delete connection notifications between the users
      try {
        await _notificationRepository.deleteNotificationsBetweenUsers(idA, idB);
        print("Deleted notifications between $idA and $idB");
      } catch (notifErr) {
        print("Non-fatal error deleting connection notifications: $notifErr");
      }

      await fetchConnections(silent: true);
      notifyListeners();
    } catch (e) {
      print("Error disconnecting users: $e");
      _setError(e);
      rethrow;
    }
  }

  Future<int> redeemInviteCode(String code, String mySharedCardType) async {
    final myUserId = _userId;
    if (myUserId == null) {
      throw Exception("User is not signed in or profile is not loaded");
    }

    try {
      final response = await _repository.redeemInviteCode(code);

      if (response == null) {
        throw Exception("Invalid or already used code");
      }

      final int senderId = response['sender_id'] as int;
      final String sharedCardType = response['shared_card_type'] as String;

      await connectUsers(
        myUserId,
        senderId,
        sharedCardByPresenter: sharedCardType,
        sharedCardByScanner: mySharedCardType,
        connectionType: 'vip_pass_key',
      );

      await _repository.markInviteCodeAsUsed(response['id'] as String);

      print("Successfully redeemed invite code: $code");
      return senderId;
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }

  Future<void> markInviteCodeAsUsedByCode(String code) async {
    try {
      await _repository.markInviteCodeAsUsedByCode(code);
    } catch (e) {
      print("Error marking invite code as used by code: $e");
    }
  }

  Future<void> deleteProfile(int id,
      {Future<void> Function(int profileId, String? roomId)?
          onRoomCleanup}) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    // Optimistically remove from local state immediately for instant UI update
    _lastKnownConnections.removeWhere((c) {
      final cId = c['id'] ?? c['connection_profile_id'] ?? c['profile_id'];
      return cId != null && (cId == id || cId.toString() == id.toString());
    });
    if (_state is UserConnectionLoaded) {
      (_state as UserConnectionLoaded).connections.removeWhere((c) {
        final cId = c['id'] ?? c['connection_profile_id'] ?? c['profile_id'];
        return cId != null && (cId == id || cId.toString() == id.toString());
      });
    }
    notifyListeners();

    if (id == myUserId) {
      try {
        await _repository.deleteMyProfile(id);
        print("Deleted my profile with id: $id");
      } catch (e) {
        print("Error deleting my profile: $e");
        _setError(e);
      }
    } else {
      try {
        final roomId = await _repository.resolveRoomId(myUserId, id);
        await disconnectUsers(myUserId, id);
        if (onRoomCleanup != null) {
          await onRoomCleanup(id, roomId);
        }
        await fetchConnections(silent: true);
      } catch (e) {
        print("Error deleting someone else's profile/chat: $e");
        _setError(e);
        rethrow;
      }
    }
    notifyListeners();
  }

  Future<void> blockUser(int id) async {
    final myUserId = _userId;
    if (myUserId == null) throw Exception("User not authenticated");

    try {
      // 1. Log the block in Supabase blocked_users table
      await Supabase.instance.client.from('blocked_users').insert({
        'blocker_id': myUserId,
        'blocked_id': id,
      });
      print("Logged block: blocker $myUserId, blocked $id");

      // 2. Refresh connections lists to show blocked status instantly
      await fetchConnections(silent: true);
    } catch (e) {
      print("Error blocking user: $e");
      _setError(e);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> unblockUser(int id) async {
    final myUserId = _userId;
    if (myUserId == null) throw Exception("User not authenticated");

    try {
      // Delete block entry from Supabase
      await Supabase.instance.client
          .from('blocked_users')
          .delete()
          .match({'blocker_id': myUserId, 'blocked_id': id});
      print("Logged unblock: blocker $myUserId, unblocked $id");

      // Refresh connections lists
      await fetchConnections(silent: true);
    } catch (e) {
      print("Error unblocking user: $e");
      _setError(e);
      rethrow;
    }
    notifyListeners();
  }
}
