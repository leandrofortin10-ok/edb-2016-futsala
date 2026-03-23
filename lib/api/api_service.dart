import 'dart:convert';
import 'package:http/http.dart' as http;
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

  static int get myInscriptionId => _inscriptionId;

  // Response: [{positions: [{club:{clubInscription:{...}}, pts, pj, ...}]}]
  static Future<List<ClasificationEntry>> fetchClasification() async {
    final uri = Uri.parse(
      '$_base/tournament/$_tournamentId/phase/$_phaseId/group/$_groupId/clasification'
      '?instanceUUID=$_instanceUUID',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Error ${res.statusCode}');
    final List data = jsonDecode(res.body);
    final positions = (data.first as Map)['positions'] as List? ?? [];
    return positions
        .map((e) => ClasificationEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Response: {children:[{value:"Fecha N", matchesPlanning:[...]}]}
  // NOTA: cada match tiene tournamentMatches[4]. tm[0] siempre es vacío.
  // Los datos reales (score, fecha) están en tm[1] (el partido oficial que
  // cuenta para la tabla). tm[2] y tm[3] son sub-partidos del mismo fixture.
  static Future<List<Match>> fetchMatches() async {
    final uri = Uri.parse(
      '$_base/tournament/$_tournamentId/phase/$_phaseId/visualizer'
      '?instanceUUID=$_instanceUUID',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Error ${res.statusCode}');

    final vizData = jsonDecode(res.body) as Map<String, dynamic>;
    final children = vizData['children'] as List? ?? [];

    final allMatches = <Match>[];
    for (final child in children) {
      final c = child as Map<String, dynamic>;
      final label = c['value'] as String?;
      final matchesPlanning = c['matchesPlanning'] as List? ?? [];
      for (final m in matchesPlanning) {
        final match = Match.fromJson(m as Map<String, dynamic>, fechaLabel: label);
        if (match.involvesInscription(_inscriptionId)) {
          allMatches.add(match);
        }
      }
    }
    return allMatches;
  }

  static Future<List<Player>> fetchPlayers() async {
    final uri = Uri.parse(
      '$_base/team/$_teamId/inscription/$_inscriptionId/category/$_categoryId/player',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final List data = jsonDecode(res.body);
    return data.map((e) => Player.fromJson(e as Map<String, dynamic>)).toList();
  }
}
