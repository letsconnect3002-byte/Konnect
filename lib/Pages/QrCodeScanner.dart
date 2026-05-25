import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:connect/Models/profile_card_type.dart';
import 'package:connect/Providers/ProviderSQL.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({Key? key}) : super(key: key);

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
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        title: const Text(
          "Scan Identity QR",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        backgroundColor: const Color(0xFF090A0F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFF090A0F),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Hold your device over the QR code",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Scanning is secure & connects you directly.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                        fontFamily: 'Inter',
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
  // bool isTripleQuoted(String str) {
  //     return str.startsWith("'''") && str.endsWith("'''");
  //   }

  //   // Check for single quotes by context (this test won't work exactly in Dart's runtime but demonstrates logic)
  //   bool isSingleQuoted(String str) {
  //     return !isTripleQuoted(str); // Fallback logic for single-quoted strings
  //   }
  Widget _buildQrView(BuildContext context) {
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 220.0
        : 300.0;
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: const Color(0xFF00F2FE),
        borderRadius: 24,
        borderLength: 38,
        borderWidth: 4,
        cutOutSize: scanArea,
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
            final int idToFetch = userIdVal is int ? userIdVal : int.parse(userIdVal.toString());

            // Show a progress dialog while fetching profile
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
                  ),
                ),
              );
            }

            if (!mounted) return;
            final profileProvider = Provider.of<ProfileProvider2>(context, listen: false);
            final fetchedData = await profileProvider.fetchProfileDataOnly(idToFetch);
            if (fetchedData.isNotEmpty) {
              fetchedData['sharedCard'] = decodedData['sharedCard'] ?? 'both';
            }

            if (mounted) {
              Navigator.pop(context); // Dismiss progress dialog
            }

            if (fetchedData.isNotEmpty && fetchedData['name'].toString().isNotEmpty) {
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
    controller?.dispose();
    super.dispose();
  }
}

