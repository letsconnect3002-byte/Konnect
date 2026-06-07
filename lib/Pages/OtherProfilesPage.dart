import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:connect/Pages/QrCodeScanner.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/Utils/profile_field_filter.dart';

class OtherProfilesPage extends StatefulWidget {
  const OtherProfilesPage({super.key});

  @override
  State<OtherProfilesPage> createState() => _OtherProfilesPageState();
}

class _OtherProfilesPageState extends State<OtherProfilesPage> {
  bool _isGridView =
      false; // true = Card View, false = List View (List is default)
  late ConnectionProvider connectionProvider;

  @override
  void initState() {
    super.initState();
    _loadDeletedProfiles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
        setState(() {});
      }
    });
  }

  void _showRedeemVipDialog(BuildContext context, ConnectionProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        String selectedType = 'casual';
        final TextEditingController controller = TextEditingController();
        bool isDialogLoading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF131422),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF26273C), width: 1.5),
              ),
              title: const Text(
                "Redeem VIP Pass",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              content: isDialogLoading
                  ? const SizedBox(
                      height: 150,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Enter the 6-character VIP code to connect immediately.",
                          style: TextStyle(
                            color: Color(0xFF8B8C9E),
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
                          decoration: InputDecoration(
                            hintText: "MNDL-XXXXXX",
                            hintStyle: const TextStyle(color: Colors.white24, fontFamily: 'Inter'),
                            filled: true,
                            fillColor: const Color(0xFF0A0A0F),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF26273C)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF00F2FE)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "SHARE BACK YOUR CARD",
                          style: TextStyle(
                            color: Color(0xFF8B8C9E),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedType = 'casual';
                                  });
                                },
                                child: Container(
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selectedType == 'casual'
                                        ? const Color(0xFF8B5CF6).withOpacity(0.1)
                                        : const Color(0xFF0A0A0F),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selectedType == 'casual'
                                          ? const Color(0xFF8B5CF6)
                                          : const Color(0xFF26273C),
                                    ),
                                  ),
                                  child: const Text(
                                    "Casual",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedType = 'professional';
                                  });
                                },
                                child: Container(
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selectedType == 'professional'
                                        ? const Color(0xFF00F2FE).withOpacity(0.1)
                                        : const Color(0xFF0A0A0F),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selectedType == 'professional'
                                          ? const Color(0xFF00F2FE)
                                          : const Color(0xFF26273C),
                                    ),
                                  ),
                                  child: const Text(
                                    "Professional",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
              actions: isDialogLoading
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.white54, fontFamily: 'Inter'),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final codeStr = controller.text.trim();
                          if (codeStr.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please enter a VIP code")),
                            );
                            return;
                          }
                          
                          setState(() {
                            isDialogLoading = true;
                          });
                          
                          try {
                            await provider.redeemInviteCode(codeStr, selectedType);
                            // Refresh connection list
                            await provider.fetchConnections();
                            if (context.mounted) {
                              await Provider.of<ChatProvider>(context, listen: false).updateUnreadCount();
                            }
                            
                            if (context.mounted) {
                              Navigator.pop(context); // Dismiss dialog
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF00F2FE)),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          "Successfully connected with VIP Pass!",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Inter',
                                          ),
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
                            }
                          } catch (e) {
                            setState(() {
                              isDialogLoading = false;
                            });
                            String errorMsg = e.toString();
                            if (errorMsg.contains("Exception:")) {
                              errorMsg = errorMsg.replaceAll("Exception:", "").trim();
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Failed to redeem: $errorMsg"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F2FE),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Redeem",
                          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                        ),
                      ),
                    ],
            );
          },
        );
      },
    );
  }



  Future<void> _loadDeletedProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('deleted_profile_ids') ?? [];
      // Profiles are stored in local preferences, no extra state needed
      print("Loaded ${list.length} deleted profile IDs locally.");
    } catch (e) {
      print("Error loading deleted profiles: $e");
    }
  }

  Future<void> _deleteProfileLocally(
      String id, ConnectionProvider provider) async {
    try {
      final intId = int.tryParse(id) ?? 0;
      await provider.deleteProfile(intId, onRoomCleanup: (profileId, roomId) async {
        await Provider.of<ChatProvider>(context, listen: false).handleRoomCleanup(profileId, roomId);
      });
    } catch (e) {
      print("Error deleting profile locally: $e");
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context,
      Map<String, dynamic> connection, ConnectionProvider provider) async {
    final name = connection['name'] ?? 'this contact';
    final profileIdStr = (connection['id'] ?? '').toString();

    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF13141F),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Delete Connection",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to remove $name from your connections? This will permanently delete this connection and clear all chat history and text messages.",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: const Text("Delete",
                  style: TextStyle(color: Colors.redAccent)),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await _deleteProfileLocally(profileIdStr, provider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Connection and chat history deleted"),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error deleting connection: $e")),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Return the actual avatar URL from the database, or empty if none
  String _getAvatarUrl(String name, String? existingUrl) {
    if (existingUrl != null &&
        existingUrl.isNotEmpty &&
        existingUrl.startsWith('http')) {
      return existingUrl;
    }
    return '';
  }

  String _getCompany(String name, String? existingCompany) {
    return existingCompany ?? '';
  }



  List<String> _getCardTypesForProfile(Map<String, dynamic> profile) {
    if (profile.containsKey('cardTypes')) {
      return List<String>.from(profile['cardTypes']);
    }

    final allTypes = <String>[];

    final hasInstagram = (profile['instagram'] ?? '').toString().isNotEmpty;
    final hasTwitter = (profile['twitter'] ?? '').toString().isNotEmpty;
    final hasCasualBio = (profile['bio'] ?? '').toString().isNotEmpty;

    final hasLinkedin = (profile['linkedin'] ?? '').toString().isNotEmpty;
    final hasCompany = (profile['company'] ?? '').toString().isNotEmpty;
    final hasEmail = (profile['email'] ?? '').toString().isNotEmpty;

    if (hasInstagram ||
        hasTwitter ||
        hasCasualBio ||
        (!hasLinkedin && !hasCompany)) {
      allTypes.add('casual');
    }
    if (hasLinkedin || hasCompany || hasEmail) {
      allTypes.add('professional');
    }

    if (allTypes.isEmpty) {
      allTypes.addAll(['casual', 'professional']);
    }

    return allTypes;
  }

  Widget _buildCardTypeBadges(Map<String, dynamic> profile) {
    final types = _getCardTypesForProfile(profile);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final type in types) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: type == 'casual'
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                  : const Color(0xFF00F2FE).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: type == 'casual'
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.35)
                    : const Color(0xFF00F2FE).withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Text(
              type == 'casual' ? 'CASUAL' : 'PROFESSIONAL',
              style: TextStyle(
                color: type == 'casual'
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF00F2FE),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
  }


  Widget _buildCircularActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF161726),
          border: Border.all(color: const Color(0xFF26273F), width: 1),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildToggleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "ALL CARDS",
            style: TextStyle(
              color: Color(0xFF5C5E78),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontFamily: 'Inter',
            ),
          ),
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF10111F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF202138), width: 1),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isGridView = true;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _isGridView
                          ? const Color(0xFF8B5CF6)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      color:
                          _isGridView ? Colors.white : const Color(0xFF5C5E78),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isGridView = false;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 34,
                    decoration: BoxDecoration(
                      color: !_isGridView
                          ? const Color(0xFF8B5CF6)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.view_list_rounded,
                      size: 18,
                      color:
                          !_isGridView ? Colors.white : const Color(0xFF5C5E78),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(
      Map<String, dynamic> profileData, ConnectionProvider provider) {
    final name = profileData["name"] ?? "Unknown";
    final profession = profileData["profession"] ?? "";
    final String sharedCard = (profileData['sharedCard'] ?? profileData['shared_card'] ?? 'both').toString();
    final String email = ProfileFieldFilter.getVisibleValue(
      'email',
      profileData["email"] ?? '',
      sharedCard,
      profileData['field_assignments'],
    );
    final String company = ProfileFieldFilter.getVisibleValue(
      'company',
      _getCompany(name, profileData["company"]),
      sharedCard,
      profileData['field_assignments'],
    );
    final avatarUrl = _getAvatarUrl(name, profileData["avatarUrl"]);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConnectionProfilePage(
              profileData: profileData,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B1B3A),
              Color(0xFF0C0C18),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF26273F),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF00F2FE), Color(0xFF8B5CF6)],
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF090A0F),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: (avatarUrl.isNotEmpty &&
                              avatarUrl.contains(
                                  'supabase.co/storage/v1/object/public/avatars/'))
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: const Color(0xFF1B1C2A),
                                alignment: Alignment.center,
                                child: Text(
                                  name.isNotEmpty
                                      ? name.substring(0, 1).toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF1B1C2A),
                              alignment: Alignment.center,
                              child: Text(
                                name.isNotEmpty
                                    ? name.substring(0, 1).toUpperCase()
                                    : "?",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 2),
                      Text(
                        profession,
                        style: const TextStyle(
                          color: Color(0xFF8B8C9E),
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _buildCardTypeBadges(profileData),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<int>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert_rounded,
                          color: Color(0xFF5C5E78)),
                      color: const Color(0xFF10111F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF202138)),
                      ),
                      onSelected: (val) {
                        if (val == 1) {
                          _showDeleteConfirmation(
                              context, profileData, provider);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 1,
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text("Delete",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: const Color(0xFF1F2032),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (company.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.business_center_rounded,
                          color: Color(0xFF5C5E78), size: 14),
                      const SizedBox(width: 8),
                      Text(
                        company,
                        style: const TextStyle(
                          color: Color(0xFFC0C1D0),
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (email.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.alternate_email_rounded,
                          color: Color(0xFF5C5E78), size: 14),
                      const SizedBox(width: 8),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Color(0xFFC0C1D0),
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IndividualChatPage(
                            connectionData: profileData,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                        size: 16, color: Colors.white),
                    label: const Text(
                      "Message",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(
      Map<String, dynamic> profileData, ConnectionProvider provider) {
    final name = profileData["name"] ?? "Unknown";
    final profession = profileData["profession"] ?? "";
    final String sharedCard = (profileData['sharedCard'] ?? profileData['shared_card'] ?? 'both').toString();
    final String company = ProfileFieldFilter.getVisibleValue(
      'company',
      _getCompany(name, profileData["company"]),
      sharedCard,
      profileData['field_assignments'],
    );
    final avatarUrl = _getAvatarUrl(name, profileData["avatarUrl"]);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConnectionProfilePage(
              profileData: profileData,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF10111F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1F2035), width: 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00F2FE), Color(0xFF8B5CF6)],
                ),
              ),
              padding: const EdgeInsets.all(1.5),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF090A0F),
                ),
                padding: const EdgeInsets.all(1.5),
                child: ClipOval(
                  child: (avatarUrl.isNotEmpty &&
                          avatarUrl.contains(
                              'supabase.co/storage/v1/object/public/avatars/'))
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: const Color(0xFF1B1C2A),
                            alignment: Alignment.center,
                            child: Text(
                              name.isNotEmpty
                                  ? name.substring(0, 1).toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF1B1C2A),
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty
                                ? name.substring(0, 1).toUpperCase()
                                : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    profession.isNotEmpty && company.isNotEmpty
                        ? "$profession  •  $company"
                        : (profession.isNotEmpty ? profession : company),
                    style: const TextStyle(
                      color: Color(0xFF8B8C9E),
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  _buildCardTypeBadges(profileData),
                ],
              ),
            ),
            PopupMenuButton<int>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert_rounded,
                  color: Color(0xFF5C5E78), size: 20),
              color: const Color(0xFF10111F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF202138)),
              ),
              onSelected: (val) {
                if (val == 1) {
                  _showDeleteConfirmation(context, profileData, provider);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 18),
                      SizedBox(width: 8),
                      Text("Delete",
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();
    final allProfiles = provider.connections;
    final count = allProfiles.length;

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Premium Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Konnections",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$count ${count == 1 ? 'connection' : 'connections'}",
                        style: const TextStyle(
                          color: Color(0xFF8B8C9E),
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildCircularActionButton(
                        icon: Icons.key_rounded,
                        onPressed: () {
                          _showRedeemVipDialog(context, provider);
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildCircularActionButton(
                        icon: Icons.qr_code_scanner_rounded,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const QRScannerPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Toggle Switch Row
            _buildToggleRow(),
            // Connection Content list or loading
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: allProfiles.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              color: Color(0xFF5C5E78),
                              size: 48,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "No profiles available.",
                              style: TextStyle(
                                color: Color(0xFF8B8C9E),
                                fontSize: 15,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        key: ValueKey<bool>(_isGridView),
                        itemCount: allProfiles.length,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        itemBuilder: (context, index) {
                          final item = allProfiles[index];
                          return _isGridView
                              ? _buildCardItem(item, provider)
                              : _buildListItem(item, provider);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
