import 'package:connect/Models/app_error.dart';
import 'package:connect/Repositories/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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

  ChatProvider({ChatRepository? chatRepository})
      : _repository = chatRepository ?? SupabaseChatRepository();

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

    if (userIdChanged && userId != null) {
      loadChatRooms();
    } else if (connectionsChanged && userId != null) {
      // Only recalculate unread counts when connection list actually changes
      updateUnreadCount();
    }
  }

  bool _connectionsChanged(List<Map<String, dynamic>> newConnections) {
    if (newConnections.length != _externalConnections.length) return true;
    if (newConnections.isEmpty) return false;
    // Check first and last id as a quick proxy for list identity
    return newConnections.first['id'] != _externalConnections.first['id'] ||
        newConnections.last['id'] != _externalConnections.last['id'];
  }

  Future<void> loadChatRooms() async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      _state = ChatLoading();
      notifyListeners();

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
    if (activeRoomId == roomId) {
      await refreshActiveRoomMessages();
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

      await _repository.updateMessageStatusLocally(messageId, 'sent');
      if (activeRoomId == roomId) {
        await refreshActiveRoomMessages();
      }
    } catch (e) {
      print("Error sending message: $e");
      _setError(e);
    }
  }

  Future<void> deleteChatMessage(String messageId,
      {required bool deleteForEveryone}) async {
    try {
      await _repository.deleteMessageLocally(messageId);

      if (deleteForEveryone) {
        await _repository.deleteMessageInSupabase(messageId);
      }

      if (activeRoomId != null) {
        await refreshActiveRoomMessages();
      }
      await updateUnreadCount();
    } catch (e) {
      print("Error deleting chat message: $e");
      _setError(e);
    }
  }

  void subscribeToRoom(String roomId) {
    if (_roomSubscriptions.containsKey(roomId)) return;

    final channel = _repository.subscribeToRoom(
      roomId,
      onInsert: (payload) async {
        final msg = payload.newRecord;
        if (msg == null) return;
        final msgId = msg['id'] as String;
        final rId = msg['room_id'] as String;
        final senderId = msg['sender_id'] as int;
        final payloadText = msg['payload'] as String;

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

        if (isInChat) {
          await refreshActiveRoomMessages();
        } else {
          notifyListeners();
        }
        await updateUnreadCount();
      },
      onUpdate: (payload) async {
        final newRecord = payload.newRecord;
        if (newRecord == null) return;
        final newStatus = newRecord['status'] as String;
        final messageId = newRecord['id'] as String;
        final rId = newRecord['room_id'] as String;

        await _repository.updateMessageStatusLocally(messageId, newStatus);

        if (activeRoomId == rId) {
          await refreshActiveRoomMessages();
        }
        await updateUnreadCount();
      },
      onDelete: (payload) async {
        final oldRecord = payload.oldRecord;
        if (oldRecord == null) return;
        final messageId = oldRecord['id'] as String?;
        final rId = oldRecord['room_id'] as String?;

        if (messageId != null) {
          final localMsg = await _repository.getMessageByIdLocally(messageId);
          if (localMsg != null) {
            final localStatus = localMsg['status'] as String?;
            if (localStatus != 'read') {
              await _repository.deleteMessageLocally(messageId);
            } else {
              await _repository.updateMessageStatusLocally(messageId, 'read');
            }
          }

          if (activeRoomId == rId) {
            await refreshActiveRoomMessages();
          }
          await updateUnreadCount();
        }
      },
      onSubscribeStatus: (status) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await syncOutgoingMessageStatuses();
          await fetchPendingMessages();
          await updateUnreadCount();
        }
      },
    );

    _roomSubscriptions[roomId] = channel;
  }

  Future<void> acknowledgeDelivery(String messageId,
      {bool isActiveInChat = false}) async {
    try {
      await _repository.updateMessageStatusInSupabase(
        messageId,
        isActiveInChat ? 'read' : 'delivered',
      );
    } catch (e) {
      print("Error acknowledging delivery: $e");
      _setError(e);
    }
  }

  Future<void> syncOutgoingMessageStatuses() async {
    final myUserId = _userId;
    if (myUserId == null) return;

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
      await syncIncomingMessageStatuses();
    } catch (e) {
      print("Error syncing outgoing message statuses: $e");
      _setError(e);
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

  Future<void> fetchPendingMessages() async {
    final myUserId = _userId;
    if (myUserId == null) return;

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

      if (activeRoomId != null) {
        await refreshActiveRoomMessages();
      } else {
        notifyListeners();
      }
      await updateUnreadCount();
    } catch (e) {
      print("Error fetching pending messages: $e");
      _setError(e);
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
          if (_statusRank(serverStatus) > _statusRank(localStatus)) {
            await _repository.updateMessageStatusLocally(msgId, serverStatus);
          }
        }
      }

      if (activeRoomId == roomId) {
        await refreshActiveRoomMessages();
      }
      await updateUnreadCount();
    } catch (e) {
      print("Error syncing room history: $e");
    }
  }

  Future<void> refreshActiveRoomMessages() async {
    if (activeRoomId == null) return;
    _activeRoomMessages = List<Map<String, dynamic>>.from(
        await _repository.getMessagesForRoomLocally(activeRoomId!));
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
        await acknowledgeDelivery(msgId, isActiveInChat: true);
        await _repository.updateMessageStatusLocally(msgId, 'read');
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
    } catch (e) {
      print("Error marking room messages as read locally: $e");
      _setError(e);
    }
  }

  Future<void> syncIncomingMessageStatuses() async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      final unreadIncoming =
          await _repository.getUnreadIncomingMessagesLocally(myUserId);

      if (unreadIncoming.isNotEmpty) {
        final messageIds =
            unreadIncoming.map((m) => m['id'] as String).toList();
        final existing =
            await _repository.fetchSupabaseMessageStatuses(messageIds);

        final Set<String> existingIds = {
          for (final row in existing) row['id'] as String
        };

        for (final localId in messageIds) {
          if (!existingIds.contains(localId)) {
            await _repository.deleteMessageLocally(localId);
          }
        }
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
}
