// Script que corre en GitHub Actions cada hora, después de check_and_notify.js.
// Genera con Gemini (vía Genkit) la "previa" del próximo partido de la
// categoría 2016 y la guarda en Firestore (ai_previews/{matchId}_{categoryId}).
// La app la muestra debajo de "Próximo partido".
//
// - Solo se genera cuando el partido está "Programado": recién ahí la API
//   trae fecha, hora y sede confirmadas.
// - Se regenera si cambian los datos (rival, fecha, sede, tabla, resultados)
//   o si el pronóstico del clima cambia de forma apreciable.
// - La primera previa de cada partido manda un push.
//
// Requiere: FIREBASE_SERVICE_ACCOUNT y GEMINI_API_KEY (sin la key no hace nada).
// Prueba local sin Firestore ni push: node generate_previews.js --dry-run
// (con GEMINI_API_KEY definida también genera el texto y lo imprime).
// FORCE_PREVIEW=true regenera y vuelve a avisar aunque la previa no haya
// cambiado (lo usa el workflow manual test_previews.yml).

const crypto = require('crypto');
const admin = require('firebase-admin');
const { genkit } = require('genkit');
const { googleAI } = require('@genkit-ai/google-genai');
const {
  MY_INSCRIPTION_ID, BASE, TOURNAMENT_ID, PHASE_ID, PREV_PHASE_ID, GROUP_ID,
  INSTANCE_UUID, CATEGORY_ID, fetchJson, toInt, parseDateTime,
} = require('./weball');
const { sendNotifications } = require('./fcm');

const MODEL   = process.env.GEMINI_MODEL || 'gemini-3.5-flash';
const DRY_RUN = process.argv.includes('--dry-run');
const FORCE   = process.env.FORCE_PREVIEW === 'true';
const TZ      = 'America/Argentina/Buenos_Aires';

// Solo la categoría principal. Para sumar otras: { year: 2017, id: 11 },
// { year: 2018, id: 12 }, { year: 2019, id: 99 } (ver category_config.dart).
const CATEGORIES = [
  { year: 2016, id: CATEGORY_ID },
];

// El pronóstico se incluye solo cuando faltan pocos días: antes es poco confiable.
const WEATHER_MAX_DAYS = 3;
// Mismas coordenadas que lib/services/weather_service.dart (centro de CABA).
const WEATHER_LAT = -34.6037;
const WEATHER_LON = -58.3816;

const WEEKDAYS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
const MONTHS   = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

const SYSTEM_PROMPT = `Sos el redactor de la app del club Estrella de Boedo, que sigue a sus equipos
infantiles de futsal en el torneo de Futsala BA. Escribís la previa del próximo partido para las
familias de los chicos.

Datos obligatorios (incluí todos los que vengan en el JSON, en este orden aproximado):
1. Número de fecha y torneo (por ejemplo, "Fecha 9 del Clausura").
2. Día, fecha y hora del partido.
3. Si Estrella juega de local o de visitante, y contra quién.
4. Sede con su dirección completa.
5. Pronóstico del clima (estado, temperatura y probabilidad de lluvia), con un consejo práctico
   breve (abrigo, agua, protector solar o paraguas).
6. Último partido de Estrella: rival y resultado.
7. Racha actual de Estrella y partidos sin perder.
8. Posición y puntos de Estrella en la tabla.
9. Cómo llega el rival: posición, puntos y su último resultado.
10. Antecedentes contra ese rival en la fase anterior, nombrando la fase (por ejemplo, "en el Apertura").

Reglas:
- Español rioplatense, tono cálido, positivo y respetuoso. Entre 110 y 160 palabras, en 3 párrafos
  cortos. Texto plano: sin títulos, listas, markdown ni emojis.
- Usá solo los datos del JSON. No inventes nada ni agregues suposiciones o interpretaciones sobre
  lo que hará el rival. Si un dato no viene (null o lista vacía), omitilo sin mencionarlo.
- Si un resultado no trae marcador, decí solo quién ganó: nunca remarques goleadas ni desmerezcas
  al rival.
- Escribí los números de temperatura y puntos con cifras.
- Los nombres de equipos y del torneo vienen en mayúsculas: escribilos con mayúscula inicial,
  respetando siglas y tildes (por ejemplo, Vélez Sarsfield, UAI Urquiza, Clausura).
- Usá frases simples y directas: "el partido se juega en...", no "nos encontramos en...".
- No menciones jugadores ni pronostiques el resultado.
- Terminá con "¡Vamos Estrella!".`;

// ── Datos ─────────────────────────────────────────────────────────────────────

function todayInArgentina() {
  // en-CA formatea como YYYY-MM-DD
  return new Intl.DateTimeFormat('en-CA', { timeZone: TZ }).format(new Date());
}

