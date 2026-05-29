import 'dart:convert';
import 'package:connect/Pages/QrCodeScanner.dart';
import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:connect/Providers/ProviderSQL.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onSetUpProfile;

  const ProfilePage({super.key, this.onSetUpProfile});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _connections = [];
  bool _qrGenerated = false;
  String _selectedShareType = 'both';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileProvider =
          Provider.of<ProfileProvider2>(context, listen: false);
      _initializeData(profileProvider);
    });
  }

  Future<void> _initializeData(ProfileProvider2 profileProvider) async {
    setState(() => _isLoading = true);

    try {
      final userid = await profileProvider.fetchAndSetUserId2(true);
      if (userid != -1) {
        final userData = await profileProvider.loadProfile(userid);
        if (userData.isNotEmpty) {
          profileProvider.setUserData(userData);
        }
        profileProvider.subscribeToConnections();
      }
    } catch (e) {
      print("Error initializing data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshData() async {
    final profileProvider =
        Provider.of<ProfileProvider2>(context, listen: false);
    await _initializeData(profileProvider);
  }

  QrImage? _generateQrImage(String data, int userId) {
    try {
      // If the data length is too long (e.g. > 300 characters), fall back to userId to keep the QR code simple and easily scannable
      if (data.length > 300) {
        throw Exception("Data too long");
      }
      final qrCode = QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.H,
      );
      return QrImage(qrCode);
    } catch (e) {
      print("Error/Fallback in generating QR image: $e. Using userId.");
      try {
        final fallbackData = jsonEncode({"userId": userId});
        final qrCode = QrCode.fromData(
          data: fallbackData,
          errorCorrectLevel: QrErrorCorrectLevel.H,
        );
        return QrImage(qrCode);
      } catch (fallbackError) {
        print("Error generating QR image with fallback: $fallbackError");
        return null;
      }
    }
  }

  // Share profile details by copying to clipboard
  void _shareProfile(ProfileProvider2 profileProvider) {
    if (profileProvider.UserData.isEmpty) return;

    // Copy the profile string format to clipboard
    final profileString = "${profileProvider.UserData}";
    Clipboard.setData(ClipboardData(text: profileString)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile link copied to clipboard!"),
          backgroundColor: Color(0xFF8B5CF6),
        ),
      );
    });
  }

  // Calculate relative time since creation
  String _getRelativeTime(dynamic createdAtValue) {
    if (createdAtValue == null) return "1h";
    try {
      DateTime createdAt;
      if (createdAtValue is String) {
        createdAt = DateTime.parse(createdAtValue);
      } else if (createdAtValue is DateTime) {
        createdAt = createdAtValue;
      } else {
        return "2h";
      }

      final difference = DateTime.now().difference(createdAt.toLocal());
      if (difference.inMinutes < 1) {
        return "now";
      } else if (difference.inMinutes < 60) {
        return "${difference.inMinutes}m";
      } else if (difference.inHours < 24) {
        return "${difference.inHours}h";
      } else {
        return "${difference.inDays}d";
      }
    } catch (e) {
      return "3h";
    }
  }

  // Delete a connection with dialog confirmation
  Future<void> _showDeleteConfirmation(BuildContext context,
      Map<String, dynamic> connection, ProfileProvider2 provider) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF13141F),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Delete Connection",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to remove ${connection['name'] ?? 'this contact'} from your Inner Circle?",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("Delete",
                  style: TextStyle(color: Colors.redAccent)),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await provider.deleteProfile(connection['id']);
                  _refreshData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Connection removed"),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                } catch (e) {
                  print("Error deleting connection: $e");
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider2>(context);
    _connections = profileProvider.connections;

    final hasBasicDetails = profileProvider.name.trim().isNotEmpty &&
        profileProvider.profession.trim().isNotEmpty &&
        (profileProvider.phoneNumber.trim().isNotEmpty ||
            profileProvider.professionalPhoneNumber.trim().isNotEmpty);

    debugPrint(
        "ProfilePage Build: userId=${profileProvider.userId}, UserData=${profileProvider.UserData}, hasBasicDetails=$hasBasicDetails, name='${profileProvider.name}', profession='${profileProvider.profession}', phoneNumber='${profileProvider.phoneNumber}'");

    // Get QR image if profile data is present, basic details are filled, and QR is generated
    QrImage? qrImage;
    if (profileProvider.userId != -1 &&
        profileProvider.UserData.isNotEmpty &&
        hasBasicDetails &&
        _qrGenerated) {
      final qrPayload = jsonEncode({
        "userId": profileProvider.userId,
        "sharedCard": _selectedShareType,
      });
      qrImage = _generateQrImage(qrPayload, profileProvider.userId);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
                ),
              )
            : RefreshIndicator(
                onRefresh: _refreshData,
                color: const Color(0xFF00F2FE),
                backgroundColor: const Color(0xFF13141F),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Header Bar
                      _buildTopHeader(context, profileProvider),
                      const SizedBox(height: 32),

                      // Title
                      const Text(
                        "Your Identity",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),

                      // Subtitle
                      Text(
                        "Scan to connect. No search, no public\nprofiles.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 15,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // QR Code / Setup Container
                      Center(
                        child: _buildQRFrame(context, qrImage, profileProvider),
                      ),
                      const SizedBox(height: 36),

                      // Quick Action Buttons
                      _buildActionButtons(context, profileProvider),
                      const SizedBox(height: 40),

                      // Inner Circle Header
                      _buildInnerCircleHeader(),
                      const SizedBox(height: 20),

                      // Inner Circle Connections List
                      _buildInnerCircleList(profileProvider),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // Header bar matching the user mockup
  Widget _buildTopHeader(
      BuildContext context, ProfileProvider2 profileProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          // Infinity link logo inside circle
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1C2A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Image.asset(
              'assets/icons/Connect Icon3.png',
              width: 22,
              height: 22,
              color: const Color(0xFF00F2FE), // Teal color link logo
            ),
          ),
          const SizedBox(width: 12),
          // Brand Title and Subtitle
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Connect",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                "Zero Noise.",
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Settings button
          GestureDetector(
            onTap: () {
              widget.onSetUpProfile?.call();
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1C2A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: const Icon(
                Icons.settings,
                color: Colors.white60,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // QR Container with Glowing Border and L-Corner brackets
  Widget _buildQRFrame(BuildContext context, QrImage? qrImage,
      ProfileProvider2 profileProvider) {
    const double outerSize = 280.0;
    final hasBasicDetails = profileProvider.name.trim().isNotEmpty &&
        profileProvider.profession.trim().isNotEmpty &&
        profileProvider.phoneNumber.trim().isNotEmpty;

    return Container(
      width: outerSize,
      height: outerSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2C42),
            const Color(0xFF3D3560).withOpacity(0.5),
            const Color(0xFF2A2C42),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.06),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.5), // Border width
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0B10),
          borderRadius: BorderRadius.circular(34),
        ),
        child: Stack(
          children: [
            // Four L-Brackets in the corners
            Positioned(
              top: 24,
              left: 24,
              child: _buildCornerBracket(top: true, left: true),
            ),
            Positioned(
              top: 24,
              right: 24,
              child: _buildCornerBracket(top: true, left: false),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              child: _buildCornerBracket(top: false, left: true),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: _buildCornerBracket(top: false, left: false),
            ),

            // Inside Content: QR code, option setup, or profile setup CTA
            Center(
              child: !hasBasicDetails
                  ? Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.contact_page_outlined,
                            color: Colors.white30,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "No Profile Setup",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Create your card to generate a QR",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              widget.onSetUpProfile?.call();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00F2FE),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "Set Up Profile",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )
                  : (qrImage != null && _qrGenerated
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 130,
                              height: 130,
                              child: PrettyQrView(
                                qrImage: qrImage,
                                decoration: const PrettyQrDecoration(
                                  shape: PrettyQrSmoothSymbol(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B1C2A),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.04)),
                              ),
                              child: Text(
                                "Sharing: ${_selectedShareType.toUpperCase()}",
                                style: const TextStyle(
                                  color: Color(0xFF00F2FE),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _showQrOptionsBottomSheet(context),
                              child: const Text(
                                "Change Share Options",
                                style: TextStyle(
                                  color: Color(0xFF8B5CF6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.qr_code_2_rounded,
                                color: Colors.white30,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "Ready to Connect",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Choose what you want to share before scanning",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  _showQrOptionsBottomSheet(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00F2FE),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  "Generate QR",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        )),
            ),
          ],
        ),
      ),
    );
  }

  void _showQrOptionsBottomSheet(BuildContext context) {
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
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
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
                      const Text(
                        "Share Identity Options",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Select which digital card you want to share with this QR Code scan:",
                        style: TextStyle(
                          color: Color(0xFF8B8C9E),
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildOptionTile(
                        title: "Casual Card Only",
                        subtitle: "Share bio, socials, name & basic details.",
                        value: "casual",
                        groupValue: _selectedShareType,
                        onChanged: (val) {
                          setModalState(() {
                            _selectedShareType = val!;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildOptionTile(
                        title: "Professional Card Only",
                        subtitle:
                            "Share company, email, phone & professional bio.",
                        value: "professional",
                        groupValue: _selectedShareType,
                        onChanged: (val) {
                          setModalState(() {
                            _selectedShareType = val!;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildOptionTile(
                        title: "Both Cards (Recommended)",
                        subtitle:
                            "Share your complete casual and professional profiles.",
                        value: "both",
                        groupValue: _selectedShareType,
                        onChanged: (val) {
                          setModalState(() {
                            _selectedShareType = val!;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _qrGenerated = true;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Generate QR Code",
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B1C38) : const Color(0xFF131422),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF26273F),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8B8C9E),
                      fontSize: 11,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFF5C5E78),
                  width: 2.0,
                ),
              ),
              padding: const EdgeInsets.all(3.0),
              child: isSelected
                  ? Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF8B5CF6),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // Widget to build single L-Corner bracket
  Widget _buildCornerBracket({required bool top, required bool left}) {
    const double lineSize = 18.0;
    const double thickness = 3.0;
    const Color neonColor = Color(0xFF4A4C6A);

    return Container(
      width: lineSize,
      height: lineSize,
      child: Stack(
        children: [
          // Horizontal segment
          Positioned(
            top: top ? 0 : null,
            bottom: !top ? 0 : null,
            left: left ? 0 : null,
            right: !left ? 0 : null,
            child: Container(
              width: lineSize,
              height: thickness,
              decoration: BoxDecoration(
                color: neonColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Vertical segment
          Positioned(
            top: top ? 0 : null,
            bottom: !top ? 0 : null,
            left: left ? 0 : null,
            right: !left ? 0 : null,
            child: Container(
              width: thickness,
              height: lineSize,
              decoration: BoxDecoration(
                color: neonColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Row of quick action buttons
  Widget _buildActionButtons(
      BuildContext context, ProfileProvider2 profileProvider) {
    final hasProfile =
        profileProvider.userId != -1 && profileProvider.UserData.isNotEmpty;

    return Row(
      children: [
        // Scan QR Action
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QRScannerPage()),
              ).then((_) => _refreshData());
            },
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF13141F),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF00F2FE),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Scan QR",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Share Link Action
        Expanded(
          child: GestureDetector(
            onTap: hasProfile ? () => _shareProfile(profileProvider) : null,
            child: Opacity(
              opacity: hasProfile ? 1.0 : 0.4,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.share_rounded,
                      color: hasProfile ? Colors.black : Colors.black45,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Share Link",
                      style: TextStyle(
                        color: hasProfile ? Colors.black : Colors.black45,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  // Inner Circle Header Widget
  Widget _buildInnerCircleHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Inner Circle",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        // Active connections badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF13141F),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            "${_connections.length} Active",
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // Build the Inner Circle connections list
  Widget _buildInnerCircleList(ProfileProvider2 provider) {
    if (_connections.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: const Color(0xFF13141F).withOpacity(0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.02)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.group_outlined,
              color: Colors.white24,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              "No connections yet",
              style: TextStyle(
                color: Colors.white60,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Scan someone's QR code to add them here.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _connections.length,
      itemBuilder: (context, index) {
        final connection = _connections[index];
        final name = connection['name'] ?? 'Unknown';
        final profession = connection['profession'] ?? '';
        final email = connection['email'] ?? '';
        final displaySubtitle = profession.isNotEmpty
            ? profession
            : (email.isNotEmpty ? email : "Connected via Connect");
        final avatarUrl =
            connection['avatarUrl'] ?? connection['avatar_url'] ?? '';

        final String? createdAtRaw = connection['created_at'];
        String? formattedConnectionDate;
        if (createdAtRaw != null) {
          try {
            final parsedDate = DateTime.parse(createdAtRaw);
            const months = [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug',
              'Sep',
              'Oct',
              'Nov',
              'Dec'
            ];
            final monthName = months[parsedDate.month - 1];
            formattedConnectionDate = "Connected $monthName ${parsedDate.year}";
          } catch (e) {
            // Ignore parse errors
          }
        }

        return GestureDetector(
          onLongPress: () =>
              _showDeleteConfirmation(context, connection, provider),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ConnectionProfilePage(
                  profileData: connection,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF13141F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
            ),
            child: Row(
              children: [
                // Avatar directly without Stack
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade600,
                        Colors.purple.shade500,
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: (avatarUrl.isNotEmpty && avatarUrl.contains('supabase.co/storage/v1/object/public/avatars/'))
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.network(
                            avatarUrl,
                            width: 45,
                            height: 45,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  name.isNotEmpty
                                      ? name.substring(0, 1).toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Text(
                          name.isNotEmpty
                              ? name.substring(0, 1).toUpperCase()
                              : "?",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 16),

                // Name and Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildCardTypeIndicators(connection),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        displaySubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (formattedConnectionDate != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          formattedConnectionDate,
                          style: const TextStyle(
                            color: Color(0xFF5C5E78),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardTypeIndicators(Map<String, dynamic> connection) {
    final typesList = connection['cardTypes'];
    final List<String> types =
        typesList != null ? List<String>.from(typesList as List) : <String>[];

    // If cardTypes array is empty in DB, we can infer it
    if (types.isEmpty) {
      final hasInstagram =
          (connection['instagram'] ?? '').toString().isNotEmpty;
      final hasTwitter = (connection['twitter'] ?? '').toString().isNotEmpty;
      final hasCasualBio = (connection['bio'] ?? '').toString().isNotEmpty;

      final hasLinkedin = (connection['linkedin'] ?? '').toString().isNotEmpty;
      final hasCompany = (connection['company'] ?? '').toString().isNotEmpty;
      final hasEmail = (connection['email'] ?? '').toString().isNotEmpty;

      if (hasInstagram ||
          hasTwitter ||
          hasCasualBio ||
          (!hasLinkedin && !hasCompany)) {
        types.add('casual');
      }
      if (hasLinkedin || hasCompany || hasEmail) {
        types.add('professional');
      }
      if (types.isEmpty) {
        types.addAll(['casual', 'professional']);
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final type in types) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: type == 'casual'
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                  : const Color(0xFF00F2FE).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: type == 'casual'
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.35)
                    : const Color(0xFF00F2FE).withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Text(
              type == 'casual' ? 'C' : 'P',
              style: TextStyle(
                color: type == 'casual'
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF00F2FE),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
