import 'dart:convert';
import 'package:connect/Models/app_error.dart';
import 'package:connect/Repositories/notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/main.dart';

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

  Set<int> _sentDirectRequestUserIds = {};
  Set<int> get sentDirectRequestUserIds => _sentDirectRequestUserIds;

  bool hasSentDirectRequest(int toUserId) =>
      _sentDirectRequestUserIds.contains(toUserId);

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
        fetchSentDirectRequests();
      } else {
        unsubscribeFromNotifications();
        _sentDirectRequestUserIds.clear();
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
        
        // Dismiss from OS notification tray if the notification row was deleted
        if (payload.eventType == PostgresChangeEvent.delete) {
          final oldRecord = payload.oldRecord;
          if (oldRecord != null) {
            final notificationId = oldRecord['id'] as String?;
            if (notificationId != null) {
              final notifId = getNotificationId(notificationId);
              await flutterLocalNotificationsPlugin.cancel(id: notifId);
              print("PushNotifications: Dismissed notification $notifId from OS tray due to deletion.");
            }
          }
          await fetchNotifications();
        } else if (payload.eventType == PostgresChangeEvent.insert) {
          final newRecord = payload.newRecord;
          final notificationId = newRecord?['id']?.toString() ?? '';

          await fetchNotifications();

          if (notificationId.isNotEmpty) {
            final notif = notifications.firstWhere(
              (n) => n['id']?.toString() == notificationId,
              orElse: () => <String, dynamic>{},
            );

            if (notif.isNotEmpty) {
              _triggerInAppBannerForNotification(notif);
            }
          }
        } else {
          await fetchNotifications();
        }
      },
    );

    // Initial fetch
    _state = NotificationLoading();
    notifyListeners();
    fetchNotifications();
    fetchSentDirectRequests();
  }

  void _triggerInAppBannerForNotification(Map<String, dynamic> notif) {
    try {
      final notifId = notif['id']?.toString() ?? '';
      if (notifId.isEmpty) return;

      final type = notif['type']?.toString() ?? '';
      final otherUser = notif['other_user'] as Map<String, dynamic>? ?? {};
      final actorName = otherUser['name']?.toString() ?? 'Someone';
      final actorAvatar = otherUser['avatar_url']?.toString() ??
          otherUser['avatarUrl']?.toString() ??
          '';
      final actorId = otherUser['id'] as int?;
      final rawNote = notif['note']?.toString();

      String title = 'Connection Update';
      String body = '$actorName sent you a connection update';

      if (type == 'vouch_request') {
        title = 'New Vouch Request';
        body = '$actorName wants to connect & vouched for you';
      } else if (type == 'vouch_received') {
        title = 'New Endorsement';
        body = '$actorName vouched for you on your profile';
      } else if (type == 'vouch_accepted') {
        title = 'Vouch Accepted';
        body = '$actorName accepted your vouch and connected with you!';
      } else if (type == 'direct_connection_request') {
        title = 'Connection Request';
        String msg = '';
        if (rawNote != null && rawNote.startsWith('{')) {
          try {
            final parsed = jsonDecode(rawNote);
            if (parsed is Map && parsed['message'] != null) {
              msg = parsed['message'].toString().trim();
            }
          } catch (_) {}
        } else if (rawNote != null) {
          msg = rawNote.trim();
        }
        body = msg.isNotEmpty
            ? '$actorName: $msg'
            : '$actorName sent you a direct connection request';
      } else if (type == 'referral') {
        final isRequest = rawNote != null &&
            (rawNote.startsWith('[REFERRAL_REQUEST]') ||
                rawNote.startsWith('[REFERRAL_REQUEST_ACTIONED]'));
        final referredUser =
            notif['referred_user'] as Map<String, dynamic>? ?? {};
        final referredName = referredUser['name']?.toString() ?? 'Someone';
        title = isRequest ? 'Introduction Request' : 'New Referral';
        body = isRequest
            ? '$actorName asked to be introduced to $referredName'
            : '$actorName referred $referredName to you';
      } else if (type == 'tribe_invite') {
        title = 'Mafia Invitation';
        body = '$actorName invited you to join a Mafia';
      } else if (type == 'custom_network_added') {
        title = 'Added to Network';
        body = '$actorName added you to a network';
      }

      showInAppConnectionBanner(
        notificationId: notifId,
        title: title,
        body: body,
        avatarUrl: actorAvatar,
        actorId: actorId,
      );
    } catch (e) {
      print("NotificationProvider: Error triggering in-app banner: $e");
    }
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

  Future<void> sendReferralRequest({
    required int toUserId,
    required int referredUserId,
    String? note,
  }) async {
    final myUserId = _userId;
    if (myUserId == null) return;
    try {
      final requestNote = note != null && note.isNotEmpty
          ? '[REFERRAL_REQUEST]:$note'
          : '[REFERRAL_REQUEST]';
      await _repository.insertReferralNotification(
        userId: toUserId,
        otherUserId: myUserId,
        referredUserId: referredUserId,
        note: requestNote,
      );
    } catch (e) {
      print("Error sending referral request: $e");
      _setError(e);
      rethrow;
    }
  }

  Future<void> fetchSentDirectRequests() async {
    final myUserId = _userId;
    if (myUserId == null) return;
    try {
      final userIds = await _repository.getSentDirectRequestUserIds(myUserId);
      _sentDirectRequestUserIds = userIds.toSet();
      notifyListeners();
    } catch (e) {
      print("Error fetching sent direct requests: $e");
    }
  }

  Future<void> sendDirectConnectionRequest({
    required int toUserId,
    required String sharedCard,
    String? note,
  }) async {
    final myUserId = _userId;
    if (myUserId == null) return;
    try {
      await _repository.sendDirectConnectionRequest(
        toUserId: toUserId,
        fromUserId: myUserId,
        sharedCard: sharedCard,
        note: note,
      );
      _sentDirectRequestUserIds.add(toUserId);
      notifyListeners();
    } catch (e) {
      print("Error sending direct connection request: $e");
      _setError(e);
      rethrow;
    }
  }

  Future<bool> hasPendingDirectConnectionRequest(int toUserId) async {
    final myUserId = _userId;
    if (myUserId == null) return false;
    try {
      return await _repository.hasPendingDirectConnectionRequest(
        fromUserId: myUserId,
        toUserId: toUserId,
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> markReferralRequestActioned(String notificationId, String currentNote) async {
    try {
      final String actionedNote = currentNote.replaceFirst('[REFERRAL_REQUEST]', '[REFERRAL_REQUEST_ACTIONED]');
      await _repository.updateNotificationNote(notificationId, actionedNote);
      
      // Update local state for immediate visual feedback
      final index = notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        final updated = List<Map<String, dynamic>>.from(notifications);
        updated[index] = Map<String, dynamic>.from(updated[index])
          ..['note'] = actionedNote
          ..['is_seen'] = true;
        _setLoadedState(updated);
        notifyListeners();
      }
    } catch (e) {
      print("Error marking referral request actioned: $e");
      _setError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getSentReferralRequests() async {
    final myUserId = _userId;
    if (myUserId == null) return [];
    try {
      return await _repository.getSentReferralRequests(myUserId);
    } catch (e) {
      print("Error fetching sent referral requests: $e");
      _setError(e);
      return [];
    }
  }

  @override
  void dispose() {
    unsubscribeFromNotifications();
    super.dispose();
  }
}
