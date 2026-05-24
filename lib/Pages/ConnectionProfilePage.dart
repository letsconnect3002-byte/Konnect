import 'dart:convert';
import 'package:connect/Models/profile_card_type.dart';
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

  ProfileCardType _previewCard = ProfileCardType.casual;
  bool _showFront = true;
  bool _isLoading = false;

  late String _name;
  late String _profession;
  late String _company;
  late String _email;
  late String _phoneNumber;
  late String _bio;
  late String _avatarUrl;
  late String _instagram;
  late String _linkedin;
  late String _twitter;

  late final ProfileProvider2 provider;
  String _sharedCardPermission = 'both'; // what they share with me
  String _mySharedCardToThem = 'both'; // what I share with them

  @override
  void initState() {
    super.initState();
    provider = Provider.of<ProfileProvider2>(context, listen: false);
    _loadProfileData();
  }

  bool _isFieldVisible(String fieldName, Map<String, dynamic>? fieldAssignments) {
    if (fieldName == 'name' || fieldName == 'avatarUrl') return true;
    if (fieldAssignments == null) return true;
    
    final assignmentMap = fieldAssignments[fieldName];
    if (assignmentMap == null) return true;
    
    final bool isCasual = assignmentMap['c'] == true;
    final bool isProfessional = assignmentMap['p'] == true || assignmentMap['p'] != false;
    
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
    _phoneNumber = data['phoneNumber'] ?? data['phone_number'] ?? '';
    _bio = data['bio'] ?? '';
    _avatarUrl = data['avatarUrl'] ?? data['avatar_url'] ?? '';
    _instagram = data['instagram'] ?? '';
    _linkedin = data['linkedin'] ?? '';
    _twitter = data['twitter'] ?? '';

    final connectionProfileId = data['connection_profile_id'];
    if (connectionProfileId != null) {
      if (mounted) {
        setState(() => _isLoading = true);
      }
      try {
        final idToFetch = connectionProfileId is int ? connectionProfileId : int.parse(connectionProfileId.toString());
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

        if (_sharedCardPermission == 'casual') {
          _previewCard = ProfileCardType.casual;
        } else if (_sharedCardPermission == 'professional') {
          _previewCard = ProfileCardType.professional;
        }

        if (response != null && mounted) {
          final Map<String, dynamic>? fieldAssignments = response['field_assignments'] is Map<String, dynamic>
              ? response['field_assignments'] as Map<String, dynamic>
              : (response['field_assignments'] is String
                  ? jsonDecode(response['field_assignments'] as String) as Map<String, dynamic>
                  : null);

          setState(() {
            _name = response['name'] ?? '';
            _avatarUrl = response['avatar_url'] ?? '';
            _profession = _isFieldVisible('profession', fieldAssignments) ? (response['profession'] ?? '') : '';
            _company = _isFieldVisible('company', fieldAssignments) ? (response['company'] ?? '') : '';
            _email = _isFieldVisible('email', fieldAssignments) ? (response['email'] ?? '') : '';
            _phoneNumber = _isFieldVisible('phoneNumber', fieldAssignments) ? (response['phone_number'] ?? '') : '';
            _instagram = _isFieldVisible('instagram', fieldAssignments) ? (response['instagram'] ?? '') : '';
            _linkedin = _isFieldVisible('linkedin', fieldAssignments) ? (response['linkedin'] ?? '') : '';
            _twitter = _isFieldVisible('twitter', fieldAssignments) ? (response['twitter'] ?? '') : '';
            _bio = _isFieldVisible('bio', fieldAssignments) ? (response['bio'] ?? '') : '';
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

  // Deterministic fallbacks to match the card view list
  String _getAvatarUrl(String name, String url) {
    if (url.isNotEmpty && url.startsWith('http')) {
      return url;
    }
    final cleanName = name.toLowerCase().trim();
    if (cleanName.contains('sarah') || cleanName.contains('chen')) {
      return 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80';
    } else if (cleanName.contains('marcus') || cleanName.contains('lee')) {
      return 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80';
    } else if (cleanName.contains('asha')) {
      return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80';
    } else if (cleanName.contains('alex') || cleanName.contains('vance')) {
      return 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80';
    } else if (cleanName.contains('santosh')) {
      return 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=300&q=80';
    }
    final hash = name.codeUnits.fold<int>(0, (prev, element) => prev + element);
    final avatars = [
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
      'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=300&q=80',
    ];
    return avatars[hash % avatars.length];
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
                'Digital Business Card',
                style: TextStyle(
                  color: Color(0xFF8B8C9E),
                  fontSize: 11.0,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          // Placeholder circular indicator to balance visual balance
          const Opacity(
            opacity: 0,
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTypeTabs() {
    final isCasual = _previewCard == ProfileCardType.casual;
    final bool casualLocked = _sharedCardPermission == 'professional';
    final bool professionalLocked = _sharedCardPermission == 'casual';

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2030)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: casualLocked
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Access to Casual card restricted by user")),
                      );
                    }
                  : () => setState(() => _previewCard = ProfileCardType.casual),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isCasual && !casualLocked
                      ? const Color(0xFF8B5CF6)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'CASUAL CARD',
                      style: TextStyle(
                        color: casualLocked
                            ? const Color(0xFF5C5E78).withOpacity(0.3)
                            : (isCasual ? Colors.white : const Color(0xFF5C5E78)),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                    if (casualLocked) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock_rounded, size: 12, color: const Color(0xFF5C5E78).withOpacity(0.5)),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: professionalLocked
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Access to Professional card restricted by user")),
                      );
                    }
                  : () => setState(() => _previewCard = ProfileCardType.professional),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: !isCasual && !professionalLocked
                      ? const Color(0xFF8B5CF6)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'PROFESSIONAL CARD',
                      style: TextStyle(
                        color: professionalLocked
                            ? const Color(0xFF5C5E78).withOpacity(0.3)
                            : (!isCasual ? Colors.white : const Color(0xFF5C5E78)),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                    if (professionalLocked) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock_rounded, size: 12, color: const Color(0xFF5C5E78).withOpacity(0.5)),
                    ],
                  ],
                ),
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
                  fontSize: 10,
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
                  fontSize: 10,
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
    final isCasual = _previewCard == ProfileCardType.casual;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = isCasual ? cardWidth / 0.82 : cardWidth / 1.58;

        return AnimatedContainer(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.0),
            gradient: LinearGradient(
              colors: isCasual
                  ? const [
                      Color(0xFF8B5CF6),
                      Color(0xFF00F2FE),
                    ]
                  : const [
                      Color(0xFF00F2FE),
                      Color(0xFF8B5CF6),
                      Color(0xFFEC4899),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (isCasual
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF00F2FE))
                    .withOpacity(0.1),
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isCasual
                      ? const [Color(0xFF16182A), Color(0xFF0E1018)]
                      : const [Color(0xFF111222), Color(0xFF0A0B10)],
                ),
                borderRadius: BorderRadius.circular(22.5),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CardPatternPainter(
                        color: (isCasual
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFF00F2FE))
                            .withOpacity(0.06),
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
                    child: _showFront
                        ? _buildUnifiedFrontCard(cardWidth)
                        : _buildUnifiedBackCard(cardWidth),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnifiedFrontCard(double cardWidth) {
    final isCasual = _previewCard == ProfileCardType.casual;
    final W = cardWidth;
    final comp = _getCompany(_name, _company);
    final avatar = _getAvatarUrl(_name, _avatarUrl);

    return Stack(
      children: [
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: 0,
          right: 0,
          top: isCasual ? 34 : 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: _cardAnimDuration,
                curve: _cardAnimCurve,
                width: isCasual ? 56 : 44,
                height: isCasual ? 56 : 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCasual
                      ? const Color(0xFF171825)
                      : const Color(0xFF151628),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6)
                        .withOpacity(isCasual ? 0.35 : 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/icons/Connect Icon2.png',
                    width: isCasual ? 28 : 22,
                    height: isCasual ? 28 : 22,
                    color: isCasual
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF00F2FE),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedDefaultTextStyle(
                duration: _cardAnimDuration,
                curve: _cardAnimCurve,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCasual ? 14 : 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: isCasual ? 3.0 : 2.5,
                  fontFamily: 'Inter',
                ),
                child: Text(
                  comp.isEmpty ? 'CONNECT' : comp.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedCrossFade(
                duration: _cardAnimDuration,
                firstCurve: _cardAnimCurve,
                secondCurve: _cardAnimCurve,
                crossFadeState: isCasual
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Text(
                  'CASUAL CARD',
                  style: TextStyle(
                    color: const Color(0xFF8B5CF6).withOpacity(0.8),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontFamily: 'Inter',
                  ),
                ),
                secondChild: Text(
                  'DIGITAL IDENTITY',
                  style: TextStyle(
                    color: const Color(0xFF00F2FE).withOpacity(0.8),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ),

        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: isCasual ? 20 : 18,
          right: isCasual ? 20 : W * 0.4,
          bottom: isCasual ? 76 : 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedAlign(
                duration: _cardAnimDuration,
                curve: _cardAnimCurve,
                alignment: isCasual ? Alignment.center : Alignment.centerLeft,
                child: AnimatedDefaultTextStyle(
                  duration: _cardAnimDuration,
                  curve: _cardAnimCurve,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCasual ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                  child: Text(
                    _name.isEmpty ? 'Unknown' : _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_profession.isNotEmpty) ...[
                const SizedBox(height: 4),
                AnimatedAlign(
                  duration: _cardAnimDuration,
                  curve: _cardAnimCurve,
                  alignment: isCasual ? Alignment.center : Alignment.centerLeft,
                  child: AnimatedDefaultTextStyle(
                    duration: _cardAnimDuration,
                    curve: _cardAnimCurve,
                    style: TextStyle(
                      color: const Color(0xFF8B5CF6),
                      fontSize: isCasual ? 12 : 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                    child: Text(
                      _profession,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Central profile icon / visual in Casual card
        if (isCasual)
          Positioned(
            left: 20,
            right: 20,
            top: 148,
            bottom: 128,
            child: Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF00F2FE)],
                  ),
                ),
                padding: const EdgeInsets.all(2.5),
                child: ClipOval(
                  child: Image.network(
                    avatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person,
                      color: Colors.white60,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),

        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: isCasual ? (W - 160) / 2 : W - 98,
          bottom: isCasual ? 24 : 14,
          width: isCasual ? 160 : 80,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCasual ? 12 : 8,
              vertical: isCasual ? 6 : 4,
            ),
            decoration: BoxDecoration(
              color:
                  isCasual ? const Color(0xFF171825) : const Color(0xFF1E1F32),
              borderRadius: BorderRadius.circular(isCasual ? 8 : 6),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    color: const Color(0xFF00F2FE),
                    size: isCasual ? 14 : 11,
                  ),
                  const SizedBox(width: 4),
                  AnimatedCrossFade(
                    duration: _cardAnimDuration,
                    firstCurve: _cardAnimCurve,
                    secondCurve: _cardAnimCurve,
                    crossFadeState: isCasual
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: const Text(
                      'SCAN TO CONNECT',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                    ),
                    secondChild: const Text(
                      'SCAN',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                    ),
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
    final isCasual = _previewCard == ProfileCardType.casual;
    final W = cardWidth;
    final H = isCasual ? cardWidth / 0.82 : cardWidth / 1.58;
    final avatar = _getAvatarUrl(_name, _avatarUrl);
    final bio = _getBio(_name, _bio);

    return Stack(
      children: [
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: isCasual ? 20 : 16,
          right: isCasual ? 20 : 16,
          top: isCasual ? 16 : 12,
          height: isCasual ? 60 : 40,
          child: Row(
            children: [
              AnimatedContainer(
                duration: _cardAnimDuration,
                curve: _cardAnimCurve,
                width: isCasual ? 56 : 36,
                height: isCasual ? 56 : 36,
                padding: const EdgeInsets.all(1.0),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF00F2FE), Color(0xFF8B5CF6)],
                  ),
                ),
                child: ClipOval(
                  child: Image.network(
                    avatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.person_rounded,
                      color: Colors.white60,
                      size: isCasual ? 28 : 18,
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: _cardAnimDuration,
                curve: _cardAnimCurve,
                width: isCasual ? 14 : 10,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedDefaultTextStyle(
                        duration: _cardAnimDuration,
                        curve: _cardAnimCurve,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCasual ? 18 : 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                        child: Text(
                          _name.isEmpty ? 'Unknown' : _name,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    if (_profession.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedDefaultTextStyle(
                          duration: _cardAnimDuration,
                          curve: _cardAnimCurve,
                          style: const TextStyle(
                            color: Color(0xFF00F2FE),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                          child: Text(
                            _profession.toUpperCase(),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Accent divider line
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: isCasual ? 20 : 16,
          right: isCasual ? 20 : 16,
          top: isCasual ? H - 19 : 140,
          height: 1,
          child: Container(
            color: const Color(0xFF8B5CF6).withOpacity(0.25),
          ),
        ),

        // Business/casual content fields
        Positioned(
          left: isCasual ? 20 : 16,
          right: isCasual ? 20 : 16,
          top: isCasual ? 90 : 60,
          bottom: isCasual ? 30 : 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bio content block
              Expanded(
                child: Text(
                  bio.isEmpty ? 'No bio provided for this card.' : bio,
                  style: const TextStyle(
                    color: Color(0xFF8B8C9E),
                    fontSize: 11,
                    fontFamily: 'Inter',
                  ),
                  maxLines: isCasual ? 7 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              if (_email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.alternate_email_rounded,
                          color: Color(0xFF8B5CF6), size: 12),
                      const SizedBox(width: 8),
                      Text(
                        _email,
                        style: const TextStyle(
                          color: Color(0xFFC0C1D0),
                          fontSize: 10,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              if (_phoneNumber.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.phone_rounded,
                        color: Color(0xFF8B5CF6), size: 12),
                    const SizedBox(width: 8),
                    Text(
                      _phoneNumber,
                      style: const TextStyle(
                        color: Color(0xFFC0C1D0),
                        fontSize: 10,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
            ],
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
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 28),

              // CARD PREVIEW Tab selectors
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CARD PREVIEW',
                    style: TextStyle(
                      color: Color(0xFF8B8C9E),
                      fontSize: 14.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  _buildFrontBackToggle(),
                ],
              ),
              const SizedBox(height: 12),
              _buildCardTypeTabs(),
              const SizedBox(height: 16),

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
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              // Read-only Details
              _buildReadOnlyField(
                label: 'Full Name',
                value: _name,
                icon: Icons.person_outline_rounded,
              ),
              _buildReadOnlyField(
                label: 'Profession',
                value: _profession,
                icon: Icons.work_outline_rounded,
              ),
              _buildReadOnlyField(
                label: 'Company',
                value: comp,
                icon: Icons.apartment_rounded,
              ),
              _buildReadOnlyField(
                label: 'Email Address',
                value: _email,
                icon: Icons.email_outlined,
              ),
              _buildReadOnlyField(
                label: 'Phone Number',
                value: _phoneNumber,
                icon: Icons.phone_android_outlined,
              ),
              _buildReadOnlyField(
                label: 'Bio',
                value: bio,
                icon: Icons.description_outlined,
              ),

              // Social media block
              if (_linkedin.isNotEmpty ||
                  _twitter.isNotEmpty ||
                  _instagram.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'SOCIAL HANDLES',
                  style: TextStyle(
                    color: Color(0xFF8B8C9E),
                    fontSize: 14.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSocialCard(
                  title: 'LinkedIn',
                  handle: _linkedin,
                  logo: linkedinLogo,
                ),
                _buildSocialCard(
                  title: 'Twitter',
                  handle: _twitter,
                  logo: twitterLogo,
                ),
                _buildSocialCard(
                  title: 'Instagram',
                  handle: _instagram,
                  logo: instagramLogo,
                ),
              ],
            ],
          ),
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
    final connectionProfileId = widget.profileData['connection_profile_id'] ?? widget.profileData['id'];
    if (connectionProfileId == null) return;
    
    final int otherUserId = connectionProfileId is int ? connectionProfileId : int.parse(connectionProfileId.toString());
    
    setState(() {
      _mySharedCardToThem = accessType;
    });
    
    await provider.updateConnectionAccess(otherUserId, accessType);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sharing settings updated to ${accessType.toUpperCase()}"),
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
