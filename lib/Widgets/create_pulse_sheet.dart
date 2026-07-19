import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/pulse_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Models/pulse.dart';
import 'package:connect/Widgets/pulse_user_picker.dart';
import 'package:connect/Utils/error_handler.dart';

class CreatePulseSheet extends StatefulWidget {
  const CreatePulseSheet({super.key});

  @override
  State<CreatePulseSheet> createState() => _CreatePulseSheetState();
}

class _CreatePulseSheetState extends State<CreatePulseSheet> with SingleTickerProviderStateMixin {
  String _selectedType = 'status'; // 'status' or 'ask'
  PulseTag? _selectedTag;
  final TextEditingController _textController = TextEditingController();
  String _visibility = 'both'; // 'casual', 'professional', 'both'
  final List<int> _hiddenUserIds = [];
  bool _isPublishing = false;
  int _selectedDurationHours = 8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pulseProvider = Provider.of<PulseProvider>(context, listen: false);
      final myPulse = pulseProvider.myPulse;
      if (myPulse != null && !myPulse.isExpired) {
        setState(() {
          _selectedType = myPulse.pulseType;
          if (pulseProvider.tags.isNotEmpty) {
            _selectedTag = pulseProvider.tags.firstWhere(
              (t) => t.id == myPulse.pulseTagId,
              orElse: () => myPulse.tag ?? pulseProvider.tags.first,
            );
          } else {
            _selectedTag = myPulse.tag;
          }
          _textController.text = myPulse.text ?? '';
          _visibility = myPulse.visibility;
          _hiddenUserIds.clear();
          _hiddenUserIds.addAll(myPulse.hiddenUserIds);
          
          final remaining = myPulse.expiresAt.difference(DateTime.now()).inHours;
          _selectedDurationHours = remaining > 0 ? remaining : 8;
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulseProvider = Provider.of<PulseProvider>(context);
    final connectionProvider = Provider.of<ConnectionProvider>(context);
    final allTags = pulseProvider.tags;
    
    // Filter tags by selected type
    final filteredTags = allTags.where((t) => t.type == _selectedType).toList();

    final durations = [1, 2, 4, 8, 24, 72];
    if (_selectedTag == null && filteredTags.isNotEmpty) {
      _selectedTag = filteredTags.first;
      _selectedDurationHours = _selectedTag!.defaultDurationHours;
    }
    if (_selectedTag != null && !durations.contains(_selectedDurationHours)) {
      durations.add(_selectedDurationHours);
      durations.sort();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.surfacePrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: context.surfaceSecondary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              // Handlebar indicator
              Center(
                child: Container(
                  width: 36,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: context.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Create Pulse",
                      style: context.displayHeader.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: context.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  children: [
                    // Segmented Selector for Status / Ask
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _selectedType = 'status';
                                  _selectedTag = null;
                                  _textController.clear();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(9),
                                  color: _selectedType == 'status'
                                      ? context.accentSecondary
                                      : Colors.transparent,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Status",
                                  style: TextStyle(
                                    color: _selectedType == 'status'
                                        ? Colors.white
                                        : context.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _selectedType = 'ask';
                                  _selectedTag = null;
                                  _textController.clear();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(9),
                                  color: _selectedType == 'ask'
                                      ? context.accentSecondary
                                      : Colors.transparent,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Ask",
                                  style: TextStyle(
                                    color: _selectedType == 'ask'
                                        ? Colors.white
                                        : context.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Scrollable Horizontal Tags List
                    Text(
                      "CHOOSE A TAG",
                      style: context.captionText.copyWith(
                        color: context.textSecondary,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: filteredTags.map((tag) {
                        final isSelected = _selectedTag?.id == tag.id;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _selectedTag = tag;
                              _selectedDurationHours = tag.defaultDurationHours;
                              _textController.clear();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? context.accentSecondary.withValues(alpha: 0.15)
                                  : context.surfaceSecondary,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? context.accentSecondary
                                    : context.surfaceSecondary,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (tag.icon != null) ...[
                                  _buildTagIcon(tag.icon!, isSelected),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  tag.name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : context.textPrimary,
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Expanding Text Field (optional for statuses, dynamically expanded for asks)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: _selectedTag != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedType == 'ask' ? "ADD DETAILS (OPTIONAL)" : "ADD NOTE (OPTIONAL)",
                                  style: context.captionText.copyWith(
                                    color: context.textSecondary,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: context.surfaceSecondary,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: TextField(
                                    controller: _textController,
                                    maxLines: 2,
                                    maxLength: 60,
                                    style: TextStyle(color: context.textPrimary, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: _selectedTag!.placeholder ?? "Share a note...",
                                      hintStyle: TextStyle(color: context.textMuted, fontSize: 14),
                                      border: InputBorder.none,
                                      counterText: '',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),

                    // Duration Selector
                    if (_selectedTag != null) ...[
                      Text(
                        "DURATION",
                        style: context.captionText.copyWith(
                          color: context.textSecondary,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: durations.map((hours) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildDurationChip(hours, context),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Visibility Selector
                    Text(
                      "VISIBILITY",
                      style: context.captionText.copyWith(
                        color: context.textSecondary,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        children: [
                          _buildVisibilityTab('casual', 'Casual'),
                          _buildVisibilityTab('professional', 'Professional'),
                          _buildVisibilityTab('both', 'Both'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Hide From picker
                    Text(
                      "EXCLUDE PEOPLE",
                      style: context.captionText.copyWith(
                        color: context.textSecondary,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final result = await showModalBottomSheet<List<int>>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => PulseUserPicker(
                            connections: connectionProvider.connections,
                            initialSelectedIds: _hiddenUserIds,
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            _hiddenUserIds.clear();
                            _hiddenUserIds.addAll(result);
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: context.surfaceSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_off_rounded, color: context.textSecondary, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  "Hide from specific people",
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Icon(Icons.chevron_right_rounded, color: context.textMuted),
                          ],
                        ),
                      ),
                    ),

                    // Excluded user chips
                    if (_hiddenUserIds.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: _hiddenUserIds.map((id) {
                          final conn = connectionProvider.connections.firstWhere(
                            (c) => c['id'] == id,
                            orElse: () => {'name': 'User'},
                          );
                          return Chip(
                            label: Text(
                              conn['name'] ?? 'User',
                              style: TextStyle(color: context.textPrimary, fontSize: 11.5),
                            ),
                            backgroundColor: context.surfaceSecondary,
                            deleteIcon: const Icon(Icons.close_rounded, size: 12),
                            deleteIconColor: context.textSecondary,
                            onDeleted: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _hiddenUserIds.remove(id);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Expiration calculation text
                    if (_selectedTag != null) ...[
                      Center(
                        child: Text(
                          "Expires in ${widgetDurationText(_selectedDurationHours)}",
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Publish Button
                    AnimatedBuilder(
                      animation: Listenable.merge([pulseProvider]),
                      builder: (context, child) {
                        final isBusy = pulseProvider.isPublishing || _isPublishing;
                        return ElevatedButton(
                          onPressed: (_selectedTag == null || isBusy)
                              ? null
                              : () => _handlePublish(context, pulseProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.accentSecondary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: context.surfaceSecondary,
                            disabledForegroundColor: context.textMuted,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  "Publish Pulse",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedTag == null ? context.textMuted : Colors.white,
                                  ),
                                ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisibilityTab(String value, String title) {
    final isSelected = _visibility == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _visibility = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: isSelected ? context.accentSecondary : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : context.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagIcon(String iconName, bool isSelected) {
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
    return Icon(
      iconData,
      size: 15,
      color: isSelected ? Colors.white : context.accentSecondary,
    );
  }

  String widgetDurationText(int hours) {
    if (hours < 24) {
      return "$hours hours";
    } else {
      final days = hours ~/ 24;
      return "$days ${days == 1 ? 'day' : 'days'}";
    }
  }

  String _getDurationLabel(int hours) {
    if (hours < 24) {
      return "${hours}h";
    } else {
      return "${hours ~/ 24}d";
    }
  }

  Widget _buildDurationChip(int hours, BuildContext context) {
    final isSelected = _selectedDurationHours == hours;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedDurationHours = hours;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.accentSecondary.withValues(alpha: 0.15)
              : context.surfaceSecondary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? context.accentSecondary
                : context.surfaceSecondary,
            width: 1.5,
          ),
        ),
        child: Text(
          _getDurationLabel(hours),
          style: TextStyle(
            color: isSelected ? Colors.white : context.textPrimary,
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _handlePublish(BuildContext context, PulseProvider provider) async {
    if (_selectedTag == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isPublishing = true;
    });

    try {
      // Publish the pulse
      await provider.publishPulse(
        tagId: _selectedTag!.id,
        pulseType: _selectedType,
        text: _textController.text.isNotEmpty ? _textController.text.trim() : null,
        visibility: _visibility,
        hiddenUserIds: _hiddenUserIds,
        durationHours: _selectedDurationHours,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pulse published successfully!"),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
          _isPublishing = false;
        });
      }
    }
  }
}
