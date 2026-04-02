// Envía una notificación de prueba a todos los tokens registrados.
// Uso: node test_push.js  (requiere FIREBASE_SERVICE_ACCOUNT, NOTIF_TITLE, NOTIF_BODY)

const admin = require('firebase-admin');

const APP_ORIGIN = 'https://edb-estrella.web.app';

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db        = admin.firestore();
const messaging = admin.messaging();

async function main() {
  const title = process.env.NOTIF_TITLE || '🧪 Test de notificación';
  const body  = process.env.NOTIF_BODY  || 'Push funcionando correctamente.';

  const targetEnv = process.env.TARGET_ENV || 'dev';
  const snap   = await db.collection('push_tokens').where('env', '==', targetEnv).get();
  const tokens = snap.docs.map((d) => d.id).filter(Boolean);

  if (tokens.length === 0) {
    console.log(`No hay tokens "${targetEnv}" registrados. Abrí la app ${targetEnv} y aceptá los permisos primero.`);
    return;
  }

  console.log(`Enviando "${title}" a ${tokens.length} dispositivo(s) [${targetEnv}]...`);

  const res = await messaging.sendEachForMulticast({
    tokens,
    notification: { title, body },
    webpush: {
      notification: {
        icon:  `${APP_ORIGIN}/icons/Icon-192.png`,
        badge: `${APP_ORIGIN}/icons/Icon-192.png`,
      },
    },
  });

  console.log(`Resultado: ${res.successCount} ok / ${res.failureCount} fallidos`);
}

main().catch((err) => {
  console.error('Error:', err);
  process.exit(1);
});
