import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/note.dart';
import 'local_notes_store.dart';

/// Pushes locally-saved notes to Firestore once connectivity is available.
///
/// Notes are written to [LocalNotesStore] first and always readable from
/// there; this service drains the pending queue in the background. A note
/// that fails to sync is retried with a capped attempt count rather than
/// retried forever, and a note already marked synced is never re-sent, which
/// avoids the duplicate-write race described in the README.
class SyncService {
  final LocalNotesStore localStore;
  final FirebaseFirestore firestore;
  final Connectivity connectivity;
  final String Function() currentUserId;
  final int maxAttempts;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _syncing = false;

  SyncService({
    required this.localStore,
    required this.firestore,
    required this.connectivity,
    required this.currentUserId,
    this.maxAttempts = 5,
  });

  void start() {
    _connectivitySub ??= connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        syncPending();
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Drains the pending queue. Safe to call multiple times concurrently;
  /// a second call while one is already running is a no-op (this was the
  /// "real bug" found during development - see README).
  Future<void> syncPending() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final pending = await localStore.pendingSync();
      for (final note in pending) {
        await _syncOne(note);
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncOne(Note note) async {
    try {
      final docRef = firestore
          .collection('users')
          .doc(currentUserId())
          .collection('notes')
          .doc(note.id);

      // set() with a deterministic doc id makes retries idempotent: syncing
      // the same note twice overwrites the same document rather than
      // creating a duplicate.
      await docRef.set(note.toFirestore(), SetOptions(merge: true));
      await localStore.markSynced(note.id);
    } catch (_) {
      final attempts = note.syncAttempts + 1;
      if (attempts >= maxAttempts) {
        await localStore.markFailed(note.id, attempts);
      } else {
        await localStore.save(note.copyWith(syncAttempts: attempts));
      }
    }
  }
}