function daysBetween(fromDate, toDate) {
  return Math.round((Date.parse(toDate) - Date.parse(fromDate)) / 86400000);
}

function longDate(date) {
  const [y, m, d] = date.split('-').map(Number);
  const weekday = WEEKDAYS[new Date(Date.UTC(y, m - 1, d)).getUTCDay()];
  return `${weekday} ${d} de ${MONTHS[m - 1]}`;
}

// Partidos de una categoría, en el orden del fixture (el mismo que usa la app).
function parseMatches(visualizer, categoryId) {
  const matches = [];
  for (const child of (visualizer.children || [])) {
    for (const m of (child.matchesPlanning || [])) {
      const tm = (m.tournamentMatches || [])
        .find((t) => toInt(t?.category?.categoryInstance?.id) === categoryId);
      if (!tm) continue;
      const homeCi = m.clubHome?.clubInscription;
      const awayCi = m.clubAway?.clubInscription;
      const { date, time } = parseDateTime(m.dateTime || tm.matchInfo?.dateTime);
      const scoreHome = toInt(tm.scoreHome);
      const scoreAway = toInt(tm.scoreAway);
      matches.push({
        id:         toInt(m.id),
        tmId:       toInt(tm.id),
        fechaLabel: child.value,
        date,
        time,
        homeId:     toInt(homeCi?.id),
        awayId:     toInt(awayCi?.id),
        homeName:   (homeCi?.tableName || m.vacancyHome?.name || '').trim() || null,
        awayName:   (awayCi?.tableName || m.vacancyAway?.name || '').trim() || null,
        scoreHome,
        scoreAway,
        hasResult:  scoreHome != null && scoreAway != null,
      });
    }
  }
  return matches;
}

const involves = (m, teamId) => m.homeId === teamId || m.awayId === teamId;

// Próximo partido: igual que _nextMatch() en home_screen.dart, pero exigiendo
// fecha confirmada (sin fecha no hay previa).
function findNextMatch(ours, today) {
  return ours
    .filter((m) => !m.hasResult && m.date && m.date >= today)
    .sort((a, b) => `${a.date} ${a.time}`.localeCompare(`${b.date} ${b.time}`))[0] || null;
}

// Resultado de un partido jugado visto desde teamId.
function resultFor(m, teamId) {
  const isHome = m.homeId === teamId;
  const gf = isHome ? m.scoreHome : m.scoreAway;
  const gc = isHome ? m.scoreAway : m.scoreHome;
  return {
    fecha:     m.fechaLabel,
    rival:     isHome ? m.awayName : m.homeName,
    condicion: isHome ? 'local' : 'visitante',
    resultado: gf > gc ? 'ganó' : gf < gc ? 'perdió' : 'empató',
    // Marcador solo en partidos parejos: en una goleada alcanza con decir quién ganó.
    marcador:  Math.abs(gf - gc) <= 3 ? `${gf}-${gc}` : null,
  };
}

// Racha actual desde el último partido jugado, como _buildStreak() de la app.
function streak(results) {
  const latest = [...results].reverse();
  if (latest.length === 0) return null;
  const first = latest[0].resultado;
  const same  = latest.findIndex((r) => r.resultado !== first);
  const unbeaten = latest.findIndex((r) => r.resultado === 'perdió');
  const label = { ganó: 'victorias', empató: 'empates', perdió: 'derrotas' }[first];
  return {
    racha:             `${same === -1 ? latest.length : same} ${label} seguidas`,
    partidosSinPerder: unbeaten === -1 ? latest.length : unbeaten,
  };
}

// Nombres de las fases del torneo por id (ej. 1392 → "CLAUSURA").
async function fetchPhaseNames() {
  try {
    const phases = await fetchJson(
      `${BASE}/tournament/${TOURNAMENT_ID}/phase?instanceUUID=${INSTANCE_UUID}`,
    );
    return new Map((phases || []).map((p) => [toInt(p.id), p.name || p.value || null]));
  } catch { return new Map(); }
}

async function fetchStandingsTables() {
  if (GROUP_ID == null) return [];
  try {
    return await fetchJson(
      `${BASE}/tournament/${TOURNAMENT_ID}/phase/${PHASE_ID}/group/${GROUP_ID}/clasification?instanceUUID=${INSTANCE_UUID}`,
    ) || [];
  } catch { return []; }
}

