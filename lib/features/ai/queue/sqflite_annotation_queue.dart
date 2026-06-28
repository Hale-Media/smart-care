import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'annotation_queue.dart';

const _kTable = 'annotation_queue';

/// Singleton SQLite-backed queue.  Call [open] once at app startup.
class SqfliteAnnotationQueue implements AnnotationQueueStore {
  SqfliteAnnotationQueue._();
  static final SqfliteAnnotationQueue instance = SqfliteAnnotationQueue._();

  Database? _db;
  Database get _d {
    assert(_db != null, 'SqfliteAnnotationQueue.open() not called');
    return _db!;
  }

  @override
  Future<void> open() async {
    if (_db != null) return;
    final path = p.join(await getDatabasesPath(), 'ai_annotation_queue.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE $_kTable (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          entity       TEXT    NOT NULL,
          entity_id    INTEGER NOT NULL,
          summary      TEXT    NOT NULL,
          risk_flags   TEXT    NOT NULL,
          mood         TEXT    NOT NULL,
          follow_up    INTEGER NOT NULL DEFAULT 0,
          model_name   TEXT    NOT NULL,
          model_sha256 TEXT    NOT NULL,
          queued_at    TEXT    NOT NULL,
          retry_count  INTEGER NOT NULL DEFAULT 0
        )
      '''),
    );
  }

  @override
  Future<void> enqueue(QueuedAnnotation item) async {
    await _d.insert(_kTable, item.toSqlite());
  }

  @override
  Future<List<QueuedAnnotation>> pending({int maxRetries = 5}) async {
    final rows = await _d.query(
      _kTable,
      where: 'retry_count < ?',
      whereArgs: [maxRetries],
      orderBy: 'queued_at ASC',
    );
    return rows.map(QueuedAnnotation.fromSqlite).toList();
  }

  @override
  Future<void> markSynced(int id) async {
    await _d.delete(_kTable, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> incrementRetry(int id) async {
    await _d.rawUpdate(
      'UPDATE $_kTable SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  @override
  Future<int> pendingCount() async {
    final result = await _d
        .rawQuery('SELECT COUNT(*) FROM $_kTable WHERE retry_count < 5');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
