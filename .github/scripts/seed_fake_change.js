// Fuerza un cambio en el estado guardado en Firestore para testear el flujo completo.
// Toma el estado real actual, modifica el nombre del rival del primer partido,
// y lo guarda. El próximo run de check_and_notify detectará el "cambio" y enviará el push.

const admin = require('firebase-admin');

const MY_INSCRIPTION_ID = 2129;
const BASE              = 'https://api.weball.me/public-v2';
const TOURNAMENT_ID     = 566;
const PHASE_ID          = 942;
const INSTANCE_UUID     = '2d260df1-7986-49fd-95a2-fcb046e7a4fb';

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function fetchMatches() {
  const res  = await fetch(`${BASE}/tournament/${TOURNAMENT_ID}/phase/${PHASE_ID}/visualizer?instanceUUID=${INSTANCE_UUID}`);
  const data = await res.json();
  const matches = [];
  for (const child of (data.children || [])) {
    for (const m of (child.matchesPlanning || [])) {
      const homeCi = m.clubHome?.clubInscription;
      const awayCi = m.clubAway?.clubInscription;
      const homeId = parseInt(homeCi?.id, 10);
      const awayId = parseInt(awayCi?.id, 10);
      if (homeId !== MY_INSCRIPTION_ID && awayId !== MY_INSCRIPTION_ID) continue;

      let tmReal = null;
      for (const tm of (m.tournamentMatches || [])) {
        if (tm?.matchInfo?.dateTime != null || tm?.scoreHome != null) { tmReal = tm; break; }
      }
      const dtStr = m.dateTime || tmReal?.matchInfo?.dateTime;
      let date = null, time = null;
      if (dtStr) {
        const dt = new Date(dtStr.includes('T') ? dtStr : dtStr.replace(' ', 'T'));
        if (!isNaN(dt.getTime())) {
          date = `${dt.getFullYear()}-${String(dt.getMonth()+1).padStart(2,'0')}-${String(dt.getDate()).padStart(2,'0')}`;
          time = `${String(dt.getHours()).padStart(2,'0')}:${String(dt.getMinutes()).padStart(2,'0')}`;
        }
      }
      const rival = homeId === MY_INSCRIPTION_ID
        ? (awayCi?.tableName || m.vacancyAway?.name || '?')
        : (homeCi?.tableName || m.vacancyHome?.name || '?');

      matches.push({
        id: parseInt(m.id, 10),
        hasResult: m.valueScoreHome != null || tmReal?.scoreHome != null,
        date, time,
        scoreLocal:   parseInt(m.valueScoreHome, 10) || parseInt(tmReal?.scoreHome, 10) || null,
        scoreVisitor: parseInt(m.valueScoreAway, 10) || parseInt(tmReal?.scoreAway, 10) || null,
        rivalName: rival,
      });
    }
  }
  return matches;
}

async function main() {
  const stateRef = db.collection('app_state').doc('weball_snapshot');
  const stateDoc = await stateRef.get();

  let matches;
  if (stateDoc.exists) {
    matches = stateDoc.data().matches || [];
  } else {
    console.log('No hay estado guardado, obteniendo desde la API...');
    matches = await fetchMatches();
  }

  if (matches.length === 0) {
    console.log('No hay partidos para modificar.');
    return;
  }

  // Modificar el rival del primer partido
  const original = matches[0].rivalName;
  matches[0] = { ...matches[0], rivalName: 'Rival Fake FC' };

  await stateRef.set({
    ...(stateDoc.exists ? stateDoc.data() : {}),
    matches,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(`✓ Estado modificado: "${original}" → "Rival Fake FC"`);
  console.log('Ahora corré Push Notifications para que detecte el cambio y envíe el push.');
}

main().catch(err => { console.error(err); process.exit(1); });