// Posiciones de la categoría ordenadas por puntos, diferencia y goles a favor.
// Vacío si la tabla no está publicada o todavía nadie jugó.
function standingsFor(tables, year) {
  const table = tables.find((t) => (t.value || '').startsWith(String(year)));
  const rows = (table?.positions || []).map((p) => ({
    inscriptionId: toInt(p.club?.clubInscription?.id),
    pts: toInt(p.pts) ?? 0, pj: toInt(p.pj) ?? 0, pg: toInt(p.pg) ?? 0,
    pe: toInt(p.pe) ?? 0, pp: toInt(p.pp) ?? 0, dg: toInt(p.dg) ?? 0, gf: toInt(p.gf) ?? 0,
  }));
  if (!rows.some((r) => r.pj > 0)) return [];
  return rows.sort((a, b) => b.pts - a.pts || b.dg - a.dg || b.gf - a.gf);
}

function positionOf(standings, inscriptionId) {
  const idx = standings.findIndex((r) => r.inscriptionId === inscriptionId);
  if (idx < 0) return null;
  const r = standings[idx];
  return {
    puesto: idx + 1, de: standings.length, puntos: r.pts,
    jugados: r.pj, ganados: r.pg, empatados: r.pe, perdidos: r.pp,
  };
}

function weatherDescription(code) {
  if (code === 0)  return 'despejado';
  if (code === 1)  return 'mayormente despejado';
  if (code === 2)  return 'parcialmente nublado';
  if (code === 3)  return 'nublado';
  if (code <= 48)  return 'niebla';
  if (code <= 55)  return 'llovizna';
  if (code <= 65)  return 'lluvia';
  if (code <= 67)  return 'lluvia helada';
  if (code <= 77)  return 'nieve';
  if (code <= 82)  return 'chaparrones';
  return 'tormenta';
}

async function fetchWeather(date, time) {
  try {
    const data = await fetchJson(
      'https://api.open-meteo.com/v1/forecast'
      + `?latitude=${WEATHER_LAT}&longitude=${WEATHER_LON}`
      + '&hourly=temperature_2m,weathercode,precipitation_probability'
      + `&timezone=${encodeURIComponent(TZ)}&start_date=${date}&end_date=${date}`,
    );
    const hour = (time || '12:00').slice(0, 2);
    const idx  = data.hourly.time.indexOf(`${date}T${hour}:00`);
    if (idx < 0) return null;
    return {
      estado:             weatherDescription(data.hourly.weathercode[idx]),
      temperatura:        Math.round(data.hourly.temperature_2m[idx]),
      probabilidadLluvia: data.hourly.precipitation_probability[idx] ?? null,
    };
  } catch { return null; }
}

const rainLevel = (p) => (p == null ? null : p < 30 ? 0 : p < 60 ? 1 : 2);

// Un cambio de pronóstico justifica regenerar solo si es apreciable.
function weatherChanged(prev, cur) {
  if (!prev || !cur) return prev !== cur;
  return prev.estado !== cur.estado
    || Math.abs(prev.temperatura - cur.temperatura) >= 3
    || rainLevel(prev.probabilidadLluvia) !== rainLevel(cur.probabilidadLluvia);
}

const sha256 = (obj) => crypto.createHash('sha256').update(JSON.stringify(obj)).digest('hex');

