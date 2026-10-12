import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/note.dart';

/// Local-first storage for notes. The UI always writes here first and reads
/// from here; Firestore sync happens afterwards in the background via
/// [SyncService]. This is what makes the app usable offline end to end, not
/// just "cache while online".
class LocalNotesStore {
  final DatabaseFactory databaseFactory;
  final String databaseName;
  Database? _db;

  LocalNotesStore({
    required this.databaseFactory,
    this.databaseName = 'voicedocs.db',
  });

  Future<Database> _database() async {
    if (_db != null) return _db!;
    // inMemoryDatabasePath (":memory:") is a sentinel sqflite recognizes
    // directly - joining it onto getDatabasesPath() turns it into a literal
    // file named ":memory:" on disk instead of an actual in-memory database.
    // That file then persists and accumulates rows across test runs, which
    // is exactly what caused the pumpAndSettle hangs described in the
    // README ("real bugs found and fixed"): the open() call ended up
    // waiting on a stale, locked file instead of a fresh in-memory db.
    final path = databaseName == inMemoryDatabasePath
        ? databaseName
        : p.join(await databaseFactory.getDatabasesPath(), databaseName);
    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE notes (
              id TEXT PRIMARY KEY,
              raw_transcript TEXT NOT NULL,
              title TEXT NOT NULL,
              summary TEXT NOT NULL,
              action_items TEXT NOT NULL,
              created_at TEXT NOT NULL,
              sync_status TEXT NOT NULL,
              sync_attempts INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      ),
    );
    return _db!;
  }

  Future<void> save(Note note) async {
    final db = await _database();
    await db.insert(
      'notes',
      note.toLocalRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Note>> all() async {
    final db = await _database();
    final rows = await db.query('notes', orderBy: 'created_at DESC');
    return rows.map(Note.fromLocalRow).toList();
  }

  Future<List<Note>> pendingSync() async {
    final db = await _database();
    final rows = await db.query(
      'notes',
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.name],
      orderBy: 'created_at ASC',
    );
    return rows.map(Note.fromLocalRow).toList();
  }

  Future<void> markSynced(String id) async {
    final db = await _database();
    await db.update(
      'notes',
      {'sync_status': SyncStatus.synced.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(String id, int attempts) async {
    final db = await _database();
    await db.update(
      'notes',
      {'sync_status': SyncStatus.failed.name, 'sync_attempts': attempts},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
