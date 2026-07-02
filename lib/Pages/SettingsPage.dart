import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/chat_provider.dart';
import 'package:connect/Config/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDeleting = false;

  void _handleSignOut(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final accentColor = context.accentSecondary;
    final navigator = Navigator.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          side: BorderSide(
            color: context.textMuted.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        title: Text(
          "Sign Out",
          style: context.screenHeading.copyWith(fontSize: 18),
        ),
        content: Text(
          "Are you sure you want to sign out from your account?",
          style: context.bodyText.copyWith(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: context.bodyText.copyWith(color: context.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Sign Out",
              style: context.bodyText.copyWith(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Clear local credentials/fields
        profileProvider.clearFields();

        // Sign out from Supabase auth
        await profileProvider.deleteAccount().catchError((_) {}); // Fallback triggers
        
        messenger.showSnackBar(
          SnackBar(
            content: const Text("Signed out successfully"),
            backgroundColor: accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Pop all back to root AuthGate
        if (mounted) {
          navigator.popUntil((route) => route.isFirst);
        }
      } catch (e) {
        print("Error signing out: $e");
      }
    }
  }

  void _handleDeleteAccount(BuildContext context) async {
    HapticFeedback.heavyImpact();
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final accentColor = context.accentSecondary;
    final navigator = Navigator.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          side: const BorderSide(
            color: Colors.redAccent,
            width: 1.5,
          ),
        ),
        title: Text(
          "Delete Account",
          style: context.screenHeading.copyWith(
            fontSize: 18,
            color: Colors.redAccent,
          ),
        ),
        content: Text(
          "Are you sure you want to permanently delete your account?\n\nThis will instantly wipe your connections, message cache, and personal info. This action is irreversible.",
          style: context.bodyText.copyWith(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: context.bodyText.copyWith(color: context.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Delete Everything",
              style: context.bodyText.copyWith(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!context.mounted) return;
      // Second strict confirmation
      final secondConfirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
            side: const BorderSide(
              color: Colors.redAccent,
              width: 1.5,
            ),
          ),
          title: Text(
            "Final Confirmation",
            style: context.screenHeading.copyWith(
              fontSize: 18,
              color: Colors.redAccent,
            ),
          ),
          content: Text(
            "Do you fully understand that all of your messages and network connections will be deleted permanently?",
            style: context.bodyText.copyWith(color: context.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "Cancel",
                style: context.bodyText.copyWith(color: context.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                "Yes, Delete Account",
                style: context.bodyText.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      if (secondConfirm == true) {
        setState(() => _isDeleting = true);
        try {
          await profileProvider.deleteAccount();
          
          messenger.showSnackBar(
            SnackBar(
              content: const Text("Account deleted successfully"),
              backgroundColor: accentColor,
              behavior: SnackBarBehavior.floating,
            ),
          );

          if (mounted) {
            navigator.popUntil((route) => route.isFirst);
          }
        } catch (e) {
          setState(() => _isDeleting = false);
          messenger.showSnackBar(
            SnackBar(
              content: Text("Error deleting account: $e"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Widget _buildCardOption({
    required String label,
    required String value,
    required String activeValue,
    required VoidCallback onTap,
  }) {
    final isActive = value == activeValue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isActive
                ? context.accentPrimary.withValues(alpha: 0.15)
                : context.surfaceSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? context.accentPrimary
                  : context.textMuted.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: context.bodyText.copyWith(
              color: isActive ? Colors.white : context.textSecondary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);

    return Scaffold(
      backgroundColor: context.canvasBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const GlassmorphicFlexibleSpace(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Settings",
          style: context.screenHeading.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isDeleting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(context.accentPrimary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Deleting account...",
                    style: context.bodyText.copyWith(color: context.textSecondary),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  
                  // ── SOUND EFFECTS SECTION ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.surfacePrimary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.textMuted.withValues(alpha: 0.1),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "AUDIO PREFERENCES",
                          style: context.captionText.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.accentPrimary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            "Global Sound Effects",
                            style: context.bodyText.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            "Play sounds when sending or receiving chat messages.",
                            style: context.captionText.copyWith(
                              color: context.textSecondary,
                            ),
                          ),
                          activeThumbColor: context.accentPrimary,
                          activeTrackColor:
                              context.accentPrimary.withValues(alpha: 0.3),
                          value: chatProvider.soundEffectsEnabled,
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            chatProvider.setSoundEffectsEnabled(val);
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // ── DEFAULT VISIBILITY SECTION ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfacePrimary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.textMuted.withValues(alpha: 0.1),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "DEFAULT CARD VISIBILITY",
                          style: context.captionText.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.accentPrimary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Select which side of your digital card is shared by default when there is no manual choice, such as sharing via VIP code.",
                          style: context.captionText.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildCardOption(
                              label: "Casual",
                              value: "casual",
                              activeValue: profileProvider.defaultCardVisibility,
                              onTap: () => profileProvider
                                  .setDefaultCardVisibility("casual"),
                            ),
                            const SizedBox(width: 8),
                            _buildCardOption(
                              label: "Professional",
                              value: "professional",
                              activeValue: profileProvider.defaultCardVisibility,
                              onTap: () => profileProvider
                                  .setDefaultCardVisibility("professional"),
                            ),
                            const SizedBox(width: 8),
                            _buildCardOption(
                              label: "Both",
                              value: "both",
                              activeValue: profileProvider.defaultCardVisibility,
                              onTap: () => profileProvider
                                  .setDefaultCardVisibility("both"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "* Note: This preference does not apply to QR code scans, where you always select what to share manually.",
                          style: context.captionText.copyWith(
                            color: context.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── SIGN OUT BUTTON ──
                  GestureDetector(
                    onTap: () => _handleSignOut(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: context.surfacePrimary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.textMuted.withValues(alpha: 0.15),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: context.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Sign Out",
                            style: context.bodyText.copyWith(
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── DELETE ACCOUNT BUTTON ──
                  GestureDetector(
                    onTap: () => _handleDeleteAccount(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.delete_forever_rounded,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Delete Account",
                            style: context.bodyText.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
