import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/profile_card_type.dart';
import 'package:connect/Models/custom_link.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connect/services/image_upload_service.dart';
import 'package:connect/Pages/crop_image_page.dart';
import 'package:connect/services/analytics_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool _isSaving = false;
  static const String _defaultAvatarUrl = '';
  String _avatarUrl = _defaultAvatarUrl;

  late TextEditingController _nameController;
  late TextEditingController _professionController;
  late TextEditingController _companyController;
  late TextEditingController _emailController;
  late TextEditingController _professionalEmailController;
  late TextEditingController _phoneController;
  late TextEditingController _professionalPhoneController;
  late TextEditingController _bioController;
  late TextEditingController _professionalBioController;
  late FocusNode _bioFocusNode;
  late FocusNode _professionalBioFocusNode;
  late FocusNode _emailFocusNode;
  late FocusNode _professionalEmailFocusNode;
  late FocusNode _phoneFocusNode;
  late FocusNode _professionalPhoneFocusNode;
  String _casualCountryCode = '+91';
  String _professionalCountryCode = '+91';

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ProfileProvider>(context, listen: false);

    _nameController = TextEditingController(text: provider.name);
    _professionController = TextEditingController(text: provider.profession);
    _companyController = TextEditingController(text: provider.company);
    _emailController = TextEditingController(text: provider.email);
    _professionalEmailController =
        TextEditingController(text: provider.professionalEmail);

    final casualPhoneParsed = _parsePhone(provider.phoneNumber);
    _casualCountryCode = casualPhoneParsed['code']!;
    _phoneController =
        TextEditingController(text: casualPhoneParsed['number']!);

    final profPhoneParsed = _parsePhone(provider.professionalPhoneNumber);
    _professionalCountryCode = profPhoneParsed['code']!;
    _professionalPhoneController =
        TextEditingController(text: profPhoneParsed['number']!);

    _bioController = TextEditingController(text: provider.bio);
    _professionalBioController =
        TextEditingController(text: provider.professionalBio);
    _avatarUrl = provider.avatarUrl.isNotEmpty ? provider.avatarUrl : _defaultAvatarUrl;

    _bioFocusNode = FocusNode();
    _professionalBioFocusNode = FocusNode();
    _emailFocusNode = FocusNode();
    _professionalEmailFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();
    _professionalPhoneFocusNode = FocusNode();

    _nameController.addListener(_onFieldChanged);
    _professionController.addListener(_onFieldChanged);
    _companyController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _professionalEmailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _professionalPhoneController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _professionalBioController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _professionController.removeListener(_onFieldChanged);
    _companyController.removeListener(_onFieldChanged);
    _emailController.removeListener(_onFieldChanged);
    _professionalEmailController.removeListener(_onFieldChanged);
    _phoneController.removeListener(_onFieldChanged);
    _professionalPhoneController.removeListener(_onFieldChanged);
    _bioController.removeListener(_onFieldChanged);
    _professionalBioController.removeListener(_onFieldChanged);

    _nameController.dispose();
    _professionController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _professionalEmailController.dispose();
    _phoneController.dispose();
    _professionalPhoneController.dispose();
    _bioController.dispose();
    _professionalBioController.dispose();
    _bioFocusNode.dispose();
    _professionalBioFocusNode.dispose();
    _emailFocusNode.dispose();
    _professionalEmailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _professionalPhoneFocusNode.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Map<String, String> _parsePhone(String rawPhone) {
    final codes = [
      '+1', '+91', '+44', '+61', '+81', '+49', '+33', '+65', '+971', '+966',
      '+27', '+55', '+86', '+7', '+52', '+39', '+34', '+31', '+82'
    ];
    codes.sort((a, b) => b.length.compareTo(a.length));

    String cleaned = rawPhone.trim();
    for (final code in codes) {
      if (cleaned.startsWith(code)) {
        String rest = cleaned.substring(code.length).trim();
        return {'code': code, 'number': rest};
      }
    }
    return {'code': '+91', 'number': cleaned};
  }

  bool _isDataChanged() {
    if (!mounted) return false;
    final provider = Provider.of<ProfileProvider>(context, listen: false);

    final String casualPhoneText = _phoneController.text.trim();
    final String casualPhoneToCompare = casualPhoneText.isNotEmpty
        ? '$_casualCountryCode $casualPhoneText'
        : '';

    final String profPhoneText = _professionalPhoneController.text.trim();
    final String profPhoneToCompare = profPhoneText.isNotEmpty
        ? '$_professionalCountryCode $profPhoneText'
        : '';

    return _nameController.text.trim() != provider.name ||
        _professionController.text.trim() != provider.profession ||
        _companyController.text.trim() != provider.company ||
        _emailController.text.trim() != provider.email ||
        _professionalEmailController.text.trim() != provider.professionalEmail ||
        casualPhoneToCompare != provider.phoneNumber ||
        profPhoneToCompare != provider.professionalPhoneNumber ||
        _bioController.text.trim() != provider.bio ||
        _professionalBioController.text.trim() != provider.professionalBio ||
        _avatarUrl != provider.avatarUrl;
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final provider = Provider.of<ProfileProvider>(context, listen: false);
    try {
      provider.setValue('name', _nameController.text.trim());
      provider.setValue('profession', _professionController.text.trim());
      provider.setValue('company', _companyController.text.trim());
      provider.setValue('email', _emailController.text.trim());
      provider.setValue(
          'professionalEmail', _professionalEmailController.text.trim());

      final String casualPhoneText = _phoneController.text.trim();
      final String casualPhoneToSave = casualPhoneText.isNotEmpty
          ? '$_casualCountryCode $casualPhoneText'
          : '';
      provider.setValue('phoneNumber', casualPhoneToSave);

      final String profPhoneText = _professionalPhoneController.text.trim();
      final String profPhoneToSave = profPhoneText.isNotEmpty
          ? '$_professionalCountryCode $profPhoneText'
          : '';
      provider.setValue('professionalPhoneNumber', profPhoneToSave);

      provider.setValue('bio', _bioController.text.trim());
      provider.setValue(
          'professionalBio', _professionalBioController.text.trim());
      provider.setValue('avatarUrl', _avatarUrl);

      await provider.saveOrUpdateProfile();
      AnalyticsService.logEvent('full_profile_completed');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text("Profile saved successfully!",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary)),
              ],
            ),
            backgroundColor: const Color(0xFF7C3AED),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("Error saving profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving profile: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(context.radiusPremiumCard)),
      ),
      builder: (context) {
        bool isUploading = false;
        String? uploadError;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppDimensions.marginStandard,
                  right: AppDimensions.marginStandard,
                  top: 24.0,
                  bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Profile Photo",
                      style: context.screenHeading,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00F2FE),
                              context.accentSecondary
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Container(
                          width: 114,
                          height: 114,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.surfaceSecondary,
                          ),
                          child: ClipOval(
                            child: (_avatarUrl.isNotEmpty &&
                                    _avatarUrl.startsWith('http'))
                                ? Image.network(
                                    _avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Center(
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
                                : Center(
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
                      GlassmorphicButton(
                        onPressed: () {
                          setModalState(() {
                            isUploading = true;
                            uploadError = null;
                          });
                          _pickAndUploadImage(
                            setModalState: setModalState,
                            onUploadSuccess: (publicUrl) {
                              if (mounted) {
                                setState(() {
                                    _avatarUrl = publicUrl;
                                });
                                final provider = Provider.of<ProfileProvider>(
                                    context,
                                    listen: false);
                                provider.setValue('avatarUrl', publicUrl);
                                if (provider.userId != null) {
                                  provider.updateProfileField(
                                      'avatarUrl', publicUrl, provider.userId!);
                                } else {
                                  provider.saveOrUpdateProfile();
                                }
                              }
                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    "Profile photo updated and saved!",
                                    style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: context.accentSecondary,
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
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusComponent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.photo_library_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "Upload from Gallery",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (uploadError != null &&
                        uploadError != "No image picked" &&
                        uploadError != "No image cropped" &&
                        uploadError != "canceled") ...[
                      const SizedBox(height: 16),
                      Text(
                        "Upload Error: $uploadError\nMake sure storage bucket 'avatars' is created and RLS is public in Supabase.",
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontFamily: 'Inter'),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: context.bodyText.copyWith(
                          color: context.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCountryPicker(
      BuildContext context, ValueChanged<String?> onCountryCodeChanged) {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(context.radiusPremiumCard)),
      ),
      builder: (context) {
        return const _CountryCodePickerSheet();
      },
    ).then((selectedCode) {
      if (selectedCode != null) {
        onCountryCodeChanged(selectedCode);
      }
    });
  }

  void _confirmCancel() {
    if (_isDataChanged()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.radiusPremiumCard),
            side: BorderSide(color: context.borderMuted, width: 1.0),
          ),
          title: Text(
            "Discard changes?",
            style: context.cardTitle.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "You have unsaved changes. Are you sure you want to discard them?",
            style: context.bodyText.copyWith(color: context.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Keep Editing", style: TextStyle(color: context.accentSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Dismiss dialog
                Navigator.pop(context); // Dismiss edit profile page
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.radiusComponent),
                ),
              ),
              child: const Text("Discard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: context.captionText.copyWith(
          color: context.accentSecondary,
          fontSize: 12,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCompactField({
    required String label,
    required String hint,
    required TextEditingController controller,
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
    int maxLines = 1,
    Widget? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: context.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: context.captionText.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: context.surfaceSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.textMuted.withValues(alpha: 0.15),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              if (prefix != null) prefix,
              Expanded(
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  style: context.bodyText.copyWith(color: context.textPrimary, fontSize: 14),
                  cursorColor: context.accentSecondary,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: context.bodyText.copyWith(
                      color: context.textMuted.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialCard({
    required String fieldKey,
    required String title,
    required String handle,
    required Widget logo,
    required VoidCallback onEdit,
  }) {
    final provider = context.watch<ProfileProvider>();
    final assignment = provider.fieldAssignments[fieldKey] ??
        FieldCardAssignment(casual: false, professional: true);
    final hasHandle = handle.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.textMuted.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              logo,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: context.bodyText.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Text("Casual", style: TextStyle(color: Colors.white54, fontSize: 10)),
              const SizedBox(width: 4),
              _buildLocalCardToggle(
                icon: Icons.person_outline_rounded,
                isActive: assignment.casual,
                activeColor: context.accentSecondary,
                onTap: () => provider.toggleFieldOnCard(
                    fieldKey, ProfileCardType.casual),
              ),
              const SizedBox(width: 12),
              const Text("Pro", style: TextStyle(color: Colors.white54, fontSize: 10)),
              const SizedBox(width: 4),
              _buildLocalCardToggle(
                icon: Icons.work_outline_rounded,
                isActive: assignment.professional,
                activeColor: context.accentSecondary,
                onTap: () => provider.toggleFieldOnCard(
                    fieldKey, ProfileCardType.professional),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.surfacePrimary,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusComponent),
                border: Border.all(
                  color: context.textMuted.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasHandle ? handle : 'Tap to add $title',
                      style: TextStyle(
                        color: hasHandle
                            ? context.accentSecondary
                            : context.textMuted,
                        fontSize: 13,
                        fontWeight:
                            hasHandle ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.edit_rounded,
                      color: context.textSecondary, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalCardToggle({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? activeColor : context.surfacePrimary,
          border: Border.all(
            color: isActive
                ? activeColor
                : context.textMuted.withValues(alpha: 0.15),
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isActive ? Colors.white : context.textMuted,
        ),
      ),
    );
  }

  void _showEditSocialDialog(String title, String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusPremiumCard),
            side: BorderSide(
                color: context.textMuted.withValues(alpha: 0.2), width: 1.0),
          ),
          title: Text(
            "Edit $title",
            style: context.cardTitle.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            style: TextStyle(color: context.textPrimary),
            cursorColor: context.accentPrimary,
            decoration: InputDecoration(
              hintText: "Enter your $title handle or link",
              hintStyle: TextStyle(color: context.textMuted),
              filled: true,
              fillColor: context.surfaceSecondary,
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusComponent),
                borderSide: BorderSide(color: context.accentPrimary, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusComponent),
                borderSide:
                    BorderSide(color: context.textMuted.withValues(alpha: 0.2)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel",
                  style: TextStyle(color: context.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newValue = controller.text.trim();
                await _updateSocialLink(field, newValue);
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusComponent),
                ),
              ),
              child: const Text("Save",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateSocialLink(String field, String value) async {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    try {
      if (provider.userId != null) {
        await provider.updateProfileField(field, value, provider.userId!);
      } else {
        provider.setValue(field, value);
      }
      if (mounted) setState(() {});
    } catch (e) {
      print("Error updating social link: $e");
    }
  }

  Widget _buildSocialLinksSection() {
    final provider = Provider.of<ProfileProvider>(context);

    final linkedinLogo = Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Image.asset('assets/icons/linkedin.png', fit: BoxFit.contain),
    );

    final twitterLogo = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Image.asset('assets/icons/twitter.png', fit: BoxFit.contain),
    );

    return Column(
      children: [
        _buildSocialCard(
          fieldKey: 'linkedin',
          title: 'LinkedIn',
          handle: provider.linkedin,
          logo: linkedinLogo,
          onEdit: () =>
              _showEditSocialDialog('LinkedIn', 'linkedin', provider.linkedin),
        ),
        _buildSocialCard(
          fieldKey: 'twitter',
          title: 'X (Former Twitter)',
          handle: provider.twitter,
          logo: twitterLogo,
          onEdit: () =>
              _showEditSocialDialog('Twitter', 'twitter', provider.twitter),
        ),
        _buildSocialCard(
          fieldKey: 'instagram',
          title: 'Instagram',
          handle: provider.instagram,
          logo: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Image.asset('assets/icons/instagram.png', fit: BoxFit.contain),
          ),
          onEdit: () => _showEditSocialDialog(
              'Instagram', 'instagram', provider.instagram),
        ),
        _buildSocialCard(
          fieldKey: 'spotify',
          title: 'Spotify',
          handle: provider.spotify,
          logo: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Image.asset('assets/icons/spotify.png', fit: BoxFit.contain),
          ),
          onEdit: () =>
              _showEditSocialDialog('Spotify', 'spotify', provider.spotify),
        ),
      ],
    );
  }

  Widget _buildCustomLinksSection() {
    final provider = Provider.of<ProfileProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (provider.customLinks.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceSecondary,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: context.textMuted.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                "No custom links added yet. Tap 'Add New' to share websites, portfolios, or other links.",
                textAlign: TextAlign.center,
                style: context.bodyText.copyWith(
                  color: context.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ...provider.customLinks.map((link) {
            final globeLogo = Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.language_rounded,
                color: context.accentSecondary,
                size: 16,
              ),
            );

            return _buildSocialCard(
              fieldKey: link.id,
              title: link.name,
              handle: link.url,
              logo: globeLogo,
              onEdit: () => _showCustomLinkDialog(existingLink: link),
            );
          }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _showCustomLinkDialog(),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
          label: const Text("Add Custom Link", style: TextStyle(fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.accentSecondary,
            side: BorderSide(color: context.accentSecondary.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  void _showCustomLinkDialog({CustomLink? existingLink}) {
    final nameController =
        TextEditingController(text: existingLink?.name ?? '');
    final urlController = TextEditingController(text: existingLink?.url ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusPremiumCard),
            side: BorderSide(
              color: context.textMuted.withValues(alpha: 0.2),
              width: 1.0,
            ),
          ),
          title: Text(
            existingLink == null ? "Add Custom Link" : "Edit Custom Link",
            style: context.cardTitle.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: context.textPrimary),
                cursorColor: context.accentPrimary,
                decoration: InputDecoration(
                  hintText: "Link Name (e.g., Portfolio, Website)",
                  hintStyle: TextStyle(color: context.textMuted),
                  filled: true,
                  fillColor: context.surfaceSecondary,
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusComponent),
                    borderSide:
                        BorderSide(color: context.accentPrimary, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusComponent),
                    borderSide: BorderSide(
                        color: context.textMuted.withValues(alpha: 0.2)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                style: TextStyle(color: context.textPrimary),
                cursorColor: context.accentPrimary,
                decoration: InputDecoration(
                  hintText: "URL (e.g., https://mywebsite.com)",
                  hintStyle: TextStyle(color: context.textMuted),
                  filled: true,
                  fillColor: context.surfaceSecondary,
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusComponent),
                    borderSide:
                        BorderSide(color: context.accentPrimary, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusComponent),
                    borderSide: BorderSide(
                        color: context.textMuted.withValues(alpha: 0.2)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (existingLink != null)
              TextButton(
                onPressed: () async {
                  final provider =
                      Provider.of<ProfileProvider>(context, listen: false);
                  await provider.removeCustomLink(
                      existingLink.id, provider.userId);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text("Delete",
                    style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel",
                  style: TextStyle(color: context.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final nameVal = nameController.text.trim();
                final urlVal = urlController.text.trim();
                if (nameVal.isEmpty || urlVal.isEmpty) return;

                final provider =
                    Provider.of<ProfileProvider>(context, listen: false);

                if (existingLink == null) {
                  await provider.addCustomLink(nameVal, urlVal, provider.userId);
                } else {
                  await provider.editCustomLink(existingLink.id, nameVal, urlVal, provider.userId);
                }
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusComponent),
                ),
              ),
              child: const Text("Save",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdvancedCardSettingsPanel() {
    final provider = context.watch<ProfileProvider>();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
        border: Border.all(color: context.textMuted.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: context.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              "Advanced Card Visibility Settings",
              style: context.bodyText.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              "Configure which details show on Casual vs. Work cards",
              style: context.captionText.copyWith(color: context.textSecondary, fontSize: 11),
            ),
            leading: Icon(Icons.settings_suggest_rounded, color: context.accentSecondary),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _buildAdvancedToggleRow(provider, 'name', 'Full Name'),
              _buildAdvancedToggleRow(provider, 'avatarUrl', 'Photo'),
              _buildAdvancedToggleRow(provider, 'profession', 'Profession'),
              _buildAdvancedToggleRow(provider, 'company', 'Company'),
              _buildAdvancedToggleRow(provider, 'email', 'Casual Email'),
              _buildAdvancedToggleRow(provider, 'professionalEmail', 'Work Email'),
              _buildAdvancedToggleRow(provider, 'phoneNumber', 'Casual Phone'),
              _buildAdvancedToggleRow(provider, 'professionalPhoneNumber', 'Work Phone'),
              _buildAdvancedToggleRow(provider, 'bio', 'Casual Bio'),
              _buildAdvancedToggleRow(provider, 'professionalBio', 'Work Bio'),
              _buildAdvancedToggleRow(provider, 'linkedin', 'LinkedIn Link'),
              _buildAdvancedToggleRow(provider, 'twitter', 'Twitter Link'),
              _buildAdvancedToggleRow(provider, 'instagram', 'Instagram Link'),
              _buildAdvancedToggleRow(provider, 'spotify', 'Spotify Link'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedToggleRow(ProfileProvider provider, String fieldKey, String label) {
    final assignment = provider.fieldAssignments[fieldKey] ??
        FieldCardAssignment(casual: fieldKey == 'name' || fieldKey == 'avatarUrl', professional: true);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.bodyText.copyWith(color: context.textPrimary, fontSize: 13),
            ),
          ),
          const Text("Casual", style: TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(width: 4),
          _buildLocalCardToggle(
            icon: Icons.person_outline_rounded,
            isActive: assignment.casual,
            activeColor: context.accentSecondary,
            onTap: () => provider.toggleFieldOnCard(fieldKey, ProfileCardType.casual),
          ),
          const SizedBox(width: 12),
          const Text("Pro", style: TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(width: 4),
          _buildLocalCardToggle(
            icon: Icons.work_outline_rounded,
            isActive: assignment.professional,
            activeColor: context.accentSecondary,
            onTap: () => provider.toggleFieldOnCard(fieldKey, ProfileCardType.professional),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasChanges = _isDataChanged();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmCancel();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F101A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F101A),
          elevation: 0,
          leadingWidth: 80,
          leading: TextButton(
            onPressed: _confirmCancel,
            child: Text(
              "Cancel",
              style: TextStyle(
                color: context.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          title: Text(
            "Edit Profile",
            style: context.screenHeading.copyWith(fontSize: 18),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: (hasChanges && !_isSaving) ? _saveProfile : null,
                child: Text(
                  "Done",
                  style: TextStyle(
                    color: hasChanges ? context.accentSecondary : context.textMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFF00F2FE)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: ClipOval(
                            child: (_avatarUrl.isNotEmpty && _avatarUrl.startsWith('http'))
                                ? Image.network(
                                    _avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      color: const Color(0xFF1E1F32),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _nameController.text.isNotEmpty
                                            ? _nameController.text.substring(0, 1).toUpperCase()
                                            : "?",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
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
                                          ? _nameController.text.substring(0, 1).toUpperCase()
                                          : "?",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _showPhotoPicker,
                          child: Text(
                            "Change Profile Photo",
                            style: TextStyle(
                              color: context.accentSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _buildSectionHeader("BASIC INFO"),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfacePrimary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderMuted),
                    ),
                    child: _buildCompactField(
                      label: 'Full Name',
                      hint: 'Jordan Miller',
                      controller: _nameController,
                      icon: Icons.person_outline_rounded,
                    ),
                  ),

                  _buildSectionHeader("CASUAL CARD DETAILS (PERSONAL)"),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfacePrimary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderMuted),
                    ),
                    child: Column(
                      children: [
                        _buildCompactField(
                          label: 'Casual Bio',
                          hint: 'Tell us about yourself...',
                          controller: _bioController,
                          icon: Icons.description_outlined,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        _buildCompactField(
                          label: 'Casual Email',
                          hint: 'jordan@design.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 12),
                        _buildCompactField(
                          label: 'Casual Phone',
                          hint: '555-0199',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          icon: Icons.phone_android_outlined,
                          prefix: GestureDetector(
                            onTap: () => _showCountryPicker(context, (val) {
                              if (val != null) {
                                setState(() => _casualCountryCode = val);
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: context.textMuted.withValues(alpha: 0.15),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_getFlagForCode(_casualCountryCode)} $_casualCountryCode',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: context.textSecondary,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _buildSectionHeader("WORK CARD DETAILS (PROFESSIONAL)"),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfacePrimary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderMuted),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildCompactField(
                                label: 'Profession',
                                hint: 'Product Designer',
                                controller: _professionController,
                                icon: Icons.work_outline_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildCompactField(
                                label: 'Company',
                                hint: 'Design Studio Inc.',
                                controller: _companyController,
                                icon: Icons.apartment_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildCompactField(
                          label: 'Work Bio',
                          hint: 'Tell clients about your work...',
                          controller: _professionalBioController,
                          icon: Icons.description_outlined,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        _buildCompactField(
                          label: 'Work Email',
                          hint: 'work@design.com',
                          controller: _professionalEmailController,
                          keyboardType: TextInputType.emailAddress,
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 12),
                        _buildCompactField(
                          label: 'Work Phone',
                          hint: '555-0200',
                          controller: _professionalPhoneController,
                          keyboardType: TextInputType.phone,
                          icon: Icons.phone_android_outlined,
                          prefix: GestureDetector(
                            onTap: () => _showCountryPicker(context, (val) {
                              if (val != null) {
                                setState(() => _professionalCountryCode = val);
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: context.textMuted.withValues(alpha: 0.15),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_getFlagForCode(_professionalCountryCode)} $_professionalCountryCode',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: context.textSecondary,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _buildSectionHeader("CONNECTED SOCIAL LINKS"),
                  _buildSocialLinksSection(),

                  _buildSectionHeader("CUSTOM LINKS"),
                  _buildCustomLinksSection(),

                  const SizedBox(height: 24),
                  _buildAdvancedCardSettingsPanel(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
            if (_isSaving)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        context.accentSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getFlagForCode(String code) {
    switch (code) {
      case '+971': return '🇦🇪';
      case '+1': return '🇺🇸';
      case '+55': return '🇧🇷';
      case '+52': return '🇲🇽';
      case '+44': return '🇬🇧';
      case '+49': return '🇩🇪';
      case '+33': return '🇫🇷';
      case '+39': return '🇮🇹';
      case '+34': return '🇪🇸';
      case '+31': return '🇳🇱';
      case '+91': return '🇮🇳';
      case '+86': return '🇨🇳';
      case '+65': return '🇸🇬';
      case '+81': return '🇯🇵';
      case '+82': return '🇰🇷';
      case '+966': return '🇸🇦';
      default: return '🏳️';
    }
  }
}

class CountryInfo {
  final String name;
  final String code;
  final String flag;
  final String region;

  const CountryInfo({
    required this.name,
    required this.code,
    required this.flag,
    required this.region,
  });
}

class _CountryCodePickerSheet extends StatefulWidget {
  const _CountryCodePickerSheet();

  @override
  State<_CountryCodePickerSheet> createState() =>
      _CountryCodePickerSheetState();
}

class _CountryCodePickerSheetState extends State<_CountryCodePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<CountryInfo> _allCountries = [
    CountryInfo(name: 'United Arab Emirates', code: '+971', flag: '🇦🇪', region: 'Dubai'),
    CountryInfo(name: 'United States', code: '+1', flag: '🇺🇸', region: 'America'),
    CountryInfo(name: 'Canada', code: '+1', flag: '🇨🇦', region: 'America'),
    CountryInfo(name: 'Brazil', code: '+55', flag: '🇧🇷', region: 'America'),
    CountryInfo(name: 'Mexico', code: '+52', flag: '🇲🇽', region: 'America'),
    CountryInfo(name: 'United Kingdom', code: '+44', flag: '🇬🇧', region: 'Europe'),
    CountryInfo(name: 'Germany', code: '+49', flag: '🇩🇪', region: 'Europe'),
    CountryInfo(name: 'France', code: '+33', flag: '🇫🇷', region: 'Europe'),
    CountryInfo(name: 'Italy', code: '+39', flag: '🇮🇹', region: 'Europe'),
    CountryInfo(name: 'Spain', code: '+34', flag: '🇪🇸', region: 'Europe'),
    CountryInfo(name: 'Netherlands', code: '+31', flag: '🇳🇱', region: 'Europe'),
    CountryInfo(name: 'India', code: '+91', flag: '🇮🇳', region: 'Asia'),
    CountryInfo(name: 'China', code: '+86', flag: '🇨🇳', region: 'Asia'),
    CountryInfo(name: 'Singapore', code: '+65', flag: '🇸🇬', region: 'Asia'),
    CountryInfo(name: 'Japan', code: '+81', flag: '🇯🇵', region: 'Asia'),
    CountryInfo(name: 'South Korea', code: '+82', flag: '🇰🇷', region: 'Asia'),
    CountryInfo(name: 'Saudi Arabia', code: '+966', flag: '🇸🇦', region: 'Asia'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.toLowerCase().trim();
    final filtered = _allCountries.where((country) {
      return country.name.toLowerCase().contains(query) ||
          country.code.contains(query) ||
          country.region.toLowerCase().contains(query);
    }).toList();

    final Map<String, List<CountryInfo>> grouped = {};
    for (var c in filtered) {
      if (!grouped.containsKey(c.region)) {
        grouped[c.region] = [];
      }
      grouped[c.region]!.add(c);
    }

    final orderedRegions = ['Dubai', 'America', 'Europe', 'Asia']
        .where((r) => grouped.containsKey(r))
        .toList();
    for (var r in grouped.keys) {
      if (!orderedRegions.contains(r)) {
        orderedRegions.add(r);
      }
    }

    final double bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: context.surfacePrimary,
      borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.radiusPremiumCard)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.marginStandard),
              child: Text(
                'Select Country',
                style: context.screenHeading.copyWith(
                  color: context.textPrimary,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                style: context.bodyText.copyWith(color: context.textPrimary),
                cursorColor: context.accentSecondary,
                decoration: InputDecoration(
                  hintText: 'Search country or code...',
                  hintStyle: context.bodyText.copyWith(
                    color: context.textMuted,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: context.textMuted,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: context.textMuted,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: context.surfaceSecondary,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusComponent),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusComponent),
                    borderSide: BorderSide(
                      color: context.textMuted.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusComponent),
                    borderSide: BorderSide(
                      color: context.accentSecondary,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No countries found',
                        style: context.bodyText.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding:
                          EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomPadding),
                      itemCount: orderedRegions.length,
                      itemBuilder: (context, regionIndex) {
                        final regionName = orderedRegions[regionIndex];
                        final countries = grouped[regionName]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 8, top: 16, bottom: 8),
                              child: Text(
                                regionName.toUpperCase(),
                                style: context.captionText.copyWith(
                                  color: context.accentSecondary,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            ...countries.map((country) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  splashColor: context.accentSecondary
                                      .withValues(alpha: 0.1),
                                  highlightColor: context.accentSecondary
                                      .withValues(alpha: 0.05),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusComponent),
                                  ),
                                  leading: Text(
                                    country.flag,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  title: Text(
                                    country.name,
                                    style: context.bodyText.copyWith(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: Text(
                                    country.code,
                                    style: context.bodyText.copyWith(
                                      color: context.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context, country.code);
                                  },
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
