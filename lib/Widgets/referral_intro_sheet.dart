import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Config/feature_config.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/services/analytics_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Widgets/horizontal_connection_map.dart';

class ReferralIntroSheet extends StatefulWidget {
  final int targetUserId;
  final String targetUserName;
  final int degree;

  const ReferralIntroSheet({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.degree = 2,
  });

  static Future<void> show({
    required BuildContext context,
    required int targetUserId,
    required String targetUserName,
    int degree = 2,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ReferralIntroSheet(
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        degree: degree,
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
    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    try {
      List<Map<String, dynamic>> list =
          await feedProvider.fetchMutualConnections(widget.targetUserId);
      if (list.isEmpty && connectionProvider.connections.isNotEmpty) {
        list = connectionProvider.connections
            .map((c) => {
                  'mutual_user_id': c['id'] ?? c['connection_profile_id'],
                  'mutual_name': c['name'] ?? 'Connection',
                  'mutual_avatar_url': c['avatarUrl'] ?? c['avatar_url'] ?? '',
                  'profession': c['profession'] ?? '',
                })
            .toList();
      }

      if (widget.degree == 3) {
        final client = Supabase.instance.client;
        for (var m in list) {
          final id = m['mutual_user_id'] is int
              ? m['mutual_user_id'] as int
              : int.tryParse(m['mutual_user_id'].toString());
          if (id != null) {
            try {
              final res = await client.rpc('get_mutual_connections', params: {
                'p_viewer_id': id,
                'p_target_id': widget.targetUserId,
              }) as List?;
              if (res != null && res.isNotEmpty) {
                m['intermediary_name'] = res.first['mutual_name']?.toString();
                m['intermediary_avatar'] =
                    res.first['mutual_avatar_url']?.toString();
              }
            } catch (e) {
              debugPrint("Error fetching RPC mutuals for $id: $e");
            }
          }
        }
      }

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
          if (connectionProvider.connections.isNotEmpty) {
            _mutuals = connectionProvider.connections
                .map((c) => {
                      'mutual_user_id': c['id'] ?? c['connection_profile_id'],
                      'mutual_name': c['name'] ?? 'Connection',
                      'mutual_avatar_url':
                          c['avatarUrl'] ?? c['avatar_url'] ?? '',
                      'profession': c['profession'] ?? '',
                    })
                .toList();
            if (_mutuals.isNotEmpty) {
              _selectedMutualId = _mutuals.first['mutual_user_id'] is int
                  ? _mutuals.first['mutual_user_id'] as int
                  : int.tryParse(_mutuals.first['mutual_user_id'].toString());
            }
          }
          _isLoading = false;
        });

        if (_selectedMutualId != null && widget.degree == 3) {
          _enrichIntermediaryForSelected(_selectedMutualId!);
        }
      }
    }
  }

  Future<void> _enrichIntermediaryForSelected(int mutualId) async {
    try {
      final client = Supabase.instance.client;
      final res = await client.rpc('get_mutual_connections', params: {
        'p_viewer_id': mutualId,
        'p_target_id': widget.targetUserId,
      }) as List?;

      if (res != null && res.isNotEmpty) {
        final firstInter = res.first;
        final interName = firstInter['mutual_name']?.toString();
        final interAvatar = firstInter['mutual_avatar_url']?.toString();
        if (mounted && interName != null && interName.isNotEmpty) {
          setState(() {
            final updatedList = List<Map<String, dynamic>>.from(_mutuals);
            for (var m in updatedList) {
              final id = m['mutual_user_id'] is int
                  ? m['mutual_user_id'] as int
                  : int.tryParse(m['mutual_user_id'].toString());
              if (id == mutualId) {
                m['intermediary_name'] = interName;
                m['intermediary_avatar'] = interAvatar ?? '';
              }
            }
            _mutuals = updatedList;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching intermediary from backend: $e");
    }
  }

  Future<void> _sendRequest() async {
    if (_selectedMutualId == null || _isSending) return;
    setState(() {
      _isSending = true;
    });

    final notifProvider =
        Provider.of<NotificationProvider>(context, listen: false);

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
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  "Introduction requests sent!",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: context.textPrimary),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF7C3AED),
            behavior: SnackBarBehavior.floating,
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final bool is3rdDegreeDisabled =
        widget.degree == 3 && !FeatureConfig.enable3rdDegreeInteraction;
    final bool isButtonEnabled =
        _selectedMutualId != null && !_isSending && !is3rdDegreeDisabled;

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
              Text(
                "Connect with ${widget.targetUserName}",
                style: context.screenHeading.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.degree == 3
                    ? "This user is a 3rd-degree connection in your circle. Request an introduction through a mutual friend:"
                    : "Ask your mutual connections to introduce you to ${widget.targetUserName}.",
                style: context.bodyText.copyWith(
                  color: context.textSecondary,
                  fontSize: 12.5,
                ),
                textAlign: TextAlign.center,
              ),
              HorizontalConnectionMap(
                selectedMutual: _selectedMutualId != null
                    ? _mutuals.firstWhere(
                        (m) {
                          final id = m['mutual_user_id'] is int
                              ? m['mutual_user_id'] as int
                              : int.tryParse(m['mutual_user_id'].toString()) ??
                                  0;
                          return id == _selectedMutualId;
                        },
                        orElse: () => _mutuals.isNotEmpty
                            ? _mutuals.first
                            : <String, dynamic>{},
                      )
                    : null,
                targetName: widget.targetUserName,
                degree: widget.degree,
              ),
              const SizedBox(height: 12),
              Text(
                "SELECT MUTUAL CONNECTIONS",
                style: context.captionText.copyWith(
                  color: context.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                    ),
                  ),
                )
              else if (_mutuals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "No direct mutual connections found to introduce you.",
                    style: context.bodyText.copyWith(
                      color: context.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.25,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _mutuals.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _mutuals[index];
                      final int id = item['mutual_user_id'] is int
                          ? item['mutual_user_id'] as int
                          : int.tryParse(item['mutual_user_id'].toString()) ??
                              0;
                      final String name =
                          item['mutual_name']?.toString() ?? 'Mutual Friend';
                      final String avatar =
                          item['mutual_avatar_url']?.toString() ?? '';
                      final String profession =
                          item['profession']?.toString() ?? '';
                      final bool isSelected = (_selectedMutualId == id);

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedMutualId = id;
                          });
                          if (widget.degree == 3) {
                            _enrichIntermediaryForSelected(id);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.accentSecondary
                                    .withValues(alpha: 0.08)
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
                                  color: context.surfacePrimary,
                                ),
                                child: ClipOval(
                                  child: avatar.startsWith('http')
                                      ? Image.network(
                                          avatar,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Center(
                                            child: Text(
                                              _getInitials(name),
                                              style: TextStyle(
                                                color: context.textPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            _getInitials(name),
                                            style: TextStyle(
                                              color: context.textPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: context.bodyText.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : context.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (profession.isNotEmpty)
                                      Text(
                                        profession,
                                        style: context.captionText.copyWith(
                                          color: context.textSecondary,
                                          fontWeight: FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isSelected
                                    ? context.accentSecondary
                                    : context.textMuted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                "LEAVE A NOTE (OPTIONAL)",
                style: context.captionText.copyWith(
                  color: context.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                maxLines: 3,
                maxLength: 69,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                style: context.bodyText,
                cursorColor: context.accentSecondary,
                decoration: InputDecoration(
                  hintText:
                      "Add a note asking for an introduction to ${widget.targetUserName}...",
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isButtonEnabled ? _sendRequest : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accentSecondary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      context.surfaceSecondary.withValues(alpha: 0.5),
                  disabledForegroundColor: context.textMuted,
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
                    : Text(
                        is3rdDegreeDisabled
                            ? "3rd Degree Introductions — Coming Soon"
                            : "Request Introduction",
                        style: context.bodyText.copyWith(
                          fontWeight: FontWeight.bold,
                          color: !isButtonEnabled
                              ? context.textMuted
                              : Colors.white,
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
