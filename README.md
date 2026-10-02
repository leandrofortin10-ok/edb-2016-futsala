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
- **Previa con IA** — texto del próximo partido generado con Gemini, con botón "Cómo llegar"
- **Asistente con IA** — chat (botón "Preguntar") sobre partidos, resultados, tabla, plantel y reglamento

## Torneo actual — CLAUSURA 2026

Los identificadores del torneo están **hardcodeados** y hay que actualizarlos cuando cambia la fase.

| Dato | Valor | Dónde |
|---|---|---|
| `tournamentId` | `566` (Elite B / Promocionales) | `lib/api/api_service.dart`, `.github/scripts/check_and_notify.js`, `.github/scripts/weball.js` |
| `phaseId` | `1392` (CLAUSURA; la Apertura era `942`) | ídem + `.github/scripts/seed_fake_change.js`; la fase anterior (antecedentes de la previa) va en `PREV_PHASE_ID` de `weball.js` |
| `groupId` (tabla) | `null` — todavía no publicada | `lib/api/api_service.dart`, `.github/scripts/check_and_notify.js`, `.github/scripts/weball.js` |
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

## Previa del próximo partido (IA)

El mismo workflow corre después `generate_previews.js`: cuando el próximo partido de la categoría
2016 pasa a "Programado" (fecha, hora y sede confirmadas), arma los datos (sede, clima si faltan 3
días o menos, tabla, racha, último resultado propio y del rival, antecedentes), le pide la previa a
Gemini vía Genkit y la guarda en Firestore (`ai_previews/{matchId}_{categoryId}`). La app la muestra
debajo de "Próximo partido". Solo se regenera si cambian los datos o el pronóstico; la primera
previa de cada partido manda un push. Para sumar categorías, ver `CATEGORIES` en el script.

- Usa el **tier gratuito** de la Gemini Developer API: el secret `GEMINI_API_KEY` sale de
  [Google AI Studio](https://aistudio.google.com/apikey) con el proyecto `edb-estrella`. Sin el
  secret, el paso no hace nada. En el tier gratuito Google puede usar los datos enviados para
  mejorar sus productos; por eso solo se mandan datos de equipos, nunca nombres de jugadores.
- Modelo: `gemini-3.5-flash` por defecto (variable `GEMINI_MODEL` para cambiarlo).
- Prueba local sin escribir nada: `node generate_previews.js --dry-run` (con `GEMINI_API_KEY`
  definida también imprime el texto generado).

## Asistente (IA)

El botón "Preguntar" abre un chat que responde con Gemini vía **Firebase AI Logic** (Gemini
Developer API, tier gratuito, plan Spark). El contexto son los datos ya cargados en la pantalla
(fixture, resultados, goleadores, tabla, plantel, próximo partido y previa) más el reglamento en
texto (`assets/reglamento/reglamento_2026.txt`, extraído del PDF de la misma carpeta; si cambia el
reglamento hay que regenerarlo con `pdftotext -layout`).

- Requiere **App Check con Fraud Defense** (ex reCAPTCHA Enterprise, invisible, cuota gratuita de
  10.000 verificaciones por mes): la clave está en `lib/services/ai_config.dart` y se administra en
  Google Cloud → Seguridad → Fraud Defense, donde se configuran los dominios habilitados (prod,
  `firebaseapp.com` y el canal dev). En `localhost` se usa un token de debug.
- **No aplicar App Check a Firestore ni a Authentication** sin antes probarlo: solo está pensado
  para AI Logic.
- Modelo y límite de preguntas por conversación: `lib/services/ai_config.dart`.

## Releases

Ver [`releases/RELEASES.md`](releases/RELEASES.md) para el historial de versiones.
