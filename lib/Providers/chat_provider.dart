import 'dart:async';
import 'package:connect/Models/app_error.dart';
import 'package:connect/Repositories/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/main.dart';

sealed class ChatState {}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatRoomsLoaded extends ChatState {
  final Map<int, String> connectionRooms;
  ChatRoomsLoaded(this.connectionRooms);
}

class ChatError extends ChatState {
  final AppError error;
  ChatError(this.error);
}

class ChatProvider with ChangeNotifier {
  final ChatRepository _repository;
  final AudioPlayer _sendPlayer = AudioPlayer(handleInterruptions: false);
  final AudioPlayer _receivePlayer = AudioPlayer(handleInterruptions: false);

  /// Guard flag to prevent overlapping sync operations from running
  /// concurrently and causing race conditions with local message storage.
  bool _isSyncing = false;

  bool _soundEffectsEnabled = true;
  bool get soundEffectsEnabled => _soundEffectsEnabled;

  Future<void> _loadSoundEffectsPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEffectsEnabled =
          prefs.getBool('chat_sound_effects_enabled') ?? true;
      notifyListeners();
    } catch (e) {
      print("Error loading sound preference: $e");
    }
  }

  Future<void> setSoundEffectsEnabled(bool value) async {
    _soundEffectsEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('chat_sound_effects_enabled', value);
    } catch (e) {
      print("Error saving sound preference: $e");
    }
  }

  Future<void> _preloadSounds() async {
    try {
      await _sendPlayer.setAsset('assets/message_audio/Send Sound.mp3');
      await _receivePlayer.setAsset('assets/message_audio/Receive Sound.mp3');
    } catch (e) {
      print("Error preloading chat sounds: $e");
    }
  }

  Future<void> _playSendSound() async {
    if (!_soundEffectsEnabled) return;
    try {
      await _sendPlayer.seek(Duration.zero);
      _sendPlayer.play();
    } catch (e) {
      print("Error playing send sound: $e");
    }
  }

  Future<void> _playReceiveSound() async {
    if (!_soundEffectsEnabled) return;
    try {
      await _receivePlayer.seek(Duration.zero);
      _receivePlayer.play();
    } catch (e) {
      print("Error playing receive sound: $e");
    }
  }

  final Map<int, String> _drafts = {};
  Map<int, String> get drafts => _drafts;

  String? getDraft(int otherUserId) => _drafts[otherUserId];

  Future<void> loadDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _drafts.clear();
      final myUserId = _userId;
      if (myUserId != null) {
        final keys = prefs.getKeys();
        for (final key in keys) {
          if (key.startsWith('chat_draft_${myUserId}_')) {
            final parts = key.split('_');
            if (parts.length == 4) {
              final otherId = int.tryParse(parts[3]);
              if (otherId != null) {
                final draft = prefs.getString(key);
                if (draft != null && draft.isNotEmpty) {
                  _drafts[otherId] = draft;
                }
              }
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      print("Error loading drafts: $e");
    }
  }

  Future<void> saveDraft(int otherUserId, String draft) async {
    final myUserId = _userId;
    if (myUserId == null) return;
    if (draft.trim().isEmpty) {
      await clearDraft(otherUserId);
      return;
    }
    _drafts[otherUserId] = draft.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_draft_${myUserId}_$otherUserId', draft.trim());
    } catch (e) {
      print("Error saving draft: $e");
    }
  }

  Future<void> clearDraft(int otherUserId) async {
    final myUserId = _userId;
    if (_drafts.containsKey(otherUserId)) {
      _drafts.remove(otherUserId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
    if (myUserId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('chat_draft_${myUserId}_$otherUserId');
    } catch (e) {
      print("Error clearing draft: $e");
    }
  }

  ChatProvider({ChatRepository? chatRepository})
      : _repository = chatRepository ?? SupabaseChatRepository() {
    _loadSoundEffectsPreference();
    _preloadSounds();
    loadDrafts();
  }

  int? _userId;
  List<Map<String, dynamic>> _externalConnections = [];

  String? activeRoomId;
  List<Map<String, dynamic>> _activeRoomMessages = [];
  List<Map<String, dynamic>> get activeRoomMessages =>
      List.unmodifiable(_activeRoomMessages);

  final Map<String, RealtimeChannel> _roomSubscriptions = {};

  int totalUnreadCount = 0;
  int casualUnreadCount = 0;
  int professionalUnreadCount = 0;

  Map<int, String> _lastKnownRooms = {};

  ChatState _state = ChatInitial();

  bool _isOtherUserTyping = false;
  bool get isOtherUserTyping => _isOtherUserTyping;
  Timer? _typingTimer;

  final Map<String, bool> _typingRooms = {};
  final Map<String, Timer> _typingRoomTimers = {};

  bool isRoomTyping(String roomId) => _typingRooms[roomId] ?? false;

  final Map<String, Map<String, dynamic>?> _lastMessagesByRoom = {};
  Map<String, Map<String, dynamic>?> get lastMessagesByRoom =>
      _lastMessagesByRoom;

  Future<void> _updateLastMessageForRoomSilent(String roomId) async {
    final lastMsg = await _repository.getLastMessageForRoom(roomId);
    _lastMessagesByRoom[roomId] = lastMsg;
    debugPrint("[ChatProvider] _updateLastMessageForRoomSilent: Room $roomId updated last message: ${lastMsg != null ? lastMsg['payload'] : 'null'}");
  }

  Future<void> updateLastMessageForRoom(String roomId) async {
    await _updateLastMessageForRoomSilent(roomId);
    notifyListeners();
  }

  ChatState get state => _state;

  bool get isChatRoomsLoaded => _state is ChatRoomsLoaded;
  Map<int, String> get connectionRooms => _state is ChatRoomsLoaded
      ? (_state as ChatRoomsLoaded).connectionRooms
      : _lastKnownRooms;
  AppError? get lastError =>
      _state is ChatError ? (_state as ChatError).error : null;

  void _setError(Object e) {
    _state = ChatError(AppError.from(e));
    notifyListeners();
  }

  void _setRoomsLoadedState(Map<int, String> rooms) {
    _lastKnownRooms = rooms;
    _state = ChatRoomsLoaded(rooms);
  }

  void clearError() {
    _state = ChatRoomsLoaded(_lastKnownRooms);
    notifyListeners();
  }

  void updateFromProviders(
      int? userId, List<Map<String, dynamic>> connections) {
    final bool userIdChanged = _userId != userId;

    // Only update connections reference if the list content changed
    // Use a simple length + first-id check as a cheap guard
    final bool connectionsChanged = _connectionsChanged(connections);

    _userId = userId;
    if (connectionsChanged) {
      _externalConnections = List.from(connections);
    }

    if (userIdChanged) {
      loadDrafts();
      if (userId != null) {
        loadChatRooms();
      }
    } else if (connectionsChanged && userId != null) {
      debugPrint("[ChatProvider] Connections list changed. Reloading chat rooms and updating subscriptions...");
      loadChatRooms(silent: true);
    }
  }

  bool _connectionsChanged(List<Map<String, dynamic>> newConnections) {
    if (newConnections.length != _externalConnections.length) return true;
    if (newConnections.isEmpty) return false;
    // Check first and last id as a quick proxy for list identity
    return newConnections.first['id'] != _externalConnections.first['id'] ||
        newConnections.last['id'] != _externalConnections.last['id'];
  }

  Future<void> loadChatRooms({bool silent = false}) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      if (!silent) {
        _state = ChatLoading();
        notifyListeners();
      }

      final myRoomIds = await _repository.fetchUserRoomIds(myUserId);

      final Map<int, String> newRooms = {};

      if (myRoomIds.isNotEmpty) {
        final participants =
            await _repository.fetchDirectParticipants(myRoomIds, myUserId);

        for (final row in participants) {
          final int uId = row['user_id'] as int;
          final String rId = row['room_id'] as String;
          if (uId != myUserId) {
            newRooms[uId] = rId;
            subscribeToRoom(rId);
          }
        }
      }

      _setRoomsLoadedState(newRooms);

      _lastMessagesByRoom.clear();
      for (final roomId in newRooms.values) {
        await _updateLastMessageForRoomSilent(roomId);
      }

      notifyListeners();

      await fetchPendingMessages();
      await syncOutgoingMessageStatuses();
      await syncIncomingMessageStatuses();
      await updateUnreadCount();
    } catch (e) {
      print("Error loading chat rooms: $e");
      _setError(e);
    }
  }

  Future<String> getOrCreateDirectRoom(int otherUserId) async {
    final myUserId = _userId;
    if (myUserId == null) throw Exception("User not authenticated");

    final rooms = connectionRooms;
    if (rooms.containsKey(otherUserId)) {
      final roomId = rooms[otherUserId]!;
      subscribeToRoom(roomId);
      return roomId;
    }

    try {
      final myRoomIds = await _repository.fetchUserRoomIds(myUserId);

      if (myRoomIds.isNotEmpty) {
        final common = await _repository.getCommonDirectRoom(
            myUserId, otherUserId, myRoomIds);

        if (common != null) {
          final roomId = common['room_id'] as String;
          final currentRooms = Map<int, String>.from(connectionRooms);
          currentRooms[otherUserId] = roomId;
          _setRoomsLoadedState(currentRooms);
          subscribeToRoom(roomId);
          notifyListeners();
          return roomId;
        }
      }

      final roomId = await _repository.createChatRoom();
      await _repository.addParticipants(roomId, myUserId, otherUserId);

      final currentRooms = Map<int, String>.from(connectionRooms);
      currentRooms[otherUserId] = roomId;
      _setRoomsLoadedState(currentRooms);
      subscribeToRoom(roomId);
      notifyListeners();
      return roomId;
    } catch (e) {
      print("Error in getOrCreateDirectRoom: $e");
      _setError(e);
      rethrow;
    }
  }

  Future<void> sendChatMessage({
    required String roomId,
    required String text,
    String? replyToMessageId,
    String? replyToMessagePayload,
    String? replyToMessageSenderName,
  }) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    // _playSendSound();

    final messageId = const Uuid().v4();
    final createdAt = DateTime.now().toUtc().toIso8601String();

    await _repository.insertMessageLocally(
      messageId,
      roomId,
      myUserId,
      text,
      status: 'pending',
      createdAt: createdAt,
      replyToMessageId: replyToMessageId,
      replyToMessagePayload: replyToMessagePayload,
      replyToMessageSenderName: replyToMessageSenderName,
    );
    await _updateLastMessageForRoomSilent(roomId);
    if (activeRoomId == roomId) {
      await refreshActiveRoomMessages();
    } else {
      notifyListeners();
    }

    try {
      await _repository.upsertMessageToSupabase({
        'id': messageId,
        'room_id': roomId,
        'sender_id': myUserId,
        'payload': text,
        'status': 'sent',
        'created_at': createdAt,
        'updated_at': createdAt,
        'reply_to_message_id': replyToMessageId,
        'reply_to_message_payload': replyToMessagePayload,
        'reply_to_message_sender_name': replyToMessageSenderName,
      });

      String resolvedStatus = 'sent';
      try {
        final existingStatuses =
            await _repository.fetchSupabaseMessageStatuses([messageId]);
        if (existingStatuses.isNotEmpty) {
          resolvedStatus =
              existingStatuses.first['status'] as String? ?? 'sent';
        }
      } catch (checkError) {
        print("Error checking supabase message status: $checkError");
      }

      await _updateMessageStatusLocallySafely(messageId, resolvedStatus);
      _playSendSound();
      await _updateLastMessageForRoomSilent(roomId);
      if (activeRoomId == roomId) {
        await refreshActiveRoomMessages();
      } else {
        notifyListeners();
      }
    } catch (e) {
      print("Error sending message: $e");
      await _updateMessageStatusLocallySafely(messageId, 'error');
      if (activeRoomId == roomId) {
        await refreshActiveRoomMessages();
      } else {
        notifyListeners();
      }
      _setError(e);
    }
  }

  Future<void> resendChatMessage(String messageId) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    // _playSendSound();

    try {
      final localMsg = await _repository.getMessageByIdLocally(messageId);
      if (localMsg == null) return;

      final roomId = localMsg['room_id'] as String;
      final text = localMsg['payload'] as String;
      final replyToMessageId = localMsg['reply_to_message_id'] as String?;
      final replyToMessagePayload =
          localMsg['reply_to_message_payload'] as String?;
      final replyToMessageSenderName =
          localMsg['reply_to_message_sender_name'] as String?;

      await _repository.updateMessageStatusLocally(messageId, 'pending');
      if (activeRoomId == roomId) {
        await refreshActiveRoomMessages();
      } else {
        notifyListeners();
      }

      final createdAt = DateTime.now().toUtc().toIso8601String();

      await _repository.upsertMessageToSupabase({
        'id': messageId,
        'room_id': roomId,
        'sender_id': myUserId,
        'payload': text,
        'status': 'sent',
        'created_at': createdAt,
        'updated_at': createdAt,
        'reply_to_message_id': replyToMessageId,
        'reply_to_message_payload': replyToMessagePayload,
        'reply_to_message_sender_name': replyToMessageSenderName,
      });

      String resolvedStatus = 'sent';
      try {
        final existingStatuses =
            await _repository.fetchSupabaseMessageStatuses([messageId]);
        if (existingStatuses.isNotEmpty) {
          resolvedStatus =
              existingStatuses.first['status'] as String? ?? 'sent';
        }
      } catch (checkError) {
        print("Error checking supabase message status: $checkError");
      }

      await _updateMessageStatusLocallySafely(messageId, resolvedStatus);
      _playSendSound();
      await _updateLastMessageForRoomSilent(roomId);
      if (activeRoomId == roomId) {
        await refreshActiveRoomMessages();
      } else {
        notifyListeners();
      }
    } catch (e) {
      print("Error resending message: $e");
      await _updateMessageStatusLocallySafely(messageId, 'error');
      if (activeRoomId != null) {
        await refreshActiveRoomMessages();
      } else {
        notifyListeners();
      }
      _setError(e);
    }
  }

  Future<void> deleteChatMessage(String messageId,
      {required bool deleteForEveryone}) async {
    try {
      final localMsg = await _repository.getMessageByIdLocally(messageId);
      final roomId = localMsg?['room_id'] as String?;

      await _repository.deleteMessageLocally(messageId);

      if (deleteForEveryone) {
        await _repository.deleteMessageInSupabase(messageId);
      }

      if (roomId != null) {
        await _updateLastMessageForRoomSilent(roomId);
      }

      if (activeRoomId != null) {
        await refreshActiveRoomMessages();
      } else {
        notifyListeners();
      }
      await updateUnreadCount();
    } catch (e) {
      print("Error deleting chat message: $e");
      _setError(e);
    }
  }

  void subscribeToRoom(String roomId) {
    if (_roomSubscriptions.containsKey(roomId)) return;

    debugPrint("[ChatProvider] Establishing Realtime subscription for room: $roomId");

    final channel = _repository.subscribeToRoom(
      roomId,
      onInsert: (payload) async {
        final msg = payload.newRecord;
        if (msg == null) return;
        final msgId = msg['id'] as String;
        final rId = msg['room_id'] as String;
        final senderId = msg['sender_id'] as int;
        final payloadText = msg['payload'] as String;

        debugPrint("[ChatProvider] Realtime Postgres INSERT event received. Room: $rId, MessageId: $msgId, SenderId: $senderId, Payload: $payloadText");

        if (senderId == _userId) return;

        final bool isInChat = activeRoomId == rId;
        final replyToId = msg['reply_to_message_id'] as String?;
        final replyToPayload = msg['reply_to_message_payload'] as String?;
        final replyToSenderName =
            msg['reply_to_message_sender_name'] as String?;

        await _repository.insertMessageLocally(
          msgId,
          rId,
          senderId,
          payloadText,
          status: isInChat ? 'read' : 'delivered',
          createdAt: msg['created_at'] as String?,
          replyToMessageId: replyToId,
          replyToMessagePayload: replyToPayload,
          replyToMessageSenderName: replyToSenderName,
        );

        await acknowledgeDelivery(msgId, isActiveInChat: isInChat);
        await _updateLastMessageForRoomSilent(rId);

        if (isInChat) {
          debugPrint("[ChatProvider] Receiver is currently inside the active chat. Refreshing active messages...");
          _playReceiveSound();
          await refreshActiveRoomMessages();
        } else {
          debugPrint("[ChatProvider] Receiver is on another page. Triggering in-app notification banner...");
          _playReceiveSound();
          notifyListeners();

          final senderConnection = _externalConnections.firstWhere(
            (c) => c['id'] == senderId,
            orElse: () => <String, dynamic>{},
          );
          final senderName =
              senderConnection['name']?.toString() ?? 'New Message';
          final senderAvatar = senderConnection['avatarUrl']?.toString() ??
              senderConnection['avatar_url']?.toString() ??
              '';

          showInAppMessageBanner(
            messageId: msgId,
            roomId: rId,
            senderId: senderId,
            senderName: senderName,
            avatarUrl: senderAvatar,
            message: payloadText,
          );
        }
        await updateUnreadCount();
      },
      onUpdate: (payload) async {
        final newRecord = payload.newRecord;
        if (newRecord == null) return;
        final newStatus = newRecord['status'] as String;
        final messageId = newRecord['id'] as String;
        final rId = newRecord['room_id'] as String;

        debugPrint("[ChatProvider] Realtime Postgres UPDATE event received. Room: $rId, MessageId: $messageId, Status: $newStatus");

        await _repository.updateMessageStatusLocally(messageId, newStatus);
        await _updateLastMessageForRoomSilent(rId);

        if (activeRoomId == rId) {
          await refreshActiveRoomMessages();
        } else {
          notifyListeners();
        }
        await updateUnreadCount();
      },
      onDelete: (payload) async {
        final oldRecord = payload.oldRecord;
        if (oldRecord == null) return;
        final messageId = oldRecord['id'] as String?;
        final rId = oldRecord['room_id'] as String?;

        debugPrint("[ChatProvider] Realtime Postgres DELETE event received. Room: $rId, MessageId: $messageId");

        if (messageId != null) {
          final localMsg = await _repository.getMessageByIdLocally(messageId);
          if (localMsg != null) {
            final senderId = localMsg['sender_id'] as int?;
            if (senderId == _userId) {
              // Outgoing message sent by me: deletion from Supabase store-and-forward means recipient read it!
              await _repository.updateMessageStatusLocally(messageId, 'read');
            } else {
              final localStatus = localMsg['status'] as String?;
              if (localStatus != 'read') {
                await _repository.deleteMessageLocally(messageId);
              }
            }
          }

          if (rId != null) {
            await _updateLastMessageForRoomSilent(rId);
          }

          if (activeRoomId == rId) {
            await refreshActiveRoomMessages();
          } else {
            notifyListeners();
          }
          await updateUnreadCount();
        }
      },
      onSubscribeStatus: (status) async {
        debugPrint("[ChatProvider] Realtime subscription status changed for room $roomId: $status");
        if (status == RealtimeSubscribeStatus.subscribed) {
          await syncOutgoingMessageStatuses();
          await updateUnreadCount();
        }
      },
      onTyping: (payload) {
        final int? senderId = payload['user_id'] is int
            ? payload['user_id'] as int
            : int.tryParse(payload['user_id']?.toString() ?? '');
        final bool? typing = payload['is_typing'] as bool?;

        if (senderId != null && typing != null && senderId != _userId) {
          if (activeRoomId == roomId) {
            _isOtherUserTyping = typing;
            _typingTimer?.cancel();
            if (_isOtherUserTyping) {
              _typingTimer = Timer(const Duration(seconds: 5), () {
                _isOtherUserTyping = false;
                notifyListeners();
              });
            }
          }

          _typingRoomTimers[roomId]?.cancel();
          if (typing) {
            _typingRooms[roomId] = true;
            _typingRoomTimers[roomId] = Timer(const Duration(seconds: 5), () {
              _typingRooms.remove(roomId);
              _typingRoomTimers.remove(roomId);
              notifyListeners();
            });
          } else {
            _typingRooms.remove(roomId);
            _typingRoomTimers.remove(roomId);
          }
          notifyListeners();
        }
      },
    );

    _roomSubscriptions[roomId] = channel;
  }

  Future<void> sendTypingStatus(bool isTyping) async {
    final roomId = activeRoomId;
    final myUserId = _userId;
    if (roomId == null || myUserId == null) return;

    final channel = _roomSubscriptions[roomId];
    if (channel == null) return;

    try {
      await _repository.sendTypingBroadcast(channel, myUserId, isTyping);
    } catch (e) {
      print("Error sending typing status: $e");
    }
  }

  Future<void> acknowledgeDelivery(String messageId,
      {bool isActiveInChat = false}) async {
    try {
      await _repository.updateMessageStatusInSupabase(
        messageId,
        isActiveInChat ? 'read' : 'delivered',
        receiverAcked: true,
      );
    } catch (e) {
      print("Error acknowledging delivery: $e");
      _setError(e);
    }
  }

  Future<void> syncOutgoingMessageStatuses() async {
    final myUserId = _userId;
    if (myUserId == null) return;
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final unreadSent =
          await _repository.getUnreadSentMessagesLocally(myUserId);
      if (unreadSent.isEmpty) return;

      final pendingMsgs =
          unreadSent.where((m) => m['status'] == 'pending').toList();
      final serverMsgs =
          unreadSent.where((m) => m['status'] != 'pending').toList();

      for (final msg in pendingMsgs) {
        final msgId = msg['id'] as String;
        final roomId = msg['room_id'] as String;
        try {
          final allMsgs = await _repository.getMessagesForRoomLocally(roomId);
          final fullMsg = allMsgs.firstWhere(
            (m) => m['id'] == msgId,
            orElse: () => <String, dynamic>{},
          );
          if (fullMsg.isNotEmpty) {
            await _repository.upsertMessageToSupabase({
              'id': msgId,
              'room_id': roomId,
              'sender_id': myUserId,
              'payload': fullMsg['payload'],
              'status': 'sent',
              'created_at': fullMsg['created_at'],
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            });
            await _repository.updateMessageStatusLocally(msgId, 'sent');
          }
        } catch (e) {
          print("Retry failed for pending message $msgId: $e");
        }
      }

      if (serverMsgs.isNotEmpty) {
        final messageIds = serverMsgs.map((m) => m['id'] as String).toList();
        final existing =
            await _repository.fetchSupabaseMessageStatuses(messageIds);

        final Map<String, String> supabaseStatuses = {
          for (final row in existing)
            row['id'] as String: row['status'] as String
        };

        for (final local in serverMsgs) {
          final msgId = local['id'] as String;
          final localStatus = local['status'] as String;

          if (!supabaseStatuses.containsKey(msgId)) {
            if (localStatus != 'read') {
              await _repository.updateMessageStatusLocally(msgId, 'read');
            }
          } else {
            final serverStatus = supabaseStatuses[msgId]!;
            if (_statusRank(serverStatus) > _statusRank(localStatus)) {
              await _repository.updateMessageStatusLocally(msgId, serverStatus);
            }
          }
        }
      }

      if (activeRoomId != null) {
        await refreshActiveRoomMessages();
      } else {
        notifyListeners();
      }
      await updateUnreadCount();
    } catch (e) {
      print("Error syncing outgoing message statuses: $e");
      _setError(e);
    } finally {
      _isSyncing = false;
    }
  }

  int _statusRank(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'sent':
        return 1;
      case 'delivered':
        return 2;
      case 'read':
        return 3;
      default:
        return -1;
    }
  }

  Future<void> _updateMessageStatusLocallySafely(
      String messageId, String targetStatus) async {
    try {
      final localMsg = await _repository.getMessageByIdLocally(messageId);
      if (localMsg == null) return;
      final currentStatus = localMsg['status'] as String? ?? 'pending';
      if (targetStatus == 'error') {
        if (currentStatus == 'pending') {
          await _repository.updateMessageStatusLocally(messageId, targetStatus);
        }
      } else if (_statusRank(targetStatus) > _statusRank(currentStatus)) {
        await _repository.updateMessageStatusLocally(messageId, targetStatus);
      }
    } catch (e) {
      print("Error safely updating message status locally: $e");
    }
  }

  Future<void> fetchPendingMessages() async {
    final myUserId = _userId;
    if (myUserId == null) return;
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final roomIds = await _repository.fetchUserRoomIds(myUserId);
      if (roomIds.isEmpty) return;

      final pendingResponse =
          await _repository.fetchPendingMessagesFromSupabase(roomIds, myUserId);

      for (final msg in pendingResponse) {
        final msgId = msg['id'] as String;
        final rId = msg['room_id'] as String;
        final senderId = msg['sender_id'] as int;
        final payloadText = msg['payload'] as String;

        final bool isInChat = activeRoomId == rId;

        await _repository.insertMessageLocally(
          msgId,
          rId,
          senderId,
          payloadText,
          status: isInChat ? 'read' : 'delivered',
          createdAt: msg['created_at'] as String?,
          replyToMessageId: msg['reply_to_message_id'] as String?,
          replyToMessagePayload: msg['reply_to_message_payload'] as String?,
          replyToMessageSenderName:
              msg['reply_to_message_sender_name'] as String?,
        );

        await acknowledgeDelivery(msgId, isActiveInChat: isInChat);
      }

      for (final rId in roomIds) {
        await _updateLastMessageForRoomSilent(rId);
      }

      if (activeRoomId != null) {
        await refreshActiveRoomMessages();
      } else {
        notifyListeners();
      }
      await updateUnreadCount();
    } catch (e) {
      print("Error fetching pending messages: $e");
      _setError(e);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> syncRoomHistory(String roomId) async {
    final myUserId = _userId;
    if (myUserId == null) return;
    try {
      final messages = await _repository.fetchMessagesFromSupabase(roomId);
      for (final msg in messages) {
        final msgId = msg['id'] as String;
        final senderId = msg['sender_id'] as int;
        final serverStatus = msg['status'] as String? ?? 'sent';

        final localMsg = await _repository.getMessageByIdLocally(msgId);
        if (localMsg == null) {
          final String localStatus;
          if (senderId != myUserId && activeRoomId == roomId) {
            localStatus = 'read';
          } else {
            localStatus = serverStatus;
          }

          await _repository.insertMessageLocally(
            msgId,
            roomId,
            senderId,
            msg['payload'] as String,
            status: localStatus,
            createdAt: msg['created_at'] as String?,
            replyToMessageId: msg['reply_to_message_id'] as String?,
            replyToMessagePayload: msg['reply_to_message_payload'] as String?,
            replyToMessageSenderName:
                msg['reply_to_message_sender_name'] as String?,
          );

          if (senderId != myUserId && localStatus == 'read') {
            await acknowledgeDelivery(msgId, isActiveInChat: true);
          } else if (senderId != myUserId && serverStatus == 'sent') {
            await acknowledgeDelivery(msgId, isActiveInChat: false);
            await _repository.updateMessageStatusLocally(msgId, 'delivered');
          }
        } else {
          final localStatus = localMsg['status'] as String? ?? 'sent';
          final targetStatus = _statusRank(serverStatus) > _statusRank(localStatus) ? serverStatus : localStatus;
          
          await _repository.insertMessageLocally(
            msgId,
            roomId,
            senderId,
            localMsg['payload'] as String,
            status: targetStatus,
            createdAt: msg['created_at'] as String?,
            replyToMessageId: msg['reply_to_message_id'] as String?,
            replyToMessagePayload: msg['reply_to_message_payload'] as String?,
            replyToMessageSenderName:
                msg['reply_to_message_sender_name'] as String?,
          );
        }
      }

      await updateLastMessageForRoom(roomId);

      if (activeRoomId == roomId) {
        await refreshActiveRoomMessages();
      }
      await updateUnreadCount();
    } catch (e) {
      print("Error syncing room history: $e");
    }
  }

  Future<void> refreshActiveRoomMessages() async {
    final roomId = activeRoomId;
    if (roomId == null) return;
    
    final messages = await _repository.getMessagesForRoomLocally(roomId);
    if (activeRoomId != roomId) return;
    
    _activeRoomMessages = List<Map<String, dynamic>>.from(messages);
    await _updateLastMessageForRoomSilent(roomId);
    
    if (activeRoomId != roomId) return;
    notifyListeners();
  }

  Future<void> _markDeliveredMessagesAsRead(String roomId) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      final deliveredMsgs = await _repository
          .fetchDeliveredMessagesFromSupabase(roomId, myUserId);

      if (deliveredMsgs.isEmpty) return;

      for (final msg in deliveredMsgs) {
        final msgId = msg['id'] as String;
        final localMsg = await _repository.getMessageByIdLocally(msgId);
        if (localMsg != null) {
          await acknowledgeDelivery(msgId, isActiveInChat: true);
          await _repository.updateMessageStatusLocally(msgId, 'read');
        }
      }

      await refreshActiveRoomMessages();
      await updateUnreadCount();
    } catch (e) {
      print("Error marking delivered messages as read: $e");
      _setError(e);
    }
  }

  Future<void> updatePushToken(String token) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      await _repository.updatePushTokenInSupabase(myUserId, token);
      print("Push token updated successfully in Supabase");
    } catch (e) {
      print("Error updating push token: $e");
      _setError(e);
    }
  }

  Future<void> markRoomMessagesAsReadLocally(String roomId) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      await _repository.markRoomMessagesAsReadLocally(roomId, myUserId);
      await updateLastMessageForRoom(roomId);
      await updateUnreadCount();
    } catch (e) {
      print("Error marking room messages as read locally: $e");
      _setError(e);
    }
  }

  Future<void> syncIncomingMessageStatuses() async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      // NOTE: We intentionally do NOT delete local messages that are missing
      // from the server. A missing server record could be caused by a network
      // hiccup, a concurrent upsert, or a transient Supabase state — not
      // necessarily a deliberate sender deletion. Legitimate deletions are
      // handled exclusively by the realtime onDelete handler.

      for (final roomId in connectionRooms.values) {
        await _updateLastMessageForRoomSilent(roomId);
      }

      totalUnreadCount = await _repository.getTotalUnreadCountLocally(myUserId);

      final roomResults =
          await _repository.getRoomUnreadCountsLocally(myUserId);

      final Map<String, int> roomUnreadMap = {
        for (final row in roomResults)
          row['room_id'] as String: int.tryParse(row['count'].toString()) ?? 0
      };

      int casualCount = 0;
      int professionalCount = 0;

      for (final connection in _externalConnections) {
        final int connId = connection['id'] as int;
        final String? rId = connectionRooms[connId];
        if (rId != null && roomUnreadMap.containsKey(rId)) {
          final int count = roomUnreadMap[rId]!;
          final sharedCard =
              (connection['my_shared_card'] ?? 'both').toString().toLowerCase();

          if (sharedCard == 'casual') {
            casualCount += count;
          } else if (sharedCard == 'professional') {
            professionalCount += count;
          } else {
            casualCount += count;
            professionalCount += count;
          }
        }
      }

      casualUnreadCount = casualCount;
      professionalUnreadCount = professionalCount;

      notifyListeners();
    } catch (e) {
      print("Error syncing incoming message statuses: $e");
      _setError(e);
    }
  }

  void setActiveRoom(String? roomId) {
    activeRoomId = roomId;
    _isOtherUserTyping = false;
    _typingTimer?.cancel();
    if (roomId != null) {
      // Refresh local messages first (fast local DB read), then notify once.
      refreshActiveRoomMessages().then((_) {
        // Heavy network I/O (mark delivered → read, update unread counts)
        // runs in the background AFTER the UI has painted the message list.
        _markDeliveredMessagesAsRead(roomId);
        markRoomMessagesAsReadLocally(roomId).then((_) {
          updateUnreadCount();
        });
      });
    } else {
      _activeRoomMessages = [];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  Future<void> updateUnreadCount() async {
    final myUserId = _userId;
    if (myUserId == null) {
      totalUnreadCount = 0;
      casualUnreadCount = 0;
      professionalUnreadCount = 0;
      return;
    }
    try {
      totalUnreadCount = await _repository.getTotalUnreadCountLocally(myUserId);

      final roomResults =
          await _repository.getRoomUnreadCountsLocally(myUserId);

      final Map<String, int> roomUnreadMap = {
        for (final row in roomResults)
          row['room_id'] as String: int.tryParse(row['count'].toString()) ?? 0
      };

      int casualCount = 0;
      int professionalCount = 0;

      for (final connection in _externalConnections) {
        final int connId = connection['id'] as int;
        final String? rId = connectionRooms[connId];
        if (rId != null && roomUnreadMap.containsKey(rId)) {
          final int count = roomUnreadMap[rId]!;

          final sharedCard =
              (connection['my_shared_card'] ?? 'both').toString().toLowerCase();

          if (sharedCard == 'casual') {
            casualCount += count;
          } else if (sharedCard == 'professional') {
            professionalCount += count;
          } else {
            casualCount += count;
            professionalCount += count;
          }
        }
      }

      casualUnreadCount = casualCount;
      professionalUnreadCount = professionalCount;

      notifyListeners();
    } catch (e) {
      print("Error calculating unread count: $e");
      _setError(e);
    }
  }

  Future<void> handleRoomCleanup(int profileId, String? roomId) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    if (roomId != null) {
      try {
        await _repository.deleteDirectRoomParticipantsLocallyAndRemotely(
            profileId, roomId, myUserId);

        final channel = _roomSubscriptions.remove(roomId);
        if (channel != null) {
          _repository.removeChannel(channel);
        }
        _typingRooms.remove(roomId);
        _typingRoomTimers.remove(roomId)?.cancel();

        print(
            "Chat rooms state and subscriptions updated for deleted profile: $profileId");
      } catch (e) {
        print("Error in handleRoomCleanup during profile deletion: $e");
        _setError(e);
      }
    }

    final currentRooms = Map<int, String>.from(connectionRooms);
    currentRooms.remove(profileId);
    _setRoomsLoadedState(currentRooms);

    if (activeRoomId == roomId) {
      activeRoomId = null;
      _activeRoomMessages = [];
    }

    await updateUnreadCount();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getLastMessageForRoom(String roomId) {
    return _repository.getLastMessageForRoom(roomId);
  }

  Future<void> reportMessage({
    required int reportedUserId,
    String? messageId,
    String? messageContent,
    required String reason,
    String? additionalDetails,
  }) async {
    final myUserId = _userId;
    if (myUserId == null) throw Exception("User not authenticated.");
    await _repository.reportMessage(
      reporterId: myUserId,
      reportedUserId: reportedUserId,
      messageId: messageId,
      messageContent: messageContent,
      reason: reason,
      additionalDetails: additionalDetails,
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    for (final timer in _typingRoomTimers.values) {
      timer.cancel();
    }
    _typingRoomTimers.clear();
    _sendPlayer.dispose();
    _receivePlayer.dispose();
    super.dispose();
  }
}
