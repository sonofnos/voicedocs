import 'package:flutter_test/flutter_test.dart';
import 'package:voicedocs/services/note_structuring_client.dart';

void main() {
  group('FakeNoteStructuringClient', () {
    final client = FakeNoteStructuringClient();

    test('empty transcript produces an empty note', () async {
      final result = await client.structure('');
      expect(result.title, 'Empty note');
      expect(result.summary, '');
      expect(result.actionItems, isEmpty);
    });

    test('uses the first sentence as the title', () async {
      final result = await client.structure(
        'Inspected the north warehouse roof. Found two leaks near the vent.',
      );
      expect(result.title, 'Inspected the north warehouse roof.');
    });

    test('truncates a long first sentence for the title', () async {
      final longSentence =
          'This is a very long opening sentence that goes on for quite a '
          'while describing many things in great detail without stopping.';
      final result = await client.structure(longSentence);
      expect(result.title.length, lessThanOrEqualTo(60));
      expect(result.title.endsWith('…'), isTrue);
    });

    test('summary keeps the full trimmed transcript', () async {
      const transcript = '  Walked the site with the supervisor.  ';
      final result = await client.structure(transcript);
      expect(result.summary, transcript.trim());
    });

    test('extracts sentences starting with action verbs as action items',
        () async {
      final result = await client.structure(
        'Met with the client. Follow up with procurement next week. '
        'The site looked fine. Call the vendor about delivery dates.',
      );
      expect(result.actionItems, [
        'Follow up with procurement next week',
        'Call the vendor about delivery dates',
      ]);
    });

    test('does not treat a mid-sentence verb as an action item', () async {
      final result = await client.structure(
        'We discussed whether to call the vendor tomorrow.',
      );
      expect(result.actionItems, isEmpty);
    });
  });
}
