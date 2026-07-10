import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/plans_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Widgets/create_plan_sheet.dart';

class PlanDetailPage extends StatefulWidget {
  final String planId;
  const PlanDetailPage({super.key, required this.planId});

  @override
  State<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<PlanDetailPage> {
  Map<String, dynamic>? _plan;
  List<Map<String, dynamic>> _invites = [];
  List<Map<String, dynamic>> _edits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = Provider.of<PlansProvider>(context, listen: false);
    final plan = await provider.getPlanById(widget.planId);
    final invites = await provider.getInvitesForPlan(widget.planId);
    final edits = await provider.getEditsForPlan(widget.planId);
    if (mounted) {
      setState(() {
        _plan = plan;
        _invites = invites;
        _edits = edits;
        _loading = false;
      });
    }
  }

  void _openEditSheet() {
    if (_plan == null) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreatePlanSheet(existingPlan: _plan),
    ).then((_) => _loadData());
  }

  void _showInviteConnectionsSheet() {
    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    final plansProvider = Provider.of<PlansProvider>(context, listen: false);
    final connections = connectionProvider.connections;

    // Filter out already invited users
    final invitedIds =
        _invites.map((i) => i['invitee_id'] as int).toSet();
    final creatorId = _plan?['creator_id'] as int?;
    final available = connections.where((c) {
      final otherId = c['id'] as int?;
      return otherId != null &&
          !invitedIds.contains(otherId) &&
          otherId != creatorId;
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        if (available.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(
                'All your connections are already invited',
                style: AppTypography.bodyText
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          itemCount: available.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('Invite Connections',
                    style: AppTypography.screenHeading),
              );
            }
            final conn = available[i - 1];
            final name = conn['name'] as String? ?? 'Unknown';
            final avatarUrl = conn['avatarUrl'] as String? ?? conn['avatar_url'] as String?;
            final otherId = conn['id'] as int;

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surfaceSecondary,
                backgroundImage: avatarUrl != null &&
                        avatarUrl.isNotEmpty &&
                        avatarUrl.startsWith('http')
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null ||
                        avatarUrl.isEmpty ||
                        !avatarUrl.startsWith('http')
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: AppTypography.cardTitle,
                      )
                    : null,
              ),
              title: Text(name, style: AppTypography.bodyText),
              trailing: GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await plansProvider.inviteUser(
                    planId: widget.planId,
                    inviteeId: otherId,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Invite',
                    style: AppTypography.captionText.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeletePlan() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfacePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Plan', style: AppTypography.cardTitle),
        content: Text(
          'Are you sure you want to delete this plan? This cannot be undone.',
          style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTypography.bodyText
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final plansProvider =
                  Provider.of<PlansProvider>(context, listen: false);
              await plansProvider.deletePlan(widget.planId);
              if (mounted) Navigator.pop(context);
            },
            child: Text('Delete',
                style: AppTypography.bodyText
                    .copyWith(color: const Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.canvasBackground,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plan == null
              ? _buildNotFound()
              : _buildContent(),
    );
  }

  Widget _buildNotFound() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('Plan not found',
                style: AppTypography.cardTitle
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text('Go Back',
                  style:
                      AppTypography.bodyText.copyWith(color: AppColors.accentPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final plan = _plan!;
    final category = plan['category'] as String? ?? 'other';
    final title = plan['title'] as String? ?? 'Untitled';
    final description = plan['description'] as String?;
    final startsAt = DateTime.tryParse(plan['starts_at'] ?? '')?.toLocal();
    final endsAt = plan['ends_at'] != null
        ? DateTime.tryParse(plan['ends_at'])?.toLocal()
        : null;
    final location = plan['location'] as String?;
    final isOnline = plan['is_online'] == true;
    final meetingLink = plan['meeting_link'] as String?;
    final planType = plan['plan_type'] as String? ?? 'casual';
    final creatorProfile = plan['creator'] as Map<String, dynamic>?;
    final creatorName = creatorProfile?['name'] as String? ?? 'Unknown';
    final creatorId = plan['creator_id'] as int?;
    final plansProvider = Provider.of<PlansProvider>(context, listen: false);
    final isCreator = plansProvider.userId == creatorId;

    final acceptedCount =
        _invites.where((i) => i['status'] == 'accepted').length + 1; // +1 for creator
    final pendingCount =
        _invites.where((i) => i['status'] == 'pending').length;
    final declinedCount =
        _invites.where((i) => i['status'] == 'declined').length;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accentPrimary,
      backgroundColor: AppColors.surfacePrimary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon:
                  const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (isCreator) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: _openEditSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 20, color: Color(0xFFEF4444)),
                  onPressed: _confirmDeletePlan,
                ),
              ],
            ],
            pinned: false,
            floating: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Text(categoryEmoji(category),
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(title, style: AppTypography.displayHeader),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Type badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: planType == 'professional'
                              ? AppColors.accentPrimary.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          planType == 'professional'
                              ? 'Professional'
                              : 'Casual',
                          style: AppTypography.captionText.copyWith(
                            color: planType == 'professional'
                                ? AppColors.accentPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          categoryLabel(category),
                          style: AppTypography.captionText
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Date & Time
                  _buildInfoRow(
                    Icons.calendar_today_outlined,
                    startsAt != null
                        ? _formatDate(startsAt)
                        : 'Date not set',
                  ),
                  _buildInfoRow(
                    Icons.access_time_rounded,
                    startsAt != null
                        ? '${_formatTime(startsAt)}${endsAt != null ? ' — ${_formatTime(endsAt)}' : ''}'
                        : 'Time not set',
                  ),
                  if (startsAt != null) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_outlined,
                            size: 13,
                            color: AppColors.accentPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Reminder will fire at ${_formatReminderTime(startsAt.subtract(const Duration(minutes: 30)))}',
                            style: AppTypography.captionText.copyWith(
                              color: AppColors.accentPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Location
                  if (location != null && location.isNotEmpty)
                    _buildInfoRow(Icons.location_on_outlined, location),
                  if (isOnline) ...[
                    _buildInfoRow(Icons.videocam_outlined, 'Online'),
                    if (meetingLink != null && meetingLink.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: meetingLink));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Meeting link copied',
                                  style: AppTypography.bodyText),
                              backgroundColor: AppColors.surfacePrimary,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: Text(
                            meetingLink,
                            style: AppTypography.bodyText.copyWith(
                              color: AppColors.accentPrimary,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.accentPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  // Description
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusComponent),
                      ),
                      child: Text(
                        description,
                        style: AppTypography.bodyText
                            .copyWith(color: AppColors.textSecondary, height: 1.5),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  // Divider
                  Container(height: 1, color: AppColors.borderMuted),
                  const SizedBox(height: 20),

                  // People section
                  Text(
                    'People ($acceptedCount going${pendingCount > 0 ? ' · $pendingCount pending' : ''}${declinedCount > 0 ? ' · $declinedCount declined' : ''})',
                    style: AppTypography.cardTitle,
                  ),
                  const SizedBox(height: 12),

                  // Creator
                  _buildPersonTile(
                    name: creatorName,
                    avatarUrl: creatorProfile?['avatar_url'] as String?,
                    status: 'creator',
                  ),

                  // Invitees
                  ..._invites.map((invite) {
                    final invitee =
                        invite['invitee'] as Map<String, dynamic>?;
                    final name =
                        invitee?['name'] as String? ?? 'Unknown';
                    final avatar =
                        invitee?['avatar_url'] as String?;
                    final status = invite['status'] as String? ?? 'pending';
                    final reason = invite['decline_reason'] as String?;

                    return _buildPersonTile(
                      name: name,
                      avatarUrl: avatar,
                      status: status,
                      declineReason: reason,
                    );
                  }),

                  const SizedBox(height: 12),
                  // Invite more button
                  GestureDetector(
                    onTap: _showInviteConnectionsSheet,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.borderMuted,
                        ),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusComponent),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add_alt_1_outlined,
                              size: 18, color: AppColors.accentPrimary),
                          const SizedBox(width: 8),
                          Text(
                            'Invite More People',
                            style: AppTypography.bodyText
                                .copyWith(color: AppColors.accentPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Edits section
                  if (_edits.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(height: 1, color: AppColors.borderMuted),
                    const SizedBox(height: 20),
                    Text('Recent Changes', style: AppTypography.cardTitle),
                    const SizedBox(height: 12),
                    ..._edits.map((edit) => _buildEditTile(edit)),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyText
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonTile({
    required String name,
    String? avatarUrl,
    required String status,
    String? declineReason,
  }) {
    final statusIcons = {
      'creator': ('✅', 'Organizer'),
      'accepted': ('✅', 'Going'),
      'pending': ('⏳', 'Pending'),
      'declined': ('❌', "Can't make it"),
    };
    final entry = statusIcons[status] ?? ('❓', status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfacePrimary,
                  backgroundImage: avatarUrl != null &&
                          avatarUrl.isNotEmpty &&
                          avatarUrl.startsWith('http')
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null ||
                          avatarUrl.isEmpty ||
                          !avatarUrl.startsWith('http')
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: AppTypography.captionText
                              .copyWith(color: Colors.white, fontSize: 14),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name, style: AppTypography.bodyText),
                ),
                Text(
                  '${entry.$1} ${entry.$2}',
                  style: AppTypography.captionText.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if (status == 'declined' &&
                declineReason != null &&
                declineReason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 46),
                child: Text(
                  '"$declineReason"',
                  style: AppTypography.bodyText.copyWith(
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditTile(Map<String, dynamic> edit) {
    final editor = edit['editor'] as Map<String, dynamic>?;
    final editorName = editor?['name'] as String? ?? 'Someone';
    final changedFields = edit['changed_fields'] as Map<String, dynamic>? ?? {};
    final createdAt =
        DateTime.tryParse(edit['created_at'] ?? '')?.toLocal();

    final changes = <String>[];
    for (final entry in changedFields.entries) {
      final field = entry.key;
      final values = entry.value as Map<String, dynamic>?;
      if (values != null) {
        changes.add(
            '$editorName changed $field from "${values['old']}" to "${values['new']}"');
      } else {
        changes.add('$editorName changed $field');
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final change in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                change,
                style: AppTypography.bodyText
                    .copyWith(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          if (createdAt != null)
            Text(
              _relativeTime(createdAt),
              style: AppTypography.captionText
                  .copyWith(color: AppColors.textMuted, fontSize: 10),
            ),
        ],
      ),
    );
  }

  String _formatReminderTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${_formatTime(dt)}';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _formatDate(dateTime);
  }
}
