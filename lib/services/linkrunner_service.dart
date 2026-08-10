import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:linkrunner/linkrunner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/Widgets/referral_connection_modal.dart';
import 'package:connect/main.dart';

class LinkrunnerService {
  static const String projectToken = 'Cw0MonxRKFUWAzGARgvmmgVK';
  static const String domain = 'app.joinmandala.in';
  static const String pendingReferrerKey = 'pending_referrer_id';
  static const String pendingInviteCodeKey = 'pending_invite_code';
  static const String processedReferrersKey = 'processed_referrers';
  static const String processedInviteCodesKey = 'processed_invite_codes';

  static final LinkrunnerService _instance = LinkrunnerService._internal();
  factory LinkrunnerService() => _instance;
  LinkrunnerService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// Initializes Linkrunner SDK and sets up deep link listeners.
  static Future<void> initialize() async {
    try {
      await LinkRunner().init(projectToken, null, null, true);
      debugPrint('[LinkrunnerService] Initialized with token: $projectToken');
    } catch (e) {
      debugPrint('[LinkrunnerService] Init error: $e');
    }

    // Set up deep link listening
    final instance = LinkrunnerService();
    await instance._handleInitialLink();
    instance._listenToDeepLinks();
    await instance._checkAttributionData();
  }

  static bool wasColdStartDeepLink = false;

  static bool consumeWasColdStartDeepLink() {
    final bool val = wasColdStartDeepLink;
    wasColdStartDeepLink = false;
    return val;
  }

