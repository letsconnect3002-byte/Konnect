import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/profile_provider.dart';

/// Minimalist, Apple-inspired guide sheet explaining:
/// 1. Connections (1st Degree)
/// 2. Your Network (Multi-Degree Trust Graph)
/// 3. Circles / Sub-Networks (Private Spaces)
class NetworkGuideSheet extends StatelessWidget {
  const NetworkGuideSheet({super.key});

  static Future<void> show(BuildContext context, {bool markAsSeen = true}) async {
    HapticFeedback.lightImpact();
    if (markAsSeen) {
      try {
        final profile = Provider.of<ProfileProvider>(context, listen: false);
        if (!profile.hasSeenNetworkGuide) {
          profile.setHasSeenNetworkGuide(true);
        }
      } catch (_) {}
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NetworkGuideSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E17).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 14,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "How Jana Works",
                      style: context.screenHeading.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "A private trust network built on verified relationships.",
                      style: context.bodyText.copyWith(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white70),
                style: IconButton.styleFrom(
                  backgroundColor: context.surfacePrimary,
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Pillar 1: Connections
          _buildPillarRow(
            context,
            icon: Icons.handshake_rounded,
            iconColor: context.accentPrimary,
            title: "1. Direct Connections (1st Degree)",
            description:
                "People you know personally. Connect in person via QR code or send a private invite pass. Zero cold messages from strangers.",
          ),
          const SizedBox(height: 18),

          // Pillar 2: The Trust Network
          _buildPillarRow(
            context,
            icon: Icons.hub_rounded,
            iconColor: const Color(0xFF60A5FA),
            title: "2. Your Network (Trust Graph)",
            description:
                "Every connection links you to their trusted circle (2nd degree). Reach new peers through curated, warm introductions.",
          ),
          const SizedBox(height: 18),

          // Pillar 3: Circles
          _buildPillarRow(
            context,
            icon: Icons.groups_rounded,
            iconColor: const Color(0xFFA78BFA),
            title: "3. Circles (Sub-Networks)",
            description:
                "Create private group spaces for your team, company alumni, or cohort. Invite members directly from your trust network.",
          ),
          const SizedBox(height: 28),

          // Dismiss Button
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              try {
                final profile = Provider.of<ProfileProvider>(context, listen: false);
                if (!profile.hasSeenNetworkGuide) {
                  profile.setHasSeenNetworkGuide(true);
                }
              } catch (_) {}
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Got It",
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
