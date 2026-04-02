// Script que corre en GitHub Actions cada hora.
// 1. Llama a la Weball API (partidos, tabla, plantel)
// 2. Compara con el estado guardado en Firestore
// 3. Si hay cambios → envía FCM a todos los dispositivos suscritos
// 4. Guarda el nuevo estado en Firestore
//
// Requiere variable de entorno: FIREBASE_SERVICE_ACCOUNT (JSON de service account)

const admin = require('firebase-admin');

const MY_INSCRIPTION_ID = 2129;
const BASE              = 'https://api.weball.me/public-v2';
const TOURNAMENT_ID     = 566;
const PHASE_ID          = 942;
const GROUP_ID          = 1440;
const INSTANCE_UUID     = '2d260df1-7986-49fd-95a2-fcb046e7a4fb';
const TEAM_ID           = 1464;
const CATEGORY_ID       = 10;
const APP_ORIGIN        = 'https://edb-estrella.web.app';

// ── Firebase Admin ────────────────────────────────────────────────────────────

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db        = admin.firestore();
const messaging = admin.messaging();

// ── Helpers ───────────────────────────────────────────────────────────────────

async function fetchJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${url}`);
  return res.json();
}

function toInt(v) {
  if (v == null) return null;
  const n = parseInt(v, 10);
  return isNaN(n) ? null : n;
}

function fmtDate(date) {
  try {
    const [, m, d] = date.split('-');
    return `${d}/${m}`;
  } catch { return date; }
}

function parseDateTime(dtStr) {
  if (!dtStr) return { date: null, time: null };
  const normalized = dtStr.includes('T') ? dtStr : dtStr.replace(' ', 'T');
  const dt = new Date(normalized);
  if (isNaN(dt.getTime())) return { date: null, time: null };
  const pad = (n) => String(n).padStart(2, '0');
  return {
    date: `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}-${pad(dt.getDate())}`,
    time: `${pad(dt.getHours())}:${pad(dt.getMinutes())}`,
  };
}

// ── Weball API ────────────────────────────────────────────────────────────────

async function fetchMatches() {
  const data = await fetchJson(
    `${BASE}/tournament/${TOURNAMENT_ID}/phase/${PHASE_ID}/visualizer?instanceUUID=${INSTANCE_UUID}`,
  );
  const matches = [];
  for (const child of (data.children || [])) {
    const label = child.value;
    for (const m of (child.matchesPlanning || [])) {
      const homeCi = m.clubHome?.clubInscription;
      const awayCi = m.clubAway?.clubInscription;
      const homeId = toInt(homeCi?.id);
      const awayId = toInt(awayCi?.id);
      if (homeId !== MY_INSCRIPTION_ID && awayId !== MY_INSCRIPTION_ID) continue;

      // El primer tournamentMatch con datos reales (tm[0] siempre es vacío en esta API)
      let tmReal = null;
      for (const tm of (m.tournamentMatches || [])) {
        if (tm?.matchInfo?.dateTime != null || tm?.scoreHome != null) {
          tmReal = tm;
          break;
        }
      }

      const { date, time } = parseDateTime(m.dateTime || tmReal?.matchInfo?.dateTime);

      matches.push({
        id:                  toInt(m.id),
        localInscriptionId:  homeId,
        visitorInscriptionId: awayId,
        localName:           homeCi?.tableName || m.vacancyHome?.name || null,
        visitorName:         awayCi?.tableName || m.vacancyAway?.name || null,
        scoreLocal:          toInt(m.valueScoreHome)  ?? toInt(tmReal?.scoreHome),
        scoreVisitor:        toInt(m.valueScoreAway)  ?? toInt(tmReal?.scoreAway),
        date,
        time,
        fechaLabel:          label,
        hasResult:           m.valueScoreHome != null || tmReal?.scoreHome != null,
      });
    }
  }
  return matches;
}

async function fetchStandings() {
  const data = await fetchJson(
    `${BASE}/tournament/${TOURNAMENT_ID}/phase/${PHASE_ID}/group/${GROUP_ID}/clasification?instanceUUID=${INSTANCE_UUID}`,
  );
  return (data[0]?.positions || []).map((p) => ({
    inscriptionId: toInt(p.club?.clubInscription?.id),
    pts:           toInt(p.pts) ?? 0,
    dg:            toInt(p.dg)  ?? 0,
  }));
}

async function fetchPlayers() {
  const data = await fetchJson(
    `${BASE}/team/${TEAM_ID}/inscription/${MY_INSCRIPTION_ID}/category/${CATEGORY_ID}/player`,
  );
  return (data || []).map((p) => ({
    fullName: `${p.name || ''} ${p.lastName || ''}`.trim(),
  }));
}

// ── FCM ───────────────────────────────────────────────────────────────────────

async function sendNotifications(notifications) {
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

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log(`[${new Date().toISOString()}] Verificando cambios...`);

  const [matches, standings, players] = await Promise.all([
    fetchMatches(),
    fetchStandings(),
    fetchPlayers(),
  ]);

  const stateRef = db.collection('app_state').doc('weball_snapshot');
  const stateDoc = await stateRef.get();
  const state    = stateDoc.exists ? stateDoc.data() : {};

  const notifications = [];

  // ── Partidos ────────────────────────────────────────────────────────────────
  const savedMatches = state.matches || [];
  for (const m of matches) {
    const prev = savedMatches.find((s) => s.id === m.id);
    if (!prev) continue;

    const rival = m.localInscriptionId === MY_INSCRIPTION_ID
      ? (m.visitorName || '?')
      : (m.localName   || '?');

    const rivalChanged    = prev.rivalName && prev.rivalName !== rival;
    const scoreChanged    = m.hasResult && (!prev.hasResult ||
      prev.scoreLocal !== m.scoreLocal || prev.scoreVisitor !== m.scoreVisitor);
    const dateTimeChanged = (prev.date || m.date) && (prev.date !== m.date || prev.time !== m.time);

    if (rivalChanged) {
      notifications.push({
        title: `📋 Rival actualizado · ${m.fechaLabel || ''}`,
        body:  `Estrella vs ${rival} (antes: ${prev.rivalName})`,
      });
    } else if (scoreChanged) {
      const isHome = m.localInscriptionId === MY_INSCRIPTION_ID;
      const us     = isHome ? m.scoreLocal   : m.scoreVisitor;
      const them   = isHome ? m.scoreVisitor : m.scoreLocal;
      const result = us > them ? '¡Ganamos!' : us < them ? 'Perdimos' : 'Empatamos';
      notifications.push({
        title: `⚽ ${result} ${m.fechaLabel || ''}`,
        body:  `Estrella ${us} – ${them} ${rival}`,
      });
    } else if (dateTimeChanged) {
      const newDT = m.date
        ? `${fmtDate(m.date)}${m.time ? ' ' + m.time : ''}`
        : 'a confirmar';
      notifications.push({
        title: `📅 Horario actualizado · ${m.fechaLabel || ''}`,
        body:  `Estrella vs ${rival} — ${newDT}`,
      });
    }
  }

  // ── Tabla de posiciones ─────────────────────────────────────────────────────
  const sorted = [...standings].sort((a, b) => {
    const c = b.pts - a.pts;
    return c !== 0 ? c : b.dg - a.dg;
  });
  const newPos      = sorted.findIndex((e) => e.inscriptionId === MY_INSCRIPTION_ID) + 1;
  const savedPos    = state.position || 0;
  if (savedPos > 0 && newPos > 0 && newPos !== savedPos) {
    const emoji = newPos < savedPos ? '📈' : '📉';
    notifications.push({
      title: `${emoji} Posición actualizada`,
      body:  `Estrella de Boedo ${newPos < savedPos ? 'subió' : 'bajó'} al puesto ${newPos}`,
    });
  }

  // ── Plantel ─────────────────────────────────────────────────────────────────
  const savedPlayerSet = new Set(state.players || []);
  const newPlayerSet   = new Set(players.map((p) => p.fullName));
  if (savedPlayerSet.size > 0) {
    for (const name of newPlayerSet) {
      if (!savedPlayerSet.has(name)) {
        notifications.push({ title: '👤 Nuevo jugador en el plantel', body: name });
      }
    }
    for (const name of savedPlayerSet) {
      if (!newPlayerSet.has(name)) {
        notifications.push({ title: '👤 Jugador salió del plantel', body: name });
      }
    }
  }

  console.log(`Cambios detectados: ${notifications.length}`);

  if (notifications.length > 0) {
    await sendNotifications(notifications);
  }

  // ── Guardar nuevo estado ─────────────────────────────────────────────────────
  await stateRef.set({
    matches: matches.map((m) => {
      const rival = m.localInscriptionId === MY_INSCRIPTION_ID
        ? (m.visitorName || '?')
        : (m.localName   || '?');
      return {
        id: m.id, hasResult: m.hasResult,
        date: m.date, time: m.time,
        scoreLocal: m.scoreLocal, scoreVisitor: m.scoreVisitor,
        rivalName: rival,
      };
    }),
    position:  newPos || savedPos,
    players:   [...newPlayerSet],
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('Estado guardado en Firestore.');
}

main().catch((err) => {
  console.error('Error fatal:', err);
  process.exit(1);
});
