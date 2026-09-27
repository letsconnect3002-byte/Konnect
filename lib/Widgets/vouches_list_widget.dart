import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/vouch_model.dart';
import 'package:connect/Providers/vouch_provider.dart';
import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:connect/Providers/profile_provider.dart';

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
    final List<UserVouch> vouches = vouchProvider.getVouchesFor(widget.userId);
    final bool isLoading = vouchProvider.isLoading(widget.userId);

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
      if (widget.isOwnProfile) {
        return Container(
          margin: const EdgeInsets.only(top: 8, bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfacePrimary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: context.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "No vouches yet",
                      style: context.bodyText.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "When trusted connections back you, their endorsements will appear here.",
                      style: context.captionText.copyWith(
                        color: context.textMuted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: context.textSecondary,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  'VOUCHES (${vouches.length})',
                  style: context.captionText.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

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
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
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

          // Statement Body
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
              "“${vouch.statement}”",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
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
