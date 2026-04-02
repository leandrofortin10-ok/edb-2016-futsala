// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _vapidKey =
    'BCKqChkY1vAgc9-9oBNw0Ag6uaayB744ZAl2wY43uKSU1UTAMnUhFSy19yiewT-vAzoPqWHmJZBzLdkqYRBszGY';

String get notifPermission => html.Notification.permission ?? 'default';

Future<void> initNotifications() async {
  await _registerFcmToken();
}

Future<void> _registerFcmToken() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized) return;

    final token = await messaging.getToken(vapidKey: _vapidKey);
    if (token == null) return;

    // Detectar si estamos en el canal dev (preview channel de Firebase Hosting)
    final hostname = html.window.location.hostname ?? '';
    final env = hostname.contains('--dev-') ? 'dev' : 'prod';

    await FirebaseFirestore.instance.collection('push_tokens').doc(token).set({
      'createdAt': FieldValue.serverTimestamp(),
      'platform': 'web',
      'env': env,
    });
  } catch (_) {
    // Nunca crashear la app por el setup de notificaciones
  }
}

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
