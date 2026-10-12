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
    apiKey: 'PLACEHOLDER_NO_LIVE_PROJECT',
    appId: '1:000000000000:android:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'voicedocs-placeholder',
    storageBucket: 'voicedocs-placeholder.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER_NO_LIVE_PROJECT',
    appId: '1:000000000000:ios:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'voicedocs-placeholder',
    storageBucket: 'voicedocs-placeholder.appspot.com',
    iosBundleId: 'com.sonofnos.voicedocs',
  );
}
