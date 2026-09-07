import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/resume_models.dart';
import 'package:connect/Utils/social_launcher.dart';
import 'package:share_plus/share_plus.dart';

/// Interactive Share Bar for the user's public resume link.
class PublicResumeShareBar extends StatelessWidget {
  final int? userId;

  const PublicResumeShareBar({super.key, required this.userId});

  String get resumeUrl {
    final idStr = userId?.toString() ?? '';
    return 'joinmandala.in/$idStr';
  }

  String get fullResumeUrl {
    final idStr = userId?.toString() ?? '';
    return 'https://joinmandala.in/$idStr';
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.accentPrimary.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: context.accentPrimary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.accentPrimary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.link_rounded,
              size: 18,
              color: context.accentPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PUBLIC RESUME LINK',
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  resumeUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Copy Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Clipboard.setData(ClipboardData(text: fullResumeUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied link: $resumeUrl'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: context.surfacePrimary,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.surfaceSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded,
                      size: 13, color: context.accentPrimary),
                  const SizedBox(width: 4),
                  Text(
                    'Copy',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Share Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              SharePlus.instance.share(
                ShareParams(
                  text: 'View my professional resume on Mandala: $fullResumeUrl',
                  subject: 'My Professional Resume on Mandala',
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: context.accentPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.share_outlined,
                size: 14,
                color: context.accentPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// LinkedIn-style Experience Timeline Section
class ExperienceTimelineSection extends StatelessWidget {
  final List<ExperienceItem> experience;
  final bool isOwner;
  final VoidCallback? onAdd;
  final Function(ExperienceItem item)? onEdit;

  const ExperienceTimelineSection({
    super.key,
    required this.experience,
    this.isOwner = false,
    this.onAdd,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwner && experience.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'EXPERIENCE',
              style: context.captionText.copyWith(
                color: context.textSecondary,
                fontSize: 14.0,
                letterSpacing: 1.5,
              ),
            ),
            if (isOwner && onAdd != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAdd!();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.surfacePrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.accentPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: context.accentPrimary),
                      const SizedBox(width: 3),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: context.accentPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        if (experience.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.work_outline_rounded,
                      size: 28, color: context.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    isOwner
                        ? 'Add your work experience to build your interactive resume.'
                        : 'No work experience added yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  if (isOwner) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onAdd?.call();
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Position'),
                      style: TextButton.styleFrom(
                        foregroundColor: context.accentPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: experience.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.white.withValues(alpha: 0.08),
              height: 20,
              thickness: 0.8,
            ),
            itemBuilder: (context, index) {
              final item = experience[index];
              return _ExperienceTimelineCard(
                item: item,
                isOwner: isOwner,
                onEdit: onEdit != null ? () => onEdit!(item) : null,
              );
            },
          ),
      ],
    );
  }
}

class _ExperienceTimelineCard extends StatefulWidget {
  final ExperienceItem item;
  final bool isOwner;
  final VoidCallback? onEdit;

  const _ExperienceTimelineCard({
    required this.item,
    required this.isOwner,
    this.onEdit,
  });

  @override
  State<_ExperienceTimelineCard> createState() =>
      _ExperienceTimelineCardState();
}

class _ExperienceTimelineCardState extends State<_ExperienceTimelineCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasLogo = item.companyLogoUrl.isNotEmpty;
    final hasUrl = item.companyUrl.trim().isNotEmpty;
    final hasDesc = item.description.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company Logo / Brand Avatar
          GestureDetector(
            onTap: hasUrl
                ? () {
                    HapticFeedback.lightImpact();
                    SocialLauncher.openUrl(context, item.companyUrl);
                  }
                : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              alignment: Alignment.center,
              child: hasLogo
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.companyLogoUrl,
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Text(
                          item.company.isNotEmpty
                              ? item.company[0].toUpperCase()
                              : '💼',
                          style: TextStyle(
                            color: context.accentPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      item.company.isNotEmpty
                          ? item.company[0].toUpperCase()
                          : '💼',
                      style: TextStyle(
                        color: context.accentPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Role Title + Optional Edit Icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    if (widget.isOwner && widget.onEdit != null)
                      GestureDetector(
                        onTap: widget.onEdit,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),

                // Company Name (with clickable link if URL exists)
                GestureDetector(
                  onTap: hasUrl
                      ? () {
                          HapticFeedback.lightImpact();
                          SocialLauncher.openUrl(context, item.companyUrl);
                        }
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.company,
                        style: TextStyle(
                          color: hasUrl
                              ? context.accentPrimary
                              : context.textSecondary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasUrl) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 12,
                          color: context.accentPrimary,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Dates & Location
                Row(
                  children: [
                    if (item.startDate.isNotEmpty || item.endDate.isNotEmpty)
                      Text(
                        '${item.startDate.isNotEmpty ? item.startDate : ''}'
                        '${item.endDate.isNotEmpty ? ' – ${item.endDate}' : ''}',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      ),
                    if (item.location.isNotEmpty) ...[
                      Text(' · ',
                          style: TextStyle(color: context.textMuted, fontSize: 12)),
                      Flexible(
                        child: Text(
                          item.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Description (with Expand / Collapse)
                if (hasDesc) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    maxLines: _isExpanded ? null : 2,
                    overflow:
                        _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                      fontFamily: 'Inter',
                    ),
                  ),
                  if (item.description.length > 80)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _isExpanded ? 'Show less ▴' : 'Read more ▾',
                          style: TextStyle(
                            color: context.accentPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Education Section
class EducationSection extends StatelessWidget {
  final List<EducationItem> education;
  final bool isOwner;
  final VoidCallback? onAdd;
  final Function(EducationItem item)? onEdit;

  const EducationSection({
    super.key,
    required this.education,
    this.isOwner = false,
    this.onAdd,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwner && education.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'EDUCATION',
              style: context.captionText.copyWith(
                color: context.textSecondary,
                fontSize: 14.0,
                letterSpacing: 1.5,
              ),
            ),
            if (isOwner && onAdd != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAdd!();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.surfacePrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.accentPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: context.accentPrimary),
                      const SizedBox(width: 3),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: context.accentPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        if (education.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.school_outlined, size: 28, color: context.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    isOwner
                        ? 'Add your education or academic background.'
                        : 'No education details added yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  if (isOwner) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onAdd?.call();
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Education'),
                      style: TextButton.styleFrom(
                        foregroundColor: context.accentPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: education.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.white.withValues(alpha: 0.08),
              height: 20,
              thickness: 0.8,
            ),
            itemBuilder: (context, index) {
              final item = education[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: context.accentSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.school,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isOwner && onEdit != null)
                                GestureDetector(
                                  onTap: () => onEdit!(item),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                    color: context.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          if (item.degree.isNotEmpty ||
                              item.fieldOfStudy.isNotEmpty)
                            Text(
                              '${item.degree}'
                              '${item.degree.isNotEmpty && item.fieldOfStudy.isNotEmpty ? ' in ' : ''}'
                              '${item.fieldOfStudy}',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          if (item.startYear.isNotEmpty ||
                              item.endYear.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${item.startYear}'
                                '${item.endYear.isNotEmpty ? ' – ${item.endYear}' : ''}',
                                style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (item.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                item.description,
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12.5,
                                  height: 1.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Skills Section
class SkillsSection extends StatelessWidget {
  final List<String> skills;
  final bool isOwner;
  final VoidCallback? onEdit;

  const SkillsSection({
    super.key,
    required this.skills,
    this.isOwner = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwner && skills.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SKILLS & SUPERPOWERS',
              style: context.captionText.copyWith(
                color: context.textSecondary,
                fontSize: 14.0,
                letterSpacing: 1.5,
              ),
            ),
            if (isOwner && onEdit != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onEdit!();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.surfacePrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.accentPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(skills.isEmpty ? Icons.add : Icons.edit_outlined,
                          size: 13, color: context.accentPrimary),
                      const SizedBox(width: 3),
                      Text(
                        skills.isEmpty ? 'Add' : 'Edit',
                        style: TextStyle(
                          color: context.accentPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (skills.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: context.surfacePrimary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Center(
              child: Text(
                isOwner
                    ? 'Add skills and expertise to highlight your superpowers.'
                    : 'No skills added yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills.map((skill) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: context.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.accentPrimary.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Text(
                  skill,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
