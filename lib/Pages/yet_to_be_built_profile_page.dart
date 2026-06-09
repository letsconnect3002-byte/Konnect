import 'package:connect/Models/profile_card_type.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Widgets/card_field_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connect/services/image_upload_service.dart';
import 'package:connect/Pages/crop_image_page.dart';
import 'package:skeletonizer/skeletonizer.dart';

class YetToBeBuiltProfilePage extends StatefulWidget {
  const YetToBeBuiltProfilePage({super.key});

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

  final Map<String, bool> _editMode = {
    'name': false,
    'profession': false,
    'company': false,
    'email': false,
    'professionalEmail': false,
    'phoneNumber': false,
    'professionalPhoneNumber': false,
    'bio': false,
    'professionalBio': false,
  };

  bool _isEditing(String field) => _editMode[field] ?? false;

  void _setEditMode(String field, bool value) {
    if (_editMode[field] != value) {
      setState(() => _editMode[field] = value);
    }
  }

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ProfileProvider>(context, listen: false);

    // If profile is already loaded in memory, start without a loading spinner
    _isLoading = !provider.hasData;

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

    _bioFocusNode = FocusNode();
    _professionalBioFocusNode = FocusNode();
    _emailFocusNode = FocusNode();
    _professionalEmailFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();
    _professionalPhoneFocusNode = FocusNode();

    // Setup real-time card preview listeners
    _nameController.addListener(_onFieldChanged);
    _professionController.addListener(_onFieldChanged);
    _companyController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _professionalEmailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _professionalPhoneController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _professionalBioController.addListener(_onFieldChanged);

    _bioFocusNode.addListener(() {
      if (!_bioFocusNode.hasFocus) {
        if (_isEditing('bio')) {
          _setEditMode('bio', false);
        }
      }
    });

