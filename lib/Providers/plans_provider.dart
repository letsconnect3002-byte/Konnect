import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Models/app_error.dart';
import 'package:connect/Repositories/plans_repository.dart';
import 'package:connect/Repositories/notification_repository.dart';
import 'package:connect/main.dart';

sealed class PlansState {}

class PlansInitial extends PlansState {}

class PlansLoading extends PlansState {}

class PlansLoaded extends PlansState {
  final List<Map<String, dynamic>> plans;
  PlansLoaded(this.plans);
}

class PlansError extends PlansState {
  final AppError error;
  PlansError(this.error);
}

/// Category metadata: emoji + display label
class PlanCategory {
  final String key;
  final String emoji;
  final String label;
  const PlanCategory(this.key, this.emoji, this.label);
}

const List<PlanCategory> planCategories = [
  PlanCategory('meeting', '💻', 'Meeting'),
  PlanCategory('video_call', '📹', 'Video Call'),
  PlanCategory('food_drinks', '🍽️', 'Food & Drinks'),
  PlanCategory('sports', '⚽', 'Sports'),
  PlanCategory('party', '🎉', 'Party'),
  PlanCategory('video_game', '🎮', 'Video Game'),
  PlanCategory('movie', '🎬', 'Movie'),
  PlanCategory('hangout', '👥', 'Hangout'),
  PlanCategory('travel', '✈️', 'Travel'),
  PlanCategory('other', '📌', 'Other'),
];

String categoryEmoji(String key) {
  final found = planCategories.firstWhere(
    (c) => c.key == key,
    orElse: () => const PlanCategory('other', '📌', 'Other'),
  );
  return found.emoji;
}

String categoryLabel(String key) {
  final found = planCategories.firstWhere(
    (c) => c.key == key,
    orElse: () => PlanCategory(key, '📌', key),
  );
  return found.label;
}

class PlansProvider with ChangeNotifier {
  final PlansRepository _repository;
  final NotificationRepository _notificationRepository;

  PlansProvider({
    PlansRepository? plansRepository,
    NotificationRepository? notificationRepository,
  })  : _repository = plansRepository ?? SupabasePlansRepository(),
        _notificationRepository =
            notificationRepository ?? SupabaseNotificationRepository();

  int? _userId;
  int? get userId => _userId;

  RealtimeChannel? _invitesSubscription;
  RealtimeChannel? _plansSubscription;
  RealtimeChannel? _notificationsSubscription;

  List<Map<String, dynamic>> _lastKnownPlans = [];

  PlansState _state = PlansInitial();
  PlansState get state => _state;

  List<Map<String, dynamic>> get plans => _state is PlansLoaded
      ? (_state as PlansLoaded).plans
      : _lastKnownPlans;

  AppError? get lastError =>
      _state is PlansError ? (_state as PlansError).error : null;

  void _setError(Object e) {
    _state = PlansError(AppError.from(e));
    notifyListeners();
  }

  void _setLoadedState(List<Map<String, dynamic>> list) {
    _lastKnownPlans = list;
    _state = PlansLoaded(list);
    _syncAllReminders(list);
  }

  Future<void> _syncAllReminders(List<Map<String, dynamic>> plansList) async {
    for (final plan in plansList) {
      final planId = plan['id'] as String?;
      final title = plan['title'] as String? ?? 'Upcoming Plan';
      final startsAtStr = plan['starts_at'] as String?;
      final myStatus = plan['my_status'] as String?;

      if (planId != null && startsAtStr != null) {
        final startsAt = DateTime.tryParse(startsAtStr);
        if (startsAt != null) {
          if (myStatus == 'accepted' || myStatus == 'creator') {
            await _scheduleReminder(planId, title, startsAt);
          } else {
            await _cancelReminder(planId);
          }
        }
      }
    }
  }

  void clearError() {
    _state = PlansLoaded(_lastKnownPlans);
    notifyListeners();
  }

  void updateUserId(int? newUserId) {
    if (_userId != newUserId) {
      _userId = newUserId;
      if (_userId != null) {
        _subscribeToRealtime();
        fetchPlans(silent: true);
      } else {
        _unsubscribeFromRealtime();
        _setLoadedState([]);
        notifyListeners();
      }
    }
  }

  // ── Fetch ──

  Future<List<Map<String, dynamic>>> fetchPlans({bool silent = false}) async {
    final myUserId = _userId;
    if (myUserId == null) return [];

    try {
      if (!silent) {
        _state = PlansLoading();
        notifyListeners();
      }
      final list = await _repository.getMyPlans(myUserId);
      _setLoadedState(list);
      notifyListeners();
      return list;
    } catch (e) {
      print("Error fetching plans: $e");
      _setError(e);
      return [];
    }
  }

