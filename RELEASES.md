# EDB Cat 2016 — Releases

Los APKs se guardan en `releases/` con el nombre `edb-cat2016-vX.Y.Z.apk`.

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
