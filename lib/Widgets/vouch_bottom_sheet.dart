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
  final String? initialScope;
  final VoidCallback? onVouched;

  const VouchBottomSheet({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserAvatar = '',
    this.targetUserProfession = '',
    this.initialScope,
    this.onVouched,
  });

  static Future<void> show({
    required BuildContext context,
    required int targetUserId,
    required String targetUserName,
    String targetUserAvatar = '',
    String targetUserProfession = '',
    String? initialScope,
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
        initialScope: initialScope,
        onVouched: onVouched,
      ),
    );
  }

  @override
  State<VouchBottomSheet> createState() => _VouchBottomSheetState();
}

class _RelationshipTypeOption {
  final String title;
  final String description;
  final IconData icon;

  const _RelationshipTypeOption({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _IntentTagOption {
  final String label;
  final String hint;
  final IconData icon;

  const _IntentTagOption({
    required this.label,
    required this.hint,
    required this.icon,
  });
}

class _VouchBottomSheetState extends State<VouchBottomSheet> {
  // 1. Relationship Context Tags (Structural labels)
  static const List<_RelationshipTypeOption> _relationshipOptions = [
    _RelationshipTypeOption(
      title: "Fought in the trenches with",
      description: "Close teammates, co-founders, or engineers who shipped code together.",
      icon: Icons.offline_bolt_rounded,
    ),
    _RelationshipTypeOption(
      title: "Managed / Was managed by",
      description: "Explicitly clarify reporting lines and executive leadership relations.",
      icon: Icons.account_tree_rounded,
    ),
    _RelationshipTypeOption(
      title: "Backed / Funded",
      description: "Reserved for investor-to-founder relationship tracking.",
      icon: Icons.monetization_on_rounded,
    ),
    _RelationshipTypeOption(
      title: "Rising Star",
      description: "Flag junior talent or high-potential individuals early in their trajectory.",
      icon: Icons.auto_awesome_rounded,
    ),
  ];

  // 2. Private Intent Tags (Matching Mechanics)
  static const List<_IntentTagOption> _intentOptions = [
    _IntentTagOption(
      label: "Would Hire",
      hint: "Signal hiring interest confidentially",
      icon: Icons.work_outline_rounded,
    ),
    _IntentTagOption(
      label: "Would Fund",
      hint: "Signal investment interest confidentially",
      icon: Icons.payments_outlined,
    ),
    _IntentTagOption(
      label: "Would Work With",
      hint: "Signal collaboration & co-founding interest",
      icon: Icons.groups_outlined,
    ),
  ];

  String? _selectedRelationship;
  final Set<String> _selectedIntents = {};

  final TextEditingController _optionalNoteController = TextEditingController();

  late String _selectedScope; // 'inner_circle', 'network', 'global', 'profile_only'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialScope?.trim().toLowerCase();
    if (init == 'inner_circle' || init == 'network' || init == 'global' || init == 'profile_only') {
      _selectedScope = init!;
    } else {
      _selectedScope = 'inner_circle';
    }
  }

  @override
  void dispose() {
    _optionalNoteController.dispose();
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

    final hasRel = _selectedRelationship != null && _selectedRelationship!.isNotEmpty;
    final hasIntents = _selectedIntents.isNotEmpty;

    if (!hasRel && !hasIntents) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a relationship context or at least one private intent tag."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final optionalNote = _optionalNoteController.text.trim();

    // Pack into formatted statement backward compatible with raw string columns
    final statementBuffer = StringBuffer();
    if (hasRel) {
      statementBuffer.write("REL:[$_selectedRelationship]");
    }
    if (hasIntents) {
      if (statementBuffer.isNotEmpty) statementBuffer.write(" ");
      statementBuffer.write("INTENTS:[${_selectedIntents.join(', ')}]");
    }
    if (optionalNote.isNotEmpty) {
      if (statementBuffer.isNotEmpty) statementBuffer.write(" ");
      statementBuffer.write("NOTE:[$optionalNote]");
    }
    final formattedStatement = statementBuffer.isEmpty ? "VOUCH" : statementBuffer.toString();

    try {
      String? announcementPostId;
      final isConnected = connectionProvider.isConnected(widget.targetUserId);

      // Only publish public feed announcement if already connected and a public relationship context is chosen
      if (isConnected && hasRel && _selectedScope != 'profile_only') {
        try {
          final announcementDisplay = StringBuffer();
          announcementDisplay.write("Vouched for @${widget.targetUserName} as \"$_selectedRelationship\"");
          if (optionalNote.isNotEmpty) {
            announcementDisplay.write("\n\n\"$optionalNote\"");
          }

          final post = await feedProvider.createPost(
            announcementDisplay.toString(),
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
        statement: formattedStatement,
        feedScope: hasRel ? _selectedScope : 'profile_only',
        announcementPostId: announcementPostId,
        relationshipType: _selectedRelationship,
        privateIntents: _selectedIntents.toList(),
        optionalNote: optionalNote.isNotEmpty ? optionalNote : null,
      );

      AnalyticsService.logEvent(
        name: 'vouch_submitted',
        parameters: {
          'target_user_id': widget.targetUserId,
          'feed_scope': hasRel ? _selectedScope : 'profile_only',
          'relationship_type': _selectedRelationship ?? 'none',
          'private_intents_count': _selectedIntents.length,
          'has_note': optionalNote.isNotEmpty,
          'is_connected': isConnected,
        },
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onVouched?.call();
        final successMessage = isConnected
            ? (hasRel
                ? "You have officially vouched for ${widget.targetUserName}!"
                : "Confidential intent signaled for ${widget.targetUserName}!")
            : "Vouch & connection request sent to ${widget.targetUserName}!";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF18191D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            content: Row(
              children: [
                Icon(
                  isConnected
                      ? (hasRel ? Icons.verified_rounded : Icons.lock_outline_rounded)
                      : Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    successMessage,
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
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
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

              const SizedBox(height: 22),

              // Section 1: Relationship Type (High Stakes Structured Options)
              Row(
                children: [
                  Text(
                    "RELATIONSHIP CONTEXT",
                    style: context.captionText.copyWith(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      _selectedRelationship != null ? "SELECTED" : "OPTIONAL",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Relationship cards
              ..._relationshipOptions.map((opt) {
                final isSelected = _selectedRelationship == opt.title;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_selectedRelationship == opt.title) {
                          _selectedRelationship = null;
                        } else {
                          _selectedRelationship = opt.title;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.08)
                            : context.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.08),
                          width: isSelected ? 1.2 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                            ),
                            child: Icon(
                              opt.icon,
                              size: 18,
                              color: isSelected
                                  ? Colors.white
                                  : context.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opt.title,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : context.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  opt.description,
                                  style: TextStyle(
                                    color: context.textMuted,
                                    fontSize: 11.5,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Section 2: Private Intent Tags (Matching Mechanics)
              Row(
                children: [
                  Text(
                    "PRIVATE INTENT TAGS",
                    style: context.captionText.copyWith(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 10,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 3),
                        Text(
                          "CONFIDENTIAL",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Remains entirely hidden until a mutual match occurs.",
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _intentOptions.map((opt) {
                  final isSelected = _selectedIntents.contains(opt.label);
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          if (isSelected) {
                            _selectedIntents.remove(opt.label);
                          } else {
                            _selectedIntents.add(opt.label);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.12)
                              : context.surfaceSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.08),
                            width: isSelected ? 1.2 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle_rounded : opt.icon,
                              size: 15,
                              color: isSelected ? Colors.white : context.textSecondary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              opt.label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : context.textPrimary,
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Section 3: Optional Endorsement Note
              Text(
                "NOTE / SPECIFIC HIGHLIGHT (OPTIONAL)",
                style: context.captionText.copyWith(
                  color: context.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: context.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: TextField(
                  controller: _optionalNoteController,
                  maxLines: 2,
                  maxLength: 250,
                  style: TextStyle(color: context.textPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: "Add specific achievements or evidence if desired...",
                    hintStyle: TextStyle(
                      color: context.textMuted,
                      fontSize: 12.5,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                    counterStyle: TextStyle(
                      color: context.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (_selectedRelationship != null && _selectedRelationship!.isNotEmpty) ...[
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
                        id: 'inner_circle',
                        title: 'Inner Circle',
                        subtitle: 'Direct 1° only',
                        icon: Icons.people_alt_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildScopeOption(
                        id: 'network',
                        title: 'Network',
                        subtitle: '1° & 2° degree',
                        icon: Icons.hub_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildScopeOption(
                        id: 'global',
                        title: 'Global Feed',
                        subtitle: 'Everyone on Mandala',
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
              ] else if (_selectedIntents.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Private intent signals are 100% confidential. No public feed post will be created until mutual intent matches.",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Submit Button
              Builder(
                builder: (context) {
                  final hasRel = _selectedRelationship != null && _selectedRelationship!.isNotEmpty;
                  final hasIntents = _selectedIntents.isNotEmpty;
                  final canSubmit = !_isSubmitting && (hasRel || hasIntents);

                  String buttonLabel = "Confirm & Vouch";
                  if (!hasRel && hasIntents) {
                    buttonLabel = "Signal Private Intent";
                  }

                  return ElevatedButton(
                    onPressed: canSubmit ? _submitVouch : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canSubmit ? Colors.white : Colors.white.withValues(alpha: 0.10),
                      foregroundColor: canSubmit ? Colors.black : Colors.white38,
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.10),
                      disabledForegroundColor: Colors.white38,
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
                              Icon(
                                hasIntents && !hasRel
                                    ? Icons.lock_outline_rounded
                                    : Icons.verified_rounded,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                buttonLabel,
                                style: context.bodyText.copyWith(
                                  color: canSubmit ? Colors.black : Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                  );
                },
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.12)
              : context.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : context.textSecondary,
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
                color: isSelected ? Colors.white70 : context.textMuted,
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
