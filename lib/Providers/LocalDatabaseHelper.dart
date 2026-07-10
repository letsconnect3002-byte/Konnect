import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDatabaseHelper {
  static final LocalDatabaseHelper instance = LocalDatabaseHelper._init();
  static Database? _database;
  static int? _activeUserId;

  LocalDatabaseHelper._init();

  static int? get activeUserId => _activeUserId;
  static set activeUserId(int? id) {
    _activeUserId = id;
    if (id != null) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('active_user_id', id);
      });
    }
  }

  Future<int?> getActiveUserId() async {
    if (_activeUserId != null) return _activeUserId;
    try {
      final prefs = await SharedPreferences.getInstance();
      _activeUserId = prefs.getInt('active_user_id');
    } catch (e) {
      print("Error loading active user ID from shared preferences: $e");
    }
    return _activeUserId;
  }

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
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        owner_id INTEGER NOT NULL,
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

    // Create index on room_id and owner_id for fast retrieval
    await db.execute('CREATE INDEX idx_messages_room_id ON messages (room_id)');
    await db.execute('CREATE INDEX idx_messages_owner_id ON messages (owner_id)');
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

    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN owner_id INTEGER');
      } catch (e) {
        print("Upgrade: error adding owner_id to messages: $e");
      }
      try {
        await db.execute('CREATE INDEX idx_messages_owner_id ON messages (owner_id)');
      } catch (e) {
        print("Upgrade: error creating owner_id index: $e");
      }
      
      // Migrate existing local messages: set owner_id to the stored active_user_id fallback to 0
      try {
        final prefs = await SharedPreferences.getInstance();
        final activeId = prefs.getInt('active_user_id');
        if (activeId != null) {
          await db.rawUpdate('UPDATE messages SET owner_id = ? WHERE owner_id IS NULL', [activeId]);
        } else {
          await db.rawUpdate('UPDATE messages SET owner_id = 0 WHERE owner_id IS NULL');
        }
      } catch (e) {
        print("Upgrade: error migrating existing message owners: $e");
      }
    }
  }

  /// Status rank used to prevent downgrading (e.g., 'read' → 'delivered').
  static int _statusRank(String status) {
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
    final ownerId = await getActiveUserId() ?? 0;
    
    // Parse and normalize timestamp to standard ISO8601 format to ensure correct SQLite text sorting
    String timeStr;
    if (createdAt != null) {
      try {
        timeStr = DateTime.parse(createdAt).toUtc().toIso8601String();
      } catch (_) {
        timeStr = createdAt;
      }
    } else {
      timeStr = DateTime.now().toUtc().toIso8601String();
    }

    // Check if message already exists locally
    final existing = await db.query(
      'messages',
      columns: ['id', 'status'],
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, ownerId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      // Message already exists — merge missing fields and check status rank
      final currentStatus = existing.first['status'] as String? ?? 'sent';
      final Map<String, dynamic> updates = {};
      
      if (_statusRank(status) > _statusRank(currentStatus)) {
        updates['status'] = status;
      }
      
      // Update metadata fields if they are present in the new insert call but might be null/missing locally
      if (replyToMessageId != null) {
        updates['reply_to_message_id'] = replyToMessageId;
      }
      if (replyToMessagePayload != null) {
        updates['reply_to_message_payload'] = replyToMessagePayload;
      }
      if (replyToMessageSenderName != null) {
        updates['reply_to_message_sender_name'] = replyToMessageSenderName;
      }
      
      // Align the local timestamp with the server-assigned standardized timestamp
      if (createdAt != null) {
        updates['created_at'] = timeStr;
      }

      if (updates.isNotEmpty) {
        await db.update(
          'messages',
          updates,
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, ownerId],
        );
      }
      return;
    }

    // New message — insert it
    await db.insert(
      'messages',
      {
        'id': id,
        'owner_id': ownerId,
        'room_id': roomId,
        'sender_id': senderId,
        'payload': payload,
        'status': status,
        'created_at': timeStr,
        'reply_to_message_id': replyToMessageId,
        'reply_to_message_payload': replyToMessagePayload,
        'reply_to_message_sender_name': replyToMessageSenderName,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> updateMessageStatus(String messageId, String status) async {
    final db = await database;
    final ownerId = await getActiveUserId() ?? 0;
    await db.update(
      'messages',
      {'status': status},
      where: 'id = ? AND owner_id = ?',
      whereArgs: [messageId, ownerId],
    );
  }

  Future<void> deleteMessage(String id) async {
    final db = await database;
    final ownerId = await getActiveUserId() ?? 0;
    await db.delete(
      'messages',
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, ownerId],
    );
  }

  Future<Map<String, dynamic>?> getMessageById(String id) async {
    final db = await database;
    final ownerId = await getActiveUserId() ?? 0;
    final List<Map<String, dynamic>> results = await db.query(
      'messages',
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, ownerId],
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getMessagesForRoom(String roomId) async {
    final db = await database;
    final ownerId = await getActiveUserId() ?? 0;
    // Order by created_at ascending for chat history
    return await db.query(
      'messages',
      where: 'room_id = ? AND owner_id = ?',
      whereArgs: [roomId, ownerId],
      orderBy: 'created_at ASC',
    );
  }

  Future<Map<String, dynamic>?> getLastMessageForRoom(String roomId) async {
    final db = await database;
    final ownerId = await getActiveUserId() ?? 0;
    final results = await db.query(
      'messages',
      where: 'room_id = ? AND owner_id = ?',
      whereArgs: [roomId, ownerId],
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
    final ownerId = await getActiveUserId() ?? 0;
    return await db.query(
      'messages',
      columns: ['id', 'room_id', 'status'],
      where: "sender_id = ? AND status != 'read' AND owner_id = ?",
      whereArgs: [senderId, ownerId],
    );
  }

  /// Returns all unread (non-'read') messages in [roomId] from [senderId],
  /// ordered oldest-first. Used to accumulate notification lines.
  Future<List<Map<String, dynamic>>> getUnreadMessagesForRoomBySender(
      String roomId, int senderId) async {
    final db = await database;
    final ownerId = await getActiveUserId() ?? 0;
    return await db.query(
      'messages',
      columns: ['payload'],
      where: "room_id = ? AND sender_id = ? AND status != 'read' AND owner_id = ?",
      whereArgs: [roomId, senderId, ownerId],
      orderBy: 'created_at ASC',
    );
  }

  /// Returns all unread (non-'read') messages in [roomId] (both sent and received),
  /// ordered oldest-first. Used to build the notification tray history.
  Future<List<Map<String, dynamic>>> getUnreadMessagesForRoom(
      String roomId) async {
    final db = await database;
    final ownerId = await getActiveUserId() ?? 0;
    return await db.query(
      'messages',
      where: "room_id = ? AND status != 'read' AND owner_id = ?",
      whereArgs: [roomId, ownerId],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> clearDatabase() async {
    final ownerId = await getActiveUserId();
    if (ownerId != null) {
      await clearDatabaseForUser(ownerId);
    }
  }

  Future<void> clearDatabaseForUser(int userId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'owner_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
