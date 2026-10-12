# voicedocs

Record a voice note, get it transcribed on-device, and have it structured
into a title, summary, and action items. Built as a focused portfolio repo
closing a specific gap: production Flutter apps that use the full breadth
of Firebase (auth, Firestore, FCM, Crashlytics, Performance Monitoring)
plus on-device speech recognition and offline-first sync, in one codebase.

The domain is kept generic (field notes, meeting notes) on purpose. This is
not a clinical app and makes no claim to healthcare experience; it mirrors
the shape of a voice-to-structured-documentation product without the
domain claim.

## Flow

1. Record a voice memo with the device microphone (`record` package).
2. Transcribe it with on-device native speech recognition (`speech_to_text`,
   which wraps iOS `SFSpeechRecognizer` and Android `SpeechRecognizer`).
3. Structure the transcript into title/summary/action items via a pluggable
   `NoteStructuringClient`.
4. Save locally first, sync to Firestore in the background.

## Why on-device speech recognition, not a cloud API

`speech_to_text` is a real, production-grade choice, not a shortcut:
no API key to manage or leak, no per-minute billing, and the recognition
step itself keeps working offline since it runs natively on the device.
Cloud transcription APIs (Whisper, Google Speech-to-Text) are a legitimate
alternative for higher accuracy or multi-language support at scale, but
for a single-user notes app, native recognition is the more honest and more
production-appropriate call, and it is what actually ships in this repo
rather than a mocked client standing in for one.

## Note structuring: real key or deterministic fake

`NoteStructuringClient` is an interface with two implementations:

- `OpenAiCompatibleStructuringClient` calls a real hosted OpenAI-compatible
  chat completions endpoint, used when `VOICEDOCS_STRUCTURING_API_KEY` is
  passed via `--dart-define`.
- `FakeNoteStructuringClient` is deterministic: title from the first
  sentence, summary is the trimmed transcript, action items are sentences
  starting with a verb like "call", "follow up", "schedule". No network
  call, no key.

The app and the entire test suite run on the fake by default. This is the
same DI-with-honest-fakes pattern used in agent-platform, chatstack-api,
and support-copilot: nothing in this repo requires a live key to build,
test, or demo.

## Firebase: all five required services, wired for real

- **Authentication** - `firebase_auth`, email/password.
- **Database integration** - `cloud_firestore`, notes stored per user at
  `users/{uid}/notes/{noteId}`.
- **Push notifications** - `firebase_messaging`, client registration and
  foreground message handling. The actual push send (e.g. a Cloud Function
  firing on a Firestore write when background sync completes) is a
  server-side piece outside this client repo; what's real here is the
  client-side token registration and receive path.
- **Crash reporting** - `firebase_crashlytics`, hooked into both
  `FlutterError.onError` and `PlatformDispatcher.instance.onError` so
  framework and async errors both report. `CrashService.triggerTestCrash()`
  exists only for manual verification (see below) and is never called from
  normal app flow.
- **Performance monitoring** - `firebase_performance`, with a custom trace
  (`transcribe_and_structure`) bracketing the record-to-save pipeline.

### Firebase project status

**No live Firebase project is wired into this build.** This machine's
Firebase CLI (`firebase --version` 14.24.2) has no authorized account
(`firebase login:list` returns none), and this build environment's
permission policy blocks the credential-materialization step
(`gcloud auth print-access-token`, `firebase projects:create`) that would
be needed to create or authenticate a project non-interactively, even
though `gcloud` itself is already logged in as
`christian1emeka@gmail.com`. Creating the project requires one interactive
browser sign-in that this environment cannot complete.

What this means concretely: `lib/firebase_options.dart` contains clearly
labeled placeholder values (`PLACEHOLDER_NO_LIVE_PROJECT`), not real
credentials. The app detects this, fails `Firebase.initializeApp` cleanly,
and falls back to a "no Firebase project configured" screen instead of
crashing on launch - see `main.dart`. All five service integrations above
are real code against the real Firebase SDKs; they have not been exercised
against a live backend.

To wire a real project:

```bash
firebase login
firebase projects:create sonofnos-voicedocs
dart pub global activate flutterfire_cli
flutterfire configure --project=sonofnos-voicedocs
```

That regenerates `lib/firebase_options.dart` with real values and adds
`google-services.json` / `GoogleService-Info.plist`.

### Manually verifying Crashlytics and Performance

