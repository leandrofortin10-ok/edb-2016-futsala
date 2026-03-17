# EDB Cat 2016 — Futsala BA

App mobile para seguir a **Estrella de Boedo** en el Torneo Joma de Futsala BA, categoría 2016.

## Funcionalidades

- **Próximo partido** — fecha, hora, rival y pronóstico del clima
- **Tabla de posiciones** — clasificación en tiempo real del grupo
- **Fixture** — todos los partidos con resultados y escudos de equipos
- **Plantel** — lista de jugadores
- **Notificaciones** — alertas automáticas ante cambios de horario, resultados, posición o jugadores
- **Sincronización en background** — actualización cada 15 minutos aunque la app esté cerrada

## Releases

Ver [`releases/RELEASES.md`](releases/RELEASES.md) para el historial de versiones y descargas.

## Stack

- Flutter (Dart)
- API: [Weball](https://weball.me) — torneos y estadísticas
- API: Open-Meteo — pronóstico del clima
- `flutter_local_notifications` — notificaciones
- `workmanager` — background sync
- `shared_preferences` — persistencia de estado

## Build

```bash
flutter pub get
flutter build apk --release
```