    _professionalBioFocusNode.addListener(() {
      if (!_professionalBioFocusNode.hasFocus) {
        if (_isEditing('professionalBio')) {
          _setEditMode('professionalBio', false);
        }
      }
    });

    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        if (_isEditing('email')) {
          _setEditMode('email', false);
        }
      }
    });

    _professionalEmailFocusNode.addListener(() {
      if (!_professionalEmailFocusNode.hasFocus) {
        if (_isEditing('professionalEmail')) {
          _setEditMode('professionalEmail', false);
        }
      }
    });

    _phoneFocusNode.addListener(() {
      if (!_phoneFocusNode.hasFocus) {
        if (_isEditing('phoneNumber')) {
          _setEditMode('phoneNumber', false);
        }
      }
    });

    _professionalPhoneFocusNode.addListener(() {
      if (!_professionalPhoneFocusNode.hasFocus) {
        if (_isEditing('professionalPhoneNumber')) {
          _setEditMode('professionalPhoneNumber', false);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
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

  Map<String, String> _parsePhone(String rawPhone) {
    final codes = [
      '+1',
      '+91',
      '+44',
      '+61',
      '+81',
      '+49',
      '+33',
      '+65',
      '+971',
      '+966',
      '+27',
      '+55',
      '+86',
      '+7',
      '+52',
      '+39',
      '+34',
      '+31',
      '+82'
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

  void _onFieldChanged() {
    if (mounted) {
      setState(() {});
    }
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
        _professionalEmailController.text.trim() !=
            provider.professionalEmail ||
        casualPhoneToCompare != provider.phoneNumber ||
        profPhoneToCompare != provider.professionalPhoneNumber ||
        _bioController.text.trim() != provider.bio ||
        _professionalBioController.text.trim() != provider.professionalBio ||
        _avatarUrl != provider.avatarUrl;
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
    _professionController.text = provider.profession;
    _companyController.text = provider.company;
    _emailController.text = provider.email;
    _professionalEmailController.text = provider.professionalEmail;

    final casualPhoneParsed = _parsePhone(provider.phoneNumber);
    _casualCountryCode = casualPhoneParsed['code']!;
    _phoneController.text = casualPhoneParsed['number']!;

    final profPhoneParsed = _parsePhone(provider.professionalPhoneNumber);
    _professionalCountryCode = profPhoneParsed['code']!;
    _professionalPhoneController.text = profPhoneParsed['number']!;

    _bioController.text = provider.bio;
    _professionalBioController.text = provider.professionalBio;
    _avatarUrl =
        provider.avatarUrl.isNotEmpty ? provider.avatarUrl : _defaultAvatarUrl;
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text("Profile saved successfully!",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Color(0xFF8B5CF6),
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
        onUploadError("No image picked");
        return;
      }

      setModalState(() {});

      final bytes = await imageFile.readAsBytes();

      if (!mounted) return;

      // Navigate to the beautiful custom crop screen
      final Uint8List? croppedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => CropImagePage(imageBytes: bytes),
        ),
      );

      if (croppedBytes == null) {
        onUploadError("No image cropped");
        return;
      }

      // Re-trigger loading state in bottom sheet UI
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
      backgroundColor: const Color(0xFF13141F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  left: 24.0,
                  right: 24.0,
                  top: 24.0,
                  bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Profile Photo",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter'),
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
                            colors: [Color(0xFF00F2FE), Color(0xFF8B5CF6)],
                          ),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          radius: 57,
                          backgroundImage: (_avatarUrl.isNotEmpty &&
                                  _avatarUrl.contains(
                                      'supabase.co/storage/v1/object/public/avatars/'))
                              ? NetworkImage(_avatarUrl)
                              : null,
                          backgroundColor: const Color(0xFF1B1C2A),
                          child: (_avatarUrl.isNotEmpty &&
                                  _avatarUrl.contains(
                                      'supabase.co/storage/v1/object/public/avatars/'))
                              ? null
                              : Text(
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
                                // Immediately persist to provider + database
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
                              Navigator.pop(
                                  context); // Auto-dismiss sheet on success

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    "Profile photo updated and saved!",
                                    style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: const Color(0xFF8B5CF6),
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
                                uploadError = err;
                              });
                            },
                          );
                        },
                        icon: const Icon(Icons.photo_library_rounded,
                            color: Colors.white, size: 18),
                        label: const Text(
                          "Upload from Gallery",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C1D30),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFF26273C)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                    if (uploadError != null &&
                        uploadError != "No image picked") ...[
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
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Color(0xFF5C5E78),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Skeletonizer(
        enabled: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF090A0F),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  left: 24.0, right: 24.0, top: 16.0, bottom: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSkeletonHeader(),
                  const SizedBox(height: 28),
                  _buildSkeletonCardSection(),
                  const SizedBox(height: 32),
                  _buildSkeletonEditorForm(),
                  const SizedBox(height: 32),
                  _buildSkeletonSocialLinks(),
                  const SizedBox(height: 16),
                  _buildSkeletonSaveButton(),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Rebuild card preview when Casual/Professional field toggles change.
    context.watch<ProfileProvider>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF090A0F),
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(
                    left: 24.0, right: 24.0, top: 16.0, bottom: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Header Capsule
                    _buildHeader(context),
                    const SizedBox(height: 28),

                    // YOUR CARDS — Casual / Professional + Front / Back
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'YOUR CARDS',
                          style: TextStyle(
                            color: Color(0xFF8B8C9E),
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        _buildFrontBackToggle(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildCardTypeTabs(),
                    const SizedBox(height: 16),

                    // Premium Glowing Gradient Border Business Card
                    _buildDigitalCard(),
                    const SizedBox(height: 32),

                    // EDIT DETAILS Header
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'EDIT DETAILS',
                          style: TextStyle(
                            color: Color(0xFF8B8C9E),
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Editor Container
                    _buildEditorForm(),
                    const SizedBox(height: 32),

                    _buildSocialLinksSection(),
                    const SizedBox(height: 16),

                    _buildSaveButton(),
                    const SizedBox(height: 0),
                  ],
                ),
              ),
              if (_isSaving)
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLinksSection() {
    final provider = Provider.of<ProfileProvider>(context);

    // LinkedIn
    final linkedinLogo = Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFFD946EF),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          "in",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            fontFamily: "Inter",
          ),
        ),
      ),
    );

    // Twitter
    final twitterLogo = Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFF1DA1F2),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.flutter_dash_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.link_rounded, color: Color(0xFF8B5CF6), size: 18),
                SizedBox(width: 8),
                Text(
                  'SOCIAL LINKS',
                  style: TextStyle(
                    color: Color(0xFF8B8C9E),
                    fontSize: 14.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
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
          title: 'Twitter',
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
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF58529),
                  Color(0xFFDD2A7B),
                  Color(0xFF8134AF)
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.camera_alt_rounded,
                color: Colors.white, size: 18),
          ),
          onEdit: () => _showEditSocialDialog(
              'Instagram', 'instagram', provider.instagram),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2030)),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => provider.toggleFieldOnCard(
                    fieldKey, ProfileCardType.casual),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: assignment.casual
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF1C1D2A),
                    border: Border.all(
                      color: assignment.casual
                          ? const Color(0xFF8B5CF6)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: assignment.casual
                        ? Colors.white
                        : const Color(0xFF5C5E78),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => provider.toggleFieldOnCard(
                    fieldKey, ProfileCardType.professional),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: assignment.professional
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF1C1D2A),
                    border: Border.all(
                      color: assignment.professional
                          ? const Color(0xFF8B5CF6)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Icon(
                    Icons.work_outline_rounded,
                    size: 16,
                    color: assignment.professional
                        ? Colors.white
                        : const Color(0xFF5C5E78),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF191A2A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasHandle ? handle : 'Tap to add $title',
                      style: TextStyle(
                        color: hasHandle
                            ? const Color(0xFF8B5CF6)
                            : Colors.white30,
                        fontSize: 14,
                        fontWeight:
                            hasHandle ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.edit_rounded,
                      color: Color(0xFF8B8C9E), size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSocialDialog(String title, String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF13141F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF1F2030), width: 1.0),
          ),
          title: Text(
            "Edit $title",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            cursorColor: const Color(0xFF8B5CF6),
            decoration: InputDecoration(
              hintText: "Enter your $title handle or link",
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: const Color(0xFF191A2A),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newValue = controller.text.trim();
                await _updateSocialLink(field, newValue);
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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

  Widget _buildSaveButton() {
    final hasChanges = _isDataChanged();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: hasChanges
            ? const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: hasChanges ? null : const Color(0xFF1B1D30),
        boxShadow: hasChanges
            ? [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: (hasChanges && !_isSaving) ? _saveProfile : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: hasChanges ? Colors.white : Colors.white24,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Save Changes',
              style: TextStyle(
                color: hasChanges ? Colors.white : Colors.white30,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrontBackToggle() {
    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2030)),
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
          color: isActive ? const Color(0xFF8B5CF6) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF8B8C9E),
            fontSize: 12,
            fontWeight: FontWeight.bold,
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

  bool _fieldVisible(String field) {
    final provider = Provider.of<ProfileProvider>(context);
    return provider.isFieldOnCard(field, _previewCard);
  }

  Widget _buildHeader(BuildContext context) {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
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
          // Back Button
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  // color: Color(0xFF1C1D2A),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 16,
                  height: 16,
                )

                // const Icon(
                //   Icons.arrow_back_ios_new_rounded,
                //   color: Colors.white,
                //   size: 16,
                // ),
                ),
          ),
          // Titles
          Column(
            children: const [
              Text(
                'My Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Digital Card',
                style: TextStyle(
                  color: Color(0xFF8B8C9E),
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          // Menu Button (Sign Out popup)
          PopupMenuButton<String>(
            color: const Color(0xFF13141F),
            offset: const Offset(0, 48),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1F2030), width: 1.5),
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF1C1D2A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.more_vert_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            onSelected: (value) async {
              if (value == 'sign_out') {
                HapticFeedback.mediumImpact();
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await Supabase.instance.client.auth.signOut();
                  provider.clearFields();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Signed out successfully"),
                      backgroundColor: Color(0xFF8B5CF6),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  print("Error signing out: $e");
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'sign_out',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Sign Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

        return AnimatedContainer(
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

  Widget _buildUnifiedFrontCard(double cardWidth) {
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
                  color: const Color(0xFF151628),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
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
                  _companyController.text.trim().isEmpty
                      ? 'CONNECT'
                      : _companyController.text.trim().toUpperCase(),
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
          left: 18,
          right: W * 0.4,
          bottom: 14,
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
                      _nameController.text.trim().isEmpty
                          ? 'Jordan Miller'
                          : _nameController.text.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              if (_fieldVisible('profession')) ...[
                const SizedBox(height: 4),
                AnimatedAlign(
                  duration: _cardAnimDuration,
                  curve: _cardAnimCurve,
                  alignment: Alignment.centerLeft,
                  child: AnimatedDefaultTextStyle(
                    duration: _cardAnimDuration,
                    curve: _cardAnimCurve,
                    style: const TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                    child: Text(
                      _professionController.text.trim().isEmpty
                          ? 'Product Designer'
                          : _professionController.text.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
    final isCasualData = _previewCard == ProfileCardType.casual;
    final W = cardWidth;

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
              if (_fieldVisible('avatarUrl'))
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
                    child: (_avatarUrl.isNotEmpty &&
                            _avatarUrl.contains(
                                'supabase.co/storage/v1/object/public/avatars/'))
                        ? Image.network(
                            _avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF1B1C2A),
                              alignment: Alignment.center,
                              child: Text(
                                _nameController.text.isNotEmpty
                                    ? _nameController.text
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
                            color: const Color(0xFF1B1C2A),
                            alignment: Alignment.center,
                            child: Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text
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
                            _nameController.text.trim().isEmpty
                                ? 'Jordan Miller'
                                : _nameController.text.trim(),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    if (_fieldVisible('profession')) ...[
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedDefaultTextStyle(
                          duration: _cardAnimDuration,
                          curve: _cardAnimCurve,
                          style: const TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                          child: Text(
                            _professionController.text.trim().isEmpty
                                ? 'Product Designer'
                                : _professionController.text.trim(),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_fieldVisible('company')) ...[
                _buildUnifiedCardRow(
                  Icons.apartment_rounded,
                  _companyController.text.trim().isEmpty
                      ? 'Design Studio Inc.'
                      : _companyController.text.trim(),
                  false,
                ),
                const SizedBox(height: 5),
              ],
              if (isCasualData) ...[
                if (_fieldVisible('email')) ...[
                  _buildUnifiedCardRow(
                    Icons.email_outlined,
                    _emailController.text.trim().isEmpty
                        ? 'jordan@designstudio.com'
                        : _emailController.text.trim(),
                    false,
                  ),
                  const SizedBox(height: 5),
                ],
                if (_fieldVisible('phoneNumber'))
                  _buildUnifiedCardRow(
                    Icons.phone_rounded,
                    _phoneController.text.trim().isEmpty
                        ? '+1 (555) 123-4567'
                        : '$_casualCountryCode ${_phoneController.text.trim()}',
                    false,
                  ),
              ] else ...[
                if (_fieldVisible('email')) ...[
                  _buildUnifiedCardRow(
                    Icons.email_outlined,
                    _professionalEmailController.text.trim().isEmpty
                        ? 'jordan@designstudio.com'
                        : _professionalEmailController.text.trim(),
                    false,
                  ),
                  const SizedBox(height: 5),
                ],
                if (_fieldVisible('phoneNumber'))
                  _buildUnifiedCardRow(
                    Icons.phone_rounded,
                    _professionalPhoneController.text.trim().isEmpty
                        ? '+1 (555) 123-4567'
                        : '$_professionalCountryCode ${_professionalPhoneController.text.trim()}',
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
          left: 16,
          right: (W * 0.5) + 6,
          top: 74,
          height: 60,
          child: _fieldVisible('bio')
              ? Text(
                  isCasualData
                      ? (_bioController.text.trim().isEmpty
                          ? 'Creating delightful user experiences through thoughtful design and innovation.'
                          : _bioController.text.trim())
                      : (_professionalBioController.text.trim().isEmpty
                          ? 'Senior Product Designer with 8+ years of experience crafting intuitive digital solutions.'
                          : _professionalBioController.text.trim()),
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
                color: isCasual ? const Color(0xFF8B8C9E) : Colors.white70,
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

  Widget _buildProfilePhotoSection() {
    final provider = context.watch<ProfileProvider>();
    final assignment = provider.fieldAssignments['avatarUrl'] ??
        FieldCardAssignment(casual: false, professional: true);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2030)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.image_outlined,
                  color: Color(0xFF8B5CF6), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Profile Photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildLocalCardToggle(
                icon: Icons.person_outline_rounded,
                isActive: assignment.casual,
                onTap: () => provider.toggleFieldOnCard(
                    'avatarUrl', ProfileCardType.casual),
              ),
              const SizedBox(width: 8),
              _buildLocalCardToggle(
                icon: Icons.work_outline_rounded,
                isActive: assignment.professional,
                onTap: () => provider.toggleFieldOnCard(
                    'avatarUrl', ProfileCardType.professional),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(1.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                child: ClipOval(
                  child: (_avatarUrl.isNotEmpty &&
                          _avatarUrl.contains(
                              'supabase.co/storage/v1/object/public/avatars/'))
                      ? Image.network(
                          _avatarUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: const Color(0xFF1B1C2A),
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
                        )
                      : Container(
                          width: 72,
                          height: 72,
                          color: const Color(0xFF1B1C2A),
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
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: _showPhotoPicker,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF191A2A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    child: const Text(
                      'Change Photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildLocalCardToggle({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? const Color(0xFF8B5CF6) : const Color(0xFF1C1D2A),
          border: Border.all(
            color: isActive
                ? const Color(0xFF8B5CF6)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isActive ? Colors.white : const Color(0xFF5C5E78),
        ),
      ),
    );
  }

  Widget _buildEditorForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfilePhotoSection(),
        CardFieldInput(
          fieldKey: 'name',
          label: 'Full Name',
          hint: 'Jordan Miller',
          icon: Icons.person_outline_rounded,
          controller: _nameController,
          showToggles: false,
          isEditing: _isEditing('name'),
          onEditingChanged: (val) => _setEditMode('name', val),
        ),
        CardFieldInput(
          fieldKey: 'profession',
          label: 'Profession',
          hint: 'Product Designer',
          icon: Icons.work_outline_rounded,
          controller: _professionController,
          isEditing: _isEditing('profession'),
          onEditingChanged: (val) => _setEditMode('profession', val),
        ),
        CardFieldInput(
          fieldKey: 'company',
          label: 'Company',
          hint: 'Design Studio Inc.',
          icon: Icons.apartment_rounded,
          controller: _companyController,
          isEditing: _isEditing('company'),
          onEditingChanged: (val) => _setEditMode('company', val),
        ),
        _buildEmailSection(),
        _buildPhoneSection(),
        _buildBioSection(),
      ],
    );
  }

  String _getFlagForCode(String code) {
    switch (code) {
      case '+971':
        return '🇦🇪';
      case '+1':
        return '🇺🇸';
      case '+55':
        return '🇧🇷';
      case '+52':
        return '🇲🇽';
      case '+44':
        return '🇬🇧';
      case '+49':
        return '🇩🇪';
      case '+33':
        return '🇫🇷';
      case '+39':
        return '🇮🇹';
      case '+34':
        return '🇪🇸';
      case '+31':
        return '🇳🇱';
      case '+91':
        return '🇮🇳';
      case '+86':
        return '🇨🇳';
      case '+65':
        return '🇸🇬';
      case '+81':
        return '🇯🇵';
      case '+82':
        return '🇰🇷';
      case '+966':
        return '🇸🇦';
      default:
        return '🏳️';
    }
  }

  void _showCountryPicker(
      BuildContext context, ValueChanged<String?> onCountryCodeChanged) {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF13141F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

  Widget _buildEmailSection() {
    final provider = context.watch<ProfileProvider>();
    final assignment = provider.fieldAssignments['email'] ??
        FieldCardAssignment(casual: true, professional: true);

    final isCasualEditing = _isEditing('email');
    final isCasualFilled = _emailController.text.isNotEmpty;
    final casualReadOnly = isCasualFilled && !isCasualEditing;

    final isProfEditing = _isEditing('professionalEmail');
    final isProfFilled = _professionalEmailController.text.isNotEmpty;
    final profReadOnly = isProfFilled && !isProfEditing;

    // Autofocus when edit mode is toggled on
    if (isCasualEditing && !_emailFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_emailFocusNode.hasFocus) {
          _emailFocusNode.requestFocus();
        }
      });
    }
    if (isProfEditing && !_professionalEmailFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_professionalEmailFocusNode.hasFocus) {
          _professionalEmailFocusNode.requestFocus();
        }
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2030)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Card Toggles
          Row(
            children: [
              const Icon(Icons.email_outlined,
                  color: Color(0xFF8B5CF6), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Email Address',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildLocalCardToggle(
                icon: Icons.person_outline_rounded,
                isActive: assignment.casual,
                onTap: () =>
                    provider.toggleFieldOnCard('email', ProfileCardType.casual),
              ),
              const SizedBox(width: 8),
              _buildLocalCardToggle(
                icon: Icons.work_outline_rounded,
                isActive: assignment.professional,
                onTap: () => provider.toggleFieldOnCard(
                    'email', ProfileCardType.professional),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Casual Email Section Header
          Row(
            children: const [
              Icon(Icons.person_outline_rounded,
                  color: Color(0xFF8B5CF6), size: 16),
              SizedBox(width: 6),
              Text(
                'Casual Email',
                style: TextStyle(
                  color: Color(0xFF8B8C9E),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            readOnly: casualReadOnly,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            cursorColor: const Color(0xFF8B5CF6),
            decoration: InputDecoration(
              hintText: 'jordan@designstudio.com',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 14,
              ),
              suffixIcon: isCasualFilled
                  ? GestureDetector(
                      onTap: () {
                        if (isCasualEditing) {
                          _setEditMode('email', false);
                          _emailFocusNode.unfocus();
                        } else {
                          _setEditMode('email', true);
                        }
                      },
                      child: Icon(
                        isCasualEditing
                            ? Icons.check_circle_outline_rounded
                            : Icons.edit_rounded,
                        color: isCasualEditing
                            ? const Color(0xFF10B981)
                            : Colors.white24,
                        size: 18,
                      ),
                    )
                  : const Icon(
                      Icons.edit_rounded,
                      color: Colors.white24,
                      size: 16,
                    ),
              filled: true,
              fillColor: const Color(0xFF191A2A),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF8B5CF6),
                  width: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Professional Email Section Header
          Row(
            children: const [
              Icon(Icons.work_outline_rounded,
                  color: Color(0xFF8B5CF6), size: 16),
              SizedBox(width: 6),
              Text(
                'Professional Email',
                style: TextStyle(
                  color: Color(0xFF8B8C9E),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _professionalEmailController,
            focusNode: _professionalEmailFocusNode,
            readOnly: profReadOnly,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            cursorColor: const Color(0xFF8B5CF6),
            decoration: InputDecoration(
              hintText: 'jordan@company.com',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 14,
              ),
              suffixIcon: isProfFilled
                  ? GestureDetector(
                      onTap: () {
                        if (isProfEditing) {
                          _setEditMode('professionalEmail', false);
                          _professionalEmailFocusNode.unfocus();
                        } else {
                          _setEditMode('professionalEmail', true);
                        }
                      },
                      child: Icon(
                        isProfEditing
                            ? Icons.check_circle_outline_rounded
                            : Icons.edit_rounded,
                        color: isProfEditing
                            ? const Color(0xFF10B981)
                            : Colors.white24,
                        size: 18,
                      ),
                    )
                  : const Icon(
                      Icons.edit_rounded,
                      color: Colors.white24,
                      size: 16,
                    ),
              filled: true,
              fillColor: const Color(0xFF191A2A),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF8B5CF6),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneSection() {
    final provider = context.watch<ProfileProvider>();
    final assignment = provider.fieldAssignments['phoneNumber'] ??
        FieldCardAssignment(casual: true, professional: true);

    final isCasualEditing = _isEditing('phoneNumber');
    final isCasualFilled = _phoneController.text.isNotEmpty;
    final casualReadOnly = isCasualFilled && !isCasualEditing;

    final isProfEditing = _isEditing('professionalPhoneNumber');
    final isProfFilled = _professionalPhoneController.text.isNotEmpty;
    final profReadOnly = isProfFilled && !isProfEditing;

    // Autofocus when edit mode is toggled on
    if (isCasualEditing && !_phoneFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_phoneFocusNode.hasFocus) {
          _phoneFocusNode.requestFocus();
        }
      });
    }
    if (isProfEditing && !_professionalPhoneFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_professionalPhoneFocusNode.hasFocus) {
          _professionalPhoneFocusNode.requestFocus();
        }
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2030)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Card Toggles
          Row(
            children: [
              const Icon(Icons.phone_android_outlined,
                  color: Color(0xFF8B5CF6), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Phone Number',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildLocalCardToggle(
                icon: Icons.person_outline_rounded,
                isActive: assignment.casual,
                onTap: () => provider.toggleFieldOnCard(
                    'phoneNumber', ProfileCardType.casual),
              ),
              const SizedBox(width: 8),
              _buildLocalCardToggle(
                icon: Icons.work_outline_rounded,
                isActive: assignment.professional,
                onTap: () => provider.toggleFieldOnCard(
                    'phoneNumber', ProfileCardType.professional),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Casual Phone Number Section Header
          Row(
            children: const [
              Icon(Icons.person_outline_rounded,
                  color: Color(0xFF8B5CF6), size: 16),
              SizedBox(width: 6),
              Text(
                'Casual Phone Number',
                style: TextStyle(
                  color: Color(0xFF8B8C9E),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Selector calling code button
              GestureDetector(
                onTap: casualReadOnly
                    ? null
                    : () => _showCountryPicker(context, (val) {
                          if (val != null) {
                            setState(() => _casualCountryCode = val);
                          }
                        }),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF191A2A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_getFlagForCode(_casualCountryCode)} $_casualCountryCode',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  readOnly: casualReadOnly,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: const Color(0xFF8B5CF6),
                  decoration: InputDecoration(
                    hintText: '(555) 123-4567',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 14,
                    ),
                    suffixIcon: isCasualFilled
                        ? GestureDetector(
                            onTap: () {
                              if (isCasualEditing) {
                                _setEditMode('phoneNumber', false);
                                _phoneFocusNode.unfocus();
                              } else {
                                _setEditMode('phoneNumber', true);
                              }
                            },
                            child: Icon(
                              isCasualEditing
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.edit_rounded,
                              color: isCasualEditing
                                  ? const Color(0xFF10B981)
                                  : Colors.white24,
                              size: 18,
                            ),
                          )
                        : const Icon(
                            Icons.edit_rounded,
                            color: Colors.white24,
                            size: 16,
                          ),
                    filled: true,
                    fillColor: const Color(0xFF191A2A),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF8B5CF6),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Professional Phone Number Section Header
          Row(
            children: const [
              Icon(Icons.work_outline_rounded,
                  color: Color(0xFF8B5CF6), size: 16),
              SizedBox(width: 6),
              Text(
                'Professional Phone Number',
                style: TextStyle(
                  color: Color(0xFF8B8C9E),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Selector calling code button
              GestureDetector(
                onTap: profReadOnly
                    ? null
                    : () => _showCountryPicker(context, (val) {
                          if (val != null) {
                            setState(() => _professionalCountryCode = val);
                          }
                        }),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF191A2A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_getFlagForCode(_professionalCountryCode)} $_professionalCountryCode',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _professionalPhoneController,
                  focusNode: _professionalPhoneFocusNode,
                  readOnly: profReadOnly,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: const Color(0xFF8B5CF6),
                  decoration: InputDecoration(
                    hintText: '(555) 987-6543',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 14,
                    ),
                    suffixIcon: isProfFilled
                        ? GestureDetector(
                            onTap: () {
                              if (isProfEditing) {
                                _setEditMode('professionalPhoneNumber', false);
                                _professionalPhoneFocusNode.unfocus();
                              } else {
                                _setEditMode('professionalPhoneNumber', true);
                              }
                            },
                            child: Icon(
                              isProfEditing
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.edit_rounded,
                              color: isProfEditing
                                  ? const Color(0xFF10B981)
                                  : Colors.white24,
                              size: 18,
                            ),
                          )
                        : const Icon(
                            Icons.edit_rounded,
                            color: Colors.white24,
                            size: 16,
                          ),
                    filled: true,
                    fillColor: const Color(0xFF191A2A),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF8B5CF6),
                        width: 1,
                      ),
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

  Widget _buildBioSection() {
    final provider = context.watch<ProfileProvider>();
    final assignment = provider.fieldAssignments['bio'] ??
        FieldCardAssignment(casual: false, professional: true);

    final isBioEditing = _isEditing('bio');
    final isBioFilled = _bioController.text.isNotEmpty;
    final bioReadOnly = isBioFilled && !isBioEditing;

    final isProfBioEditing = _isEditing('professionalBio');
    final isProfBioFilled = _professionalBioController.text.isNotEmpty;
    final profBioReadOnly = isProfBioFilled && !isProfBioEditing;

    // Autofocus when edit mode is toggled on
    if (isBioEditing && !_bioFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_bioFocusNode.hasFocus) {
          _bioFocusNode.requestFocus();
        }
      });
    }

    if (isProfBioEditing && !_professionalBioFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_professionalBioFocusNode.hasFocus) {
          _professionalBioFocusNode.requestFocus();
        }
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2030)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined,
                  color: Color(0xFF8B5CF6), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Bio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildLocalCardToggle(
                icon: Icons.person_outline_rounded,
                isActive: assignment.casual,
                onTap: () =>
                    provider.toggleFieldOnCard('bio', ProfileCardType.casual),
              ),
              const SizedBox(width: 8),
              _buildLocalCardToggle(
                icon: Icons.work_outline_rounded,
                isActive: assignment.professional,
                onTap: () => provider.toggleFieldOnCard(
                    'bio', ProfileCardType.professional),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Casual Card Bio
          Row(
            children: const [
              Icon(Icons.person_outline_rounded,
                  color: Color(0xFF8B5CF6), size: 16),
              SizedBox(width: 6),
              Text(
                'Casual Card Bio',
                style: TextStyle(
                  color: Color(0xFF8B8C9E),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _bioController,
            focusNode: _bioFocusNode,
            readOnly: bioReadOnly,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            cursorColor: const Color(0xFF8B5CF6),
            decoration: InputDecoration(
              hintText:
                  'Creating delightful user experiences through thoughtful design and innovation.',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 14,
              ),
              suffixIcon: isBioFilled
                  ? GestureDetector(
                      onTap: () {
                        if (isBioEditing) {
                          _setEditMode('bio', false);
                          _bioFocusNode.unfocus();
                        } else {
                          _setEditMode('bio', true);
                        }
                      },
                      child: Icon(
                        isBioEditing
                            ? Icons.check_circle_outline_rounded
                            : Icons.edit_rounded,
                        color: isBioEditing
                            ? const Color(0xFF10B981)
                            : Colors.white24,
                        size: 18,
                      ),
                    )
                  : const Icon(
                      Icons.edit_rounded,
                      color: Colors.white24,
                      size: 16,
                    ),
              filled: true,
              fillColor: const Color(0xFF191A2A),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF8B5CF6),
                  width: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Professional Card Bio
          Row(
            children: const [
              Icon(Icons.work_outline_rounded,
                  color: Color(0xFF8B5CF6), size: 16),
              SizedBox(width: 6),
              Text(
                'Professional Card Bio',
                style: TextStyle(
                  color: Color(0xFF8B8C9E),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _professionalBioController,
            focusNode: _professionalBioFocusNode,
            readOnly: profBioReadOnly,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            cursorColor: const Color(0xFF8B5CF6),
            decoration: InputDecoration(
              hintText:
                  'Senior Product Designer with 8+ years of experience crafting intuitive digital solutions.',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 14,
              ),
              suffixIcon: isProfBioFilled
                  ? GestureDetector(
                      onTap: () {
                        if (isProfBioEditing) {
                          _setEditMode('professionalBio', false);
                          _professionalBioFocusNode.unfocus();
                        } else {
                          _setEditMode('professionalBio', true);
                        }
                      },
                      child: Icon(
                        isProfBioEditing
                            ? Icons.check_circle_outline_rounded
                            : Icons.edit_rounded,
                        color: isProfBioEditing
                            ? const Color(0xFF10B981)
                            : Colors.white24,
                        size: 18,
                      ),
                    )
                  : const Icon(
                      Icons.edit_rounded,
                      color: Colors.white24,
                      size: 16,
                    ),
              filled: true,
              fillColor: const Color(0xFF191A2A),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF8B5CF6),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonHeader() {
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
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
          ),
          Column(
            children: [
              Text(
                'My Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Digital Card',
                style: TextStyle(
                  color: Color(0xFF8B8C9E),
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'YOUR CARDS',
              style: TextStyle(
                color: Color(0xFF8B8C9E),
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            Container(width: 80, height: 24, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white10)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Container(height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white10))),
            const SizedBox(width: 12),
            Expanded(child: Container(height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white10))),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: const Color(0xFF131422),
          ),
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Jane Doe", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text("Software Engineer", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  SizedBox(height: 6),
                  Text("Tech Corp", style: TextStyle(color: Colors.white30, fontSize: 11)),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonEditorForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EDIT DETAILS',
          style: TextStyle(
            color: Color(0xFF8B8C9E),
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < 4; i++)
          Container(
            height: 56,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF13141F),
            ),
          ),
      ],
    );
  }

  Widget _buildSkeletonSocialLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (int i = 0; i < 3; i++)
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF13141F)),
          ),
      ],
    );
  }

  Widget _buildSkeletonSaveButton() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF8B5CF6),
      ),
    );
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
    // Dubai
    CountryInfo(
        name: 'United Arab Emirates',
        code: '+971',
        flag: '🇦🇪',
        region: 'Dubai'),
    // America
    CountryInfo(
        name: 'United States', code: '+1', flag: '🇺🇸', region: 'America'),
    CountryInfo(name: 'Canada', code: '+1', flag: '🇨🇦', region: 'America'),
    CountryInfo(name: 'Brazil', code: '+55', flag: '🇧🇷', region: 'America'),
    CountryInfo(name: 'Mexico', code: '+52', flag: '🇲🇽', region: 'America'),
    // Europe
    CountryInfo(
        name: 'United Kingdom', code: '+44', flag: '🇬🇧', region: 'Europe'),
    CountryInfo(name: 'Germany', code: '+49', flag: '🇩🇪', region: 'Europe'),
    CountryInfo(name: 'France', code: '+33', flag: '🇫🇷', region: 'Europe'),
    CountryInfo(name: 'Italy', code: '+39', flag: '🇮🇹', region: 'Europe'),
    CountryInfo(name: 'Spain', code: '+34', flag: '🇪🇸', region: 'Europe'),
    CountryInfo(
        name: 'Netherlands', code: '+31', flag: '🇳🇱', region: 'Europe'),
    // Asia
    CountryInfo(name: 'India', code: '+91', flag: '🇮🇳', region: 'Asia'),
    CountryInfo(name: 'China', code: '+86', flag: '🇨🇳', region: 'Asia'),
    CountryInfo(name: 'Singapore', code: '+65', flag: '🇸🇬', region: 'Asia'),
    CountryInfo(name: 'Japan', code: '+81', flag: '🇯🇵', region: 'Asia'),
    CountryInfo(name: 'South Korea', code: '+82', flag: '🇰🇷', region: 'Asia'),
    CountryInfo(
        name: 'Saudi Arabia', code: '+966', flag: '🇸🇦', region: 'Asia'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter countries based on query
    final query = _searchQuery.toLowerCase().trim();
    final filtered = _allCountries.where((country) {
      return country.name.toLowerCase().contains(query) ||
          country.code.contains(query) ||
          country.region.toLowerCase().contains(query);
    }).toList();

    // Group filtered countries by region
    final Map<String, List<CountryInfo>> grouped = {};
    for (var c in filtered) {
      if (!grouped.containsKey(c.region)) {
        grouped[c.region] = [];
      }
      grouped[c.region]!.add(c);
    }

    // Keep regional ordering: Dubai, America, Europe, Asia
    final orderedRegions = ['Dubai', 'America', 'Europe', 'Asia']
        .where((r) => grouped.containsKey(r))
        .toList();
    // Add any dynamic regions if somehow created
    for (var r in grouped.keys) {
      if (!orderedRegions.contains(r)) {
        orderedRegions.add(r);
      }
    }

    final double bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: const Color(0xFF13141F),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
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
            // Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Select Country',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                style: const TextStyle(color: Colors.white, fontSize: 15),
                cursorColor: const Color(0xFF8B5CF6),
                decoration: InputDecoration(
                  hintText: 'Search country or code...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.4),
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
                  fillColor: const Color(0xFF191A2A),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF8B5CF6),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Countries List
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No countries found',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontFamily: 'Inter',
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
                                style: const TextStyle(
                                  color: Color(0xFF8B5CF6),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            ...countries.map((country) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  splashColor: const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.1),
                                  highlightColor: const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.05),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  leading: Text(
                                    country.flag,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  title: Text(
                                    country.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: Text(
                                    country.code,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Inter',
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