Neither can be proven from CI - Crashlytics needs a real app restart after
a real crash to flush the report, and Performance Monitoring traces land in
the console with a delay. Once a real project is wired:

1. Call `CrashService.triggerTestCrash()` from a debug button, run on a
   real device/simulator, relaunch the app once (Crashlytics sends on next
   launch), and confirm the event in the Firebase console.
2. Record and process one note, then check the Performance console for a
   `transcribe_and_structure` trace.

## Offline-first and background sync

The UI never blocks on network. `LocalNotesStore` (sqflite) is the only
thing the UI reads from and writes to directly; `SyncService` drains the
pending queue to Firestore in the background, triggered on save and on
connectivity regained (`connectivity_plus`).

Sync uses `set()` with the note's own id as the Firestore document id, so
retrying a sync is idempotent - resending the same note overwrites the same
document instead of creating a duplicate. A note is retried up to 5 times
before being marked `failed` rather than retried forever.

## Testing

`flutter analyze` is clean. `flutter test` covers:

- `FakeNoteStructuringClient`: title extraction, truncation, action-item
  detection, empty-transcript handling.
- `LocalNotesStore`: save/read round trip, pending-only filtering,
  sync-status transitions, upsert-not-duplicate on repeated save. Uses
  `sqflite_common_ffi` (`databaseFactoryFfiNoIsolate`) with a dedicated
  database file per test rather than a real device database, which is the
  standard way to unit test sqflite outside a Flutter app process.
- `SyncService`: successful sync, idempotent resync, the concurrent-call
  race described below, and the max-retry failure path. Uses
  `fake_cloud_firestore` instead of a real Firestore project - it
  implements the same `cloud_firestore` API surface in memory, so the test
  exercises real query/write code paths without needing network access or
  a live project.
- Widget tests for the login screen (`firebase_auth_mocks`'
  `MockFirebaseAuth`, so `AuthService` runs against a real
  `FirebaseAuth`-shaped API without a live project), the notes list screen
  (with `NotesController` overridden to a fixed in-memory list so the test
  covers rendering, not storage - `LocalNotesStore` has its own direct
  tests above), and the record screen's initial state.

No test requires a live Firebase project, a live API key, or network
access.

## Real bug found and fixed

`SyncService.syncPending()` had no guard against concurrent calls. The app
calls it both right after saving a note and from the connectivity-restored
listener; if both fired close together, each call read the same
pending-notes list before the other had updated any statuses, and both
would try to sync the same notes. Firestore's `set()` made this safe from
duplicate documents, but it did double work and raced to update local sync
status. Fixed with a simple `_syncing` boolean so a second call while one
is in flight is a no-op; `test/unit/sync_service_test.dart` has a test that
fires two overlapping `syncPending()` calls and asserts every note ends up
`synced` exactly once.

`LocalNotesStore` had a path bug that only showed up once there were
multiple widget tests in one file. `inMemoryDatabasePath` (sqflite's
`":memory:"` sentinel) was being joined onto `getDatabasesPath()`, which
turned it into a literal file named `:memory:` on disk instead of an actual
in-memory database. Worse, sqflite's open helper caches connections by
resolved path with `singleInstance` defaulting to true, so a second test
reusing that same path got handed the first test's already-open,
already-populated database instead of a fresh one. The symptom was a
`pumpAndSettle` timeout: the notes list stayed on its loading spinner
because the underlying query was stuck behind a stale file lock. Fixed in
two places: `LocalNotesStore._database()` now uses the sentinel directly
instead of joining it with a path, and every test that opens a real
database gives itself a unique file name and deletes it in `tearDown`.
`test/widget/notes_list_screen_test.dart` sidesteps the whole class of
problem by overriding the notes controller with fixed data instead of
exercising sqflite through a widget test at all - `LocalNotesStore` has its
own direct, narrower tests for that.

## Verified, with one caveat

`flutter analyze` and `flutter test` both pass (see CI). What was not
manually verified in this environment: an interactive simulator run, since
there is no live Firebase project to authenticate against yet and this
build environment has no GUI simulator window for tapping through the
record -> transcribe -> structure -> save -> sync flow by hand. The
business logic behind every step - structuring, local storage, and sync -
is exercised directly by the unit tests above, which is a different and
narrower claim than a full on-device run; this README does not claim the
latter.

## CI

`.github/workflows/ci.yml` runs `flutter analyze` and `flutter test` on
every push and PR to `main`.
