import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/tribe_provider.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Pages/Tribe/TribeDetailsPage.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/main.dart';

class TribeChatPage extends StatefulWidget {
  final String tribeId;
  final String tribeName;

  const TribeChatPage({
    super.key,
    required this.tribeId,
    required this.tribeName,
  });

  @override
  State<TribeChatPage> createState() => _TribeChatPageState();
}

class _TribeChatPageState extends State<TribeChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  late TribeProvider _tribeProvider;

  Map<String, dynamic>? _replyMessage;
  Map<String, dynamic>? _selectedMessage;

  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;
  bool _isLoadingMessages = true;
  final Set<String> _animatedMessageIds = {};

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<TribeProvider>(context, listen: false);
    provider.setActiveTribe(widget.tribeId);
    provider.subscribeToTribeRealtime(widget.tribeId);
    provider.fetchTribeDetails(widget.tribeId);
    provider.fetchMyTribes(silent: true);
    provider.fetchBlockedUserIds();
    _clearTribeNotifications();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final provider = Provider.of<TribeProvider>(context, listen: false);
    try {
      await provider.fetchTribeMessagesAndLog(widget.tribeId);
    } catch (e) {
      print("Error loading tribe messages: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  Future<void> _clearTribeNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('unread_tribe_messages_${widget.tribeId}');
      await cancelLocalNotification(widget.tribeId);
    } catch (e) {
      print("Error clearing tribe notifications: $e");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tribeProvider = Provider.of<TribeProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _tribeProvider.setActiveTribe(null);
    _tribeProvider.unsubscribeFromTribeRealtime(widget.tribeId);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final provider = Provider.of<TribeProvider>(context, listen: false);
    if (!provider.hasPermission(widget.tribeId, 'post_messages')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("You do not have permission to post messages.")),
      );
      return;
    }

    _messageController.clear();

    try {
      final replyId = _replyMessage?['id'] as String?;
      setState(() {
        _replyMessage = null;
      });

      await provider.sendTribeTextMessage(
        widget.tribeId,
        text,
        replyToId: replyId,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Message could not be sent. Please check your network.")),
        );
      }
    }
  }

  String _getActivityLogText(Map<String, dynamic> log, int? myUserId) {
    final actor = log['actor'] as Map<String, dynamic>?;
    final actorId = actor != null ? actor['id'] as int? : null;
    final isMe = actorId != null && actorId == myUserId;

    final String actorName = isMe
        ? "You"
        : (actor != null ? actor['name']?.toString() ?? 'Someone' : 'Someone');
    final actionType = log['action_type']?.toString();

    // Extract target name from metadata (for actions that affect another user)
    final metadata = log['metadata'] as Map<String, dynamic>? ?? {};
    final String targetName = metadata['target_name']?.toString() ?? 'a member';

    switch (actionType) {
      case 'joined':
        return isMe ? "You joined the Mafia" : "$actorName joined the Mafia";
      case 'left':
        return isMe ? "You left the Mafia" : "$actorName left the Mafia";
      case 'removed':
        // actor = the admin who removed; target = the person who was removed
        return isMe
            ? "You removed $targetName from the Mafia"
            : "$actorName removed $targetName from the Mafia";
      case 'invited':
        return isMe
            ? "You invited $targetName"
            : "$actorName invited $targetName";
      case 'requested_to_join':
        return isMe
            ? "You requested to join the Mafia"
            : "$actorName requested to join the Mafia";
      case 'declined_invite':
        return isMe
            ? "You declined invitation"
            : "$actorName declined invitation";
      case 'role_changed':
        return isMe
            ? "You updated $targetName's role"
            : "$actorName updated $targetName's role";
      default:
        return isMe
            ? "You performed an action"
            : "$actorName performed an action";
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TribeProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final myUserId = profileProvider.userId;

    final messages = provider.getMessages(widget.tribeId);
    final logs = provider.getActivityLog(widget.tribeId);
    final canViewLog = provider.hasPermission(widget.tribeId, 'view_activity_log');

    // Merge and sort reverse with deduplication
    final Set<String> seenIds = {};
    final List<Map<String, dynamic>> mergedList = [];
    for (final m in messages) {
      final id = m['id']?.toString();
      if (id != null && !seenIds.add('msg_$id')) continue;
      mergedList.add({
        ...m,
        '_is_message': true,
        'created_at_parsed':
            DateTime.tryParse(m['created_at'] ?? '') ?? DateTime(0),
      });
    }
    if (canViewLog) {
      for (final l in logs) {
        final id = l['id']?.toString();
        if (id != null && !seenIds.add('log_$id')) continue;
        mergedList.add({
          ...l,
          '_is_message': false,
          'created_at_parsed':
              DateTime.tryParse(l['created_at'] ?? '') ?? DateTime(0),
        });
      }
    }

    mergedList.sort((a, b) {
      final aTime = a['created_at_parsed'] as DateTime;
      final bTime = b['created_at_parsed'] as DateTime;
      return bTime.compareTo(aTime);
    });

    // Filter out soft-deleted messages
    mergedList.removeWhere((item) =>
        item['_is_message'] == true && item['is_deleted'] == true);

    // Filter out messages from blocked users
    final blockedIds = provider.blockedUserIds;
    if (blockedIds.isNotEmpty) {
      mergedList.removeWhere((item) =>
          item['_is_message'] == true &&
          item['sender_id'] != myUserId &&
          blockedIds.contains(item['sender_id']));
    }

    if (_animatedMessageIds.isEmpty && messages.isNotEmpty && !_isLoadingMessages) {
      for (final msg in messages) {
        final id = msg['id'] as String?;
        if (id != null) {
          _animatedMessageIds.add(id);
        }
      }
    }

    final membership = provider.myTribes.firstWhereOrNull(
      (t) {
        final tr = t['tribe'] as Map<String, dynamic>?;
        return t['tribe_id'] == widget.tribeId ||
            t['id'] == widget.tribeId ||
            (tr != null && tr['id'] == widget.tribeId);
      },
    );
    final tribeMap = membership != null
        ? membership['tribe'] as Map<String, dynamic>?
        : null;
    final avatarUrl =
        tribeMap != null ? tribeMap['avatar_url']?.toString() ?? '' : '';

    final isBlocked = provider.myTribes.any(
      (t) =>
          (t['tribe_id'] == widget.tribeId || t['id'] == widget.tribeId) &&
          (t['status'] == 'removed' ||
              t['status'] == 'left' ||
              t['status'] == 'declined'),
    );

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
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TribeDetailsPage(tribeId: widget.tribeId),
                    ),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: context.accentSecondary, width: 1.5),
                        color: context.surfaceSecondary,
                        image: avatarUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(avatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: avatarUrl.isEmpty
                          ? const Icon(Icons.group_rounded, size: 16, color: Colors.white70)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.tribeName,
                            style: context.bodyText.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Tap for Mafia Info",
                            style: context.captionText
                                .copyWith(color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        actions: _selectedMessage == null
            ? []
            : [
                // Report — only for other people's messages
                if (_selectedMessage!['sender_id'] != myUserId &&
                    _selectedMessage!['is_deleted'] != true)
                  IconButton(
                    icon: const Icon(Icons.report_gmailerrorred_outlined,
                        color: Colors.orangeAccent),
                    tooltip: 'Report Message',
                    onPressed: () {
                      final msg = _selectedMessage!;
                      setState(() {
                        _selectedMessage = null;
                      });
                      _showReportDialog(msg, provider);
                    },
                  ),
                // Block — only for other people's messages
                if (_selectedMessage!['sender_id'] != myUserId)
                  IconButton(
                    icon: const Icon(Icons.block_rounded,
                        color: Colors.red),
                    tooltip: 'Block User',
                    onPressed: () {
                      final msg = _selectedMessage!;
                      setState(() {
                        _selectedMessage = null;
                      });
                      _showBlockConfirmation(msg, provider);
                    },
                  ),
                // Reply — always (if not deleted)
                if (_selectedMessage!['is_deleted'] != true)
                  IconButton(
                    icon: const Icon(Icons.reply_rounded, color: Colors.white),
                    tooltip: 'Reply',
                    onPressed: () {
                      final msg = _selectedMessage!;
                      setState(() {
                        _selectedMessage = null;
                        _replyMessage = msg;
                      });
                      _messageFocusNode.requestFocus();
                    },
                  ),
                // Delete — only for own messages
                if (_selectedMessage!['sender_id'] == myUserId &&
                    _selectedMessage!['is_deleted'] != true)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent),
                    tooltip: 'Delete',
                    onPressed: () async {
                      final msg = _selectedMessage!;
                      setState(() {
                        _selectedMessage = null;
                      });
                      await provider.softDeleteTribeMessage(
                          widget.tribeId, msg['id'] as String);
                    },
                  ),
                const SizedBox(width: 8),
              ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoadingMessages
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.accentSecondary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : mergedList.isEmpty
                      ? Center(
                          child: Text(
                            "Welcome to your Mafia Chat room!",
                            style:
                                context.bodyText.copyWith(color: context.textMuted),
                          ),
                        )
                      : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      itemCount: mergedList.length,
                      itemBuilder: (context, index) {
                        final item = mergedList[index];
                        final isMsg = item['_is_message'] == true;

                        if (!isMsg) {
                          // Render inline system divider
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getActivityLogText(item, myUserId),
                                  style: context.captionText
                                      .copyWith(color: context.textMuted),
                                ),
                              ),
                            ),
                          );
                        }

                        // Render message bubble
                        final senderRaw = item['sender'];
                        final Map<String, dynamic>? sender = senderRaw is List
                            ? (senderRaw.isNotEmpty ? senderRaw.first as Map<String, dynamic>? : null)
                            : (senderRaw as Map<String, dynamic>?);
                        final senderName = sender != null
                            ? sender['name']?.toString() ?? 'Someone'
                            : 'Someone';
                        final senderAvatar = sender != null
                            ? sender['avatar_url']?.toString() ?? ''
                            : '';
                        final isDeleted = item['is_deleted'] == true;

                        final replyToRaw = item['reply_to'];
                        final Map<String, dynamic>? replyTo = replyToRaw is List
                            ? (replyToRaw.isNotEmpty ? replyToRaw.first as Map<String, dynamic>? : null)
                            : (replyToRaw as Map<String, dynamic>?);

                        final msgId = item['id'] as String;
                        final key = _messageKeys.putIfAbsent(msgId, () => GlobalKey());

                        final hasAlreadyAnimated = _animatedMessageIds.contains(msgId);
                        if (!hasAlreadyAnimated) {
                          _animatedMessageIds.add(msgId);
                        }

                        final childWidget = SwipeToReply(
                          key: key,
                          onReply: () {
                            if (isDeleted) return;
                            setState(() {
                              _replyMessage = item;
                            });
                            _messageFocusNode.requestFocus();
                          },
                          child: GestureDetector(
                            onLongPress: () {
                              if (isDeleted) return;
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _selectedMessage = item;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.symmetric(vertical: 10.0),
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              color: msgId == _highlightedMessageId
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : (_selectedMessage?['id'] == item['id']
                                      ? context.accentSecondary
                                          .withValues(alpha: 0.15)
                                      : Colors.transparent),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (replyTo != null) ...[
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 36,
                                            height: 32,
                                            child: CustomPaint(
                                              painter: ThreadConnectorTopPainter(
                                                color: Colors.white.withValues(alpha: 0.15),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                _scrollToAndHighlightMessage(
                                                    replyTo['id'] as String,
                                                    mergedList);
                                              },
                                              behavior: HitTestBehavior.opaque,
                                              child: _buildThreadReplyBlock(replyTo, context),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Left Column (Avatar + optional top connector line)
                                          SizedBox(
                                            width: 36,
                                            child: Column(
                                              children: [
                                                if (replyTo != null)
                                                  Container(
                                                    width: 1.5,
                                                    height: 12,
                                                    color: Colors.white.withValues(alpha: 0.15),
                                                  ),
                                                CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: context.surfaceSecondary,
                                                  backgroundImage: senderAvatar.isNotEmpty
                                                      ? NetworkImage(senderAvatar)
                                                      : null,
                                                  child: senderAvatar.isEmpty
                                                      ? Text(
                                                          senderName.isNotEmpty
                                                              ? senderName.substring(0, 1).toUpperCase()
                                                              : '?',
                                                          style: const TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.bold),
                                                        )
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Right Column (Header + content)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (replyTo != null)
                                                  const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          senderName,
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        if (item['sender_id'] == myUserId) ...[
                                                          const SizedBox(width: 6),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                            decoration: BoxDecoration(
                                                              color: context.accentSecondary.withValues(alpha: 0.15),
                                                              borderRadius: BorderRadius.circular(4),
                                                              border: Border.all(
                                                                color: context.accentSecondary.withValues(alpha: 0.3),
                                                                width: 0.5,
                                                              ),
                                                            ),
                                                            child: Text(
                                                              "You",
                                                              style: TextStyle(
                                                                color: context.accentSecondary,
                                                                fontSize: 9,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    Text(
                                                      _formatMessageTime(item['created_at'] as String?),
                                                      style: TextStyle(
                                                        color: Colors.white.withValues(alpha: 0.4),
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                isDeleted
                                                    ? Text(
                                                        "This message was deleted",
                                                        style: context.bodyText.copyWith(
                                                          color: Colors.white38,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      )
                                                    : item['message_type'] == 'image'
                                                        ? ClipRRect(
                                                            borderRadius: BorderRadius.circular(8),
                                                            child: Image.network(
                                                              item['attachment_url']?.toString() ?? '',
                                                              width: 200,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (context, error, stackTrace) =>
                                                                  const Icon(Icons.broken_image_rounded, size: 40),
                                                            ),
                                                          )
                                                        : Text(
                                                            item['content']?.toString() ?? '',
                                                            style: context.bodyText.copyWith(
                                                              color: Colors.white,
                                                              height: 1.4,
                                                            ),
                                                          ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );

                        return RepaintBoundary(
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
                                    alignment: Alignment.bottomLeft,
                                  ),
                        );
                      },
                    ),
            ),
            if (_replyMessage != null)
              Builder(
                builder: (context) {
                  final replySenderRaw = _replyMessage!['sender'];
                  final Map<String, dynamic>? replySender = replySenderRaw is List
                      ? (replySenderRaw.isNotEmpty ? replySenderRaw.first as Map<String, dynamic>? : null)
                      : (replySenderRaw as Map<String, dynamic>?);
                  final replySenderName = replySender != null
                      ? replySender['name']?.toString() ?? 'Someone'
                      : 'Someone';
                  final bool isReplyToMe = _replyMessage!['sender_id'] == myUserId;
                  final String replyDisplayName = isReplyToMe ? "You" : replySenderName;

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
                                  replyDisplayName,
                                  style: TextStyle(
                                    color: context.accentSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _replyMessage!['content']?.toString() ?? 'Attachment',
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
                },
              ),
            if (isBlocked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.redAccent.withValues(alpha: 0.1),
                child: const Text(
                  "You are no longer a member of this Mafia.",
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              )
            else if (!provider.hasPermission(widget.tribeId, 'post_messages'))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.white.withValues(alpha: 0.05),
                child: Text(
                  "You have read-only access in this Mafia.",
                  style: TextStyle(
                      color: context.textSecondary, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: context.surfaceSecondary,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          style: context.bodyText
                              .copyWith(color: context.textPrimary),
                          decoration: const InputDecoration(
                            hintText: "Message Mafia...",
                            hintStyle: TextStyle(color: Colors.white30),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.accentSecondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Report Dialog ──

  void _showReportDialog(Map<String, dynamic> message, TribeProvider provider) {
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
                            await provider.reportTribeMessage(
                              reportedUserId: message['sender_id'] as int,
                              messageId: message['id'] as String,
                              messageContent: message['content'] as String? ?? '',
                              reason: selectedReason,
                              additionalDetails: detailsController.text.trim().isEmpty
                                  ? null
                                  : detailsController.text.trim(),
                            );

                            if (mounted) {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(this.context).showSnackBar(
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
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text("Could not report message. Please try again."),
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

  // ── Block Confirmation ──

  void _showBlockConfirmation(Map<String, dynamic> message, TribeProvider provider) {
    final senderRaw = message['sender'];
    final Map<String, dynamic>? sender = senderRaw is List
        ? (senderRaw.isNotEmpty ? senderRaw.first as Map<String, dynamic>? : null)
        : (senderRaw as Map<String, dynamic>?);
    final senderName = sender?['name']?.toString() ?? 'this user';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return GlassmorphicAlertDialog(
          title: Text(
            "Block $senderName?",
            style: context.screenHeading.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "You won't see their messages in any Mafia chat. You can unblock them later from your settings.",
            style: context.bodyText.copyWith(color: context.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text("Cancel", style: TextStyle(color: context.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await provider.blockUserInTribe(message['sender_id'] as int);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("$senderName has been blocked."),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Could not block user. Please try again."),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text("Block", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _scrollToAndHighlightMessage(
      String replyToId, List<Map<String, dynamic>> messages) async {
    final targetIndex = messages.indexWhere((m) => m['id'] == replyToId);
    if (targetIndex == -1 || !_scrollController.hasClients) return;

    final totalMessages = messages.length;
    final scrollExtent = _scrollController.position.maxScrollExtent;
    // In our reverse list, newest (bottom) is at index 0 (0.0 offset),
    // and oldest (top) is at index totalMessages - 1 (maxScrollExtent offset).
    final double fraction = targetIndex / totalMessages;
    final double estimatedOffset =
        (fraction * scrollExtent).clamp(0.0, scrollExtent);

    // Jump close to target if not yet built
    GlobalKey? targetKey = _messageKeys[replyToId];
    if (targetKey == null || targetKey.currentContext == null) {
      _scrollController.jumpTo(estimatedOffset);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Precise scroll using ensureVisible
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

    // Flash highlight
    if (mounted) {
      setState(() {
        _highlightedMessageId = replyToId;
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    }
  }

  String _formatMessageTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();

      final hour = dateTime.hour > 12
          ? dateTime.hour - 12
          : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      final timeStr = "$hour:$minute $period";

      if (dateTime.year == now.year &&
          dateTime.month == now.month &&
          dateTime.day == now.day) {
        return "Today, $timeStr";
      }

      final yesterday = DateTime(now.year, now.month, now.day - 1);
      if (dateTime.year == yesterday.year &&
          dateTime.month == yesterday.month &&
          dateTime.day == yesterday.day) {
        return "Yesterday, $timeStr";
      }

      return "${dateTime.day}/${dateTime.month}/${dateTime.year}, $timeStr";
    } catch (_) {
      return '';
    }
  }

  Widget _buildThreadReplyBlock(Map<String, dynamic> replyTo, BuildContext context) {
    final replyToSenderRaw = replyTo['sender'];
    final Map<String, dynamic>? replyToSender = replyToSenderRaw is List
        ? (replyToSenderRaw.isNotEmpty ? replyToSenderRaw.first as Map<String, dynamic>? : null)
        : (replyToSenderRaw as Map<String, dynamic>?);
    final replyToSenderName = replyToSender != null
        ? replyToSender['name']?.toString() ?? 'Someone'
        : 'Someone';
    final replyToSenderAvatar = replyToSender != null
        ? replyToSender['avatar_url']?.toString() ?? ''
        : '';
    final myUserId = Provider.of<ProfileProvider>(context, listen: false).userId;
    final bool isReplyToMe = replyTo['sender_id'] == myUserId;
    final String replyToDisplayName = isReplyToMe ? "You" : replyToSenderName;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 9,
          backgroundColor: context.surfaceSecondary,
          backgroundImage: replyToSenderAvatar.isNotEmpty
              ? NetworkImage(replyToSenderAvatar)
              : null,
          child: replyToSenderAvatar.isEmpty
              ? Text(
                  replyToSenderName.isNotEmpty
                      ? replyToSenderName.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 8,
                      color: Colors.white))
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          replyToDisplayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            replyTo['content']?.toString() ?? 'Attachment',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
            child: SizedBox(
              width: double.infinity,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class ThreadConnectorTopPainter extends CustomPainter {
  final Color color;
  const ThreadConnectorTopPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    path.moveTo(size.width, size.height / 2);
    path.quadraticBezierTo(
      size.width / 2,
      size.height / 2,
      size.width / 2,
      size.height,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
