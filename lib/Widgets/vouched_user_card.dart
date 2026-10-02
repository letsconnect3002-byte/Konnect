import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Widgets/user_profile_modal.dart';

class _VouchCardData {
  final int voucheeId;
  final String voucheeName;
  final String voucheeAvatarUrl;
  final String voucheeProfession;
  final String voucheeCompany;
  final String? relationshipType;
  final String? optionalNote;
  final String? statement;
  final int totalVouchesCount;
  final Map<String, dynamic> fullProfile;

  const _VouchCardData({
    required this.voucheeId,
    required this.voucheeName,
    required this.voucheeAvatarUrl,
    required this.voucheeProfession,
    required this.voucheeCompany,
    this.relationshipType,
    this.optionalNote,
    this.statement,
    required this.totalVouchesCount,
    required this.fullProfile,
  });
}

class VouchedUserCard extends StatefulWidget {
  final String postId;
  final String postContent;

  const VouchedUserCard({
    super.key,
    required this.postId,
    required this.postContent,
  });

  @override
  State<VouchedUserCard> createState() => _VouchedUserCardState();
}

class _VouchedUserCardState extends State<VouchedUserCard> {
  static final Map<String, _VouchCardData> _cache = {};

  _VouchCardData? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVouchData();
  }

  @override
  void didUpdateWidget(covariant VouchedUserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId ||
        oldWidget.postContent != widget.postContent) {
      _loadVouchData();
    }
  }

  Future<void> _loadVouchData() async {
    final cached = _cache[widget.postId];
    if (cached != null) {
      if (mounted) {
        setState(() {
          _data = cached;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      int? voucheeId;
      Map<String, dynamic>? profile;
      String? relationshipType;
      String? optionalNote;
      String? statement;

      // 1. Try finding in user_vouches by announcement_post_id
      try {
        final res = await Supabase.instance.client
            .from('user_vouches')
            .select('*, profiles!vouchee_id(id, name, avatar_url, profession, company)')
            .eq('announcement_post_id', widget.postId)
            .maybeSingle();

        if (res != null) {
          voucheeId = res['vouchee_id'] is int
              ? res['vouchee_id'] as int
              : int.tryParse(res['vouchee_id']?.toString() ?? '');
          if (res['profiles'] is Map) {
            profile = Map<String, dynamic>.from(res['profiles']);
          }
          relationshipType = res['relationship_type']?.toString();
          optionalNote = res['optional_note']?.toString();
          statement = res['statement']?.toString();
        }
      } catch (e) {
        debugPrint("Error looking up vouch by post ID: $e");
      }

      // 2. Fallback: extract @Name and relationship from post content
      if (voucheeId == null || profile == null) {
        final match = RegExp(r'(?:⭐\s*)?Vouched for @([^\n\r"]+?)(?:\s+as\s+|\n|$)')
            .firstMatch(widget.postContent);
        if (match != null) {
          final rawName = match.group(1)?.trim();
          if (rawName != null && rawName.isNotEmpty) {
            try {
              final found = await Supabase.instance.client
                  .from('profiles')
                  .select('id, name, avatar_url, profession, company')
                  .ilike('name', rawName)
                  .limit(1)
                  .maybeSingle();
              if (found != null) {
                profile = Map<String, dynamic>.from(found);
                voucheeId = profile['id'] is int
                    ? profile['id'] as int
                    : int.tryParse(profile['id']?.toString() ?? '');
              }
            } catch (e) {
              debugPrint("Error looking up profile by name: $e");
            }
          }
        }
      }

      // 3. Fallback: query user_vouches for vouchee if relationship is not yet loaded
      if (voucheeId != null && (relationshipType == null || relationshipType.isEmpty)) {
        try {
          final vRes = await Supabase.instance.client
              .from('user_vouches')
              .select('relationship_type, optional_note, statement')
              .eq('vouchee_id', voucheeId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (vRes != null) {
            relationshipType ??= vRes['relationship_type']?.toString();
            optionalNote ??= vRes['optional_note']?.toString();
            statement ??= vRes['statement']?.toString();
          }
        } catch (_) {}
      }

      // 4. Content regex fallback for relationship and note
      if (relationshipType == null || relationshipType.isEmpty) {
        final relMatch = RegExp(r'as "([^"]+)"').firstMatch(widget.postContent);
        if (relMatch != null) {
          relationshipType = relMatch.group(1);
        }
      }
      if (optionalNote == null || optionalNote.isEmpty) {
        final noteMatch = RegExp(r'\n\n"([^"]+)"').firstMatch(widget.postContent);
        if (noteMatch != null) {
          optionalNote = noteMatch.group(1);
        }
      }

      if (voucheeId == null || profile == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 5. Total vouches count for this vouchee
      int vouchesCount = 1;
      try {
        vouchesCount = await Supabase.instance.client
            .from('user_vouches')
            .count(CountOption.exact)
            .eq('vouchee_id', voucheeId)
            .eq('status', 'accepted');
      } catch (e) {
        debugPrint("Error counting vouches: $e");
      }

      final data = _VouchCardData(
        voucheeId: voucheeId,
        voucheeName: profile['name']?.toString() ?? 'User',
        voucheeAvatarUrl: profile['avatar_url']?.toString() ?? '',
        voucheeProfession: profile['profession']?.toString() ?? '',
        voucheeCompany: profile['company']?.toString() ?? '',
        relationshipType: relationshipType,
        optionalNote: optionalNote,
        statement: statement,
        totalVouchesCount: vouchesCount,
        fullProfile: profile,
      );

      _cache[widget.postId] = data;
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading vouch card data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildInitials(String name, {double size = 12}) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : 'U';
    return Container(
      color: Colors.white.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        height: 80,
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
      );
    }

    final data = _data;
    if (data == null) {
      return const SizedBox.shrink();
    }

    final relType = (data.relationshipType != null && data.relationshipType!.trim().isNotEmpty)
        ? data.relationshipType!.trim()
        : "Endorsement";
    final note = data.optionalNote?.trim();
    final hasNote = note != null && note.isNotEmpty;

    final profileProvider = Provider.of<ProfileProvider>(context);
    final myUserId = profileProvider.userId;
    final myName = profileProvider.name.trim().toLowerCase();
    final voucheeName = data.voucheeName.trim().toLowerCase();
    final bool isMe = (myUserId != null && data.voucheeId != 0 && myUserId == data.voucheeId) ||
        (myName.isNotEmpty && voucheeName.isNotEmpty && myName == voucheeName);

    return GestureDetector(
      onTap: isMe
          ? null
          : () {
              UserProfileModal.show(
                context,
                userId: data.voucheeId,
                userName: data.voucheeName,
                avatarUrl: data.voucheeAvatarUrl,
              );
            },
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row: Verified Vouch Indicator + Relationship Endorsement Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      "VERIFIED VOUCH",
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4.5),
                        Flexible(
                          child: Text(
                            relType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Middle Section: Optional Testimonial Note
            if (hasNote) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '“$note”',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],

            // Divider before recipient attribution
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Divider(
                color: Colors.white.withValues(alpha: 0.07),
                height: 1,
                thickness: 0.8,
              ),
            ),

            // Bottom Row: Recipient (Vouchee) Attribution + Tap to View
            Row(
              children: [
                // Small vouchee avatar
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 0.8,
                    ),
                  ),
                  child: ClipOval(
                    child: (data.voucheeAvatarUrl.isNotEmpty &&
                            data.voucheeAvatarUrl.startsWith('http'))
                        ? Image.network(
                            data.voucheeAvatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildInitials(data.voucheeName, size: 9.5),
                          )
                        : _buildInitials(data.voucheeName, size: 9.5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                          children: [
                            TextSpan(
                              text: "Vouched for ",
                              style: TextStyle(
                                color: context.textSecondary,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            TextSpan(
                              text: data.voucheeName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (data.voucheeProfession.isNotEmpty ||
                          data.voucheeCompany.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          [data.voucheeProfession, data.voucheeCompany]
                              .where((s) => s.isNotEmpty)
                              .join(' • '),
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 10.5,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isMe) ...[
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "View",
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 9.5,
                        color: context.textMuted,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
