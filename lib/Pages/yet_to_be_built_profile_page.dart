import 'dart:async';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Pages/SettingsPage.dart';
import 'package:connect/Pages/edit_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Widgets/connect_hub_bottom_sheet.dart';
import 'package:connect/Utils/social_launcher.dart';
import 'package:connect/services/analytics_service.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connect/services/image_upload_service.dart';
import 'package:connect/Pages/crop_image_page.dart';
import 'package:connect/Models/resume_models.dart';
import 'package:connect/Widgets/resume_sections_widget.dart';
import 'package:connect/Widgets/resume_edit_sheets.dart';
import 'package:connect/Widgets/vouches_list_widget.dart';

class YetToBeBuiltProfilePage extends StatefulWidget {
  final bool isEditingMode;
  const YetToBeBuiltProfilePage({super.key, this.isEditingMode = false});

  @override
  State<YetToBeBuiltProfilePage> createState() =>
      _YetToBeBuiltProfilePageState();
}

class _YetToBeBuiltProfilePageState extends State<YetToBeBuiltProfilePage> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Onboarding UI state variables
  int _onboardingStep = 0;
  final PageController _onboardingPageController = PageController();
  final ScrollController _onboardingScrollController = ScrollController();
  final Set<String> _selectedInterests = {};

  late TextEditingController _nameController;
  final TextEditingController _customInterestController =
      TextEditingController();

  final TextEditingController _onboardingEmailController =
      TextEditingController();
  final TextEditingController _onboardingPhoneController =
      TextEditingController();
  final TextEditingController _onboardingProfessionController =
      TextEditingController();
  final TextEditingController _onboardingBioController =
      TextEditingController();

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
    _customInterestController.dispose();
    _onboardingEmailController.dispose();
    _onboardingPhoneController.dispose();
    _onboardingProfessionController.dispose();
    _onboardingBioController.dispose();
    super.dispose();
  }

  // Onboarding Wizard Methods

  void _nextStep() {
    if (_onboardingStep < 4) {
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

  Future<void> _finishQuickIdentity() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);
    try {
      final provider = Provider.of<ProfileProvider>(context, listen: false);
      provider.name = _nameController.text.trim();
      provider.interestTags = _selectedInterests.toList();

      final profession = _onboardingProfessionController.text.trim();
      final bio = _onboardingBioController.text.trim();

      provider.profession = profession;
      provider.company = provider.currentCompany;
      provider.bio = bio;
      provider.professionalBio = bio;

      final email = _onboardingEmailController.text.trim();
      final phone = _onboardingPhoneController.text.trim();
      provider.email = email;
      provider.phoneNumber = phone;
      provider.professionalEmail = email;
      provider.professionalPhoneNumber = phone;

      provider.quickSetupComplete = true;

      await provider.saveOrUpdateProfile();

      AnalyticsService.logEvent(name: 'quick_identity_complete');
    } catch (e) {
      debugPrint("Error finishing onboarding: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Could not complete profile setup. Please try again."),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildAvatarPlaceholder() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      return Container(
        color: context.surfaceSecondary,
        alignment: Alignment.center,
        child: Text(
          name.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
      );
    }
    return Container(
      color: context.surfaceSecondary,
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 40,
        color: Colors.white54,
      ),
    );
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
                _buildStepIdentity(),
                _buildStepRoleAbout(),
                _buildStepContactDetails(),
                _buildStepInterests(),
                _buildStepDone(),
              ],
            ),
            if (_isSaving)
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              context.accentSecondary)),
                      const SizedBox(height: 16),
                      Text(
                        "Setting up your profile...",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
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

  Widget _buildStepIdentity() {
    final provider = Provider.of<ProfileProvider>(context);

    return SingleChildScrollView(
      controller: _onboardingScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
          left: 24.0, right: 24.0, top: 24.0, bottom: 120.0),
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
          // Photo Picker
          Center(
            child: GestureDetector(
              onTap: () {
                _showPhotoPicker();
              },
              child: Stack(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(3.0),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFEC4899),
                          Color(0xFF00F2FE),
                        ],
                      ),
                    ),
                    child: ClipOval(
                      child: (provider.avatarUrl.isNotEmpty &&
                              provider.avatarUrl.startsWith('http'))
                          ? Image.network(
                              provider.avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildAvatarPlaceholder(),
                            )
                          : _buildAvatarPlaceholder(),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.surfaceSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.surfacePrimary,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              "Add photo (optional)",
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "What should they call you?",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter your full name to display on your profile.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
            decoration: InputDecoration(
              hintText: "Your full name",
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
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
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _nameController.text.trim().isNotEmpty
                ? () {
                    HapticFeedback.lightImpact();
                    AnalyticsService.logEvent(name: 'quick_identity_name');
                    _nextStep();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentPrimary,
              disabledBackgroundColor: Colors.white10,
              foregroundColor: Colors.black,
              disabledForegroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "Continue",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRoleAbout() {
    return SingleChildScrollView(
      controller: _onboardingScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
          left: 24.0, right: 24.0, top: 24.0, bottom: 120.0),
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
                  "ROLE & ABOUT",
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
          const SizedBox(height: 16),
          const Text(
            "What do you do?",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Add your role and a short intro.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 28),

          // Profession / Role
          TextField(
            controller: _onboardingProfessionController,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontFamily: 'Inter'),
            decoration: InputDecoration(
              labelText: "Profession / Role",
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              hintText: "e.g. Software Engineer, Designer, Founder",
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
          const SizedBox(height: 20),

          // Bio / My Story
          TextField(
            controller: _onboardingBioController,
            maxLines: 3,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontFamily: 'Inter'),
            decoration: InputDecoration(
              labelText: "Bio / About You",
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              hintText: "Tell people a little bit about yourself...",
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
          const SizedBox(height: 36),

          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _nextStep();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentPrimary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "Continue",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _nextStep();
            },
            child: const Text(
              "Skip for now",
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

  Widget _buildStepContactDetails() {
    return SingleChildScrollView(
      controller: _onboardingScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
          left: 24.0, right: 24.0, top: 24.0, bottom: 120.0),
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
              labelText: "Email",
              labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              hintText: "email@example.com",
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.15), fontSize: 14),
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
              labelText: "Phone",
              labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              hintText: "+1 (555) 123-4567",
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.15), fontSize: 14),
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_onboardingEmailController.text.trim().isNotEmpty ||
                    _onboardingPhoneController.text.trim().isNotEmpty)
                ? () {
                    HapticFeedback.lightImpact();
                    _nextStep();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentPrimary,
              disabledBackgroundColor: Colors.white10,
              foregroundColor: Colors.black,
              disabledForegroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "Continue",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
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
      padding: const EdgeInsets.only(
          left: 24.0, right: 24.0, top: 24.0, bottom: 120.0),
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
                          TextStyle(color: Colors.white.withValues(alpha: 0.3)),
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
            onPressed: _selectedInterests.where((i) => i != 'Others').length >= 3
                ? () {
                    HapticFeedback.lightImpact();
                    final finalInterests =
                        _selectedInterests.where((i) => i != 'Others').toList();
                    _selectedInterests.clear();
                    _selectedInterests.addAll(finalInterests);

                    AnalyticsService.logEvent(
                        name: 'quick_identity_interests',
                        parameters: {'interests': finalInterests});
                    _nextStep();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentPrimary,
              disabledBackgroundColor: Colors.white10,
              foregroundColor: Colors.black,
              disabledForegroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "All Done",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDone() {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    final profession = _onboardingProfessionController.text.trim();
    final company = provider.currentCompany.trim();
    String headline = '';
    if (profession.isNotEmpty && company.isNotEmpty) {
      headline = '$profession • $company';
    } else if (profession.isNotEmpty) {
      headline = profession;
    } else if (company.isNotEmpty) {
      headline = company;
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 16.0,
        bottom: 120.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.surfaceSecondary.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(24),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                                  color: context.accentSecondary
                                      .withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Builder(builder: (context) {
                              final provider =
                                  Provider.of<ProfileProvider>(context,
                                      listen: false);
                              return (provider.avatarUrl.isNotEmpty &&
                                      provider.avatarUrl.startsWith('http'))
                                  ? ClipOval(
                                      child: Image.network(
                                        provider.avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                _buildAvatarPlaceholder(),
                                      ),
                                    )
                                  : _buildAvatarPlaceholder();
                            }),
                          )
                              .animate()
                              .scale(duration: 400.ms, curve: Curves.easeOutBack),
                          const SizedBox(height: 16),
                          Text(
                            _nameController.text,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter'),
                          ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
                          if (headline.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              headline,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                              ),
                            ).animate().fadeIn(delay: 250.ms, duration: 300.ms),
                          ],
                          if (_selectedInterests.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: _selectedInterests
                                  .where((i) => i != 'Others')
                                  .take(4)
                                  .map((i) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.06),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          i,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
                          ],
                        ],
                      ),
                    ),
                  ),
          const SizedBox(height: 20),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                "Your profile is ready. Share your profile or QR code to connect and exchange contacts instantly.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _finishQuickIdentity,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentPrimary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "Get Started",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
          ).animate().fadeIn(delay: 550.ms),
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
    _onboardingEmailController.text =
        provider.email.isNotEmpty ? provider.email : provider.professionalEmail;
    _onboardingPhoneController.text = provider.phoneNumber.isNotEmpty
        ? provider.phoneNumber
        : provider.professionalPhoneNumber;
    _onboardingProfessionController.text = provider.profession;
    _onboardingBioController.text =
        provider.bio.isNotEmpty ? provider.bio : provider.professionalBio;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when profile state changes.
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
                  const SizedBox(height: 24),
                  _buildIdentityHeader(context),
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


                  _buildIdentityHeader(context),
                  const SizedBox(height: 28),

                  // Section: My Story
                  _buildSectionHeader('MY STORY', _showEditBioSheet),
                  const SizedBox(height: 0),
                  Container(
                    padding: const EdgeInsets.fromLTRB(1, 8, 8, 8),
                    child: Text(
                      (provider.bio.trim().isNotEmpty
                              ? provider.bio.trim()
                              : provider.professionalBio.trim())
                          .isEmpty
                          ? 'No bio added yet. Tap edit to tell the world about yourself!'
                          : (provider.bio.trim().isNotEmpty
                              ? provider.bio.trim()
                              : provider.professionalBio.trim()),
                      style: context.bodyText.copyWith(
                        color: (provider.bio.trim().isNotEmpty
                                ? provider.bio.trim()
                                : provider.professionalBio.trim())
                            .isEmpty
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
                  const SizedBox(height: 10),
                  provider.interestTags.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(1, 4, 8, 8),
                          child: Text(
                            'No interests added yet. Tap edit to add your interests!',
                            style: context.bodyText.copyWith(
                              color: context.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: provider.interestTags.map((interest) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: context.surfaceSecondary,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: context.textMuted.withValues(alpha: 0.2),
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
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 28),

                  // Experience Timeline Section (LinkedIn style)
                  ExperienceTimelineSection(
                    experience: provider.experience,
                    isOwner: true,
                    onAdd: () => _showAddExperienceSheet(context),
                    onEdit: (item) => _showEditExperienceSheet(context, item),
                  ),
                  const SizedBox(height: 28),

                  // Education Section
                  EducationSection(
                    education: provider.education,
                    isOwner: true,
                    onAdd: () => _showAddEducationSheet(context),
                    onEdit: (item) => _showEditEducationSheet(context, item),
                  ),
                  const SizedBox(height: 28),

                  // Skills & Superpowers Section
                  SkillsSection(
                    skills: provider.skills,
                    isOwner: true,
                    onEdit: () => _showEditSkillsSheet(context),
                  ),
                  const SizedBox(height: 32),
                  _buildProfileDetailsSection(),
                if (provider.userId != null) ...[
                  const SizedBox(height: 28),
                  VouchesListWidget(
                    userId: provider.userId!,
                    userName: provider.name,
                    isOwnProfile: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityHeader(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final nameText =
        provider.name.trim().isEmpty ? 'Your Name' : provider.name.trim();
    final String professionText = provider.profession.trim();
    final String companyText = provider.currentCompany.trim();

    String subtitle = '';
    if (professionText.isNotEmpty && companyText.isNotEmpty) {
      subtitle = '$professionText • $companyText';
    } else if (professionText.isNotEmpty) {
      subtitle = professionText;
    } else if (companyText.isNotEmpty) {
      subtitle = companyText;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar with gradient ring & edit indicator
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showEditIdentitySheet();
                },
                child: Stack(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFEC4899),
                            Color(0xFF00F2FE),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: ClipOval(
                        child: (provider.avatarUrl.isNotEmpty &&
                                provider.avatarUrl.startsWith('http'))
                            ? Image.network(
                                provider.avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: context.surfaceSecondary,
                                  alignment: Alignment.center,
                                  child: Text(
                                    provider.name.isNotEmpty
                                        ? provider.name
                                            .substring(0, 1)
                                            .toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: context.surfaceSecondary,
                                alignment: Alignment.center,
                                child: Text(
                                  provider.name.isNotEmpty
                                      ? provider.name
                                          .substring(0, 1)
                                          .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.surfaceSecondary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.surfacePrimary,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Name, subtitle, vibe
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Inter',
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Action Buttons: Edit Profile and Share QR
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showEditIdentitySheet();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: context.surfaceSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.textMuted.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 15,
                          color: context.accentSecondary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Edit Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const ConnectHubBottomSheet(
                        initialShareType: 'both',
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: context.surfaceSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.textMuted.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_2_rounded,
                          size: 15,
                          color: Color(0xFF00F2FE),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Share QR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showEditIdentitySheet();
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
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
                'Profile',
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

  Widget _buildProfileDetailsSection() {
    final provider = Provider.of<ProfileProvider>(context);

    final displayEmail = provider.email.trim().isNotEmpty
        ? provider.email.trim()
        : provider.professionalEmail.trim();
    final isEmailPrivate = provider.isFieldPrivate('email') ||
        provider.isFieldPrivate('professionalEmail');

    final displayPhone = provider.phoneNumber.trim().isNotEmpty
        ? provider.phoneNumber.trim()
        : provider.professionalPhoneNumber.trim();
    final isPhonePrivate = provider.isFieldPrivate('phoneNumber') ||
        provider.isFieldPrivate('professionalPhoneNumber');

    // View Mode: show details in a gorgeous, readable card
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('PROFILE DETAILS', () => _showEditDetailsSheet()),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              _buildDetailRow(
                icon: Icons.work_rounded,
                label: 'Profession',
                value: provider.profession.trim().isEmpty
                    ? 'Not set'
                    : provider.profession.trim(),
              ),
              const Divider(color: Colors.transparent, height: 20),

              // Email
              _buildDetailRow(
                icon: isEmailPrivate
                    ? Icons.lock_outline_rounded
                    : Icons.email_rounded,
                label: isEmailPrivate ? 'Email (Private)' : 'Email',
                value: displayEmail.isEmpty ? 'Not set' : displayEmail,
                isPrivate: isEmailPrivate,
                onTogglePrivacy: () async {
                  final newPrivate = !isEmailPrivate;
                  await provider.setFieldPrivate('email', newPrivate);
                  await provider.setFieldPrivate('professionalEmail', newPrivate);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              newPrivate
                                  ? Icons.lock_outline_rounded
                                  : Icons.lock_open_rounded,
                              color: context.accentSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              newPrivate
                                  ? 'Email is now private'
                                  : 'Email is now public',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF1C1D22),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                onCopy: () {
                  if (displayEmail.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: displayEmail));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: context.accentSecondary, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Email copied to clipboard',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF1C1D22),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
              ),
              const Divider(color: Colors.transparent, height: 20),

              // Phone
              _buildDetailRow(
                icon: isPhonePrivate
                    ? Icons.lock_outline_rounded
                    : Icons.phone_rounded,
                label: isPhonePrivate ? 'Phone (Private)' : 'Phone',
                value: displayPhone.isEmpty ? 'Not set' : displayPhone,
                isPrivate: isPhonePrivate,
                onTogglePrivacy: () async {
                  final newPrivate = !isPhonePrivate;
                  await provider.setFieldPrivate('phoneNumber', newPrivate);
                  await provider.setFieldPrivate('professionalPhoneNumber', newPrivate);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              newPrivate
                                  ? Icons.lock_outline_rounded
                                  : Icons.lock_open_rounded,
                              color: context.accentSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              newPrivate
                                  ? 'Phone number is now private'
                                  : 'Phone number is now public',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF1C1D22),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                onCopy: () {
                  if (displayPhone.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: displayPhone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: context.accentSecondary, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Phone number copied to clipboard',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF1C1D22),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),

        // Social profiles section
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
            _buildSocialCard(
                'linkedin', 'LinkedIn', 'assets/icons/linkedin.png'),
            _buildSocialCard(
                'twitter', 'X (Twitter)', 'assets/icons/twitter.png'),
            _buildSocialCard(
                'instagram', 'Instagram', 'assets/icons/instagram.png'),
            _buildSocialCard(
                'spotify', 'Spotify', 'assets/icons/spotify.png'),
          ],
        ),

        // Custom links section
        const SizedBox(height: 24),
        _buildSectionHeader('CUSTOM LINKS', _showEditCustomLinksSheet),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(0),
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
                        label: link.name.isNotEmpty ? link.name : 'Link',
                        value: link.url,
                        onCopy: () {
                          final url = link.url;
                          if (url.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Link copied to clipboard'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildSocialCard(String platform, String name, String assetPath) {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    String handle = '';
    if (platform == 'linkedin') {
      handle = provider.linkedin;
    } else if (platform == 'twitter') {
      handle = provider.twitter;
    } else if (platform == 'instagram') {
      handle = provider.instagram;
    } else if (platform == 'spotify') {
      handle = provider.spotify;
    }
    final hasLink = handle.isNotEmpty;

    return GestureDetector(
      onTap: hasLink
          ? () {
              HapticFeedback.lightImpact();
              _showSocialActionSheet(
                  context, platform, name, handle, assetPath);
            }
          : () {
              HapticFeedback.lightImpact();
              _showEditSocialSheet();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasLink
                ? context.accentSecondary.withValues(alpha: 0.3)
                : context.textMuted.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Image.asset(
              assetPath,
              width: 18,
              height: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasLink ? handle : 'Add $name',
                style: TextStyle(
                  color: hasLink ? Colors.white : context.textMuted,
                  fontSize: 12,
                  fontWeight: hasLink ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onCopy,
    VoidCallback? onTogglePrivacy,
    VoidCallback? onTap,
    bool isPrivate = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: onTap != null ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: context.accentSecondary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                  style: TextStyle(
                    color: value == 'Not set' ? Colors.white38 : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            Icon(
              Icons.chevron_right_rounded,
              color: context.textSecondary.withValues(alpha: 0.6),
              size: 18,
            ),
            const SizedBox(width: 4),
          ],
        if (onTogglePrivacy != null && value != 'Not set' && value.isNotEmpty) ...[
          IconButton(
            icon: Icon(
              isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: isPrivate ? context.accentSecondary : context.textSecondary,
              size: 16,
            ),
            onPressed: onTogglePrivacy,
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: isPrivate ? 'Make public' : 'Make private',
          ),
          const SizedBox(width: 12),
        ],
        if (onCopy != null && value != 'Not set' && value.isNotEmpty)
          IconButton(
            icon: Icon(Icons.copy_rounded, color: context.textSecondary, size: 16),
            onPressed: onCopy,
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Copy to clipboard',
          ),
      ],
    ),
  );
}

  String _getSocialUrl(String platform, String handle) {
    return SocialLauncher.getSocialUrl(platform, handle);
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
            color: context.surfacePrimary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: context.borderMuted,
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
                      color: context.accentPrimary.withValues(alpha: 0.1),
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
                          style: TextStyle(
                            color: context.textSecondary,
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
                  color: context.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.borderMuted,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        url,
                        style: TextStyle(
                          color: context.accentSecondary,
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
                              content: Text('Copied $displayName link to clipboard!',
                                  style: TextStyle(color: context.textPrimary)),
                              backgroundColor: context.surfaceSecondary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.copy_rounded,
                          color: context.textSecondary, size: 18),
                      label: Text(
                        "Copy Link",
                        style: TextStyle(
                            color: context.textSecondary, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: context.borderMuted),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await SocialLauncher.launchSocialLink(
                              context, platform, handle);
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.open_in_new_rounded,
                            color: Colors.black, size: 18),
                        label: const Text(
                          "Open Account",
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.black,
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
    final initialBio = provider.bio.isNotEmpty
        ? provider.bio
        : provider.professionalBio;
    final controller = TextEditingController(text: initialBio);

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
                    final trimmedBio = controller.text.trim();
                    await provider.updateProfileField('bio', trimmedBio, uid);
                    await provider.updateProfileField(
                        'professionalBio', trimmedBio, uid);
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

  void _showAddExperienceSheet(BuildContext context) {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => ExperienceEditSheet(
        onSave: (item) => provider.addExperience(item),
      ),
    );
  }

  void _showEditExperienceSheet(BuildContext context, ExperienceItem item) {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => ExperienceEditSheet(
        item: item,
        onSave: (updated) => provider.updateExperience(updated),
        onDelete: () => provider.deleteExperience(item.id),
      ),
    );
  }

  void _showAddEducationSheet(BuildContext context) {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => EducationEditSheet(
        onSave: (item) => provider.addEducation(item),
      ),
    );
  }

  void _showEditEducationSheet(BuildContext context, EducationItem item) {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => EducationEditSheet(
        item: item,
        onSave: (updated) => provider.updateEducation(updated),
        onDelete: () => provider.deleteEducation(item.id),
      ),
    );
  }

  void _showEditSkillsSheet(BuildContext context) {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => SkillsEditSheet(
        currentSkills: provider.skills,
        onSave: (skills) => provider.setSkills(skills),
      ),
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
                        'Configure which social profiles show on your digital profile card.',
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
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
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
                                )
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final avatarUrl = provider.avatarUrl;

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
                                      ? Image.network(
                                          avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Container(
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
                                        )
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
                      const SizedBox(height: 28),

                      // Save Button
                      _buildSheetSaveButton(() async {
                        final newName = nameC.text.trim();
                        final uid = provider.userId;

                        if (uid != null) {
                          if (newName.isNotEmpty) {
                            await provider.updateProfileField(
                                'name', newName, uid);
                            setState(() {
                              _nameController.text = newName;
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

    final initialEmail = provider.email.isNotEmpty ? provider.email : provider.professionalEmail;
    final initialPhone = provider.phoneNumber.isNotEmpty ? provider.phoneNumber : provider.professionalPhoneNumber;

    final emailC = TextEditingController(text: initialEmail);
    final phoneC = TextEditingController(text: initialPhone);
    final professionC = TextEditingController(text: provider.profession);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetCtx) {
        bool emailPrivate = provider.isFieldPrivate('email') || provider.isFieldPrivate('professionalEmail');
        bool phonePrivate = provider.isFieldPrivate('phoneNumber') || provider.isFieldPrivate('professionalPhoneNumber');

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
                      const SizedBox(height: 18),

                      _buildSheetField(
                        label: 'Profession',
                        controller: professionC,
                        icon: Icons.work_outline_rounded,
                        accentColor: context.accentSecondary,
                      ),
                      const SizedBox(height: 14),

                      _buildSheetField(
                        label: 'Email',
                        controller: emailC,
                        icon: Icons.email_outlined,
                        accentColor: context.accentSecondary,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: emailPrivate,
                              activeColor: context.accentSecondary,
                              checkColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              side: BorderSide(
                                color: context.textSecondary.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  emailPrivate = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Keep email private",
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      _buildSheetField(
                        label: 'Phone Number',
                        controller: phoneC,
                        icon: Icons.phone_android_outlined,
                        accentColor: context.accentSecondary,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: phonePrivate,
                              activeColor: context.accentSecondary,
                              checkColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              side: BorderSide(
                                color: context.textSecondary.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  phonePrivate = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Keep phone number private",
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      _buildSheetSaveButton(() async {
                        final uid = provider.userId;
                        if (uid != null) {
                          final emailVal = emailC.text.trim();
                          final phoneVal = phoneC.text.trim();
                          final professionVal = professionC.text.trim();

                          await provider.updateProfileField('email', emailVal, uid);
                          await provider.updateProfileField('professionalEmail', emailVal, uid);
                          await provider.updateProfileField('phoneNumber', phoneVal, uid);
                          await provider.updateProfileField('professionalPhoneNumber', phoneVal, uid);
                          await provider.updateProfileField('profession', professionVal, uid);

                          await provider.setFieldPrivate('email', emailPrivate);
                          await provider.setFieldPrivate('professionalEmail', emailPrivate);
                          await provider.setFieldPrivate('phoneNumber', phonePrivate);
                          await provider.setFieldPrivate('professionalPhoneNumber', phonePrivate);
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

  Widget _buildSocialEditRow({
    required String platform,
    required String label,
    required TextEditingController controller,
    required String assetPath,
    required ProfileProvider provider,
    required StateSetter setModalState,
  }) {
    final isVisible = provider.isFieldOnCard(platform);

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
                  await provider.toggleFieldOnCard(platform);
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
    Widget? suffixIcon,
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
        suffixIcon: suffixIcon,
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
    final hasCustomColors = widget.customColors != null && widget.customColors!.isNotEmpty;
    final buttonColor = hasCustomColors ? widget.customColors!.first : context.accentSecondary;
    final effectiveColor =
        _isLoading ? buttonColor.withValues(alpha: 0.5) : buttonColor;

    final Decoration decoration;
    if (hasCustomColors && widget.customColors!.length > 1 && !_isLoading) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          colors: widget.customColors!,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      );
    } else {
      decoration = BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(14),
      );
    }

    return Container(
      width: double.infinity,
      decoration: decoration,
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
