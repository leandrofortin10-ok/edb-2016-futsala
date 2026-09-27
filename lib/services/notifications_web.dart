// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// Scope donde el SDK de FCM (index.html) registra firebase-messaging-sw.js
const _fcmSwScope = '/firebase-cloud-messaging-push-scope';

String get notifPermission => html.Notification.permission ?? 'default';

Future<void> initNotifications() async {}

Future<void> showNotification(String title, String body) async {
  try {
    final permission = html.Notification.permission;
    if (permission == 'denied') return;

    if (permission != 'granted') {
      final result = await html.Notification.requestPermission()
          .timeout(const Duration(seconds: 5), onTimeout: () => 'default');
      if (result != 'granted') return;
    }

    // Chrome Android requiere ServiceWorker — intentamos primero, fallback a Notification directa.
    // NO usar serviceWorker.ready: cuelga indefinidamente si ningún SW controla el scope
    // raíz (index.html desregistra el de Flutter y el de FCM vive en otro scope).
    try {
      final sw = await html.window.navigator.serviceWorker
          ?.getRegistration(_fcmSwScope)
          .timeout(const Duration(seconds: 3));
      if (sw != null) {
        await sw.showNotification(title, {'body': body, 'icon': '/icons/Icon-192.png'});
        return;
      }
    } catch (_) {}

    // Fallback: Notification directa (funciona en desktop)
    html.Notification(title, body: body);
  } catch (_) {
    // Nunca crashear la app por una notificación fallida
  }
}
