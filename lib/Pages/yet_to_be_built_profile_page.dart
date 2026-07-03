import 'dart:async';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/profile_card_type.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Pages/SettingsPage.dart';
import 'package:connect/Pages/edit_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Widgets/connect_hub_bottom_sheet.dart';
import 'package:connect/services/analytics_service.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connect/services/image_upload_service.dart';
import 'package:connect/Pages/crop_image_page.dart';

class YetToBeBuiltProfilePage extends StatefulWidget {
  final bool isEditingMode;
  const YetToBeBuiltProfilePage({super.key, this.isEditingMode = false});

  @override
  State<YetToBeBuiltProfilePage> createState() =>
      _YetToBeBuiltProfilePageState();
}

class _YetToBeBuiltProfilePageState extends State<YetToBeBuiltProfilePage> {
  static const _cardAnimDuration = Duration(milliseconds: 400);
  static const _cardAnimCurve = Curves.easeInOut;

  bool _isLoading = true;
  bool _isSaving = false;
  ProfileCardType _previewCard = ProfileCardType.casual;
  bool _showFront = true;

  // Onboarding UI state variables
  int _onboardingStep = 0;
  final PageController _onboardingPageController = PageController();
  final ScrollController _onboardingScrollController = ScrollController();
  String _selectedVibe = '';
  final Set<String> _selectedInterests = {};

  late TextEditingController _nameController;
  final TextEditingController _customVibeController = TextEditingController();
  final TextEditingController _customInterestController =
      TextEditingController();

  final TextEditingController _onboardingEmailController =
      TextEditingController();
  final TextEditingController _onboardingPhoneController =
      TextEditingController();
  final TextEditingController _onboardingProfEmailController =
      TextEditingController();
  final TextEditingController _onboardingProfPhoneController =
      TextEditingController();
  bool _useSameContactForProfessional = true;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ProfileProvider>(context, listen: false);

    // If profile is already loaded in memory, start without a loading spinner
    _isLoading = !provider.hasData;

