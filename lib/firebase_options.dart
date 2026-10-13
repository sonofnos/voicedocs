// File generated normally by the `flutterfire configure` command.
//
// PLACEHOLDER: no live Firebase project is wired into this build. See
// README.md "Firebase project status" for why, and for the exact command to
// run (`flutterfire configure`) once a project exists. These values will
// not authenticate against a real Firebase backend.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for '
          '$defaultTargetPlatform - run flutterfire configure.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDqwzmDmzvBsbthxkSliWCRpzLMyOcn7OQ',
    appId: '1:825557007634:android:ea77d4f30b74cbe6d087cb',
    messagingSenderId: '825557007634',
    projectId: 'sonofnos-voicedocs',
    storageBucket: 'sonofnos-voicedocs.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAsaEyNudE_0Ioaod7WRtXyOPPjTJgBbNI',
    appId: '1:825557007634:ios:f6d8e4d4b8b6b4c5d087cb',
    messagingSenderId: '825557007634',
    projectId: 'sonofnos-voicedocs',
    storageBucket: 'sonofnos-voicedocs.firebasestorage.app',
    iosBundleId: 'com.sonofnos.voicedocs',
  );

}