import 'package:connect/Models/app_error.dart';
import 'package:connect/Repositories/connection_repository.dart';
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

  ConnectionProvider({ConnectionRepository? connectionRepository})
      : _repository = connectionRepository ?? SupabaseConnectionRepository();

  int? _userId;
  int? get userId => _userId;

  RealtimeChannel? _connectionsSubscription;

  List<Map<String, dynamic>> _lastKnownConnections = [];

  UserConnectionState _state = UserConnectionInitial();
  UserConnectionState get state => _state;

  List<Map<String, dynamic>> get connections =>
      _state is UserConnectionLoaded ? (_state as UserConnectionLoaded).connections : [];
  AppError? get lastError =>
      _state is UserConnectionError ? (_state as UserConnectionError).error : null;

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

  Future<List<Map<String, dynamic>>> fetchConnections() async {
    _state = UserConnectionLoading();
    notifyListeners();
    final list = await getOtherProfiles();
    _setLoadedState(list);
    notifyListeners();
    return list;
  }

  void subscribeToConnections() {
    if (_userId == null) return;
    unsubscribeFromConnections();

    _connectionsSubscription = _repository.subscribeToConnections((payload) async {
      print("Realtime connection change detected: ${payload.toString()}");
      await fetchConnections();
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
      {String? sharedCardByPresenter, String? sharedCardByScanner}) async {
    if (idA == idB) {
      print("Cannot connect a user to themselves");
      return;
    }
    final int id1 = idA < idB ? idA : idB;
    final int id2 = idA > idB ? idA : idB;

    String u1Share = 'both';
    String u2Share = 'both';

    if (idA < idB) {
      u1Share = sharedCardByScanner ?? 'both';
      u2Share = sharedCardByPresenter ?? 'both';
    } else {
      u1Share = sharedCardByPresenter ?? 'both';
      u2Share = sharedCardByScanner ?? 'both';
    }

    try {
      await _repository.connectUsers(id1, id2, u1Share, u2Share);
      print(
          "Successfully connected user $id1 and user $id2 (shares: $u1Share, $u2Share)");
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
      await _repository.updateConnectionAccess(id1, id2, columnToUpdate, newAccessType);
      print(
          "Updated connection access: $myUserId shares $newAccessType with $otherUserId");
      await fetchConnections();
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
      );

      await _repository.markInviteCodeAsUsed(response['id']);

      print("Successfully redeemed invite code: $code");
      return senderId;
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }

  Future<void> deleteProfile(int id, {Future<void> Function(int profileId, String? roomId)? onRoomCleanup}) async {
    final myUserId = _userId;
    if (myUserId == null) return;
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
        await fetchConnections();
      } catch (e) {
        print("Error deleting someone else's profile/chat: $e");
        _setError(e);
        rethrow;
      }
    }
    notifyListeners();
  }
}
