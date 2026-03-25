import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_service.dart';
import '../models/models.dart';
import '../utils/birthdays.dart';
import 'notifications.dart';

const _myInscriptionId = 2129;

Future<void> seedTestStateOnce() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('test_state_seeded') ?? false) return;
  await prefs.setInt('last_position', 1);
  await prefs.setString('last_matches', '[]');
  await prefs.setBool('test_state_seeded', true);
}

Future<void> initBackgroundSync() async {
  // No hay background tasks en web — las notificaciones se disparan
  // desde checkForChanges() llamado en foreground al recargar datos.
}

Future<void> resetSavedState() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('last_matches');
  await prefs.remove('last_position');
  await prefs.remove('last_players');
  await prefs.remove('last_birthdays');
  await prefs.remove('last_birthday_check');
  await prefs.remove('test_state_seeded');
}

Future<void> checkForChanges({
  List<Match>? matches,
  List<ClasificationEntry>? standings,
  List<Player>? players,
}) => _checkForChanges(
  prefetchedMatches: matches,
  prefetchedStandings: standings,
  prefetchedPlayers: players,
);

Future<void> _checkForChanges({
  List<Match>? prefetchedMatches,
  List<ClasificationEntry>? prefetchedStandings,
  List<Player>? prefetchedPlayers,
}) async {
  final prefs = await SharedPreferences.getInstance();

  // ── Matches ──────────────────────────────────────────────────────────────
  final matches   = prefetchedMatches   ?? await ApiService.fetchMatches();
  final savedJson = prefs.getString('last_matches') ?? '[]';
  final savedList = (jsonDecode(savedJson) as List)
      .map((e) => _MatchSnap.fromJson(e as Map<String, dynamic>))
      .toList();

  for (final m in matches) {
    final prev = savedList._firstWhereOrNull((s) => s.id == m.id);
    if (prev == null) continue;

    final rival = m.localInscriptionId == _myInscriptionId
        ? (m.visitorName ?? '?')
        : (m.localName ?? '?');

    final rivalChanged    = prev.rivalName != null && prev.rivalName != rival;
    final scoreChanged    = m.hasResult &&
        (!prev.hasResult ||
         prev.scoreLocal != m.scoreLocal ||
         prev.scoreVisitor != m.scoreVisitor);
    final dateTimeChanged = prev.date != m.date || prev.time != m.time;

    if (rivalChanged) {
      await showNotification(
        '📋 Rival actualizado · ${m.fechaLabel ?? ''}',
        'Estrella vs $rival (antes: ${prev.rivalName})',
      );
    } else if (scoreChanged) {
      final isHome = m.localInscriptionId == _myInscriptionId;
      final us   = isHome ? m.scoreLocal! : m.scoreVisitor!;
      final them = isHome ? m.scoreVisitor! : m.scoreLocal!;
      final result = us > them ? '¡Ganamos!' : us < them ? 'Perdimos' : 'Empatamos';
      await showNotification(
        '⚽ $result ${m.fechaLabel ?? ''}',
        'Estrella $us – $them $rival',
      );
    } else if (dateTimeChanged) {
      final newDateTime = m.date != null
          ? '${_fmt(m.date!)}${m.time != null ? ' ${m.time}' : ''}'
          : 'a confirmar';
      await showNotification(
        '📅 Horario actualizado · ${m.fechaLabel ?? ''}',
        'Estrella vs $rival — $newDateTime',
      );
    }
  }

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

  // ── Posiciones ────────────────────────────────────────────────────────────
  final standings = prefetchedStandings ?? await ApiService.fetchClasification();
  final myEntry   = standings._firstWhereOrNull((e) => e.inscriptionId == _myInscriptionId);
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

  // ── Plantel ───────────────────────────────────────────────────────────────
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

  // ── Cumpleaños: cambio de fecha ────────────────────────────────────────────
  final currentBdMap = birthdays.map((k, v) => MapEntry(k, '${v.$1}-${v.$2}'));
  final savedBdJson  = prefs.getString('last_birthdays');
  if (savedBdJson != null) {
    final savedBdMap = (jsonDecode(savedBdJson) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as String));
    for (final entry in currentBdMap.entries) {
      final prev = savedBdMap[entry.key];
      if (prev != null && prev != entry.value) {
        final name = _nameForBirthdayKey(entry.key, players);
        final parts = entry.value.split('-');
        final m = int.tryParse(parts[0]) ?? 0;
        final d = int.tryParse(parts[1]) ?? 0;
        await showNotification(
          '🎂 Cumpleaños actualizado: $name',
          'Nueva fecha: $d de ${bdMonthNames[m]}',
        );
        // Forzar re-chequeo del día exacto por si la nueva fecha es hoy
        await prefs.remove('last_birthday_check');
      }
    }
  }
  await prefs.setString('last_birthdays', jsonEncode(currentBdMap));

  // ── Cumpleaños: día exacto ──────────────────────────────────────────────────
  final today = DateTime.now();
  final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  if (prefs.getString('last_birthday_check') != todayKey) {
    for (final p in players) {
      final bd = birthdayForLastName(p.lastName ?? '');
      if (bd != null && bd.$1 == today.month && bd.$2 == today.day) {
        await showNotification(
          '🎂 Cumpleaños hoy: ${p.fullName}',
          '¡Feliz cumple desde el equipo!',
        );
      }
    }
    await prefs.setString('last_birthday_check', todayKey);
  }
}

String _nameForBirthdayKey(String key, List<Player> players) {
  for (final p in players) {
    final ln = (p.lastName ?? '').toUpperCase().trim();
    if (ln.contains(key) || key.contains(ln)) return p.fullName;
  }
  return key;
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
    id:           j['id'] as int,
    hasResult:    j['hasResult'] as bool,
    date:         j['date'] as String?,
    time:         j['time'] as String?,
    scoreLocal:   j['scoreLocal'] as int?,
    scoreVisitor: j['scoreVisitor'] as int?,
    rivalName:    j['rivalName'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'hasResult': hasResult,
    'date': date, 'time': time,
    'scoreLocal': scoreLocal, 'scoreVisitor': scoreVisitor,
    'rivalName': rivalName,
  };
}

extension _ListExt<T> on List<T> {
  T? _firstWhereOrNull(bool Function(T) test) {
    for (final e in this) { if (test(e)) return e; }
    return null;
  }
}
