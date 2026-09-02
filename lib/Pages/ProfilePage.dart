import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:connect/services/linkrunner_service.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/Pages/NotificationPage.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:connect/Widgets/connect_hub_bottom_sheet.dart';
import 'package:connect/Config/app_theme.dart';

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
  String _selectedKeyType = 'single_use';

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

  /// Background refresh — reads from Supabase without flipping _isLoading,
  /// so the screen does not flicker with a loading spinner while pulling
  /// fresh data.
  Future<void> _refreshSilently(ProfileProvider profileProvider) async {
    try {
      final userid = profileProvider.userId;
      if (userid != null) {
        await profileProvider.loadProfile(userid);
      }
    } catch (e) {
      debugPrint("Error silently refreshing profile: $e");
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

  // Share profile details by generating a Private Key and sharing it
  void _shareProfile(ProfileProvider profileProvider) async {
    if (profileProvider.userId == null) return;

    // Show a progress dialog while generating VIP code
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: GlassmorphicContainer(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusPremiumCard),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(context.accentPrimary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Generating Private Key...",
                    style: context.cardTitle,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final code = await profileProvider.generateInviteCode(
        _selectedShareType,
        keyType: _selectedKeyType,
      );

      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
      }

      final inviteLink = LinkrunnerService.generateInviteLink(
        senderUserId: profileProvider.userId ?? '',
        inviteCode: code,
      );

      final String shareMessage;
      if (_selectedKeyType == 'group_24h') {
        shareMessage =
            "Hey everyone! I'm inviting the group to connect with me on Jana. Click here to connect within 24 hours: $inviteLink or use group key: *$code* (Active for 24 hours).";
      } else {
        shareMessage =
            "Hey, I'm inviting you to my private circle on Jana. Click here to download & connect: $inviteLink or use my single-use Private Key: *$code*.";
      }

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

    // debugPrint(
    //     "ProfilePage Build: userId=${profileProvider.userId}, hasBasicDetails=$hasBasicDetails, name='${profileProvider.name}', profession='${profileProvider.profession}', phoneNumber='${profileProvider.phoneNumber}'");

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
      backgroundColor: context.canvasBackground,
      body: SafeArea(
        child: _isLoading
            ? Skeletonizer(
                enabled: true,
                child: _buildSkeletonBody(context),
              )
            : RefreshIndicator(
                onRefresh: _refreshData,
                color: context.accentPrimary,
                backgroundColor: context.surfacePrimary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(
                      left: AppDimensions.marginStandard,
                      right: AppDimensions.marginStandard,
                      top: 16.0,
                      bottom: 100.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Personalized Profile Header
                      _buildTopHeader(context, profileProvider),
                      const SizedBox(height: 28),

                      // QR Code / Setup Card Container
                      Center(
                        child: _buildQRFrame(context, qrImage, profileProvider),
                      ),

                      // Active sharing type chip/card below QR code
                      if (hasBasicDetails && _qrGenerated) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: context.surfacePrimary,
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusPremiumCard),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.04),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Glowing/active dot indicator
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: context.accentPrimary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.accentPrimary
                                            .withValues(alpha: 0.4),
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
                                      .copyWith(fontWeight: FontWeight.w600),
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
                      const SizedBox(height: 28),

                      // Premium Asymmetric Dashboard Grid
                      _buildDashboardGrid(context, profileProvider),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // Header bar containing Name, Bio, and Avatar
  Widget _buildTopHeader(
      BuildContext context, ProfileProvider profileProvider) {
    final hasAvatar = profileProvider.avatarUrl.isNotEmpty &&
        profileProvider.avatarUrl.startsWith('http');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Name and Bio aligned perfectly to left margin grid line
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profileProvider.name.trim().isEmpty
                    ? "Welcome!"
                    : profileProvider.name,
                style: context.displayHeader,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                profileProvider.profession.trim().isEmpty
                    ? "Create your digital card below"
                    : profileProvider.profession,
                style: context.bodyText.copyWith(color: context.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Notifications and Avatar Row on the right
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                      color: context.surfacePrimary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.04)),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.notifications_rounded,
                          color: context.textSecondary,
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
                                    color: context.surfacePrimary, width: 1.5),
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
            const SizedBox(width: 12),
            // Circular avatar with minimal soft volt ring accent
            GestureDetector(
              onTap: () {
                widget.onSetUpProfile?.call();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.accentPrimary.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(2.0),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.surfaceSecondary,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasAvatar
                      ? Image.network(
                          profileProvider.avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildFallbackAvatar(profileProvider),
                        )
                      : _buildFallbackAvatar(profileProvider),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFallbackAvatar(ProfileProvider profileProvider) {
    final monogram = profileProvider.name.trim().isNotEmpty
        ? profileProvider.name.trim().substring(0, 1).toUpperCase()
        : "?";
    return Center(
      child: Text(
        monogram,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  // QR Container with Glowing Border and L-Corner brackets
  Widget _buildQRFrame(
      BuildContext context, QrImage? qrImage, ProfileProvider profileProvider) {
    const double outerSize = 280.0;
    final hasBasicDetails = profileProvider.name.trim().isNotEmpty &&
        profileProvider.profession.trim().isNotEmpty &&
        (profileProvider.phoneNumber.trim().isNotEmpty ||
            profileProvider.professionalPhoneNumber.trim().isNotEmpty);

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
      padding: const EdgeInsets.all(
          AppDimensions.marginStandard), // explicit padding
      child: Stack(
        children: [
          // Four L-Brackets in the corners using Volt Green (accentPrimary)
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

          // Inside Content: QR code, option setup, or profile setup CTA
          Center(
            child: !hasBasicDetails
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.contact_page_outlined,
                          color: context.textMuted,
                          size: 44,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "No Profile Setup",
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Create your card to generate a QR",
                          style: TextStyle(
                            color: context.textSecondary,
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
                            backgroundColor: context.accentPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusComponent),
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
                          width: 180,
                          height: 180,
                          child: PrettyQrView(
                            qrImage: qrImage,
                            decoration: PrettyQrDecoration(
                              shape: PrettyQrSmoothSymbol(
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              color: context.textMuted,
                              size: 44,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Ready to Connect",
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Choose what you want to share before scanning",
                              style: TextStyle(
                                color: context.textSecondary,
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
                                backgroundColor: context.accentPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusComponent),
                                ),
                              ),
                              child: const Text(
                                "Generate QR",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )),
          ),
        ],
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
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.accentPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusComponent),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Generate QR Code",
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

  void _showShareOptionsBottomSheet(
      BuildContext context, ProfileProvider profileProvider) {
    String tempShareType = _selectedShareType;
    String tempKeyType = _selectedKeyType;

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
                        "Share Private Key Options",
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Select key duration and which digital card to share:",
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 1. Key Type Section
                      Text(
                        "KEY TYPE & DURATION",
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildOptionTile(
                        title: "Single-Use Key",
                        subtitle: "Expires once used. Perfect for personal 1-on-1 sharing.",
                        value: "single_use",
                        groupValue: tempKeyType,
                        onChanged: (val) {
                          setModalState(() {
                            tempKeyType = val!;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildOptionTile(
                        title: "24-Hour Group Key",
                        subtitle: "Active for 24 hours. Multiple people can join via link or key.",
                        value: "group_24h",
                        groupValue: tempKeyType,
                        onChanged: (val) {
                          setModalState(() {
                            tempKeyType = val!;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      // 2. Card to Share Section
                      Text(
                        "DIGITAL CARD TO SHARE",
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildOptionTile(
                        title: "Casual Card Only",
                        subtitle: "Share bio, socials, name & basic details.",
                        value: "casual",
                        groupValue: tempShareType,
                        onChanged: (val) {
                          setModalState(() {
                            tempShareType = val!;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildOptionTile(
                        title: "Professional Card Only",
                        subtitle:
                            "Share company, email, phone & professional bio.",
                        value: "professional",
                        groupValue: tempShareType,
                        onChanged: (val) {
                          setModalState(() {
                            tempShareType = val!;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          _selectedShareType = tempShareType;
                          _selectedKeyType = tempKeyType;
                          Navigator.pop(context);
                          _shareProfile(profileProvider);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.accentPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusComponent),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Share Private Key",
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
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? context.accentPrimary : context.textMuted,
                  width: 2.0,
                ),
              ),
              padding: const EdgeInsets.all(3.0),
              child: isSelected
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.accentPrimary,
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
  Widget _buildCornerBracket(
      {required bool top, required bool left, required Color color}) {
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

  // ─── Premium Asymmetric Dashboard Grid ───────────────────────────────────
  Widget _buildDashboardGrid(
      BuildContext context, ProfileProvider profileProvider) {
    final hasProfile = profileProvider.userId != null &&
        profileProvider.name.trim().isNotEmpty;

    const double gap = 12.0;
    const double radius = AppDimensions.radiusPremiumCard;

    // ── Shared helpers ──────────────────────────────────────────────────
    BoxDecoration darkCard() => BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: context.borderMuted, width: 1.0),
        );

    // ── Arrow icon widget ────────────────────────────────────────────────
    Widget arrowIcon({Color color = Colors.white}) => Text(
          '↗',
          style: TextStyle(
            color: color.withValues(alpha: 0.5),
            fontSize: 14,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        );

    // ── LEFT COLUMN ─────────────────────────────────────────────────────

    // Card 1 – Edit Profile (premium hero card)
    // final editProfileCard = GestureDetector(
    //   onTap: () => widget.onSetUpProfile?.call(),
    //   child: Container(
    //     height: 120,
    //     decoration: darkCard(),
    //     padding: cardPad,
    //     child: Column(
    //       crossAxisAlignment: CrossAxisAlignment.start,
    //       children: [
    //         Row(
    //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //           crossAxisAlignment: CrossAxisAlignment.start,
    //           children: [
    //             Container(
    //               padding: const EdgeInsets.all(9),
    //               decoration: BoxDecoration(
    //                 color: context.surfaceSecondary,
    //                 shape: BoxShape.circle,
    //               ),
    //               child: Icon(
    //                 Icons.edit_rounded,
    //                 color: context.accentPrimary,
    //                 size: 16,
    //               ),
    //             ),
    //             Column(
    //               children: [
    //                 Text(
    //                   'Edit Profile',
    //                   style: context.cardTitle,
    //                   maxLines: 1,
    //                   overflow: TextOverflow.ellipsis,
    //                 ),
    //                 const SizedBox(height: 4),
    //                 Text(
    //                   'Update name, bio & socials',
    //                   style: context.captionText.copyWith(
    //                     color: context.textSecondary,
    //                     fontWeight: FontWeight.w400,
    //                   ),
    //                   maxLines: 1,
    //                   overflow: TextOverflow.ellipsis,
    //                 ),
    //               ],
    //             ),
    //             arrowIcon(),
    //           ],
    //         ),
    //         // const Spacer(),
    //         // Text(
    //         //   'Edit Profile',
    //         //   style: context.cardTitle,
    //         //   maxLines: 1,
    //         //   overflow: TextOverflow.ellipsis,
    //         // ),
    //         // const SizedBox(height: 4),
    //         // Text(
    //         //   'Update name, bio & socials',
    //         //   style: context.captionText.copyWith(
    //         //     color: context.textSecondary,
    //         //     fontWeight: FontWeight.w400,
    //         //   ),
    //         //   maxLines: 1,
    //         //   overflow: TextOverflow.ellipsis,
    //         // ),
    //       ],
    //     ),
    //   ),
    // );

    // Shared compact card builder (premium horizontal list tile style)
    Widget compactCard({
      required IconData icon,
      required String label,
      required String subtitle,
      required VoidCallback? onTap,
      bool disabled = false,
      Color? iconColor,
    }) =>
        Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: GestureDetector(
            onTap: disabled ? null : onTap,
            child: Container(
              height: 76,
              decoration: darkCard(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.surfaceSecondary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? context.accentPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: context.cardTitle.copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: context.captionText.copyWith(
                            color: context.textMuted,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  arrowIcon(),
                ],
              ),
            ),
          ),
        );

    final scanCard = compactCard(
      icon: Icons.person_add_rounded,
      label: 'Connect Hub',
      subtitle: 'Scan QR, Show QR, or Add Code',
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const ConnectHubBottomSheet(),
        ).then((_) => _refreshData());
      },
    );

    final editProfileCard = compactCard(
      icon: Icons.edit_rounded,
      label: 'Edit Profile',
      subtitle: 'Update name, bio & socials',
      onTap: () => widget.onSetUpProfile?.call(),
    );

    final shareCard = compactCard(
      icon: Icons.share_rounded,
      label: 'Share Link',
      subtitle: 'Send your Private Key',
      disabled: !hasProfile,
      onTap: () => _showShareOptionsBottomSheet(context, profileProvider),
    );

    // ── Assemble Column ──────────────────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        editProfileCard,
        const SizedBox(height: gap),
        scanCard,
        const SizedBox(height: gap),
        shareCard,
        // const SizedBox(height: gap),
        // blurCard,
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
          // Header Bar Skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 140, height: 28, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(width: 180, height: 14, color: Colors.white),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // QR Code Container Skeleton
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusPremiumCard),
                color: Colors.white,
              ),
              child: Center(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Dashboard Grid Skeleton
          Column(
            children: [
              Container(
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusPremiumCard),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusPremiumCard),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusPremiumCard),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusPremiumCard),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
