import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/custom_network.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/custom_network_provider.dart';
import 'package:connect/Providers/feed_provider.dart';

class CreateCustomNetworkSheet extends StatefulWidget {
  const CreateCustomNetworkSheet({super.key});

  static Future<CustomNetwork?> show(BuildContext context) {
    return showModalBottomSheet<CustomNetwork>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreateCustomNetworkSheet(),
    );
  }

  @override
  State<CreateCustomNetworkSheet> createState() =>
      _CreateCustomNetworkSheetState();
}

class _CreateCustomNetworkSheetState extends State<CreateCustomNetworkSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _memberSearchController = TextEditingController();

  String _selectedEmoji = '🌐';
  bool _isPrivate = true;
  bool _allowAnonymous = false;
  bool _isSubmitting = false;

  final Set<int> _selectedMemberIds = {};

  static const List<String> _emojiOptions = [
    '🌐', '🚀', '💡', '🎨', '☕', '🎮', '👥', '⚡', '🛡️', '💎', '🔥', '🧠'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a network name', style: AppTypography.bodyText),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final netProvider =
          Provider.of<CustomNetworkProvider>(context, listen: false);
      final feedProvider = Provider.of<FeedProvider>(context, listen: false);

      final newNetwork = await netProvider.createNetwork(
        name: name,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        iconEmoji: _selectedEmoji,
        colorHex: '#FFFFFF', // Default unified monochrome
        isPrivate: _isPrivate,
        allowAnonymous: _allowAnonymous,
        initialMemberIds: _selectedMemberIds.toList(),
      );

      // Automatically select and switch feed to the newly created network
      feedProvider.selectCustomNetwork(newNetwork);

      if (mounted) {
        Navigator.of(context).pop(newNetwork);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network "${newNetwork.name}" created!',
                style: AppTypography.bodyText.copyWith(color: Colors.white)),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create network: $e',
                style: AppTypography.bodyText.copyWith(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionProvider = Provider.of<ConnectionProvider>(context);
    final myConnections = connectionProvider.connections;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Filter connections if searching
    final memberQuery = _memberSearchController.text.trim().toLowerCase();
    final filteredConnections = myConnections.where((c) {
      if (memberQuery.isEmpty) return true;
      final name = (c['name']?.toString() ?? '').toLowerCase();
      return name.contains(memberQuery);
    }).toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: AppColors.borderSubtle,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.85),
              blurRadius: 36,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Standard Apple Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet Header with Title, Subtitle, and Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  // Squircle Preview Badge (Monochrome)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.borderSubtle,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _selectedEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Network',
                          style: AppTypography.screenHeading.copyWith(
                            fontSize: 19,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'A dedicated circle with private feed & members',
                          style: AppTypography.captionText.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Close Dismiss Button
                  BounceTap(
                    scaleDown: 0.90,
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.borderSubtle,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(
              height: 1,
              color: AppColors.borderSubtle,
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section: Network Name
                    _buildSectionHeader('NETWORK NAME'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'e.g. Founders Circle, Core Team, Weekend Crew',
                      icon: Icons.groups_rounded,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Section: Description (Optional)
                    _buildSectionHeader('DESCRIPTION (OPTIONAL)'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _descController,
                      hint: 'What is this network about?',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // Section: Icon Emoji Selector
                    _buildSectionHeader('ICON EMOJI'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 46,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _emojiOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final emoji = _emojiOptions[index];
                          final isSelected = _selectedEmoji == emoji;
                          return BounceTap(
                            scaleDown: 0.92,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedEmoji = emoji);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.borderSubtle,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Section: Access & Privacy Settings (No background box, just clean rows)
                    _buildSectionHeader('ACCESS & PERMISSIONS'),
                    const SizedBox(height: 6),
                    _buildSettingRow(
                      icon: _isPrivate ? Icons.lock_rounded : Icons.public_rounded,
                      title: _isPrivate ? 'Private Network' : 'Public Network',
                      subtitle: _isPrivate
                          ? 'Only invited & added members can view this feed'
                          : 'Anyone in the app can discover & view this feed',
                      value: _isPrivate,
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _isPrivate = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingRow(
                      icon: _allowAnonymous
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      title: 'Allow Anonymous Posts',
                      subtitle: _allowAnonymous
                          ? 'Members may publish posts & replies anonymously'
                          : 'All posts & replies must show member profiles',
                      value: _allowAnonymous,
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _allowAnonymous = val);
                      },
                    ),
                    const SizedBox(height: 22),

                    // Section: Direct Member Addition (No enclosing background container)
                    if (myConnections.isNotEmpty) ...[
                      _buildSectionHeader(
                        'ADD CONNECTIONS (${_selectedMemberIds.length})',
                      ),
                      const SizedBox(height: 8),

                      // Optional member quick filter
                      if (myConnections.length > 5) ...[
                        Container(
                          height: 38,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: TextField(
                            controller: _memberSearchController,
                            style: AppTypography.bodyText.copyWith(fontSize: 13),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search connections...',
                              hintStyle: AppTypography.bodyText.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Connection list rendered directly on the sheet canvas without boxed background
                      filteredConnections.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(18),
                              child: Center(
                                child: Text(
                                  'No connections match your search',
                                  style: AppTypography.captionText.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: filteredConnections.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, idx) {
                                  final conn = filteredConnections[idx];
                                  final connId = int.tryParse(
                                          conn['id']?.toString() ?? '0') ??
                                      0;
                                  final name =
                                      conn['name']?.toString() ?? 'User';
                                  final avatarUrl =
                                      conn['avatarUrl']?.toString() ??
                                          conn['avatar_url']?.toString() ??
                                          '';
                                  final isChecked =
                                      _selectedMemberIds.contains(connId);

                                  return BounceTap(
                                    scaleDown: 0.98,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        if (isChecked) {
                                          _selectedMemberIds.remove(connId);
                                        } else {
                                          _selectedMemberIds.add(connId);
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 17,
                                            backgroundColor:
                                                AppColors.surfaceSecondary,
                                            backgroundImage:
                                                avatarUrl.isNotEmpty
                                                    ? NetworkImage(avatarUrl)
                                                    : null,
                                            child: avatarUrl.isEmpty
                                                ? Text(
                                                    name.isNotEmpty
                                                        ? name[0].toUpperCase()
                                                        : '?',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: AppTypography.cardTitle
                                                  .copyWith(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 180),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isChecked
                                                  ? Colors.white
                                                  : AppColors.surfaceSecondary,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                              border: Border.all(
                                                color: isChecked
                                                    ? Colors.white
                                                    : AppColors.borderMuted,
                                              ),
                                            ),
                                            child: Text(
                                              isChecked ? 'Added' : '+ Add',
                                              style: TextStyle(
                                                color: isChecked
                                                    ? Colors.black
                                                    : AppColors.textPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                      const SizedBox(height: 24),
                    ],

                    // Primary Submit Button (High contrast pure white luxury button)
                    BounceTap(
                      scaleDown: 0.97,
                      onTap: _isSubmitting ? null : _handleCreate,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.15),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  'Create Network',
                                  style: AppTypography.cardTitle.copyWith(
                                    color: Colors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.captionText.copyWith(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.borderMuted,
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        autofocus: false,
        maxLines: maxLines,
        onChanged: onChanged,
        style: AppTypography.bodyText,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.bodyText.copyWith(
            color: AppColors.textMuted,
          ),
          prefixIcon: icon != null
              ? Icon(icon, size: 18, color: AppColors.textSecondary)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            color: value ? AppColors.textPrimary : AppColors.textMuted,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.captionText.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            activeThumbColor: Colors.black,
            activeTrackColor: Colors.white,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
