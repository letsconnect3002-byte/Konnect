import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/profile_card_type.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Edit field styled like the reference mockup with Casual / Professional toggles.
class CardFieldInput extends StatefulWidget {
  final String fieldKey;
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final String? value;
  final ValueChanged<String>? onChanged;
  final TextInputType keyboardType;
  final int maxLines;
  final VoidCallback? onTap;
  final bool showToggles;

  final bool isEditing;
  final ValueChanged<bool> onEditingChanged;

  const CardFieldInput({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.icon,
    this.controller,
    this.value,
    this.onChanged,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.onTap,
    this.showToggles = true,
    required this.isEditing,
    required this.onEditingChanged,
  });

  @override
  State<CardFieldInput> createState() => _CardFieldInputState();
}

class _CardFieldInputState extends State<CardFieldInput> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      if (!widget.isEditing) {
        widget.onEditingChanged(true);
      }
    } else {
      if (widget.isEditing) {
        widget.onEditingChanged(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final assignment = provider.fieldAssignments[widget.fieldKey] ??
        FieldCardAssignment(casual: false, professional: true);

    final isEditing = widget.isEditing;
    final isFilled = (widget.controller?.text ?? '').isNotEmpty;
    final readOnly = isFilled && !isEditing;

    if (isEditing && !_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
        border: Border.all(color: context.textMuted.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: context.accentSecondary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: context.bodyText.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.showToggles) ...[
                _CardToggle(
                  icon: Icons.person_outline_rounded,
                  isActive: assignment.casual,
                  activeColor: context.accentSecondary,
                  onTap: () => provider.toggleFieldOnCard(
                      widget.fieldKey, ProfileCardType.casual),
                ),
                const SizedBox(width: 8),
                _CardToggle(
                  icon: Icons.work_outline_rounded,
                  isActive: assignment.professional,
                  activeColor: context.accentSecondary,
                  onTap: () => provider.toggleFieldOnCard(
                      widget.fieldKey, ProfileCardType.professional),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (widget.onTap != null)
            GestureDetector(
              onTap: widget.onTap,
              child: _InputShell(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (widget.value ?? '').isNotEmpty
                            ? widget.value!
                            : widget.hint,
                        style: context.bodyText.copyWith(
                          color: (widget.value ?? '').isNotEmpty
                              ? context.textPrimary
                              : context.textMuted,
                        ),
                        maxLines: widget.maxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: context.textMuted, size: 20),
                  ],
                ),
              ),
            )
          else
            TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              readOnly: readOnly,
              onChanged: widget.onChanged,
              keyboardType: widget.keyboardType,
              maxLines: widget.maxLines,
              style: context.bodyText.copyWith(color: context.textPrimary),
              cursorColor: context.accentPrimary,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: context.bodyText.copyWith(
                  color: context.textMuted,
                ),
                suffixIcon: isFilled
                    ? GestureDetector(
                        onTap: () {
                          if (isEditing) {
                            widget.onEditingChanged(false);
                            _focusNode.unfocus();
                          } else {
                            widget.onEditingChanged(true);
                          }
                        },
                        child: Icon(
                          isEditing
                              ? Icons.check_circle_outline_rounded
                              : Icons.edit_rounded,
                          color: isEditing
                              ? const Color(0xFF10B981)
                              : context.textMuted,
                          size: 18,
                        ),
                      )
                    : Icon(
                        Icons.edit_rounded,
                        color: context.textMuted,
                        size: 16,
                      ),
                filled: true,
                fillColor: context.surfaceSecondary,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusComponent),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusComponent),
                  borderSide: BorderSide(
                    color: context.textMuted.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusComponent),
                  borderSide: BorderSide(
                    color: context.accentSecondary,
                    width: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InputShell extends StatelessWidget {
  final Widget child;

  const _InputShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
        border: Border.all(color: context.textMuted.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }
}

class _CardToggle extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _CardToggle({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? activeColor : context.surfaceSecondary,
          border: Border.all(
            color: isActive
                ? activeColor
                : context.textMuted.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isActive ? Colors.white : context.textMuted,
        ),
      ),
    );
  }
}
