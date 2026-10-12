import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../models/note.dart';
import '../services/auth_service.dart';
import '../services/crash_service.dart';
import '../services/local_notes_store.dart';
import '../services/note_structuring_client.dart';
import '../services/notification_service.dart';
import '../services/performance_service.dart';
import '../services/recording_service.dart';
import '../services/sync_service.dart';
import '../services/transcription_service.dart';

/// Every provider below is overridden in tests with fakes/mocks, which is
/// how the test suite never needs a live Firebase project or a real API key.

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final databaseFactoryProvider = Provider<DatabaseFactory>(
  (ref) => databaseFactory,
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(firebaseAuthProvider)),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

final localNotesStoreProvider = Provider<LocalNotesStore>(
  (ref) => LocalNotesStore(databaseFactory: ref.watch(databaseFactoryProvider)),
);

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final syncServiceProvider = Provider<SyncService>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return SyncService(
    localStore: ref.watch(localNotesStoreProvider),
    firestore: ref.watch(firestoreProvider),
    connectivity: ref.watch(connectivityProvider),
    currentUserId: () => auth.currentUser?.uid ?? 'anonymous',
  );
});

/// No API key configured means the app runs entirely on the deterministic
/// fake structurer - this is the default and what CI/tests exercise.
const _structuringApiKeyEnv = 'VOICEDOCS_STRUCTURING_API_KEY';

final noteStructuringClientProvider = Provider<NoteStructuringClient>((ref) {
  const apiKey = String.fromEnvironment(_structuringApiKeyEnv);
  if (apiKey.isEmpty) {
    return FakeNoteStructuringClient();
  }
  return OpenAiCompatibleStructuringClient(apiKey: apiKey);
});

final recordingServiceProvider = Provider<RecordingService>(
  (ref) => RecordingService(),
);

final transcriptionServiceProvider = Provider<TranscriptionService>(
  (ref) => TranscriptionService(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(FirebaseMessaging.instance),
);

final crashServiceProvider = Provider<CrashService>(
  (ref) => CrashService(FirebaseCrashlytics.instance),
);

final performanceServiceProvider = Provider<PerformanceService>(
  (ref) => PerformanceService(FirebasePerformance.instance),
);

/// Holds the current list of notes, read from local storage and kept in
/// sync with it. The UI only ever talks to this; it never blocks on network.
class NotesController extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    return ref.watch(localNotesStoreProvider).all();
  }

  Future<void> addNote(Note note) async {
    final store = ref.watch(localNotesStoreProvider);
    await store.save(note);
    state = AsyncValue.data(await store.all());
    unawaited(ref.watch(syncServiceProvider).syncPending());
  }

  Future<void> refresh() async {
    state = AsyncValue.data(await ref.watch(localNotesStoreProvider).all());
  }
}

final notesControllerProvider =
    AsyncNotifierProvider<NotesController, List<Note>>(NotesController.new);

void unawaited(Future<void> future) {}
