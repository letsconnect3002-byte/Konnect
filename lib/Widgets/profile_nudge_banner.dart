import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/profile_provider.dart';

class ProfileNudgeBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onOpenProfile;

  const ProfileNudgeBanner({
    super.key,
    required this.onDismiss,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    if (!profileProvider.shouldShowProfileNudge) {
      return const SizedBox.shrink();
    }

    final missing = profileProvider.missingEssentialFields;
    final missingText = missing.join(', ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onOpenProfile();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.accentSecondary.withValues(alpha: 0.16),
                context.surfaceSecondary.withValues(alpha: 0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.accentSecondary.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon Badge
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.accentSecondary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.accentSecondary.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: context.accentSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Complete Your Profile",
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: context.accentSecondary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "${4 - missing.length}/4",
                            style: TextStyle(
                              color: context.accentSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2.5),
                    Text(
                      "Add: $missingText",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Arrow & Close Button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: context.textSecondary,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.textSecondary,
                      size: 18,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      profileProvider.dismissProfileNudge();
                      onDismiss();
                    },
                    tooltip: "Dismiss for 2 days",
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
