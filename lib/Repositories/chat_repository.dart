import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Providers/LocalDatabaseHelper.dart';
import 'package:sqflite/sqflite.dart';

abstract class ChatRepository {
  Future<List<String>> fetchUserRoomIds(int myUserId);
  Future<List<Map<String, dynamic>>> fetchDirectParticipants(
      List<String> roomIds, int myUserId);
  Future<Map<String, dynamic>?> getCommonDirectRoom(
      int myUserId, int otherUserId, List<String> myRoomIds);
  Future<String> createChatRoom();
  Future<void> addParticipants(String roomId, int myUserId, int otherUserId);
  Future<void> insertMessageLocally(
    String id,
    String roomId,
    int senderId,
    String payload, {
    String status = 'sent',
    String? createdAt,
    String? replyToMessageId,
    String? replyToMessagePayload,
    String? replyToMessageSenderName,
  });
  Future<void> updateMessageStatusLocally(String messageId, String status);
  Future<void> deleteMessageLocally(String id);
  Future<Map<String, dynamic>?> getMessageByIdLocally(String id);
  Future<List<Map<String, dynamic>>> getMessagesForRoomLocally(String roomId);
  Future<List<Map<String, dynamic>>> getUnreadSentMessagesLocally(int senderId);
  Future<List<Map<String, dynamic>>> getUnreadIncomingMessagesLocally(
      int senderId);
  Future<int> getTotalUnreadCountLocally(int myUserId);
  Future<List<Map<String, dynamic>>> getRoomUnreadCountsLocally(int myUserId);
  Future<void> clearLocalDatabase();
  Future<Map<String, dynamic>?> getLastMessageForRoom(String roomId);
  Future<void> upsertMessageToSupabase(Map<String, dynamic> messageData);
  Future<void> deleteMessageInSupabase(String messageId);
  Future<void> updateMessageStatusInSupabase(String messageId, String status);
  Future<List<Map<String, dynamic>>> fetchMessagesFromSupabase(String roomId);
  Future<List<Map<String, dynamic>>> fetchPendingMessagesFromSupabase(
      List<String> roomIds, int myUserId);
  Future<List<Map<String, dynamic>>> fetchDeliveredMessagesFromSupabase(
      String roomId, int myUserId);
  Future<List<Map<String, dynamic>>> fetchSupabaseMessageStatuses(
      List<String> messageIds);
  Future<void> updatePushTokenInSupabase(int myUserId, String token);
  Future<void> markRoomMessagesAsReadLocally(String roomId, int myUserId);
  Future<void> deleteDirectRoomParticipantsLocallyAndRemotely(
      int profileId, String roomId, int myUserId);
  RealtimeChannel subscribeToRoom(
    String roomId, {
    required void Function(dynamic payload) onInsert,
    required void Function(dynamic payload) onUpdate,
    required void Function(dynamic payload) onDelete,
    required void Function(RealtimeSubscribeStatus status) onSubscribeStatus,
    required void Function(Map<String, dynamic> payload) onTyping,
  });
  Future<void> sendTypingBroadcast(
      RealtimeChannel channel, int userId, bool isTyping);
  void removeChannel(RealtimeChannel channel);
}

class SupabaseChatRepository implements ChatRepository {
  final SupabaseClient _client;
  final LocalDatabaseHelper _localDb;

  SupabaseChatRepository({SupabaseClient? client, LocalDatabaseHelper? localDb})
      : _client = client ?? Supabase.instance.client,
        _localDb = localDb ?? LocalDatabaseHelper.instance;

