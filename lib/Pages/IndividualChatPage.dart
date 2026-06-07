import 'dart:async';
import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/chat_provider.dart';
import 'package:provider/provider.dart';

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

  late final ChatProvider _provider;
  late final int? _myUserId;
  String? _roomId;
  bool _isRoomLoading = true;
  Map<String, dynamic>? _replyMessage;
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;
  bool _showScrollToBottom = false;
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _name = widget.connectionData['name'] ?? 'Unknown';
    _avatarUrl = widget.connectionData['avatarUrl'] ??
        widget.connectionData['avatar_url'] ??
        '';
    _profession = widget.connectionData['profession'] ?? 'Connection';

    _provider = Provider.of<ChatProvider>(context, listen: false);
    _myUserId = Provider.of<ProfileProvider>(context, listen: false).userId;
    _scrollController.addListener(_onScroll);
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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Show the button when user is scrolled more than 100px from bottom
    final isScrolledUp = pos.maxScrollExtent - pos.pixels > 100;
    if (isScrolledUp != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = isScrolledUp;
      });
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.maxScrollExtent - pos.pixels < 100;
  }

  @override
  void dispose() {
    _provider.setActiveRoom(null);
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    // Wait a frame so the layout (especially tall reply-quote bubbles) settles
    await Future.delayed(const Duration(milliseconds: 50));
    if (!_scrollController.hasClients || !mounted) return;

    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    // If maxScrollExtent grew during the animation (e.g. images loaded,
    // new messages arrived), snap to the true bottom.
    if (_scrollController.hasClients) {
      final trueMax = _scrollController.position.maxScrollExtent;
      if (_scrollController.offset < trueMax - 1) {
        _scrollController.jumpTo(trueMax);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _roomId == null) return;

    _messageController.clear();
    HapticFeedback.lightImpact();

    final replyMsg = _replyMessage;
    setState(() {
      _replyMessage = null;
    });

    if (replyMsg != null) {
      final isReplyMe = replyMsg['sender_id'] == _myUserId;
      final replySenderName = isReplyMe ? 'You' : _name;
      await _provider.sendChatMessage(
        roomId: _roomId!,
        text: text,
        replyToMessageId: replyMsg['id']?.toString(),
        replyToMessagePayload: replyMsg['payload']?.toString(),
        replyToMessageSenderName: replySenderName,
      );
    } else {
      await _provider.sendChatMessage(roomId: _roomId!, text: text);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _formatMessageTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final hour = dateTime.hour > 12
          ? dateTime.hour - 12
          : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return "$hour:$minute $period";
    } catch (_) {
      return "Just now";
    }
  }

  bool _isDifferentDay(String prevIso, String currentIso) {
    if (prevIso.isEmpty || currentIso.isEmpty) return false;
    try {
      final prevDate = DateTime.parse(prevIso).toLocal();
      final currDate = DateTime.parse(currentIso).toLocal();
      return prevDate.year != currDate.year ||
          prevDate.month != currDate.month ||
          prevDate.day != currDate.day;
    } catch (_) {
      return false;
    }
  }

  String _formatMessageDateHeader(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();

      if (dateTime.year == now.year &&
          dateTime.month == now.month &&
          dateTime.day == now.day) {
        return "Today";
      }

      final yesterday = DateTime(now.year, now.month, now.day - 1);
      if (dateTime.year == yesterday.year &&
          dateTime.month == yesterday.month &&
          dateTime.day == yesterday.day) {
        return "Yesterday";
      }

      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      final monthName = months[dateTime.month - 1];
      return "$monthName ${dateTime.day}, ${dateTime.year}";
    } catch (_) {
      return "";
    }
  }

  Widget _buildDateHeader(String dateText) {
    if (dateText.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF13141F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1F2030), width: 0.5),
        ),
        child: Text(
          dateText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
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
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _getAvatarUrl(_name, _avatarUrl);
    final provider = Provider.of<ChatProvider>(context);
    final messages = provider.activeRoomMessages;

    // Auto-scroll ONLY when a genuinely new message arrives AND user is near the bottom
    if (messages.length > _previousMessageCount && _previousMessageCount > 0) {
      if (_isNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
    _previousMessageCount = messages.length;

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F101A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
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
                              _name.isNotEmpty
                                  ? _name.substring(0, 1).toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
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
                    Text(
                      _profession,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
                    ),
                  )
                : Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        itemCount: messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length) {
                            return _buildTypingIndicator();
                          }

                          final msg = messages[index];
                          final msgId = msg['id'] as String;
                          final key = _messageKeys.putIfAbsent(
                              msgId, () => GlobalKey());
                          final isMe = msg['sender_id'] == _myUserId;
                          final timeString =
                              _formatMessageTime(msg['created_at'] as String);
                          final status = msg['status'] as String?;
                          final replyToId =
                              msg['reply_to_message_id'] as String?;
                          final replyToPayload =
                              msg['reply_to_message_payload'] as String?;
                          final replyToSenderName =
                              msg['reply_to_message_sender_name'] as String?;
                          final isHighlighted = msgId == _highlightedMessageId;

                          Offset tapPosition = Offset.zero;

                          final prevCreatedAt = index > 0
                              ? (messages[index - 1]['created_at'] as String? ??
                                  '')
                              : '';
                          final currentCreatedAt =
                              msg['created_at'] as String? ?? '';
                          final showDateHeader = index == 0 ||
                              _isDifferentDay(prevCreatedAt, currentCreatedAt);

                          final bubbleWidget = SwipeToReply(
                            key: key,
                            onReply: () {
                              _setReplyMessage(msg, isMe);
                            },
                            child: GestureDetector(
                              onTapDown: (details) {
                                tapPosition = details.globalPosition;
                              },
                              onLongPress: () {
                                _showContextMenu(
                                    context, tapPosition, msg, isMe);
                              },
                              child: _buildMessageBubble(
                                text: msg['payload'] ?? '',
                                time: timeString,
                                isMe: isMe,
                                status: status,
                                replyToId: replyToId,
                                replyToPayload: replyToPayload,
                                replyToSenderName: replyToSenderName,
                                isHighlighted: isHighlighted,
                              ),
                            ),
                          );

                          if (showDateHeader) {
                            final dateText =
                                _formatMessageDateHeader(currentCreatedAt);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildDateHeader(dateText),
                                bubbleWidget,
                              ],
                            );
                          }

                          return bubbleWidget;
                        },
                      ),
                      // ── Scroll-to-bottom FAB ──
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: AnimatedScale(
                          scale: _showScrollToBottom ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                          child: AnimatedOpacity(
                            opacity: _showScrollToBottom ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: GestureDetector(
                              onTap: _scrollToBottom,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF8B5CF6),
                                      Color(0xFF00F2FE)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6)
                                          .withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(1.5),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(
                                        0xFF0D0E1A), // Blend with dark background
                                  ),
                                  child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          _buildReplyPreview(),
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
    String? replyToId,
    String? replyToPayload,
    String? replyToSenderName,
    bool isHighlighted = false,
  }) {
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // ── Full-width highlight band behind the bubble only ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isHighlighted
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
            child: Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  borderRadius: bubbleRadius,
                  gradient: isMe
                      ? const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF5D3FE8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe ? null : const Color(0xFF13141F),
                  border:
                      isMe ? null : Border.all(color: const Color(0xFF1F2030)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (replyToId != null) ...[
                      GestureDetector(
                        onTap: () {
                          _scrollToAndHighlightMessage(
                              replyToId, _provider.activeRoomMessages);
                        },
                        child: _buildBubbleReplyQuote(replyToSenderName ?? '',
                            replyToPayload ?? '', isMe),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        height: 1.35,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // ── Time + status row (never highlighted) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 11,
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
    );
  }

  Widget _buildStatusIcon(String status) {
    // 🕒 PENDING — saved locally, not yet confirmed by Supabase
    if (status == 'pending') {
      return Icon(
        Icons.access_time_rounded,
        size: 12,
        color: Colors.white.withValues(alpha: 0.35),
      );
    }

    // ✓ SENT — message reached Supabase server
    if (status == 'sent') {
      return Icon(
        Icons.check_rounded,
        size: 12,
        color: Colors.white.withValues(alpha: 0.3),
      );
    }

    // ✓✓ DELIVERED — landed on recipient's device (grey)
    if (status == 'delivered') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded,
              size: 12, color: Colors.white.withValues(alpha: 0.4)),
          Transform.translate(
            offset: const Offset(-6, 0),
            child: Icon(Icons.check_rounded,
                size: 12, color: Colors.white.withValues(alpha: 0.4)),
          ),
        ],
      );
    }

    // ✓✓ READ — recipient opened the chat (blue)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_rounded, size: 12, color: const Color(0xFF00F2FE)),
        Transform.translate(
          offset: const Offset(-6, 0),
          child: Icon(Icons.check_rounded,
              size: 12, color: const Color(0xFF00F2FE)),
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
          top: BorderSide(color: Colors.white.withValues(alpha: 0.03)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF13141F),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1F2030)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
                cursorColor: const Color(0xFF8B5CF6),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 14.5,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
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
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleReplyQuote(String senderName, String text, bool isMe) {
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(isMe ? 0.15 : 0.22),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color:
                      isMe ? const Color(0xFF00F2FE) : const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      senderName,
                      style: TextStyle(
                        color: isMe
                            ? const Color(0xFF00F2FE)
                            : const Color(0xFF8B5CF6),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      text,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scrollToAndHighlightMessage(
      String replyToId, List<Map<String, dynamic>> messages) async {
    final targetIndex = messages.indexWhere((m) => m['id'] == replyToId);
    if (targetIndex == -1 || !_scrollController.hasClients) return;

    // ── Step 1: Jump close to the target so ListView builds it ──
    // Estimate a rough position – messages average ~80px but vary.
    final totalMessages = messages.length;
    final scrollExtent = _scrollController.position.maxScrollExtent;
    final double fraction = targetIndex / totalMessages;
    final double estimatedOffset =
        (fraction * scrollExtent).clamp(0.0, scrollExtent);

    // Check if the target widget is already built
    GlobalKey? targetKey = _messageKeys[replyToId];
    if (targetKey == null || targetKey.currentContext == null) {
      // Jump immediately (no animation) to get close, then let ListView build
      _scrollController.jumpTo(estimatedOffset);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // ── Step 2: Precise scroll using ensureVisible ──
    // Try up to 3 times with small delays to let the list catch up
    for (int attempt = 0; attempt < 3; attempt++) {
      targetKey = _messageKeys[replyToId];
      if (targetKey != null && targetKey.currentContext != null) {
        await Scrollable.ensureVisible(
          targetKey.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment:
              0.4, // Position the target ~40% from the top of the viewport
        );
        break;
      }
      await Future.delayed(const Duration(milliseconds: 80));
    }

    // ── Step 3: Flash highlight ──
    if (mounted) {
      setState(() {
        _highlightedMessageId = replyToId;
      });

      Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    }
  }

  Widget _buildReplyPreview() {
    if (_replyMessage == null) return const SizedBox.shrink();

    final isMe = _replyMessage!['sender_id'] == _myUserId;
    final senderName = isMe ? 'You' : _name;
    final text = _replyMessage!['payload'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F101A),
        border: Border(
          top: BorderSide(color: Color(0xFF1F2030), width: 1),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF13141F),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF8B5CF6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderName,
                    style: const TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white38, size: 18),
              onPressed: () {
                setState(() {
                  _replyMessage = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setReplyMessage(Map<String, dynamic> message, bool isMe) {
    setState(() {
      _replyMessage = message;
    });
  }

  void _showContextMenu(BuildContext context, Offset tapPosition,
      Map<String, dynamic> message, bool isMe) {
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        tapPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: const Color(0xFF10111F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF202138)),
      ),
      items: [
        const PopupMenuItem(
          value: 'reply',
          child: Row(
            children: [
              Icon(Icons.reply_rounded, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text("Reply",
                  style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 18),
              SizedBox(width: 8),
              Text("Delete",
                  style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'reply') {
        _setReplyMessage(message, isMe);
      } else if (value == 'delete') {
        _handleDeleteMessage(message, isMe);
      }
    });
  }

  void _handleDeleteMessage(Map<String, dynamic> message, bool isMe) {
    final status = message['status'] as String?;
    final isSeen = (status == 'read');

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10111F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF202138)),
          ),
          title: const Text(
            "Delete Message?",
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Text(
            isMe
                ? (isSeen
                    ? "Want to delete the message?"
                    : "Do you want to delete this message for everyone or only for yourself?")
                : "This message will be deleted for you.",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel",
                  style: TextStyle(color: Color(0xFF8B8C9E))),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _provider.deleteChatMessage(message['id'] as String,
                    deleteForEveryone: false);
              },
              child: const Text("Delete for Me",
                  style: TextStyle(color: Colors.redAccent)),
            ),
            if (isMe && !isSeen)
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _provider.deleteChatMessage(message['id'] as String,
                      deleteForEveryone: true);
                },
                child: const Text("Delete for Everyone",
                    style: TextStyle(color: Color(0xFF00F2FE))),
              ),
          ],
        );
      },
    );
  }
}

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragOffset = 0.0;
  bool _triggerThresholdReached = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx < 0 && _dragOffset <= 0) return;

    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx * 0.6).clamp(0.0, 70.0);
      if (_dragOffset >= 50.0 && !_triggerThresholdReached) {
        _triggerThresholdReached = true;
        HapticFeedback.lightImpact();
      } else if (_dragOffset < 50.0 && _triggerThresholdReached) {
        _triggerThresholdReached = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_triggerThresholdReached) {
      widget.onReply();
    }
    setState(() {
      _dragOffset = 0.0;
      _triggerThresholdReached = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: -40 + (_dragOffset * 0.4),
            child: Opacity(
              opacity: (_dragOffset / 70.0).clamp(0.0, 1.0),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                ),
                child: const Icon(
                  Icons.reply_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 18,
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
