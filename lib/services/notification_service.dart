import 'package:firebase_messaging/firebase_messaging.dart';

/// Wraps Firebase Cloud Messaging. Requests permission, registers the
/// device token, and exposes a stream of foreground messages so the UI can
/// surface a "note ready" notification when background structuring/sync
/// completes.
///
/// Sending the actual push (e.g. from a Cloud Function that fires on a
/// Firestore write) is a server-side concern outside this client repo; what
/// is real here is the client-side registration and receive path.
class NotificationService {
  final FirebaseMessaging _messaging;

  NotificationService(this._messaging);

  Future<String?> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    return _messaging.getToken();
  }

  Stream<RemoteMessage> onMessage() => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> onMessageOpenedApp() =>
      FirebaseMessaging.onMessageOpenedApp;
}
