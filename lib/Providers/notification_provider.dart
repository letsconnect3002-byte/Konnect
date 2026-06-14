import 'package:connect/Models/app_error.dart';
import 'package:connect/Repositories/notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

sealed class NotificationState {}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class NotificationLoaded extends NotificationState {
  final List<Map<String, dynamic>> notifications;
  NotificationLoaded(this.notifications);
}

class NotificationError extends NotificationState {
  final AppError error;
  NotificationError(this.error);
}

class NotificationProvider with ChangeNotifier {
  final NotificationRepository _repository;

  NotificationProvider({NotificationRepository? notificationRepository})
      : _repository =
            notificationRepository ?? SupabaseNotificationRepository();

  int? _userId;
  int? get userId => _userId;

  RealtimeChannel? _notificationsSubscription;
  List<Map<String, dynamic>> _lastKnownNotifications = [];

  NotificationState _state = NotificationInitial();
  NotificationState get state => _state;

  List<Map<String, dynamic>> get notifications => _state is NotificationLoaded
      ? (_state as NotificationLoaded).notifications
      : _lastKnownNotifications;

  int get unreadCount =>
      notifications.where((n) => n['is_seen'] == false).length;

  AppError? get lastError =>
      _state is NotificationError ? (_state as NotificationError).error : null;

  void _setError(Object e) {
    _state = NotificationError(AppError.from(e));
    notifyListeners();
  }

  void _setLoadedState(List<Map<String, dynamic>> list) {
    _lastKnownNotifications = list;
    _state = NotificationLoaded(list);
  }

  void clearError() {
    _state = NotificationLoaded(_lastKnownNotifications);
    notifyListeners();
  }

  void updateUserId(int? newUserId) {
    if (_userId != newUserId) {
      _userId = newUserId;
      if (_userId != null) {
        subscribeToNotifications();
      } else {
        unsubscribeFromNotifications();
        _setLoadedState([]);
        notifyListeners();
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final myUserId = _userId;
    if (myUserId == null) return [];

    try {
      final list = await _repository.getNotifications(myUserId);
      _setLoadedState(list);
      notifyListeners();
      return list;
    } catch (e) {
      print("Error fetching notifications: $e");
      _setError(e);
      return [];
    }
  }

  void subscribeToNotifications() {
    if (_userId == null) return;
    unsubscribeFromNotifications();

    _notificationsSubscription = _repository.subscribeToNotifications(
      _userId!,
      (payload) async {
        print("Realtime connection notification change: ${payload.toString()}");
        await fetchNotifications();
      },
    );

    // Initial fetch
    _state = NotificationLoading();
    notifyListeners();
    fetchNotifications();
  }

  void unsubscribeFromNotifications() {
    if (_notificationsSubscription != null) {
      _repository.removeChannel(_notificationsSubscription!);
      _notificationsSubscription = null;
    }
  }

  Future<void> markAsSeen(String notificationId) async {
    try {
      await _repository.markAsSeen(notificationId);
      // Wait for realtime listener to trigger update, or update local list immediately:
      final index = notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        final updated = List<Map<String, dynamic>>.from(notifications);
        updated[index] = Map<String, dynamic>.from(updated[index])
          ..['is_seen'] = true;
        _setLoadedState(updated);
        notifyListeners();
      }
    } catch (e) {
      print("Error marking notification seen: $e");
      _setError(e);
    }
  }

  Future<void> markAllAsSeen() async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      await _repository.markAllAsSeen(myUserId);
      // Update local state for immediate response
      final updated = notifications.map((n) {
        return Map<String, dynamic>.from(n)..['is_seen'] = true;
      }).toList();
      _setLoadedState(updated);
      notifyListeners();
    } catch (e) {
      print("Error marking all notifications seen: $e");
      _setError(e);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _repository.deleteNotification(notificationId);
      final updated = List<Map<String, dynamic>>.from(notifications)
        ..removeWhere((n) => n['id'] == notificationId);
      _setLoadedState(updated);
      notifyListeners();
    } catch (e) {
      print("Error deleting notification: $e");
      _setError(e);
    }
  }

  Future<void> sendReferral({
    required int toUserId,
    required int referredUserId,
    String? note,
  }) async {
    final myUserId = _userId;
    if (myUserId == null) return;
    try {
      await _repository.insertReferralNotification(
        userId: toUserId,
        otherUserId: myUserId,
        referredUserId: referredUserId,
        note: note,
      );
    } catch (e) {
      print("Error sending referral: $e");
      _setError(e);
      rethrow;
    }
  }

  @override
  void dispose() {
    unsubscribeFromNotifications();
    super.dispose();
  }
}
