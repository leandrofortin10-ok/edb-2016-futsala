const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./service-account-key.json')) });
const db        = admin.firestore();
const messaging = admin.messaging();

const TITLE = '🆕 Nuevas categorías disponibles';
const BODY   = 'Ya podés ver tabla, fixture y plantel de Cat. 2017, 2018 y 2019';

async function main() {
  const snap = await db.collection('push_tokens').get();

  // Deduplicar tokens
  const unique = [...new Set(snap.docs.map(d => d.id))];
  console.log(`Tokens únicos: ${unique.length} (de ${snap.size} registros)`);

  // FCM acepta hasta 500 por llamada
  const CHUNK = 500;
  let ok = 0, fail = 0;
  for (let i = 0; i < unique.length; i += CHUNK) {
    const chunk = unique.slice(i, i + CHUNK);
    const res = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification: { title: TITLE, body: BODY },
      webpush: {
        notification: {
          icon:  'https://edb-estrella.web.app/icons/Icon-192.png',
          badge: 'https://edb-estrella.web.app/icons/Icon-192.png',
        },
      },
    });
    ok   += res.successCount;
    fail += res.failureCount;
  }

  console.log(`✅ Enviadas: ${ok} ok / ${fail} fallidas`);
  process.exit(0);
}

main().catch(e => { console.error(e.message); process.exit(1); });
