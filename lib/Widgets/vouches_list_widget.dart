import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/vouch_model.dart';
import 'package:connect/Providers/vouch_provider.dart';
import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Widgets/vouch_bottom_sheet.dart';

class VouchesListWidget extends StatefulWidget {
  final int userId;
  final String userName;
  final bool isOwnProfile;

  const VouchesListWidget({
    super.key,
    required this.userId,
    required this.userName,
    this.isOwnProfile = false,
  });

  @override
  State<VouchesListWidget> createState() => _VouchesListWidgetState();
}

class _VouchesListWidgetState extends State<VouchesListWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<VouchProvider>(context, listen: false)
            .loadVouches(widget.userId);
      }
    });
  }

  void _openVouchSheet(BuildContext context) {
    final pProvider = Provider.of<ProfileProvider>(context, listen: false);
    final myId = pProvider.userId;
    if (myId == null || widget.userId == 0 || myId == widget.userId) return;

    VouchBottomSheet.show(
      context: context,
      targetUserId: widget.userId,
      targetUserName: widget.userName,
      onVouched: () {
        if (mounted) {
          Provider.of<VouchProvider>(context, listen: false)
              .loadVouches(widget.userId);
        }
      },
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
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
  Widget build(BuildContext context) {
    final vouchProvider = Provider.of<VouchProvider>(context);
    final allVouches = vouchProvider.getVouchesFor(widget.userId);
    final List<UserVouch> vouches = allVouches.where((v) =>
        (v.relationshipType != null && v.relationshipType!.trim().isNotEmpty) ||
        (v.optionalNote != null && v.optionalNote!.trim().isNotEmpty)).toList();
    final bool isLoading = vouchProvider.isLoading(widget.userId);
    final String firstName = widget.userName.trim().split(RegExp(r'\s+')).first;

    if (isLoading && vouches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (vouches.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'VOUCHES (0)',
                style: TextStyle(
                  color: Color(0xFFA1A4B0),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'Inter',
                ),
              ),
              if (!widget.isOwnProfile)
                Consumer<ProfileProvider>(
                  builder: (context, pProvider, _) {
                    final myId = pProvider.userId;
                    final hasVouched = (myId != null && widget.userId != 0)
                        ? vouchProvider.hasVouchedFor(myId, widget.userId)
                        : false;
                    if (hasVouched) return const SizedBox.shrink();

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _openVouchSheet(context);
                      },
                      child: const Text(
                        '+ Vouch',
                        style: TextStyle(
                          color: Color(0xFF00F2FE),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1013),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00F2FE).withValues(alpha: 0.10),
                    border: Border.all(
                      color: const Color(0xFF00F2FE).withValues(alpha: 0.20),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF00F2FE),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "No vouches yet",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isOwnProfile
                      ? "When trusted connections back you, their endorsements will appear here."
                      : "Be the first to endorse $firstName's work, skills, and character on Jana.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFA1A4B0),
                    fontSize: 11.5,
                    height: 1.4,
                    fontFamily: 'Inter',
                  ),
                ),
                if (!widget.isOwnProfile) ...[
                  const SizedBox(height: 16),
                  Consumer<ProfileProvider>(
                    builder: (context, pProvider, _) {
                      final myId = pProvider.userId;
                      final hasVouched = (myId != null && widget.userId != 0)
                          ? vouchProvider.hasVouchedFor(myId, widget.userId)
                          : false;
                      if (hasVouched) return const SizedBox.shrink();

                      return ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _openVouchSheet(context);
                        },
                        icon: const Icon(Icons.add_rounded,
                            color: Colors.black, size: 16),
                        label: Text(
                          "Vouch for $firstName",
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'VOUCHES (${vouches.length})',
              style: const TextStyle(
                color: Color(0xFFA1A4B0),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontFamily: 'Inter',
              ),
            ),
            if (!widget.isOwnProfile)
              Consumer<ProfileProvider>(
                builder: (context, pProvider, _) {
                  final myId = pProvider.userId;
                  final hasVouched = (myId != null && widget.userId != 0)
                      ? vouchProvider.hasVouchedFor(myId, widget.userId)
                      : false;
                  if (hasVouched) return const SizedBox.shrink();

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _openVouchSheet(context);
                    },
                    child: const Text(
                      '+ Vouch',
                      style: TextStyle(
                        color: Color(0xFF00F2FE),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 10),

        // List of Vouchers
        ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: vouches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final vouch = vouches[index];
            return _buildVouchCard(context, vouch);
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildVouchCard(BuildContext context, UserVouch vouch) {
    final currentUserId =
        Provider.of<ProfileProvider>(context, listen: false).userId;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Voucher Info Header
          InkWell(
            onTap: () {
              if (vouch.voucherId != currentUserId) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConnectionProfilePage(
                      profileData: {
                        'id': vouch.voucherId,
                        'name': vouch.voucherName,
                        'avatarUrl': vouch.voucherAvatarUrl,
                        'avatar_url': vouch.voucherAvatarUrl,
                        'profession': vouch.voucherProfession,
                        'company': vouch.voucherCompany,
                      },
                    ),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.2,
                    ),
                  ),
                  child: ClipOval(
                    child: (vouch.voucherAvatarUrl.isNotEmpty &&
                            vouch.voucherAvatarUrl.startsWith('http'))
                        ? Image.network(
                            vouch.voucherAvatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildSmallInitials(vouch.voucherName),
                          )
                        : _buildSmallInitials(vouch.voucherName),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vouch.voucherName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (vouch.voucherProfession.isNotEmpty ||
                          vouch.voucherCompany.isNotEmpty) ...[
                        Text(
                          [
                            vouch.voucherProfession,
                            vouch.voucherCompany,
                          ].where((s) => s.isNotEmpty).join(' • '),
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  _formatTimeAgo(vouch.createdAt),
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Structured or Legacy Statement Body
          if (vouch.relationshipType != null && vouch.relationshipType!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              vouch.relationshipType!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (vouch.contextTag != null && vouch.contextTag!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vouch.contextTag!,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (vouch.optionalNote != null && vouch.optionalNote!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      "“${vouch.optionalNote!.trim()}”",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 2.0,
                  ),
                ),
              ),
              child: Text(
                "“${vouch.displayStatement}”",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallInitials(String name) {
    return Center(
      child: Text(
        _getInitials(name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
