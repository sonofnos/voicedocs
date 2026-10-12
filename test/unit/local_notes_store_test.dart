import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:voicedocs/models/note.dart';
import 'package:voicedocs/services/local_notes_store.dart';

Note _note(String id, {SyncStatus status = SyncStatus.pending}) {
  return Note(
    id: id,
    rawTranscript: 'raw $id',
    title: 'Title $id',
    summary: 'Summary $id',
    actionItems: ['do $id'],
    createdAt: DateTime(2026, 1, 1),
    syncStatus: status,
  );
}

void main() {
  late LocalNotesStore store;
  int counter = 0;

  setUpAll(() {
    sqfliteFfiInit();
  });

  // Each test gets its own database file name. sqflite's open helper caches
  // open connections by resolved path with singleInstance defaulting to
  // true, so reusing one name (even inMemoryDatabasePath, which without
  // this would still collide on the cache key) across tests silently
  // handed every test the previous test's already-open database instead of
  // a fresh one - see README, "real bugs found and fixed".
  setUp(() {
    counter++;
    store = LocalNotesStore(
      databaseFactory: databaseFactoryFfiNoIsolate,
      databaseName: 'test_local_notes_store_$counter.db',
    );
  });

  tearDown(() async {
    await store.close();
    final dbPath = p.join(
      await databaseFactoryFfiNoIsolate.getDatabasesPath(),
      'test_local_notes_store_$counter.db',
    );
    await databaseFactoryFfiNoIsolate.deleteDatabase(dbPath);
  });

  test('saved notes round trip through local storage', () async {
    await store.save(_note('a'));
    final notes = await store.all();
    expect(notes, hasLength(1));
    expect(notes.first.title, 'Title a');
    expect(notes.first.actionItems, ['do a']);
  });

  test('pendingSync only returns notes marked pending', () async {
    await store.save(_note('a', status: SyncStatus.pending));
    await store.save(_note('b', status: SyncStatus.synced));

    final pending = await store.pendingSync();
    expect(pending.map((n) => n.id), ['a']);
  });

  test('markSynced flips status without losing other fields', () async {
    await store.save(_note('a'));
    await store.markSynced('a');

    final notes = await store.all();
    expect(notes.single.syncStatus, SyncStatus.synced);
    expect(notes.single.title, 'Title a');
  });

  test('markFailed records the attempt count', () async {
    await store.save(_note('a'));
    await store.markFailed('a', 5);

    final notes = await store.all();
    expect(notes.single.syncStatus, SyncStatus.failed);
    expect(notes.single.syncAttempts, 5);
  });

  test('saving a note with the same id overwrites rather than duplicating',
      () async {
    await store.save(_note('a'));
    await store.save(_note('a').copyWith(syncStatus: SyncStatus.synced));

    final notes = await store.all();
    expect(notes, hasLength(1));
    expect(notes.single.syncStatus, SyncStatus.synced);
  });
}