  // ── Create ──

  Future<Map<String, dynamic>?> createPlan({
    required String title,
    required String category,
    required String planType,
    required DateTime startsAt,
    DateTime? endsAt,
    String? description,
    String? location,
    bool isOnline = false,
    String? meetingLink,
    List<int> inviteeIds = const [],
  }) async {
    final myUserId = _userId;
    if (myUserId == null) return null;

    try {
      final planData = <String, dynamic>{
        'creator_id': myUserId,
        'title': title,
        'category': category,
        'plan_type': planType,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'description': description,
        'location': location,
        'is_online': isOnline,
        'meeting_link': meetingLink,
      };
      if (endsAt != null) {
        planData['ends_at'] = endsAt.toUtc().toIso8601String();
      }

      final plan = await _repository.createPlan(planData);
      final planId = plan['id'] as String;

      // Invite users
      for (final inviteeId in inviteeIds) {
        await _repository.inviteUser(
          planId: planId,
          inviterId: myUserId,
          inviteeId: inviteeId,
        );
        try {
          await _notificationRepository.insertNotification(
            userId: inviteeId,
            otherUserId: myUserId,
            type: 'plan_invite',
            note: planId,
          );
        } catch (notifErr) {
          print("Non-fatal error inserting plan notification: $notifErr");
        }
      }

      // Schedule a local reminder 30 minutes before
      await _scheduleReminder(planId, title, startsAt);

      await fetchPlans(silent: true);
      return plan;
    } catch (e) {
      print("Error creating plan: $e");
      _setError(e);
      return null;
    }
  }

  // ── Update ──

  Future<void> updatePlan({
    required String planId,
    required Map<String, dynamic> updates,
    required Map<String, dynamic> changedFields,
  }) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      await _repository.updatePlan(planId, updates);
      if (changedFields.isNotEmpty) {
        await _repository.logEdit(
          planId: planId,
          editedBy: myUserId,
          changedFields: changedFields,
        );
        // Notify accepted participants of update
        try {
          final invites = await _repository.getInvitesForPlan(planId);
          for (final invite in invites) {
            if (invite['status'] == 'accepted') {
              final inviteeId = invite['invitee_id'] as int;
              if (inviteeId != myUserId) {
                final notePayload = jsonEncode({
                  'plan_id': planId,
                  'changed_fields': changedFields.keys.toList(),
                });
                await _notificationRepository.insertNotification(
                  userId: inviteeId,
                  otherUserId: myUserId,
                  type: 'plan_update',
                  note: notePayload,
                );
              }
            }
          }
        } catch (notifErr) {
          print("Non-fatal error notifying participants of update: $notifErr");
        }
      }

      // Re-schedule reminder if start time changed
      if (updates.containsKey('starts_at')) {
        final newStart = DateTime.parse(updates['starts_at']);
        final title = updates['title'] ?? 'Your Plan';
        await _scheduleReminder(planId, title, newStart);
      }

