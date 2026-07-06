import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';

import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Pages/QrCodeScanner.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/main.dart';

class ConnectHubBottomSheet extends StatefulWidget {
  final String initialShareType;
  const ConnectHubBottomSheet({super.key, this.initialShareType = 'casual'});

  @override
  State<ConnectHubBottomSheet> createState() => _ConnectHubBottomSheetState();
}

class _ConnectHubBottomSheetState extends State<ConnectHubBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _codeController = TextEditingController();

  bool _isRedeeming = false;
  bool _isGeneratingCode = false;
  String? _generatedInviteCode;
  QrImage? _qrImage;
  bool _qrGenerationError = false;
  String _selectedShareType = 'casual';
  bool _qrGenerated = false;

  @override
  void initState() {
    super.initState();
    _selectedShareType = widget.initialShareType;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {});
  }

  void _initializeQrCode() {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final userId = profileProvider.userId;
    if (userId == null) return;

    try {
      final String qrData = jsonEncode({
        "userId": userId,
        "sharedCard": _selectedShareType,
      });

      final qrCode = QrCode.fromData(
        data: qrData,
        errorCorrectLevel: QrErrorCorrectLevel.H,
      );

      setState(() {
        _qrImage = QrImage(qrCode);
        _qrGenerationError = false;
      });
    } catch (e) {
      debugPrint("Error generating personal QR Code: $e");
      setState(() {
        _qrGenerationError = true;
      });
    }
  }

  Future<void> _generateInviteCode() async {
    if (_isGeneratingCode) return;
    setState(() {
      _isGeneratingCode = true;
    });

    try {
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final code = await profileProvider.generateInviteCode(_selectedShareType);
      if (mounted) {
        setState(() {
          _generatedInviteCode = code;
          _isGeneratingCode = false;
        });
      }
    } catch (e) {
      debugPrint("Error generating invite code: $e");
      if (mounted) {
        setState(() {
          _isGeneratingCode = false;
        });
      }
    }
  }

  Future<void> _redeemInviteCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isRedeeming = true;
    });

    try {
      final connectionProvider =
          Provider.of<ConnectionProvider>(context, listen: false);

      await connectionProvider.redeemInviteCode(code, "both");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: context.accentPrimary),
                const SizedBox(width: 10),
                const Text(
                  "Successfully connected!",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: context.surfacePrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusComponent),
              side: BorderSide(color: context.surfaceSecondary, width: 1.5),
            ),
          ),
        );
        Navigator.pop(context); // Close the bottom sheet
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Connection failed: ${e.toString().replaceAll("Exception: ", "")}",
              style: const TextStyle(fontFamily: 'Inter', color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRedeeming = false;
        });
      }
    }
  }

  void _openCameraScanner() {
    Navigator.pop(context); // Close bottom sheet first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerPage(),
      ),
    );
  }

  void _copyToClipboard() {
    if (_generatedInviteCode == null) return;
    Clipboard.setData(ClipboardData(text: _generatedInviteCode!));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "Invite Code copied to clipboard!",
          style: TextStyle(fontFamily: 'Inter'),
        ),
        backgroundColor: context.surfacePrimary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareInviteLink() async {
    if (_generatedInviteCode == null) return;
    final shareMessage =
        "Hey! Connect with me on Jana using my connection code: $_generatedInviteCode. Let's start messaging privately.";
    await SharePlus.instance.share(ShareParams(text: shareMessage));
  }

  // Bracket Drawing Helper
  Widget _buildCornerBracket({
    required bool top,
    required bool left,
    required Color color,
  }) {
    const double lineSize = 18.0;
    const double thickness = 3.0;

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
                color: color,
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
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Top Identity Header

  // QR Container with Glowing Border and L-Corner brackets
  Widget _buildQRFrame(BuildContext context, QrImage? qrImage) {
    const double outerSize = 250.0;

    return Container(
      width: outerSize,
      height: outerSize,
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPremiumCard),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppDimensions.marginStandard),
      child: Stack(
        children: [
          // Four corner brackets
          Positioned(
            top: 0,
            left: 0,
            child: _buildCornerBracket(
                top: true, left: true, color: context.accentPrimary),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: _buildCornerBracket(
                top: true, left: false, color: context.accentPrimary),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: _buildCornerBracket(
                top: false, left: true, color: context.accentPrimary),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: _buildCornerBracket(
                top: false, left: false, color: context.accentPrimary),
          ),

          // QR Display Module
          Center(
            child: !_qrGenerated
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_2_rounded,
                        color: context.textMuted.withValues(alpha: 0.15),
                        size: 80,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _showQrOptionsBottomSheet(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.accentPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Generate QR",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  )
                : qrImage != null && !_qrGenerationError
                    ? SizedBox(
                        width: 160,
                        height: 160,
                        child: PrettyQrView(
                          qrImage: qrImage,
                          decoration: PrettyQrDecoration(
                            shape: PrettyQrSmoothSymbol(
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                      )
                    : const CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }

  // Options Sheet trigger for Sharing types
  void _showQrOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return GlassmorphicContainer(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusPremiumCard)),
              border: Border(
                top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.04), width: 1),
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
                            color: context.surfaceSecondary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Share Identity Options",
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Select which digital card you want to share with this QR Code scan:",
                        style: TextStyle(
                          color: context.textSecondary,
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
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _qrGenerated = true;
                          });
                          _initializeQrCode();
                          if (_generatedInviteCode != null) {
                            _generateInviteCode();
                          }
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.accentPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Apply Selection",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                            fontSize: 14,
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
          color: isSelected ? context.surfaceSecondary : context.surfacePrimary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          border: Border.all(
            color: isSelected
                ? context.accentPrimary
                : Colors.white.withValues(alpha: 0.04),
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
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: context.accentPrimary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E17).withValues(alpha: 0.93),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: context.surfaceSecondary, width: 1.5),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottom sheet drag handle
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Connect Hub",
                      style: context.screenHeading.copyWith(fontSize: 20),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: context.surfacePrimary,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Glassmorphic Custom Tab Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.surfacePrimary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.transparent,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: context.textMuted,
                    labelStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.qr_code_scanner_rounded, size: 16),
                            SizedBox(width: 8),
                            Text("Scan QR Code"),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.qr_code_rounded, size: 16),
                            SizedBox(width: 8),
                            Text("My QR Code"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tab Bar Content (Explicit view heights)
              SizedBox(
                height:
                    575, // Increased height to fit matching ProfilePage style
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildScanTab(),
                    _buildMyCodeTab(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Pulsing camera layout box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: context.surfacePrimary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.surfaceSecondary,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                // Glowing circle camera icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        context.accentPrimary.withValues(alpha: 0.2),
                        context.accentSecondary.withValues(alpha: 0.2),
                      ],
                    ),
                    border: Border.all(
                      color: context.accentPrimary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: context.accentPrimary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Scan QR Code",
                  style: context.bodyText.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Point your camera at a friend's profile QR code to connect instantly.",
                  textAlign: TextAlign.center,
                  style: context.captionText.copyWith(
                    color: context.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                // Scanner Trigger Button
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        context.accentPrimary,
                        context.accentPrimary.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _openCameraScanner,
                    icon: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 18),
                    label: const Text(
                      "Open Camera Scanner",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Manual invite code redeem segment
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.surfacePrimary,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: context.surfaceSecondary, width: 1.5),
                  ),
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                    decoration: InputDecoration(
                      hintText: "Enter invite code: MNDL-XXXXXX",
                      hintStyle: TextStyle(
                        color: context.textMuted,
                        fontWeight: FontWeight.normal,
                        letterSpacing: 0.0,
                        fontSize: 12,
                      ),
                      prefixIcon: Icon(Icons.vpn_key_rounded,
                          color: context.textSecondary, size: 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Submit manual button
              GestureDetector(
                onTap: _isRedeeming ? null : _redeemInviteCode,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: context.accentSecondary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _isRedeeming
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            "Connect",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                              fontSize: 13,
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

  Widget _buildMyCodeTab() {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final userId = profileProvider.userId;

    if (userId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_rounded,
                  color: context.textSecondary, size: 48),
              const SizedBox(height: 16),
              Text(
                "Profile Not Configured",
                style: context.bodyText.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                "Please configure your profile first in the Settings/Profile screen to generate your connection QR Code.",
                textAlign: TextAlign.center,
                style:
                    context.captionText.copyWith(color: context.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final bool isComplete = _checkIsProfileComplete(profileProvider);
    if (!isComplete) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: _buildIncompleteProfileCard(profileProvider),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),

          // Centered QR container card with corner brackets (Exactly like ProfilePage.dart)
          Center(
            child: _buildQRFrame(context, _qrImage),
          ),
          const SizedBox(height: 16),

          if (_qrGenerated) ...[
            // Active sharing type chip/card below QR code
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: context.surfacePrimary,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusPremiumCard),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glowing dot indicator
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.accentPrimary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: context.accentPrimary.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Sharing: ${_selectedShareType.toUpperCase()}",
                      style: context.bodyText
                          .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
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
                      onTap: () => _showQrOptionsBottomSheet(context),
                      child: Text(
                        "Change",
                        style: TextStyle(
                          color: context.accentPrimary,
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
          const SizedBox(height: 20),

          // Invite Code text and share action buttons
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: context.surfacePrimary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.surfaceSecondary,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                if (_isGeneratingCode)
                  const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                else if (_generatedInviteCode == null)
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "No active Private Key generated",
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _generateInviteCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.accentPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Generate Private Key",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _generatedInviteCode!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _copyToClipboard,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.copy_all_rounded,
                            color: context.accentPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _generatedInviteCode == null
                            ? null
                            : _copyToClipboard,
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text(
                          "Copy Code",
                          style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                              color: context.surfaceSecondary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _generatedInviteCode == null
                            ? null
                            : _shareInviteLink,
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text(
                          "Share Invite",
                          style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.accentSecondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  bool _checkIsProfileComplete(ProfileProvider provider) {
    final String name = provider.name.trim();

    // Name check: not empty and not default "Jane Doe"
    final bool hasName = name.isNotEmpty && name.toLowerCase() != 'jane doe';

    // Email check: either casual email or professional email is filled
    final bool hasEmail = provider.email.trim().isNotEmpty ||
        provider.professionalEmail.trim().isNotEmpty;

    return hasName && hasEmail;
  }

  Widget _buildIncompleteProfileCard(ProfileProvider provider) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151624),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  "Setup Required",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "To generate your personal QR code and private sharing keys, please complete your name and email settings first.",
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              height: 1.4,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Switch to the Profile tab index (4) using global appShellKey
              appShellKey.currentState?.setSelectedIndex(4);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            child: const Text(
              "Go to Profile",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
