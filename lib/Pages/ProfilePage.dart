import 'dart:convert';
import 'package:connect/Pages/QrCodeScanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/Pages/NotificationPage.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onSetUpProfile;

  const ProfilePage({super.key, this.onSetUpProfile});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = false; // set properly in initState based on data presence
  bool _qrGenerated = false;
  String _selectedShareType = 'casual';

  @override
  void initState() {
    super.initState();
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);

    // Synchronous check — if AppShellGate already loaded data, start with
    // _isLoading = false so the first build renders content, not a spinner.
    _isLoading = !profileProvider.hasData;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (profileProvider.hasData) {
        // Data is in memory — refresh quietly without blocking the UI.
        _refreshSilently(profileProvider);
      } else {
        // Genuinely no data yet (first launch, cleared state, etc.)
        _initializeData(profileProvider);
      }
    });
  }

  /// Full blocking load — only used when there is no profile data at all.
  Future<void> _initializeData(ProfileProvider profileProvider) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userid = await profileProvider.fetchAndSetUserId2(true);
      if (userid != null) {
        await profileProvider.loadProfile(userid);
      }
    } catch (e) {
      debugPrint("Error initializing profile data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Silent background refresh — keeps the UI visible and just updates
  /// provider fields when the server responds.
  Future<void> _refreshSilently(ProfileProvider profileProvider) async {
    try {
      final userId = profileProvider.userId;
      if (userId != null) {
        await profileProvider.loadProfile(userId);
      }
    } catch (e) {
      debugPrint("Silent profile refresh error: $e");
    }
  }

  /// Called by the pull-to-refresh indicator. Updates content in place
  /// without blanking the screen.
  Future<void> _refreshData() async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    await _refreshSilently(profileProvider);
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

  // Share profile details by generating a VIP Pass and sharing it
  void _shareProfile(ProfileProvider profileProvider) async {
    if (profileProvider.userId == null) return;

    // Show a progress dialog while generating VIP code
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Dialog(
          backgroundColor: Color(0xFF131422),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
                ),
                SizedBox(height: 16),
                Text(
                  "Generating VIP Pass...",
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
      );
    }

    try {
      final code = await profileProvider.generateInviteCode(_selectedShareType);

      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
      }

      final shareMessage =
          "Hey,I'm inviting you to my private circle on Mandala. Download the app here: joinmandala.in and use my single-use VIP code to connect: *$code*.";

      await SharePlus.instance.share(ShareParams(text: shareMessage));
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error generating VIP code: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);

    final hasBasicDetails = profileProvider.name.trim().isNotEmpty &&
        profileProvider.profession.trim().isNotEmpty &&
        (profileProvider.phoneNumber.trim().isNotEmpty ||
            profileProvider.professionalPhoneNumber.trim().isNotEmpty);

    debugPrint(
        "ProfilePage Build: userId=${profileProvider.userId}, hasBasicDetails=$hasBasicDetails, name='${profileProvider.name}', profession='${profileProvider.profession}', phoneNumber='${profileProvider.phoneNumber}'");

    // Get QR image if profile data is present, basic details are filled, and QR is generated
    QrImage? qrImage;
    if (profileProvider.userId != null &&
        profileProvider.name.trim().isNotEmpty &&
        hasBasicDetails &&
        _qrGenerated) {
      final qrPayload = jsonEncode({
        "userId": profileProvider.userId,
        "sharedCard": _selectedShareType,
      });
      qrImage = _generateQrImage(qrPayload, profileProvider.userId!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      body: SafeArea(
        child: _isLoading
            ? Skeletonizer(
                enabled: true,
                child: _buildSkeletonBody(context),
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
                        "My Card",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // QR Code / Setup Container
                      Center(
                        child: _buildQRFrame(context, qrImage, profileProvider),
                      ),
                      if (hasBasicDetails && _qrGenerated) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13141F),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Glowing/active dot indicator
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00F2FE),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Sharing: ${_selectedShareType.toUpperCase()}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Vertical divider
                                Container(
                                  width: 1,
                                  height: 14,
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                                const SizedBox(width: 12),
                                // Change action
                                GestureDetector(
                                  onTap: () =>
                                      _showQrOptionsBottomSheet(context),
                                  child: const Text(
                                    "Change",
                                    style: TextStyle(
                                      color: Color(0xFF8B5CF6),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 36),

                      // Quick Action Buttons
                      _buildActionButtons(context, profileProvider),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // Header bar matching the user mockup
  Widget _buildTopHeader(
      BuildContext context, ProfileProvider profileProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Infinity link logo inside circle
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1C2A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Image.asset(
              'assets/icons/Mandala Icon 1.png',
              width: 22,
              height: 22,
              color: const Color(0xFF00F2FE), // Teal color link logo
            ),
          ),
          // const SizedBox(width: 12),
          // Brand Title and Subtitle
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Mandala",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                "Your Circle",
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          // const Spacer(),
          // Notifications Bell button
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, child) {
              final unread = notifProvider.unreadCount;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationPage(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1C2A),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.notifications_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      if (unread > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444), // Vibrant Red
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF1B1C2A), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 8,
                              minHeight: 8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          // const SizedBox(width: 8),
          // Settings button
          // GestureDetector(
          //   onTap: () {
          //     widget.onSetUpProfile?.call();
          //   },
          //   child: Container(
          //     padding: const EdgeInsets.all(10),
          //     decoration: BoxDecoration(
          //       color: const Color(0xFF1B1C2A),
          //       shape: BoxShape.circle,
          //       border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          //     ),
          //     child: const Icon(
          //       Icons.settings_rounded,
          //       color: Colors.white60,
          //       size: 20,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  // QR Container with Glowing Border and L-Corner brackets
  Widget _buildQRFrame(
      BuildContext context, QrImage? qrImage, ProfileProvider profileProvider) {
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
            const Color(0xFF3D3560).withValues(alpha: 0.5),
            const Color(0xFF2A2C42),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
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
                              color: Colors.white.withValues(alpha: 0.4),
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
                      ? Center(
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: PrettyQrView(
                              qrImage: qrImage,
                              decoration: const PrettyQrDecoration(
                                shape: PrettyQrSmoothSymbol(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
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
                                  color: Colors.white.withValues(alpha: 0.4),
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
                        title: "Both Cards",
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

  void _showShareOptionsBottomSheet(
      BuildContext context, ProfileProvider profileProvider) {
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
                        "Share VIP Pass Options",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Select which digital card you want to share with this VIP Pass code:",
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
                        title: "Both Cards",
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
                          Navigator.pop(context);
                          _shareProfile(profileProvider);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F2FE),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Share VIP Pass",
                          style: TextStyle(
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

    return SizedBox(
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
      BuildContext context, ProfileProvider profileProvider) {
    final hasProfile = profileProvider.userId != null &&
        profileProvider.name.trim().isNotEmpty;

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
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
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
            onTap: hasProfile
                ? () => _showShareOptionsBottomSheet(context, profileProvider)
                : null,
            child: Opacity(
              opacity: hasProfile ? 1.0 : 0.4,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.03),
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

  Widget _buildSkeletonBody(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF13141F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B1C2A),
                    shape: BoxShape.circle,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 80, height: 14, color: Colors.white),
                    const SizedBox(height: 6),
                    Container(width: 50, height: 10, color: Colors.white),
                  ],
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B1C2A),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Title
          const Text(
            "My Card",
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.8,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // QR Code / Setup Container
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                color: const Color(0xFF13141F),
              ),
              child: Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 56),

          // Quick Action Buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF13141F),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF13141F),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
