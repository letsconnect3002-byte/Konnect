import 'dart:async';
import 'package:connect/Pages/ConnectionProfilePage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/chat_provider.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';

class IndividualChatPage extends StatefulWidget {
  final Map<String, dynamic>? connectionData;
  final int? otherUserId;

  const IndividualChatPage({
    super.key,
    this.connectionData,
    this.otherUserId,
  });

  @override
  State<IndividualChatPage> createState() => _IndividualChatPageState();
}

class _IndividualChatPageState extends State<IndividualChatPage>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  Timer? _localTypingTimer;
  bool _amITyping = false;
  String _name = 'Loading...';
  String _avatarUrl = '';
  String _profession = 'Connection';
  Map<String, dynamic>? _connectionData;
  bool _isProfileLoading = false;

  late final ChatProvider _provider;
  late final int? _myUserId;
  String? _roomId;
  bool _isRoomLoading = true;
  Map<String, dynamic>? _replyMessage;
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;
  bool _showScrollToBottom = false;
  int _previousMessageCount = 0;
  final Set<String> _animatedMessageIds = {};
  Map<String, dynamic>? _selectedMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectionData = widget.connectionData;
    if (_connectionData != null) {
      _name = _connectionData!['name'] ?? 'Unknown';
      _avatarUrl =
          _connectionData!['avatarUrl'] ?? _connectionData!['avatar_url'] ?? '';
      _profession = _connectionData!['profession'] ?? 'Connection';
      _isProfileLoading = false;
    } else {
      _isProfileLoading = true;
    }

    _provider = Provider.of<ChatProvider>(context, listen: false);
    _myUserId = Provider.of<ProfileProvider>(context, listen: false).userId;
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);

    // Start chat room init after the very first frame so the page shell
    // (app bar, background, loading spinner) renders instantly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initChatRoom();
      }
    });
  }

  Future<void> _initChatRoom() async {
    try {
      // Wait for the slide transition to finish so the animation stays
      // smooth. The page shows an empty chat background during the slide.
      final route = ModalRoute.of(context);
      if (route != null && route.animation != null) {
        final animation = route.animation!;
        if (!animation.isCompleted) {
          final completer = Completer<void>();
          void statusListener(AnimationStatus status) {
            if (status == AnimationStatus.completed) {
              animation.removeStatusListener(statusListener);
              completer.complete();
            }
          }

          animation.addStatusListener(statusListener);
          await completer.future;
        }
      }

      if (!mounted) return;

      // ── Fetch sender profile details in the background if connectionData was null ──
      if (_connectionData == null && widget.otherUserId != null) {
        final profileProvider =
            Provider.of<ProfileProvider>(context, listen: false);
        try {
          final profile =
              await profileProvider.fetchProfileDataOnly(widget.otherUserId!);
          if (mounted && profile.isNotEmpty) {
            setState(() {
              _connectionData = profile;
              _name = profile['name'] ?? 'Unknown';
              _avatarUrl = profile['avatarUrl'] ?? profile['avatar_url'] ?? '';
              _profession = profile['profession'] ?? 'Connection';
              _isProfileLoading = false;
            });
          }
        } catch (e) {
          print("Error loading profile in IndividualChatPage: $e");
          if (mounted) {
            setState(() {
              _isProfileLoading = false;
            });
          }
        }
      }

      final otherUserId = _connectionData != null
          ? (_connectionData!['id'] as int)
          : widget.otherUserId!;
      final roomId = await _provider.getOrCreateDirectRoom(otherUserId);

      if (!mounted) return;

      // Show messages from local cache immediately, then sync in background
      _provider.setActiveRoom(roomId);
      await _provider.refreshActiveRoomMessages();

      if (!mounted) return;

      final draft = _provider.getDraft(otherUserId);
      if (draft != null && draft.isNotEmpty) {
        _messageController.text = draft;
      }

      setState(() {
        _roomId = roomId;
        _isRoomLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      // Background safety net: sync full room history from Supabase to recover
      // any messages missed by the realtime subscription.
      _provider.syncRoomHistory(roomId);
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
    // In a reversed list, pos.pixels is the scroll distance from the bottom.
    // Show the button when user is scrolled up (distance from bottom > 100)
    final isScrolledUp = pos.pixels > 100;
    if (isScrolledUp != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = isScrolledUp;
      });
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    // In a reversed list, pos.pixels is the scroll distance from the bottom.
    return pos.pixels < 100;
  }

  void _onTextChanged() {
    final text = _messageController.text;

    // Turn typing status ON when user starts inputting text
    if (text.isNotEmpty && !_amITyping) {
      _amITyping = true;
      _provider.sendTypingStatus(true);
    }

    // Debounce: if user stops typing for 2.5s, broadcast false
    _localTypingTimer?.cancel();
    _localTypingTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _amITyping) {
        _amITyping = false;
        _provider.sendTypingStatus(false);
      }
    });

    // If text box is completely cleared, instantly broadcast false
    if (text.isEmpty && _amITyping) {
      _localTypingTimer?.cancel();
      _amITyping = false;
      _provider.sendTypingStatus(false);
    }
  }

  void _saveDraft() {
    final otherUserId = _connectionData != null
        ? (_connectionData!['id'] as int?)
        : widget.otherUserId;
    if (otherUserId != null) {
      final text = _messageController.text.trim();
      if (text.isNotEmpty) {
        _provider.saveDraft(otherUserId, text);
      } else {
        _provider.clearDraft(otherUserId);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveDraft();
    }
  }

  @override
  void dispose() {
    _saveDraft();
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onTextChanged);
    _localTypingTimer?.cancel();
    if (_amITyping) {
      _provider.sendTypingStatus(false);
    }
    _provider.setActiveRoom(null);
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    // Wait a frame so the layout settles
    await Future.delayed(const Duration(milliseconds: 50));
    if (!_scrollController.hasClients || !mounted) return;

    if (_scrollController.offset > 0.0) {
      await _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _roomId == null) return;

    // Reset typing tracking immediately upon send
    _localTypingTimer?.cancel();
    if (_amITyping) {
      _amITyping = false;
      _provider.sendTypingStatus(false);
    }

    _messageController.clear();
    final otherUserId = _connectionData != null
        ? (_connectionData!['id'] as int?)
        : widget.otherUserId;
    if (otherUserId != null) {
      _provider.clearDraft(otherUserId);
    }
    HapticFeedback.lightImpact();

    final replyMsg = _replyMessage;
    setState(() {
      _replyMessage = null;
    });
    if (replyMsg != null) {
      final isReplyMe = replyMsg['sender_id'] == _myUserId;
      final myName = Provider.of<ProfileProvider>(context, listen: false).name;
      final replySenderName = isReplyMe ? (myName.isNotEmpty ? myName : 'You') : _name;
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
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return "$hour:$minute";
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
          color: context.surfaceSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.surfaceSecondary, width: 0.5),
        ),
        child: Text(
          dateText,
          style: context.captionText.copyWith(
            color: context.textSecondary,
            fontWeight: FontWeight.w600,
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
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _getAvatarUrl(_name, _avatarUrl);
    final provider = Provider.of<ChatProvider>(context);
    final messages = provider.activeRoomMessages;
    final isOtherTyping = provider.isOtherUserTyping;

    // Auto-scroll ONLY when a genuinely new message arrives AND user is near the bottom
    if (messages.length > _previousMessageCount && _previousMessageCount > 0) {
      if (_isNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
    _previousMessageCount = messages.length;

    if (_animatedMessageIds.isEmpty && messages.isNotEmpty && !_isRoomLoading) {
      for (final msg in messages) {
        final id = msg['id'] as String?;
        if (id != null) {
          _animatedMessageIds.add(id);
        }
      }
    }

    return Scaffold(
      backgroundColor: context.canvasBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const GlassmorphicFlexibleSpace(),
        leading: _selectedMessage != null
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                onPressed: () {
                  setState(() {
                    _selectedMessage = null;
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
        titleSpacing: 0,
        title: _selectedMessage != null
            ? Text(
                "1 selected",
                style: context.screenHeading.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              )
            : GestureDetector(
                onTap: () {
                  if (_connectionData != null) {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConnectionProfilePage(
                          profileData: _connectionData!,
                        ),
                      ),
                    );
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.accentPrimary,
                          width: 2.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(1.5),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.surfaceSecondary,
                        ),
                        padding: const EdgeInsets.all(1.5),
                        child: _isProfileLoading
                            ? const _ShimmerBox(
                                width: 34,
                                height: 34,
                                shape: BoxShape.circle,
                              )
                            : ClipOval(
                                child: avatar.isNotEmpty
                                    ? Image.network(
                                        avatar,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(
                                          color: context.surfaceSecondary,
                                          alignment: Alignment.center,
                                          child: Text(
                                            _name.isNotEmpty
                                                ? _name.substring(0, 1).toUpperCase()
                                                : "?",
                                            style: TextStyle(
                                                color: context.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: context.surfaceSecondary,
                                        alignment: Alignment.center,
                                        child: Text(
                                          _name.isNotEmpty
                                              ? _name.substring(0, 1).toUpperCase()
                                              : "?",
                                          style: TextStyle(
                                              color: context.textPrimary,
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
                          if (_isProfileLoading) ...[
                            const _ShimmerBox(
                              width: 100,
                              height: 14,
                              borderRadius: 4,
                            ),
                            const SizedBox(height: 5),
                            const _ShimmerBox(
                              width: 70,
                              height: 10,
                              borderRadius: 3,
                            ),
                          ] else ...[
                            Text(
                              _name,
                              style: context.bodyText.copyWith(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _profession,
                              style: context.captionText.copyWith(
                                color: context.textSecondary,
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
              ),
        actions: _selectedMessage == null
            ? []
            : [
                if (_selectedMessage!['sender_id'] == _myUserId &&
                    _selectedMessage!['status'] == 'error')
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00F2FE)),
                    tooltip: 'Resend',
                    onPressed: () {
                      final msg = _selectedMessage!;
                      setState(() {
                        _selectedMessage = null;
                      });
                      _provider.resendChatMessage(msg['id'] as String);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.report_gmailerrorred_outlined, color: Colors.orangeAccent),
                  tooltip: 'Report Message',
                  onPressed: () {
                    final msg = _selectedMessage!;
                    setState(() {
                      _selectedMessage = null;
                    });
                    _showReportDialog(msg);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.reply_rounded, color: Colors.white),
                  tooltip: 'Reply',
                  onPressed: () {
                    final msg = _selectedMessage!;
                    setState(() {
                      _selectedMessage = null;
                    });
                    _setReplyMessage(msg, msg['sender_id'] == _myUserId);
                    _messageFocusNode.requestFocus();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  tooltip: 'Delete',
                  onPressed: () {
                    final msg = _selectedMessage!;
                    setState(() {
                      _selectedMessage = null;
                    });
                    _handleDeleteMessage(msg, msg['sender_id'] == _myUserId);
                  },
                ),
                const SizedBox(width: 8),
              ],
      ),
      body: GestureDetector(
        onTap: () {
          if (_selectedMessage != null) {
            setState(() {
              _selectedMessage = null;
            });
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background/message background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.85,
              child: Container(
                decoration: BoxDecoration(
                  gradient: context.felineBackgroundGradient,
                ),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: (_isRoomLoading || _isProfileLoading)
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(context.accentPrimary),
                        ),
                      )
                    : Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 20),
                            itemCount: messages.length + (isOtherTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (isOtherTyping && index == 0) {
                                  return _buildTypingIndicator();
                              }

                              final int msgIndex = isOtherTyping
                                  ? messages.length - index
                                  : messages.length - 1 - index;

                              final msg = messages[msgIndex];
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

                              final prevCreatedAt = msgIndex > 0
                                  ? (messages[msgIndex - 1]['created_at']
                                          as String? ??
                                      '')
                                  : '';
                              final currentCreatedAt =
                                  msg['created_at'] as String? ?? '';
                              final showDateHeader = msgIndex == 0 ||
                                  _isDifferentDay(prevCreatedAt, currentCreatedAt);

                              final hasAlreadyAnimated =
                                  _animatedMessageIds.contains(msgId);
                              if (!hasAlreadyAnimated) {
                                _animatedMessageIds.add(msgId);
                              }

                              final childWidget = SwipeToReply(
                                key: key,
                                onReply: () {
                                  _setReplyMessage(msg, isMe);
                                  _messageFocusNode.requestFocus();
                                },
                                child: GestureDetector(
                                  onTapDown: (details) {
                                    tapPosition = details.globalPosition;
                                  },
                                  onTap: () {
                                    if (_selectedMessage != null) {
                                      setState(() {
                                        _selectedMessage = null;
                                      });
                                    }
                                  },
                                  onLongPress: () {
                                    _messageFocusNode.unfocus();
                                    HapticFeedback.mediumImpact();
                                    setState(() {
                                      _selectedMessage = msg;
                                    });
                                  },
                                  child: _buildMessageBubble(
                                    text: msg['payload'] ?? '',
                                    time: timeString,
                                    isMe: isMe,
                                    status: status,
                                    replyToId: replyToId,
                                    replyToPayload: replyToPayload,
                                    replyToSenderName: replyToSenderName,
                                    isHighlighted: isHighlighted || (_selectedMessage?['id'] == msgId),
                                  ),
                                ),
                              );

                              final bubbleWidget = RepaintBoundary(
                                key: ValueKey('${msgId}_bubble'),
                                child: hasAlreadyAnimated
                                    ? childWidget
                                    : childWidget
                                        .animate()
                                        .fadeIn(
                                            duration: 150.ms,
                                            curve: Curves.easeOut)
                                        .scale(
                                          duration: 200.ms,
                                          curve: Curves.easeOutBack,
                                          alignment: isMe
                                              ? Alignment.bottomRight
                                              : Alignment.bottomLeft,
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
                                      color: context.accentSecondary,
                                      boxShadow: [
                                        BoxShadow(
                                          color: context.accentSecondary
                                              .withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.all(1.5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: context
                                            .surfacePrimary, // Blend with dark background
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
        ],
      ),
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
      topLeft: const Radius.circular(AppDimensions.radiusPremiumCard),
      topRight: const Radius.circular(AppDimensions.radiusPremiumCard),
      bottomLeft: isMe
          ? const Radius.circular(AppDimensions.radiusPremiumCard)
          : const Radius.circular(4.0),
      bottomRight: isMe
          ? const Radius.circular(4.0)
          : const Radius.circular(AppDimensions.radiusPremiumCard),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                  minWidth: 80,
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  borderRadius: bubbleRadius,
                  color: isMe ? context.accentPrimary : context.surfacePrimary,
                  border: Border.all(
                    color: isMe
                        ? context.accentSecondary.withValues(alpha: 0.5)
                        : context.surfaceSecondary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                padding: EdgeInsets.only(
                  left: 12,
                  right: isMe ? 8 : 12,
                  top: 10,
                  bottom: 6,
                ),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (replyToId != null) ...[
                        GestureDetector(
                          onTap: () {
                            _scrollToAndHighlightMessage(
                                replyToId, _provider.activeRoomMessages);
                          },
                          child: _buildBubbleReplyQuote(
                              _resolveReplySenderName(replyToSenderName),
                              replyToPayload ?? '', isMe),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        text,
                        style: context.bodyText.copyWith(
                          color: context.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            status == 'error' ? 'Failed to send' : time,
                            style: context.captionText.copyWith(
                              color: status == 'error'
                                  ? Colors.redAccent
                                  : const Color.fromARGB(133, 255, 255, 255),
                              fontSize: 9.5,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          if (isMe && status != null) ...[
                            const SizedBox(width: 4),
                            _buildStatusIcon(status),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    if (status == 'error') {
      return const Icon(
        Icons.error_outline_rounded,
        size: 12,
        color: Colors.redAccent,
      );
    }

    // 🕒 PENDING — saved locally, not yet confirmed by Supabase
    if (status == 'pending') {
      return Icon(
        Icons.access_time_rounded,
        size: 12,
        color: context.textMuted,
      );
    }

    // ✓ SENT — message reached Supabase server
    if (status == 'sent') {
      return Icon(
        Icons.check_rounded,
        size: 12,
        color: context.textSecondary.withValues(alpha: 0.5),
      );
    }

    // ✓✓ DELIVERED — landed on recipient's device (grey)
    if (status == 'delivered') {
      return SizedBox(
        width: 17,
        height: 12,
        child: Stack(
          children: [
            Icon(Icons.check_rounded,
                size: 12, color: context.textSecondary.withValues(alpha: 0.6)),
            Positioned(
              left: 5,
              child: Icon(Icons.check_rounded,
                  size: 12,
                  color: context.textSecondary.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    // ✓✓ READ — recipient opened the chat (blue)
    return const SizedBox(
      width: 17,
      height: 12,
      child: Stack(
        children: [
          Icon(Icons.check_rounded,
              size: 12, color: Color.fromARGB(255, 255, 255, 255)),
          Positioned(
            left: 5,
            child: Icon(Icons.check_rounded,
                size: 12, color: Color.fromARGB(255, 255, 255, 255)),
          ),
        ],
      ),
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
          color: context.surfacePrimary,
          border: Border.all(color: context.surfaceSecondary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return _BouncingDot(
              color: context.accentSecondary,
              delay: Duration(milliseconds: index * 200),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            16.0, 8.0, 16.0, 16.0), // Floating above bottom zone
        padding: const EdgeInsets.symmetric(
            horizontal: 16.0, vertical: 6.0), // Horiz padding 16.0 matched
        decoration: BoxDecoration(
          color: context
              .surfacePrimary, // input field structure matching AppTheme.surfacePrimary
          borderRadius: BorderRadius.circular(
              AppDimensions.radiusPill), // Capsule row profile
          border: Border.all(
              color: context.surfaceSecondary.withValues(alpha: 0.8), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                style: context.bodyText.copyWith(color: context.textPrimary),
                cursorColor: context.accentPrimary,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle:
                      context.bodyText.copyWith(color: context.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context
                      .accentPrimary, // sharp circular neon asset powered by AppTheme.accentPrimary
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: context.accentPrimary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white, // contrasting black icon label
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveReplySenderName(String? storedName) {
    if (storedName == null || storedName.isEmpty) return '';
    final myName = Provider.of<ProfileProvider>(context, listen: false).name;
    if (storedName == myName || storedName == 'You') return 'You';
    return storedName;
  }

  Widget _buildBubbleReplyQuote(String senderName, String text, bool isMe) {
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: isMe ? 0.15 : 0.22),
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
                      isMe ? const Color(0xFF00F2FE) : context.accentSecondary,
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
                            : context.accentSecondary,
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
                        color: Colors.white.withValues(alpha: 0.65),
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
    final totalMessages = messages.length;
    final scrollExtent = _scrollController.position.maxScrollExtent;
    // In a reversed list, the oldest message (index 0) is at the top (maxScrollExtent)
    // and the newest message (index totalMessages - 1) is at the bottom (0.0).
    final double fraction = 1.0 - (targetIndex / totalMessages);
    final double estimatedOffset =
        (fraction * scrollExtent).clamp(0.0, scrollExtent);

    // Check if the target widget is already built
    GlobalKey? targetKey = _messageKeys[replyToId];
    if (targetKey == null || targetKey.currentContext == null) {
      _scrollController.jumpTo(estimatedOffset);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // ── Step 2: Precise scroll using ensureVisible ──
    for (int attempt = 0; attempt < 3; attempt++) {
      targetKey = _messageKeys[replyToId];
      if (targetKey != null && targetKey.currentContext != null) {
        await Scrollable.ensureVisible(
          targetKey.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.4,
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
      decoration: BoxDecoration(
        color: context.canvasBackground,
        border: Border(
          top: BorderSide(color: context.surfaceSecondary, width: 1),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: context.accentSecondary,
                borderRadius: const BorderRadius.only(
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
                    style: TextStyle(
                      color: context.accentSecondary,
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

  void _showReportDialog(Map<String, dynamic> message) {
    String selectedReason = 'Spam';
    final detailsController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return GlassmorphicAlertDialog(
              title: Text(
                "Report Message",
                style: context.screenHeading.copyWith(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Please select the reason for flagging this content:",
                        style: context.bodyText.copyWith(color: context.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      ...['Spam', 'Harassment or Abuse', 'Inappropriate Content', 'Other'].map((reason) {
                        final isSelected = selectedReason == reason;
                        return InkWell(
                          onTap: isSubmitting ? null : () {
                            setStateBuilder(() {
                              selectedReason = reason;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: isSelected
                                      ? context.accentPrimary
                                      : context.textMuted,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  reason,
                                  style: context.bodyText.copyWith(
                                    color: isSelected
                                        ? context.textPrimary
                                        : context.textSecondary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      Text(
                        "Additional Details (Optional):",
                        style: context.bodyText.copyWith(color: context.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: detailsController,
                        maxLines: 3,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          hintText: "Enter details here...",
                          hintStyle: TextStyle(color: context.textMuted, fontSize: 13),
                          fillColor: context.surfaceSecondary,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: context.borderMuted),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: context.accentPrimary),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: context.bodyText,
                      ),
                    ],
                  ),
                ),
              ),
              actions: isSubmitting
                  ? [
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    ]
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text("Cancel", style: TextStyle(color: context.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () async {
                          setStateBuilder(() {
                            isSubmitting = true;
                          });
                          
                          try {
                            await _provider.reportMessage(
                              reportedUserId: message['sender_id'] as int,
                              messageId: message['id'] as String,
                              messageContent: message['payload'] as String? ?? '',
                              reason: selectedReason,
                              additionalDetails: detailsController.text.trim().isEmpty 
                                  ? null 
                                  : detailsController.text.trim(),
                            );
                            
                            if (mounted) {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Thank you, this content has been flagged for review."),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setStateBuilder(() {
                                isSubmitting = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Failed to report message: $e"),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text("Submit Report", style: TextStyle(color: Colors.orangeAccent)),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  void _showContextMenu(BuildContext context, Offset tapPosition,
      Map<String, dynamic> message, bool isMe) {
    // Unfocus the input field before showing the menu to prevent keyboard refocusing issues
    _messageFocusNode.unfocus();

    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final surfaceSecondaryColor = context.surfaceSecondary;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        tapPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: context.surfaceSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: surfaceSecondaryColor),
      ),
      items: [
        if (isMe && message['status'] == 'error')
          const PopupMenuItem(
            value: 'resend',
            child: Row(
              children: [
                Icon(Icons.refresh_rounded, color: Color(0xFF00F2FE), size: 18),
                SizedBox(width: 8),
                Text("Resend",
                    style: TextStyle(color: Color(0xFF00F2FE), fontSize: 14)),
              ],
            ),
          ),
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
      if (value == 'resend') {
        _provider.resendChatMessage(message['id'] as String);
      } else if (value == 'reply') {
        _setReplyMessage(message, isMe);
        _messageFocusNode.requestFocus();
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
        return GlassmorphicAlertDialog(
          title: Text(
            "Delete Message?",
            style: context.screenHeading.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Text(
            isMe
                ? (isSeen
                    ? "Want to delete the message?"
                    : "Do you want to delete this message for everyone or only for yourself?")
                : "This message will be deleted for you.",
            style: context.bodyText.copyWith(color: context.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text("Cancel",
                  style: TextStyle(color: context.textSecondary)),
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
                  color: context.accentSecondary.withValues(alpha: 0.2),
                ),
                child: Icon(
                  Icons.reply_rounded,
                  color: context.accentSecondary,
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

class _BouncingDot extends StatefulWidget {
  final Color color;
  final Duration delay;

  const _BouncingDot({required this.color, required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Stagger the start of each dot's animation
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Transform.translate(
            offset: Offset(0, _animation.value),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 4.0,
    this.shape = BoxShape.rectangle,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.35, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              shape: widget.shape,
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: widget.shape == BoxShape.circle
                  ? null
                  : BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}
