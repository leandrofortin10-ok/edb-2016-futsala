# EDB — Futsala BA

App para seguir a **Estrella de Boedo** en el Torneo Joma de Futsala BA (Elite B, Promocionales),
con selector de categorías **2016 / 2017 / 2018 / 2019**.

Producción: https://edb-estrella.web.app

## Funcionalidades

- **Próximo partido** — fecha, hora, rival y pronóstico del clima
- **Tabla de posiciones** — clasificación del grupo
- **Fixture** — todos los partidos con resultados y escudos de equipos
- **Plantel** — lista de jugadores
- **Galería por partido** — fotos y videos (carga y borrado restringidos a admin)
- **Notificaciones push** — alertas ante cambios de horario, resultados, posición o plantel

## Torneo actual — CLAUSURA 2026

Los identificadores del torneo están **hardcodeados** y hay que actualizarlos cuando cambia la fase.

| Dato | Valor | Dónde |
|---|---|---|
| `tournamentId` | `566` (Elite B / Promocionales) | `lib/api/api_service.dart`, `.github/scripts/check_and_notify.js` |
| `phaseId` | `1392` (CLAUSURA; la Apertura era `942`) | ídem + `.github/scripts/seed_fake_change.js` |
| `groupId` (tabla) | `null` — todavía no publicada | `lib/api/api_service.dart`, `.github/scripts/check_and_notify.js` |
| `inscriptionId` | `2129` (Estrella de Boedo) | ídem |
| `teamId` | `1464` | ídem |
| `categoryId` | `10` / `11` / `12` / `99` = 2016 / 2017 / 2018 / 2019 | `lib/models/category_config.dart` |

**La tabla de posiciones del Clausura aún no existe.** La organización no publicó el grupo de
clasificación, así que la sección muestra "Sin datos de tabla" y no se emiten notificaciones de
cambio de puesto. Para saber si ya está disponible:

```bash
curl "https://api.weball.me/public-v2/tournament/566/phase/1392/clasification-groups?instanceUUID=2d260df1-7986-49fd-95a2-fcb046e7a4fb"
```

Mientras devuelva `[]` no hay tabla. Cuando devuelva un objeto con `"value":"CATEGORÍAS"`, ese `id`
va en `_groupId` (Dart) y `GROUP_ID` (script de notificaciones).

Para descubrir la fase cuando arranque el próximo torneo:

```bash
curl "https://api.weball.me/public-v2/tournament/566/phase?instanceUUID=2d260df1-7986-49fd-95a2-fcb046e7a4fb"
```

> El flag `active` viene en `false` en todas las fases, así que no sirve para detectar la vigente.

## Stack

- Flutter (Dart) — **target web**; se despliega en Firebase Hosting
- API: [Weball](https://weball.me) — torneos y estadísticas
- API: Open-Meteo — pronóstico del clima
- Firebase Auth (admin), Cloud Firestore (media + estado), FCM (push)
- Cloudinary — almacenamiento de fotos y videos

> `lib/screens/home_screen.dart` y `lib/screens/match_detail_screen.dart` importan `dart:html`
> directamente, así que **el build de Android no compila**. Los archivos `*_mobile.dart`,
> `workmanager` y `flutter_local_notifications` quedaron sin uso.

## Build

```bash
flutter pub get
flutter build web --release
```

Deploy manual (build + cache-busting + Firebase): `scripts/deploy.sh`.
En CI, `.github/workflows/deploy.yml` publica `dev` → canal preview y `master` → producción.

## Notificaciones push

`.github/workflows/push_notifications.yml` corre `check_and_notify.js` cada hora: compara la API
contra el snapshot en Firestore (`app_state/weball_snapshot`) y manda FCM a los tokens registrados.

## Releases

Ver [`releases/RELEASES.md`](releases/RELEASES.md) para el historial de versiones.
