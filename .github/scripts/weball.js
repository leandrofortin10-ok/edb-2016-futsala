// Constantes del torneo y helpers para los scripts de GitHub Actions
// (por ahora los usa generate_previews.js; check_and_notify.js tiene su copia).
//
// Los ids están hardcodeados: hay que actualizarlos cuando cambia la fase.

const MY_INSCRIPTION_ID = 2129;
const BASE              = 'https://api.weball.me/public-v2';
const TOURNAMENT_ID     = 566;
// Fase CLAUSURA 2026 (la Apertura era 942). Ver: GET /tournament/566/phase
const PHASE_ID          = 1392;
// Fase anterior: se usa para los antecedentes contra cada rival en la previa.
const PREV_PHASE_ID     = 942;
// Grupo de la tabla del Clausura (en la Apertura era 1440). No aparece en
// ningún endpoint: se encontró probando ids en /phase/1392/group/{id}/clasification.
// null = tabla no publicada (no se notifican cambios de posición).
const GROUP_ID          = 2145;
const INSTANCE_UUID     = '2d260df1-7986-49fd-95a2-fcb046e7a4fb';
const TEAM_ID           = 1464;
const CATEGORY_ID       = 10;
const APP_ORIGIN        = 'https://edb-estrella.web.app';

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

module.exports = {
  MY_INSCRIPTION_ID, BASE, TOURNAMENT_ID, PHASE_ID, PREV_PHASE_ID, GROUP_ID,
  INSTANCE_UUID, TEAM_ID, CATEGORY_ID, APP_ORIGIN,
  fetchJson, toInt, fmtDate, parseDateTime,
};
