import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/feed_provider.dart';

/// A sleek Discord-style segmented pill toggle that switches between
/// normal chat messaging UI and card-based threads UI.
class DiscordNetworkViewToggle extends StatelessWidget {
  final NetworkViewMode mode;
  final ValueChanged<NetworkViewMode> onChanged;

  const DiscordNetworkViewToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMessages = mode == NetworkViewMode.messages;

    return Container(
      height: 32,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment(
            context: context,
            label: 'Chat',
            icon: Icons.chat_bubble_rounded,
            isSelected: isMessages,
            onTap: () {
              if (!isMessages) {
                HapticFeedback.selectionClick();
                onChanged(NetworkViewMode.messages);
              }
            },
          ),
          _buildSegment(
            context: context,
            label: 'Threads',
            icon: Icons.forum_rounded,
            isSelected: !isMessages,
            onTap: () {
              if (isMessages) {
                HapticFeedback.selectionClick();
                onChanged(NetworkViewMode.threads);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSegment({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? context.accentPrimary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: isSelected
              ? Border.all(
                  color: context.accentPrimary.withValues(alpha: 0.35),
                  width: 1,
                )
              : Border.all(color: Colors.transparent, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? context.accentPrimary : context.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : context.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'Inter',
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