  /// Handles initial deep link on cold launch.
  Future<void> _handleInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[LinkrunnerService] Cold start link: $initialUri');
        wasColdStartDeepLink = true;
        await _processUri(initialUri);
      }
    } catch (e) {
      debugPrint('[LinkrunnerService] Error getting initial link: $e');
    }
  }

  /// Listens to incoming deep links while app is open / backgrounded.
  void _listenToDeepLinks() {
    _linkSubscription?.cancel();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        debugPrint('[LinkrunnerService] Warm start link: $uri');
        await _processUri(uri);
        final navContext = navigatorKey.currentContext;
        if (navContext != null && navContext.mounted) {
          await ReferralConnectionModal.checkAndShowPrompt(
            navContext,
            isExplicitLinkClick: true,
          );
        }
      },
      onError: (err) {
        debugPrint('[LinkrunnerService] Link stream error: $err');
      },
    );
  }

  /// Queries Linkrunner attribution data for deferred deep linking.
  Future<void> _checkAttributionData() async {
    try {
      final attributionData = await LinkRunner().getAttributionData();
      debugPrint('[LinkrunnerService] Attribution data: $attributionData');
      if (attributionData != null) {
        final String? deeplinkStr = attributionData.deeplink;
        if (deeplinkStr != null && deeplinkStr.isNotEmpty) {
          final uri = Uri.tryParse(deeplinkStr);
          if (uri != null) {
            await _extractAndSaveParams(uri);
          }
        }
      }
    } catch (e) {
      debugPrint('[LinkrunnerService] Attribution error: $e');
    }
  }

  /// Processes an incoming URI and extracts `referrer` and `code` parameters.
  Future<void> _processUri(Uri uri) async {
    try {
      LinkRunner().handleDeeplink(uri.toString());
    } catch (e) {
      debugPrint('[LinkrunnerService] handleDeeplink error: $e');
    }

    await _extractAndSaveParams(uri);
  }

  /// Extracts referrer and invite code parameters from URI and saves to SharedPreferences.
  /// Always saves so that checkAndShowPrompt can evaluate the data.
  Future<void> _extractAndSaveParams(Uri uri) async {
    final String? referrer = uri.queryParameters['referrer'] ??
        uri.queryParameters['referrer_id'] ??
        uri.queryParameters['sender_id'];

    final String? code = uri.queryParameters['invite_code'] ??
        uri.queryParameters['code'] ??
        uri.queryParameters['key'] ??
        uri.queryParameters['private_key'];

    if (referrer != null && referrer.isNotEmpty) {
      debugPrint('[LinkrunnerService] Extracted referrer: $referrer');
      await savePendingReferrerId(referrer);
    }

    if (code != null && code.isNotEmpty) {
      debugPrint('[LinkrunnerService] Extracted invite code: $code');
      await savePendingInviteCode(code);
    }
  }

  /// Helper to generate friction-free share link containing both referrer ID and Private Key code.
  static String generateInviteLink({
    required dynamic senderUserId,
    String? inviteCode,
  }) {
    if (inviteCode != null && inviteCode.isNotEmpty) {
      return 'https://$domain/?referrer=$senderUserId&invite_code=$inviteCode';
    }
    return 'https://$domain/?referrer=$senderUserId';
  }

  /// Saves pending referrer ID to SharedPreferences.
  static Future<void> savePendingReferrerId(String referrerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingReferrerKey, referrerId);
    debugPrint('[LinkrunnerService] Saved pending referrer ID: $referrerId');
  }

  /// Saves pending invite code / private key to SharedPreferences.
  static Future<void> savePendingInviteCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingInviteCodeKey, code);
    debugPrint('[LinkrunnerService] Saved pending invite code: $code');
  }

  /// Gets pending referrer ID from SharedPreferences.
  static Future<String?> getPendingReferrerId() async {
    final prefs = await SharedPreferences.getInstance();
    final String? id = prefs.getString(pendingReferrerKey);
    return (id != null && id.isNotEmpty) ? id : null;
  }

  /// Gets pending invite code / private key from SharedPreferences.
  static Future<String?> getPendingInviteCode() async {
    final prefs = await SharedPreferences.getInstance();
    final String? code = prefs.getString(pendingInviteCodeKey);
    return (code != null && code.isNotEmpty) ? code : null;
  }

  static Future<void> clearPendingReferralData() async {
    wasColdStartDeepLink = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingReferrerKey);
    await prefs.remove(pendingInviteCodeKey);
    debugPrint('[LinkrunnerService] Cleared pending referral data');
  }

  /// Marks a referrer ID as actioned/processed so it will not re-trigger on subsequent app launches.
  static Future<void> markReferrerAsProcessed(String referrerId, {String? inviteCode}) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> processed = prefs.getStringList(processedReferrersKey) ?? [];
    if (!processed.contains(referrerId)) {
      processed.add(referrerId);
      await prefs.setStringList(processedReferrersKey, processed);
    }
    // Also mark the invite code as processed if provided
    if (inviteCode != null && inviteCode.isNotEmpty) {
      await markInviteCodeAsProcessed(inviteCode);
    }
    await clearPendingReferralData();
    debugPrint('[LinkrunnerService] Marked referrer $referrerId as processed');
  }

  /// Checks if a referrer ID has already been actioned/processed.
  static Future<bool> isReferrerProcessed(String referrerId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> processed = prefs.getStringList(processedReferrersKey) ?? [];
    return processed.contains(referrerId);
  }

  /// Marks an invite code as processed so it will not re-trigger on subsequent app launches.
  static Future<void> markInviteCodeAsProcessed(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> processed = prefs.getStringList(processedInviteCodesKey) ?? [];
    final normalized = code.trim().toUpperCase();
    if (!processed.contains(normalized)) {
      processed.add(normalized);
      await prefs.setStringList(processedInviteCodesKey, processed);
    }
    debugPrint('[LinkrunnerService] Marked invite code $normalized as processed');
  }

  /// Checks if an invite code has already been processed.
  static Future<bool> isInviteCodeProcessed(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> processed = prefs.getStringList(processedInviteCodesKey) ?? [];
    return processed.contains(code.trim().toUpperCase());
  }

  /// Alias for clearPendingReferralData for backward compatibility.
  static Future<void> clearPendingReferrerId() => clearPendingReferralData();
}
