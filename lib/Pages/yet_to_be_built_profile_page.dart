import 'package:connect/Models/profile_card_type.dart';
import 'package:connect/Providers/ProviderSQL.dart';
import 'package:connect/Widgets/card_field_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:connect/Pages/crop_image_page.dart';

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
  static const String _defaultAvatarUrl =
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80';
  String _avatarUrl = _defaultAvatarUrl;

  late TextEditingController _nameController;
  late TextEditingController _professionController;
  late TextEditingController _companyController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _professionalBioController;
  late FocusNode _bioFocusNode;
  late FocusNode _professionalBioFocusNode;
  bool _showProfileToConnections = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _professionController = TextEditingController();
    _companyController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _bioController = TextEditingController();
    _professionalBioController = TextEditingController();
    _bioFocusNode = FocusNode();
    _professionalBioFocusNode = FocusNode();

    // Setup real-time card preview listeners
    _nameController.addListener(_onFieldChanged);
    _professionController.addListener(_onFieldChanged);
    _companyController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _professionalBioController.addListener(_onFieldChanged);

    _bioFocusNode.addListener(() {
      if (!_bioFocusNode.hasFocus) {
        final provider = Provider.of<ProfileProvider2>(context, listen: false);
        if (provider.editMode['bio'] == true) {
          provider.setEditMode('bio', false);
        }
      }
    });

    _professionalBioFocusNode.addListener(() {
      if (!_professionalBioFocusNode.hasFocus) {
        final provider = Provider.of<ProfileProvider2>(context, listen: false);
        if (provider.editMode['professionalBio'] == true) {
          provider.setEditMode('professionalBio', false);
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
    _phoneController.removeListener(_onFieldChanged);
    _bioController.removeListener(_onFieldChanged);
    _professionalBioController.removeListener(_onFieldChanged);

    _nameController.dispose();
    _professionController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _professionalBioController.dispose();
    _bioFocusNode.dispose();
    _professionalBioFocusNode.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _isDataChanged() {
    if (!mounted) return false;
    final provider = Provider.of<ProfileProvider2>(context, listen: false);
    return _nameController.text.trim() != provider.name ||
        _professionController.text.trim() != provider.profession ||
        _companyController.text.trim() != provider.company ||
        _emailController.text.trim() != provider.email ||
        _phoneController.text.trim() != provider.phoneNumber ||
        _bioController.text.trim() != provider.bio ||
        _professionalBioController.text.trim() != provider.professionalBio ||
        _avatarUrl != provider.avatarUrl;
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final provider = Provider.of<ProfileProvider2>(context, listen: false);
    try {
      final userid = await provider.fetchAndSetUserId2(true);
      if (userid != -1) {
        final userData = await provider.loadProfile(userid);
        if (userData.isNotEmpty) {
          provider.setUserData(userData);
          _nameController.text = provider.name;
          _professionController.text = provider.profession;
          _companyController.text = provider.company;
          _emailController.text = provider.email;
          _phoneController.text = provider.phoneNumber;
          _bioController.text = provider.bio;
          _professionalBioController.text = provider.professionalBio;
          _showProfileToConnections = provider.showProfileToConnections;
          _avatarUrl = provider.avatarUrl.isNotEmpty
              ? provider.avatarUrl
              : _defaultAvatarUrl;
        }
      } else {
        // Use default placeholders
        _nameController.text = provider.name;
        _professionController.text = provider.profession;
        _companyController.text = provider.company;
        _emailController.text = provider.email;
        _phoneController.text = provider.phoneNumber;
        _bioController.text = provider.bio;
        _professionalBioController.text = provider.professionalBio;
        _showProfileToConnections = provider.showProfileToConnections;
        _avatarUrl = provider.avatarUrl.isNotEmpty
            ? provider.avatarUrl
            : _defaultAvatarUrl;
        await provider.loadFieldAssignments();
      }
    } catch (e) {
      print("Error loading initial data in profile tab: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final provider = Provider.of<ProfileProvider2>(context, listen: false);
    try {
      provider.setValue('name', _nameController.text.trim());
      provider.setValue('profession', _professionController.text.trim());
      provider.setValue('company', _companyController.text.trim());
      provider.setValue('email', _emailController.text.trim());
      provider.setValue('phoneNumber', _phoneController.text.trim());
      provider.setValue('bio', _bioController.text.trim());
      provider.setValue(
          'professionalBio', _professionalBioController.text.trim());
      provider.setValue('avatarUrl', _avatarUrl);
      provider.setShowProfileToConnections(_showProfileToConnections);

      await provider.saveOrUpdateProfile();
      await provider.saveFieldAssignments();

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

  Future<Uint8List> _compressImageTo10Kb(Uint8List originalBytes) async {
    if (originalBytes.length <= 10 * 1024) {
      return originalBytes;
    }

    final image = img.decodeImage(originalBytes);
    if (image == null) return originalBytes;

    int width = 150;
    int height = (image.height * (width / image.width)).round();
    img.Image resized = img.copyResize(image, width: width, height: height);

    int quality = 80;
    Uint8List compressedBytes;
    do {
      compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      if (compressedBytes.length <= 10 * 1024 || quality <= 10) {
        break;
      }
      quality -= 15;
      if (quality < 10) quality = 10;
    } while (compressedBytes.length > 10 * 1024);

    if (compressedBytes.length > 10 * 1024) {
      resized = img.copyResize(image, width: 80, height: 80);
      compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 15));
    }

    return compressedBytes;
  }

  Future<void> _pickAndUploadImage({
    required StateSetter setModalState,
    required Function(String) onUploadSuccess,
    required Function(String) onUploadError,
  }) async {
    final provider = Provider.of<ProfileProvider2>(context, listen: false);
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

      final compressedBytes = await _compressImageTo10Kb(croppedBytes);

      try {
        await Supabase.instance.client.storage.createBucket('avatars', const BucketOptions(public: true));
      } catch (_) {
        // Safe to ignore if bucket already exists
      }

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String folderName = provider.userId != -1 ? '${provider.userId}' : 'temp_user';
      final String fileName = '$folderName/avatar_$timestamp.jpg';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            compressedBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final String publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

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
                          backgroundImage: NetworkImage(_avatarUrl),
                          backgroundColor: const Color(0xFF1B1C2A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    if (isUploading) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
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
                              }
                              Navigator.pop(context); // Auto-dismiss sheet on success
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    "Profile photo updated and saved to storage!",
                                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
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
                        icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 18),
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
                    
                    if (uploadError != null && uploadError != "No image picked") ...[
                      const SizedBox(height: 16),
                      Text(
                        "Upload Error: $uploadError\nMake sure storage bucket 'avatars' is created and RLS is public in Supabase.",
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontFamily: 'Inter'),
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
      return const Scaffold(
        backgroundColor: Color(0xFF090A0F),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
          ),
        ),
      );
    }

    // Rebuild card preview when Casual/Professional field toggles change.
    context.watch<ProfileProvider2>();

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

                    // Premium Glowing Gradient Border Business Card
                    _buildDigitalCard(),
                    const SizedBox(height: 32),

                    // EDIT DETAILS Header
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EDIT DETAILS',
                          style: TextStyle(
                            color: Color(0xFF8B8C9E),
                            fontSize: 14.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _previewCard == ProfileCardType.casual
                              ? 'Casual Card'
                              : 'Professional Card',
                          style: const TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Editor Container
                    _buildEditorForm(),
                    const SizedBox(height: 32),

                    _buildSocialLinksSection(),
                    const SizedBox(height: 32),

                    _buildSaveButton(),
                    const SizedBox(height: 32),

                    _buildPrivacySection(),
                    const SizedBox(height: 24),
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
    final provider = Provider.of<ProfileProvider2>(context);

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
    final provider = context.watch<ProfileProvider2>();
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
    final provider = Provider.of<ProfileProvider2>(context, listen: false);
    try {
      if (provider.userId != -1) {
        await provider.updateProfileField(field, value, provider.userId);
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
              'Save Profile Details',
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

  Widget _buildPrivacySection() {
    final provider = Provider.of<ProfileProvider2>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.security_rounded, color: Color(0xFF8B5CF6), size: 18),
            SizedBox(width: 8),
            Text(
              'PRIVACY',
              style: TextStyle(
                color: Color(0xFF8B8C9E),
                fontSize: 14.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF13141F),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: const Color(0xFF1F2030),
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1D2A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.visibility_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Show Profile to Connections",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Your card is visible to your circle",
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 12.0,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _showProfileToConnections,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF8B5CF6),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.white12,
                onChanged: (val) async {
                  setState(() {
                    _showProfileToConnections = val;
                  });
                  await provider.setShowProfileToConnections(val);
                },
              ),
            ],
          ),
        ),
      ],
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
    final provider = Provider.of<ProfileProvider2>(context);
    return provider.isFieldOnCard(field, _previewCard);
  }

  Widget _buildHeader(BuildContext context) {
    final provider = Provider.of<ProfileProvider2>(context, listen: false);
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
                'Digital Business Card',
                style: TextStyle(
                  color: Color(0xFF8B8C9E),
                  fontSize: 11.0,
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
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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
                    .withValues(alpha: 0.1),
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
                            .withValues(alpha: 0.06),
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
        _previewCard == ProfileCardType.casual ? 0.82 : 1.58,
        cardWidth,
        const ValueKey('FrontCard'),
      );
    } else {
      return _wrapCardFace(
        _buildUnifiedBackCard(cardWidth),
        _previewCard == ProfileCardType.casual ? 0.82 : 1.58,
        cardWidth,
        const ValueKey('BackCard'),
      );
    }
  }

  Widget _buildUnifiedFrontCard(double cardWidth) {
    final isCasual = _previewCard == ProfileCardType.casual;
    final W = cardWidth;

    return Stack(
      children: [
        // 1. Top Section: Logo, Company Name, Card Type
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
                        .withValues(alpha: isCasual ? 0.35 : 0.3),
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
                  _companyController.text.trim().isEmpty
                      ? 'CONNECT'
                      : _companyController.text.trim().toUpperCase(),
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
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.8),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontFamily: 'Inter',
                  ),
                ),
                secondChild: Text(
                  'DIGITAL IDENTITY',
                  style: TextStyle(
                    color: const Color(0xFF00F2FE).withValues(alpha: 0.8),
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

        // 2. Name and Profession
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
              if (_fieldVisible('name'))
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
                color: Colors.white.withValues(alpha: 0.08),
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

    return Stack(
      children: [
        // 1. Row 1: Avatar, Name, Profession, Link Button
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: isCasual ? 20 : 16,
          right: isCasual ? 20 : 16,
          top: isCasual ? 16 : 12,
          height: isCasual ? 60 : 40,
          child: Row(
            children: [
              if (_fieldVisible('avatarUrl'))
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
                      _avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.person_rounded,
                        color: Colors.white60,
                        size: isCasual ? 28 : 18,
                      ),
                    ),
                  ),
                ),
              if (_fieldVisible('avatarUrl'))
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
                    if (_fieldVisible('name'))
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
                          style: TextStyle(
                            color: const Color(0xFF8B5CF6),
                            fontSize: isCasual ? 13 : 10,
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
                padding: EdgeInsets.all(isCasual ? 8 : 6),
                decoration: BoxDecoration(
                  color: isCasual
                      ? const Color(0xFF171825)
                      : const Color(0xFF1E1F32),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Icon(
                  Icons.link_rounded,
                  color: const Color(0xFF00F2FE),
                  size: isCasual ? 16 : 14,
                ),
              ),
            ],
          ),
        ),

        // 2. Divider Line
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: isCasual ? 20 : 16,
          right: isCasual ? 20 : 16,
          top: isCasual ? 206 : 60,
          height: 1,
          child: Container(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),

        // 3. Contact Details Group (Company, Email, Phone)
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: isCasual ? 20 : (W * 0.5) + 6,
          right: isCasual ? 20 : 16,
          top: isCasual ? 86 : 74,
          height: isCasual ? 120 : 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isCasual ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (_fieldVisible('company')) ...[
                _buildUnifiedCardRow(
                  Icons.apartment_rounded,
                  _companyController.text.trim().isEmpty
                      ? 'Design Studio Inc.'
                      : _companyController.text.trim(),
                  isCasual,
                ),
                AnimatedContainer(
                  duration: _cardAnimDuration,
                  curve: _cardAnimCurve,
                  height: isCasual ? 12 : 5,
                ),
              ],
              if (_fieldVisible('email')) ...[
                _buildUnifiedCardRow(
                  Icons.email_outlined,
                  _emailController.text.trim().isEmpty
                      ? 'jordan@designstudio.com'
                      : _emailController.text.trim(),
                  isCasual,
                ),
                AnimatedContainer(
                  duration: _cardAnimDuration,
                  curve: _cardAnimCurve,
                  height: isCasual ? 12 : 5,
                ),
              ],
              if (_fieldVisible('phoneNumber'))
                _buildUnifiedCardRow(
                  Icons.phone_rounded,
                  _phoneController.text.trim().isEmpty
                      ? '+1 (555) 123-4567'
                      : _phoneController.text.trim(),
                  isCasual,
                ),
            ],
          ),
        ),

        // 4. Bio Section
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: isCasual ? 20 : 16,
          right: isCasual ? 20 : (W * 0.5) + 6,
          top: isCasual ? 220 : 74,
          height: isCasual ? 70 : 60,
          child: _fieldVisible('bio')
              ? AnimatedCrossFade(
                  duration: _cardAnimDuration,
                  firstCurve: _cardAnimCurve,
                  secondCurve: _cardAnimCurve,
                  crossFadeState: isCasual
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Text(
                    _bioController.text.trim().isEmpty
                        ? 'Creating delightful user experiences through thoughtful design and innovation.'
                        : _bioController.text.trim(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: isCasual ? 12 : 9,
                      height: isCasual ? 1.4 : 1.25,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondChild: Text(
                    _professionalBioController.text.trim().isEmpty
                        ? 'Senior Product Designer with 8+ years of experience crafting intuitive digital solutions.'
                        : _professionalBioController.text.trim(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 9,
                      height: 1.25,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // 5. Bottom Accent Line
        AnimatedPositioned(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          left: isCasual ? 20 : 16,
          right: isCasual ? 20 : W - 76,
          top: isCasual ? H - 19 : 140,
          height: isCasual ? 3 : 2,
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
          width: isCasual ? 32 : 18,
          height: isCasual ? 32 : 18,
          decoration: const BoxDecoration(
            color: Color(0xFF171825),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              color: isCasual ? const Color(0xFF8B8C9E) : Colors.white54,
              size: isCasual ? 14 : 10,
            ),
          ),
        ),
        AnimatedContainer(
          duration: _cardAnimDuration,
          curve: _cardAnimCurve,
          width: isCasual ? 12 : 6,
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
                fontSize: isCasual ? 13 : 9,
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
    final provider = context.watch<ProfileProvider2>();
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
                  child: Image.network(
                    _avatarUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: const Color(0xFF1B1C2A),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: Colors.white60,
                        size: 36,
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
        ),
        CardFieldInput(
          fieldKey: 'profession',
          label: 'Profession',
          hint: 'Product Designer',
          icon: Icons.work_outline_rounded,
          controller: _professionController,
        ),
        CardFieldInput(
          fieldKey: 'company',
          label: 'Company',
          hint: 'Design Studio Inc.',
          icon: Icons.apartment_rounded,
          controller: _companyController,
        ),
        CardFieldInput(
          fieldKey: 'email',
          label: 'Email Address',
          hint: 'jordan@designstudio.com',
          icon: Icons.email_outlined,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        CardFieldInput(
          fieldKey: 'phoneNumber',
          label: 'Phone Number',
          hint: '+1 (555) 123-4567',
          icon: Icons.phone_android_outlined,
          controller: _phoneController,
          keyboardType: TextInputType.phone,
        ),
        _buildBioSection(),
      ],
    );
  }

  Widget _buildBioSection() {
    final provider = context.watch<ProfileProvider2>();
    final assignment = provider.fieldAssignments['bio'] ??
        FieldCardAssignment(casual: false, professional: true);

    final isBioEditing = provider.editMode['bio'] ?? false;
    final isBioFilled = _bioController.text.isNotEmpty;
    final bioReadOnly = isBioFilled && !isBioEditing;

    final isProfBioEditing = provider.editMode['professionalBio'] ?? false;
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
                          provider.setEditMode('bio', false);
                          _bioFocusNode.unfocus();
                        } else {
                          provider.setEditMode('bio', true);
                        }
                      },
                      child: Icon(
                        isBioEditing ? Icons.check_circle_outline_rounded : Icons.edit_rounded,
                        color: isBioEditing ? const Color(0xFF10B981) : Colors.white24,
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
                          provider.setEditMode('professionalBio', false);
                          _professionalBioFocusNode.unfocus();
                        } else {
                          provider.setEditMode('professionalBio', true);
                        }
                      },
                      child: Icon(
                        isProfBioEditing ? Icons.check_circle_outline_rounded : Icons.edit_rounded,
                        color: isProfBioEditing ? const Color(0xFF10B981) : Colors.white24,
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
