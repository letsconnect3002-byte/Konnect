import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connect/main.dart';
import 'package:connect/Providers/LocalDatabaseHelper.dart';
import 'package:connect/Providers/profile_provider.dart';

class MonkModeProvider with ChangeNotifier {
  ProfileProvider? _profileProvider;

  bool _enabled = false;
  DateTime? _deactivateAt;
  List<int> _blockedIds = [];
  int _selectedDurationIndex = 5;
  int? _customDurationMinutes;
  Timer? _deactivateTimer;
  bool _initialized = false;
  int? _lastSyncedProfileId;
  bool _deactivatedAutomatically = false;

  bool get enabled => _enabled;
  DateTime? get deactivateAt => _deactivateAt;
  List<int> get blockedIds => _blockedIds;
  int get selectedDurationIndex => _selectedDurationIndex;
  int? get customDurationMinutes => _customDurationMinutes;
  bool get initialized => _initialized;
  bool get deactivatedAutomatically => _deactivatedAutomatically;

  MonkModeProvider() {
    loadSettings();
  }

  void updateProfileProvider(ProfileProvider profileProvider) {
    _profileProvider = profileProvider;
    if (profileProvider.userId != null && profileProvider.state is ProfileLoaded) {
      _syncFromProfileProvider(profileProvider);
    }
  }

  void clearDeactivatedAutomatically() {
    _deactivatedAutomatically = false;
  }

