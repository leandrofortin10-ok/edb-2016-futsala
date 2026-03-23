# EDB Cat 2016 — Releases

Los APKs se guardan en `releases/` con el nombre `edb-cat2016-vX.Y.Z.apk`.

---

## v1.4.0 — 2026-03-19

**APK:** `releases/edb-cat2016-v1.4.0.apk`

### Cambios
- Fix de notificaciones duplicadas: cuando cambiaban múltiples cosas de un mismo partido en el mismo ciclo (rival + fecha, resultado + fecha, etc.) se enviaban varias notificaciones. Ahora se aplica prioridad: rival > resultado > fecha/hora, una sola notificación por partido por ciclo

---

## v1.3.0 — 2026-03-19

**APK:** `releases/edb-cat2016-v1.3.0.apk`

### Cambios
- Fix: las fechas y horarios de los partidos ahora se leen correctamente desde la nueva estructura de la API (el campo `dateTime` se movió a `tournamentMatches[].matchInfo.dateTime`)
- Fix: parseo defensivo de todos los campos numéricos — si la API devuelve un String donde se espera un int, la app lo convierte sin crashear

---

## v1.2.0 — 2026-03-17

**APK:** `releases/edb-cat2016-v1.2.0.apk`

### Cambios
- Fixture rediseñado: escudos de ambos equipos en cada fila
- Nombres de equipos en fuente más chica (evita cortes) con soporte de 2 líneas
- Fixture muestra fecha y hora del partido (antes solo fecha)

---

## v1.1.0 — 2026-03-17

**APK:** `releases/edb-cat2016-v1.1.0.apk`

### Cambios
- Icono de la app cambiado al logo del club (descargado desde la API de Weball)
- Nombre de la app cambiado a "EDB Cat 2016"
- Fix de notificaciones: cuando múltiples campos cambiaban al mismo tiempo solo llegaba 1 notificación. Ahora cada notificación tiene un ID único (contador incremental) y todas llegan correctamente
- Fix de clima: la info del tiempo se muestra correctamente para el próximo partido
- Fix de jugadores: agregar y quitar jugadores del plantel funciona correctamente

---

## v1.0.0 — 2026-03-11

**APK:** `releases/edb-cat2016-v1.0.0.apk`

### Cambios
- Primera versión funcional
- Próximo partido con clima
- Tabla de posiciones
- Fixture completo
- Plantel
- Notificaciones de cambios (partidos, posiciones, jugadores)
- Sincronización en background (cada 15 minutos)
- Pantalla de debug para simular cambios
