import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<TribeProvider>(context, listen: false);
    provider.setActiveTribe(widget.tribeId);
    provider.subscribeToTribeRealtime(widget.tribeId);
    provider.fetchTribeDetails(widget.tribeId);
    provider.fetchTribeMessagesAndLog(widget.tribeId);
    provider.fetchMyTribes(silent: true);
    _clearTribeNotifications();
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
          SnackBar(content: Text("Failed to send message: $e")),
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

    switch (actionType) {
      case 'joined':
        return isMe ? "You joined the Mafia" : "$actorName joined the Mafia";
      case 'left':
        return isMe ? "You left the Mafia" : "$actorName left the Mafia";
      case 'removed':
        return isMe
            ? "You were removed from the Mafia"
            : "$actorName was removed from the Mafia";
      case 'invited':
        return isMe ? "You invited a user" : "$actorName invited a user";
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
            ? "You updated a member role"
            : "$actorName updated a member role";
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

    // Merge and sort reverse
    final List<Map<String, dynamic>> mergedList = [];
    for (final m in messages) {
      mergedList.add({
        ...m,
        '_is_message': true,
        'created_at_parsed':
            DateTime.tryParse(m['created_at'] ?? '') ?? DateTime(0),
      });
    }
    if (canViewLog) {
      for (final l in logs) {
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
                if (_selectedMessage!['sender_id'] == myUserId &&
                    _selectedMessage!['is_deleted'] != true)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent),
                    onPressed: () async {
                      final msg = _selectedMessage!;
                      setState(() {
                        _selectedMessage = null;
                      });
                      await provider.softDeleteTribeMessage(
                          widget.tribeId, msg['id'] as String);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.reply_rounded, color: Colors.white),
                  onPressed: () {
                    final msg = _selectedMessage!;
                    setState(() {
                      _selectedMessage = null;
                      _replyMessage = msg;
                    });
                    _messageFocusNode.requestFocus();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _selectedMessage = null;
                    });
                  },
                ),
              ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: mergedList.isEmpty
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
                        final isMe = item['sender_id'] == myUserId;
                        final isDeleted = item['is_deleted'] == true;

                        final replyToRaw = item['reply_to'];
                        final Map<String, dynamic>? replyTo = replyToRaw is List
                            ? (replyToRaw.isNotEmpty ? replyToRaw.first as Map<String, dynamic>? : null)
                            : (replyToRaw as Map<String, dynamic>?);

                        return GestureDetector(
                          onLongPress: () {
                            if (isDeleted) return;
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _selectedMessage = item;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            color: _selectedMessage?['id'] == item['id']
                                ? context.accentSecondary
                                    .withValues(alpha: 0.15)
                                : Colors.transparent,
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                // Sender header row (avatar + name) for other members
                                if (!isMe) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
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
                                                      fontSize: 10,
                                                      color: Colors.white))
                                              : null,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          senderName,
                                          style: TextStyle(
                                            color: context.accentSecondary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                // Message bubble
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? context.accentSecondary
                                              .withValues(alpha: 0.8)
                                          : context.surfacePrimary,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: isMe
                                            ? const Radius.circular(16)
                                            : Radius.zero,
                                        bottomRight: isMe
                                            ? Radius.zero
                                            : const Radius.circular(16),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (replyTo != null) ...[
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            margin: const EdgeInsets.only(
                                                bottom: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.black26,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              replyTo['content']
                                                      ?.toString() ??
                                                  'Attachment',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white54,
                                                  fontStyle:
                                                      FontStyle.italic),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                        isDeleted
                                            ? Text(
                                                "This message was deleted",
                                                style:
                                                    context.bodyText.copyWith(
                                                  color: Colors.white38,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              )
                                            : item['message_type'] == 'image'
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: Image.network(
                                                      item['attachment_url']
                                                              ?.toString() ??
                                                          '',
                                                      width: 200,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : Text(
                                                    item['content']
                                                            ?.toString() ??
                                                        '',
                                                    style: context.bodyText
                                                        .copyWith(
                                                            color:
                                                                Colors.white),
                                                  ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_replyMessage != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: context.surfacePrimary,
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _replyMessage!['content']?.toString() ??
                            "Image Attachment",
                        style: const TextStyle(
                            color: Colors.white70, fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 16, color: Colors.white70),
                      onPressed: () {
                        setState(() {
                          _replyMessage = null;
                        });
                      },
                    ),
                  ],
                ),
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
}
