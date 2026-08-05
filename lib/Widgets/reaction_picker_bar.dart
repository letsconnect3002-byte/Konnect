import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/Config/app_theme.dart';

class ReactionOption {
  final String key;
  final String emoji;
  final String label;

  const ReactionOption({
    required this.key,
    required this.emoji,
    required this.label,
  });
}

class ReactionPickerBar extends StatefulWidget {
  final String? activeReaction;
  final ValueChanged<String> onSelectReaction;

  static const List<ReactionOption> options = [
    ReactionOption(key: 'like', emoji: '❤️', label: 'Like'),
    ReactionOption(key: 'fire', emoji: '🔥', label: 'Fire'),
    ReactionOption(key: 'clap', emoji: '👏', label: 'Clap'),
    ReactionOption(key: 'laugh', emoji: '😂', label: 'Haha'),
    ReactionOption(key: 'mindblown', emoji: '🤯', label: 'Wow'),
    ReactionOption(key: 'insight', emoji: '💡', label: 'Insight'),
  ];

  const ReactionPickerBar({
    super.key,
    this.activeReaction,
    required this.onSelectReaction,
  });

  static Future<void> show({
    required BuildContext context,
    required Rect targetRect,
    String? activeReaction,
    required ValueChanged<String> onSelectReaction,
  }) async {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _ReactionPickerOverlay(
        targetRect: targetRect,
        activeReaction: activeReaction,
        onSelect: (selectedKey) {
          entry.remove();
          onSelectReaction(selectedKey);
        },
        onDismiss: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }

  @override
  State<ReactionPickerBar> createState() => _ReactionPickerBarState();
}

class _ReactionPickerBarState extends State<ReactionPickerBar> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: context.surfaceSecondary.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: context.borderMuted.withValues(alpha: 0.8),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(ReactionPickerBar.options.length, (index) {
              final option = ReactionPickerBar.options[index];
              final isHovered = _hoveredIndex == index;
              final isActive = widget.activeReaction == option.key;

              final double scale = isHovered ? 1.35 : (isActive ? 1.15 : 1.0);

              return MouseRegion(
                onEnter: (_) => setState(() => _hoveredIndex = index),
                onExit: (_) => setState(() => _hoveredIndex = null),
                child: GestureDetector(
                  onTapDown: (_) {
                    HapticFeedback.mediumImpact();
                    widget.onSelectReaction(option.key);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.diagonal3Values(scale, scale, 1.0),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 150),
                      style: TextStyle(
                        fontSize: isHovered ? 26 : 22,
                      ),
                      child: Text(option.emoji),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ReactionPickerOverlay extends StatefulWidget {
  final Rect targetRect;
  final String? activeReaction;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;

  const _ReactionPickerOverlay({
    required this.targetRect,
    this.activeReaction,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_ReactionPickerOverlay> createState() => _ReactionPickerOverlayState();
}

class _ReactionPickerOverlayState extends State<_ReactionPickerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismissWithAnim([String? selectedKey]) async {
    await _controller.reverse();
    if (selectedKey != null) {
      widget.onSelect(selectedKey);
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const double barWidth = 260.0;
    const double barHeight = 52.0;

    double left = widget.targetRect.left - 10;
    if (left + barWidth > screenSize.width - 16) {
      left = screenSize.width - barWidth - 16;
    }
    if (left < 16) left = 16;

    double top = widget.targetRect.top - barHeight - 10;
    if (top < MediaQuery.of(context).padding.top + 10) {
      top = widget.targetRect.bottom + 10;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _dismissWithAnim(),
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnim.value,
                alignment: Alignment.bottomLeft,
                child: Opacity(
                  opacity: _fadeAnim.value,
                  child: ReactionPickerBar(
                    activeReaction: widget.activeReaction,
                    onSelectReaction: (selectedKey) => _dismissWithAnim(selectedKey),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
