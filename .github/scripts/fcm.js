// Envío de notificaciones push (FCM) a todos los dispositivos registrados.
// Lo usa generate_previews.js (check_and_notify.js tiene su copia). Requiere
// que el script que lo usa haya llamado a admin.initializeApp().

const admin = require('firebase-admin');
const { APP_ORIGIN } = require('./weball');

async function sendNotifications(notifications) {
  const db        = admin.firestore();
  const messaging = admin.messaging();
  const targetEnv = process.env.TARGET_ENV || 'prod';
  const snap   = await db.collection('push_tokens').where('env', '==', targetEnv).get();
  const tokens = snap.docs.map((d) => d.id).filter(Boolean);

  if (tokens.length === 0) {
    console.log('Sin tokens registrados — no se envían notificaciones.');
    return;
  }

  for (const notif of notifications) {
    console.log(`  → ${notif.title}`);

    // FCM acepta máximo 500 tokens por llamada
    for (let i = 0; i < tokens.length; i += 500) {
      const batch = tokens.slice(i, i + 500);
      const res   = await messaging.sendEachForMulticast({
        tokens: batch,
        notification: { title: notif.title, body: notif.body },
        webpush: {
          notification: {
            icon:  `${APP_ORIGIN}/icons/Icon-192.png`,
            badge: `${APP_ORIGIN}/icons/Icon-192.png`,
          },
        },
      });

      // Limpiar tokens expirados o inválidos
      const expired = [];
      res.responses.forEach((r, idx) => {
        if (!r.success) {
          const code = r.error?.code || '';
          if (
            code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token'
          ) {
            expired.push(batch[idx]);
          }
        }
      });
      if (expired.length > 0) {
        const bw = db.batch();
        for (const t of expired) bw.delete(db.collection('push_tokens').doc(t));
        await bw.commit();
        console.log(`    Eliminados ${expired.length} token(s) expirado(s).`);
      }

      console.log(`    ${res.successCount} ok / ${res.failureCount} fallidos (de ${batch.length})`);
    }
  }
}

module.exports = { sendNotifications };
