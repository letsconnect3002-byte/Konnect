import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Providers/vouch_provider.dart';
import 'package:connect/services/analytics_service.dart';

class VouchBottomSheet extends StatefulWidget {
  final int targetUserId;
  final String targetUserName;
  final String targetUserAvatar;
  final String targetUserProfession;
  final VoidCallback? onVouched;

  const VouchBottomSheet({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserAvatar = '',
    this.targetUserProfession = '',
    this.onVouched,
  });

  static Future<void> show({
    required BuildContext context,
    required int targetUserId,
    required String targetUserName,
    String targetUserAvatar = '',
    String targetUserProfession = '',
    VoidCallback? onVouched,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => VouchBottomSheet(
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        targetUserAvatar: targetUserAvatar,
        targetUserProfession: targetUserProfession,
        onVouched: onVouched,
      ),
    );
  }

  @override
  State<VouchBottomSheet> createState() => _VouchBottomSheetState();
}

class _VouchBottomSheetState extends State<VouchBottomSheet> {
  final TextEditingController _statementController = TextEditingController();
  String _selectedScope = 'network'; // 'network', 'global', 'profile_only'
  bool _isSubmitting = false;

  @override
  void dispose() {
    _statementController.dispose();
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

  Future<void> _submitVouch() async {
    final statement = _statementController.text.trim();
    if (statement.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please write a short statement (at least 5 characters)."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    final vouchProvider = Provider.of<VouchProvider>(context, listen: false);

    final int? myUserId = profileProvider.userId;
    if (myUserId == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      String? announcementPostId;

      // If user chose to broadcast to network or global feed
      if (_selectedScope != 'profile_only') {
        final postContent =
            "Vouched for @${widget.targetUserName}\n\n\"$statement\"";

        try {
          final post = await feedProvider.createPost(
            postContent,
            authorName: profileProvider.name,
            authorAvatarUrl: profileProvider.avatarUrl,
            connections: connectionProvider.connections,
            visibility: 'both',
            isAnonymous: false,
            feedScope: _selectedScope,
          );
          announcementPostId = post.id;
        } catch (e) {
          debugPrint("Error publishing vouch announcement post: $e");
        }
      }

      await vouchProvider.submitVouch(
        voucherId: myUserId,
        voucheeId: widget.targetUserId,
        statement: statement,
        feedScope: _selectedScope,
        announcementPostId: announcementPostId,
      );

      AnalyticsService.logEvent(
        name: 'vouch_submitted',
        parameters: {
          'target_user_id': widget.targetUserId,
          'feed_scope': _selectedScope,
          'char_count': statement.length,
        },
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onVouched?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "You have officially vouched for ${widget.targetUserName}!",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error submitting vouch: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to submit vouch: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
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

              // Target User Info
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF59E0B),
                        width: 2.0,
                      ),
                    ),
                    child: ClipOval(
                      child: (widget.targetUserAvatar.isNotEmpty &&
                              widget.targetUserAvatar.startsWith('http'))
                          ? Image.network(
                              widget.targetUserAvatar,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                            )
                          : _buildAvatarFallback(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.targetUserName,
                          style: context.screenHeading.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.targetUserProfession.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.targetUserProfession,
                            style: context.captionText.copyWith(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Statement Input Label
              Text(
                "WHY DO YOU VOUCH FOR THEM?",
                style: context.captionText.copyWith(
                  color: context.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // Statement TextField
              Container(
                decoration: BoxDecoration(
                  color: context.surfaceSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: TextField(
                  controller: _statementController,
                  maxLines: 3,
                  maxLength: 300,
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText:
                        "e.g. Exceptional builder, brilliant work ethic, one of the sharpest founders I've worked with...",
                    hintStyle: TextStyle(
                      color: context.textMuted,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                    border: InputBorder.none,
                    counterStyle: TextStyle(
                      color: context.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Broadcast Scope Selector
              Text(
                "ANNOUNCE TO",
                style: context.captionText.copyWith(
                  color: context.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _buildScopeOption(
                      id: 'network',
                      title: 'Private Network',
                      subtitle: '1st & 2nd degree',
                      icon: Icons.hub_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildScopeOption(
                      id: 'global',
                      title: 'Global Feed',
                      subtitle: 'Everyone on Jana',
                      icon: Icons.public_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildScopeOption(
                      id: 'profile_only',
                      title: 'Profile Only',
                      subtitle: 'No feed post',
                      icon: Icons.badge_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitVouch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Confirm & Vouch",
                            style: context.bodyText.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
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

  Widget _buildScopeOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedScope == id;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedScope = id);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
              : context.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF59E0B)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFFF59E0B) : context.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : context.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 9.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Center(
      child: Text(
        _getInitials(widget.targetUserName),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
