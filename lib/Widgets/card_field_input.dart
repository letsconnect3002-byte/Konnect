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
    if (!_focusNode.hasFocus) {
      // Lock field again if it has focus loss and contains data
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

    // Autofocus when edit mode is toggled on
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
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2030)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: const Color(0xFF8B5CF6), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.showToggles) ...[
                _CardToggle(
                  icon: Icons.person_outline_rounded,
                  isActive: assignment.casual,
                  onTap: () => provider.toggleFieldOnCard(
                      widget.fieldKey, ProfileCardType.casual),
                ),
                const SizedBox(width: 8),
                _CardToggle(
                  icon: Icons.work_outline_rounded,
                  isActive: assignment.professional,
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
                        style: TextStyle(
                          color: (widget.value ?? '').isNotEmpty
                              ? Colors.white
                              : Colors.white30,
                          fontSize: 15,
                        ),
                        maxLines: widget.maxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white38, size: 20),
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
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: const Color(0xFF8B5CF6),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 15,
                ),
                suffixIcon: isFilled
                    ? GestureDetector(
                        onTap: () {
                          if (isEditing) {
                            // Stop editing (lock it)
                            widget.onEditingChanged(false);
                            _focusNode.unfocus();
                          } else {
                            // Start editing
                            widget.onEditingChanged(true);
                          }
                        },
                        child: Icon(
                          isEditing
                              ? Icons.check_circle_outline_rounded
                              : Icons.edit_rounded,
                          color: isEditing
                              ? const Color(0xFF10B981)
                              : Colors.white24,
                          size: 18,
                        ),
                      )
                    : const Icon(
                        Icons.edit_rounded,
                        color: Colors.white24,
                        size: 16,
                      ),
                filled: true,
                fillColor: const Color(0xFF191A2A),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF8B5CF6),
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
        color: const Color(0xFF191A2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: child,
    );
  }
}

class _CardToggle extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _CardToggle({
    required this.icon,
    required this.isActive,
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
          color: isActive ? const Color(0xFF8B5CF6) : const Color(0xFF1C1D2A),
          border: Border.all(
            color: isActive
                ? const Color(0xFF8B5CF6)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isActive ? Colors.white : const Color(0xFF5C5E78),
        ),
      ),
    );
  }
}
