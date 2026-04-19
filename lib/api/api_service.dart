import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static const _base         = 'https://api.weball.me/public-v2';
  static const _tournamentId = 566;
  static const _phaseId      = 942;
  static const _groupId      = 1440;
  static const _instanceUUID = '2d260df1-7986-49fd-95a2-fcb046e7a4fb';
  static const _inscriptionId = 2129;
  static const _teamId       = 1464;
  static const _categoryId   = 10;
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

  // ── Parse helpers (reused by cache and network paths) ────────────────────

  static List<ClasificationEntry> _parseClasification(String body) {
    final List data = jsonDecode(body);
    final positions = (data.first as Map)['positions'] as List? ?? [];
    return positions
        .map((e) => ClasificationEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<Match> _parseMatches(String body) {
    final vizData  = jsonDecode(body) as Map<String, dynamic>;
    final children = vizData['children'] as List? ?? [];
    final allMatches = <Match>[];
    for (final child in children) {
      final c = child as Map<String, dynamic>;
      final label          = c['value'] as String?;
      final matchesPlanning = c['matchesPlanning'] as List? ?? [];
      for (final m in matchesPlanning) {
        final match = Match.fromJson(m as Map<String, dynamic>, fechaLabel: label);
        if (match.involvesInscription(_inscriptionId)) allMatches.add(match);
      }
    }
    return allMatches;
  }

  static List<Player> _parsePlayers(String body) {
    final List data = jsonDecode(body);
    return data.map((e) => Player.fromJson(e as Map<String, dynamic>)).toList();
  }

  static MatchDetailData _parseMatchDetail(String body) =>
      MatchDetailData.fromJson(jsonDecode(body) as Map<String, dynamic>);

  // ── Public API ────────────────────────────────────────────────────────────

  static Future<List<ClasificationEntry>> fetchClasification() async {
    final cached = await _readCache('clasification');
    if (cached != null) return _parseClasification(cached);

    final uri = Uri.parse(
      '$_base/tournament/$_tournamentId/phase/$_phaseId/group/$_groupId/clasification'
      '?instanceUUID=$_instanceUUID',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Error ${res.statusCode}');
    await _writeCache('clasification', res.body);
    return _parseClasification(res.body);
  }

  static Future<List<Match>> fetchMatches() async {
    final cached = await _readCache('matches');
    if (cached != null) return _parseMatches(cached);

    final uri = Uri.parse(
      '$_base/tournament/$_tournamentId/phase/$_phaseId/visualizer'
      '?instanceUUID=$_instanceUUID',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Error ${res.statusCode}');
    await _writeCache('matches', res.body);
    return _parseMatches(res.body);
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

  static Future<List<Player>> fetchPlayers() async {
    final cached = await _readCache('players');
    if (cached != null) return _parsePlayers(cached);

    final uri = Uri.parse(
      '$_base/team/$_teamId/inscription/$_inscriptionId/category/$_categoryId/player',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    await _writeCache('players', res.body);
    return _parsePlayers(res.body);
  }

  // ── Stale snapshot: datos guardados sin importar TTL, para mostrar
  //    algo instantáneo al abrir la app antes de que llegue la respuesta
  //    de red. Devuelve null si no hay nada guardado todavía.

  static Future<({
    List<ClasificationEntry> standings,
    List<Match>              matches,
    List<Player>             players,
  })?> loadStaleSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cls  = prefs.getString('weball_clasification');
      final mtch = prefs.getString('weball_matches');
      if (cls == null || mtch == null) return null;
      final plyr = prefs.getString('weball_players');
      return (
        standings: _parseClasification(cls),
        matches:   _parseMatches(mtch),
        players:   plyr != null ? _parsePlayers(plyr) : <Player>[],
      );
    } catch (_) {
      return null;
    }
  }
}
