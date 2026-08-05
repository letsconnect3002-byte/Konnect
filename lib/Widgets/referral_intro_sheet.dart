import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/services/analytics_service.dart';

class ReferralIntroSheet extends StatefulWidget {
  final int targetUserId;
  final String targetUserName;

  const ReferralIntroSheet({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  static Future<void> show({
    required BuildContext context,
    required int targetUserId,
    required String targetUserName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReferralIntroSheet(
        targetUserId: targetUserId,
        targetUserName: targetUserName,
      ),
    );
  }

  @override
  State<ReferralIntroSheet> createState() => _ReferralIntroSheetState();
}

class _ReferralIntroSheetState extends State<ReferralIntroSheet> {
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _mutuals = [];
  int? _selectedMutualId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchMutuals();
  }

  Future<void> _fetchMutuals() async {
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    try {
      final list = await feedProvider.fetchMutualConnections(widget.targetUserId);
      if (mounted) {
        setState(() {
          _mutuals = list;
          if (_mutuals.isNotEmpty) {
            _selectedMutualId = _mutuals.first['mutual_user_id'] is int
                ? _mutuals.first['mutual_user_id'] as int
                : int.tryParse(_mutuals.first['mutual_user_id'].toString());
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendRequest() async {
    if (_selectedMutualId == null || _isSending) return;
    setState(() {
      _isSending = true;
    });

    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);

    try {
      await notifProvider.sendReferralRequest(
        toUserId: _selectedMutualId!,
        referredUserId: widget.targetUserId,
        note: _noteController.text.trim(),
      );

      AnalyticsService.logEvent(
        name: 'referral_intro_requested',
        parameters: {
          'target_user_id': widget.targetUserId,
          'selected_mutual_id': _selectedMutualId!,
          'has_note': _noteController.text.trim().isNotEmpty,
        },
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Referral introduction request sent to your mutual friend! ✨"),
            backgroundColor: context.accentPrimary,
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
            content: Text("Failed to send referral request. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 16),
          Text(
            "Connect with ${widget.targetUserName}",
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "This user is a 2nd-degree connection in your circle. Request an introduction through a mutual friend:",
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_mutuals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                "No direct mutual connections found to introduce you.",
                style: TextStyle(color: context.textMuted, fontSize: 13),
              ),
            )
          else ...[
            Text(
              "Select Mutual Friend to Ask for Intro:",
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: context.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _mutuals.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                itemBuilder: (context, index) {
                  final item = _mutuals[index];
                  final int id = item['mutual_user_id'] is int
                      ? item['mutual_user_id'] as int
                      : int.tryParse(item['mutual_user_id'].toString()) ?? 0;
                  final String name = item['mutual_name']?.toString() ?? 'Mutual Friend';
                  final String avatar = item['mutual_avatar_url']?.toString() ?? '';
                  final bool isSelected = (_selectedMutualId == id);

                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      dense: true,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedMutualId = id;
                        });
                      },
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: context.surfaceSecondary,
                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty
                            ? Text(name.substring(0, 1).toUpperCase(),
                                style: TextStyle(color: context.textPrimary, fontSize: 11))
                            : null,
                      ),
                      title: Text(name, style: TextStyle(color: context.textPrimary, fontSize: 14)),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded, color: context.accentPrimary, size: 20)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              maxLines: 2,
              style: TextStyle(color: context.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Add an optional recommendation note for your friend...",
                hintStyle: TextStyle(color: context.textMuted, fontSize: 12),
                filled: true,
                fillColor: context.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: (_selectedMutualId != null && !_isSending) ? _sendRequest : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accentPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        "Send Referral Intro Request",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
