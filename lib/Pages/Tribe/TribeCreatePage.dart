import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/tribe_provider.dart';
import 'package:connect/Pages/Tribe/TribeChatPage.dart';
import 'package:connect/services/image_upload_service.dart';
import 'package:connect/Pages/crop_image_page.dart';
import 'package:connect/services/analytics_service.dart';
import 'package:uuid/uuid.dart';

class TribeCreatePage extends StatefulWidget {
  const TribeCreatePage({super.key});

  @override
  State<TribeCreatePage> createState() => _TribeCreatePageState();
}

class _TribeCreatePageState extends State<TribeCreatePage> {
  final _nameController = TextEditingController();
  late final String _tribeId;
  
  String? _uploadedAvatarUrl;
  bool _isUploadingImage = false;
  String _visibility = 'private';
  bool _requiresApproval = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tribeId = const Uuid().v4();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadTribeImage() async {
    if (_isUploadingImage) return;

    final picker = ImagePicker();
    try {
      final XFile? imageFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (imageFile == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      final bytes = await imageFile.readAsBytes();

      if (!mounted) return;

      final Uint8List? croppedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => CropImagePage(imageBytes: bytes),
        ),
      );

      if (croppedBytes == null) {
        setState(() {
          _isUploadingImage = false;
        });
        return;
      }

      final compressedBytes = await ImageUploadService.compressImageTo10Kb(croppedBytes);

      final String publicUrl = await ImageUploadService.uploadTribeAvatarImage(
        _tribeId,
        compressedBytes,
      );

      if (mounted) {
        setState(() {
          _uploadedAvatarUrl = publicUrl;
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mafia image uploaded successfully!")),
        );
      }
    } catch (e) {
      print("Error uploading tribe image: $e");
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not upload image. Please try again.")),
        );
      }
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mafia name cannot be empty.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final provider = Provider.of<TribeProvider>(context, listen: false);

    try {
      final result = await provider.createTribe(
        name: name,
        description: "",
        visibility: _visibility,
        requiresApproval: _requiresApproval,
        maxMembers: null,
        avatarUrl: _uploadedAvatarUrl ?? "",
        id: _tribeId,
      );

      if (mounted && result != null) {
        AnalyticsService.logEvent(
          name: 'tribe_created',
          parameters: {
            'tribe_id': result['id']?.toString() ?? '',
            'visibility': _visibility,
            'requires_approval': _requiresApproval ? 1 : 0,
          },
        );
        Navigator.pop(context); // Pop creation screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TribeChatPage(
              tribeId: result['id'] as String,
              tribeName: result['name'] as String,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not create Mafia. Please check your entries and try again.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.canvasBackground,
      appBar: AppBar(
        title: Text("Create Mafia", style: context.screenHeading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const GlassmorphicFlexibleSpace(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickAndUploadTribeImage,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: context.surfaceSecondary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.accentSecondary,
                                width: 1.5,
                              ),
                              image: _uploadedAvatarUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_uploadedAvatarUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            alignment: Alignment.center,
                             child: _uploadedAvatarUrl == null
                                 ? const Icon(Icons.group_rounded, size: 36, color: Colors.white70)
                                 : null,
                          ),
                          if (_isUploadingImage)
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: context.accentSecondary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: context.canvasBackground, width: 2),
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
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      "Upload Mafia Logo",
                      style: context.captionText.copyWith(
                        color: context.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _nameController,
                    style: context.bodyText.copyWith(color: context.textPrimary),
                    decoration: InputDecoration(
                      labelText: "Mafia Name *",
                      labelStyle: TextStyle(color: context.textSecondary, fontSize: 13),
                      hintText: "Enter mafia name",
                      hintStyle: TextStyle(color: context.textMuted, fontSize: 13),
                      fillColor: context.surfaceSecondary,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.borderMuted),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.borderMuted),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.accentSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Requires Approval to Join", style: context.bodyText.copyWith(color: context.textPrimary)),
                    subtitle: Text("Elders must approve join requests", style: context.captionText.copyWith(color: context.textMuted)),
                    value: _requiresApproval,
                    activeColor: context.accentSecondary,
                    onChanged: (val) {
                      setState(() {
                        _requiresApproval = val;
                      });
                    },
                  ),
                  const SizedBox(height: 36),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accentSecondary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Create Mafia", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }
}
