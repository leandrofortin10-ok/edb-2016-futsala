import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../api/api_service.dart';
import '../models/models.dart';
import 'notifications.dart';

const _taskName = 'estrellaSync';
const _taskTag  = 'estrella_background_sync';
const _myInscriptionId = 2129;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await initNotifications();
      await _checkForChanges();
    } catch (_) {}
    return Future.value(true);
  });
}

Future<void> seedTestStateOnce() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('test_state_seeded') ?? false) return;
  await prefs.setInt('last_position', 1);
  await prefs.setString('last_matches', '[]');
  await prefs.setBool('test_state_seeded', true);
}

Future<void> initBackgroundSync() async {
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    _taskName,
    _taskTag,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}

/// Llamado desde el foreground con datos ya cargados para evitar doble llamada a la API.
Future<void> checkForChanges({
  List<Match>? matches,
  List<ClasificationEntry>? standings,
  List<Player>? players,
}) => _checkForChanges(
  prefetchedMatches: matches,
  prefetchedStandings: standings,
  prefetchedPlayers: players,
);

Future<void> resetSavedState() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('last_matches');
  await prefs.remove('last_position');
  await prefs.remove('last_players');
  await prefs.remove('test_state_seeded');
}

Future<void> _checkForChanges({
  List<Match>? prefetchedMatches,
  List<ClasificationEntry>? prefetchedStandings,
  List<Player>? prefetchedPlayers,
}) async {
  final prefs = await SharedPreferences.getInstance();

  // ── Matches (fecha, hora, resultado, rival) ────────────────────────────────
  final matches   = prefetchedMatches   ?? await ApiService.fetchMatches();
  final savedJson = prefs.getString('last_matches') ?? '[]';
  final savedList = (jsonDecode(savedJson) as List)
      .map((e) => _MatchSnap.fromJson(e as Map<String, dynamic>))
      .toList();

  for (final m in matches) {
    final prev = savedList.firstWhereOrNull((s) => s.id == m.id);
    if (prev == null) continue; // primera vez, sin notificar

    final rival = m.localInscriptionId == _myInscriptionId
        ? (m.visitorName ?? '?')
        : (m.localName ?? '?');

    // Nombre del rival cambió
    if (prev.rivalName != null && prev.rivalName != rival) {
      await showNotification(
        '📋 Rival actualizado · ${m.fechaLabel ?? ''}',
        'Estrella vs $rival (antes: ${prev.rivalName})',
      );
    }

    // Fecha u hora cambió (cualquier dirección)
    if (prev.date != m.date || prev.time != m.time) {
      final newDateTime = m.date != null
          ? '${_fmt(m.date!)}${m.time != null ? ' ${m.time}' : ''}'
          : 'a confirmar';
      await showNotification(
        '📅 Horario actualizado · ${m.fechaLabel ?? ''}',
        'Estrella vs $rival — $newDateTime',
      );
    }

    // Resultado apareció o cambió
    if (m.hasResult &&
        (!prev.hasResult ||
         prev.scoreLocal != m.scoreLocal ||
         prev.scoreVisitor != m.scoreVisitor)) {
      final isHome = m.localInscriptionId == _myInscriptionId;
      final us   = isHome ? m.scoreLocal! : m.scoreVisitor!;
      final them = isHome ? m.scoreVisitor! : m.scoreLocal!;
      final result = us > them ? '¡Ganamos!' : us < them ? 'Perdimos' : 'Empatamos';
      await showNotification(
        '⚽ $result ${m.fechaLabel ?? ''}',
        'Estrella $us – $them $rival',
      );
    }
  }

  // Guardar estado actual de matches
  await prefs.setString('last_matches',
    jsonEncode(matches.map((m) {
      final rival = m.localInscriptionId == _myInscriptionId
          ? (m.visitorName ?? '?')
          : (m.localName ?? '?');
      return _MatchSnap(
        id: m.id, hasResult: m.hasResult,
        date: m.date, time: m.time,
        scoreLocal: m.scoreLocal, scoreVisitor: m.scoreVisitor,
        rivalName: rival,
      ).toJson();
    }).toList()),
  );

  // ── Posiciones ─────────────────────────────────────────────────────────────
  final standings = prefetchedStandings ?? await ApiService.fetchClasification();
  final myEntry   = standings.firstWhereOrNull((e) => e.inscriptionId == _myInscriptionId);
  if (myEntry != null) {
    final sorted = [...standings]..sort((a, b) {
      final c = b.pts.compareTo(a.pts);
      return c != 0 ? c : b.dg.compareTo(a.dg);
    });
    final newPos = sorted.indexWhere((e) => e.inscriptionId == _myInscriptionId) + 1;
    final oldPos = prefs.getInt('last_position') ?? 0;

    if (oldPos > 0 && newPos != oldPos) {
      final emoji = newPos < oldPos ? '📈' : '📉';
      await showNotification(
        '$emoji Posición actualizada',
        'Estrella de Boedo ${newPos < oldPos ? 'subió' : 'bajó'} al puesto $newPos',
      );
    }
    await prefs.setInt('last_position', newPos);
  }

  // ── Plantel (altas, bajas y modificaciones) ───────────────────────────────
  final players    = prefetchedPlayers ?? await ApiService.fetchPlayers();
  final newNames   = players.map((p) => p.fullName).toSet();
  final savedPlayersJson = prefs.getString('last_players');

  if (savedPlayersJson != null) {
    final oldNames = (jsonDecode(savedPlayersJson) as List).cast<String>().toSet();

    for (final name in newNames.difference(oldNames)) {
      await showNotification('👤 Nuevo jugador en el plantel', name);
    }
    for (final name in oldNames.difference(newNames)) {
      await showNotification('👤 Jugador salió del plantel', name);
    }
  }

  await prefs.setString('last_players', jsonEncode(newNames.toList()));
}

String _fmt(String date) {
  try {
    final p = date.split('-');
    return '${p[2]}/${p[1]}';
  } catch (_) { return date; }
}

class _MatchSnap {
  final int id;
  final bool hasResult;
  final String? date;
  final String? time;
  final int? scoreLocal;
  final int? scoreVisitor;
  final String? rivalName;
  _MatchSnap({required this.id, required this.hasResult,
      this.date, this.time, this.scoreLocal, this.scoreVisitor, this.rivalName});
  factory _MatchSnap.fromJson(Map<String, dynamic> j) => _MatchSnap(
    id:          j['id'] as int,
    hasResult:   j['hasResult'] as bool,
    date:        j['date'] as String?,
    time:        j['time'] as String?,
    scoreLocal:  j['scoreLocal'] as int?,
    scoreVisitor:j['scoreVisitor'] as int?,
    rivalName:   j['rivalName'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id, 'hasResult': hasResult,
    'date': date, 'time': time,
    'scoreLocal': scoreLocal, 'scoreVisitor': scoreVisitor,
    'rivalName': rivalName,
  };
}

extension _ListExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) { if (test(e)) return e; }
    return null;
  }
}
