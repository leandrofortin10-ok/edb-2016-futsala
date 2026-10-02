import '../models/category_config.dart';
import '../models/match_preview.dart';
import '../models/models.dart';
import 'weather_service.dart';

/// Arma, en texto plano, los datos que la app ya tiene cargados para que el
/// asistente responda sobre partidos, resultados, tabla, plantel y goleadores.
/// Formato compacto: el texto viaja en cada pregunta.
String buildAssistantContext({
  required CategoryConfig category,
  required int myInscriptionId,
  required List<Match> matches,
  required List<Match> allMatches,
  required List<ClasificationEntry> standings,
  required bool standingsPublished,
  required List<Player> players,
  required Map<int, MatchDetailData> matchDetails,
  Match? nextMatch,
  WeatherInfo? weather,
  MatchPreview? preview,
}) {
  final b = StringBuffer();
  String score(Match m) => m.hasResult ? '${m.scoreLocal}-${m.scoreVisitor}' : 'sin jugar';
  String when(Match m) => m.date == null
      ? 'fecha a confirmar'
      : '${m.date}${m.time != null ? ' ${m.time}' : ''}';

  b.writeln('Categoría: ${category.categoryLabel}');

  b.writeln('\n## Próximo partido');
  if (nextMatch == null) {
    b.writeln('No hay próximo partido.');
  } else {
    final isHome = nextMatch.localInscriptionId == myInscriptionId;
    b.writeln('${nextMatch.fechaLabel ?? ''}: ${nextMatch.localName} vs ${nextMatch.visitorName} '
        '(Estrella juega de ${isHome ? 'local' : 'visitante'}), ${when(nextMatch)}');
    if (weather != null) {
      b.writeln('Pronóstico: ${weather.description}, ${weather.tempRounded} °C');
    }
    if (preview != null) b.writeln('Previa publicada en la app: ${preview.text}');
  }

  b.writeln('\n## Fixture y resultados de Estrella de Boedo');
  for (final m in matches) {
    b.write('${m.fechaLabel ?? ''} | ${when(m)} | ${m.localName} ${score(m)} ${m.visitorName}');
    final d = matchDetails[m.tournamentMatchId];
    if (d != null) {
      final isHome = m.localInscriptionId == myInscriptionId;
      String goals(List<MatchGoalEvent> l) =>
          l.map((g) => g.goals > 1 ? '${g.playerName} (${g.goals})' : g.playerName).join(', ');
      String names(List<MatchCardEvent> l) => l.map((c) => c.playerName).join(', ');
      final ourGoals = isHome ? d.goalsHome : d.goalsAway;
      final ourYellow = isHome ? d.yellowCardsHome : d.yellowCardsAway;
      final ourRed = isHome ? d.redCardsHome : d.redCardsAway;
      if (d.venueName != null) b.write(' | sede: ${d.venueName}, ${d.venueAddress ?? ''}');
      if (ourGoals.isNotEmpty) b.write(' | goles de Estrella: ${goals(ourGoals)}');
      if (ourYellow.isNotEmpty) b.write(' | amarillas de Estrella: ${names(ourYellow)}');
      if (ourRed.isNotEmpty) b.write(' | rojas de Estrella: ${names(ourRed)}');
    }
    b.writeln();
  }

  final scorers = <String, int>{};
  for (final m in matches.where((m) => m.hasResult)) {
    final d = matchDetails[m.tournamentMatchId];
    if (d == null) continue;
    final ourGoals = m.localInscriptionId == myInscriptionId ? d.goalsHome : d.goalsAway;
    for (final g in ourGoals) {
      if (g.playerName.isNotEmpty) scorers[g.playerName] = (scorers[g.playerName] ?? 0) + g.goals;
    }
  }
  if (scorers.isNotEmpty) {
    final sorted = scorers.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    b.writeln('\n## Goleadores de Estrella');
    for (final e in sorted) {
      b.writeln('${e.key}: ${e.value}');
    }
  }

  b.writeln('\n## Tabla de posiciones');
  if (!standingsPublished || standings.every((e) => e.pj == 0)) {
    b.writeln('La tabla todavía no está publicada.');
  } else {
    b.writeln('Pos | Equipo | Pts | PJ | PG | PE | PP | GF | GC | DG');
    for (var i = 0; i < standings.length; i++) {
      final e = standings[i];
      b.writeln('${i + 1} | ${e.inscriptionName} | ${e.pts} | ${e.pj} | ${e.pg} | ${e.pe} | '
          '${e.pp} | ${e.gf} | ${e.gc} | ${e.dg}');
    }
  }

  b.writeln('\n## Resultados de todos los equipos de la categoría');
  for (final m in allMatches.where((m) => m.hasResult)) {
    b.writeln('${m.fechaLabel ?? ''}: ${m.localName} ${score(m)} ${m.visitorName}');
  }

  b.writeln('\n## Plantel de Estrella');
  b.writeln(players.isEmpty ? 'Sin datos.' : players.map((p) => p.fullName).join(', '));

  return b.toString();
}
