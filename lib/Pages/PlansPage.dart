import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/plans_provider.dart';

import 'package:connect/Pages/PlanDetailPage.dart';
import 'package:connect/Widgets/create_plan_sheet.dart';
import 'package:skeletonizer/skeletonizer.dart';

class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<PlansProvider>(context, listen: false).fetchPlans();
      }
    });
  }

  Future<void> _handleRefresh() async {
    await Provider.of<PlansProvider>(context, listen: false)
        .fetchPlans(silent: true);
  }

  void _openCreatePlanSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreatePlanSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Consumer<PlansProvider>(
                builder: (context, provider, _) {
                  final state = provider.state;

                  if (state is PlansLoading) {
                    return _buildSkeleton();
                  }

                  final plans = provider.plans;
                  if (plans.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildPlansList(plans);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Plans', style: AppTypography.displayHeader),
          GestureDetector(
            onTap: _openCreatePlanSheet,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: 3,
        itemBuilder: (ctx, i) => _buildSkeletonCard(),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
        border: Border.all(color: AppColors.borderMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 160, height: 18, color: Colors.white),
          const SizedBox(height: 8),
          Container(width: 120, height: 14, color: Colors.white),
          const SizedBox(height: 8),
          Container(width: 80, height: 14, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.accentPrimary,
      backgroundColor: AppColors.surfacePrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 64,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  'No upcoming plans',
                  style: AppTypography.cardTitle
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to create one',
                  style: AppTypography.bodyText
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlansList(List<Map<String, dynamic>> plans) {
    // Group plans by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final plan in plans) {
      final startsAt = DateTime.tryParse(plan['starts_at'] ?? '')?.toLocal();
      if (startsAt == null) continue;
      final key = _dateGroupKey(startsAt);
      grouped.putIfAbsent(key, () => []).add(plan);
    }

    final sortedKeys = grouped.keys.toList();

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.accentPrimary,
      backgroundColor: AppColors.surfacePrimary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        itemCount: sortedKeys.length,
        itemBuilder: (ctx, i) {
          final key = sortedKeys[i];
          final datePlans = grouped[key]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  key.toUpperCase(),
                  style: AppTypography.captionText.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              ...datePlans.map((plan) => _buildPlanCard(plan)),
            ],
          );
        },
      ),
    );
  }

  String _dateGroupKey(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final planDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = planDate.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 7) {
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      return days[dateTime.weekday - 1];
    }
    return '${_monthName(dateTime.month)} ${dateTime.day}';
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final category = plan['category'] as String? ?? 'other';
    final title = plan['title'] as String? ?? 'Untitled';
    final startsAt = DateTime.tryParse(plan['starts_at'] ?? '')?.toLocal();
    final endsAt = plan['ends_at'] != null
        ? DateTime.tryParse(plan['ends_at'])?.toLocal()
        : null;
    final location = plan['location'] as String?;
    final isOnline = plan['is_online'] == true;
    final planType = plan['plan_type'] as String? ?? 'casual';
    final myStatus = plan['my_status'] as String? ?? '';

    // Check if plan is happening now
    final now = DateTime.now();
    final isLive = startsAt != null &&
        startsAt.isBefore(now) &&
        (endsAt == null || endsAt.isAfter(now));

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlanDetailPage(planId: plan['id'] as String),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfacePrimary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          border: Border.all(
            color: isLive
                ? AppColors.accentPrimary.withValues(alpha: 0.5)
                : AppColors.borderMuted,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Text(categoryEmoji(category), style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'LIVE',
                      style: AppTypography.captionText.copyWith(
                        color: const Color(0xFF22C55E),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Time + location
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  _formatTime(startsAt),
                  style: AppTypography.bodyText
                      .copyWith(color: AppColors.textSecondary, fontSize: 13),
                ),
                if (location != null && location.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: AppTypography.bodyText.copyWith(
                          color: AppColors.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else if (isOnline) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.videocam_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Online',
                    style: AppTypography.bodyText
                        .copyWith(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // Bottom row: plan type + status
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: planType == 'professional'
                        ? AppColors.accentPrimary.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    planType == 'professional' ? 'Professional' : 'Casual',
                    style: AppTypography.captionText.copyWith(
                      color: planType == 'professional'
                          ? AppColors.accentPrimary
                          : AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Spacer(),
                if (myStatus == 'pending')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Invited',
                      style: AppTypography.captionText.copyWith(
                        color: const Color(0xFFF59E0B),
                        fontSize: 10,
                      ),
                    ),
                  ),
                if (myStatus == 'creator')
                  Text(
                    'Created by you',
                    style: AppTypography.captionText.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            // Live progress bar
            if (isLive && endsAt != null) ...[
              const SizedBox(height: 10),
              _buildProgressBar(startsAt, endsAt),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(DateTime start, DateTime end) {
    final now = DateTime.now();
    final total = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    final progress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 3,
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        valueColor:
            const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
      ),
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }
}
