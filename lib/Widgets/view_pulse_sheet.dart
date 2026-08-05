import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/pulse.dart';
import 'package:connect/Providers/pulse_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:connect/Widgets/create_plan_sheet.dart';
import 'package:connect/services/analytics_service.dart';
import 'package:connect/Utils/error_handler.dart';

class ViewPulseSheet extends StatefulWidget {
  final UserPulse pulse;
  final bool isOwnPulse;

  const ViewPulseSheet({
    super.key,
    required this.pulse,
    required this.isOwnPulse,
  });

  @override
  State<ViewPulseSheet> createState() => _ViewPulseSheetState();
}

class _ViewPulseSheetState extends State<ViewPulseSheet> {
  final TextEditingController _updateController = TextEditingController();
  bool _isSubmittingUpdate = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logEvent(
      name: 'pulse_viewed',
      parameters: {
        'pulse_id': widget.pulse.id,
        'is_own_pulse': widget.isOwnPulse,
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<PulseProvider>(context, listen: false).loadUpdates(widget.pulse.id);
      }
    });
  }

  @override
  void dispose() {
    _updateController.dispose();
    super.dispose();
  }

  String _getCountdownText(DateTime expiresAt) {
    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    if (difference.isNegative) {
      return "Expired";
    }
    if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m left";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h left";
    } else {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      if (expiresAt.day == tomorrow.day &&
          expiresAt.month == tomorrow.month &&
          expiresAt.year == tomorrow.year) {
        return "Tomorrow";
      } else {
        return "${difference.inDays}d left";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pulseProvider = Provider.of<PulseProvider>(context);
    final updates = pulseProvider.cachedUpdates[widget.pulse.id] ?? [];
    final countdown = _getCountdownText(widget.pulse.expiresAt);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: context.surfaceSecondary, width: 1.5),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.isOwnPulse ? "My Pulse" : "${widget.pulse.userName}'s Pulse",
                              style: context.displayHeader.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                if (widget.isOwnPulse)
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert_rounded, color: context.textSecondary),
                                    color: context.surfaceSecondary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    onSelected: (val) {
                                      if (val == 'delete') {
                                        _confirmDelete(context, pulseProvider);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              "Delete Pulse",
                                              style: TextStyle(color: context.textPrimary, fontSize: 13.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                IconButton(
                                  icon: Icon(Icons.close_rounded, color: context.textSecondary),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // User Card Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundImage: widget.pulse.userAvatarUrl.isNotEmpty
                                  ? NetworkImage(widget.pulse.userAvatarUrl)
                                  : null,
                              backgroundColor: context.surfaceSecondary,
                              child: widget.pulse.userAvatarUrl.isEmpty
                                  ? Text(
                                      widget.pulse.userName.isNotEmpty
                                          ? widget.pulse.userName[0].toUpperCase()
                                          : '',
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.pulse.userName,
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.pulse.userProfession +
                                        (widget.pulse.userCompany.isNotEmpty ? " @ ${widget.pulse.userCompany}" : ""),
                                    style: TextStyle(color: context.textSecondary, fontSize: 12.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: context.surfaceSecondary,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer_outlined, size: 13, color: context.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    countdown,
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tag Bubble & Context text
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.surfaceSecondary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (widget.pulse.tag?.icon != null) ...[
                                    _buildTagIcon(widget.pulse.tag!.icon!),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    widget.pulse.tag?.name ?? widget.pulse.pulseType.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.pulse.text != null && widget.pulse.text!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  widget.pulse.text!,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 14.5,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action button (If not own pulse)
                      if (!widget.isOwnPulse && widget.pulse.tag?.actionType != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: ElevatedButton(
                            onPressed: () => _handleAction(context, widget.pulse.tag!.actionType!),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.accentSecondary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              _getActionText(widget.pulse.tag!.actionType!),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Follow-up timeline header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          "UPDATES",
                          style: context.captionText.copyWith(
                            color: context.textSecondary,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                if (updates.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      height: 100,
                      alignment: Alignment.center,
                      child: Text(
                        "No updates yet.",
                        style: TextStyle(color: context.textMuted, fontSize: 13.5),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final itemIndex = index ~/ 2;
                          if (index.isOdd) {
                            return const SizedBox(height: 10);
                          }
                          final update = updates[itemIndex];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF7C3AED), // Amethyst Purple
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      update.text,
                                      style: TextStyle(color: context.textPrimary, fontSize: 13.5, height: 1.3),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatTimeAgo(update.createdAt),
                                      style: TextStyle(color: context.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                        childCount: updates.length * 2 - 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Add Update bar (If own pulse)
          if (widget.isOwnPulse)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _updateController,
                        style: TextStyle(color: context.textPrimary, fontSize: 13.5),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (val) => _submitUpdate(pulseProvider),
                        decoration: InputDecoration(
                          hintText: "Add update...",
                          hintStyle: TextStyle(color: context.textMuted, fontSize: 13.5),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSubmittingUpdate ? null : () => _submitUpdate(pulseProvider),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: context.accentSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: _isSubmittingUpdate
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagIcon(String iconName) {
    IconData iconData;
    switch (iconName) {
      case 'briefcase':
        iconData = Icons.business_center_rounded;
        break;
      case 'coffee':
        iconData = Icons.coffee_rounded;
        break;
      case 'flight':
        iconData = Icons.flight_takeoff_rounded;
        break;
      case 'fitness_center':
        iconData = Icons.fitness_center_rounded;
        break;
      case 'school':
        iconData = Icons.school_rounded;
        break;
      case 'groups':
        iconData = Icons.groups_rounded;
        break;
      case 'chat':
        iconData = Icons.chat_rounded;
        break;
      case 'person_add':
        iconData = Icons.person_add_rounded;
        break;
      case 'rate_review':
        iconData = Icons.rate_review_rounded;
        break;
      case 'work':
        iconData = Icons.work_rounded;
        break;
      case 'help':
        iconData = Icons.help_outline_rounded;
        break;
      case 'handshake':
        iconData = Icons.handshake_rounded;
        break;
      case 'hub':
        iconData = Icons.hub_rounded;
        break;
      default:
        iconData = Icons.circle_outlined;
    }
    return Icon(iconData, size: 15, color: context.accentSecondary);
  }

  String _getActionText(String actionType) {
    switch (actionType) {
      case 'message':
        return "Message";
      case 'refer':
        return "Refer Someone";
      case 'propose_plan':
        return "Propose Plan";
      default:
        return "Interact";
    }
  }

  void _handleAction(BuildContext context, String actionType) {
    HapticFeedback.mediumImpact();
    AnalyticsService.logEvent(
      name: 'pulse_action_triggered',
      parameters: {
        'action_type': actionType,
        'pulse_owner_id': widget.pulse.userId,
      },
    );
    if (actionType == 'message') {
      final connections = Provider.of<ConnectionProvider>(context, listen: false).connections;
      final conn = connections.firstWhere((c) => c['id'] == widget.pulse.userId, orElse: () => {});
      if (conn.isNotEmpty) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IndividualChatPage(connectionData: conn),
          ),
        );
      }
    } else if (actionType == 'propose_plan') {
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const CreatePlanSheet(),
      );
    } else {
      // refer
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Initiated introduction flow for ${widget.pulse.userName}."),
          backgroundColor: context.accentSecondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitUpdate(PulseProvider provider) async {
    final text = _updateController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();

    setState(() {
      _isSubmittingUpdate = true;
    });

    try {
      await provider.addPulseUpdate(widget.pulse.id, text);
      AnalyticsService.logEvent(name: 'pulse_update_added');
      _updateController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getFriendlyErrorMessage(e)),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingUpdate = false;
        });
      }
    }
  }

  void _confirmDelete(BuildContext context, PulseProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfacePrimary,
        title: Text(
          "Delete Pulse?",
          style: TextStyle(color: context.textPrimary, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to delete your active Pulse? This cannot be undone.",
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: context.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx); // Close dialog
              HapticFeedback.mediumImpact();
              try {
                await provider.deletePulse(widget.pulse.id);
                if (mounted) {
                  navigator.pop(); // Close view sheet
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Pulse deleted successfully."),
                      backgroundColor: Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(getFriendlyErrorMessage(e)),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final difference = DateTime.now().difference(dt);
    if (difference.inMinutes < 1) {
      return "just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else {
      return "${difference.inDays}d ago";
    }
  }
}
