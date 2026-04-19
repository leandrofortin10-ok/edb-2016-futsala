const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./service-account-key.json')) });
const db = admin.firestore();

async function main() {
  const snap = await db.collection('push_tokens').orderBy('createdAt', 'desc').get();
  console.log(`Total tokens: ${snap.size}`);
  for (const doc of snap.docs) {
    const d = doc.data();
    console.log(`env=${d.env} | createdAt=${d.createdAt?.toDate?.().toISOString()} | id=${doc.id.substring(0,20)}...`);
  }
  process.exit(0);
}
main().catch(e => { console.error(e.message); process.exit(1); });
