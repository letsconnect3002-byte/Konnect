import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:linkrunner/linkrunner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Widgets/referral_connection_modal.dart';
import 'package:connect/main.dart';

class LinkrunnerService {
  static const String projectToken = 'Cw0MonxRKFUWAzGARgvmmgVK';
  static const String domain = 'app.joinmandala.in';
  static const String pendingReferrerKey = 'pending_referrer_id';
  static const String pendingInviteCodeKey = 'pending_invite_code';
  static const String pendingProfileTargetKey = 'pending_profile_target';
  static const String processedReferrersKey = 'processed_referrers';
  static const String processedInviteCodesKey = 'processed_invite_codes';

  static String? _inMemoryPendingProfileTarget;

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

  String? _initialUriHandled;

  /// Handles initial deep link on cold launch.
  Future<void> _handleInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[LinkrunnerService] Cold start link: $initialUri');
        _initialUriHandled = initialUri.toString();
        wasColdStartDeepLink = true;
        await _processUri(initialUri);

        final profileTarget = extractProfileTarget(initialUri);
        if (profileTarget != null) {
          debugPrint('[LinkrunnerService] Cold start profile target: $profileTarget');
          await savePendingProfileTarget(profileTarget);
        }
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
        if (_initialUriHandled != null && uri.toString() == _initialUriHandled) {
          _initialUriHandled = null;
          return;
        }
        _initialUriHandled = null;
        debugPrint('[LinkrunnerService] Warm start link: $uri');
        await _processUri(uri);

        final profileTarget = extractProfileTarget(uri);
        final navContext = navigatorKey.currentContext;

        if (profileTarget != null) {
          debugPrint('[LinkrunnerService] Handling warm start profile target: $profileTarget');
          if (navContext != null && navContext.mounted) {
            final session = Supabase.instance.client.auth.currentSession;
            if (session != null) {
              await navigateToProfileTarget(navContext, profileTarget);
              return;
            } else {
              await savePendingProfileTarget(profileTarget);
              return;
            }
          } else {
            await savePendingProfileTarget(profileTarget);
            return;
          }
        }

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
            final target = extractProfileTarget(uri);
            if (target != null) {
              await savePendingProfileTarget(target);
            }
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

