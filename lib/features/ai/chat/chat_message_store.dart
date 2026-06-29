import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../../../providers/ai_provider.dart';

const _kTable = 'ai_chat_messages';
const _kMax = 100;

/// SQLite-backed store for RAG chat history, scoped per home.
class ChatMessageStore {
  ChatMessageStore._();
  static final ChatMessageStore instance = ChatMessageStore._();

  Database? _db;
  Database get _d {
    assert(_db != null, 'ChatMessageStore.open() not called');
    return _db!;
  }

  Future<void> open() async {
    if (_db != null) return;
    final path = p.join(await getDatabasesPath(), 'ai_chat_history.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE $_kTable (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          home_id    INTEGER NOT NULL,
          is_user    INTEGER NOT NULL,
          text       TEXT    NOT NULL,
          created_at TEXT    NOT NULL
        )
      '''),
    );
  }

  Future<List<ChatMsg>> load(int homeId) async {
    final rows = await _d.query(
      _kTable,
      where: 'home_id = ?',
      whereArgs: [homeId],
      orderBy: 'id ASC',
      limit: _kMax,
    );
    return rows
        .map((r) => ChatMsg(
              text: r['text'] as String,
              isUser: (r['is_user'] as int) == 1,
            ))
        .toList();
  }

  Future<void> append(int homeId, ChatMsg msg) async {
    await _d.insert(_kTable, {
      'home_id': homeId,
      'is_user': msg.isUser ? 1 : 0,
      'text': msg.text,
      'created_at': DateTime.now().toIso8601String(),
    });
    // Keep only the most recent _kMax messages per home.
    await _d.rawDelete('''
      DELETE FROM $_kTable
      WHERE home_id = ? AND id NOT IN (
        SELECT id FROM $_kTable WHERE home_id = ? ORDER BY id DESC LIMIT $_kMax
      )
    ''', [homeId, homeId]);
  }

  Future<void> clear(int homeId) async {
    await _d.delete(_kTable, where: 'home_id = ?', whereArgs: [homeId]);
  }
}
