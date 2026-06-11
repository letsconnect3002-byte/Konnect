import 'dart:convert';
import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/chat_provider.dart';
import 'package:provider/provider.dart';
import 'package:connect/Utils/profile_field_filter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:connect/Config/app_theme.dart';

class ConnectionProfilePage extends StatefulWidget {
  final Map<String, dynamic> profileData;
  const ConnectionProfilePage({super.key, required this.profileData});

  @override
  State<ConnectionProfilePage> createState() => _ConnectionProfilePageState();
}

class _ConnectionProfilePageState extends State<ConnectionProfilePage> {
  static const _cardAnimDuration = Duration(milliseconds: 400);
  static const _cardAnimCurve = Curves.easeInOut;

  bool _showFront = true;
  bool _isLoading = false;
  Map<String, dynamic>? _fieldAssignments;

  late String _name;
  late String _profession;
  late String _company;
  late String _email;
  late String _professionalEmail;
  late String _phoneNumber;
  late String _professionalPhoneNumber;
  late String _bio;
  late String _professionalBio;
  late String _avatarUrl;
  late String _instagram;
  late String _linkedin;
  late String _twitter;
  late String _spotify;
  List<dynamic> _customLinks = [];
  Map<String, String> _casualFields = {};
  Map<String, String> _professionalFields = {};

  String _selectedPreviewCardType = 'professional';

  Map<String, String> get _activeFields {
    if (_sharedCardPermission == 'casual') return _casualFields;
    if (_sharedCardPermission == 'professional') return _professionalFields;

    // If 'both', show professional fields (no fallback merging)
    return _professionalFields;
  }

  Map<String, String> get _previewFields {
    if (_sharedCardPermission == 'both') {
      return _selectedPreviewCardType == 'casual'
          ? _casualFields
          : _professionalFields;
    }
    return _activeFields;
  }

  late final ProfileProvider profileProvider;
  late final ConnectionProvider connectionProvider;
  String _sharedCardPermission = 'both'; // what they share with me
  String _mySharedCardToThem = 'both'; // what I share with them

