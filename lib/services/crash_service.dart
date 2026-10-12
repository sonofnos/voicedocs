import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Wires Firebase Crashlytics into Flutter's own error hooks so uncaught
/// framework errors and async errors are both reported.
///
/// You cannot "prove" a crash report landed from an automated test - it is
/// Crashlytics' own backend that receives it, on a delay, after a real app
/// restart. Manual verification steps are in the README.
class CrashService {
  final FirebaseCrashlytics _crashlytics;

  CrashService(this._crashlytics);

  void install() {
    FlutterError.onError = _crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  Future<void> recordNonFatal(Object error, StackTrace stack) {
    return _crashlytics.recordError(error, stack, fatal: false);
  }

  /// Triggers a real native crash, used only to manually verify Crashlytics
  /// is wired correctly. Not called anywhere in normal app flow.
  void triggerTestCrash() {
    _crashlytics.crash();
  }
}
