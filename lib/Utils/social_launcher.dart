import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialLauncher {
  /// Resolves the social media handle or URL dynamically.
  /// Handles full URLs, @handles, and raw usernames.
  static String getSocialUrl(String platform, String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    String username = trimmed;
    if (username.startsWith('@')) {
      username = username.substring(1);
    }

    switch (platform.toLowerCase()) {
      case 'linkedin':
        return 'https://linkedin.com/in/$username';
      case 'twitter':
      case 'x':
        return 'https://x.com/$username';
      case 'instagram':
        return 'https://instagram.com/$username';
      case 'spotify':
        if (username.contains('spotify.com')) return username;
        return 'https://open.spotify.com/user/$username';
      default:
        return username;
    }
  }

  /// Resolves and launches the social link in an external application.
  static Future<void> launchSocialLink(
      BuildContext context, String platform, String input) async {
    final url = getSocialUrl(platform, input);
    if (url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch $url'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      print("Error launching social link: $e");
    }
  }
}
