// Migrates match_media Firestore docs from planning matchId to 2016 tournamentMatchId
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./service-account-key.json')) });
const db = admin.firestore();

// planning_id -> 2016 tournament_match_id
const ID_MAP = {
  '42128': '156666',
  '42129': '156667',
  '42142': '156680',
  '42144': '156682',
  '42155': '156693',
  '42159': '156697',
  '42168': '156706',
  '42174': '156712',
  '42181': '156719',
  '42189': '156727',
  '42194': '156732',
  '42204': '156742',
  '42207': '156745',
};

async function migrate() {
  const snap = await db.collection('match_media').get();
  console.log(`Found ${snap.size} documents`);

  let migrated = 0, skipped = 0;
  const batch = db.batch();

  for (const doc of snap.docs) {
    const oldId = String(doc.data().matchId);
    const newId = ID_MAP[oldId];
    if (newId) {
      batch.update(doc.ref, { matchId: newId });
      console.log(`  ${doc.id}: ${oldId} → ${newId}`);
      migrated++;
    } else {
      console.log(`  ${doc.id}: matchId=${oldId} (no mapping, skipped)`);
      skipped++;
    }
  }

  if (migrated > 0) {
    await batch.commit();
    console.log(`\n✅ Migrated ${migrated} docs, skipped ${skipped}`);
  } else {
    console.log('\nNothing to migrate.');
  }
  process.exit(0);
}

migrate().catch(e => { console.error(e.message); process.exit(1); });