  /// Saves pending profile identifier (handle, numeric ID, or UUID) to memory & SharedPreferences.
  static Future<void> savePendingProfileTarget(String target) async {
    final clean = target.trim().replaceFirst(RegExp(r'^@'), '');
    if (clean.isEmpty) return;
    _inMemoryPendingProfileTarget = clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(pendingProfileTargetKey, clean);
      debugPrint('[LinkrunnerService] Saved pending profile target: $clean');
    } catch (e) {
      debugPrint('[LinkrunnerService] Error saving pending profile target: $e');
    }
  }

  /// Gets pending profile target from memory or SharedPreferences.
  static Future<String?> getPendingProfileTarget() async {
    if (_inMemoryPendingProfileTarget != null &&
        _inMemoryPendingProfileTarget!.isNotEmpty) {
      return _inMemoryPendingProfileTarget;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(pendingProfileTargetKey);
      if (val != null && val.isNotEmpty) {
        _inMemoryPendingProfileTarget = val;
        return val;
      }
    } catch (e) {
      debugPrint('[LinkrunnerService] Error getting pending profile target: $e');
    }
    return null;
  }

  /// Clears pending profile target.
  static Future<void> clearPendingProfileTarget() async {
    _inMemoryPendingProfileTarget = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(pendingProfileTargetKey);
      debugPrint('[LinkrunnerService] Cleared pending profile target');
    } catch (_) {}
  }

  /// Gets and clears pending profile target atomically.
  static Future<String?> getAndClearPendingProfileTarget() async {
    final target = await getPendingProfileTarget();
    if (target != null) {
      await clearPendingProfileTarget();
    }
    return target;
  }

  /// Extracts the profile handle or ID from any incoming deep link or web URL:
  /// Examples:
  /// - jana://x/santosh -> santosh
  /// - jana://x/24 -> 24
  /// - jana:///x/santosh -> santosh
  /// - https://joinmandala.in/x/santosh -> santosh
  /// - https://app.joinmandala.in/x/santosh -> santosh
  /// - connectapp://x/santosh -> santosh
  /// - /x/santosh -> santosh
  /// - intent://x/santosh#Intent;... -> santosh
  static String? extractProfileTarget(dynamic link) {
    if (link == null) return null;
    Uri? uri;
    if (link is Uri) {
      uri = link;
    } else if (link is String) {
      final trimmed = link.trim();
      if (trimmed.isEmpty) return null;
      uri = Uri.tryParse(trimmed);
      if (uri == null || (!uri.hasScheme && trimmed.startsWith('/'))) {
        final cleanPath = trimmed.split('?').first;
        final segments =
            cleanPath.split('/').where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty &&
            segments.first.toLowerCase() == 'x' &&
            segments.length > 1) {
          final candidate = segments[1].trim().replaceFirst(RegExp(r'^@'), '');
          return candidate.isNotEmpty ? candidate : null;
        } else if (segments.isNotEmpty && segments.length == 1) {
          final candidate =
              segments.first.trim().replaceFirst(RegExp(r'^@'), '');
          if (candidate.isNotEmpty &&
              candidate != 'login-callback' &&
              !candidate.startsWith('auth') &&
              !candidate.contains('code=')) {
            return candidate;
          }
        }
      }
    }
    if (uri == null) return null;

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final pathSegments = uri.pathSegments;

    // 1. Custom Schemes: jana:// or connectapp://
    if (scheme == 'jana' || scheme == 'connectapp') {
      if (host == 'x') {
        if (pathSegments.isNotEmpty) {
          final target =
              pathSegments.first.trim().replaceFirst(RegExp(r'^@'), '');
          if (target.isNotEmpty) return target;
        }
      } else if (pathSegments.isNotEmpty &&
          pathSegments.first.toLowerCase() == 'x') {
        if (pathSegments.length > 1) {
          final target =
              pathSegments[1].trim().replaceFirst(RegExp(r'^@'), '');
          if (target.isNotEmpty) return target;
        }
      } else if (host.isNotEmpty && host != 'login-callback') {
        final target = host.trim().replaceFirst(RegExp(r'^@'), '');
        if (target.isNotEmpty) return target;
      }
    }

    // 2. HTTP / HTTPS web URLs (joinmandala.in, app.joinmandala.in, etc.)
    if (scheme == 'http' || scheme == 'https') {
      if (pathSegments.isNotEmpty && pathSegments.first.toLowerCase() == 'x') {
        if (pathSegments.length > 1) {
          final target =
              pathSegments[1].trim().replaceFirst(RegExp(r'^@'), '');
          if (target.isNotEmpty) return target;
        }
      }
    }

    // 3. Android Intent URLs (intent://x/[handle]#Intent...)
    if (scheme == 'intent') {
      if (host == 'x' && pathSegments.isNotEmpty) {
        final target =
            pathSegments.first.trim().replaceFirst(RegExp(r'^@'), '');
        if (target.isNotEmpty) return target;
      } else if (pathSegments.isNotEmpty &&
          pathSegments.first.toLowerCase() == 'x') {
        if (pathSegments.length > 1) {
          final target =
              pathSegments[1].trim().replaceFirst(RegExp(r'^@'), '');
          if (target.isNotEmpty) return target;
        }
      }
    }

    return null;
  }

  static String? _navigatingTarget;
  static int _lastNavigatedTimestamp = 0;

  /// Navigates to the profile corresponding to the identifier (handle or id).
  /// Resolves the user from Supabase, checks if it's the current user (isMe),
  /// and opens `YetToBeBuiltProfilePage` or `ConnectionProfilePage`.
  static Future<bool> navigateToProfileTarget(
    BuildContext context,
    String target,
  ) async {
    final clean = target.trim().replaceFirst(RegExp(r'^@'), '');
    if (clean.isEmpty) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (_navigatingTarget == clean && (now - _lastNavigatedTimestamp) < 2000) {
      debugPrint('[LinkrunnerService] Already navigating to $clean, skipping duplicate');
      return true;
    }
    _navigatingTarget = clean;
    _lastNavigatedTimestamp = now;

    try {
      debugPrint('[LinkrunnerService] Navigating to profile target: $clean');

      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final myUserId = profileProvider.userId;
      final currentAuthUserId = Supabase.instance.client.auth.currentUser?.id;

      Map<String, dynamic>? profile;

      // 1. Try finding by numeric id
      final intId = int.tryParse(clean);
      if (intId != null) {
        try {
          final res = await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', intId)
              .maybeSingle();
          if (res != null) {
            profile = Map<String, dynamic>.from(res);
          }
        } catch (e) {
          debugPrint('[LinkrunnerService] Fetch profile by id error: $e');
        }
      }

      // 2. Try finding by handle (case-insensitive)
      if (profile == null) {
        try {
          final res = await Supabase.instance.client
              .from('profiles')
              .select()
              .ilike('handle', clean)
              .maybeSingle();
          if (res != null) {
            profile = Map<String, dynamic>.from(res);
          }
        } catch (e) {
          debugPrint('[LinkrunnerService] Fetch profile by handle error: $e');
        }
      }

      // 3. Try finding by UUID (owner_id)
      if (profile == null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(clean)) {
        try {
          final res = await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('owner_id', clean)
              .maybeSingle();
          if (res != null) {
            profile = Map<String, dynamic>.from(res);
          }
        } catch (e) {
          debugPrint('[LinkrunnerService] Fetch profile by owner_id error: $e');
        }
      }

      if (profile == null) {
        debugPrint('[LinkrunnerService] No profile found in DB for $clean');
        return false;
      }

      if (!context.mounted) return false;

      final profileId = profile['id'];
      final profileOwnerId = profile['owner_id'];

      final bool isMe = (myUserId != null && profileId == myUserId) ||
          (currentAuthUserId != null && profileOwnerId == currentAuthUserId);

      final nav = navigatorKey.currentState;
      if (nav == null) {
        debugPrint('[LinkrunnerService] navigatorKey.currentState is null');
        return false;
      }

      debugPrint(
          '[LinkrunnerService] Target is user $profileId (isMe: $isMe). Pushing ConnectionProfilePage');
      final connProvider =
          Provider.of<ConnectionProvider>(context, listen: false);
      final matchingConn = connProvider.connections.where((c) {
        final cId = c['id'] ?? c['connection_profile_id'] ?? c['user_id'];
        return cId == profileId;
      }).firstOrNull;

      final targetProfileData = matchingConn != null
          ? Map<String, dynamic>.from(matchingConn)
          : {
              'id': profileId,
              'connection_profile_id': profileId,
              ...profile,
            };

      nav.push(
        MaterialPageRoute(
          builder: (_) => ConnectionProfilePage(
            profileData: targetProfileData,
          ),
        ),
      );
      return true;
    } catch (e, stack) {
      debugPrint('[LinkrunnerService] Error navigating to profile: $e\n$stack');
      return false;
    }
  }
}