// Arma los datos de la previa del próximo partido de una categoría, o null si
// todavía no corresponde generarla.
async function buildFacts(category, ctx) {
  const all  = parseMatches(ctx.visualizer, category.id);
  const ours = all.filter((m) => involves(m, MY_INSCRIPTION_ID));
  const next = findNextMatch(ours, ctx.today);
  if (!next) return { skip: 'sin próximo partido con fecha confirmada' };

  const detail = await fetchJson(`${BASE}/matches/${next.tmId}`);
  if (detail.status?.name !== 'Programado') {
    return { skip: `${next.fechaLabel} en estado "${detail.status?.name}"` };
  }

  const isHome = next.homeId === MY_INSCRIPTION_ID;
  const rivalId = isHome ? next.awayId : next.homeId;
  const venue = detail.venue;
  const standings = standingsFor(ctx.tables, category.year);

  const ourResults   = ours.filter((m) => m.hasResult).map((m) => resultFor(m, MY_INSCRIPTION_ID));
  const rivalResults = all.filter((m) => m.hasResult && involves(m, rivalId))
    .map((m) => resultFor(m, rivalId));
  const headToHead = parseMatches(ctx.prevVisualizer, category.id)
    .filter((m) => m.hasResult && involves(m, MY_INSCRIPTION_ID) && involves(m, rivalId))
    .map((m) => resultFor(m, MY_INSCRIPTION_ID));

  const facts = {
    categoria: `${category.year} Promocionales`,
    torneo:    ctx.phaseNames.get(PHASE_ID) || null,
    fecha:     next.fechaLabel,
    dia:       longDate(next.date),
    hora:      next.time,
    estrellaJuegaDe: isHome ? 'local' : 'visitante',
    rival:     isHome ? next.awayName : next.homeName,
    sede:      venue ? { nombre: venue.name?.trim(), direccion: venue.address?.trim() } : null,
    estrella: {
      posicion:     positionOf(standings, MY_INSCRIPTION_ID),
      ...streak(ourResults),
      ultimoPartido: ourResults.at(-1) || null,
    },
    rivalComoLlega: {
      posicion:     positionOf(standings, rivalId),
      ultimoPartido: rivalResults.at(-1) || null,
    },
    antecedentes: {
      fase:     ctx.phaseNames.get(PREV_PHASE_ID) || null,
      partidos: headToHead,
    },
  };

  const weather = daysBetween(ctx.today, next.date) <= WEATHER_MAX_DAYS
    ? await fetchWeather(next.date, next.time)
    : null;

  return {
    next,
    facts: { ...facts, clima: weather },
    // El clima se compara aparte (weatherChanged) para no regenerar por cada
    // décima de grado; en el hash solo cuenta si se incluyó o no.
    inputHash: sha256({ ...facts, climaIncluido: weather != null }),
    weather,
    mapsUrl: venue?.googleMapsUrl || null,
  };
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log(`[${new Date().toISOString()}] Generando previas (modelo ${MODEL})...`);

  const hasKey = Boolean(process.env.GEMINI_API_KEY);
  if (!hasKey && !DRY_RUN) {
    console.log('GEMINI_API_KEY no configurada — se omiten las previas.');
    return;
  }

  let db = null;
  if (!DRY_RUN) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    db = admin.firestore();
  }
  const ai = hasKey ? genkit({ plugins: [googleAI()] }) : null;

  const [visualizer, prevVisualizer, tables, phaseNames] = await Promise.all([
    fetchJson(`${BASE}/tournament/${TOURNAMENT_ID}/phase/${PHASE_ID}/visualizer?instanceUUID=${INSTANCE_UUID}`),
    fetchJson(`${BASE}/tournament/${TOURNAMENT_ID}/phase/${PREV_PHASE_ID}/visualizer?instanceUUID=${INSTANCE_UUID}`),
    fetchStandingsTables(),
    fetchPhaseNames(),
  ]);
  const ctx = { visualizer, prevVisualizer, tables, phaseNames, today: todayInArgentina() };

  const notifications = [];

  for (const category of CATEGORIES) {
    const tag = `[${category.year}]`;
    try {
      const built = await buildFacts(category, ctx);
      if (built.skip) {
        console.log(`${tag} Sin previa: ${built.skip}.`);
        continue;
      }
      const { next, facts, inputHash, weather, mapsUrl } = built;
      const docRef = db?.collection('ai_previews').doc(`${next.id}_${category.id}`);
      const prev = docRef ? await docRef.get() : null;
      const prevData = prev?.exists ? prev.data() : null;

      if (!FORCE && prevData && prevData.inputHash === inputHash
          && !weatherChanged(prevData.weather, weather)) {
        console.log(`${tag} ${next.fechaLabel}: previa vigente, sin cambios.`);
        continue;
      }

      if (DRY_RUN) console.log(`${tag} Datos:\n${JSON.stringify(facts, null, 2)}`);
      if (!ai) continue;

      const { text } = await ai.generate({
        model:  googleAI.model(MODEL),
        system: SYSTEM_PROMPT,
        prompt: `Datos del partido (JSON):\n${JSON.stringify(facts, null, 2)}`,
        config: { temperature: 0.7 },
      });
      const preview = (text || '').trim();
      if (!preview) throw new Error('el modelo devolvió un texto vacío');

      if (DRY_RUN) {
        console.log(`${tag} Previa generada:\n${preview}\n`);
        continue;
      }

      await docRef.set({
        matchId:     next.id,
        categoryId:  category.id,
        text:        preview,
        mapsUrl,
        weather,
        inputHash,
        model:       MODEL,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`${tag} ${next.fechaLabel}: previa ${prevData ? 'actualizada' : 'creada'}.`);

      // Push solo la primera vez; las actualizaciones no avisan.
      if (!prevData || FORCE) {
        const day = facts.dia.charAt(0).toUpperCase() + facts.dia.slice(1);
        notifications.push({
          title: `✨ Previa · ${next.fechaLabel}`,
          body:  `${day} ${facts.hora} vs ${facts.rival} (${facts.estrellaJuegaDe}). Entrá a la app para leerla.`,
        });
      }
    } catch (err) {
      // Un error en una categoría (API caída, cuota de Gemini) no frena a las demás.
      console.error(`${tag} Error generando la previa:`, err.message || err);
    }
  }

  if (notifications.length > 0) await sendNotifications(notifications);
}

main().catch((err) => {
  console.error('Error fatal:', err);
  process.exit(1);
});
