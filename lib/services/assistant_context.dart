import '../models/category_config.dart';
import '../models/match_preview.dart';
import '../models/models.dart';
import 'weather_service.dart';

/// Arma, en texto plano, los datos que la app ya tiene cargados para que el
/// asistente responda sobre partidos, resultados, tabla y plantel. No incluye
/// goleadores ni tarjetas: la app no muestra datos individuales de los chicos.
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
    if (d != null && d.venueName != null) {
      b.write(' | sede: ${d.venueName}, ${d.venueAddress ?? ''}');
    }
    b.writeln();
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
