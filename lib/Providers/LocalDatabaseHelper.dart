import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabaseHelper {
  static final LocalDatabaseHelper instance = LocalDatabaseHelper._init();
  static Database? _database;

  LocalDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('connect_chat.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        sender_id INTEGER NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        reply_to_message_id TEXT,
        reply_to_message_payload TEXT,
        reply_to_message_sender_name TEXT
      )
    ''');

    // Create index on room_id for fast retrieval
    await db.execute('CREATE INDEX idx_messages_room_id ON messages (room_id)');

    await db.execute('''
      CREATE TABLE monk_mode_settings (
        id INTEGER PRIMARY KEY,
        enabled INTEGER NOT NULL,
        deactivate_at TEXT,
        blocked_ids TEXT
      )
    ''');

    await db.insert('monk_mode_settings', {
      'id': 1,
      'enabled': 0,
      'deactivate_at': null,
      'blocked_ids': '[]',
    });
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db
          .execute('ALTER TABLE messages ADD COLUMN reply_to_message_id TEXT');
      await db.execute(
          'ALTER TABLE messages ADD COLUMN reply_to_message_payload TEXT');
      await db.execute(
          'ALTER TABLE messages ADD COLUMN reply_to_message_sender_name TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS monk_mode_settings (
          id INTEGER PRIMARY KEY,
          enabled INTEGER NOT NULL,
          deactivate_at TEXT,
          blocked_ids TEXT
        )
      ''');
      await db.insert(
        'monk_mode_settings',
        {
          'id': 1,
          'enabled': 0,
          'deactivate_at': null,
          'blocked_ids': '[]',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> insertMessage(
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
    final db = await database;
    final timeStr = createdAt ?? DateTime.now().toUtc().toIso8601String();

    await db.insert(
      'messages',
      {
        'id': id,
        'room_id': roomId,
        'sender_id': senderId,
        'payload': payload,
        'status': status,
        'created_at': timeStr,
        'reply_to_message_id': replyToMessageId,
        'reply_to_message_payload': replyToMessagePayload,
        'reply_to_message_sender_name': replyToMessageSenderName,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore, // Upsert idempotency helper
    );
  }

  Future<void> updateMessageStatus(String messageId, String status) async {
    final db = await database;
    await db.update(
      'messages',
      {'status': status},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> deleteMessage(String id) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getMessageById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getMessagesForRoom(String roomId) async {
    final db = await database;
    // Order by created_at ascending for chat history
    return await db.query(
      'messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'created_at ASC',
    );
  }

  Future<Map<String, dynamic>?> getLastMessageForRoom(String roomId) async {
    final db = await database;
    final results = await db.query(
      'messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  /// Returns messages sent by [senderId] that are NOT yet 'read' in SQLite,
  /// so we can reconcile them against Supabase on next app launch.
  Future<List<Map<String, dynamic>>> getUnreadSentMessages(int senderId) async {
    final db = await database;
    return await db.query(
      'messages',
      columns: ['id', 'room_id', 'status'],
      where: "sender_id = ? AND status != 'read'",
      whereArgs: [senderId],
    );
  }

  /// Returns all unread (non-'read') messages in [roomId] from [senderId],
  /// ordered oldest-first. Used to accumulate notification lines.
  Future<List<Map<String, dynamic>>> getUnreadMessagesForRoomBySender(
      String roomId, int senderId) async {
    final db = await database;
    return await db.query(
      'messages',
      columns: ['payload'],
      where: "room_id = ? AND sender_id = ? AND status != 'read'",
      whereArgs: [roomId, senderId],
      orderBy: 'created_at ASC',
    );
  }

  /// Returns all unread (non-'read') messages in [roomId] from any sender,
  /// ordered oldest-first.
  Future<List<Map<String, dynamic>>> getUnreadMessagesForRoom(
      String roomId) async {
    final db = await database;
    return await db.query(
      'messages',
      columns: ['payload', 'sender_id'],
      where: "room_id = ? AND status != 'read'",
      whereArgs: [roomId],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> updateMonkMode({
    required bool enabled,
    String? deactivateAt,
    required List<int> blockedIds,
  }) async {
    final db = await database;
    await db.insert(
      'monk_mode_settings',
      {
        'id': 1,
        'enabled': enabled ? 1 : 0,
        'deactivate_at': deactivateAt,
        'blocked_ids': jsonEncode(blockedIds),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>> getMonkModeSettings() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'monk_mode_settings',
      where: 'id = 1',
    );
    if (results.isNotEmpty) {
      final row = results.first;
      final bool enabled = row['enabled'] == 1;
      final String? deactivateAt = row['deactivate_at'];
      final String blockedIdsStr = row['blocked_ids'] ?? '[]';
      List<int> blockedIds = [];
      try {
        final List<dynamic> decoded = jsonDecode(blockedIdsStr);
        blockedIds = decoded.map((e) => e as int).toList();
      } catch (e) {
        print("Error parsing blocked_ids: $e");
      }
      return {
        'enabled': enabled,
        'deactivate_at': deactivateAt,
        'blocked_ids': blockedIds,
      };
    }
    return {
      'enabled': false,
      'deactivate_at': null,
      'blocked_ids': <int>[],
    };
  }

  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('monk_mode_settings');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
