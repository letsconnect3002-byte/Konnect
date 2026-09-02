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
    try {
      Map<String, Object>? sanitizedParams;
      if (parameters != null) {
        sanitizedParams = parameters.map((key, value) {
          if (value is String || value is num) {
            return MapEntry(key, value);
          } else if (value is bool) {
            return MapEntry(key, value ? 'true' : 'false');
          } else {
            return MapEntry(key, value.toString());
          }
        });
      }
      await _analytics.logEvent(name: name, parameters: sanitizedParams);
    } catch (_) {}
  }
}
