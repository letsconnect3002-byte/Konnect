import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> setUserId(String? id) async {
    await _analytics.setUserId(id: id);
  }

  static Future<void> setUserProperties({
    required int connectionCount,
    required int profileCompletionPct,
  }) async {
    await _analytics.setUserProperty(
      name: 'connection_count',
      value: connectionCount.toString(),
    );
    await _analytics.setUserProperty(
      name: 'profile_completion_pct',
      value: profileCompletionPct.toString(),
    );
  }

  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }
}
