import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:connect/Utils/profile_field_filter.dart';
import 'package:connect/Config/app_theme.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<StatefulWidget> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.canvasBackground,
      appBar: AppBar(
        title: Text(
          "Scan Identity QR",
          style: context.screenHeading,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: Container(
              color: context.canvasBackground,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Hold your device over the QR code",
                      style: context.bodyText.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Scanning is secure & connects you directly.",
                      style: context.captionText.copyWith(
                        color: context.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: context.accentPrimary,
        borderRadius: AppDimensions.radiusPremiumCard,
        borderLength: 38,
        borderWidth: 3.0,
        cutOutSize: 260.0,
        overlayColor: const Color(0xFF03100D).withValues(alpha: 0.75),
      ),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  // String convertToJsonFormat(String input) {
  //   // Add quotes around the keys.
  //   String fixedData = input.replaceAllMapped(RegExp(r'(\w+):'), (match) {
  //     return '"${match.group(1)}":'; // Add quotes around the keys
  //   });

  //   // Add quotes around values. This will also handle multi-word values properly.
  //   fixedData =
  //       fixedData.replaceAllMapped(RegExp(r'(\w+)(?=\s*,|\s*})'), (match) {
  //     return '"${match.group(1)}"'; // Add quotes around values
  //   });

  //   // Handle special cases like multi-word names (e.g., "Santosh Patil" should stay intact).
  //   fixedData = fixedData.replaceAllMapped(RegExp(r'(\w+ [\w\s]+)'), (match) {
  //     return '"${match.group(0)}"'; // Add quotes around multi-word strings
  //   });

  //   // Fix any unescaped quotes inside the values by escaping them.
  //   fixedData = fixedData.replaceAll('"', '\\"');

  //   return fixedData;
  // }

  String convertToJsonFormat(String input) {
    // Add quotes around the keys.
    String fixedData = input.replaceAllMapped(RegExp(r'(\w+):'), (match) {
      return '"${match.group(1)}":'; // Add quotes around the keys
    });

    // Add quotes around values and ensure there are no leading or trailing spaces.
    fixedData = fixedData
        .replaceAllMapped(RegExp(r'(\w+[\w\s@.]+)(?=\s*,|\s*})'), (match) {
      // Remove leading/trailing spaces and add quotes
      return '"${match.group(1)!.trim()}"';
    });

    // Fix any issues in the email field and remove unnecessary quote marks
    fixedData = fixedData.replaceAll(RegExp(r'\"'), '"');

    return fixedData;
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });

    controller.scannedDataStream.listen((scanData) async {
      print("Scanned QR Code: ${scanData.code}");

      setState(() {
        result = scanData;
      });

      if (result != null) {
        try {
          // Ensure raw input is used for decoding
          String rawData = scanData.code ?? "";

          Map<String, dynamic> decodedData;
          final trimmed = rawData.trim();
          if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
            decodedData = jsonDecode(trimmed) as Map<String, dynamic>;
          } else {
            // Convert to valid JSON format
            String jsonFormatted = convertToJsonFormat(rawData);
            print("Converted to Data Map: $jsonFormatted");
            // Decode the JSON
            decodedData = jsonDecode(jsonFormatted) as Map<String, dynamic>;
          }

          print("Decoded Data Map: $decodedData");

          // Pause the camera to prevent additional scans
          controller.pauseCamera();

          if (decodedData.containsKey('userId')) {
            final userIdVal = decodedData['userId'];
            final int idToFetch =
                userIdVal is int ? userIdVal : int.parse(userIdVal.toString());

            // Show a progress dialog while fetching profile
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Dialog(
                  backgroundColor: context.surfacePrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusPremiumCard),
                    side:
                        BorderSide(color: context.surfaceSecondary, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              context.accentPrimary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Loading their card...",
                          style: context.bodyText.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (!mounted) return;
            final profileProvider =
                Provider.of<ProfileProvider>(context, listen: false);
            final fetchedData =
                await profileProvider.fetchProfileDataOnly(idToFetch);
            if (fetchedData.isNotEmpty) {
              fetchedData['sharedCard'] = decodedData['sharedCard'] ?? 'both';
            }

            if (mounted) {
              Navigator.pop(context); // Dismiss progress dialog
            }

            if (fetchedData.isNotEmpty &&
                fetchedData['name'].toString().isNotEmpty) {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileCard(profileData: fetchedData),
                  ),
                ).then((_) {
                  controller.resumeCamera();
                });
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Profile data not found")),
                );
                controller.resumeCamera();
              }
            }
          } else {
            decodedData['sharedCard'] = decodedData['sharedCard'] ?? 'both';
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileCard(profileData: decodedData),
                ),
              ).then((_) {
                controller.resumeCamera();
              });
            }
          }
        } catch (e) {
          // Handle any parsing errors gracefully
          print("Error decoding QR data: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Invalid QR Code")),
            );
          }
          controller.resumeCamera();
        }
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Permission')),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class ProfileCard extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const ProfileCard({super.key, required this.profileData});

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  late final ProfileProvider profileProvider;
  late final ConnectionProvider connectionProvider;
  String _shareBackType = 'casual';

  @override
  void initState() {
    super.initState();
    profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
  }

  String _getAvatarUrl(String name, String? existingUrl) {
    if (existingUrl != null &&
        existingUrl.isNotEmpty &&
        existingUrl.startsWith('http')) {
      return existingUrl;
    }
    return '';
  }

  void saveProfile() async {
    if (profileProvider.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please set up your profile first")),
      );
      return;
    }
    final otherUserIdVal = widget.profileData['id'];
    if (otherUserIdVal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid scanned profile data")),
      );
      return;
    }
    final int scannedUserId = otherUserIdVal is int
        ? otherUserIdVal
        : int.parse(otherUserIdVal.toString());

    final String presenterSharedCard =
        widget.profileData['sharedCard'] ?? 'both';

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final themeSurfacePrimary = context.surfacePrimary;
    final themeSurfaceSecondary = context.surfaceSecondary;
    final themeAccentPrimary = context.accentPrimary;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: themeSurfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPremiumCard),
          side: BorderSide(color: themeSurfaceSecondary, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(themeAccentPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                "Saving connection...",
                style: context.bodyText.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await connectionProvider.connectUsers(
        profileProvider.userId!,
        scannedUserId,
        sharedCardByPresenter: presenterSharedCard,
        sharedCardByScanner: _shareBackType,
      );
      navigator.pop(); // Dismiss progress dialog

      final otherName = widget.profileData['name'] ?? 'Connection';
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: themeAccentPrimary),
              const SizedBox(width: 10),
              Text(
                "Connected with $otherName!",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          backgroundColor: themeSurfacePrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
            side: BorderSide(color: themeSurfaceSecondary, width: 1.5),
          ),
        ),
      );
      navigator.pop(); // Pop back to scan screen / homepage
    } catch (e) {
      navigator.pop(); // Dismiss progress dialog
      messenger.showSnackBar(
        SnackBar(content: Text("Error saving connection: $e")),
      );
    }
  }

  Widget _buildProfileHeaderCard() {
    final String name = widget.profileData['name'] ?? 'Unknown';
    final String sharedCard =
        (widget.profileData['sharedCard'] ?? 'both').toString();
    final bool isCasual = sharedCard == 'casual';
    final Color accentColor =
        isCasual ? context.accentSecondary : context.accentPrimary;

    final String profession = ProfileFieldFilter.getVisibleValue(
        'profession',
        widget.profileData['profession'] ?? '',
        sharedCard,
        widget.profileData['field_assignments']);
    final String company = ProfileFieldFilter.getVisibleValue(
        'company',
        widget.profileData['company'] ?? '',
        sharedCard,
        widget.profileData['field_assignments']);
    final String avatar = _getAvatarUrl(name, widget.profileData['avatarUrl']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isCasual
                ? [const Color(0xFF2C1E4D), const Color(0xFF0F0922)]
                : [const Color(0xFF132A33), const Color(0xFF091316)],
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusPremiumCard),
          border: Border.all(
              color: accentColor.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isCasual
                      ? [
                          context.accentSecondary,
                          context.accentSecondary.withValues(alpha: 0.5)
                        ]
                      : [
                          context.accentPrimary,
                          context.accentPrimary.withValues(alpha: 0.5)
                        ],
                ),
              ),
              padding: const EdgeInsets.all(1.5),
              child: ClipOval(
                child: (avatar.isNotEmpty && avatar.startsWith('http'))
                    ? Image.network(
                        avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: context.surfaceSecondary,
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty
                                ? name.substring(0, 1).toUpperCase()
                                : "?",
                            style: context.cardTitle.copyWith(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    : Container(
                        color: context.surfaceSecondary,
                        alignment: Alignment.center,
                        child: Text(
                          name.isNotEmpty
                              ? name.substring(0, 1).toUpperCase()
                              : "?",
                          style: context.cardTitle.copyWith(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: context.cardTitle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (profession.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      profession,
                      style: TextStyle(
                        color: accentColor.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (company.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      company,
                      style: context.captionText.copyWith(
                        color: context.textSecondary,
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
      ),
    );
  }

  Widget _buildProfileDetailsSection() {
    final String sharedCard =
        (widget.profileData['sharedCard'] ?? 'both').toString();
    final bool isCasual = sharedCard == 'casual';
    final Color accentColor =
        isCasual ? context.accentSecondary : context.accentPrimary;

    final String email = ProfileFieldFilter.getVisibleValue(
        'email',
        widget.profileData['email'] ?? '',
        sharedCard,
        widget.profileData['field_assignments']);
    final String phone = ProfileFieldFilter.getVisibleValue(
        'phoneNumber',
        widget.profileData['phoneNumber'] ??
            widget.profileData['phone_number'] ??
            '',
        sharedCard,
        widget.profileData['field_assignments']);
    final String bio = ProfileFieldFilter.getVisibleValue(
        'bio',
        widget.profileData['bio'] ?? '',
        sharedCard,
        widget.profileData['field_assignments']);
    final String instagram = ProfileFieldFilter.getVisibleValue(
        'instagram',
        widget.profileData['instagram'] ?? '',
        sharedCard,
        widget.profileData['field_assignments']);
    final String linkedin = ProfileFieldFilter.getVisibleValue(
        'linkedin',
        widget.profileData['linkedin'] ?? '',
        sharedCard,
        widget.profileData['field_assignments']);
    final String twitter = ProfileFieldFilter.getVisibleValue(
        'twitter',
        widget.profileData['twitter'] ?? '',
        sharedCard,
        widget.profileData['field_assignments']);

    if (email.isEmpty &&
        phone.isEmpty &&
        bio.isEmpty &&
        instagram.isEmpty &&
        linkedin.isEmpty &&
        twitter.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPremiumCard),
          border: Border.all(color: context.surfaceSecondary, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bio.isNotEmpty) ...[
              Text(
                "ABOUT ME",
                style: context.captionText.copyWith(
                  color: context.textSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                bio,
                style: context.bodyText.copyWith(
                  color: context.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (email.isNotEmpty ||
                  phone.isNotEmpty ||
                  instagram.isNotEmpty ||
                  linkedin.isNotEmpty ||
                  twitter.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                      color: accentColor.withValues(alpha: 0.15), height: 1),
                ),
            ],
            if (email.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.alternate_email_rounded,
                      color: accentColor, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      style: context.bodyText.copyWith(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (phone.isNotEmpty) const SizedBox(height: 10),
            ],
            if (phone.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.phone_rounded, color: accentColor, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phone,
                      style: context.bodyText.copyWith(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (instagram.isNotEmpty ||
                linkedin.isNotEmpty ||
                twitter.isNotEmpty) ...[
              if (email.isNotEmpty || phone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                      color: accentColor.withValues(alpha: 0.15), height: 1),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "SOCIALS",
                    style: context.captionText.copyWith(
                      color: context.textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (instagram.isNotEmpty) ...[
                        Icon(Icons.camera_alt_outlined,
                            color: accentColor, size: 16),
                        const SizedBox(width: 10),
                      ],
                      if (linkedin.isNotEmpty) ...[
                        Icon(Icons.link_rounded, color: accentColor, size: 16),
                        const SizedBox(width: 10),
                      ],
                      if (twitter.isNotEmpty) ...[
                        Icon(Icons.chat_bubble_outline_rounded,
                            color: accentColor, size: 16),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShareBackSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPremiumCard),
        border: Border.all(color: context.surfaceSecondary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "HOW DO YOU KNOW THEM?",
            style: context.captionText.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _shareBackType == 'casual'
                ? "You'll share your Casual card with them."
                : "You'll share your Professional card with them.",
            style: context.captionText.copyWith(
              color: context.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildShareBackOption(
                  type: 'casual',
                  label: "Casual",
                  color: context.accentSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildShareBackOption(
                  type: 'professional',
                  label: "Professional",
                  color: context.accentPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareBackOption({
    required String type,
    required String label,
    required Color color,
  }) {
    final bool isSelected = _shareBackType == type;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _shareBackType = type;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : context.canvasBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          border: Border.all(
            color: isSelected ? color : context.surfaceSecondary,
            width: isSelected ? 1.8 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 8,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : context.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.canvasBackground,
      appBar: AppBar(
        title: Text(
          "Profile Preview",
          style: context.screenHeading,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              _buildProfileHeaderCard(),
              _buildProfileDetailsSection(),
              _buildShareBackSelector(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: _shareBackType == 'casual'
                          ? [
                              context.accentSecondary,
                              context.accentSecondary.withValues(alpha: 0.8)
                            ]
                          : [
                              context.accentPrimary,
                              context.accentPrimary.withValues(alpha: 0.8)
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_shareBackType == 'casual'
                                ? context.accentSecondary
                                : context.accentPrimary)
                            .withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _shareBackType == 'casual'
                          ? "Add to My Casual Network"
                          : "Add to My Professional Network",
                      style: TextStyle(
                        color: _shareBackType == 'casual'
                            ? Colors.white
                            : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
