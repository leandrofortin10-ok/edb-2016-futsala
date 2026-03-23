import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _plugin = FlutterLocalNotificationsPlugin();
int _notifId = 0;

String get notifPermission => 'granted';

Future<void> initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _plugin.initialize(const InitializationSettings(android: android));

  final androidImpl = _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  // Solicitar permiso en Android 13+ (API 33+)
  await androidImpl?.requestNotificationsPermission();

  // Canal de notificaciones
  const channel = AndroidNotificationChannel(
    'estrella_updates',
    'Actualizaciones Estrella de Boedo',
    description: 'Cambios en partidos, posiciones y horarios',
    importance: Importance.high,
  );
  await androidImpl?.createNotificationChannel(channel);
}

Future<void> showNotification(String title, String body) async {
  await _plugin.show(
    _notifId++,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'estrella_updates',
        'Actualizaciones Estrella de Boedo',
        channelDescription: 'Cambios en partidos, posiciones y horarios',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}
