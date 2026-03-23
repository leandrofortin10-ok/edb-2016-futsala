// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String get notifPermission => html.Notification.permission ?? 'default';

Future<void> initNotifications() async {}

Future<void> showNotification(String title, String body) async {
  try {
    final permission = html.Notification.permission;
    if (permission == 'denied') return;

    if (permission != 'granted') {
      final result = await html.Notification.requestPermission();
      if (result != 'granted') return;
    }

    // Chrome Android requiere ServiceWorker — intentamos primero, fallback a Notification directa
    try {
      final sw = await html.window.navigator.serviceWorker?.ready;
      if (sw != null) {
        await sw.showNotification(title, {'body': body});
        return;
      }
    } catch (_) {}

    // Fallback: Notification directa (funciona en desktop)
    html.Notification(title, body: body);
  } catch (_) {
    // Nunca crashear la app por una notificación fallida
  }
}