      await fetchPlans(silent: true);
    } catch (e) {
      print("Error updating plan: $e");
      _setError(e);
    }
  }

  // ── Delete ──

  Future<void> deletePlan(String planId) async {
    try {
      await _cancelReminder(planId);
      await _repository.deletePlan(planId);
      await fetchPlans(silent: true);
    } catch (e) {
      print("Error deleting plan: $e");
      _setError(e);
    }
  }

  // ── Invites ──

  Future<List<Map<String, dynamic>>> getInvitesForPlan(String planId) async {
    try {
      return await _repository.getInvitesForPlan(planId);
    } catch (e) {
      print("Error fetching invites for plan: $e");
      return [];
    }
  }

  Future<void> inviteUser({
    required String planId,
    required int inviteeId,
  }) async {
    final myUserId = _userId;
    if (myUserId == null) return;
    try {
      await _repository.inviteUser(
        planId: planId,
        inviterId: myUserId,
        inviteeId: inviteeId,
      );
      try {
        await _notificationRepository.insertNotification(
          userId: inviteeId,
          otherUserId: myUserId,
          type: 'plan_invite',
          note: planId,
        );
      } catch (notifErr) {
        print("Non-fatal error inserting plan notification: $notifErr");
      }
    } catch (e) {
      print("Error inviting user: $e");
      _setError(e);
    }
  }

  Future<void> respondToInvite({
    required String inviteId,
    required String status,
    String? declineReason,
  }) async {
    try {
      await _repository.respondToInvite(
        inviteId: inviteId,
        status: status,
        declineReason: declineReason,
      );
      await fetchPlans(silent: true);
    } catch (e) {
      print("Error responding to invite: $e");
      _setError(e);
    }
  }

  Future<void> respondToPlanInviteByPlanId({
    required String planId,
    required String status,
    String? declineReason,
  }) async {
    final myUserId = _userId;
    if (myUserId == null) return;
    try {
      final invites = await _repository.getInvitesForPlan(planId);
      final myInvite = invites.firstWhere(
        (i) => i['invitee_id'] == myUserId,
        orElse: () => throw Exception("Invite not found for current user"),
      );
      final inviteId = myInvite['id'] as String;
      await respondToInvite(
        inviteId: inviteId,
        status: status,
        declineReason: declineReason,
      );
    } catch (e) {
      print("Error responding to invite by plan id: $e");
      _setError(e);
    }
  }

  // ── Edits ──

  Future<List<Map<String, dynamic>>> getEditsForPlan(String planId) async {
    try {
      return await _repository.getEditsForPlan(planId);
    } catch (e) {
      print("Error fetching edits for plan: $e");
      return [];
    }
  }

  // ── Plan Detail ──

  Future<Map<String, dynamic>?> getPlanById(String planId) async {
    try {
      return await _repository.getPlanById(planId);
    } catch (e) {
      print("Error fetching plan by id: $e");
      return null;
    }
  }

  // ── Realtime ──

  void _subscribeToRealtime() {
    if (_userId == null) return;
    _unsubscribeFromRealtime();

    _invitesSubscription = _repository.subscribeToPlanInvites(
      _userId!,
      (payload) async {
        print("Realtime plan_invites change: ${payload.toString()}");
        await fetchPlans(silent: true);
      },
    );

    _plansSubscription = _repository.subscribeToPlans(
      _userId!,
      (payload) async {
        print("Realtime plans change: ${payload.toString()}");
        bool shouldRefresh = false;
        if (payload.eventType == PostgresChangeEvent.insert) {
          shouldRefresh = true;
        } else {
          final record = payload.newRecord ?? payload.oldRecord;
          if (record != null) {
            final planId = record['id']?.toString();
            if (planId != null) {
              shouldRefresh = plans.any((p) => p['id'] == planId);
            }
          }
        }
        if (shouldRefresh) {
          await fetchPlans(silent: true);
        }
      },
    );

    _notificationsSubscription = _notificationRepository.subscribeToNotifications(
      _userId!,
      (payload) async {
        print("Realtime notifications change in PlansProvider: ${payload.toString()}");
        if (payload.eventType == PostgresChangeEvent.insert ||
            payload.eventType == PostgresChangeEvent.update) {
          final type = payload.newRecord?['type']?.toString();
          if (type == 'plan_invite' || type == 'plan_update') {
            await fetchPlans(silent: true);
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          // If a plan notification is deleted, the plan itself was likely deleted or cancelled
          await fetchPlans(silent: true);
        }
      },
    );
  }

  void _unsubscribeFromRealtime() {
    if (_invitesSubscription != null) {
      _repository.removeChannel(_invitesSubscription!);
      _invitesSubscription = null;
    }
    if (_plansSubscription != null) {
      _repository.removeChannel(_plansSubscription!);
      _plansSubscription = null;
    }
    if (_notificationsSubscription != null) {
      _repository.removeChannel(_notificationsSubscription!);
      _notificationsSubscription = null;
    }
  }

  // ── Local Reminder Notifications ──

  Future<void> _scheduleReminder(
      String planId, String title, DateTime startsAt) async {
    try {
      final notifId30Min = planId.hashCode.abs() % 0x3FFFFFFF;
      final notifIdStart = (planId.hashCode.abs() % 0x3FFFFFFF) + 0x40000000;

      // Cancel any existing scheduled local reminders for this plan (clean up old state)
      await flutterLocalNotificationsPlugin.cancel(id: notifId30Min);
      await flutterLocalNotificationsPlugin.cancel(id: notifIdStart);
    } catch (e) {
      print("Error canceling local plan reminders: $e");
    }
  }

  Future<void> _cancelReminder(String planId) async {
    try {
      final notifId30Min = planId.hashCode.abs() % 0x3FFFFFFF;
      final notifIdStart = (planId.hashCode.abs() % 0x3FFFFFFF) + 0x40000000;
      await flutterLocalNotificationsPlugin.cancel(id: notifId30Min);
      await flutterLocalNotificationsPlugin.cancel(id: notifIdStart);
    } catch (e) {
      print("Error cancelling plan reminder: $e");
    }
  }

  @override
  void dispose() {
    _unsubscribeFromRealtime();
    super.dispose();
  }
}
