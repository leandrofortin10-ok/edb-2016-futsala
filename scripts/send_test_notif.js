const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./service-account-key.json')) });
const db        = admin.firestore();
const messaging = admin.messaging();

async function main() {
  const snap = await db.collection('push_tokens').orderBy('createdAt', 'desc').limit(1).get();
  if (snap.empty) { console.log('Sin tokens registrados.'); process.exit(0); }

  const doc   = snap.docs[0];
  const token = doc.id;
  const data  = doc.data();
  console.log(`Enviando a: env=${data.env} createdAt=${data.createdAt?.toDate?.()}`);

  const res = await messaging.sendEachForMulticast({
    tokens: [token],
    notification: { title: '🆕 Nuevas categorías disponibles', body: 'Ya podés ver tabla, fixture y plantel de Cat. 2017, 2018 y 2019' },
    webpush: {
      notification: {
        icon:  'https://edb-estrella.web.app/icons/Icon-192.png',
        badge: 'https://edb-estrella.web.app/icons/Icon-192.png',
      },
    },
  });
  console.log(`Resultado: ${res.successCount} ok / ${res.failureCount} fallidos`);
  if (res.responses[0]?.error) console.error('Error:', res.responses[0].error.message);
  process.exit(0);
}

main().catch(e => { console.error(e.message); process.exit(1); });
