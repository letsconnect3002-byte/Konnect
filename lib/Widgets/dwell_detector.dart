import 'dart:async';
import 'package:flutter/material.dart';

class DwellDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onDwell;
  final Duration dwellDuration;

  const DwellDetector({
    super.key,
    required this.child,
    required this.onDwell,
    this.dwellDuration = const Duration(milliseconds: 700),
  });

  @override
  State<DwellDetector> createState() => _DwellDetectorState();
}

class _DwellDetectorState extends State<DwellDetector> {
  Timer? _dwellTimer;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (!mounted || _hasTriggered) return;

    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.attached) {
      final size = renderObject.size;
      final position = renderObject.localToGlobal(Offset.zero);
      final screenHeight = MediaQuery.of(context).size.height;

      // Check if at least 40% of the item is within the visible screen bounds
      final top = position.dy;
      final bottom = position.dy + size.height;
      final isVisible = (top < screenHeight * 0.95 && bottom > screenHeight * 0.05);

      if (isVisible) {
        _dwellTimer ??= Timer(widget.dwellDuration, () {
          if (mounted && !_hasTriggered) {
            _hasTriggered = true;
            widget.onDwell();
          }
        });
      } else {
        _dwellTimer?.cancel();
        _dwellTimer = null;
      }
    }
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        _checkVisibility();
        return false;
      },
      child: widget.child,
    );
  }
}