  Future<void> loadSettings() async {
    try {
      final userIdVal = _profileProvider?.userId ?? await LocalDatabaseHelper.instance.getActiveUserId();
      if (userIdVal == null) return;
      final settings = await LocalDatabaseHelper.instance.getMonkModeSettings(userIdVal);
      _enabled = settings['enabled'] as bool? ?? false;
      final String? deactivateAtStr = settings['deactivate_at'] as String?;
      _deactivateAt = deactivateAtStr != null ? DateTime.tryParse(deactivateAtStr)?.toLocal() : null;
      _blockedIds = List<int>.from(settings['blocked_ids'] as List? ?? []);

      final prefs = await SharedPreferences.getInstance();
      _selectedDurationIndex = prefs.getInt('monk_mode_selected_duration_index') ?? 5;
      _customDurationMinutes = prefs.getInt('monk_mode_custom_duration_minutes');

      // Check if expired
      if (_enabled && _deactivateAt != null) {
        if (DateTime.now().isAfter(_deactivateAt!)) {
          _enabled = false;
          _deactivateAt = null;
          await _saveToLocalDb();
        } else {
          _startDeactivateTimer();
        }
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      print("Error loading monk mode settings in provider: $e");
    }
  }

  void _syncFromProfileProvider(ProfileProvider profileProvider) async {
    final int profileId = profileProvider.userId!;
    if (_lastSyncedProfileId == profileId) return;
    _lastSyncedProfileId = profileId;

    final profileData = profileProvider.getMonkModeData();
    if (profileData != null) {
      _enabled = profileData['enabled'] as bool;
      _deactivateAt = profileData['deactivate_at'] as DateTime?;
      _blockedIds = profileData['blocked_ids'] as List<int>;

      await _saveToLocalDb();

      if (_enabled && _deactivateAt != null) {
        if (DateTime.now().isAfter(_deactivateAt!)) {
          _enabled = false;
          _deactivateAt = null;
          await _saveToLocalDb();
          _syncToSupabase();
        } else {
          _startDeactivateTimer();
          await _scheduleDeactivationNotification(_deactivateAt!);
        }
      } else {
        _deactivateTimer?.cancel();
        await _cancelScheduledDeactivationNotification();
      }
      notifyListeners();
    }
  }

  void _startDeactivateTimer() {
    _deactivateTimer?.cancel();
    if (!_enabled || _deactivateAt == null) return;
    final diff = _deactivateAt!.difference(DateTime.now());
    if (diff.isNegative) {
      deactivateMonkMode(automatic: true);
    } else {
      _deactivateTimer = Timer(diff, () {
        deactivateMonkMode(automatic: true);
      });
    }
  }

  Future<void> setMonkMode({
    required bool enabled,
    DateTime? deactivateAt,
    int? selectedDurationIndex,
    int? customDurationMinutes,
  }) async {
    _enabled = enabled;
    _deactivateAt = deactivateAt;

    final prefs = await SharedPreferences.getInstance();
    if (selectedDurationIndex != null) {
      _selectedDurationIndex = selectedDurationIndex;
      await prefs.setInt('monk_mode_selected_duration_index', selectedDurationIndex);
    }
    if (customDurationMinutes != null) {
      _customDurationMinutes = customDurationMinutes;
      await prefs.setInt('monk_mode_custom_duration_minutes', customDurationMinutes);
    } else if (selectedDurationIndex != null && selectedDurationIndex != 4) {
      _customDurationMinutes = null;
      await prefs.remove('monk_mode_custom_duration_minutes');
    }

    if (_enabled) {
      _startDeactivateTimer();
      if (_deactivateAt != null) {
        await _scheduleDeactivationNotification(_deactivateAt!);
      }
    } else {
      _deactivateTimer?.cancel();
      _deactivateAt = null;
      await _cancelScheduledDeactivationNotification();
    }

    await _saveToLocalDb();
    _syncToSupabase();
    notifyListeners();
  }

  Future<void> toggleUserBlock(int userId, bool block) async {
    if (block) {
      if (!_blockedIds.contains(userId)) {
        _blockedIds.add(userId);
      }
    } else {
      _blockedIds.remove(userId);
    }
    await _saveToLocalDb();
    _syncToSupabase();
    notifyListeners();
  }

  Future<void> muteAll(List<int> userIds) async {
    for (final id in userIds) {
      if (!_blockedIds.contains(id)) {
        _blockedIds.add(id);
      }
    }
    await _saveToLocalDb();
    _syncToSupabase();
    notifyListeners();
  }

  Future<void> allowAll() async {
    _blockedIds.clear();
    await _saveToLocalDb();
    _syncToSupabase();
    notifyListeners();
  }

  Future<void> deactivateMonkMode({bool automatic = false}) async {
    _enabled = false;
    _deactivateAt = null;
    _deactivateTimer?.cancel();
    _deactivatedAutomatically = automatic;
    await _cancelScheduledDeactivationNotification();
    await _saveToLocalDb();
    _syncToSupabase();
    notifyListeners();
  }

  Future<void> _saveToLocalDb() async {
    final userIdVal = _profileProvider?.userId ?? await LocalDatabaseHelper.instance.getActiveUserId();
    if (userIdVal == null) return;
    await LocalDatabaseHelper.instance.updateMonkMode(
      userId: userIdVal,
      enabled: _enabled,
      deactivateAt: _deactivateAt?.toUtc().toIso8601String(),
      blockedIds: _blockedIds,
    );
  }

  Future<void> _syncToSupabase() async {
    final userId = _profileProvider?.userId;
    if (userId == null) return;
    try {
      _profileProvider!.monkModeEnabled = _enabled;
      _profileProvider!.monkModeDeactivateAt = _deactivateAt?.toUtc().toIso8601String();
      _profileProvider!.monkModeBlockedIds = _blockedIds;

      await _profileProvider!.saveOrUpdateProfile();
      print("Monk Mode synced silently to Supabase.");
    } catch (e) {
      print("Error syncing Monk Mode to Supabase: $e");
    }
  }

  static const int _monkModeNotificationId = 888888;

  Future<void> _scheduleDeactivationNotification(DateTime deactivateAt) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'monk_mode_channel',
        'Monk Mode Alerts',
        channelDescription: 'Alerts for Monk Mode state changes',
        importance: Importance.max,
        priority: Priority.high,
      );
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _cancelScheduledDeactivationNotification();

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: _monkModeNotificationId,
        title: 'Monk Mode',
        body: 'Monk Mode deactivated automatically. You are back in the loop!',
        scheduledDate: tz.TZDateTime.from(deactivateAt, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print("Scheduled Monk Mode deactivation alert at $deactivateAt");
    } catch (e) {
      print("Error scheduling Monk Mode notification: $e");
    }
  }

  Future<void> _cancelScheduledDeactivationNotification() async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id: _monkModeNotificationId);
      print("Cancelled scheduled Monk Mode deactivation alert.");
    } catch (e) {
      print("Error cancelling Monk Mode notification: $e");
    }
  }

  @override
  void dispose() {
    _deactivateTimer?.cancel();
    super.dispose();
  }
}
