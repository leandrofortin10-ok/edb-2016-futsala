import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/category_config.dart';

class ApiService {
  static const _base         = 'https://api.weball.me/public-v2';
  static const _tournamentId = 566;
  // Fase CLAUSURA 2026 (la Apertura era 942).
  // Fases del torneo 566: GET /tournament/566/phase
  static const _phaseId      = 1392;
  // La organizacion todavia no publico la tabla del Clausura:
  // GET /tournament/566/phase/1392/clasification-groups devuelve [].
  // Cuando la publiquen, poner aca el id del grupo (en la Apertura era 1440).
  static const int? _groupId = null;
  static const _instanceUUID = '2d260df1-7986-49fd-95a2-fcb046e7a4fb';
  static const _inscriptionId = 2129;
  static const _teamId       = 1464;
  static const _ttl          = Duration(minutes: 5);

  static int get myInscriptionId => _inscriptionId;

  // ── Cache helpers ─────────────────────────────────────────────────────────

  static Future<String?> _readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final body = prefs.getString('weball_$key');
      final ts   = prefs.getInt('weball_ts_$key');
      if (body == null || ts == null) return null;
      final age = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - ts);
      return age <= _ttl ? body : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(String key, String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('weball_$key', body);
      await prefs.setInt('weball_ts_$key', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  // ── Parse helpers ────────────────────────────────────────────────────────

  static List<ClasificationEntry> _parseClasification(String body, CategoryConfig cat) {
    if (cat.clasificationIndex == null) return [];
    final decoded = jsonDecode(body);
    if (decoded is! List) return [];
    final List data = decoded;
    final yearStr = '${cat.year}';
    // Match by year string in the 'value' field (e.g. "2016 PROMOCIONALES")
    Map? item;
    for (final e in data) {
      if ((e as Map)['value']?.toString().contains(yearStr) == true) {
        item = e;
        break;
      }
    }
    item ??= (cat.clasificationIndex! < data.length ? data[cat.clasificationIndex!] as Map : null);
    if (item == null) return [];
    final positions = item['positions'] as List? ?? [];
    return positions
        .map((e) => ClasificationEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<Match> _parseMatches(String body, CategoryConfig cat) {
    final vizData  = jsonDecode(body) as Map<String, dynamic>;
    final children = vizData['children'] as List? ?? [];
    final yearStr  = cat.year.toString();
    final allMatches = <Match>[];
    for (final child in children) {
      final c = child as Map<String, dynamic>;
      final label           = c['value'] as String?;
      final matchesPlanning = c['matchesPlanning'] as List? ?? [];
      for (final m in matchesPlanning) {
        final match = Match.fromJson(m as Map<String, dynamic>, fechaLabel: label, categoryId: cat.categoryId);
        if (!match.involvesInscription(_inscriptionId)) continue;
        // If categoryYear is known, filter by it; if null keep the match
        if (match.categoryYear != null && match.categoryYear != yearStr) continue;
        allMatches.add(match);
      }
    }
    return allMatches;
  }

  // Jugadores que ya no forman parte del plantel: se excluyen aunque la API
  // de weball los siga devolviendo. Comparar por nombre completo en mayusculas.
  static const Set<String> excludedPlayers = {
    'CAMILO LUIS LUJAN DEL BAO',
    'GONZALO NICOLAS STAMBULSKY',
  };

  static List<Player> _parsePlayers(String body) {
    final List data = jsonDecode(body);
    return data
        .map((e) => Player.fromJson(e as Map<String, dynamic>))
        .where((p) => !excludedPlayers.contains(p.fullName.toUpperCase()))
        .toList();
  }

  static MatchDetailData _parseMatchDetail(String body) =>
      MatchDetailData.fromJson(jsonDecode(body) as Map<String, dynamic>);

  // ── Public API ────────────────────────────────────────────────────────────

  static Future<List<ClasificationEntry>> fetchClasification([CategoryConfig? cat]) async {
    final groupId = _groupId;
    // Sin grupo de clasificacion no hay tabla que pedir: la UI muestra
    // el estado vacio ("Sin datos de tabla") en vez de un error.
    if (groupId == null) return [];
    final config = cat ?? CategoryConfig.all.first;
    const cacheKey = 'clasification';
    final cached = await _readCache(cacheKey);
    if (cached != null) return _parseClasification(cached, config);

    final uri = Uri.parse(
      '$_base/tournament/$_tournamentId/phase/$_phaseId/group/$groupId/clasification'
      '?instanceUUID=$_instanceUUID',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Error ${res.statusCode}');
    await _writeCache(cacheKey, res.body);
    return _parseClasification(res.body, config);
  }

  static Future<List<Match>> fetchMatches([CategoryConfig? cat]) async {
    final config = cat ?? CategoryConfig.all.first;
    const cacheKey = 'matches';
    final cached = await _readCache(cacheKey);
    if (cached != null) return _parseMatches(cached, config);

    final uri = Uri.parse(
      '$_base/tournament/$_tournamentId/phase/$_phaseId/visualizer'
      '?instanceUUID=$_instanceUUID',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Error ${res.statusCode}');
    await _writeCache(cacheKey, res.body);
    return _parseMatches(res.body, config);
  }

  static Future<MatchDetailData> fetchMatchDetail(int tournamentMatchId) async {
    final key    = 'match_$tournamentMatchId';
    final cached = await _readCache(key);
    if (cached != null) return _parseMatchDetail(cached);

    final uri = Uri.parse('$_base/matches/$tournamentMatchId');
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Error ${res.statusCode}');
    await _writeCache(key, res.body);
    return _parseMatchDetail(res.body);
  }

  static Future<List<Player>> fetchPlayers([CategoryConfig? cat]) async {
    final config = cat ?? CategoryConfig.all.first;
    final cacheKey = 'players_${config.categoryId}';
    final cached = await _readCache(cacheKey);
    if (cached != null) return _parsePlayers(cached);

    final uri = Uri.parse(
      '$_base/team/$_teamId/inscription/$_inscriptionId/category/${config.categoryId}/player',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    await _writeCache(cacheKey, res.body);
    return _parsePlayers(res.body);
  }

  // ── Stale snapshot ────────────────────────────────────────────────────────

  static Future<({
    List<ClasificationEntry> standings,
    List<Match>              matches,
    List<Player>             players,
  })?> loadStaleSnapshot([CategoryConfig? cat]) async {
    final config = cat ?? CategoryConfig.all.first;
    try {
      final prefs = await SharedPreferences.getInstance();
      final mtch = prefs.getString('weball_matches');
      if (mtch == null) return null;
      final cls  = prefs.getString('weball_clasification');
      final plyr = prefs.getString('weball_players_${config.categoryId}');
      return (
        standings: cls != null ? _parseClasification(cls, config) : <ClasificationEntry>[],
        matches:   _parseMatches(mtch, config),
        players:   plyr != null ? _parsePlayers(plyr) : <Player>[],
      );
    } catch (_) {
      return null;
    }
  }
}
