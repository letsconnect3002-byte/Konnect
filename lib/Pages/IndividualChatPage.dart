import 'dart:async';
import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Providers/ProviderSQL.dart';

class IndividualChatPage extends StatefulWidget {
  final Map<String, dynamic> connectionData;

  const IndividualChatPage({
    super.key,
    required this.connectionData,
  });

  @override
  State<IndividualChatPage> createState() => _IndividualChatPageState();
}

class _IndividualChatPageState extends State<IndividualChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isTyping = false;
  late String _name;
  late String _avatarUrl;
  late String _profession;
  
  late final ProfileProvider2 _provider;
  String? _roomId;
  bool _isRoomLoading = true;

  @override
  void initState() {
    super.initState();
    _name = widget.connectionData['name'] ?? 'Unknown';
    _avatarUrl = widget.connectionData['avatarUrl'] ?? widget.connectionData['avatar_url'] ?? '';
    _profession = widget.connectionData['profession'] ?? 'Connection';

    _provider = Provider.of<ProfileProvider2>(context, listen: false);
    _initChatRoom();
  }

  Future<void> _initChatRoom() async {
    try {
      final otherUserId = widget.connectionData['id'] as int;
      final roomId = await _provider.getOrCreateDirectRoom(otherUserId);
      if (mounted) {
        setState(() {
          _roomId = roomId;
          _isRoomLoading = false;
        });
        _provider.setActiveRoom(roomId);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      print("Error initializing room in IndividualChatPage: $e");
      if (mounted) {
        setState(() {
          _isRoomLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _provider.setActiveRoom(null);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _roomId == null) return;

    _messageController.clear();
    HapticFeedback.lightImpact();
    
    await _provider.sendChatMessage(roomId: _roomId!, text: text);
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _formatMessageTime(String isoString) {
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
        return "Yesterday, $timeStr";
      }

      return "${dateTime.day}/${dateTime.month}/${dateTime.year}, $timeStr";
    } catch (_) {
      return "Just now";
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

  @override
  Widget build(BuildContext context) {
    final avatar = _getAvatarUrl(_name, _avatarUrl);
    final provider = Provider.of<ProfileProvider2>(context);
    final messages = provider.activeRoomMessages;

    // Auto-scroll when new messages arrive
    if (messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F101A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ConnectionProfilePage(
                  profileData: widget.connectionData,
                ),
              ),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
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
                    child: avatar.isNotEmpty
                        ? Image.network(avatar, fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFF1B1C2A),
                            alignment: Alignment.center,
                            child: Text(
                              _name.isNotEmpty ? _name.substring(0, 1).toUpperCase() : "?",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _profession,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isRoomLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return _buildTypingIndicator();
                      }

                      final msg = messages[index];
                      final isMe = msg['sender_id'] == provider.userId;
                      final timeString = _formatMessageTime(msg['created_at'] as String);
                      final status = msg['status'] as String?;

                      return _buildMessageBubble(
                        text: msg['payload'] ?? '',
                        time: timeString,
                        isMe: isMe,
                        status: status,
                      );
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required String time,
    required bool isMe,
    String? status,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                ),
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF5D3FE8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMe ? null : const Color(0xFF13141F),
                border: isMe ? null : Border.all(color: const Color(0xFF1F2030)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  height: 1.35,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.25),
                      fontSize: 10,
                      fontFamily: 'Inter',
                    ),
                  ),
                  if (isMe && status != null) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(status),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    // 🕒 PENDING — saved locally, not yet confirmed by Supabase
    if (status == 'pending') {
      return Icon(
        Icons.access_time_rounded,
        size: 12,
        color: Colors.white.withOpacity(0.35),
      );
    }

    // ✓ SENT — message reached Supabase server
    if (status == 'sent') {
      return Icon(
        Icons.check_rounded,
        size: 12,
        color: Colors.white.withOpacity(0.3),
      );
    }

    // ✓✓ DELIVERED — landed on recipient's device (grey)
    if (status == 'delivered') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 12,
              color: Colors.white.withOpacity(0.4)),
          Transform.translate(
            offset: const Offset(-6, 0),
            child: Icon(Icons.check_rounded, size: 12,
                color: Colors.white.withOpacity(0.4)),
          ),
        ],
      );
    }

    // ✓✓ READ — recipient opened the chat (blue)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_rounded, size: 12,
            color: const Color(0xFF00F2FE)),
        Transform.translate(
          offset: const Offset(-6, 0),
          child: Icon(Icons.check_rounded, size: 12,
              color: const Color(0xFF00F2FE)),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF13141F),
          border: Border.all(color: const Color(0xFF1F2030)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF8B5CF6),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F101A),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.03)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Attachments coming soon!")),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF1C1D2A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white60, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF13141F),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1F2030)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
                cursorColor: const Color(0xFF8B5CF6),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 14.5,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF00F2FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
