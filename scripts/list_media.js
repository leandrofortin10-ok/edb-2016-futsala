const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./service-account-key.json')) });
const db = admin.firestore();

async function run() {
  const snap = await db.collection('match_media').get();
  console.log('Total:', snap.size);
  for (const d of snap.docs) {
    const data = d.data();
    console.log('matchId:', data.matchId, '| type:', data.type, '| id:', d.id);
  }
  process.exit(0);
}
run().catch(e => { console.error(e.message); process.exit(1); });
