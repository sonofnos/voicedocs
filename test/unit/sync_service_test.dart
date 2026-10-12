import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:voicedocs/models/note.dart';
import 'package:voicedocs/services/local_notes_store.dart';
import 'package:voicedocs/services/sync_service.dart';

class _MockConnectivity extends Mock implements Connectivity {}

Note _note(String id, {int syncAttempts = 0}) {
  return Note(
    id: id,
    rawTranscript: 'raw $id',
    title: 'Title $id',
    summary: 'Summary $id',
    actionItems: const [],
    createdAt: DateTime(2026, 1, 1),
    syncAttempts: syncAttempts,
  );
}

void main() {
  late LocalNotesStore localStore;
  late FakeFirebaseFirestore firestore;
  late _MockConnectivity connectivity;
  late SyncService sync;
  int counter = 0;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    counter++;
    localStore = LocalNotesStore(
      databaseFactory: databaseFactoryFfiNoIsolate,
      databaseName: 'test_sync_service_$counter.db',
    );
    firestore = FakeFirebaseFirestore();
    connectivity = _MockConnectivity();
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => const Stream.empty());

    sync = SyncService(
      localStore: localStore,
      firestore: firestore,
      connectivity: connectivity,
      currentUserId: () => 'user-1',
    );
  });

  tearDown(() async {
    sync.dispose();
    await localStore.close();
    final dbPath = p.join(
      await databaseFactoryFfiNoIsolate.getDatabasesPath(),
      'test_sync_service_$counter.db',
    );
    await databaseFactoryFfiNoIsolate.deleteDatabase(dbPath);
  });

  test('syncing a pending note writes it to Firestore and marks it synced',
      () async {
    await localStore.save(_note('a'));

    await sync.syncPending();

    final notes = await localStore.all();
    expect(notes.single.syncStatus, SyncStatus.synced);

    final doc = await firestore
        .collection('users')
        .doc('user-1')
        .collection('notes')
        .doc('a')
        .get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['title'], 'Title a');
  });

  test('already-synced notes are not resent', () async {
    await localStore.save(_note('a'));
    await sync.syncPending();

    // Delete the remote copy directly to prove a second sync pass does not
    // recreate it - pendingSync() should return nothing for an already
    // synced note.
    await firestore
        .collection('users')
        .doc('user-1')
        .collection('notes')
        .doc('a')
        .delete();

    await sync.syncPending();

    final doc = await firestore
        .collection('users')
        .doc('user-1')
        .collection('notes')
        .doc('a')
        .get();
    expect(doc.exists, isFalse);
  });

  test('concurrent syncPending calls do not double-process the queue',
      () async {
    await localStore.save(_note('a'));
    await localStore.save(_note('b'));

    // This reproduces the race found during development: calling
    // syncPending() twice back to back, before the first finishes,
    // used to let both calls read the same pending list and both try to
    // write the same notes. The _syncing guard in SyncService fixes it.
    final first = sync.syncPending();
    final second = sync.syncPending();
    await Future.wait([first, second]);

    final notes = await localStore.all();
    expect(notes.every((n) => n.syncStatus == SyncStatus.synced), isTrue);
  });

  test('a note that keeps failing is marked failed after maxAttempts', () async {
    final failingFirestoreNote = _note('a', syncAttempts: 4);
    await localStore.save(failingFirestoreNote);

    final breakingSync = SyncService(
      localStore: localStore,
      firestore: _ThrowingFirestore(),
      connectivity: connectivity,
      currentUserId: () => 'user-1',
      maxAttempts: 5,
    );

    await breakingSync.syncPending();

    final notes = await localStore.all();
    expect(notes.single.syncStatus, SyncStatus.failed);
    expect(notes.single.syncAttempts, 5);
  });
}

/// A minimal Firestore stand-in whose collection() call throws, used to
/// exercise the retry/failure path without needing a real network error.
class _ThrowingFirestore extends Fake implements FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    throw Exception('simulated network failure');
  }
}
