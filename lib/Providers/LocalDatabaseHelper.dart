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
      version: 1,
      onCreate: _createDB,
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
        created_at TEXT NOT NULL
      )
    ''');

    // Create index on room_id for fast retrieval
    await db.execute('CREATE INDEX idx_messages_room_id ON messages (room_id)');
  }

  Future<void> insertMessage(
    String id,
    String roomId,
    int senderId,
    String payload, {
    String status = 'sent',
    String? createdAt,
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

  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('messages');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
