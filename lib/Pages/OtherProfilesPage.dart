import 'dart:convert';
import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:connect/Pages/QrCodeScanner.dart';
import 'package:connect/Providers/ProviderSQL.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OtherProfilesPage extends StatefulWidget {
  const OtherProfilesPage({super.key});

  @override
  State<OtherProfilesPage> createState() => _OtherProfilesPageState();
}

class _OtherProfilesPageState extends State<OtherProfilesPage> {
  bool _isGridView = true; // true = Card View, false = List View
  Set<String> _favoritedIds = {};
  Set<String> _deletedProfileIds = {};
  late ProfileProvider2 profileProvider;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadDeletedProfiles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        profileProvider = Provider.of<ProfileProvider2>(context, listen: false);
        setState(() {});
      }
    });
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('favorite_connection_ids') ?? [];
      if (mounted) {
        setState(() {
          _favoritedIds = list.toSet();
        });
      }
    } catch (e) {
      print("Error loading favorites: $e");
    }
  }

  Future<void> _toggleFavorite(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        if (_favoritedIds.contains(id)) {
          _favoritedIds.remove(id);
        } else {
          _favoritedIds.add(id);
        }
      });
      await prefs.setStringList(
          'favorite_connection_ids', _favoritedIds.toList());
    } catch (e) {
      print("Error toggling favorite: $e");
    }
  }

  Future<void> _loadDeletedProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('deleted_profile_ids') ?? [];
      if (mounted) {
        setState(() {
          _deletedProfileIds = list.toSet();
        });
      }
    } catch (e) {
      print("Error loading deleted profiles: $e");
    }
  }

  Future<void> _deleteProfileLocally(
      String id, ProfileProvider2 provider) async {
    try {
      final intId = int.tryParse(id) ?? 0;
      await provider.deleteProfile(intId);
    } catch (e) {
      print("Error deleting profile locally: $e");
    }
  }

  String _getVisibleField(
    Map<String, dynamic> profileData,
    String fieldKey,
    String rawValue,
  ) {
    // name and avatar are always visible
    if (fieldKey == 'name' || fieldKey == 'avatarUrl') return rawValue;

    // Determine what card type this viewer has access to
    final String sharedCard =
        (profileData['sharedCard'] ?? profileData['shared_card'] ?? 'both')
            .toString();

    // If no field_assignments data present, show everything
    final dynamic faRaw = profileData['field_assignments'];
    if (faRaw == null) return rawValue;

    Map<String, dynamic> fa;
    try {
      fa = faRaw is String
          ? jsonDecode(faRaw) as Map<String, dynamic>
          : faRaw as Map<String, dynamic>;
    } catch (_) {
      return rawValue;
    }

    final dynamic assignmentRaw = fa[fieldKey];
    if (assignmentRaw == null) return rawValue;

    final Map<String, dynamic> assignment =
        assignmentRaw as Map<String, dynamic>;
    final bool isCasual = assignment['c'] == true;
    final bool isProfessional = assignment['p'] == true;

    if (sharedCard == 'casual') return isCasual ? rawValue : '';
    if (sharedCard == 'professional') return isProfessional ? rawValue : '';
    // 'both': show if on either card
    return (isCasual || isProfessional) ? rawValue : '';
  }

  // Deterministic fallbacks to guarantee high-fidelity presentation
  String _getAvatarUrl(String name, String? existingUrl) {
    if (existingUrl != null &&
        existingUrl.isNotEmpty &&
        existingUrl.startsWith('http')) {
      return existingUrl;
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

  String _getCompany(String name, String? existingCompany) {
    if (existingCompany != null && existingCompany.isNotEmpty) {
      return existingCompany;
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

  String _getBio(String name, String? existingBio) {
    if (existingBio != null && existingBio.isNotEmpty) {
      return existingBio;
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

  List<String> _getCardTypesForProfile(Map<String, dynamic> profile) {
    if (profile.containsKey('cardTypes')) {
      return List<String>.from(profile['cardTypes']);
    }

    final allTypes = <String>[];

    final hasInstagram = (profile['instagram'] ?? '').toString().isNotEmpty;
    final hasTwitter = (profile['twitter'] ?? '').toString().isNotEmpty;
    final hasCasualBio = (profile['bio'] ?? '').toString().isNotEmpty;

    final hasLinkedin = (profile['linkedin'] ?? '').toString().isNotEmpty;
    final hasCompany = (profile['company'] ?? '').toString().isNotEmpty;
    final hasEmail = (profile['email'] ?? '').toString().isNotEmpty;

    if (hasInstagram ||
        hasTwitter ||
        hasCasualBio ||
        (!hasLinkedin && !hasCompany)) {
      allTypes.add('casual');
    }
    if (hasLinkedin || hasCompany || hasEmail) {
      allTypes.add('professional');
    }

    if (allTypes.isEmpty) {
      allTypes.addAll(['casual', 'professional']);
    }

    return allTypes;
  }

  Widget _buildCardTypeBadges(Map<String, dynamic> profile) {
    final types = _getCardTypesForProfile(profile);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final type in types) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: type == 'casual'
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                  : const Color(0xFF00F2FE).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: type == 'casual'
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.35)
                    : const Color(0xFF00F2FE).withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Text(
              type == 'casual' ? 'CASUAL' : 'PROFESSIONAL',
              style: TextStyle(
                color: type == 'casual'
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF00F2FE),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
  }

  void _showSendMessageDialog(
      BuildContext context, Map<String, dynamic> profile) {
    final name = profile['name'] ?? 'Connection';
    final controller = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F1020),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: Color(0xFF26273F), width: 1),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF26273F),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Message to $name",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "This will send a message via your connected profile.",
                    style: TextStyle(
                      color: Color(0xFF8B8C9E),
                      fontSize: 13,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    maxLength: 500,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontFamily: 'Inter'),
                    cursorColor: const Color(0xFF8B5CF6),
                    decoration: InputDecoration(
                      hintText: "Write your message here...",
                      hintStyle: const TextStyle(
                          color: Color(0xFF5C5E78), fontSize: 14),
                      fillColor: const Color(0xFF161726),
                      filled: true,
                      counterStyle: const TextStyle(color: Color(0xFF5C5E78)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF26273F)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isSending
                        ? null
                        : () async {
                            if (controller.text.trim().isEmpty) return;
                            setModalState(() {
                              isSending = true;
                            });
                            await Future.delayed(
                                const Duration(milliseconds: 1200));
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Message sent to $name!"),
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      disabledBackgroundColor:
                          const Color(0xFF8B5CF6).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isSending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            "Send Message",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'Inter',
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showViewCardDialog(BuildContext context, Map<String, dynamic> profile) {
    bool isFront = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final String name = profile['name'] ?? 'Unknown';
            final String profession = profile['profession'] ?? '';
            final String companyName = _getCompany(name, profile['company']);
            final String email = profile['email'] ?? '';
            final String phone = profile['phoneNumber'] ?? '';
            final String bio = _getBio(name, profile['bio']);
            final String avatar = _getAvatarUrl(name, profile['avatarUrl']);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        isFront = !isFront;
                      });
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) {
                        final rotate =
                            Tween(begin: 3.14, end: 0.0).animate(animation);
                        return AnimatedBuilder(
                          animation: rotate,
                          builder: (context, widget) {
                            final value = rotate.value;
                            final matrix = Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(value);
                            return Transform(
                              transform: matrix,
                              alignment: Alignment.center,
                              child: widget,
                            );
                          },
                          child: child,
                        );
                      },
                      child: isFront
                          ? _buildDialogCardFront(
                              name, profession, companyName, avatar)
                          : _buildDialogCardBack(name, email, phone, bio),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Tap the card to flip it",
                    style: TextStyle(
                      color: Color(0xFF8B8C9E),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161726),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF26273F)),
                      ),
                      child: const Text(
                        "Close Preview",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogCardFront(
      String name, String profession, String company, String avatar) {
    return Container(
      key: const ValueKey('front'),
      width: 320,
      height: 190,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B1B3A),
            Color(0xFF0C0C18),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2F305A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -30,
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/icons/Connect Icon2.png',
                width: 160,
                height: 160,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/icons/Connect Icon2.png',
                        width: 18,
                        height: 18,
                        color: const Color(0xFF00F2FE),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "CONNECT",
                        style: TextStyle(
                          color: Color(0xFF00F2FE),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F2FE).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFF00F2FE).withOpacity(0.3)),
                    ),
                    child: const Text(
                      "DIGITAL ID",
                      style: TextStyle(
                        color: Color(0xFF00F2FE),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF00F2FE), Color(0xFF8B5CF6)],
                      ),
                    ),
                    padding: const EdgeInsets.all(1.5),
                    child: ClipOval(
                      child: (avatar.isNotEmpty &&
                              avatar.contains(
                                  'supabase.co/storage/v1/object/public/avatars/'))
                          ? Image.network(
                              avatar,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: const Color(0xFF1B1C2A),
                                alignment: Alignment.center,
                                child: Text(
                                  name.isNotEmpty
                                      ? name.substring(0, 1).toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF1B1C2A),
                              alignment: Alignment.center,
                              child: Text(
                                name.isNotEmpty
                                    ? name.substring(0, 1).toUpperCase()
                                    : "?",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profession,
                          style: const TextStyle(
                            color: Color(0xFF00F2FE),
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (company.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            company,
                            style: const TextStyle(
                              color: Color(0xFF8B8C9E),
                              fontSize: 11,
                              fontFamily: 'Inter',
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDialogCardBack(
      String name, String email, String phone, String bio) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(3.14),
      child: Container(
        key: const ValueKey('back'),
        width: 320,
        height: 190,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B1B3A),
              Color(0xFF0C0C18),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2F305A), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                bio.isNotEmpty ? bio : 'No bio provided for this card.',
                style: const TextStyle(
                  color: Color(0xFF8B8C9E),
                  fontSize: 11,
                  fontFamily: 'Inter',
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              height: 1,
              color: const Color(0xFF2F305A),
              margin: const EdgeInsets.symmetric(vertical: 8),
            ),
            if (email.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.alternate_email_rounded,
                      color: Color(0xFF8B5CF6), size: 12),
                  const SizedBox(width: 6),
                  Text(
                    email,
                    style: const TextStyle(
                      color: Color(0xFFC0C1D0),
                      fontSize: 10,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone_rounded,
                      color: Color(0xFF8B5CF6), size: 12),
                  const SizedBox(width: 6),
                  Text(
                    phone,
                    style: const TextStyle(
                      color: Color(0xFFC0C1D0),
                      fontSize: 10,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCircularActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF161726),
          border: Border.all(color: const Color(0xFF26273F), width: 1),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildToggleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "ALL CARDS",
            style: TextStyle(
              color: Color(0xFF5C5E78),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontFamily: 'Inter',
            ),
          ),
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF10111F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF202138), width: 1),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isGridView = true;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _isGridView
                          ? const Color(0xFF8B5CF6)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      color:
                          _isGridView ? Colors.white : const Color(0xFF5C5E78),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isGridView = false;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 34,
                    decoration: BoxDecoration(
                      color: !_isGridView
                          ? const Color(0xFF8B5CF6)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.view_list_rounded,
                      size: 18,
                      color:
                          !_isGridView ? Colors.white : const Color(0xFF5C5E78),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(
      Map<String, dynamic> profileData, ProfileProvider2 provider) {
    final name = profileData["name"] ?? "Unknown";
    final profession = profileData["profession"] ?? "";
    final String email =
        _getVisibleField(profileData, 'email', profileData["email"] ?? '');
    final String company = _getVisibleField(
      profileData,
      'company',
      _getCompany(name, profileData["company"]),
    );
    final avatarUrl = _getAvatarUrl(name, profileData["avatarUrl"]);
    final profileIdStr = (profileData['id'] ?? '').toString();
    final isFavorite = _favoritedIds.contains(profileIdStr);

    final int id = profileData['id'] is int
        ? profileData['id'] as int
        : int.tryParse(profileData['id'].toString()) ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConnectionProfilePage(
              profileData: profileData,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF18192E),
              Color(0xFF0F1020),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF26273F),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF00F2FE), Color(0xFF8B5CF6)],
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF090A0F),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: (avatarUrl.isNotEmpty &&
                              avatarUrl.contains(
                                  'supabase.co/storage/v1/object/public/avatars/'))
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: const Color(0xFF1B1C2A),
                                alignment: Alignment.center,
                                child: Text(
                                  name.isNotEmpty
                                      ? name.substring(0, 1).toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF1B1C2A),
                              alignment: Alignment.center,
                              child: Text(
                                name.isNotEmpty
                                    ? name.substring(0, 1).toUpperCase()
                                    : "?",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profession,
                        style: const TextStyle(
                          color: Color(0xFF8B8C9E),
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _buildCardTypeBadges(profileData),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<int>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert_rounded,
                          color: Color(0xFF5C5E78)),
                      color: const Color(0xFF10111F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF202138)),
                      ),
                      onSelected: (val) async {
                        if (val == 1) {
                          try {
                            await _deleteProfileLocally(profileIdStr, provider);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Profile deleted successfully"),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text("Error deleting profile: $e")),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 1,
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text("Delete",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: const Color(0xFF1F2032),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (company.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.business_center_rounded,
                          color: Color(0xFF5C5E78), size: 14),
                      const SizedBox(width: 8),
                      Text(
                        company,
                        style: const TextStyle(
                          color: Color(0xFFC0C1D0),
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (email.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.alternate_email_rounded,
                          color: Color(0xFF5C5E78), size: 14),
                      const SizedBox(width: 8),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Color(0xFFC0C1D0),
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showSendMessageDialog(context, profileData);
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                        size: 16, color: Colors.white),
                    label: const Text(
                      "Message",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(
      Map<String, dynamic> profileData, ProfileProvider2 provider) {
    final name = profileData["name"] ?? "Unknown";
    final profession = profileData["profession"] ?? "";
    final String company = _getVisibleField(
      profileData,
      'company',
      _getCompany(name, profileData["company"]),
    );
    final avatarUrl = _getAvatarUrl(name, profileData["avatarUrl"]);
    final profileIdStr = (profileData['id'] ?? '').toString();
    final isFavorite = _favoritedIds.contains(profileIdStr);

    final int id = profileData['id'] is int
        ? profileData['id'] as int
        : int.tryParse(profileData['id'].toString()) ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConnectionProfilePage(
              profileData: profileData,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF10111F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1F2035), width: 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00F2FE), Color(0xFF8B5CF6)],
                ),
              ),
              padding: const EdgeInsets.all(1.5),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF090A0F),
                ),
                padding: const EdgeInsets.all(1.5),
                child: ClipOval(
                  child: (avatarUrl.isNotEmpty &&
                          avatarUrl.contains(
                              'supabase.co/storage/v1/object/public/avatars/'))
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: const Color(0xFF1B1C2A),
                            alignment: Alignment.center,
                            child: Text(
                              name.isNotEmpty
                                  ? name.substring(0, 1).toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF1B1C2A),
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty
                                ? name.substring(0, 1).toUpperCase()
                                : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    profession.isNotEmpty && company.isNotEmpty
                        ? "$profession  •  $company"
                        : (profession.isNotEmpty ? profession : company),
                    style: const TextStyle(
                      color: Color(0xFF8B8C9E),
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  _buildCardTypeBadges(profileData),
                ],
              ),
            ),
            PopupMenuButton<int>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert_rounded,
                  color: Color(0xFF5C5E78), size: 20),
              color: const Color(0xFF10111F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF202138)),
              ),
              onSelected: (val) async {
                if (val == 1) {
                  try {
                    await _deleteProfileLocally(profileIdStr, provider);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Profile deleted successfully"),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error deleting profile: $e")),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 18),
                      SizedBox(width: 8),
                      Text("Delete",
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider2>();
    final allProfiles = provider.connections;
    final count = allProfiles.length;

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Premium Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Konnections",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$count ${count == 1 ? 'connection' : 'connections'}",
                        style: const TextStyle(
                          color: Color(0xFF8B8C9E),
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildCircularActionButton(
                        icon: Icons.qr_code_scanner_rounded,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const QRScannerPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Toggle Switch Row
            _buildToggleRow(),
            // Connection Content list or loading
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: allProfiles.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              color: Color(0xFF5C5E78),
                              size: 48,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "No profiles available.",
                              style: TextStyle(
                                color: Color(0xFF8B8C9E),
                                fontSize: 15,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        key: ValueKey<bool>(_isGridView),
                        itemCount: allProfiles.length,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        itemBuilder: (context, index) {
                          final item = allProfiles[index];
                          return _isGridView
                              ? _buildCardItem(item, provider)
                              : _buildListItem(item, provider);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