  @override
  Future<List<String>> fetchUserRoomIds(int myUserId) async {
    final response = await _client
        .from('room_participants')
        .select('room_id')
        .eq('user_id', myUserId);
    return (response as List).map((r) => r['room_id'] as String).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDirectParticipants(
      List<String> roomIds, int myUserId) async {
    final response = await _client
        .from('room_participants')
        .select('room_id, user_id, chat_rooms!inner(type)')
        .eq('chat_rooms.type', 'direct')
        .filter('room_id', 'in', '(${roomIds.join(",")})');
    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<Map<String, dynamic>?> getCommonDirectRoom(
      int myUserId, int otherUserId, List<String> myRoomIds) async {
    return await _client
        .from('room_participants')
        .select('room_id, chat_rooms!inner(type)')
        .eq('user_id', otherUserId)
        .eq('chat_rooms.type', 'direct')
        .filter('room_id', 'in', '(${myRoomIds.join(",")})')
        .limit(1)
        .maybeSingle();
  }

  @override
  Future<String> createChatRoom() async {
    final newRoom = await _client
        .from('chat_rooms')
        .insert({'type': 'direct'})
        .select('id')
        .single();
    return newRoom['id'] as String;
  }

  @override
  Future<void> addParticipants(
      String roomId, int myUserId, int otherUserId) async {
    await _client.from('room_participants').insert([
      {'room_id': roomId, 'user_id': myUserId},
      {'room_id': roomId, 'user_id': otherUserId},
    ]);
  }

  @override
  Future<void> insertMessageLocally(
    String id,
    String roomId,
    int senderId,
    String payload, {
    String status = 'sent',
    String? createdAt,
    String? replyToMessageId,
    String? replyToMessagePayload,
    String? replyToMessageSenderName,
  }) async {
    await _localDb.insertMessage(
      id,
      roomId,
      senderId,
      payload,
      status: status,
      createdAt: createdAt,
      replyToMessageId: replyToMessageId,
      replyToMessagePayload: replyToMessagePayload,
      replyToMessageSenderName: replyToMessageSenderName,
    );
  }

  @override
  Future<void> updateMessageStatusLocally(
      String messageId, String status) async {
    await _localDb.updateMessageStatus(messageId, status);
  }

  @override
  Future<void> deleteMessageLocally(String id) async {
    await _localDb.deleteMessage(id);
  }

  @override
  Future<Map<String, dynamic>?> getMessageByIdLocally(String id) async {
    return await _localDb.getMessageById(id);
  }

  @override
  Future<List<Map<String, dynamic>>> getMessagesForRoomLocally(
      String roomId) async {
    return await _localDb.getMessagesForRoom(roomId);
  }

  @override
  Future<List<Map<String, dynamic>>> getUnreadSentMessagesLocally(
      int senderId) async {
    return await _localDb.getUnreadSentMessages(senderId);
  }

  @override
  Future<List<Map<String, dynamic>>> getUnreadIncomingMessagesLocally(
      int senderId) async {
    final db = await _localDb.database;
    return await db.query(
      'messages',
      columns: ['id'],
      where: "sender_id != ? AND status != 'read'",
      whereArgs: [senderId],
    );
  }

  @override
  Future<int> getTotalUnreadCountLocally(int myUserId) async {
    final db = await _localDb.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM messages WHERE sender_id != ? AND status != 'read'",
      [myUserId],
    );
    if (result.isNotEmpty) {
      return Sqflite.firstIntValue(result) ?? 0;
    }
    return 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getRoomUnreadCountsLocally(
      int myUserId) async {
    final db = await _localDb.database;
    return await db.rawQuery(
      "SELECT room_id, COUNT(*) as count FROM messages WHERE sender_id != ? AND status != 'read' GROUP BY room_id",
      [myUserId],
    );
  }

  @override
  Future<void> clearLocalDatabase() async {
    await _localDb.clearDatabase();
  }

  @override
  Future<Map<String, dynamic>?> getLastMessageForRoom(String roomId) async {
    return await _localDb.getLastMessageForRoom(roomId);
  }

  @override
  Future<void> upsertMessageToSupabase(Map<String, dynamic> messageData) async {
    await _client.from('messages').upsert(messageData, onConflict: 'id');
  }

  @override
  Future<void> deleteMessageInSupabase(String messageId) async {
    await _client.from('messages').delete().eq('id', messageId);
  }

  @override
  Future<void> updateMessageStatusInSupabase(
      String messageId, String status) async {
    await _client
        .from('messages')
        .update({'status': status}).eq('id', messageId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMessagesFromSupabase(
      String roomId) async {
    final response = await _client
        .from('messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPendingMessagesFromSupabase(
      List<String> roomIds, int myUserId) async {
    final response = await _client
        .from('messages')
        .select()
        .filter('room_id', 'in', '(${roomIds.join(',')})')
        .inFilter('status', ['sent', 'delivered'])
        .neq('sender_id', myUserId);
    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDeliveredMessagesFromSupabase(
      String roomId, int myUserId) async {
    final response = await _client
        .from('messages')
        .select('id')
        .eq('room_id', roomId)
        .eq('status', 'delivered')
        .neq('sender_id', myUserId);
    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSupabaseMessageStatuses(
      List<String> messageIds) async {
    final response = await _client
        .from('messages')
        .select('id, status')
        .filter('id', 'in', '(${messageIds.join(',')})');
    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<void> updatePushTokenInSupabase(int myUserId, String token) async {
    await _client.from('user_push_tokens').upsert({
      'user_id': myUserId,
      'fcm_token': token,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> markRoomMessagesAsReadLocally(
      String roomId, int myUserId) async {
    final db = await _localDb.database;
    await db.update(
      'messages',
      {'status': 'read'},
      where: "room_id = ? AND sender_id != ? AND status != 'read'",
      whereArgs: [roomId, myUserId],
    );
  }

  @override
  Future<void> deleteDirectRoomParticipantsLocallyAndRemotely(
      int profileId, String roomId, int myUserId) async {
    await _client.from('room_participants').delete().eq('room_id', roomId);

    await _client.from('messages').delete().eq('room_id', roomId);

    await _client.from('chat_rooms').delete().eq('id', roomId);

    final db = await _localDb.database;
    await db.delete(
      'messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
    );
  }

  @override
  RealtimeChannel subscribeToRoom(
    String roomId, {
    required void Function(dynamic payload) onInsert,
    required void Function(dynamic payload) onUpdate,
    required void Function(dynamic payload) onDelete,
    required void Function(RealtimeSubscribeStatus status) onSubscribeStatus,
    required void Function(Map<String, dynamic> payload) onTyping,
  }) {
    final channel = _client.channel('room-$roomId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: onInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: onUpdate,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: onDelete,
        )
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            onTyping(Map<String, dynamic>.from(payload));
          },
        );

    channel.subscribe((status, [error]) {
      onSubscribeStatus(status);
    });

    return channel;
  }

  @override
  Future<void> sendTypingBroadcast(
      RealtimeChannel channel, int userId, bool isTyping) async {
    await channel.sendBroadcastMessage(
      event: 'typing',
      payload: {
        'user_id': userId,
        'is_typing': isTyping,
      },
    );
  }

  @override
  void removeChannel(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}
