import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/login_screen.dart';
import 'features/notes/notes_list_screen.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // No live Firebase project is wired in yet (see README). Initialization
  // is wrapped so the app still runs - with Firebase-backed features
  // disabled - rather than crashing on launch for anyone pulling the repo
  // before running `flutterfire configure`.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }

  runApp(ProviderScope(child: VoiceDocsApp(firebaseReady: firebaseReady)));
}

class VoiceDocsApp extends ConsumerWidget {
  final bool firebaseReady;
  const VoiceDocsApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'voicedocs',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: firebaseReady ? const _AuthGate() : const _NoFirebaseNotice(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) =>
          user == null ? const LoginScreen() : const NotesListScreen(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

class _NoFirebaseNotice extends StatelessWidget {
  const _NoFirebaseNotice();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No Firebase project is configured for this build.\n'
            'Run flutterfire configure, then relaunch.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