class ProfileCard extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const ProfileCard({Key? key, required this.profileData}) : super(key: key);

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  late final ProfileProvider2 provider;
  ProfileCardType _activeTab = ProfileCardType.professional;
  String _shareBackType = 'both';
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    provider = Provider.of<ProfileProvider2>(context, listen: false);

    final String presenterSharedCard = (widget.profileData['sharedCard'] ?? 'both').toString();
    if (presenterSharedCard == 'casual') {
      _activeTab = ProfileCardType.casual;
    } else {
      _activeTab = ProfileCardType.professional;
    }
  }

  String _getVisibleField(String fieldKey, String rawValue) {
    if (fieldKey == 'name' || fieldKey == 'avatarUrl') return rawValue;

    final String sharedCard = (widget.profileData['sharedCard'] ?? 'both').toString();
    final dynamic faRaw = widget.profileData['field_assignments'];
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

    final Map<String, dynamic> assignment = assignmentRaw as Map<String, dynamic>;
    final bool isCasual = assignment['c'] == true;
    final bool isProfessional = assignment['p'] == true;

    final bool isCasualTab = _activeTab == ProfileCardType.casual;

    if (sharedCard == 'casual' && !isCasualTab) return '';
    if (sharedCard == 'professional' && isCasualTab) return '';

    if (isCasualTab) {
      return isCasual ? rawValue : '';
    } else {
      return isProfessional ? rawValue : '';
    }
  }

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

  void saveProfile() async {
    if (provider.userId == -1) {
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
    final int scannedUserId = otherUserIdVal is int ? otherUserIdVal : int.parse(otherUserIdVal.toString());

    final String presenterSharedCard = widget.profileData['sharedCard'] ?? 'both';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
        ),
      ),
    );

    provider.connectUsers(
      provider.userId, 
      scannedUserId, 
      sharedCardByPresenter: presenterSharedCard,
      sharedCardByScanner: _shareBackType,
    ).then((v) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss progress dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF00F2FE)),
              const SizedBox(width: 10),
              Text(
                "Connected with ${widget.profileData['name']}!",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF131422),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF26273C), width: 1),
          ),
        ),
      );
      Navigator.pop(context); // Pop back to scan screen / homepage
    }).catchError((e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving connection: $e")),
      );
    });
  }

  Widget _buildCardTypeTabs() {
    final String presenterSharedCard = (widget.profileData['sharedCard'] ?? 'both').toString();
    if (presenterSharedCard != 'both') {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: presenterSharedCard == 'casual'
              ? const Color(0xFF8B5CF6).withOpacity(0.1)
              : const Color(0xFF00F2FE).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: presenterSharedCard == 'casual'
                ? const Color(0xFF8B5CF6).withOpacity(0.3)
                : const Color(0xFF00F2FE).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          "${widget.profileData['name']}'s ${presenterSharedCard.toUpperCase()} CARD",
          style: TextStyle(
            color: presenterSharedCard == 'casual'
                ? const Color(0xFFC084FC)
                : const Color(0xFF22D3EE),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontFamily: 'Inter',
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF202130), width: 1.5),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: _buildSingleTab(
              type: ProfileCardType.casual,
              label: "Casual Details",
              activeColor: const Color(0xFF8B5CF6),
            ),
          ),
          Expanded(
            child: _buildSingleTab(
              type: ProfileCardType.professional,
              label: "Professional Details",
              activeColor: const Color(0xFF00F2FE),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleTab({
    required ProfileCardType type,
    required String label,
    required Color activeColor,
  }) {
    final bool isActive = _activeTab == type;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _activeTab = type;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? activeColor.withOpacity(0.4) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : const Color(0xFF8B8C9E),
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlippingCard() {
    final String name = widget.profileData['name'] ?? 'Unknown';
    final String profession = _getVisibleField('profession', widget.profileData['profession'] ?? '');
    final String company = _getVisibleField('company', widget.profileData['company'] ?? '');
    final String email = _getVisibleField('email', widget.profileData['email'] ?? '');
    final String phone = _getVisibleField('phoneNumber', widget.profileData['phoneNumber'] ?? widget.profileData['phone_number'] ?? '');
    final String bio = _getVisibleField('bio', widget.profileData['bio'] ?? '');
    final String avatar = _getAvatarUrl(name, widget.profileData['avatarUrl']);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _showFront = !_showFront;
        });
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) {
          final rotate = Tween(begin: 3.14, end: 0.0).animate(animation);
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
        child: _showFront
            ? _buildCardFront(name, profession, company, avatar)
            : _buildCardBack(name, email, phone, bio),
      ),
    );
  }

  Widget _buildCardFront(String name, String profession, String company, String avatar) {
    final bool isCasual = _activeTab == ProfileCardType.casual;
    final Color accentColor = isCasual ? const Color(0xFF8B5CF6) : const Color(0xFF00F2FE);

    return Container(
      key: const ValueKey('front'),
      width: 320,
      height: 190,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCasual
              ? [const Color(0xFF2C1E4D), const Color(0xFF0F0922)]
              : [const Color(0xFF132A33), const Color(0xFF091316)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.qr_code_2_rounded,
                        color: accentColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCasual ? "CASUAL CARD" : "PROFESSIONAL CARD",
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accentColor.withOpacity(0.3)),
                    ),
                    child: const Text(
                      "SCANNED ID",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isCasual
                            ? [const Color(0xFF8B5CF6), const Color(0xFFD8B4FE)]
                            : [const Color(0xFF00F2FE), const Color(0xFF38BDF8)],
                      ),
                    ),
                    padding: const EdgeInsets.all(1.5),
                    child: ClipOval(
                      child: Image.network(
                        avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person, color: Colors.white, size: 28),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (profession.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            profession,
                            style: TextStyle(
                              color: accentColor.withOpacity(0.9),
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

  Widget _buildCardBack(String name, String email, String phone, String bio) {
    final bool isCasual = _activeTab == ProfileCardType.casual;
    final Color accentColor = isCasual ? const Color(0xFF8B5CF6) : const Color(0xFF00F2FE);

    final String instagram = _getVisibleField('instagram', widget.profileData['instagram'] ?? '');
    final String linkedin = _getVisibleField('linkedin', widget.profileData['linkedin'] ?? '');
    final String twitter = _getVisibleField('twitter', widget.profileData['twitter'] ?? '');

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(3.14),
      child: Container(
        key: const ValueKey('back'),
        width: 320,
        height: 190,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isCasual
                ? [const Color(0xFF2C1E4D), const Color(0xFF0F0922)]
                : [const Color(0xFF132A33), const Color(0xFF091316)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
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
                fontSize: 11,
                fontWeight: FontWeight.w900,
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
                  height: 1.3,
                  fontFamily: 'Inter',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              height: 1,
              color: accentColor.withOpacity(0.2),
              margin: const EdgeInsets.symmetric(vertical: 8),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (email.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.alternate_email_rounded,
                                color: accentColor, size: 12),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                email,
                                style: const TextStyle(
                                  color: Color(0xFFC0C1D0),
                                  fontSize: 10,
                                  fontFamily: 'Inter',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.phone_rounded,
                                color: accentColor, size: 12),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                phone,
                                style: const TextStyle(
                                  color: Color(0xFFC0C1D0),
                                  fontSize: 10,
                                  fontFamily: 'Inter',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (instagram.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.camera_alt_outlined, color: accentColor, size: 14),
                    ],
                    if (linkedin.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.link_rounded, color: accentColor, size: 14),
                    ],
                    if (twitter.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.chat_bubble_outline_rounded, color: accentColor, size: 14),
                    ],
                  ],
                ),
              ],
            ),
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
        color: const Color(0xFF131422),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF26273C), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "SHARE YOUR CARD BACK",
            style: TextStyle(
              color: Color(0xFF8B8C9E),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Choose which profile card you want to share with ${widget.profileData['name'] ?? 'them'}:",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              height: 1.3,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildShareBackOption(
                  type: 'casual',
                  label: "Casual",
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildShareBackOption(
                  type: 'professional',
                  label: "Professional",
                  color: const Color(0xFF00F2FE),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildShareBackOption(
                  type: 'both',
                  label: "Both",
                  color: const Color(0xFFFF007F),
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
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : const Color(0xFF0A0A0F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF26273C),
            width: isSelected ? 1.8 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.12),
                    blurRadius: 8,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF8B8C9E),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
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
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        title: const Text(
          "Profile Preview",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'Inter',
          ),
        ),
        backgroundColor: const Color(0xFF090A0F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildCardTypeTabs(),
              ),
              _buildFlippingCard(),
              const SizedBox(height: 12),
              const Text(
                "Tap card to flip and view details",
                style: TextStyle(
                  color: Color(0xFF5C5E78),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Inter',
                ),
              ),
              _buildShareBackSelector(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF8B5CF6),
                        Color(0xFF00F2FE),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F2FE).withOpacity(0.2),
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
                    child: const Text(
                      "Connect & Add to Circle",
                      style: TextStyle(
                        color: Colors.white,
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
