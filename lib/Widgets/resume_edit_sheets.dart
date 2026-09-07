import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/resume_models.dart';
import 'package:uuid/uuid.dart';

class ExperienceEditSheet extends StatefulWidget {
  final ExperienceItem? item;
  final Function(ExperienceItem item) onSave;
  final VoidCallback? onDelete;

  const ExperienceEditSheet({
    super.key,
    this.item,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<ExperienceEditSheet> createState() => _ExperienceEditSheetState();
}

class _ExperienceEditSheetState extends State<ExperienceEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _companyController;
  late final TextEditingController _companyUrlController;
  late final TextEditingController _locationController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _descriptionController;
  late bool _isCurrent;

  String _previewLogoUrl = '';

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _titleController = TextEditingController(text: it?.title ?? '');
    _companyController = TextEditingController(text: it?.company ?? '');
    _companyUrlController = TextEditingController(text: it?.companyUrl ?? '');
    _locationController = TextEditingController(text: it?.location ?? '');
    _startDateController = TextEditingController(text: it?.startDate ?? '');
    _endDateController = TextEditingController(text: it?.endDate ?? '');
    _descriptionController = TextEditingController(text: it?.description ?? '');
    _isCurrent = it?.isCurrent ?? false;

    _updateLogoPreview(_companyUrlController.text);
    _companyUrlController.addListener(() {
      _updateLogoPreview(_companyUrlController.text);
    });
  }

