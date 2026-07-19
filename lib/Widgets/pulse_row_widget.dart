import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/pulse.dart';
import 'package:connect/Providers/pulse_provider.dart';
import 'package:connect/Widgets/create_pulse_sheet.dart';
import 'package:connect/Widgets/view_pulse_sheet.dart';

class PulseRowWidget extends StatelessWidget {
  const PulseRowWidget({
    super.key,
  });

  String _getEmojiForIcon(String iconName) {
    switch (iconName) {
      case 'briefcase':
        return "💼";
      case 'coffee':
        return "☕";
      case 'flight':
        return "✈️";
      case 'fitness_center':
        return "🏋️";
      case 'school':
        return "🎓";
      case 'groups':
        return "👥";
      case 'chat':
        return "💬";
      case 'person_add':
        return "🙋";
      case 'rate_review':
        return "📝";
      case 'work':
        return "💼";
      case 'help':
        return "ℹ️";
      case 'handshake':
        return "🤝";
      case 'hub':
        return "🌐";
      default:
        return "✨";
    }
  }

  @override
  Widget build(BuildContext context) {
    final pulseProvider = Provider.of<PulseProvider>(context);
    final myPulse = pulseProvider.myPulse;

    final filteredConnectionPulses = pulseProvider.connectionPulses;

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User's Own Pulse
            _buildOwnPulseItem(context, pulseProvider, myPulse),

            // Connection Pulses
            for (var pulse in filteredConnectionPulses) ...[
              const SizedBox(width: 20),
              _buildConnectionPulseItem(context, pulse),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOwnPulseItem(BuildContext context, PulseProvider provider, UserPulse? pulse) {
    final hasPulse = pulse != null && !pulse.isExpired;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (hasPulse) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => ViewPulseSheet(
              pulse: pulse,
              isOwnPulse: true,
            ),
          );
        } else {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => const CreatePulseSheet(),
          );
        }
      },
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                // Avatar
                Container(
                  width: 58,
                  height: 58,
                  margin: const EdgeInsets.only(top: 24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasPulse ? context.accentSecondary : context.surfaceSecondary,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Container(
                      color: context.surfaceSecondary,
                      alignment: Alignment.center,
                      child: hasPulse
                          ? Text(
                              _getEmojiForIcon(pulse.tag?.icon ?? ''),
                              style: const TextStyle(fontSize: 22),
                            )
                          : Icon(
                              Icons.add_rounded,
                              color: context.textSecondary,
                              size: 24,
                            ),
                    ),
                  ),
                ),

                // Note Bubble Floating Above
                Positioned(
                  top: 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: hasPulse
                        ? _buildBubble(
                            text: "${_getEmojiForIcon(pulse.tag?.icon ?? '')} ${pulse.text ?? pulse.tag?.name ?? ''}",
                            context: context,
                          )
                        : _buildBubble(
                            text: "+ Add Pulse",
                            context: context,
                            isPlaceholder: true,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "My Pulse",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionPulseItem(BuildContext context, UserPulse pulse) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => ViewPulseSheet(
            pulse: pulse,
            isOwnPulse: false,
          ),
        );
      },
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                // Avatar
                Container(
                  width: 58,
                  height: 58,
                  margin: const EdgeInsets.only(top: 24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.surfaceSecondary,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: pulse.userAvatarUrl.isNotEmpty
                        ? Image.network(pulse.userAvatarUrl, fit: BoxFit.cover)
                        : Container(
                            color: context.surfaceSecondary,
                            alignment: Alignment.center,
                            child: Text(
                              pulse.userName.isNotEmpty ? pulse.userName[0].toUpperCase() : '',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                  ),
                ),

                // Note Bubble Floating Above
                Positioned(
                  top: 0,
                  child: _buildBubble(
                    text: "${_getEmojiForIcon(pulse.tag?.icon ?? '')} ${pulse.text ?? pulse.tag?.name ?? ''}",
                    context: context,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              pulse.userName.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble({
    required String text,
    required BuildContext context,
    bool isPlaceholder = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      constraints: const BoxConstraints(maxWidth: 80),
      decoration: BoxDecoration(
        color: context.surfaceSecondary.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlaceholder
              ? Colors.white.withValues(alpha: 0.04)
              : context.accentSecondary.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isPlaceholder ? context.textMuted : Colors.white,
          fontSize: 9.5,
          fontWeight: isPlaceholder ? FontWeight.normal : FontWeight.bold,
          height: 1.2,
        ),
      ),
    );
  }
}
