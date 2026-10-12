import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicedocs/features/record/record_screen.dart';

void main() {
  testWidgets('starts in the idle stage with a start-recording button',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RecordScreen()),
      ),
    );

    expect(find.text('Stage: idle'), findsOneWidget);
    expect(find.byKey(const Key('startRecordingButton')), findsOneWidget);
    expect(find.byKey(const Key('stopRecordingButton')), findsNothing);
  });
}
