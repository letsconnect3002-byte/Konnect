import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:connect/Widgets/anonymous_avatar.dart';
import 'package:connect/main.dart';

class InAppNotificationBanner extends StatefulWidget {
  final int senderId;
  final String senderName;
  final String avatarUrl;
  final String message;
  final bool isAnonymous;
  final String? anonSeed;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const InAppNotificationBanner({
    super.key,
    required this.senderId,
    required this.senderName,
    required this.avatarUrl,
    required this.message,
    this.isAnonymous = false,
    this.anonSeed,
    required this.onDismiss,
    this.onTap,
  });

  static OverlayEntry? _currentOverlayEntry;
  static Timer? _autoDismissTimer;

  static void show({
    required OverlayState overlayState,
    required int senderId,
    required String senderName,
    required String avatarUrl,
    required String message,
    bool isAnonymous = false,
    String? anonSeed,
    VoidCallback? onTap,
  }) {
    // Dismiss any existing banner first
    dismiss();

    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: InAppNotificationBanner(
            senderId: senderId,
            senderName: senderName,
            avatarUrl: avatarUrl,
            message: message,
            isAnonymous: isAnonymous,
            anonSeed: anonSeed,
            onDismiss: () => dismiss(),
            onTap: onTap,
          ),
        ),
      ),
    );

    _currentOverlayEntry = overlayEntry;
    overlayState.insert(overlayEntry);
  }

  static void dismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    if (_currentOverlayEntry != null) {
      _currentOverlayEntry!.remove();
      _currentOverlayEntry = null;
    }
  }

  @override
  State<InAppNotificationBanner> createState() => _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();

    // Start auto-dismiss timer
    InAppNotificationBanner._autoDismissTimer =
        Timer(const Duration(seconds: 4), () {
      _dismissWithAnimation();
    });
  }

  Future<void> _dismissWithAnimation() async {
    if (mounted) {
      await _animationController.reverse();
    }
    widget.onDismiss();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.up,
          onDismissed: (_) {
            InAppNotificationBanner._autoDismissTimer?.cancel();
            widget.onDismiss();
          },
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _dismissWithAnimation();
              if (widget.onTap != null) {
                widget.onTap!();
              } else {
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) =>
                        IndividualChatPage(otherUserId: widget.senderId),
                  ),
                );
              }
            },
            child: GlassmorphicContainer(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Sender Avatar
                  widget.isAnonymous
                      ? AnonymousAvatar(
                          seed: widget.anonSeed ?? widget.senderName,
                          radius: 21,
                        )
                      : Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: widget.avatarUrl.isNotEmpty
                                ? Image.network(
                                    widget.avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildAvatarFallback(),
                                  )
                                : _buildAvatarFallback(),
                          ),
                        ),
                  const SizedBox(width: 12),
                  // Sender Name and Message Snippet
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.senderName,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.message,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Close Icon
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.textMuted,
                      size: 18,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _dismissWithAnimation();
                    },
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    final String initial = widget.senderName.isNotEmpty
        ? widget.senderName.substring(0, 1).toUpperCase()
        : "?";
    return Container(
      color: context.surfaceSecondary,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: context.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
