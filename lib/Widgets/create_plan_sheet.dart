import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/plans_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/services/analytics_service.dart';

class CreatePlanSheet extends StatefulWidget {
  final Map<String, dynamic>? existingPlan;
  const CreatePlanSheet({super.key, this.existingPlan});

  @override
  State<CreatePlanSheet> createState() => _CreatePlanSheetState();
}

class _CreatePlanSheetState extends State<CreatePlanSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _meetingLinkController = TextEditingController();
  final _customCategoryController = TextEditingController();

  String _selectedCategory = 'meeting';
  String _selectedPlanType = 'casual';
  bool _isOnline = false;
  DateTime _startDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _startTime = TimeOfDay.fromDateTime(
      DateTime.now().add(const Duration(hours: 1)));
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _hasEndTime = false;

  final Set<int> _selectedInvitees = {};
  bool _saving = false;

  bool get _isEditing => widget.existingPlan != null;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onFormChanged);
    _customCategoryController.addListener(_onFormChanged);
    if (_isEditing) {
      _populateFromExisting();
    }
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  String? _getValidationError() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return "Enter a title for your plan";
    }

    if (_selectedCategory == 'other') {
      final customCat = _customCategoryController.text.trim();
      if (customCat.isEmpty) {
        return "Specify a custom category name";
      }
    }

    if (_hasEndTime) {
      if (_endTime == null) {
        return "Select an end time for your plan";
      }
      final startsAt = _combineDateAndTime(_startDate, _startTime);
      final endsAt = _combineDateAndTime(_endDate ?? _startDate, _endTime!);
      if (!endsAt.isAfter(startsAt)) {
        return "End time must be after start time";
      }
    }

    return null;
  }

  void _populateFromExisting() {
    final plan = widget.existingPlan!;
    _titleController.text = plan['title'] as String? ?? '';
    _descriptionController.text = plan['description'] as String? ?? '';
    _locationController.text = plan['location'] as String? ?? '';
    _meetingLinkController.text = plan['meeting_link'] as String? ?? '';
    
    final category = plan['category'] as String? ?? 'meeting';
    if (category == 'meeting' ||
        category == 'video_call' ||
        category == 'food_drinks' ||
        category == 'sports' ||
        category == 'party' ||
        category == 'video_game' ||
        category == 'movie' ||
        category == 'hangout' ||
        category == 'travel') {
      _selectedCategory = category;
    } else {
      _selectedCategory = 'other';
      _customCategoryController.text = category;
    }
    
    _selectedPlanType = plan['plan_type'] as String? ?? 'casual';
    _isOnline = plan['is_online'] == true;

    final startsAt = DateTime.tryParse(plan['starts_at'] ?? '')?.toLocal();
    if (startsAt != null) {
      _startDate = startsAt;
      _startTime = TimeOfDay.fromDateTime(startsAt);
    }

    final endsAt = plan['ends_at'] != null
        ? DateTime.tryParse(plan['ends_at'])?.toLocal()
        : null;
    if (endsAt != null) {
      _hasEndTime = true;
      _endDate = endsAt;
      _endTime = TimeOfDay.fromDateTime(endsAt);
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFormChanged);
    _customCategoryController.removeListener(_onFormChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _meetingLinkController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDate(bool isEndDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isEndDate ? (_endDate ?? _startDate) : _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accentPrimary,
            surface: AppColors.surfacePrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isEndDate) {
          _endDate = picked;
        } else {
          _startDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime(bool isEndTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isEndTime ? (_endTime ?? _startTime) : _startTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accentPrimary,
            surface: AppColors.surfacePrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isEndTime) {
          _endTime = picked;
        } else {
          _startTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final validationError = _getValidationError();
    if (validationError != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError, style: AppTypography.bodyText),
          backgroundColor: AppColors.surfaceSecondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final title = _titleController.text.trim();

    String categoryToSend = _selectedCategory;
    if (_selectedCategory == 'other') {
      final customText = _customCategoryController.text.trim();
      categoryToSend = customText.isNotEmpty ? customText : 'Other';
    }

    setState(() => _saving = true);

    final plansProvider = Provider.of<PlansProvider>(context, listen: false);
    final startsAt = _combineDateAndTime(_startDate, _startTime);

    DateTime? endsAt;
    if (_hasEndTime && _endTime != null) {
      endsAt = _combineDateAndTime(_endDate ?? _startDate, _endTime!);
    }

    if (_isEditing) {
      // Build change log
      final existing = widget.existingPlan!;
      final changes = <String, dynamic>{};
      final updates = <String, dynamic>{};

      if (title != (existing['title'] ?? '')) {
        changes['title'] = {'old': existing['title'], 'new': title};
        updates['title'] = title;
      }
      final oldCategory = existing['category'] ?? 'meeting';
      if (categoryToSend != oldCategory) {
        changes['category'] = {
          'old': oldCategory,
          'new': categoryToSend
        };
        updates['category'] = categoryToSend;
      }
      if (_selectedPlanType != (existing['plan_type'] ?? 'casual')) {
        changes['plan_type'] = {
          'old': existing['plan_type'],
          'new': _selectedPlanType
        };
        updates['plan_type'] = _selectedPlanType;
      }
      final oldStartsAt =
          DateTime.tryParse(existing['starts_at'] ?? '')?.toLocal();
      if (oldStartsAt == null ||
          startsAt.difference(oldStartsAt).inMinutes.abs() > 0) {
        changes['starts_at'] = {
          'old': _formatDateTime(oldStartsAt),
          'new': _formatDateTime(startsAt)
        };
        updates['starts_at'] = startsAt.toUtc().toIso8601String();
      }

      final desc = _descriptionController.text.trim();
      if (desc != (existing['description'] ?? '')) {
        updates['description'] = desc;
      }
      final loc = _locationController.text.trim();
      if (loc != (existing['location'] ?? '')) {
        if (loc.isNotEmpty || (existing['location'] ?? '').isNotEmpty) {
          changes['location'] = {'old': existing['location'] ?? '', 'new': loc};
        }
        updates['location'] = loc;
      }
      if (_isOnline != (existing['is_online'] == true)) {
        updates['is_online'] = _isOnline;
      }
      final link = _meetingLinkController.text.trim();
      if (link != (existing['meeting_link'] ?? '')) {
        updates['meeting_link'] = link;
      }
      if (endsAt != null) {
        updates['ends_at'] = endsAt.toUtc().toIso8601String();
      }
      // Always include title in updates for the reminder reschedule
      if (!updates.containsKey('title')) {
        updates['title'] = title;
      }

      await plansProvider.updatePlan(
        planId: existing['id'] as String,
        updates: updates,
        changedFields: changes,
      );
    } else {
      await plansProvider.createPlan(
        title: title,
        category: categoryToSend,
        planType: _selectedPlanType,
        startsAt: startsAt,
        endsAt: endsAt,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        isOnline: _isOnline,
        meetingLink: _meetingLinkController.text.trim().isNotEmpty
            ? _meetingLinkController.text.trim()
            : null,
        inviteeIds: _selectedInvitees.toList(),
      );

      AnalyticsService.logEvent(
        name: 'plan_created',
        parameters: {
          'category': categoryToSend,
          'plan_type': _selectedPlanType,
          'is_online': _isOnline,
          'invitees_count': _selectedInvitees.length,
        },
      );
    }

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${months[dt.month - 1]} ${dt.day}, $displayHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Edit Plan' : 'New Plan',
                  style: AppTypography.screenHeading,
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded,
                      color: AppColors.textSecondary, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  _buildLabel('Title'),
                  _buildTextField(
                    controller: _titleController,
                    hint: 'e.g. Movie Night',
                  ),
                  const SizedBox(height: 16),

                  // Category
                  _buildLabel('Category'),
                  _buildCategoryPicker(),
                  const SizedBox(height: 16),

                  // Type
                  _buildLabel('Type'),
                  _buildTypePicker(),
                  const SizedBox(height: 16),

                  // When
                  _buildLabel('When'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateTimeTile(
                          icon: Icons.calendar_today_outlined,
                          text: _formatDateShort(_startDate),
                          onTap: () => _pickDate(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateTimeTile(
                          icon: Icons.access_time_rounded,
                          text: _startTime.format(context),
                          onTap: () => _pickTime(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          size: 13,
                          color: AppColors.accentPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Reminder will fire at ${_formatReminderTime(_combineDateAndTime(_startDate, _startTime).subtract(const Duration(minutes: 30)))}',
                          style: AppTypography.captionText.copyWith(
                            color: AppColors.accentPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // End time toggle
                  GestureDetector(
                    onTap: () =>
                        setState(() => _hasEndTime = !_hasEndTime),
                    child: Row(
                      children: [
                        Icon(
                          _hasEndTime
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 20,
                          color: _hasEndTime
                              ? AppColors.accentPrimary
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Set end time',
                          style: AppTypography.bodyText
                              .copyWith(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  if (_hasEndTime) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateTimeTile(
                            icon: Icons.calendar_today_outlined,
                            text: _formatDateShort(_endDate ?? _startDate),
                            onTap: () => _pickDate(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateTimeTile(
                            icon: Icons.access_time_rounded,
                            text: _endTime != null
                                ? _endTime!.format(context)
                                : 'Pick time',
                            onTap: () => _pickTime(true),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Online toggle + location
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isOnline = !_isOnline),
                        child: Row(
                          children: [
                            Icon(
                              _isOnline
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 20,
                              color: _isOnline
                                  ? AppColors.accentPrimary
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Online',
                              style: AppTypography.bodyText.copyWith(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (!_isOnline)
                    _buildTextField(
                      controller: _locationController,
                      hint: 'Location (optional)',
                      icon: Icons.location_on_outlined,
                    ),

                  if (_isOnline)
                    _buildTextField(
                      controller: _meetingLinkController,
                      hint: 'Meeting link (optional)',
                      icon: Icons.link_rounded,
                    ),

                  const SizedBox(height: 16),

                  // Description
                  _buildLabel('Description (optional)'),
                  _buildTextField(
                    controller: _descriptionController,
                    hint: 'What is this plan about?',
                    maxLines: 3,
                  ),

                  // Invitees (only for new plans)
                  if (!_isEditing) ...[
                    const SizedBox(height: 20),
                    _buildLabel('Invite Connections'),
                    const SizedBox(height: 8),
                    _buildInviteesPicker(),
                  ],

                  const SizedBox(height: 24),

                  // Submit button & validation feedback
                  Builder(
                    builder: (context) {
                      final validationError = _getValidationError();
                      final isValid = validationError == null;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isValid && !_saving) ...[
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: AppColors.accentPrimary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.accentPrimary.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: AppColors.accentPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      validationError,
                                      style: AppTypography.captionText.copyWith(
                                        color: AppColors.accentPrimary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          GestureDetector(
                            onTap: (_saving || !isValid)
                                ? () {
                                    if (!isValid) {
                                      HapticFeedback.lightImpact();
                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            validationError,
                                            style: AppTypography.bodyText.copyWith(color: Colors.white),
                                          ),
                                          backgroundColor: AppColors.surfaceSecondary,
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                : _save,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isValid
                                    ? AppColors.accentPrimary
                                    : AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isValid
                                      ? AppColors.accentPrimary
                                      : AppColors.borderMuted,
                                ),
                              ),
                              child: Center(
                                child: _saving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _isEditing ? 'Save Changes' : 'Create Plan',
                                        style: AppTypography.cardTitle.copyWith(
                                          color: isValid
                                              ? Colors.white
                                              : AppColors.textMuted,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTypography.captionText
            .copyWith(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderMuted),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: AppTypography.bodyText,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              AppTypography.bodyText.copyWith(color: AppColors.textMuted),
          prefixIcon: icon != null
              ? Icon(icon, size: 18, color: AppColors.textSecondary)
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: planCategories.map((cat) {
            final selected = _selectedCategory == cat.key;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accentPrimary.withValues(alpha: 0.15)
                      : AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppColors.accentPrimary
                        : AppColors.borderMuted,
                  ),
                ),
                child: Text(
                  '${cat.emoji} ${cat.label}',
                  style: AppTypography.captionText.copyWith(
                    color: selected
                        ? AppColors.accentPrimary
                        : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedCategory == 'other') ...[
          const SizedBox(height: 12),
          _buildTextField(
            controller: _customCategoryController,
            hint: 'Enter custom category (e.g. Date, Movie, Sports)',
            icon: Icons.edit_note_rounded,
          ),
        ],
      ],
    );
  }

  Widget _buildTypePicker() {
    return Row(
      children: ['casual', 'professional'].map((type) {
        final selected = _selectedPlanType == type;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedPlanType = type);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(
                  right: type == 'casual' ? 6 : 0,
                  left: type == 'professional' ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accentPrimary.withValues(alpha: 0.12)
                    : AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppColors.accentPrimary
                      : AppColors.borderMuted,
                ),
              ),
              child: Center(
                child: Text(
                  type == 'casual' ? 'Casual' : 'Professional',
                  style: AppTypography.bodyText.copyWith(
                    color: selected
                        ? AppColors.accentPrimary
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateTimeTile({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderMuted),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: AppTypography.bodyText
                    .copyWith(color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteesPicker() {
    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    final connections = connectionProvider.connections;

    if (connections.isEmpty) {
      return Text(
        'No connections to invite yet',
        style:
            AppTypography.bodyText.copyWith(color: AppColors.textMuted),
      );
    }

    return Column(
      children: connections.map((conn) {
        final otherId = conn['id'] as int?;
        final name = conn['name'] as String? ?? 'Unknown';
        final avatarUrl = conn['avatarUrl'] as String? ?? conn['avatar_url'] as String?;
        if (otherId == null) return const SizedBox.shrink();

        final isSelected = _selectedInvitees.contains(otherId);

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isSelected) {
                _selectedInvitees.remove(otherId);
              } else {
                _selectedInvitees.add(otherId);
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentPrimary.withValues(alpha: 0.08)
                  : AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.borderMuted,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
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
                              .copyWith(color: Colors.white, fontSize: 12),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name,
                      style: AppTypography.bodyText.copyWith(fontSize: 13)),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 20,
                  color: isSelected
                      ? AppColors.accentPrimary
                      : AppColors.textMuted,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatTimeOfDateTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final formattedMinute = minute.toString().padLeft(2, '0');
    return '$formattedHour:$formattedMinute $period';
  }

  String _formatReminderTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${_formatTimeOfDateTime(dt)}';
  }

  String _formatDateShort(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
