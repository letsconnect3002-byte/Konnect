import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/services/analytics_service.dart';
import 'package:connect/Widgets/anonymous_avatar.dart';

class DirectConnectionSheet extends StatefulWidget {
  final int targetUserId;
  final String targetUserName;
  final String targetUserAvatar;
  final String targetUserProfession;
  final bool isAnonymous;
  final VoidCallback? onRequestSent;

  const DirectConnectionSheet({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserAvatar = '',
    this.targetUserProfession = '',
    this.isAnonymous = false,
    this.onRequestSent,
  });

  static Future<void> show({
    required BuildContext context,
    required int targetUserId,
    required String targetUserName,
    String targetUserAvatar = '',
    String targetUserProfession = '',
    bool isAnonymous = false,
    VoidCallback? onRequestSent,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DirectConnectionSheet(
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        targetUserAvatar: targetUserAvatar,
        targetUserProfession: targetUserProfession,
        isAnonymous: isAnonymous,
        onRequestSent: onRequestSent,
      ),
    );
  }

  @override
  State<DirectConnectionSheet> createState() => _DirectConnectionSheetState();
}

class _DirectConnectionSheetState extends State<DirectConnectionSheet> {
  final TextEditingController _noteController = TextEditingController();
  String _selectedCard = 'casual'; // 'casual' or 'professional'
  bool _isSending = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Future<void> _sendRequest() async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
    });

    final notifProvider =
        Provider.of<NotificationProvider>(context, listen: false);

    try {
      await notifProvider.sendDirectConnectionRequest(
        toUserId: widget.targetUserId,
        sharedCard: _selectedCard,
        note: _noteController.text.trim(),
      );

      AnalyticsService.logEvent(
        name: 'direct_connection_request_sent',
        parameters: {
          'target_user_id': widget.targetUserId,
          'shared_card': _selectedCard,
          'has_note': _noteController.text.trim().isNotEmpty,
        },
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onRequestSent?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Connection request sent to ${widget.targetUserName}!",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: context.surfaceSecondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: context.accentPrimary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Failed to send request. Please try again."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimensions.marginStandard,
          right: AppDimensions.marginStandard,
          top: 16.0,
          bottom: 24.0 + bottomPadding,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Target user preview
              Row(
                children: [
                  widget.isAnonymous
                      ? AnonymousAvatar(
                          seed: widget.targetUserId != 0
                              ? widget.targetUserId.toString()
                              : widget.targetUserName,
                          radius: 23,
                        )
                      : Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.surfaceSecondary,
                            border: Border.all(
                              color: context.accentPrimary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: widget.targetUserAvatar.startsWith('http')
                                ? Image.network(
                                    widget.targetUserAvatar,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Center(
                                      child: Text(
                                        _getInitials(widget.targetUserName),
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      _getInitials(widget.targetUserName),
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.targetUserName,
                                style: context.screenHeading.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.accentPrimary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: context.accentPrimary.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.isAnonymous
                                        ? Icons.visibility_off_rounded
                                        : Icons.language_rounded,
                                    size: 10,
                                    color: context.accentSecondary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    widget.isAnonymous ? "Anonymous" : "Global",
                                    style: TextStyle(
                                      color: context.accentSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.targetUserProfession.isNotEmpty
                              ? widget.targetUserProfession
                              : "Member on Konnect",
                          style: context.bodyText.copyWith(
                            color: context.textSecondary,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.surfaceSecondary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Text(
                  widget.isAnonymous
                      ? "This author posted anonymously. If they accept your request, your real profile cards will be shared with each other."
                      : "You are not connected in any circle yet. Send a direct request to exchange profile cards and connect.",
                  style: context.bodyText.copyWith(
                    color: context.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Text(
                "CHOOSE CARD TO SHARE",
                style: context.captionText.copyWith(
                  color: context.textSecondary,
                  letterSpacing: 1.5,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),

              // Card Selector: Casual vs Professional
              _buildCardOption(
                title: "Casual Card",
                description: "Share bio, socials & casual contact details",
                icon: Icons.person_outline_rounded,
                value: 'casual',
              ),
              const SizedBox(height: 8),
              _buildCardOption(
                title: "Professional Card",
                description: "Share company, job title, work email & LinkedIn",
                icon: Icons.business_center_outlined,
                value: 'professional',
              ),

              const SizedBox(height: 20),
              Text(
                "LEAVE A NOTE (OPTIONAL)",
                style: context.captionText.copyWith(
                  color: context.textSecondary,
                  letterSpacing: 1.5,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                maxLines: 3,
                maxLength: 150,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                style: context.bodyText,
                cursorColor: context.accentSecondary,
                decoration: InputDecoration(
                  hintText: "Add a message to introduce yourself...",
                  hintStyle: context.bodyText
                      .copyWith(color: context.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: context.surfaceSecondary,
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusComponent),
                    borderSide: BorderSide(color: context.surfaceSecondary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusComponent),
                    borderSide: BorderSide(color: context.accentSecondary),
                  ),
                ),
              ),

              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _isSending ? null : _sendRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accentSecondary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      context.surfaceSecondary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusComponent),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            "Send Connection Request",
                            style: context.bodyText.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardOption({
    required String title,
    required String description,
    required IconData icon,
    required String value,
  }) {
    final bool isSelected = _selectedCard == value;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedCard = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? context.accentSecondary.withValues(alpha: 0.08)
              : context.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? context.accentSecondary
                : context.surfaceSecondary,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? context.accentSecondary.withValues(alpha: 0.15)
                    : context.surfacePrimary,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected
                    ? context.accentSecondary
                    : context.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? context.accentSecondary
                          : context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? context.accentSecondary
                      : context.textMuted.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.accentSecondary,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
