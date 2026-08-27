import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connect/services/image_upload_service.dart';
import 'package:connect/Pages/crop_image_page.dart';
import 'package:provider/provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/tribe_provider.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/Pages/Tribe/TribeRoleBuilderPage.dart';
import 'package:connect/Models/mafia_role_details.dart';
import 'package:connect/services/analytics_service.dart';

class TribeDetailsPage extends StatefulWidget {
  final String tribeId;

  const TribeDetailsPage({
    super.key,
    required this.tribeId,
  });

  @override
  State<TribeDetailsPage> createState() => _TribeDetailsPageState();
}

class _TribeDetailsPageState extends State<TribeDetailsPage> {
  bool _isLoading = false;
  bool _isEditing = false;
  final _nameController = TextEditingController();
  String? _uploadedAvatarUrl;
  bool _isUploadingImage = false;
  bool _requiresApproval = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
    });
    final provider = Provider.of<TribeProvider>(context, listen: false);
    await provider.fetchTribeDetails(widget.tribeId);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  QrImage? _generateQrImage(String data) {
    try {
      final qrCode = QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.H,
      );
      return QrImage(qrCode);
    } catch (e) {
      print("Error generating QR Image: $e");
      return null;
    }
  }

  Future<void> _pickAndUploadImage() async {
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
      final compressedBytes =
          await ImageUploadService.compressImageTo10Kb(croppedBytes);
      final String publicUrl = await ImageUploadService.uploadTribeAvatarImage(
        widget.tribeId,
        compressedBytes,
      );
      setState(() {
        _uploadedAvatarUrl = publicUrl;
        _isUploadingImage = false;
      });
    } catch (e) {
      print("Error uploading tribe image: $e");
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Future<bool> _showInviteRoleSelectionDialog(
      BuildContext context, Map<String, dynamic> connection) async {
    final tribeProvider = Provider.of<TribeProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final roles = tribeProvider.getRoles(widget.tribeId);
    final name = connection['name'] ?? 'this member';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isAdding = false;
        String selectedRoleTitle = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PopScope(
              canPop: !isAdding,
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: GlassmorphicContainer(
                  borderRadius: BorderRadius.circular(24),
                  padding: const EdgeInsets.all(24),
                  child: isAdding
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12),
                            const SizedBox(
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(
                                strokeWidth: 3.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Adding to Mafia...",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Assigning $name the $selectedRoleTitle role...",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Select Role for $name",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                                "Choose which role this user will be assigned.",
                                style: TextStyle(
                                    color: context.textSecondary, fontSize: 12)),
                            const SizedBox(height: 16),
                            Flexible(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.5,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: roles.length,
                                  itemBuilder: (context, index) {
                                    final role = roles[index];
                                    final roleColorStr =
                                        role['color']?.toString() ?? '#FFFFFF';
                                    final roleColor = Color(int.parse(
                                        roleColorStr.replaceAll('#', '0xFF')));
                                    final slug = role['slug']?.toString() ?? '';
                                    final roleDetails =
                                        MafiaRoleDetails.getForSlug(slug);
                                    final displayTitle = role['name']?.toString() ??
                                        roleDetails.title;

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: BounceTap(
                                        onTap: isAdding
                                            ? null
                                            : () async {
                                                setDialogState(() {
                                                  isAdding = true;
                                                  selectedRoleTitle =
                                                      displayTitle;
                                                });
                                                try {
                                                  await tribeProvider.addMember(
                                                      widget.tribeId,
                                                      connection['id'] as int,
                                                      role['id'] as String);
                                                  AnalyticsService.logEvent(
                                                    name: 'tribe_invite_sent',
                                                    parameters: {
                                                      'tribe_id': widget.tribeId,
                                                      'invitee_id': connection['id'] as int,
                                                      'role_slug': slug,
                                                    },
                                                  );

                                                  if (dialogContext.mounted) {
                                                    Navigator.of(dialogContext).pop(true);
                                                  }
                                                } catch (e) {
                                                  print("Error adding member: $e");
                                                  if (dialogContext.mounted) {
                                                    setDialogState(() {
                                                      isAdding = false;
                                                    });
                                                  }
                                                  scaffoldMessenger.showSnackBar(
                                                    SnackBar(
                                                        content: Text(e
                                                            .toString()
                                                            .replaceAll(
                                                                "Exception: ",
                                                                "")),
                                                        backgroundColor:
                                                            Colors.redAccent),
                                                  );
                                                }
                                              },
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: context.surfaceSecondary,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: roleColor.withValues(alpha: 0.25),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: roleColor.withValues(alpha: 0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(roleDetails.icon,
                                                    style: const TextStyle(fontSize: 18)),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(displayTitle,
                                                        style: TextStyle(
                                                            color: roleColor,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14)),
                                                    if (roleDetails.uxProfile.isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Text(roleDetails.uxProfile,
                                                          style: TextStyle(
                                                              color: context.textSecondary,
                                                              fontSize: 11)),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              Icon(Icons.chevron_right_rounded,
                                                  color: context.textMuted, size: 20),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                child: const Text("Cancel",
                                    style: TextStyle(color: Colors.white70)),
                                onPressed: isAdding
                                    ? null
                                    : () => Navigator.pop(dialogContext, false),
                              ),
                            )
                          ],
                        ),
                ),
              ),
            );
          },
        );
      },
    );

    return result ?? false;
  }

  void _showInviteUserSheet(BuildContext context) {
    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    final tribeProvider = Provider.of<TribeProvider>(context, listen: false);
    final myConnections = connectionProvider.connections;

    // Filter connections: only exclude members who are currently active
    final existingMemberIds = tribeProvider
        .getMembers(widget.tribeId)
        .where((m) => m['status'] == 'active')
        .map((m) => m['user_id'] as int)
        .toSet();

    final inviteable = myConnections
        .where((c) => !existingMemberIds.contains(c['id']))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return GlassmorphicContainer(
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Add Connection",
                  style: context.screenHeading
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: inviteable.isEmpty
                    ? Center(
                        child: Text("No connections to add",
                            style: TextStyle(color: context.textMuted)))
                    : ListView.builder(
                        itemCount: inviteable.length,
                        itemBuilder: (context, index) {
                          final conn = inviteable[index];
                          final name = conn['name'] ?? 'Unknown';
                          final avatarUrl = conn['avatarUrl']?.toString() ??
                              conn['avatar_url']?.toString() ??
                              '';
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: context.surfaceSecondary,
                                backgroundImage: avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl.isEmpty
                                    ? Text(
                                        name.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                            color: context.textPrimary),
                                      )
                                    : null,
                              ),
                              title: Text(name,
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text(conn['profession'] ?? '',
                                  style: TextStyle(color: context.textMuted)),
                              trailing: TextButton(
                                child: const Text("Add",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  final success =
                                      await _showInviteRoleSelectionDialog(
                                          sheetContext, conn);
                                  if (success && sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "$name added to Mafia successfully!"),
                                            backgroundColor: Colors.green),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRequestsSheet(BuildContext context) {
    final tribeProvider = Provider.of<TribeProvider>(context, listen: false);
    final requestedMembers = tribeProvider
        .getMembers(widget.tribeId)
        .where((m) => m['status'] == 'requested')
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassmorphicContainer(
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Join Requests",
                  style: context.screenHeading
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: requestedMembers.isEmpty
                    ? Center(
                        child: Text("No pending join requests",
                            style: TextStyle(color: context.textMuted)))
                    : ListView.builder(
                        itemCount: requestedMembers.length,
                        itemBuilder: (context, index) {
                          final mem = requestedMembers[index];
                          final profile =
                              mem['profile'] as Map<String, dynamic>? ?? {};
                          final name = profile['name'] ?? 'Someone';
                          final profileAvatar =
                              profile['avatar_url']?.toString() ??
                                  profile['avatarUrl']?.toString() ??
                                  '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: context.surfaceSecondary,
                              backgroundImage: profileAvatar.isNotEmpty
                                  ? NetworkImage(profileAvatar)
                                  : null,
                              child: profileAvatar.isEmpty
                                  ? Text(name.substring(0, 1).toUpperCase())
                                  : null,
                            ),
                            title: Text(name,
                                style: const TextStyle(color: Colors.white)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle_rounded,
                                      color: Colors.green),
                                  onPressed: () async {
                                    final nav = Navigator.of(context);
                                    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
                                    try {
                                      await tribeProvider.approveRequest(
                                          widget.tribeId,
                                          mem['user_id'] as int);
                                      await notifProvider.fetchNotifications();
                                      nav.pop();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text("Request Approved"),
                                            backgroundColor: Colors.green),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text("Could not approve request. Please try again.")),
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel_rounded,
                                      color: Colors.redAccent),
                                  onPressed: () async {
                                    final nav = Navigator.of(context);
                                    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
                                    try {
                                      await tribeProvider
                                          .declineRequestOrInvite(
                                              widget.tribeId,
                                              mem['user_id'] as int);
                                      await notifProvider.fetchNotifications();
                                      nav.pop();
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text("Could not decline request. Please try again.")),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMemberRolePicker(BuildContext context, Map<String, dynamic> member,
      List<Map<String, dynamic>> roles) {
    final tribeProvider = Provider.of<TribeProvider>(context, listen: false);
    final profile = member['profile'] as Map<String, dynamic>? ?? {};
    final name = profile['name'] ?? 'this member';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: GlassmorphicContainer(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Assign Role to $name",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: roles.length,
                    itemBuilder: (context, index) {
                      final role = roles[index];
                      final roleColorStr =
                          role['color']?.toString() ?? '#FFFFFF';
                      final roleColor = Color(
                          int.parse(roleColorStr.replaceAll('#', '0xFF')));
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          leading: const Icon(Icons.shield_rounded,
                              size: 20, color: Colors.white70),
                          title: Text(role['name'] ?? '',
                              style: TextStyle(
                                  color: roleColor,
                                  fontWeight: FontWeight.bold)),
                          onTap: () async {
                            final navigator = Navigator.of(context);
                            try {
                              await tribeProvider.changeMemberRole(
                                  widget.tribeId,
                                  member['user_id'] as int,
                                  role['id'] as String);
                              navigator.pop();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Could not change member role. Please try again.")),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    child: const Text("Cancel",
                        style: TextStyle(color: Colors.white70)),
                    onPressed: () => Navigator.pop(context),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showInviteQRCodeDialog(BuildContext context, String inviteCode) {
    final qrPayload = jsonEncode({
      "tribeCode": inviteCode,
    });
    final qrImage = _generateQrImage(qrPayload);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: GlassmorphicContainer(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Mafia Share Code",
                        style: context.screenHeading.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Text("Scan QR code below to quickly join this Mafia.",
                    style:
                        TextStyle(color: context.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (qrImage != null)
                  Center(
                    child: Container(
                      width: 180,
                      height: 180,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: PrettyQrView(
                        qrImage: qrImage,
                        decoration: const PrettyQrDecoration(
                          shape: PrettyQrSmoothSymbol(color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  "Invite Code: $inviteCode",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text("Copy Invite Code"),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Invite code copied to clipboard!")),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accentSecondary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmLeave(
      BuildContext context, TribeProvider tribeProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GlassmorphicContainer(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Leave Mafia?",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              const SizedBox(height: 12),
              const Text("Are you sure you want to leave this mafia?",
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text("Cancel",
                        style: TextStyle(color: Colors.white70)),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Leave",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      final nav = Navigator.of(context);
      try {
        await tribeProvider.leaveTribe(widget.tribeId);
        nav.pop(); // Pop details
        nav.pop(); // Pop chat
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not leave Mafia. Please try again.")),
        );
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, TribeProvider tribeProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GlassmorphicContainer(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Delete Mafia?",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              const SizedBox(height: 12),
              const Text(
                  "This action is permanent. Are you sure you want to delete this mafia and all its chats?",
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text("Cancel",
                        style: TextStyle(color: Colors.white70)),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Delete",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      final nav = Navigator.of(context);
      try {
        await tribeProvider.deleteTribe(widget.tribeId);
        nav.pop(); // Pop details
        nav.pop(); // Pop chat
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not delete Mafia. Please try again.")),
        );
      }
    }
  }

  Future<void> _saveDetails() async {
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
    try {
      final updates = {
        'name': name,
        'description': "",
        'avatar_url': _uploadedAvatarUrl ?? "",
        'max_members': null,
        'visibility': 'private',
        'requires_approval': _requiresApproval,
      };
      final tribeProvider = Provider.of<TribeProvider>(context, listen: false);
      await tribeProvider.editTribe(widget.tribeId, updates);
      setState(() {
        _isEditing = false;
        _isLoading = false;
      });
      _fetchDetails();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not save changes. Please try again.")),
      );
    }
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderMuted.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: context.accentSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tribeProvider = Provider.of<TribeProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final myUserId = profileProvider.userId;

    final myTribeRow = tribeProvider.myTribes.firstWhere(
      (t) => t['tribe_id'] == widget.tribeId || t['id'] == widget.tribeId,
      orElse: () => <String, dynamic>{},
    );

    final tribe =
        myTribeRow.containsKey('tribe') ? myTribeRow['tribe'] : myTribeRow;

    if (tribe == null || tribe.isEmpty) {
      return Scaffold(
        backgroundColor: context.canvasBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final String name = tribe['name'] ?? 'Mafia';
    final String inviteCode = tribe['invite_code'] ?? '';
    final int? maxMembers = tribe['max_members'] as int?;

    final members = tribeProvider.getMembers(widget.tribeId);
    final activeMembers =
        members.where((m) => m['status'] == 'active').toList();
    final requestedMembers =
        members.where((m) => m['status'] == 'requested').toList();
    final roles = tribeProvider.getRoles(widget.tribeId);

    // Permission checks
    final canEdit = tribeProvider.hasPermission(widget.tribeId, 'edit_tribe');
    final canManageMembers =
        tribeProvider.hasPermission(widget.tribeId, 'manage_members');
    final canManageRoles =
        tribeProvider.hasPermission(widget.tribeId, 'manage_roles');
    final canDelete =
        tribeProvider.hasPermission(widget.tribeId, 'delete_tribe');
    final canInvite =
        tribeProvider.hasPermission(widget.tribeId, 'invite_members');

    return PopScope(
      canPop: !_isEditing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _isEditing = false;
        });
      },
      child: Scaffold(
        backgroundColor: context.canvasBackground,
        appBar: AppBar(
          title: Text(_isEditing ? "Edit Mafia" : "Mafia Details",
              style:
                  context.screenHeading.copyWith(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: const GlassmorphicFlexibleSpace(),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onPressed: () {
              if (_isEditing) {
                setState(() {
                  _isEditing = false;
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isEditing
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: _pickAndUploadImage,
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
                                      width: 2,
                                    ),
                                    image: _uploadedAvatarUrl != null &&
                                            _uploadedAvatarUrl!.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(
                                                _uploadedAvatarUrl!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: _uploadedAvatarUrl == null ||
                                          _uploadedAvatarUrl!.isEmpty
                                      ? const Icon(Icons.group_rounded,
                                          size: 36, color: Colors.white70)
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
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
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
                                        border: Border.all(
                                            color: context.canvasBackground,
                                            width: 2),
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
                        const SizedBox(height: 32),
                        TextField(
                          controller: _nameController,
                          style: context.bodyText
                              .copyWith(color: context.textPrimary),
                          decoration: InputDecoration(
                            labelText: "Mafia Name *",
                            labelStyle: TextStyle(
                                color: context.textSecondary, fontSize: 13),
                            fillColor: context.surfaceSecondary,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: context.borderMuted),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: context.borderMuted),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: context.accentSecondary, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: context.surfacePrimary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    context.borderMuted.withValues(alpha: 0.3)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text("Requires Approval to Join",
                                  style: context.bodyText
                                      .copyWith(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  "New members must be approved by an Elder",
                                  style: context.captionText
                                      .copyWith(color: context.textMuted)),
                              value: _requiresApproval,
                              activeColor: context.accentSecondary,
                              onChanged: (val) {
                                setState(() {
                                  _requiresApproval = val;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditing = false;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: context.textSecondary,
                                  side: BorderSide(color: context.borderMuted),
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text("Cancel",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saveDetails,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.accentSecondary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text("Save",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: context.accentSecondary
                                          .withValues(alpha: 0.4),
                                      width: 2),
                                  color: context.surfaceSecondary,
                                  image: (tribe['avatar_url'] != null &&
                                          tribe['avatar_url']
                                              .toString()
                                              .isNotEmpty)
                                      ? DecorationImage(
                                          image: NetworkImage(
                                              tribe['avatar_url'].toString()),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: (tribe['avatar_url'] == null ||
                                        tribe['avatar_url'].toString().isEmpty)
                                    ? const Icon(Icons.group_rounded,
                                        size: 40, color: Colors.white70)
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                name,
                                style: context.screenHeading.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.lock_outline_rounded,
                                            size: 12, color: Colors.white54),
                                        const SizedBox(width: 4),
                                        Text(
                                          "PRIVATE",
                                          style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (tribe['requires_approval'] == true) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: context.accentSecondary
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: context.accentSecondary
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        "REQUIRES APPROVAL",
                                        style: TextStyle(
                                          color: context.accentSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Pending Requests Banner Alert
                        if (canManageMembers &&
                            requestedMembers.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          InkWell(
                            onTap: () => _showRequestsSheet(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orangeAccent.withValues(alpha: 0.15),
                                    Colors.orange.withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.orangeAccent
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.notifications_active_rounded,
                                      color: Colors.orangeAccent, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Pending Join Requests",
                                          style: context.bodyText.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orangeAccent),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${requestedMembers.length} user(s) requested to join this mafia.",
                                          style: context.captionText.copyWith(
                                              color: context.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded,
                                      color: Colors.orangeAccent, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Actions row
                        if (canEdit ||
                            canManageMembers ||
                            inviteCode.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              if (canEdit)
                                Expanded(
                                  child: _buildActionButton(
                                    icon: Icons.edit_rounded,
                                    label: "Edit Details",
                                    onTap: () {
                                      setState(() {
                                        _isEditing = true;
                                        _nameController.text =
                                            tribe['name'] ?? '';
                                        _uploadedAvatarUrl =
                                            tribe['avatar_url']?.toString();
                                        _requiresApproval =
                                            tribe['requires_approval'] == true;
                                      });
                                    },
                                  ),
                                ),
                              if (canEdit &&
                                  (canInvite || canManageRoles))
                                const SizedBox(width: 12),
                              if (canInvite)
                                Expanded(
                                  child: _buildActionButton(
                                    icon: Icons.person_add_alt_1_rounded,
                                    label: "Add Member",
                                    onTap: () => _showInviteUserSheet(context),
                                  ),
                                ),
                              if (canInvite &&
                                  (inviteCode.isNotEmpty || canManageRoles))
                                const SizedBox(width: 12),
                              if (canInvite && inviteCode.isNotEmpty)
                                Expanded(
                                  child: _buildActionButton(
                                    icon: Icons.qr_code_2_rounded,
                                    label: "Share QR",
                                    onTap: () => _showInviteQRCodeDialog(
                                        context, inviteCode),
                                  ),
                                ),
                              if (canInvite && inviteCode.isNotEmpty && canManageRoles)
                                const SizedBox(width: 12),
                              if (canManageRoles)
                                Expanded(
                                  child: _buildActionButton(
                                    icon: Icons.shield_rounded,
                                    label: "Roles",
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              TribeRoleBuilderPage(
                                                  tribeId: widget.tribeId),
                                        ),
                                      ).then((_) => _fetchDetails());
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ],

                        // Member Directory
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Member Directory",
                                style: context.cardTitle.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.2)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              // decoration: BoxDecoration(
                              //   color: Colors.white10,
                              //   borderRadius: BorderRadius.circular(10),
                              // ),
                              child: Text(
                                "${activeMembers.length}${maxMembers != null ? ' / $maxMembers' : ''}",
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: activeMembers.length,
                          itemBuilder: (context, index) {
                            final mem = activeMembers[index];
                            final profile =
                                mem['profile'] as Map<String, dynamic>? ?? {};
                            final role =
                                mem['role'] as Map<String, dynamic>? ?? {};
                            final profileName = profile['name'] ?? 'Unknown';
                            final profileAvatar =
                                profile['avatar_url']?.toString() ??
                                    profile['avatarUrl']?.toString() ??
                                    '';
                            final isMemMe = mem['user_id'] == myUserId;

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 0),
                              // decoration: BoxDecoration(
                              //   color: context.surfacePrimary,
                              //   borderRadius: BorderRadius.circular(16),
                              //   border: Border.all(
                              //       color: context.borderMuted
                              //           .withValues(alpha: 0.3)),
                              // ),
                              child: Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: context.surfaceSecondary,
                                    backgroundImage: profileAvatar.isNotEmpty
                                        ? NetworkImage(profileAvatar)
                                        : null,
                                    child: profileAvatar.isEmpty
                                        ? Text(
                                            profileName
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: TextStyle(
                                                color: context.textPrimary),
                                          )
                                        : null,
                                  ),
                                  title: Row(
                                    children: [
                                      Text(profileName,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                      if (isMemMe) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: context.accentSecondary
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text("YOU",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Row(
                                    children: [
                                      const Icon(Icons.shield_rounded,
                                          size: 12, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          role['name'] ?? 'Member',
                                          style: TextStyle(
                                            color: role['color'] != null
                                                ? Color(int.parse(role['color']
                                                    .replaceAll('#', '0xFF')))
                                                : context.textMuted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: (isMemMe)
                                      ? null
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (canManageRoles)
                                              IconButton(
                                                icon: const Icon(
                                                    Icons
                                                        .admin_panel_settings_rounded,
                                                    size: 18,
                                                    color: Colors.blueAccent),
                                                onPressed: () =>
                                                    _showMemberRolePicker(
                                                        context, mem, roles),
                                              ),
                                            if (canManageMembers)
                                              IconButton(
                                                icon: const Icon(
                                                    Icons
                                                        .remove_circle_outline_rounded,
                                                    size: 18,
                                                    color: Colors.redAccent),
                                                onPressed: () async {
                                                  final confirmed =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                      backgroundColor: context
                                                          .surfacePrimary,
                                                      title: const Text(
                                                          "Remove Member?",
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white)),
                                                      content: Text(
                                                          "Are you sure you want to remove $profileName from this mafia?",
                                                          style: const TextStyle(
                                                              color: Colors
                                                                  .white70)),
                                                      actions: [
                                                        TextButton(
                                                          child: const Text(
                                                              "Cancel"),
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  false),
                                                        ),
                                                        TextButton(
                                                          style: TextButton.styleFrom(
                                                              foregroundColor:
                                                                  Colors
                                                                      .redAccent),
                                                          child: const Text(
                                                              "Remove"),
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  true),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirmed == true &&
                                                      mounted) {
                                                    try {
                                                      await tribeProvider
                                                          .removeMember(
                                                              widget.tribeId,
                                                              mem['user_id']
                                                                  as int);
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                            content: Text(
                                                                "Could not remove member. Please try again.")),
                                                      );
                                                    }
                                                  }
                                                },
                                              ),
                                          ],
                                        ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Danger Zone
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    Colors.redAccent.withValues(alpha: 0.15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Danger Zone",
                                style: context.cardTitle.copyWith(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Leaving or deleting a mafia cannot be undone.",
                                style: context.captionText
                                    .copyWith(color: context.textMuted),
                              ),
                              const SizedBox(height: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.logout_rounded,
                                        size: 16),
                                    label: const Text("Leave Mafia"),
                                    onPressed: () =>
                                        _confirmLeave(context, tribeProvider),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.redAccent,
                                      side: const BorderSide(
                                          color: Colors.redAccent),
                                      minimumSize:
                                          const Size(double.infinity, 44),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  if (canDelete) ...[
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      icon: const Icon(
                                          Icons.delete_forever_rounded,
                                          size: 16),
                                      label: const Text("Delete Mafia"),
                                      onPressed: () => _confirmDelete(
                                          context, tribeProvider),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        minimumSize:
                                            const Size(double.infinity, 44),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
      ),
    );
  }
}
