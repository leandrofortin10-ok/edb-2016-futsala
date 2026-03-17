class ClasificationEntry {
  final int? inscriptionId;
  final String? inscriptionName;
  final String? logo;
  final int pts, pj, pg, pe, pp, gf, gc, dg;

  ClasificationEntry({
    this.inscriptionId,
    this.inscriptionName,
    this.logo,
    required this.pts,
    required this.pj,
    required this.pg,
    required this.pe,
    required this.pp,
    required this.gf,
    required this.gc,
    required this.dg,
  });

  // Response structure: positions[].club.clubInscription + stats at position level
  factory ClasificationEntry.fromJson(Map<String, dynamic> j) {
    final ci = (j['club'] as Map?)?['clubInscription'] as Map? ?? {};
    return ClasificationEntry(
      inscriptionId:   ci['id'] as int?,
      inscriptionName: ci['tableName'] as String? ?? ci['name'] as String?,
      logo:            ci['logo'] as String?,
      pts: j['pts'] as int? ?? 0,
      pj:  j['pj']  as int? ?? 0,
      pg:  j['pg']  as int? ?? 0,
      pe:  j['pe']  as int? ?? 0,
      pp:  j['pp']  as int? ?? 0,
      gf:  j['gf']  as int? ?? 0,
      gc:  j['gc']  as int? ?? 0,
      dg:  j['dg']  as int? ?? 0,
    );
  }
}

class Match {
  final int id;
  final String? date;
  final String? time;
  final String? localName;
  final String? visitorName;
  final String? localLogo;
  final String? visitorLogo;
  final int? localInscriptionId;
  final int? visitorInscriptionId;
  final int? scoreLocal;
  final int? scoreVisitor;
  final String? fechaLabel;

  Match({
    required this.id,
    this.date,
    this.time,
    this.localName,
    this.visitorName,
    this.localLogo,
    this.visitorLogo,
    this.localInscriptionId,
    this.visitorInscriptionId,
    this.scoreLocal,
    this.scoreVisitor,
    this.fechaLabel,
  });

  // Response structure: visualizer.children[].matchesPlanning[]
  // clubHome/clubAway.clubInscription, valueScoreHome/Away, dateTime
  factory Match.fromJson(Map<String, dynamic> j, {String? fechaLabel}) {
    final homeCi = (j['clubHome'] as Map?)?['clubInscription'] as Map?;
    final awayCi = (j['clubAway'] as Map?)?['clubInscription'] as Map?;
    final homeVac = j['vacancyHome'] as Map?;
    final awayVac = j['vacancyAway'] as Map?;

    String? date, time;
    final dtStr = j['dateTime'] as String?;
    if (dtStr != null) {
      final dt = DateTime.tryParse(dtStr)?.toLocal();
      if (dt != null) {
        date = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return Match(
      id:                    j['id'] as int? ?? 0,
      date:                  date,
      time:                  time,
      localName:             homeCi?['tableName'] as String? ?? homeVac?['name'] as String?,
      visitorName:           awayCi?['tableName'] as String? ?? awayVac?['name'] as String?,
      localLogo:             homeCi?['logo'] as String?,
      visitorLogo:           awayCi?['logo'] as String?,
      localInscriptionId:    homeCi?['id'] as int?,
      visitorInscriptionId:  awayCi?['id'] as int?,
      scoreLocal:            j['valueScoreHome'] as int?,
      scoreVisitor:          j['valueScoreAway'] as int?,
      fechaLabel:            fechaLabel,
    );
  }

  bool involvesInscription(int id) =>
      localInscriptionId == id || visitorInscriptionId == id;

  bool get hasResult => scoreLocal != null && scoreVisitor != null;
}

class Player {
  final String? name;
  final String? lastName;
  final String? categoryName;

  Player({this.name, this.lastName, this.categoryName});

  factory Player.fromJson(Map<String, dynamic> j) => Player(
    name:         j['name'] as String?,
    lastName:     j['lastName'] as String?,
    categoryName: j['categoryName'] as String?,
  );

  String get fullName => '${name ?? ''} ${lastName ?? ''}'.trim();

  String get initials {
    final n = name?.isNotEmpty == true ? name![0] : '';
    final l = lastName?.isNotEmpty == true ? lastName![0] : '';
    return '$n$l'.toUpperCase();
  }
}
