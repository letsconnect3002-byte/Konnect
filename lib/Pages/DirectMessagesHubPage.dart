import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:connect/Providers/ProviderSQL.dart';
import 'package:connect/Providers/LocalDatabaseHelper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class DirectMessagesHubPage extends StatefulWidget {
  const DirectMessagesHubPage({super.key});

  @override
  State<DirectMessagesHubPage> createState() => _DirectMessagesHubPageState();
}

class _DirectMessagesHubPageState extends State<DirectMessagesHubPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTab = 'casual';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ProfileProvider2>(context, listen: false);
      if (provider.userId != -1) {
        provider.subscribeToConnections();
      } else {
        provider.fetchAndSetUserId2(true).then((uid) {
          if (uid != -1) {
            provider.subscribeToConnections();
          }
        });
      }
    });
  }

  List<String> _getCardTypesForConnection(Map<String, dynamic> connection) {
    final sharedCard = (connection['my_shared_card'] ?? connection['shared_card'] ?? connection['sharedCard'] ?? 'both').toString().toLowerCase();
    if (sharedCard == 'casual') {
      return ['casual'];
    } else if (sharedCard == 'professional') {
      return ['professional'];
    } else {
      return ['casual', 'professional'];
    }
  }

  Future<Map<String, dynamic>?> _getLastMessage(String? roomId) async {
    if (roomId == null) return null;
    return await LocalDatabaseHelper.instance.getLastMessageForRoom(roomId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatMessageTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();

      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      final timeStr = "$hour:$minute $period";

      if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
        return timeStr;
      }

      final yesterday = DateTime(now.year, now.month, now.day - 1);
      if (dateTime.year == yesterday.year && dateTime.month == yesterday.month && dateTime.day == yesterday.day) {
        return "Yesterday";
      }

      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    } catch (_) {
      return '';
    }
  }

  String _getAvatarUrl(String name, String? existingUrl) {
    if (existingUrl != null && existingUrl.isNotEmpty && existingUrl.startsWith('http')) {
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
    return '';
  }

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
            "Are you sure you want to remove ${connection['name'] ?? 'this contact'} from your connections?",
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
    final provider = Provider.of<ProfileProvider2>(context);
    final connections = provider.connections;

    // Filter connections based on tab and query
    final filteredConnections = connections.where((c) {
      final cardTypes = _getCardTypesForConnection(c);
      if (!cardTypes.contains(_selectedTab)) {
        return false;
      }

      final name = (c['name'] ?? '').toString().toLowerCase();
      final profession = (c['profession'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || profession.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Direct Messages',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF13141F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1F2030)),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedTab = 'casual';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: _selectedTab == 'casual'
                              ? const LinearGradient(
                                  colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          boxShadow: _selectedTab == 'casual'
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Casual",
                          style: TextStyle(
                            color: _selectedTab == 'casual' ? Colors.white : const Color(0xFF8B8C9E),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedTab = 'professional';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: _selectedTab == 'professional'
                              ? const LinearGradient(
                                  colors: [Color(0xFF00F2FE), Color(0xFF00B5FE)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          boxShadow: _selectedTab == 'professional'
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00F2FE).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Professional",
                          style: TextStyle(
                            color: _selectedTab == 'professional' ? Colors.white : const Color(0xFF8B8C9E),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Search Box
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF13141F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1F2030)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFF5C5E78), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      cursorColor: const Color(0xFF8B5CF6),
                      decoration: InputDecoration(
                        hintText: 'Search connections...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: filteredConnections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Color(0xFF5C5E78),
                          size: 40,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? "No active conversations yet" : "No results match your search",
                          style: const TextStyle(
                            color: Color(0xFF8B8C9E),
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredConnections.length,
                    itemBuilder: (context, index) {
                      final connection = filteredConnections[index];
                      final name = connection['name'] ?? 'Unknown';
                      final avatar = _getAvatarUrl(name, connection['avatarUrl'] ?? connection['avatar_url']);

                      final roomId = provider.connectionRooms[connection['id']];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13141F).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          clipBehavior: Clip.antiAlias,
                          borderRadius: BorderRadius.circular(16),
                          child: FutureBuilder<Map<String, dynamic>?>(
                            future: _getLastMessage(roomId),
                            builder: (context, snapshot) {
                              final lastMsg = snapshot.data;

                              final String lastMessageText = lastMsg != null
                                  ? lastMsg['payload'] ?? ''
                                  : "Start a conversation!";

                              final String msgTime = lastMsg != null
                                  ? _formatMessageTime(lastMsg['created_at'] as String?)
                                  : '';

                              final bool isUnread = lastMsg != null &&
                                  lastMsg['sender_id'] != provider.userId &&
                                  lastMsg['status'] != 'read';

                              return ListTile(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => IndividualChatPage(connectionData: connection),
                                    ),
                                  );
                                },
                                onLongPress: () {
                                  HapticFeedback.mediumImpact();
                                  _showDeleteConfirmation(context, connection, provider);
                                },
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                leading: Stack(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: avatar.isNotEmpty
                                            ? Image.network(avatar, fit: BoxFit.cover)
                                            : Container(
                                                color: const Color(0xFF1B1C2A),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?",
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFF090A0F), width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    if (msgTime.isNotEmpty)
                                      Text(
                                        msgTime,
                                        style: TextStyle(
                                          color: isUnread ? const Color(0xFF8B5CF6) : Colors.white.withValues(alpha: 0.2),
                                          fontSize: 10.5,
                                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          lastMessageText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isUnread ? Colors.white70 : Colors.white.withValues(alpha: 0.35),
                                            fontSize: 12.5,
                                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                      if (isUnread)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF8B5CF6),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
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
  }
}