  void _updateLogoPreview(String url) {
    final tempItem = ExperienceItem(
      id: '',
      title: '',
      company: '',
      companyUrl: url,
    );
    final logo = tempItem.companyLogoUrl;
    if (logo != _previewLogoUrl) {
      setState(() {
        _previewLogoUrl = logo;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _companyUrlController.dispose();
    _locationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final title = _titleController.text.trim();
    final company = _companyController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a role or job title')),
      );
      return;
    }
    if (company.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a company name')),
      );
      return;
    }

    HapticFeedback.lightImpact();

    final item = ExperienceItem(
      id: widget.item?.id ?? const Uuid().v4(),
      title: title,
      company: company,
      companyUrl: _companyUrlController.text.trim(),
      location: _locationController.text.trim(),
      startDate: _startDateController.text.trim(),
      endDate: _isCurrent ? 'Present' : _endDateController.text.trim(),
      isCurrent: _isCurrent,
      description: _descriptionController.text.trim(),
    );

    widget.onSave(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle Pill
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Experience' : 'Add Experience',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  if (isEditing && widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 22),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onDelete!();
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // Title / Role Field
              _buildTextField(
                controller: _titleController,
                label: 'Title / Role *',
                hint: 'e.g. Senior Software Engineer',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 14),

              // Company Field
              _buildTextField(
                controller: _companyController,
                label: 'Company / Organization *',
                hint: 'e.g. Stripe, Google, or Stealth',
                icon: Icons.business_rounded,
              ),
              const SizedBox(height: 14),

              // Company URL Field with Live Logo Preview
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _companyUrlController,
                      label: 'Company Website / Domain',
                      hint: 'e.g. stripe.com or google.com',
                      icon: Icons.link_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Logo Preview Container
                  Container(
                    width: 46,
                    height: 46,
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: context.surfaceSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: _previewLogoUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _previewLogoUrl,
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.business_rounded,
                                      size: 22, color: context.textSecondary),
                            ),
                          )
                        : Icon(Icons.domain_rounded,
                            size: 22, color: context.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Location Field
              _buildTextField(
                controller: _locationController,
                label: 'Location',
                hint: 'e.g. Bengaluru, India · Remote',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 14),

              // Dates Row
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _startDateController,
                      label: 'Start Date',
                      hint: 'e.g. Jan 2022',
                      icon: Icons.calendar_today_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _endDateController,
                      label: 'End Date',
                      hint: _isCurrent ? 'Present' : 'e.g. Dec 2023',
                      enabled: !_isCurrent,
                      icon: Icons.event_available_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Current Role Toggle
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _isCurrent,
                      activeColor: context.accentPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _isCurrent = val ?? false;
                          if (_isCurrent) {
                            _endDateController.text = 'Present';
                          } else {
                            _endDateController.clear();
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCurrent = !_isCurrent;
                        if (_isCurrent) {
                          _endDateController.text = 'Present';
                        } else {
                          _endDateController.clear();
                        }
                      });
                    },
                    child: Text(
                      'I currently work here',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Description Field
              _buildTextField(
                controller: _descriptionController,
                label: 'Description / Key Achievements',
                hint: 'What did you build, scale, or accomplish?',
                maxLines: 4,
                icon: Icons.notes_rounded,
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accentPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isEditing ? 'Update Experience' : 'Save Experience',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          style: TextStyle(
            color: enabled ? context.textPrimary : context.textMuted,
            fontSize: 14,
            fontFamily: 'Inter',
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: context.textMuted.withValues(alpha: 0.6),
              fontSize: 13.5,
            ),
            prefixIcon: maxLines == 1
                ? Icon(icon, size: 18, color: context.textSecondary)
                : null,
            filled: true,
            fillColor: context.surfaceSecondary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.accentPrimary.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class EducationEditSheet extends StatefulWidget {
  final EducationItem? item;
  final Function(EducationItem item) onSave;
  final VoidCallback? onDelete;

  const EducationEditSheet({
    super.key,
    this.item,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<EducationEditSheet> createState() => _EducationEditSheetState();
}

class _EducationEditSheetState extends State<EducationEditSheet> {
  late final TextEditingController _schoolController;
  late final TextEditingController _degreeController;
  late final TextEditingController _fieldController;
  late final TextEditingController _startYearController;
  late final TextEditingController _endYearController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _schoolController = TextEditingController(text: it?.school ?? '');
    _degreeController = TextEditingController(text: it?.degree ?? '');
    _fieldController = TextEditingController(text: it?.fieldOfStudy ?? '');
    _startYearController = TextEditingController(text: it?.startYear ?? '');
    _endYearController = TextEditingController(text: it?.endYear ?? '');
    _descriptionController = TextEditingController(text: it?.description ?? '');
  }

  @override
  void dispose() {
    _schoolController.dispose();
    _degreeController.dispose();
    _fieldController.dispose();
    _startYearController.dispose();
    _endYearController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final school = _schoolController.text.trim();
    if (school.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter school or university name')),
      );
      return;
    }

    HapticFeedback.lightImpact();

    final item = EducationItem(
      id: widget.item?.id ?? const Uuid().v4(),
      school: school,
      degree: _degreeController.text.trim(),
      fieldOfStudy: _fieldController.text.trim(),
      startYear: _startYearController.text.trim(),
      endYear: _endYearController.text.trim(),
      description: _descriptionController.text.trim(),
    );

    widget.onSave(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Education' : 'Add Education',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  if (isEditing && widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 22),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onDelete!();
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _buildInput(
                controller: _schoolController,
                label: 'School / University *',
                hint: 'e.g. Stanford University',
                icon: Icons.school_rounded,
              ),
              const SizedBox(height: 14),
              _buildInput(
                controller: _degreeController,
                label: 'Degree',
                hint: 'e.g. Bachelor of Science, B.Tech',
                icon: Icons.workspace_premium_rounded,
              ),
              const SizedBox(height: 14),
              _buildInput(
                controller: _fieldController,
                label: 'Field of Study',
                hint: 'e.g. Computer Science',
                icon: Icons.auto_stories_rounded,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildInput(
                      controller: _startYearController,
                      label: 'Start Year',
                      hint: 'e.g. 2018',
                      icon: Icons.calendar_today_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInput(
                      controller: _endYearController,
                      label: 'End Year (or Expected)',
                      hint: 'e.g. 2022',
                      icon: Icons.event_available_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInput(
                controller: _descriptionController,
                label: 'Activities / Notes',
                hint: 'Clubs, honors, or key highlights',
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accentPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isEditing ? 'Update Education' : 'Save Education',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 14,
            fontFamily: 'Inter',
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: context.textMuted.withValues(alpha: 0.6),
              fontSize: 13.5,
            ),
            prefixIcon: maxLines == 1
                ? Icon(icon, size: 18, color: context.textSecondary)
                : null,
            filled: true,
            fillColor: context.surfaceSecondary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.accentPrimary.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SkillsEditSheet extends StatefulWidget {
  final List<String> currentSkills;
  final Function(List<String> skills) onSave;

  const SkillsEditSheet({
    super.key,
    required this.currentSkills,
    required this.onSave,
  });

  @override
  State<SkillsEditSheet> createState() => _SkillsEditSheetState();
}

class _SkillsEditSheetState extends State<SkillsEditSheet> {
  late final List<String> _skills;
  final TextEditingController _inputController = TextEditingController();

  static const List<String> _popularSuggestions = [
    'Flutter',
    'React',
    'Product Management',
    'UI/UX Design',
    'System Architecture',
    'Python',
    'TypeScript',
    'AI / Machine Learning',
    'Growth Strategy',
    'PostgreSQL',
    'Figma',
    'Project Leadership',
  ];

  @override
  void initState() {
    super.initState();
    _skills = List.from(widget.currentSkills);
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _addSkill(String skill) {
    final trimmed = skill.trim();
    if (trimmed.isNotEmpty && !_skills.contains(trimmed)) {
      HapticFeedback.selectionClick();
      setState(() {
        _skills.add(trimmed);
      });
      _inputController.clear();
    }
  }

  void _removeSkill(String skill) {
    HapticFeedback.selectionClick();
    setState(() {
      _skills.remove(skill);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Skills & Superpowers',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 16),

              // Add Skill Input Bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: TextStyle(color: context.textPrimary, fontSize: 14),
                      onSubmitted: _addSkill,
                      decoration: InputDecoration(
                        hintText: 'Type a skill & tap Add (e.g. Flutter)...',
                        hintStyle: TextStyle(
                          color: context.textMuted.withValues(alpha: 0.6),
                          fontSize: 13.5,
                        ),
                        filled: true,
                        fillColor: context.surfaceSecondary,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _addSkill(_inputController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accentPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add',
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Current Selected Skills
              if (_skills.isNotEmpty) ...[
                Text(
                  'Your Skills (${_skills.length})',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skills.map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.accentPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.accentPrimary.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            skill,
                            style: TextStyle(
                              color: context.accentPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _removeSkill(skill),
                            child: Icon(
                              Icons.close_rounded,
                              size: 15,
                              color: context.accentPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // Popular Suggestions
              Text(
                'Suggestions',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _popularSuggestions
                    .where((s) => !_skills.contains(s))
                    .map((suggestion) {
                  return ActionChip(
                    label: Text(suggestion),
                    labelStyle: TextStyle(
                      color: context.textPrimary,
                      fontSize: 12.5,
                    ),
                    backgroundColor: context.surfaceSecondary,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    avatar: Icon(Icons.add,
                        size: 14, color: context.accentPrimary),
                    onPressed: () => _addSkill(suggestion),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Save Button
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onSave(_skills);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accentPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