    _nameController = TextEditingController(text: provider.name);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      if (widget.isEditingMode) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EditProfilePage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _onboardingPageController.dispose();
    _onboardingScrollController.dispose();
    _customVibeController.dispose();
    _customInterestController.dispose();
    _onboardingEmailController.dispose();
    _onboardingPhoneController.dispose();
    _onboardingProfEmailController.dispose();
    _onboardingProfPhoneController.dispose();
    super.dispose();
  }

  // Onboarding Wizard Methods

  void _nextStep() {
    if (_onboardingStep < 3) {
      setState(() {
        _onboardingStep++;
      });
      _onboardingPageController.animateToPage(
        _onboardingStep,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prevStep() {
    if (_onboardingStep > 0) {
      setState(() {
        _onboardingStep--;
      });
      _onboardingPageController.animateToPage(
        _onboardingStep,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finishQuickIdentity(
      {required bool openProfessionalEditor}) async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);
    try {
      final provider = Provider.of<ProfileProvider>(context, listen: false);
      provider.name = _nameController.text.trim();
      provider.vibeTag = _selectedVibe;
      provider.interestTags = _selectedInterests.toList();

      // Save onboarding contact details
      provider.email = _onboardingEmailController.text.trim();
      provider.phoneNumber = _onboardingPhoneController.text.trim();
      if (_useSameContactForProfessional) {
        provider.professionalEmail = _onboardingEmailController.text.trim();
        provider.professionalPhoneNumber =
            _onboardingPhoneController.text.trim();
      } else {
        provider.professionalEmail = _onboardingProfEmailController.text.trim();
        provider.professionalPhoneNumber =
            _onboardingProfPhoneController.text.trim();
      }

      provider.quickSetupComplete = true;

      await provider.saveOrUpdateProfile();

      AnalyticsService.logEvent('quick_identity_complete');

      if (!mounted) return;

      if (openProfessionalEditor) {
        AnalyticsService.logEvent('full_profile_started');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const YetToBeBuiltProfilePage(isEditingMode: true),
          ),
        );
      } else {
        // Just let the profile page viewer rebuild in place.
      }
    } catch (e) {
      debugPrint("Error finishing onboarding: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Error completing onboarding: $e"),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildQuickIdentityWizard() {
    return Scaffold(
      backgroundColor: context.surfacePrimary,
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _onboardingPageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStepNameVibe(),
                _buildStepContactDetails(),
                _buildStepInterests(),
                _buildStepDone(),
              ],
            ),
            if (_isSaving)
              Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              context.accentSecondary)),
                      const SizedBox(height: 16),
                      Text(
                        "Setting up your vibe...",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
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

  Widget _buildStepNameVibe() {
    final List<String> defaultVibes = [
      "Night owl",
      "Early bird",
      "Music head",
      "Bookworm",
      "Gamer"
    ];
    final List<String> vibes = [...defaultVibes, "Others"];

    final bool isCustomVibe =
        _selectedVibe.isNotEmpty && !defaultVibes.contains(_selectedVibe);
    final String activeChipSelection = isCustomVibe ? "Others" : _selectedVibe;

    return SingleChildScrollView(
      controller: _onboardingScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              SizedBox(width: 40),
              Expanded(
                child: Text(
                  "IDENTITY",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 11,
                  ),
                ),
              ),
              SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "What should they call you?",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 36),
          TextField(
            controller: _nameController,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
            decoration: InputDecoration(
              hintText: "Your name",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24, width: 2),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: context.accentSecondary, width: 2),
              ),
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          const Text(
            "CHOOSE A VIBE",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: vibes.map((vibe) {
              final isSelected = activeChipSelection == vibe;
              return ChoiceChip(
                label: Text(
                  vibe,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: isSelected,
                selectedColor: context.accentSecondary,
                backgroundColor: context.surfaceSecondary,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color: isSelected
                          ? context.accentSecondary
                          : Colors.white10),
                ),
                onSelected: (selected) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (vibe == 'Others') {
                      _selectedVibe = selected ? 'Others' : '';
                      if (!selected) {
                        _customVibeController.clear();
                      } else {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_onboardingScrollController.hasClients) {
                            _onboardingScrollController.animateTo(
                              _onboardingScrollController
                                  .position.maxScrollExtent,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      }
                    } else {
                      _selectedVibe = selected ? vibe : '';
                      _customVibeController.clear();
                    }
                  });
                },
              );
            }).toList(),
          ),
          if (activeChipSelection == 'Others') ...[
            const SizedBox(height: 24),
            TextField(
              controller: _customVibeController,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
              decoration: InputDecoration(
                hintText: "Enter your custom vibe",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24, width: 1.5),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: context.accentSecondary, width: 1.5),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: (_nameController.text.trim().isNotEmpty &&
                    _selectedVibe.isNotEmpty &&
                    (_selectedVibe != 'Others' ||
                        _customVibeController.text.trim().isNotEmpty))
                ? () {
                    HapticFeedback.lightImpact();
                    final finalVibe = _selectedVibe == 'Others'
                        ? _customVibeController.text.trim()
                        : _selectedVibe;
                    _selectedVibe = finalVibe;
                    AnalyticsService.logEvent(
                        'quick_identity_name_vibe', {'vibe': finalVibe});
                    _nextStep();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentSecondary,
              disabledBackgroundColor: Colors.white10,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "Continue",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContactDetails() {
    return SingleChildScrollView(
      controller: _onboardingScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
          left: 24.0, right: 24.0, top: 24.0, bottom: 80.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white54, size: 20),
                onPressed: _prevStep,
              ),
              const Expanded(
                child: Text(
                  "CONTACT INFO",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "How should people reach you?",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Fill in your email and phone number.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 20),

          // Email Input
          TextField(
            controller: _onboardingEmailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontFamily: 'Inter'),
            decoration: InputDecoration(
              labelText: "Casual Email",
              labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              hintText: "email@example.com",
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.15), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24, width: 1.0),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: context.accentSecondary, width: 1.5),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Phone Input
          TextField(
            controller: _onboardingPhoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontFamily: 'Inter'),
            decoration: InputDecoration(
              labelText: "Casual Phone",
              labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              hintText: "+1 (555) 123-4567",
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.15), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24, width: 1.0),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: context.accentSecondary, width: 1.5),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Same as Professional Toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  "Use same details for Professional profile",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              Switch(
                value: _useSameContactForProfessional,
                onChanged: (val) {
                  setState(() {
                    _useSameContactForProfessional = val;
                  });
                },
                activeColor: context.accentSecondary,
                activeTrackColor: context.accentSecondary.withOpacity(0.3),
              ),
            ],
          ),

          if (!_useSameContactForProfessional) ...[
            const SizedBox(height: 14),
            // Pro Email Input
            TextField(
              controller: _onboardingProfEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontFamily: 'Inter'),
              decoration: InputDecoration(
                labelText: "Professional Email",
                labelStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                hintText: "work@company.com",
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.15), fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24, width: 1.0),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: context.accentSecondary, width: 1.5),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),

            // Pro Phone Input
            TextField(
              controller: _onboardingProfPhoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontFamily: 'Inter'),
              decoration: InputDecoration(
                labelText: "Professional Phone",
                labelStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                hintText: "+1 (555) 987-6543",
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.15), fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24, width: 1.0),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: context.accentSecondary, width: 1.5),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_onboardingEmailController.text.trim().isNotEmpty &&
                    _onboardingPhoneController.text.trim().isNotEmpty &&
                    (_useSameContactForProfessional ||
                        (_onboardingProfEmailController.text
                                .trim()
                                .isNotEmpty &&
                            _onboardingProfPhoneController.text
                                .trim()
                                .isNotEmpty)))
                ? () {
                    HapticFeedback.lightImpact();
                    _nextStep();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentSecondary,
              disabledBackgroundColor: Colors.white10,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "Continue",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepInterests() {
    final List<String> defaultInterests = [
      "Tech",
      "Art",
      "Travel",
      "Fitness",
      "Movies",
      "Coffee",
      "Music",
      "Food",
      "Sports",
      "Reading"
    ];

    // Combine default interests, any custom interests in _selectedInterests, and "Others"
    final List<String> displayInterests = [
      ...defaultInterests,
      ..._selectedInterests
          .where((i) => !defaultInterests.contains(i) && i != 'Others'),
      "Others"
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white54, size: 20),
                onPressed: _prevStep,
              ),
              const Expanded(
                child: Text(
                  "INTERESTS",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "Pick your interests.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Select 3 or more topics you love talking about.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: displayInterests.map((interest) {
              final isSelected = _selectedInterests.contains(interest);
              return FilterChip(
                label: Text(
                  interest,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: isSelected,
                selectedColor: context.accentSecondary,
                backgroundColor: context.surfaceSecondary,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color: isSelected
                          ? context.accentSecondary
                          : Colors.white10),
                ),
                onSelected: (selected) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (interest == 'Others') {
                      if (selected) {
                        _selectedInterests.add('Others');
                      } else {
                        _selectedInterests.remove('Others');
                        _customInterestController.clear();
                      }
                    } else {
                      if (selected) {
                        _selectedInterests.add(interest);
                      } else {
                        _selectedInterests.remove(interest);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
          if (_selectedInterests.contains('Others')) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customInterestController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Inter',
                    ),
                    decoration: InputDecoration(
                      hintText: "Add custom interest...",
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.3)),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: context.accentSecondary),
                      ),
                    ),
                    onSubmitted: (_) => _addCustomInterest(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline_rounded,
                      color: context.accentSecondary, size: 28),
                  onPressed: _addCustomInterest,
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            "${_selectedInterests.where((i) => i != 'Others').length} selected",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _selectedInterests.where((i) => i != 'Others').length >= 3
                  ? context.accentSecondary
                  : Colors.white38,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 60),
          ElevatedButton(
            onPressed: _selectedInterests.where((i) => i != 'Others').length >=
                    3
                ? () {
                    HapticFeedback.lightImpact();
                    // Remove "Others" placeholder chip from the final saved interests list
                    final finalInterests =
                        _selectedInterests.where((i) => i != 'Others').toList();
                    _selectedInterests.clear();
                    _selectedInterests.addAll(finalInterests);

                    AnalyticsService.logEvent('quick_identity_interests',
                        {'interests': finalInterests});
                    _nextStep();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentSecondary,
              disabledBackgroundColor: Colors.white10,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "All Done",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _addCustomInterest() {
    final text = _customInterestController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _selectedInterests.add(text);
        _customInterestController.clear();
      });
    }
  }

  Widget _buildStepDone() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.surfaceSecondary.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          context.accentSecondary,
                          context.accentSecondary.withValues(alpha: 0.8)
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.accentSecondary.withOpacity(0.15),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Builder(builder: (context) {
                      final provider =
                          Provider.of<ProfileProvider>(context, listen: false);
                      return (provider.avatarUrl.isNotEmpty &&
                              provider.avatarUrl.startsWith('http'))
                          ? ClipOval(
                              child: Image.network(provider.avatarUrl,
                                  fit: BoxFit.cover),
                            )
                          : Center(
                              child: Text(
                                _nameController.text.isNotEmpty
                                    ? _nameController.text
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : "?",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold),
                              ),
                            );
                    }),
                  )
                      .animate()
                      .scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 20),
                  Text(
                    _nameController.text,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter'),
                  ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.accentSecondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _selectedVibe,
                      style: TextStyle(
                          color: context.accentSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "You are ready to connect!",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: 'Inter',
            ),
          ).animate().fadeIn(delay: 450.ms),
          const SizedBox(height: 8),
          const Text(
            "Scan others to connect or show your card to share details instantly.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ).animate().fadeIn(delay: 500.ms),
          const Spacer(),
          ElevatedButton(
            onPressed: () =>
                _finishQuickIdentity(openProfessionalEditor: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentSecondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "Continue",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _finishQuickIdentity(openProfessionalEditor: true),
            child: const Text(
              "Add Professional Details",
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    final provider = Provider.of<ProfileProvider>(context, listen: false);

    // Fast path: provider already has data (loaded by AppShellGate).
    // Populate controllers from memory and skip the network call entirely.
    if (provider.hasData) {
      _populateControllers(provider);
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Slow path: genuine first load or cleared state.
    if (mounted && provider.userId == null) {
      setState(() => _isLoading = true);
    }

    try {
      final userid = await provider.fetchAndSetUserId2(true);
      if (userid != null) {
        await provider.loadProfile(userid);
      }
      if (mounted) _populateControllers(provider);
    } catch (e) {
      debugPrint("Error loading profile page data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _populateControllers(ProfileProvider provider) {
    _nameController.text = provider.name;
    _selectedVibe = provider.vibeTag;
    final List<String> defaultVibes = [
      "Night owl",
      "Early bird",
      "Music head",
      "Bookworm",
      "Gamer"
    ];
    if (_selectedVibe.isNotEmpty && !defaultVibes.contains(_selectedVibe)) {
      _customVibeController.text = _selectedVibe;
    }

    _onboardingEmailController.text = provider.email;
    _onboardingPhoneController.text = provider.phoneNumber;
    _onboardingProfEmailController.text = provider.professionalEmail;
    _onboardingProfPhoneController.text = provider.professionalPhoneNumber;

    // Default switch to true if professional details match casual or are empty
    _useSameContactForProfessional = provider.professionalEmail.isEmpty ||
        provider.professionalEmail == provider.email;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild card preview when Casual/Professional field toggles change.
    final provider = context.watch<ProfileProvider>();

    if (_isLoading) {
      return Skeletonizer(
        enabled: true,
        child: Scaffold(
          backgroundColor: context.canvasBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  left: AppDimensions.marginStandard,
                  right: AppDimensions.marginStandard,
                  top: 16.0,
                  bottom: 100.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 28),
                  _buildCardTypeTabs(),
                  const SizedBox(height: 20),
                  _buildCasualSocialProfile(),
                  const SizedBox(height: 32),
                  _buildProfileDetailsSection(),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!widget.isEditingMode && !provider.quickSetupComplete) {
      return _buildQuickIdentityWizard();
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: context.canvasBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
                left: AppDimensions.marginStandard,
                right: AppDimensions.marginStandard,
                top: 16.0,
                bottom: 100.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Capsule
                _buildHeader(context),
                const SizedBox(height: 28),

                _buildCardTypeTabs(),
                const SizedBox(height: 20),

                if (_previewCard == ProfileCardType.casual) ...[
                  _buildCasualSocialProfile(),
                  const SizedBox(height: 32),
                  _buildProfileDetailsSection(),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'YOUR CARD',
                        style: context.captionText.copyWith(
                          color: context.textSecondary,
                          fontSize: 14.0,
                          letterSpacing: 1.5,
                        ),
                      ),
                      _buildFrontBackToggle(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDigitalCard(),
                  const SizedBox(height: 32),
                  // Section: My Story (Professional Bio)
                  _buildSectionHeader(
                      'MY STORY', _showEditProfessionalBioSheet),
                  const SizedBox(height: 0),
                  Container(
                    padding: const EdgeInsets.fromLTRB(1, 8, 8, 8),
                    // decoration: BoxDecoration(
                    //   color: context.surfacePrimary,
                    //   borderRadius: BorderRadius.circular(16),
                    //   border: Border.all(
                    //       color: context.textMuted.withValues(alpha: 0.15)),
                    // ),
                    child: Text(
                      provider.professionalBio.trim().isEmpty
                          ? 'No professional bio added yet. Tap edit to write a summary for your professional network!'
                          : provider.professionalBio.trim(),
                      style: context.bodyText.copyWith(
                        color: provider.professionalBio.trim().isEmpty
                            ? context.textMuted
                            : context.textPrimary,
                        height: 1.4,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildProfileDetailsSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrontBackToggle() {
    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.textMuted.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFaceTab(
              'Front', _showFront, () => setState(() => _showFront = true)),
          _buildFaceTab(
              'Back', !_showFront, () => setState(() => _showFront = false)),
        ],
      ),
    );
  }

  Widget _buildFaceTab(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? context.accentSecondary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: context.captionText.copyWith(
            color: isActive ? Colors.white : context.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildCardTypeTabs() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.textMuted.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCardTab(
              label: 'Casual',
              icon: Icons.person_outline_rounded,
              isActive: _previewCard == ProfileCardType.casual,
              onTap: () =>
                  setState(() => _previewCard = ProfileCardType.casual),
            ),
          ),
          Expanded(
            child: _buildCardTab(
              label: 'Professional',
              icon: Icons.work_outline_rounded,
              isActive: _previewCard == ProfileCardType.professional,
              onTap: () =>
                  setState(() => _previewCard = ProfileCardType.professional),
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
              style: context.captionText.copyWith(
                color: isActive ? Colors.white : context.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _fieldVisible(String field) {
    final provider = Provider.of<ProfileProvider>(context);
    return provider.isFieldOnCard(field, _previewCard);
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(30.0),
        border: Border.all(
          color: context.textMuted.withValues(alpha: 0.2),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 30),
          // Center: Titles
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'My Profile',
                style: context.screenHeading.copyWith(
                  fontSize: 18.0,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Digital Card',
                style: context.captionText.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
          ),

          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),

          // Right: spacer to balance layout (editing is now per-section)
          // const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildCasualSocialProfile() {
    final provider = context.watch<ProfileProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Section: Identity (Photo, Name, Vibe)
        // _buildSectionHeader('IDENTITY', _showEditIdentitySheet),
        const SizedBox(height: 0),
        Container(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          // decoration: BoxDecoration(
          //   color: context.surfacePrimary,
          //   borderRadius: BorderRadius.circular(16),
          //   border: Border.all(color: context.textMuted.withValues(alpha: 0.15)),
          // ),
          child: Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: _showEditIdentitySheet,
                child: Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFEC4899), Color(0xFF00F2FE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: ClipOval(
                        child: (provider.avatarUrl.isNotEmpty &&
                                provider.avatarUrl.startsWith('http'))
                            ? Image.network(provider.avatarUrl,
                                fit: BoxFit.cover)
                            : Container(
                                color: const Color(0xFF1E1F32),
                                alignment: Alignment.center,
                                child: Text(
                                  _nameController.text.isNotEmpty
                                      ? _nameController.text
                                          .substring(0, 1)
                                          .toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0064E0),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF0F101A), width: 1.5),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Name and Vibe
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text.trim().isEmpty
                          ? 'Jordan Miller'
                          : _nameController.text.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Inter',
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              const Color(0xFF00F2FE).withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded,
                              color: Color(0xFF00F2FE), size: 10),
                          const SizedBox(width: 4),
                          Text(
                            _selectedVibe.isNotEmpty
                                ? _selectedVibe
                                : (provider.vibeTag.isNotEmpty
                                    ? provider.vibeTag
                                    : 'Early bird'),
                            style: const TextStyle(
                              color: Color(0xFF00F2FE),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section: My Story (Bio)
        _buildSectionHeader('MY STORY', _showEditBioSheet),
        const SizedBox(height: 0),
        Container(
          padding: const EdgeInsets.fromLTRB(1, 8, 8, 8),
          decoration: BoxDecoration(
              // color: context.surfacePrimary,
              // borderRadius: BorderRadius.circular(16),
              // border:
              //     Border.all(color: context.textMuted.withValues(alpha: 0.15)),
              ),
          child: Text(
            provider.bio.trim().isEmpty
                ? 'No bio added yet. Tap edit to tell others about yourself!'
                : provider.bio.trim(),
            style: context.bodyText.copyWith(
              color: provider.bio.trim().isEmpty
                  ? context.textMuted
                  : context.textPrimary,
              height: 1.4,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Section: Interests
        _buildSectionHeader('INTERESTS', _showEditInterestsSheet),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (provider.interestTags.isNotEmpty
                  ? provider.interestTags
                  : (_selectedInterests.isNotEmpty
                      ? _selectedInterests.toList()
                      : ['Tech', 'Design', 'Music']))
              .map((interest) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      // color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      interest,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 28),

        // Section: Social Profiles
        _buildSectionHeader('SOCIAL PROFILES', _showEditSocialSheet),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.8,
          children: [
            _buildCasualSocialCard(
                'linkedin', 'LinkedIn', 'assets/icons/linkedin.png'),
            _buildCasualSocialCard(
                'twitter', 'X (Twitter)', 'assets/icons/twitter.png'),
            _buildCasualSocialCard(
                'instagram', 'Instagram', 'assets/icons/instagram.png'),
            _buildCasualSocialCard(
                'spotify', 'Spotify', 'assets/icons/spotify.png'),
          ],
        ),
      ],
    );
  }

  Widget _buildCasualSocialCard(
      String platform, String name, String assetPath) {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    String handle = '';
    if (platform == 'linkedin')
      handle = provider.linkedin;
    else if (platform == 'twitter')
      handle = provider.twitter;
    else if (platform == 'instagram')
      handle = provider.instagram;
    else if (platform == 'spotify') handle = provider.spotify;
    final hasLink = handle.isNotEmpty;
    final isVisible = _fieldVisible(platform);

    return GestureDetector(
      onTap: hasLink
          ? () {
              HapticFeedback.lightImpact();
              _showSocialActionSheet(
                  context, platform, name, handle, assetPath);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        decoration: BoxDecoration(
            // color: context.surfacePrimary,
            // borderRadius: BorderRadius.circular(12),
            // border: Border.all(
            //   color: hasLink
            //       ? (isVisible
            //           ? const Color(0xFF00F2FE).withValues(alpha: 0.3)
            //           : context.textMuted.withValues(alpha: 0.2))
            //       : context.textMuted.withValues(alpha: 0.15),
            // ),
            ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: hasLink
                    ? (isVisible
                        ? const Color(0xFF00F2FE).withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.03))
                    : Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Opacity(
                  opacity: hasLink ? (isVisible ? 1.0 : 0.4) : 0.35,
                  child: Image.asset(
                    assetPath,
                    width: 16,
                    height: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: hasLink ? Colors.white : context.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasLink ? handle : 'Not connected',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasLink
                                ? (isVisible
                                    ? const Color(0xFF00F2FE)
                                    : context.textMuted.withValues(alpha: 0.7))
                                : context.textMuted.withValues(alpha: 0.7),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (hasLink && !isVisible) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.visibility_off_rounded,
                          color: context.textMuted.withValues(alpha: 0.5),
                          size: 11,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetailsSection() {
    final provider = Provider.of<ProfileProvider>(context);

    // Filter fields depending on Casual / Professional type
    final isCasual = _previewCard == ProfileCardType.casual;

    // View Mode: show details in a gorgeous, readable card
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('PROFILE DETAILS', _showEditDetailsSheet),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(0),
          // decoration: BoxDecoration(
          //   color: context.surfacePrimary,
          //   borderRadius: BorderRadius.circular(16),
          //   border:
          //       Border.all(color: context.textMuted.withValues(alpha: 0.15)),
          // ),
          child: Column(
            children: [
              // Work section (Only for Professional)
              if (!isCasual) ...[
                _buildDetailRow(
                  icon: Icons.work_rounded,
                  label: 'Profession',
                  value: provider.profession.trim().isEmpty
                      ? 'Not set'
                      : provider.profession.trim(),
                ),
                const Divider(color: Colors.transparent, height: 20),
                _buildDetailRow(
                  icon: Icons.business_rounded,
                  label: 'Company',
                  value: provider.company.trim().isEmpty
                      ? 'Not set'
                      : provider.company.trim(),
                ),
                const Divider(color: Colors.transparent, height: 20),
              ],

              // Email
              _buildDetailRow(
                icon: Icons.email_rounded,
                label: isCasual ? 'Casual Email' : 'Professional Email',
                value: isCasual
                    ? (provider.email.trim().isEmpty
                        ? 'Not set'
                        : provider.email.trim())
                    : (provider.professionalEmail.trim().isEmpty
                        ? 'Not set'
                        : provider.professionalEmail.trim()),
              ),
              const Divider(color: Colors.transparent, height: 20),

              // Phone
              _buildDetailRow(
                icon: Icons.phone_rounded,
                label: isCasual ? 'Casual Phone' : 'Professional Phone',
                value: isCasual
                    ? (provider.phoneNumber.trim().isEmpty
                        ? 'Not set'
                        : provider.phoneNumber.trim())
                    : (provider.professionalPhoneNumber.trim().isEmpty
                        ? 'Not set'
                        : provider.professionalPhoneNumber.trim()),
              ),
            ],
          ),
        ),

        // Social handles listed in view mode (Only for Professional card since Casual has a grid!)
        if (!isCasual) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('SOCIAL PROFILES', _showEditSocialSheet),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.8,
            children: [
              _buildCasualSocialCard(
                  'linkedin', 'LinkedIn', 'assets/icons/linkedin.png'),
              _buildCasualSocialCard(
                  'twitter', 'X (Twitter)', 'assets/icons/twitter.png'),
              _buildCasualSocialCard(
                  'instagram', 'Instagram', 'assets/icons/instagram.png'),
              _buildCasualSocialCard(
                  'spotify', 'Spotify', 'assets/icons/spotify.png'),
            ],
          ),
        ],

        // Custom links listed in view mode
        const SizedBox(height: 24),
        _buildSectionHeader('CUSTOM LINKS', _showEditCustomLinksSheet),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(0),
          // decoration: BoxDecoration(
          //   color: context.surfacePrimary,
          //   borderRadius: BorderRadius.circular(16),
          //   border:
          //       Border.all(color: context.textMuted.withValues(alpha: 0.15)),
          // ),
          child: provider.customLinks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No custom links added yet. Tap edit to add links!',
                      textAlign: TextAlign.center,
                      style: context.bodyText
                          .copyWith(color: context.textMuted, fontSize: 13),
                    ),
                  ),
                )
              : Column(
                  children: provider.customLinks.map((link) {
                    final isLast = provider.customLinks.last == link;
                    return Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0.0 : 12.0),
                      child: _buildDetailRow(
                        icon: Icons.link_rounded,
                        label: link.name,
                        value: link.url,
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: context.accentSecondary, size: 18),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDigitalCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = cardWidth / 1.58;

        return AnimatedContainer(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.radiusPremiumCard),
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
            borderRadius:
                BorderRadius.circular(context.radiusPremiumCard - 1.5),
            child: AnimatedContainer(
              duration: _cardAnimDuration,
              curve: _cardAnimCurve,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B1B3A), Color(0xFF0C0C18)],
                ),
                borderRadius:
                    BorderRadius.circular(context.radiusPremiumCard - 1.5),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CardPatternPainter(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.06),
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
        );
      },
    );
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

  Widget _buildCasualFrontCard(double W) {
    final H = W / 1.58;
    final provider = context.watch<ProfileProvider>();

    return Container(
      width: W,
      height: H,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.radiusPremiumCard),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E0F38), // Deep cyber purple
            const Color(0xFF0F1A30), // Deep blue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Glowing background circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEC4899).withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            left: -10,
            bottom: -10,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00F2FE).withValues(alpha: 0.15),
              ),
            ),
          ),

          // Main Row: Left Avatar, Right Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Glowing Avatar Container
              Container(
                width: H * 0.55,
                height: H * 0.55,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFF00F2FE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F2FE).withValues(alpha: 0.15),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                    )
                  ],
                ),
                child: ClipOval(
                  child: (provider.avatarUrl.isNotEmpty &&
                          provider.avatarUrl.startsWith('http'))
                      ? Image.network(provider.avatarUrl, fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFF121324),
                          alignment: Alignment.center,
                          child: Text(
                            provider.name.isNotEmpty
                                ? provider.name.substring(0, 1).toUpperCase()
                                : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // 2. Right details (Name, Vibe, Interests)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Name
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        provider.name.trim().isEmpty
                            ? 'Jordan Miller'
                            : provider.name.trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Vibe Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              const Color(0xFF00F2FE).withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded,
                              color: Color(0xFF00F2FE), size: 10),
                          const SizedBox(width: 4),
                          Text(
                            _selectedVibe.isNotEmpty
                                ? _selectedVibe
                                : (provider.vibeTag.isNotEmpty
                                    ? provider.vibeTag
                                    : 'Early bird'),
                            style: const TextStyle(
                              color: Color(0xFF00F2FE),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Interests Wrap
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: (provider.interestTags.isNotEmpty
                              ? provider.interestTags
                              : (_selectedInterests.isNotEmpty
                                  ? _selectedInterests.toList()
                                  : ['Tech', 'Design']))
                          .take(3)
                          .map((interest) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Text(
                                  interest,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 3. Scan Badge on bottom right
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const ConnectHubBottomSheet(),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Color(0xFF00F2FE),
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCasualBackCard(double W) {
    final H = W / 1.58;
    final provider = context.watch<ProfileProvider>();

    return Container(
      width: W,
      height: H,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.radiusPremiumCard),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E0F38),
            const Color(0xFF0F1A30),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Background glow
          Positioned(
            left: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00F2FE).withValues(alpha: 0.15),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header: Name and Vibe
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.name.trim().isEmpty
                            ? 'Jordan Miller'
                            : provider.name.trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedVibe.isNotEmpty
                            ? _selectedVibe
                            : (provider.vibeTag.isNotEmpty
                                ? provider.vibeTag
                                : 'Early bird'),
                        style: const TextStyle(
                          color: Color(0xFF00F2FE),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Image.asset(
                    'assets/icons/Mandala Icon 1.png',
                    width: 20,
                    height: 20,
                    color: const Color(0xFF00F2FE),
                  ),
                ],
              ),

              // Center: Social Handles Row
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCasualSocialIcon(
                        'linkedin', 'assets/icons/linkedin.png'),
                    const SizedBox(width: 12),
                    _buildCasualSocialIcon(
                        'twitter', 'assets/icons/twitter.png'),
                    const SizedBox(width: 12),
                    _buildCasualSocialIcon(
                        'instagram', 'assets/icons/instagram.png'),
                    const SizedBox(width: 12),
                    _buildCasualSocialIcon(
                        'spotify', 'assets/icons/spotify.png'),
                  ],
                ),
              ),

              // Footer: Interests Wrap
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: (provider.interestTags.isNotEmpty
                        ? provider.interestTags
                        : (_selectedInterests.isNotEmpty
                            ? _selectedInterests.toList()
                            : ['Tech', 'Design']))
                    .take(3)
                    .map((interest) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            interest,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCasualSocialIcon(String platform, String assetPath) {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    String handle = '';
    if (platform == 'linkedin')
      handle = provider.linkedin;
    else if (platform == 'twitter')
      handle = provider.twitter;
    else if (platform == 'instagram')
      handle = provider.instagram;
    else if (platform == 'spotify') handle = provider.spotify;
    final hasLink = handle.isNotEmpty;

    final displayName = platform[0].toUpperCase() + platform.substring(1);
    return GestureDetector(
      onTap: hasLink
          ? () {
              HapticFeedback.lightImpact();
              _showSocialActionSheet(
                  context, platform, displayName, handle, assetPath);
            }
          : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: hasLink
              ? const Color(0xFF00F2FE).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: hasLink
                ? const Color(0xFF00F2FE).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Center(
          child: Opacity(
            opacity: hasLink ? 1.0 : 0.25,
            child: Image.asset(
              assetPath,
              width: 16,
              height: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedFrontCard(double cardWidth) {
    if (_previewCard == ProfileCardType.casual) {
      return _buildCasualFrontCard(cardWidth);
    }
    final provider = context.watch<ProfileProvider>();
    final W = cardWidth;

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
                  color: context.surfaceSecondary,
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
                  provider.company.trim().isEmpty
                      ? 'CONNECT'
                      : provider.company.trim().toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'DIGITAL IDENTITY',
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

        // 2. Name and Profession
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: 20,
          right: W * 0.4,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_fieldVisible('name'))
                AnimatedAlign(
                  duration: _cardAnimDuration,
                  curve: _cardAnimCurve,
                  alignment: Alignment.centerLeft,
                  child: AnimatedDefaultTextStyle(
                    duration: _cardAnimDuration,
                    curve: _cardAnimCurve,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                    child: Text(
                      provider.name.trim().isEmpty
                          ? 'Jordan Miller'
                          : provider.name.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              AnimatedAlign(
                duration: _cardAnimDuration,
                curve: _cardAnimCurve,
                alignment: Alignment.centerLeft,
                child: AnimatedDefaultTextStyle(
                  duration: _cardAnimDuration,
                  curve: _cardAnimCurve,
                  style: TextStyle(
                    color: _previewCard == ProfileCardType.casual
                        ? context.accentPrimary
                        : context.accentSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                  child: Text(
                    _previewCard == ProfileCardType.casual
                        ? 'Casual Card'
                        : 'Professional Card',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Scan Badge
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          right: 20,
          bottom: 16,
          width: 95,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const ConnectHubBottomSheet(),
              );
            },
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
        ),
      ],
    );
  }

  Widget _buildUnifiedBackCard(double cardWidth) {
    if (_previewCard == ProfileCardType.casual) {
      return _buildCasualBackCard(cardWidth);
    }
    final provider = context.watch<ProfileProvider>();
    final isCasualData = _previewCard == ProfileCardType.casual;
    final W = cardWidth;

    return Stack(
      children: [
        // 1. Row 1: Avatar, Name, Profession, Link Button
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: 20,
          right: 20,
          top: 16,
          height: 40,
          child: Row(
            children: [
              if (_fieldVisible('avatarUrl'))
                AnimatedContainer(
                  duration: _cardAnimDuration,
                  curve: _cardAnimCurve,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00F2FE),
                        context.accentSecondary
                      ],
                    ),
                  ),
                  child: ClipOval(
                    child: (provider.avatarUrl.isNotEmpty &&
                            provider.avatarUrl.startsWith('http'))
                        ? Image.network(
                            provider.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: context.surfaceSecondary,
                              alignment: Alignment.center,
                              child: Text(
                                provider.name.isNotEmpty
                                    ? provider.name
                                        .substring(0, 1)
                                        .toUpperCase()
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
                            color: context.surfaceSecondary,
                            alignment: Alignment.center,
                            child: Text(
                              provider.name.isNotEmpty
                                  ? provider.name.substring(0, 1).toUpperCase()
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
              if (_fieldVisible('avatarUrl'))
                AnimatedContainer(
                  duration: _cardAnimDuration,
                  curve: _cardAnimCurve,
                  width: 10,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_fieldVisible('name'))
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedDefaultTextStyle(
                          duration: _cardAnimDuration,
                          curve: _cardAnimCurve,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                          child: Text(
                            provider.name.trim().isEmpty
                                ? 'Jordan Miller'
                                : provider.name.trim(),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    if (_fieldVisible('profession') ||
                        _previewCard == ProfileCardType.casual) ...[
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedDefaultTextStyle(
                          duration: _cardAnimDuration,
                          curve: _cardAnimCurve,
                          style: TextStyle(
                            color: context.accentSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                          child: Text(
                            _previewCard == ProfileCardType.casual
                                ? (_selectedVibe.isNotEmpty
                                    ? _selectedVibe
                                    : (provider.vibeTag.isNotEmpty
                                        ? provider.vibeTag
                                        : 'Casual Vibe'))
                                : (provider.profession.trim().isEmpty
                                    ? 'Product Designer'
                                    : provider.profession.trim()),
                            maxLines: 1,
                          ),
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
          left: 20,
          right: 20,
          top: 68,
          height: 1,
          child: Container(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),

        // 3. Contact Details Group (Company, Email, Phone)
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: (W * 0.5) + 10,
          right: 20,
          top: 80,
          height: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_fieldVisible('company')) ...[
                _buildUnifiedCardRow(
                  Icons.apartment_rounded,
                  provider.company.trim().isEmpty
                      ? 'Design Studio Inc.'
                      : provider.company.trim(),
                  false,
                ),
                const SizedBox(height: 5),
              ],
              if (isCasualData) ...[
                if (_fieldVisible('email')) ...[
                  _buildUnifiedCardRow(
                    Icons.email_outlined,
                    provider.email.trim().isEmpty
                        ? 'jordan@designstudio.com'
                        : provider.email.trim(),
                    false,
                  ),
                  const SizedBox(height: 5),
                ],
                if (_fieldVisible('phoneNumber'))
                  _buildUnifiedCardRow(
                    Icons.phone_rounded,
                    provider.phoneNumber.trim().isEmpty
                        ? '+1 (555) 123-4567'
                        : provider.phoneNumber.trim(),
                    false,
                  ),
              ] else ...[
                if (_fieldVisible('email')) ...[
                  _buildUnifiedCardRow(
                    Icons.email_outlined,
                    provider.professionalEmail.trim().isEmpty
                        ? 'jordan@designstudio.com'
                        : provider.professionalEmail.trim(),
                    false,
                  ),
                  const SizedBox(height: 5),
                ],
                if (_fieldVisible('phoneNumber'))
                  _buildUnifiedCardRow(
                    Icons.phone_rounded,
                    provider.professionalPhoneNumber.trim().isEmpty
                        ? '+1 (555) 123-4567'
                        : provider.professionalPhoneNumber.trim(),
                    false,
                  ),
              ],
            ],
          ),
        ),

        // 4. Bio Section
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: 20,
          right: (W * 0.5) + 10,
          top: 80,
          height: 60,
          child: isCasualData
              ? Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: (provider.interestTags.isNotEmpty
                          ? provider.interestTags
                          : (_selectedInterests.isNotEmpty
                              ? _selectedInterests.toList()
                              : ['Connect', 'Explore', 'Inspire']))
                      .map((interest) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  context.accentPrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: context.accentPrimary
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              interest,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600),
                            ),
                          ))
                      .toList(),
                )
              : (_fieldVisible('bio')
                  ? Text(
                      provider.professionalBio.trim().isEmpty
                          ? 'Senior Product Designer with 8+ years of experience crafting intuitive digital solutions.'
                          : provider.professionalBio.trim(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        height: 1.25,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    )
                  : const SizedBox.shrink()),
        ),

        // 5. Bottom Accent Line
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: 20,
          right: W - 80,
          top: 148,
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

  Widget _buildUnifiedCardRow(IconData icon, String text, bool isCasual) {
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
              color: Colors.white54,
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
                color: isCasual ? context.textSecondary : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
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

  String _getSocialUrl(String platform, String handle) {
    final cleaned = handle.trim();
    if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
      return cleaned;
    }
    switch (platform.toLowerCase()) {
      case 'linkedin':
        return 'https://linkedin.com/in/$cleaned';
      case 'twitter':
      case 'x':
        return 'https://x.com/$cleaned';
      case 'instagram':
        return 'https://instagram.com/$cleaned';
      case 'spotify':
        if (cleaned.contains('spotify.com')) return cleaned;
        return 'https://open.spotify.com/user/$cleaned';
      default:
        return cleaned;
    }
  }

  void _showSocialActionSheet(
    BuildContext context,
    String platform,
    String displayName,
    String handle,
    String assetPath,
  ) {
    final url = _getSocialUrl(platform, handle);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF151624),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F2FE).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Image.asset(
                        assetPath,
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@$handle',
                          style: const TextStyle(
                            color: Color(0xFF8FA39E),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        url,
                        style: const TextStyle(
                          color: Color(0xFF00F2FE),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Copied $displayName link to clipboard!'),
                              backgroundColor: const Color(0xFF1E1F32),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded,
                          color: Colors.white70, size: 18),
                      label: const Text(
                        "Copy Link",
                        style: TextStyle(
                            color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } else {
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Could not launch $url'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.open_in_new_rounded,
                            color: Colors.white, size: 18),
                        label: const Text(
                          "Open Account",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onEdit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: context.captionText.copyWith(
            color: context.textSecondary,
            fontSize: 12.0,
            letterSpacing: 1.5,
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onEdit();
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.accentSecondary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.edit_rounded,
              color: context.accentSecondary,
              size: 13,
            ),
          ),
        ),
      ],
    );
  }

  void _showEditBioSheet() {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    final controller = TextEditingController(text: provider.bio);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: context.surfacePrimary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Edit My Story',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 5,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Tell the world about yourself...',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF00F2FE), width: 1)),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSheetSaveButton(() async {
                  final uid = provider.userId;
                  if (uid != null) {
                    await provider.updateProfileField(
                        'bio', controller.text.trim(), uid);
                  }
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditProfessionalBioSheet() {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    final controller = TextEditingController(text: provider.professionalBio);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: context.surfacePrimary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Edit Professional Story',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 5,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText:
                        'Summarize your professional experience & goals...',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFEC4899), width: 1)),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSheetSaveButton(() async {
                  final uid = provider.userId;
                  if (uid != null) {
                    await provider.updateProfileField(
                        'professionalBio', controller.text.trim(), uid);
                  }
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                }, customColors: [
                  const Color(0xFFEC4899),
                  const Color(0xFFD946EF)
                ]),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditInterestsSheet() {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    final currentInterests = Set<String>.from(provider.interestTags.isNotEmpty
        ? provider.interestTags
        : _selectedInterests);
    final customController = TextEditingController();

    final List<String> defaultInterests = [
      "Tech",
      "Art",
      "Travel",
      "Fitness",
      "Movies",
      "Coffee",
      "Music",
      "Food",
      "Sports",
      "Reading"
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final displayInterests = [
              ...defaultInterests,
              ...currentInterests
                  .where((i) => !defaultInterests.contains(i) && i != 'Others'),
              'Others',
            ];

            return Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.7),
                decoration: BoxDecoration(
                  color: context.surfacePrimary,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                          child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 20),
                      const Text('Edit Interests',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: displayInterests.map((interest) {
                          final isSelected =
                              currentInterests.contains(interest);
                          return FilterChip(
                            label: Text(interest,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            selected: isSelected,
                            selectedColor: context.accentSecondary,
                            backgroundColor: context.surfaceSecondary,
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                    color: isSelected
                                        ? context.accentSecondary
                                        : Colors.white10)),
                            onSelected: (selected) {
                              HapticFeedback.lightImpact();
                              setSheetState(() {
                                if (interest == 'Others') {
                                  if (selected) {
                                    currentInterests.add('Others');
                                  } else {
                                    currentInterests.remove('Others');
                                    customController.clear();
                                  }
                                } else {
                                  if (selected) {
                                    currentInterests.add(interest);
                                  } else {
                                    currentInterests.remove(interest);
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      if (currentInterests.contains('Others')) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: customController,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Add custom interest...',
                                  hintStyle: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.3)),
                                  enabledBorder: const UnderlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.white24)),
                                  focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: context.accentSecondary)),
                                ),
                                onSubmitted: (_) {
                                  final t = customController.text.trim();
                                  if (t.isNotEmpty) {
                                    setSheetState(() {
                                      currentInterests.add(t);
                                      customController.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_circle_outline_rounded,
                                  color: context.accentSecondary, size: 26),
                              onPressed: () {
                                final t = customController.text.trim();
                                if (t.isNotEmpty) {
                                  setSheetState(() {
                                    currentInterests.add(t);
                                    customController.clear();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      _buildSheetSaveButton(() async {
                        final finalList = currentInterests
                            .where((i) => i != 'Others')
                            .toList();
                        provider.setVibeAndInterests(
                            provider.vibeTag, finalList);
                        final uid = provider.userId;
                        if (uid != null) {
                          await provider.updateProfileField(
                              'interest_tags', finalList.join(','), uid);
                        }
                        setState(() {
                          _selectedInterests.clear();
                          _selectedInterests.addAll(finalList);
                        });
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      }),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditSocialSheet() {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    final linkedinC = TextEditingController(text: provider.linkedin);
    final twitterC = TextEditingController(text: provider.twitter);
    final instagramC = TextEditingController(text: provider.instagram);
    final spotifyC = TextEditingController(text: provider.spotify);
    final isCasual = _previewCard == ProfileCardType.casual;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: context.surfacePrimary,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                          child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 20),
                      const Text('Edit Social Profiles & Visibility',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'Configure which social profiles show on your active ${isCasual ? "Casual" : "Work"} Card.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSocialEditRow(
                          platform: 'linkedin',
                          label: 'LinkedIn',
                          controller: linkedinC,
                          assetPath: 'assets/icons/linkedin.png',
                          provider: provider,
                          setModalState: setModalState),
                      _buildSocialEditRow(
                          platform: 'twitter',
                          label: 'X (Twitter)',
                          controller: twitterC,
                          assetPath: 'assets/icons/twitter.png',
                          provider: provider,
                          setModalState: setModalState),
                      _buildSocialEditRow(
                          platform: 'instagram',
                          label: 'Instagram',
                          controller: instagramC,
                          assetPath: 'assets/icons/instagram.png',
                          provider: provider,
                          setModalState: setModalState),
                      _buildSocialEditRow(
                          platform: 'spotify',
                          label: 'Spotify',
                          controller: spotifyC,
                          assetPath: 'assets/icons/spotify.png',
                          provider: provider,
                          setModalState: setModalState),
                      const SizedBox(height: 16),
                      _buildSheetSaveButton(() async {
                        final uid = provider.userId;
                        if (uid != null) {
                          await provider.updateProfileField(
                              'linkedin', linkedinC.text.trim(), uid);
                          await provider.updateProfileField(
                              'twitter', twitterC.text.trim(), uid);
                          await provider.updateProfileField(
                              'instagram', instagramC.text.trim(), uid);
                          await provider.updateProfileField(
                              'spotify', spotifyC.text.trim(), uid);
                        }
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      }),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditCustomLinksSheet() {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final links = provider.customLinks;

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: context.surfacePrimary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Edit Custom Links',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // List of existing links
                    if (links.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          "No custom links added yet. Use the fields below to add new ones.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: links.length,
                          itemBuilder: (context, index) {
                            final link = links[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.link_rounded,
                                      color: Color(0xFF00F2FE), size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          link.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          link.url,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.4),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 20),
                                    onPressed: () async {
                                      await provider.removeCustomLink(
                                          link.id, provider.userId);
                                      setSheetState(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    const Divider(color: Colors.white10, height: 24),
                    const Text('Add New Link',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),

                    // Name Field
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Link Name (e.g., Portfolio, Website)',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF00F2FE), width: 1)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // URL Field
                    TextField(
                      controller: urlController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'URL (e.g., https://mywebsite.com)',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF00F2FE), width: 1)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Add Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0064E0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final url = urlController.text.trim();
                        if (name.isNotEmpty && url.isNotEmpty) {
                          await provider.addCustomLink(
                              name, url, provider.userId);
                          nameController.clear();
                          urlController.clear();
                          setSheetState(() {});
                        }
                      },
                      child: const Text('Add Link',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),

                    const SizedBox(height: 24),

                    // Done/Close Button
                    _buildSheetSaveButton(() {
                      Navigator.pop(sheetCtx);
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickAndUploadImage({
    required StateSetter setModalState,
    required Function(String) onUploadSuccess,
    required Function(String) onUploadError,
  }) async {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    final picker = ImagePicker();
    try {
      final XFile? imageFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (imageFile == null) {
        onUploadError("canceled");
        return;
      }

      setModalState(() {});

      final bytes = await imageFile.readAsBytes();

      if (!mounted) return;

      final Uint8List? croppedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => CropImagePage(imageBytes: bytes),
        ),
      );

      if (croppedBytes == null) {
        onUploadError("canceled");
        return;
      }

      setModalState(() {});

      final compressedBytes =
          await ImageUploadService.compressImageTo10Kb(croppedBytes);

      final String publicUrl = await ImageUploadService.uploadAvatarImage(
        provider.userId,
        compressedBytes,
      );

      onUploadSuccess(publicUrl);
    } catch (e) {
      print("Error picking/uploading image: $e");
      onUploadError(e.toString());
    }
  }

  void _showPhotoPicker() {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        bool isUploading = false;
        String? uploadError;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final avatarUrl = provider.avatarUrl;
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24.0,
                  bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Profile Photo",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF00F2FE), Color(0xFF0064E0)],
                          ),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: ClipOval(
                          child: (avatarUrl.isNotEmpty &&
                                  avatarUrl.startsWith('http'))
                              ? Image.network(avatarUrl, fit: BoxFit.cover)
                              : Container(
                                  color: const Color(0xFF1E1F32),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _nameController.text.isNotEmpty
                                        ? _nameController.text
                                            .substring(0, 1)
                                            .toUpperCase()
                                        : "?",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isUploading) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF00F2FE)),
                          ),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.photo_library_rounded,
                            color: Colors.white, size: 18),
                        label: const Text(
                          "Upload from Gallery",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0064E0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          setModalState(() {
                            isUploading = true;
                            uploadError = null;
                          });
                          _pickAndUploadImage(
                            setModalState: setModalState,
                            onUploadSuccess: (publicUrl) async {
                              if (mounted) {
                                final uid = provider.userId;
                                if (uid != null) {
                                  await provider.updateProfileField(
                                      'avatarUrl', publicUrl, uid);
                                }
                              }
                              if (sheetCtx.mounted) Navigator.pop(sheetCtx);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    "Profile photo updated and saved!",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: const Color(0xFF0064E0),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                            onUploadError: (err) {
                              setModalState(() {
                                isUploading = false;
                                if (err == "canceled") {
                                  uploadError = null;
                                } else {
                                  uploadError = err;
                                }
                              });
                            },
                          );
                        },
                      ),
                    ],
                    if (uploadError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        uploadError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditIdentitySheet() {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    final nameC = TextEditingController(text: provider.name);

    final List<String> defaultVibes = [
      "Night owl",
      "Early bird",
      "Music head",
      "Bookworm",
      "Gamer"
    ];

    final currentVibe =
        provider.vibeTag.isNotEmpty ? provider.vibeTag : 'Early bird';
    final bool isCustomVibe = !defaultVibes.contains(currentVibe);

    String tempSelectedVibe = isCustomVibe ? 'Others' : currentVibe;
    final tempCustomVibeController =
        TextEditingController(text: isCustomVibe ? currentVibe : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final avatarUrl = provider.avatarUrl;
            final vibes = [...defaultVibes, "Others"];

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: context.surfacePrimary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Edit Profile Identity',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

                      // Avatar Edit Section
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            _showPhotoPicker();
                            Future.delayed(const Duration(seconds: 1), () {
                              if (sheetCtx.mounted) setSheetState(() {});
                            });
                          },
                          child: Stack(
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFEC4899),
                                      Color(0xFF00F2FE)
                                    ],
                                  ),
                                ),
                                child: ClipOval(
                                  child: (avatarUrl.isNotEmpty &&
                                          avatarUrl.startsWith('http'))
                                      ? Image.network(avatarUrl,
                                          fit: BoxFit.cover)
                                      : Container(
                                          color: const Color(0xFF1E1F32),
                                          alignment: Alignment.center,
                                          child: Text(
                                            nameC.text.isNotEmpty
                                                ? nameC.text
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                                : "?",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0064E0),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFF0F101A),
                                        width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Full Name Field
                      _buildSheetField(
                        label: 'Full Name',
                        controller: nameC,
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 20),

                      // Vibe Selection
                      const Text(
                        'Select Vibe',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: vibes.map((vibe) {
                          final isSelected = tempSelectedVibe == vibe;
                          return ChoiceChip(
                            label: Text(
                              vibe,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: context.accentSecondary,
                            backgroundColor: context.surfaceSecondary,
                            checkmarkColor: Colors.white,
                            showCheckmark: false,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: isSelected
                                      ? context.accentSecondary
                                      : Colors.white10),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() {
                                  tempSelectedVibe = vibe;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      if (tempSelectedVibe == 'Others') ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: tempCustomVibeController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: "Enter your custom vibe...",
                            hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.2)),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.white24, width: 1.5),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: Color(0xFF00F2FE), width: 1.5),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),

                      // Save Button
                      _buildSheetSaveButton(() async {
                        final newName = nameC.text.trim();
                        final finalVibe = tempSelectedVibe == 'Others'
                            ? tempCustomVibeController.text.trim()
                            : tempSelectedVibe;
                        final uid = provider.userId;

                        if (uid != null) {
                          if (newName.isNotEmpty) {
                            await provider.updateProfileField(
                                'name', newName, uid);
                            setState(() {
                              _nameController.text = newName;
                            });
                          }
                          if (finalVibe.isNotEmpty) {
                            await provider.updateProfileField(
                                'vibeTag', finalVibe, uid);
                            setState(() {
                              _selectedVibe = finalVibe;
                            });
                          }
                        }
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      }),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditDetailsSheet() {
    final provider = Provider.of<ProfileProvider>(context, listen: false);

    // Initial controllers with current provider values for both casual and professional
    final casualEmailC = TextEditingController(text: provider.email);
    final casualPhoneC = TextEditingController(text: provider.phoneNumber);

    final profEmailC = TextEditingController(text: provider.professionalEmail);
    final profPhoneC =
        TextEditingController(text: provider.professionalPhoneNumber);
    final professionC = TextEditingController(text: provider.profession);
    final companyC = TextEditingController(text: provider.company);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: context.surfacePrimary,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Edit Profile Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- SECTION 1: CASUAL DETAILS ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "CASUAL PROFILE",
                            style: TextStyle(
                              color: Color(0xFF00F2FE),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                          if (profEmailC.text.isNotEmpty ||
                              profPhoneC.text.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  if (casualEmailC.text.isEmpty) {
                                    casualEmailC.text = profEmailC.text;
                                  }
                                  if (casualPhoneC.text.isEmpty) {
                                    casualPhoneC.text = profPhoneC.text;
                                  }
                                });
                              },
                              icon: const Icon(Icons.copy_all_rounded,
                                  size: 12, color: Color(0xFF00F2FE)),
                              label: const Text(
                                "Copy Pro Details",
                                style: TextStyle(
                                    color: Color(0xFF00F2FE),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSheetField(
                        label: 'Casual Email',
                        controller: casualEmailC,
                        icon: Icons.email_outlined,
                        accentColor: const Color(0xFF00F2FE),
                      ),
                      const SizedBox(height: 14),
                      _buildSheetField(
                        label: 'Casual Phone',
                        controller: casualPhoneC,
                        icon: Icons.phone_android_outlined,
                        accentColor: const Color(0xFF00F2FE),
                      ),
                      const SizedBox(height: 24),

                      // --- SECTION 2: PROFESSIONAL DETAILS ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "PROFESSIONAL PROFILE",
                            style: TextStyle(
                              color: Color(0xFFEC4899),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                          if (casualEmailC.text.isNotEmpty ||
                              casualPhoneC.text.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  if (profEmailC.text.isEmpty) {
                                    profEmailC.text = casualEmailC.text;
                                  }
                                  if (profPhoneC.text.isEmpty) {
                                    profPhoneC.text = casualPhoneC.text;
                                  }
                                });
                              },
                              icon: const Icon(Icons.copy_all_rounded,
                                  size: 12, color: Color(0xFFEC4899)),
                              label: const Text(
                                "Copy Casual Details",
                                style: TextStyle(
                                    color: Color(0xFFEC4899),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSheetField(
                        label: 'Profession',
                        controller: professionC,
                        icon: Icons.work_outline_rounded,
                        accentColor: const Color(0xFFEC4899),
                      ),
                      const SizedBox(height: 14),
                      _buildSheetField(
                        label: 'Company',
                        controller: companyC,
                        icon: Icons.business_outlined,
                        accentColor: const Color(0xFFEC4899),
                      ),
                      const SizedBox(height: 14),
                      _buildSheetField(
                        label: 'Professional Email',
                        controller: profEmailC,
                        icon: Icons.email_outlined,
                        accentColor: const Color(0xFFEC4899),
                      ),
                      const SizedBox(height: 14),
                      _buildSheetField(
                        label: 'Professional Phone',
                        controller: profPhoneC,
                        icon: Icons.phone_android_outlined,
                        accentColor: const Color(0xFFEC4899),
                      ),
                      const SizedBox(height: 28),

                      _buildSheetSaveButton(() async {
                        final uid = provider.userId;
                        if (uid != null) {
                          // Save casual details
                          await provider.updateProfileField(
                              'email', casualEmailC.text.trim(), uid);
                          await provider.updateProfileField(
                              'phoneNumber', casualPhoneC.text.trim(), uid);

                          // Save professional details
                          await provider.updateProfileField(
                              'professionalEmail', profEmailC.text.trim(), uid);
                          await provider.updateProfileField(
                              'professionalPhoneNumber',
                              profPhoneC.text.trim(),
                              uid);
                          await provider.updateProfileField(
                              'profession', professionC.text.trim(), uid);
                          await provider.updateProfileField(
                              'company', companyC.text.trim(), uid);
                        }
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      }, customColors: [
                        const Color(0xFF00F2FE),
                        const Color(0xFFEC4899)
                      ]),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSocialEditRow({
    required String platform,
    required String label,
    required TextEditingController controller,
    required String assetPath,
    required ProfileProvider provider,
    required StateSetter setModalState,
  }) {
    final isCasual = _previewCard == ProfileCardType.casual;
    final assignment = provider.fieldAssignments[platform] ??
        FieldCardAssignment(casual: false, professional: true);
    final isVisible = isCasual ? assignment.casual : assignment.professional;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset(
                assetPath,
                width: 18,
                height: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Visibility Toggle Button
              GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await provider.toggleFieldOnCard(platform, _previewCard);
                  setModalState(() {});
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isVisible
                        ? const Color(0xFF00F2FE).withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isVisible
                          ? const Color(0xFF00F2FE).withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVisible
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: isVisible
                            ? const Color(0xFF00F2FE)
                            : Colors.white38,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVisible ? 'Visible' : 'Hidden',
                        style: TextStyle(
                          color: isVisible
                              ? const Color(0xFF00F2FE)
                              : Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Enter $label handle or link...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 12.5,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFF00F2FE), width: 1),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    String? assetPath,
    Color accentColor = const Color(0xFF00F2FE),
  }) {
    Widget? prefix;
    if (assetPath != null) {
      prefix = Padding(
        padding: const EdgeInsets.all(12.0),
        child: Image.asset(
          assetPath,
          width: 18,
          height: 18,
        ),
      );
    } else if (icon != null) {
      prefix = Icon(icon, color: accentColor, size: 18);
    }

    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
        prefixIcon: prefix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentColor, width: 1)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSheetSaveButton(FutureOr<void> Function() onSave,
      {List<Color>? customColors}) {
    return _SheetSaveButton(onSave: onSave, customColors: customColors);
  }
}

class _SheetSaveButton extends StatefulWidget {
  final FutureOr<void> Function() onSave;
  final List<Color>? customColors;
  const _SheetSaveButton({required this.onSave, this.customColors});

  @override
  State<_SheetSaveButton> createState() => _SheetSaveButtonState();
}

class _SheetSaveButtonState extends State<_SheetSaveButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final buttonColor = context.accentSecondary;
    final effectiveColor =
        _isLoading ? buttonColor.withValues(alpha: 0.5) : buttonColor;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : () async {
                final messenger = ScaffoldMessenger.of(context);
                setState(() {
                  _isLoading = true;
                });
                try {
                  await widget.onSave();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: context.accentSecondary, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Changes saved successfully!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF1E1F32),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Failed to save changes: $e',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF1E1F32),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                } finally {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
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

    // Draw concentric circles in the top right corner
    final centerTR = Offset(size.width, 0);
    for (double r = 40.0; r <= 220.0; r += 16.0) {
      canvas.drawCircle(centerTR, r, paint);
    }

    // Draw concentric circles in the bottom left corner
    final centerBL = Offset(0, size.height);
    for (double r = 40.0; r <= 220.0; r += 16.0) {
      canvas.drawCircle(centerBL, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CardPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