  @override
  void initState() {
    super.initState();
    profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final data = widget.profileData;
    _fieldAssignments = data['field_assignments'] is Map<String, dynamic>
        ? data['field_assignments'] as Map<String, dynamic>
        : (data['field_assignments'] is String
            ? jsonDecode(data['field_assignments'] as String)
                as Map<String, dynamic>
            : null);
    _name = data['name'] ?? '';
    _profession = data['profession'] ?? '';
    _company = data['company'] ?? '';
    _email = data['email'] ?? '';
    _professionalEmail =
        data['professionalEmail'] ?? data['professional_email'] ?? '';
    _phoneNumber = data['phoneNumber'] ?? data['phone_number'] ?? '';
    _professionalPhoneNumber = data['professionalPhoneNumber'] ??
        data['professional_phone_number'] ??
        '';
    _bio = data['bio'] ?? '';
    _professionalBio =
        data['professionalBio'] ?? data['professional_bio'] ?? '';
    _avatarUrl = data['avatarUrl'] ?? data['avatar_url'] ?? '';
    _instagram = data['instagram'] ?? '';
    _linkedin = data['linkedin'] ?? '';
    _twitter = data['twitter'] ?? '';
    _spotify = data['spotify'] ?? '';
    _customLinks = data['custom_links'] != null
        ? List<dynamic>.from(data['custom_links'] as List)
        : [];

    // Fallbacks for skeleton loading shapes
    if (_name.isEmpty) _name = "Jane Doe";
    if (_profession.isEmpty) _profession = "Software Engineer";
    if (_company.isEmpty) _company = "Tech Corporation";
    if (_email.isEmpty) _email = "jane.doe@example.com";
    if (_professionalEmail.isEmpty) _professionalEmail = "jane.doe@work.com";
    if (_phoneNumber.isEmpty) _phoneNumber = "+91 98765 43210";
    if (_professionalPhoneNumber.isEmpty)
      _professionalPhoneNumber = "+91 98765 00000";
    if (_bio.isEmpty)
      _bio =
          "Passionate developer building modern apps and exploring design systems.";
    if (_professionalBio.isEmpty)
      _professionalBio =
          "Experienced software engineer leading web and mobile products.";
    if (_instagram.isEmpty) _instagram = "instagram_handle";
    if (_linkedin.isEmpty) _linkedin = "linkedin_handle";
    if (_twitter.isEmpty) _twitter = "twitter_handle";
    if (_spotify.isEmpty) _spotify = "";

    final String initialProfEmail = _professionalEmail;
    final String initialProfPhone = _professionalPhoneNumber;

    _casualFields = {
      'email': _email,
      'phoneNumber': _phoneNumber,
      'instagram': _instagram,
      'linkedin': _linkedin,
      'twitter': _twitter,
      'spotify': _spotify,
      'bio': _bio,
    };
    _professionalFields = {
      'email': initialProfEmail,
      'phoneNumber': initialProfPhone,
      'instagram': _instagram,
      'linkedin': _linkedin,
      'twitter': _twitter,
      'spotify': _spotify,
      'bio': _professionalBio,
    };

    final connectionProfileId = data['connection_profile_id'];
    if (connectionProfileId != null) {
      if (mounted) {
        setState(() => _isLoading = true);
      }
      try {
        final idToFetch = connectionProfileId is int
            ? connectionProfileId
            : int.parse(connectionProfileId.toString());
        final details = await profileProvider.fetchConnectionDetails(idToFetch);
        final response = details['profile'] as Map<String, dynamic>?;
        _sharedCardPermission = details['sharedCardPermission'] as String;
        _mySharedCardToThem = details['mySharedCardToThem'] as String;

        if (response != null && mounted) {
          final Map<String, dynamic>? fieldAssignments =
              response['field_assignments'] is Map<String, dynamic>
                  ? response['field_assignments'] as Map<String, dynamic>
                  : (response['field_assignments'] is String
                      ? jsonDecode(response['field_assignments'] as String)
                          as Map<String, dynamic>
                      : null);

          setState(() {
            _fieldAssignments = fieldAssignments;
            _name = response['name'] ?? '';
            _avatarUrl = response['avatar_url'] ?? '';
            _profession = response['profession'] ?? '';
            _company = response['company'] ?? '';
            _email = ProfileFieldFilter.getVisibleValue(
                'email',
                response['email'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _professionalEmail = ProfileFieldFilter.getVisibleValue(
                'professionalEmail',
                response['professional_email'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _phoneNumber = ProfileFieldFilter.getVisibleValue(
                'phoneNumber',
                response['phone_number'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _professionalPhoneNumber = ProfileFieldFilter.getVisibleValue(
                'professionalPhoneNumber',
                response['professional_phone_number'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _instagram = ProfileFieldFilter.getVisibleValue(
                'instagram',
                response['instagram'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _linkedin = ProfileFieldFilter.getVisibleValue(
                'linkedin',
                response['linkedin'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _twitter = ProfileFieldFilter.getVisibleValue(
                'twitter',
                response['twitter'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _spotify = ProfileFieldFilter.getVisibleValue(
                'spotify',
                response['spotify'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _bio = ProfileFieldFilter.getVisibleValue('bio',
                response['bio'] ?? '', _sharedCardPermission, fieldAssignments);
            _customLinks = response['custom_links'] != null
                ? List<dynamic>.from(response['custom_links'] is String
                    ? jsonDecode(response['custom_links'] as String)
                        as List<dynamic>
                    : response['custom_links'] as List<dynamic>)
                : [];
          });

          // Build per-card filtered field sets
          final Map<String, dynamic>? fa = fieldAssignments;

          String filterField(String field, String rawValue) {
            return ProfileFieldFilter.getVisibleValue(
                field, rawValue, 'casual', fa);
          }

          String filterFieldPro(String field, String rawValue) {
            return ProfileFieldFilter.getVisibleValue(
                field, rawValue, 'professional', fa);
          }

          setState(() {
            final String rawEmail = response['email'] ?? '';
            final String rawPhone = response['phone_number'] ?? '';
            final String rawProfEmail = response['professional_email'] ?? '';
            final String rawProfPhone =
                response['professional_phone_number'] ?? '';

            final String filterCasualEmail = filterField('email', rawEmail);
            final String filterCasualPhone =
                filterField('phoneNumber', rawPhone);

            final String filterProfEmail =
                filterFieldPro('professionalEmail', rawProfEmail);

            final String filterProfPhone =
                filterFieldPro('professionalPhoneNumber', rawProfPhone);

            _casualFields = {
              'email': filterCasualEmail,
              'phoneNumber': filterCasualPhone,
              'instagram':
                  filterField('instagram', response['instagram'] ?? ''),
              'linkedin': filterField('linkedin', response['linkedin'] ?? ''),
              'twitter': filterField('twitter', response['twitter'] ?? ''),
              'spotify': filterField('spotify', response['spotify'] ?? ''),
              'bio': filterField('bio', response['bio'] ?? ''),
            };

            final String rawProfBio = response['professional_bio'] ?? '';
            _professionalBio = ProfileFieldFilter.getVisibleValue(
                'professionalBio',
                rawProfBio,
                _sharedCardPermission,
                fieldAssignments);

            _professionalFields = {
              'email': filterProfEmail,
              'phoneNumber': filterProfPhone,
              'instagram':
                  filterFieldPro('instagram', response['instagram'] ?? ''),
              'linkedin':
                  filterFieldPro('linkedin', response['linkedin'] ?? ''),
              'twitter': filterFieldPro('twitter', response['twitter'] ?? ''),
              'spotify': filterFieldPro('spotify', response['spotify'] ?? ''),
              'bio': filterFieldPro('professionalBio', rawProfBio),
            };
          });
        }
      } catch (e) {
        print("Error fetching connection profile data: $e");
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // Return the actual avatar URL from the database, or empty if none
  String _getAvatarUrl(String name, String url) {
    if (url.isNotEmpty) {
      return url;
    }
    return '';
  }

  String _getCompany(String name, String comp) {
    return comp;
  }

  String _getBio(String name, String bioText) {
    return bioText;
  }

  Widget _buildFallbackAvatar() {
    final monogram =
        _name.isNotEmpty ? _name.substring(0, 1).toUpperCase() : "?";
    return Center(
      child: Text(
        monogram,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: context.surfaceSecondary,
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(
          color: context.surfaceSecondary.withValues(alpha: 0.8),
          width: 1.0,
        ),
      ),
      child: Text(
        text,
        style: context.captionText.copyWith(
          color: context.accentPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildHeroSection(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Banner Cover Background
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 180,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.surfacePrimary,
                    context.surfaceSecondary,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CardPatternPainter(
                        color: context.accentPrimary.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          context.canvasBackground,
                        ],
                        stops: const [0.35, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Back Button Overlay
          Positioned(
            left: AppDimensions.marginStandard,
            top: 48,
            child: GestureDetector(
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.surfacePrimary.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.surfaceSecondary,
                    width: 1.0,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),

          // 3. Avatar Placement
          Positioned(
            left: AppDimensions.marginStandard,
            top: 110,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.accentPrimary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(1.5),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.surfaceSecondary,
                ),
                clipBehavior: Clip.antiAlias,
                child: (_avatarUrl.isNotEmpty && _avatarUrl.startsWith('http'))
                    ? Image.network(
                        _avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackAvatar(),
                      )
                    : _buildFallbackAvatar(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrontBackToggle() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: context.surfaceSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.surfaceSecondary),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showFront = true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color:
                    _showFront ? context.accentSecondary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                'FRONT',
                style: TextStyle(
                  color: _showFront ? Colors.white : context.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showFront = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color:
                    !_showFront ? context.accentSecondary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                'BACK',
                style: TextStyle(
                  color: !_showFront ? Colors.white : context.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = cardWidth / 1.58;

        return GestureDetector(
          onDoubleTap: () {
            HapticFeedback.mediumImpact();
            setState(() {
              _showFront = !_showFront;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: _cardAnimDuration,
            curve: _cardAnimCurve,
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusPremiumCard),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00F2FE),
                  context.accentSecondary,
                  const Color(0xFFEC4899),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F2FE).withValues(alpha: 0.1),
                  blurRadius: 14,
                  spreadRadius: 0,
                ),
              ],
            ),
            padding: const EdgeInsets.all(1.5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22.5),
              child: AnimatedContainer(
                duration: _cardAnimDuration,
                curve: _cardAnimCurve,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1B1B3A), Color(0xFF0C0C18)],
                  ),
                  borderRadius: BorderRadius.circular(22.5),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: CardPatternPainter(
                          color:
                              const Color(0xFF00F2FE).withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: _cardAnimDuration,
                      switchInCurve: _cardAnimCurve,
                      switchOutCurve: _cardAnimCurve,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: ScaleTransition(
                              scale: Tween<double>(begin: 0.96, end: 1.0)
                                  .animate(animation),
                              child: child,
                            ).scale,
                            child: child,
                          ),
                        );
                      },
                      child: _buildActiveCardFace(cardWidth),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveCardFace(double cardWidth) {
    final isFront = _showFront;
    if (isFront) {
      return _wrapCardFace(
        _buildUnifiedFrontCard(cardWidth),
        1.58,
        cardWidth,
        const ValueKey('FrontCard'),
      );
    } else {
      return _wrapCardFace(
        _buildUnifiedBackCard(cardWidth),
        1.58,
        cardWidth,
        const ValueKey('BackCard'),
      );
    }
  }

  Widget _wrapCardFace(
      Widget child, double targetAspectRatio, double cardWidth, Key key) {
    final targetHeight = cardWidth / targetAspectRatio;
    return ClipRect(
      key: key,
      child: OverflowBox(
        minWidth: cardWidth,
        maxWidth: cardWidth,
        minHeight: cardWidth / 1.58,
        maxHeight: cardWidth / 0.82,
        alignment: Alignment.topCenter,
        child: AnimatedContainer(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          width: cardWidth,
          height: targetHeight,
          child: child,
        ),
      ),
    );
  }

  Widget _buildUnifiedFrontCard(double cardWidth) {
    final W = cardWidth;
    final comp = _getCompany(_name, _company);
    final nameText = _name.isEmpty ? 'Jordan Miller' : _name;
    final professionText = _profession;

    return Stack(
      children: [
        // 1. Top Section: Logo, Company Name, Card Type
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: 0,
          right: 0,
          top: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: _cardAnimDuration,
                curve: _cardAnimCurve,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF151628),
                  border: Border.all(
                    color: context.accentSecondary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/icons/Mandala Icon 1.png',
                    width: 22,
                    height: 22,
                    color: const Color(0xFF00F2FE),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedDefaultTextStyle(
                duration: _cardAnimDuration,
                curve: _cardAnimCurve,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.5,
                  fontFamily: 'Inter',
                ),
                child: Text(
                  comp.isEmpty ? 'CONNECT' : comp.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'DIGITAL CARD',
                style: TextStyle(
                  color: const Color(0xFF00F2FE).withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),

        // 2. Name & Profession
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: 18,
          right: W * 0.4,
          bottom: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: _cardAnimDuration,
                curve: _cardAnimCurve,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
                child: Text(
                  nameText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (professionText.isNotEmpty) ...[
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: _cardAnimDuration,
                  curve: _cardAnimCurve,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                  child: Text(
                    professionText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),

        // 3. Scan Badge
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: W - 113,
          bottom: 14,
          width: 95,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1F32),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFF00F2FE),
                    size: 13,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'SCAN',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedBackCard(double cardWidth) {
    final W = cardWidth;
    final avatar = _getAvatarUrl(_name, _avatarUrl);
    final comp = _getCompany(_name, _company);
    final bioVal = _getBio(_name, _previewFields['bio'] ?? '');
    final emailVal = _previewFields['email'] ?? '';
    final phoneVal = _previewFields['phoneNumber'] ?? '';
    final professionText = _profession;

    return Stack(
      children: [
        // 1. Row 1: Avatar, Name, Profession, Link Button
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: 16,
          right: 16,
          top: 12,
          height: 40,
          child: Row(
            children: [
              AnimatedContainer(
                duration: _cardAnimDuration,
                curve: _cardAnimCurve,
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(1.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [const Color(0xFF00F2FE), context.accentSecondary],
                  ),
                ),
                child: ClipOval(
                  child: (avatar.isNotEmpty && avatar.startsWith('http'))
                      ? Image.network(
                          avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF1E1F32),
                            alignment: Alignment.center,
                            child: Text(
                              _name.isNotEmpty
                                  ? _name.substring(0, 1).toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF1E1F32),
                          alignment: Alignment.center,
                          child: Text(
                            _name.isNotEmpty
                                ? _name.substring(0, 1).toUpperCase()
                                : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
              AnimatedContainer(
                duration: _cardAnimDuration,
                curve: _cardAnimCurve,
                width: 10,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: _cardAnimDuration,
                      curve: _cardAnimCurve,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                      child: Text(
                        _name.isEmpty ? 'Unknown' : _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (professionText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: _cardAnimDuration,
                        curve: _cardAnimCurve,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                        child: Text(
                          professionText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1F32),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: Color(0xFF00F2FE),
                  size: 14,
                ),
              ),
            ],
          ),
        ),

        // 2. Divider Line
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: 16,
          right: 16,
          top: 60,
          height: 1,
          child: Container(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),

        // 3. Contact Details Group (Company, Email, Phone)
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: (W * 0.5) + 6,
          right: 16,
          top: 74,
          height: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildUnifiedCardRow(
                Icons.apartment_rounded,
                comp.isNotEmpty ? comp : 'Data Unavailable',
                false,
                isUnavailable: comp.isEmpty,
              ),
              const SizedBox(height: 5),
              _buildUnifiedCardRow(
                Icons.email_outlined,
                emailVal.isNotEmpty ? emailVal : 'Data Unavailable',
                false,
                isUnavailable: emailVal.isEmpty,
              ),
              const SizedBox(height: 5),
              _buildUnifiedCardRow(
                Icons.phone_rounded,
                phoneVal.isNotEmpty ? phoneVal : 'Data Unavailable',
                false,
                isUnavailable: phoneVal.isEmpty,
              ),
            ],
          ),
        ),

        // 4. Bio Section
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: 16,
          right: (W * 0.5) + 6,
          top: 74,
          height: 60,
          child: bioVal.isNotEmpty
              ? Text(
                  bioVal,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    height: 1.25,
                    fontFamily: 'Inter',
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                )
              : const SizedBox.shrink(),
        ),

        // 5. Bottom Accent Line
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: 16,
          right: W - 76,
          top: 140,
          height: 2,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1.5),
              gradient: LinearGradient(
                colors: [context.accentSecondary, const Color(0xFF00F2FE)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedCardRow(IconData icon, String text, bool isCasual,
      {bool isUnavailable = false}) {
    return Row(
      children: [
        AnimatedContainer(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFF171825),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              color: isUnavailable
                  ? const Color(0xFF3A3B50)
                  : (isCasual ? const Color(0xFF8B8C9E) : Colors.white54),
              size: 12,
            ),
          ),
        ),
        AnimatedContainer(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          width: 8,
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedDefaultTextStyle(
              duration: _cardAnimDuration,
              curve: _cardAnimCurve,
              style: TextStyle(
                color: isUnavailable
                    ? const Color(0xFF3A3B50)
                    : (isCasual ? const Color(0xFF8B8C9E) : Colors.white70),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontStyle: isUnavailable ? FontStyle.italic : FontStyle.normal,
                fontFamily: 'Inter',
              ),
              child: Text(
                text,
                maxLines: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPremiumCard),
        border:
            Border.all(color: context.surfaceSecondary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.accentPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.captionText,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: context.bodyText.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.content_copy_rounded,
                color: context.textSecondary, size: 18),
            onPressed: () {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final surfaceSecondaryColor = context.surfaceSecondary;
              Clipboard.setData(ClipboardData(text: value)).then((_) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text("Copied $label to clipboard!"),
                    backgroundColor: surfaceSecondaryColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCard({
    required String title,
    required String handle,
    required Widget logo,
  }) {
    if (handle.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPremiumCard),
        border:
            Border.all(color: context.surfaceSecondary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          logo,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.captionText,
                ),
                const SizedBox(height: 4),
                Text(
                  handle,
                  style: context.bodyText.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.content_copy_rounded,
                color: context.textSecondary, size: 18),
            onPressed: () {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final surfaceSecondaryColor = context.surfaceSecondary;
              Clipboard.setData(ClipboardData(text: handle)).then((_) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text("Copied $title handle to clipboard!"),
                    backgroundColor: surfaceSecondaryColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(30.0),
        border: Border.all(
          color: context.surfaceSecondary,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white10),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
          Column(
            children: [
              Text(
                _name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Digital Card',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12.0,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          SizedBox(
            width: 32,
            height: 32,
            // decoration: const BoxDecoration(
            //     shape: BoxShape.circle, color: Colors.white10),
            // child: const Icon(
            //   Icons.badge_outlined,
            //   color: Colors.white54,
            //   size: 14,
            // ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mock social media logos matching profile page
    final linkedinLogo = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      // padding: const EdgeInsets.all(8),
      child: Image.asset(
        'assets/icons/linkedin.png',
        fit: BoxFit.contain,
      ),
    );
    final twitterLogo = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      // padding: const EdgeInsets.all(8),
      child: Image.asset(
        'assets/icons/twitter.png',
        fit: BoxFit.contain,
      ),
    );
    final instagramLogo = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      // padding: const EdgeInsets.all(8),
      child: Image.asset(
        'assets/icons/instagram.png',
        fit: BoxFit.contain,
      ),
    );
    final spotifyLogo = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(8),
      child: Image.asset(
        'assets/icons/spotify.png',
        fit: BoxFit.contain,
      ),
    );

    return Scaffold(
      backgroundColor: context.canvasBackground,
      body: SafeArea(
        top: false,
        child: Skeletonizer(
          enabled: _isLoading,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Premium Hero Banner & Avatar Overlay
                // _buildHeroSection(context),

                // 2. Profile Details Left-aligned
                // Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: AppDimensions.marginStandard),
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Text(
                //         _name,
                //         style: context.displayHeader,
                //       ),
                //       const SizedBox(height: 4),
                //       if (_profession.isNotEmpty || _company.isNotEmpty) ...[
                //         Text(
                //           _company.isNotEmpty ? "$_profession at $_company" : _profession,
                //           style: context.bodyText.copyWith(color: context.textSecondary),
                //         ),
                //         const SizedBox(height: 8),
                //       ],
                //       // Category tag Wrap
                //       Wrap(
                //         spacing: 8.0,
                //         runSpacing: 8.0,
                //         children: [
                //           _buildTag("Konnection"),
                //           if (_sharedCardPermission != 'both')
                //             _buildTag(_sharedCardPermission.toUpperCase())
                //           else ...[
                //             _buildTag("CASUAL"),
                //             _buildTag("PROFESSIONAL"),
                //           ],
                //         ],
                //       ),
                //       const SizedBox(height: 24),
                //     ],
                //   ),
                // ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.marginStandard,
                    right: AppDimensions.marginStandard,
                    top: 56.0,
                  ),
                  child: _buildSkeletonHeader(),
                ),
                const SizedBox(
                  height: 24,
                ),

                // 3. Digital Cards Preview and Permissions Details
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.marginStandard),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildFrontBackToggle(),
                      ),
                      const SizedBox(height: 16),

                      if (_sharedCardPermission == 'both') ...[
                        _buildPreviewTabSelector(),
                        const SizedBox(height: 16),
                      ],
                      // Business card graphic
                      _buildDigitalCard(),
                      const SizedBox(height: 24),
                      _buildAccessControlSection(),
                      const SizedBox(height: 32),

                      // DETAILS DISPLAY HEADER
                      Text(
                        'CONNECTION DETAILS',
                        style: context.captionText.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Read-only Details (filtered by shared card permission)
                      _buildReadOnlyField(
                        label: 'Full Name',
                        value: _name,
                        icon: Icons.person_outline_rounded,
                      ),
                      // Profession & Company are professional details
                      if (_sharedCardPermission == 'professional' ||
                          _sharedCardPermission == 'both') ...[
                        _buildReadOnlyField(
                          label: 'Profession',
                          value: _profession,
                          icon: Icons.work_outline_rounded,
                        ),
                        _buildReadOnlyField(
                          label: 'Company',
                          value: _company,
                          icon: Icons.apartment_rounded,
                        ),
                      ],
                      // When 'both', show casual & professional variants separately
                      if (_sharedCardPermission == 'both')
                        ..._buildBothFields(
                          casualFields: _casualFields,
                          professionalFields: _professionalFields,
                          linkedinLogo: linkedinLogo,
                          twitterLogo: twitterLogo,
                          instagramLogo: instagramLogo,
                          spotifyLogo: spotifyLogo,
                        )
                      else ...[
                        _buildReadOnlyField(
                          label: 'Email Address',
                          value: _activeFields['email'] ?? '',
                          icon: Icons.email_outlined,
                        ),
                        _buildReadOnlyField(
                          label: 'Phone Number',
                          value: _activeFields['phoneNumber'] ?? '',
                          icon: Icons.phone_android_outlined,
                        ),
                        _buildReadOnlyField(
                          label: 'Bio',
                          value: _activeFields['bio'] ?? '',
                          icon: Icons.description_outlined,
                        ),

                        // Social media block — only show if at least one handle exists
                        if ([
                          _activeFields['linkedin'] ?? '',
                          _activeFields['twitter'] ?? '',
                          _activeFields['instagram'] ?? '',
                          _activeFields['spotify'] ?? '',
                        ].any((v) => v.trim().isNotEmpty)) ...[
                          const SizedBox(height: 16),
                          Text(
                            'SOCIAL HANDLES',
                            style: context.captionText.copyWith(
                              color: context.textSecondary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSocialCard(
                            title: 'LinkedIn',
                            handle: _activeFields['linkedin'] ?? '',
                            logo: linkedinLogo,
                          ),
                          _buildSocialCard(
                            title: 'Twitter',
                            handle: _activeFields['twitter'] ?? '',
                            logo: twitterLogo,
                          ),
                          _buildSocialCard(
                            title: 'Instagram',
                            handle: _activeFields['instagram'] ?? '',
                            logo: instagramLogo,
                          ),
                          _buildSocialCard(
                            title: 'Spotify',
                            handle: _activeFields['spotify'] ?? '',
                            logo: spotifyLogo,
                          ),
                        ],
                      ],

                      // CUSTOM LINKS
                      ..._buildCustomLinksList(_fieldAssignments),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.marginStandard,
            vertical: 12.0,
          ),
          decoration: BoxDecoration(
            color: context.canvasBackground,
            border: Border(
              top: BorderSide(
                color: context.surfaceSecondary,
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _showDeleteConfirmation(
                        context, widget.profileData, connectionProvider);
                  },
                  style: OutlinedButton.styleFrom(
                    side:
                        BorderSide(color: context.surfaceSecondary, width: 1.0),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  child: Text(
                    "Remove Connection",
                    style: context.bodyText.copyWith(
                      color: context.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IndividualChatPage(
                          connectionData: widget.profileData,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accentPrimary,
                    foregroundColor: Colors.black,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    elevation: 0,
                  ),
                  child: Text(
                    "Message",
                    style: context.bodyText.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the detail + social widgets when the shared card permission is
  /// 'both'. Deduplicates identical values across casual/professional and
  /// only renders fields that actually have data.
  List<Widget> _buildBothFields({
    required Map<String, String> casualFields,
    required Map<String, String> professionalFields,
    required Widget linkedinLogo,
    required Widget twitterLogo,
    required Widget instagramLogo,
    required Widget spotifyLogo,
  }) {
    final widgets = <Widget>[];

    // --- Helper to emit one or two rows for a given field key. ---
    void addField(String key, String label, IconData icon) {
      final casual = casualFields[key]?.trim() ?? '';
      final professional = professionalFields[key]?.trim() ?? '';
      if (casual.isEmpty && professional.isEmpty) return;
      // If both have data and they differ, show separately.
      if (casual.isNotEmpty &&
          professional.isNotEmpty &&
          casual != professional) {
        widgets.add(_buildReadOnlyField(
          label: '$label (Casual)',
          value: casual,
          icon: icon,
        ));
        widgets.add(_buildReadOnlyField(
          label: '$label (Professional)',
          value: professional,
          icon: icon,
        ));
      } else {
        // Show whichever is available (or the shared value).
        widgets.add(_buildReadOnlyField(
          label: label,
          value: casual.isNotEmpty ? casual : professional,
          icon: icon,
        ));
      }
    }

    addField('email', 'Email Address', Icons.email_outlined);
    addField('phoneNumber', 'Phone Number', Icons.phone_android_outlined);
    addField('bio', 'Bio', Icons.description_outlined);

    // --- Helper to emit social card row. ---
    void addSocial(String key, String title, Widget logo) {
      final casual = casualFields[key]?.trim() ?? '';
      final professional = professionalFields[key]?.trim() ?? '';
      if (casual.isEmpty && professional.isEmpty) return;
      if (casual.isNotEmpty &&
          professional.isNotEmpty &&
          casual != professional) {
        widgets.add(_buildSocialCard(
          title: '$title (Casual)',
          handle: casual,
          logo: logo,
        ));
        widgets.add(_buildSocialCard(
          title: '$title (Professional)',
          handle: professional,
          logo: logo,
        ));
      } else {
        widgets.add(_buildSocialCard(
          title: title,
          handle: casual.isNotEmpty ? casual : professional,
          logo: logo,
        ));
      }
    }

    // Only add the social header if at least one handle exists.
    final hasAnySocial = [
      casualFields['linkedin'],
      professionalFields['linkedin'],
      casualFields['twitter'],
      professionalFields['twitter'],
      casualFields['instagram'],
      professionalFields['instagram'],
      casualFields['spotify'],
      professionalFields['spotify'],
    ].any((v) => (v ?? '').trim().isNotEmpty);

    if (hasAnySocial) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(Text(
        'SOCIAL HANDLES',
        style: context.captionText.copyWith(
          color: context.textSecondary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ));
      widgets.add(const SizedBox(height: 16));
      addSocial('linkedin', 'LinkedIn', linkedinLogo);
      addSocial('twitter', 'Twitter', twitterLogo);
      addSocial('instagram', 'Instagram', instagramLogo);
      addSocial('spotify', 'Spotify', spotifyLogo);
    }

    return widgets;
  }

  List<Widget> _buildCustomLinksList(dynamic fieldAssignments) {
    final widgets = <Widget>[];

    // Filter links based on visibility
    final visibleLinks = _customLinks.where((link) {
      final String linkId = link['id'] ?? '';
      return ProfileFieldFilter.isFieldVisible(
          linkId, _sharedCardPermission, fieldAssignments);
    }).toList();

    if (visibleLinks.isEmpty) return widgets;

    widgets.add(const SizedBox(height: 24));
    widgets.add(Text(
      'CUSTOM LINKS',
      style: context.captionText.copyWith(
        color: context.textSecondary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    ));
    widgets.add(const SizedBox(height: 16));

    for (final link in visibleLinks) {
      final String name = link['name'] ?? '';
      final String url = link['url'] ?? '';
      final String id = link['id'] ?? '';

      String label = name;
      if (_sharedCardPermission == 'both') {
        final assignments =
            ProfileFieldFilter.parseFieldAssignments(fieldAssignments);
        final assignment = assignments != null ? assignments[id] : null;
        final isC = assignment != null && assignment['c'] == true;
        final isP = assignment != null && assignment['p'] == true;
        if (isC && !isP) {
          label = '$name (Casual)';
        } else if (isP && !isC) {
          label = '$name (Professional)';
        }
      }

      final globeLogo = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.language_rounded,
          color: context.accentSecondary,
          size: 20,
        ),
      );

      widgets.add(_buildSocialCard(
        title: label,
        handle: url,
        logo: globeLogo,
      ));
    }

    return widgets;
  }

  Widget _buildPreviewTabSelector() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.surfaceSecondary),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCardTab(
              label: 'Casual',
              icon: Icons.person_outline_rounded,
              isActive: _selectedPreviewCardType == 'casual',
              onTap: () => setState(() => _selectedPreviewCardType = 'casual'),
            ),
          ),
          Expanded(
            child: _buildCardTab(
              label: 'Professional',
              icon: Icons.work_outline_rounded,
              isActive: _selectedPreviewCardType == 'professional',
              onTap: () =>
                  setState(() => _selectedPreviewCardType = 'professional'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTab({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? context.accentSecondary : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : context.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : context.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessControlSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPremiumCard),
        border:
            Border.all(color: context.surfaceSecondary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security_rounded,
                  color: context.accentPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                "ACCESS PERMISSIONS",
                style: context.captionText.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Configure which digital card of yours this contact can see:",
            style: context.bodyText.copyWith(
              color: context.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          _buildAccessPills(),
        ],
      ),
    );
  }

  Widget _buildAccessPills() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: context.canvasBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
        border: Border.all(color: context.surfaceSecondary),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _buildPillItem('casual', 'Casual'),
          _buildPillItem('professional', 'Professional'),
          _buildPillItem('both', 'Both'),
        ],
      ),
    );
  }

  Widget _buildPillItem(String value, String label) {
    final bool isSelected = _mySharedCardToThem == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _updateSharingAccess(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? context.accentPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : context.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateSharingAccess(String accessType) async {
    final connectionProfileId =
        widget.profileData['connection_profile_id'] ?? widget.profileData['id'];
    if (connectionProfileId == null) return;

    final int otherUserId = connectionProfileId is int
        ? connectionProfileId
        : int.parse(connectionProfileId.toString());

    setState(() {
      _mySharedCardToThem = accessType;
    });

    await connectionProvider.updateConnectionAccess(otherUserId, accessType);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Sharing settings updated to ${accessType.toUpperCase()}"),
          backgroundColor: context.textPrimary,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  Future<void> _deleteProfileLocally(
      String id, ConnectionProvider provider) async {
    try {
      final intId = int.tryParse(id) ?? 0;
      await provider.deleteProfile(intId,
          onRoomCleanup: (profileId, roomId) async {
        await Provider.of<ChatProvider>(context, listen: false)
            .handleRoomCleanup(profileId, roomId);
      });
    } catch (e) {
      print("Error deleting profile locally: $e");
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context,
      Map<String, dynamic> connection, ConnectionProvider provider) async {
    final name = connection['name'] ?? 'this contact';
    final profileIdStr =
        (connection['id'] ?? connection['connection_profile_id'] ?? '')
            .toString();

    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: context.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusPremiumCard),
            side: BorderSide(color: context.surfaceSecondary, width: 1.5),
          ),
          title: Text(
            "Delete Connection",
            style: context.screenHeading.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to remove $name from your connections? This will permanently delete this connection and clear all chat history and text messages.",
            style: context.bodyText.copyWith(color: context.textSecondary),
          ),
          actions: [
            TextButton(
              child: Text("Cancel",
                  style: TextStyle(color: context.textSecondary)),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: const Text("Delete",
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(dialogContext);
                try {
                  await _deleteProfileLocally(profileIdStr, provider);
                  if (!mounted) return;
                  navigator
                      .pop(); // Pop profile detail screen since it's deleted
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text("Connection and chat history deleted"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text("Error deleting connection: $e")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class CardPatternPainter extends CustomPainter {
  final Color color;
  CardPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final centerTR = Offset(size.width, 0);
    for (double r = 40.0; r <= 220.0; r += 16.0) {
      canvas.drawCircle(centerTR, r, paint);
    }

    final centerBL = Offset(0, size.height);
    for (double r = 40.0; r <= 220.0; r += 16.0) {
      canvas.drawCircle(centerBL, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CardPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
