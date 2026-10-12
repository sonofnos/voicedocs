import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicedocs/features/notes/notes_list_screen.dart';
import 'package:voicedocs/models/note.dart';
import 'package:voicedocs/providers/providers.dart';

/// Returns a fixed list of notes instead of reading LocalNotesStore, so
/// this widget test exercises NotesListScreen's rendering logic without
/// going through sqflite at all. LocalNotesStore itself is covered directly
/// by test/unit/local_notes_store_test.dart.
class _FixedNotesController extends NotesController {
  _FixedNotesController(this._notes);
  final List<Note> _notes;

  @override
  Future<List<Note>> build() async => _notes;
}

void main() {
  testWidgets('shows empty state when there are no notes', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
          notesControllerProvider.overrideWith(
            () => _FixedNotesController(const []),
          ),
        ],
        child: const MaterialApp(home: NotesListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No notes yet. Record one.'), findsOneWidget);
    expect(find.byKey(const Key('recordFab')), findsOneWidget);
  });

  testWidgets('lists a saved note with its sync status icon', (tester) async {
    final note = Note(
      id: 'a',
      rawTranscript: 'raw',
      title: 'Site walk notes',
      summary: 'Walked the north wing with the supervisor.',
      actionItems: const ['Follow up with facilities'],
      createdAt: DateTime(2026, 2, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
          notesControllerProvider.overrideWith(
            () => _FixedNotesController([note]),
          ),
        ],
        child: const MaterialApp(home: NotesListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Site walk notes'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
  });
}
