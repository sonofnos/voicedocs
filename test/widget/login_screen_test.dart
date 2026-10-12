import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicedocs/features/auth/login_screen.dart';
import 'package:voicedocs/providers/providers.dart';

void main() {
  testWidgets('shows sign in form by default', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Sign in'), findsWidgets);
    expect(find.byKey(const Key('emailField')), findsOneWidget);
    expect(find.byKey(const Key('passwordField')), findsOneWidget);
  });

  testWidgets('toggling switches to the register form', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.text('No account? Register'));
    await tester.pump();

    expect(find.text('Create an account'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Register'), findsOneWidget);
  });

  testWidgets('entering credentials and submitting signs the user in',
      (tester) async {
    final auth = MockFirebaseAuth();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('emailField')),
      'someone@example.com',
    );
    await tester.enterText(find.byKey(const Key('passwordField')), 'secret123');
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pumpAndSettle();

    // firebase_auth_mocks signs in as its configured mock user rather than
    // echoing back the credentials passed to signInWithEmailAndPassword, so
    // the meaningful assertion is that a user session now exists, not what
    // the mock's built-in email happens to be.
    expect(auth.currentUser, isNotNull);
  });
}
