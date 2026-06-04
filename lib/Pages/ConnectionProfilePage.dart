import 'dart:convert';
import 'package:connect/Models/profile_card_type.dart';
import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Providers/ProviderSQL.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  late final ProfileProvider2 provider;
  String _sharedCardPermission = 'both'; // what they share with me
  String _mySharedCardToThem = 'both'; // what I share with them

  @override
  void initState() {
    super.initState();
    provider = Provider.of<ProfileProvider2>(context, listen: false);
    _loadProfileData();
  }

  bool _isFieldVisible(
      String fieldName, Map<String, dynamic>? fieldAssignments) {
    String key = fieldName;
    if (fieldName == 'professionalEmail') {
      key = 'email';
    } else if (fieldName == 'professionalPhoneNumber') {
      key = 'phoneNumber';
    } else if (fieldName == 'professionalBio') {
      key = 'bio';
    }

    if (key == 'name' || key == 'avatarUrl') return true;
    if (fieldAssignments == null) return true;

    final assignmentMap = fieldAssignments[key];
    if (assignmentMap == null) return true;

    final bool isCasual = assignmentMap['c'] == true;
    final bool isProfessional = assignmentMap['p'] == true;

    if (_sharedCardPermission == 'casual') {
      return isCasual;
    } else if (_sharedCardPermission == 'professional') {
      return isProfessional;
    } else {
      return isCasual || isProfessional;
    }
  }

  Future<void> _loadProfileData() async {
    final data = widget.profileData;
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

    final String initialProfEmail = _professionalEmail;
    final String initialProfPhone = _professionalPhoneNumber;

    _casualFields = {
      'email': _email,
      'phoneNumber': _phoneNumber,
      'instagram': _instagram,
      'linkedin': _linkedin,
      'twitter': _twitter,
      'bio': _bio,
    };
    _professionalFields = {
      'email': initialProfEmail,
      'phoneNumber': initialProfPhone,
      'instagram': _instagram,
      'linkedin': _linkedin,
      'twitter': _twitter,
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
        final response = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', idToFetch)
            .maybeSingle();

        final myUserId = provider.userId;
        if (myUserId != -1) {
          final connResponse = await Supabase.instance.client
              .from('network_graph')
              .select('shared_card')
              .eq('primary_user_id', myUserId)
              .eq('connected_user_id', idToFetch)
              .maybeSingle();
          if (connResponse != null) {
            _sharedCardPermission = connResponse['shared_card'] ?? 'both';
          }

          final int id1 = myUserId < idToFetch ? myUserId : idToFetch;
          final int id2 = myUserId > idToFetch ? myUserId : idToFetch;
          final rawConn = await Supabase.instance.client
              .from('user_connections')
              .select()
              .eq('user_id_1', id1)
              .eq('user_id_2', id2)
              .maybeSingle();
          if (rawConn != null) {
            if (myUserId < idToFetch) {
              _mySharedCardToThem = rawConn['user_1_shared_card'] ?? 'both';
            } else {
              _mySharedCardToThem = rawConn['user_2_shared_card'] ?? 'both';
            }
          }
        }

        if (response != null && mounted) {
          final Map<String, dynamic>? fieldAssignments =
              response['field_assignments'] is Map<String, dynamic>
                  ? response['field_assignments'] as Map<String, dynamic>
                  : (response['field_assignments'] is String
                      ? jsonDecode(response['field_assignments'] as String)
                          as Map<String, dynamic>
                      : null);

          setState(() {
            _name = response['name'] ?? '';
            _avatarUrl = response['avatar_url'] ?? '';
            _profession = response['profession'] ?? '';
            _company = response['company'] ?? '';
            _email = _isFieldVisible('email', fieldAssignments)
                ? (response['email'] ?? '')
                : '';
            _professionalEmail =
                _isFieldVisible('professionalEmail', fieldAssignments)
                    ? (response['professional_email'] ?? '')
                    : '';
            _phoneNumber = _isFieldVisible('phoneNumber', fieldAssignments)
                ? (response['phone_number'] ?? '')
                : '';
            _professionalPhoneNumber =
                _isFieldVisible('professionalPhoneNumber', fieldAssignments)
                    ? (response['professional_phone_number'] ?? '')
                    : '';
            _instagram = _isFieldVisible('instagram', fieldAssignments)
                ? (response['instagram'] ?? '')
                : '';
            _linkedin = _isFieldVisible('linkedin', fieldAssignments)
                ? (response['linkedin'] ?? '')
                : '';
            _twitter = _isFieldVisible('twitter', fieldAssignments)
                ? (response['twitter'] ?? '')
                : '';
            _bio = _isFieldVisible('bio', fieldAssignments)
                ? (response['bio'] ?? '')
                : '';
          });

          // Build per-card filtered field sets
          final Map<String, dynamic>? fa = fieldAssignments;

          String _filterField(String field, String rawValue) {
            String key = field;
            if (field == 'professionalEmail') {
              key = 'email';
            } else if (field == 'professionalPhoneNumber') {
              key = 'phoneNumber';
            } else if (field == 'professionalBio') {
              key = 'bio';
            }
            if (key == 'name' || key == 'avatarUrl') return rawValue;
            if (fa == null) return rawValue;
            final assignmentMap = fa[key];
            if (assignmentMap == null) return rawValue;
            return assignmentMap['c'] == true ? rawValue : '';
          }

          String _filterFieldPro(String field, String rawValue) {
            String key = field;
            if (field == 'professionalEmail') {
              key = 'email';
            } else if (field == 'professionalPhoneNumber') {
              key = 'phoneNumber';
            } else if (field == 'professionalBio') {
              key = 'bio';
            }
            if (key == 'name' || key == 'avatarUrl') return rawValue;
            if (fa == null) return rawValue;
            final assignmentMap = fa[key];
            if (assignmentMap == null) return rawValue;
            return assignmentMap['p'] == true ? rawValue : '';
          }

          setState(() {
            final String rawEmail = response['email'] ?? '';
            final String rawPhone = response['phone_number'] ?? '';
            final String rawProfEmail = response['professional_email'] ?? '';
            final String rawProfPhone =
                response['professional_phone_number'] ?? '';

            final String filterCasualEmail = _filterField('email', rawEmail);
            final String filterCasualPhone =
                _filterField('phoneNumber', rawPhone);

            final String filterProfEmail =
                _filterFieldPro('professionalEmail', rawProfEmail);

            final String filterProfPhone =
                _filterFieldPro('professionalPhoneNumber', rawProfPhone);

            _casualFields = {
              'email': filterCasualEmail,
              'phoneNumber': filterCasualPhone,
              'instagram':
                  _filterField('instagram', response['instagram'] ?? ''),
              'linkedin': _filterField('linkedin', response['linkedin'] ?? ''),
              'twitter': _filterField('twitter', response['twitter'] ?? ''),
              'bio': _filterField('bio', response['bio'] ?? ''),
            };

            final String rawProfBio = response['professional_bio'] ?? '';
            _professionalBio =
                _isFieldVisible('professionalBio', fieldAssignments)
                    ? rawProfBio
                    : '';

            _professionalFields = {
              'email': filterProfEmail,
              'phoneNumber': filterProfPhone,
              'instagram':
                  _filterFieldPro('instagram', response['instagram'] ?? ''),
              'linkedin':
                  _filterFieldPro('linkedin', response['linkedin'] ?? ''),
              'twitter': _filterFieldPro('twitter', response['twitter'] ?? ''),
              'bio': _filterFieldPro('professionalBio', rawProfBio),
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
    if (comp.isNotEmpty) {
      return comp;
    }
    final cleanName = name.toLowerCase().trim();
    if (cleanName.contains('sarah') || cleanName.contains('chen')) {
      return 'TechFlow Inc.';
    } else if (cleanName.contains('marcus') || cleanName.contains('lee')) {
      return 'CodeCraft Studios';
    } else if (cleanName.contains('asha')) {
      return 'Innovate Labs';
    } else if (cleanName.contains('alex') || cleanName.contains('vance')) {
      return 'Vortex Media';
    } else if (cleanName.contains('santosh')) {
      return 'Antigravity Labs';
    }
    final hash = name.codeUnits.fold<int>(0, (prev, element) => prev + element);
    final companies = [
      'TechFlow Inc.',
      'CodeCraft Studios',
      'Synergy Corp',
      'Pixel Perfect',
      'AppVentures',
    ];
    return companies[hash % companies.length];
  }

  String _getBio(String name, String bioText) {
    if (bioText.isNotEmpty) {
      return bioText;
    }
    final cleanName = name.toLowerCase().trim();
    if (cleanName.contains('sarah') || cleanName.contains('chen')) {
      return 'Senior Product Designer at TechFlow Inc. Passionate about crafting high-fidelity design systems and user experiences.';
    } else if (cleanName.contains('marcus') || cleanName.contains('lee')) {
      return 'Lead Software Engineer. Building robust mobile apps and cloud architectures with Flutter and Go.';
    } else if (cleanName.contains('asha')) {
      return 'Product Manager. Driving innovation in AI-first developer tools and user-centric features.';
    } else if (cleanName.contains('alex') || cleanName.contains('vance')) {
      return 'Creative Director. Design strategist and tech enthusiast helping early-stage startups establish their visual identity.';
    } else if (cleanName.contains('santosh')) {
      return 'Fullstack developer & designer crafting seamless experiences across web and mobile ecosystems.';
    }
    return 'Digital Identity on Connect. Tap scan or view profile to start connecting and collaborating.';
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(30.0),
        border: Border.all(
          color: const Color(0xFF1F2030),
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
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF1C1D2A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          Column(
            children: const [
              Text(
                'Card Preview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                  fontFamily: 'Inter',
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Digital Card',
                style: TextStyle(
                  color: Color(0xFF8B8C9E),
                  fontSize: 11.0,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          // Message Button to start/view chat with this connection
          GestureDetector(
            onTap: () {
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
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF1C1D2A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF00F2FE),
                size: 16,
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
        color: const Color(0xFF161726),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF26273F)),
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
                    _showFront ? const Color(0xFF8B5CF6) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                'FRONT',
                style: TextStyle(
                  color: _showFront ? Colors.white : const Color(0xFF5C5E78),
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
                    !_showFront ? const Color(0xFF8B5CF6) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                'BACK',
                style: TextStyle(
                  color: !_showFront ? Colors.white : const Color(0xFF5C5E78),
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
    final isCasual = false;

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
              borderRadius: BorderRadius.circular(24.0),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF00F2FE),
                  Color(0xFF8B5CF6),
                  Color(0xFFEC4899),
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
                            scale: Tween<double>(begin: 0.96, end: 1.0)
                                .animate(animation),
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
    final isCasual = false;
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
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/icons/Connect Icon2.png',
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
    final isCasual = false;
    final W = cardWidth;
    final H = cardWidth / 1.58;
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF00F2FE), Color(0xFF8B5CF6)],
                  ),
                ),
                child: ClipOval(
                  child: (avatar.isNotEmpty &&
                          avatar.contains(
                              'supabase.co/storage/v1/object/public/avatars/'))
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
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF00F2FE)],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2030)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8B8C9E),
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.content_copy_rounded,
                color: Color(0xFF5C5E78), size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value)).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Copied $label to clipboard!"),
                    backgroundColor: const Color(0xFF8B5CF6),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2030)),
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
                  style: const TextStyle(
                    color: Color(0xFF8B8C9E),
                    fontSize: 11,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  handle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.content_copy_rounded,
                color: Color(0xFF5C5E78), size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: handle)).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Copied $title handle to clipboard!"),
                    backgroundColor: const Color(0xFF8B5CF6),
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

  @override
  Widget build(BuildContext context) {
    final String avatar = _getAvatarUrl(_name, _avatarUrl);
    final String comp = _getCompany(_name, _company);
    final String bio = _getBio(_name, _bio);

    // Mock social media logos matching profile page
    final linkedinLogo = Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFF0077B5),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.link_rounded, color: Colors.white, size: 18),
    );
    final twitterLogo = Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFF1DA1F2),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
    );
    final instagramLogo = Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
        ),
        shape: BoxShape.circle,
      ),
      child:
          const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
    );
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 16),
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
                    const Text(
                      'CONNECTION DETAILS',
                      style: TextStyle(
                        color: Color(0xFF8B8C9E),
                        fontSize: 14.0,
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
                    // Profession & Company are professional details — only show
                    // when the professional or both card is shared.
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
                    // but only if the values actually differ; otherwise show one.
                    if (_sharedCardPermission == 'both')
                      ..._buildBothFields(
                        casualFields: _casualFields,
                        professionalFields: _professionalFields,
                        linkedinLogo: linkedinLogo,
                        twitterLogo: twitterLogo,
                        instagramLogo: instagramLogo,
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
                      ].any((v) => v.trim().isNotEmpty)) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'SOCIAL HANDLES',
                          style: TextStyle(
                            color: Color(0xFF8B8C9E),
                            fontSize: 14.0,
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
                      ],
                    ]
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

    // --- Social handles ---
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
    ].any((v) => (v ?? '').trim().isNotEmpty);

    if (hasAnySocial) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(const Text(
        'SOCIAL HANDLES',
        style: TextStyle(
          color: Color(0xFF8B8C9E),
          fontSize: 14.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ));
      widgets.add(const SizedBox(height: 16));
      addSocial('linkedin', 'LinkedIn', linkedinLogo);
      addSocial('twitter', 'Twitter', twitterLogo);
      addSocial('instagram', 'Instagram', instagramLogo);
    }

    return widgets;
  }

  Widget _buildPreviewTabSelector() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2030)),
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
          color: isActive ? const Color(0xFF8B5CF6) : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : const Color(0xFF8B8C9E),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF8B8C9E),
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
        color: const Color(0xFF131422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF26273F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.security_rounded, color: Color(0xFF00F2FE), size: 18),
              SizedBox(width: 8),
              Text(
                "ACCESS PERMISSIONS",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Configure which digital card of yours this contact can see:",
            style: TextStyle(
              color: Color(0xFF8B8C9E),
              fontSize: 11.5,
              fontFamily: 'Inter',
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
        color: const Color(0xFF0C0D16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2030)),
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
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF5C5E78),
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

    await provider.updateConnectionAccess(otherUserId, accessType);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Sharing settings updated to ${accessType.toUpperCase()}"),
          backgroundColor: const Color(0xFF8B5CF6),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
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
