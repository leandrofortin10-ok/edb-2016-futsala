import 'dart:convert';

int? _parseInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

int _parseIntOrZero(dynamic v) => _parseInt(v) ?? 0;

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
      inscriptionId:   _parseInt(ci['id']),
      inscriptionName: ci['tableName'] as String? ?? ci['name'] as String?,
      logo:            ci['logo'] as String?,
      pts: _parseIntOrZero(j['pts']),
      pj:  _parseIntOrZero(j['pj']),
      pg:  _parseIntOrZero(j['pg']),
      pe:  _parseIntOrZero(j['pe']),
      pp:  _parseIntOrZero(j['pp']),
      gf:  _parseIntOrZero(j['gf']),
      gc:  _parseIntOrZero(j['gc']),
      dg:  _parseIntOrZero(j['dg']),
    );
  }
}

class Match {
  final int id;
  final int tournamentMatchId;
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
  final String? fieldState;
  final String? payment;
  final String? refereeClothing;
  final List<String> spreadsheetPhotos;

  Match({
    required this.id,
    this.tournamentMatchId = 0,
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
    this.fieldState,
    this.payment,
    this.refereeClothing,
    this.spreadsheetPhotos = const [],
  });

  // Response structure: visualizer.children[].matchesPlanning[]
  // clubHome/clubAway.clubInscription, valueScoreHome/Away, dateTime
  factory Match.fromJson(Map<String, dynamic> j, {String? fechaLabel}) {
    final homeCi = (j['clubHome'] as Map?)?['clubInscription'] as Map?;
    final awayCi = (j['clubAway'] as Map?)?['clubInscription'] as Map?;
    final homeVac = j['vacancyHome'] as Map?;
    final awayVac = j['vacancyAway'] as Map?;

    String? date, time;
    // tm[0] es siempre vacío en esta API. Los datos reales están en tm[1]+.
    // Buscamos el primer tournamentMatch con datos reales.
    Map? tmReal;
    final tmList = j['tournamentMatches'];
    if (tmList is List) {
      for (final t in tmList) {
        final mi = (t as Map?)?['matchInfo'] as Map?;
        if (mi?['dateTime'] != null || t?['scoreHome'] != null) {
          tmReal = t as Map?;
          break;
        }
      }
    }

    String? dtStr = j['dateTime'] as String?;
    if (dtStr == null) {
      dtStr = tmReal?['matchInfo']?['dateTime'] as String?;
    }
    if (dtStr != null) {
      // Format may be "2026-03-22 10:00" (local) or ISO — handle both
      final dt = DateTime.tryParse(dtStr) ?? DateTime.tryParse(dtStr.replaceFirst(' ', 'T'));
      if (dt != null) {
        final local = dtStr.contains('T') ? dt.toLocal() : dt;
        date = '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
        time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      }
    }

    // Parse refereeReport JSON string from matchInfo
    String? fieldState;
    String? payment;
    String? refereeClothing;
    final refereeReportStr = tmReal?['matchInfo']?['refereeReport'] as String?;
    if (refereeReportStr != null) {
      try {
        final report = jsonDecode(refereeReportStr) as Map?;
        fieldState      = report?['fieldState'] as String?;
        payment         = report?['payment'] as String?;
        refereeClothing = report?['clothing'] as String?;
      } catch (_) {}
    }

    // Parse spreadsheet photos
    final photosRaw = tmReal?['matchInfo']?['spreadsheetPhotos'];
    final spreadsheetPhotos = photosRaw is List
        ? photosRaw.whereType<String>().toList()
        : <String>[];

    return Match(
      id:                    _parseIntOrZero(j['id']),
      tournamentMatchId:     _parseIntOrZero(tmReal?['id']),
      date:                  date,
      time:                  time,
      localName:             homeCi?['tableName'] as String? ?? homeVac?['name'] as String?,
      visitorName:           awayCi?['tableName'] as String? ?? awayVac?['name'] as String?,
      localLogo:             homeCi?['logo'] as String?,
      visitorLogo:           awayCi?['logo'] as String?,
      localInscriptionId:    _parseInt(homeCi?['id']),
      visitorInscriptionId:  _parseInt(awayCi?['id']),
      scoreLocal:            _parseInt(j['valueScoreHome']) ?? _parseInt(tmReal?['scoreHome']),
      scoreVisitor:          _parseInt(j['valueScoreAway']) ?? _parseInt(tmReal?['scoreAway']),
      fechaLabel:            fechaLabel,
      fieldState:            fieldState,
      payment:               payment,
      refereeClothing:       refereeClothing,
      spreadsheetPhotos:     spreadsheetPhotos,
    );
  }

  bool involvesInscription(int id) =>
      localInscriptionId == id || visitorInscriptionId == id;

  bool get hasResult => scoreLocal != null && scoreVisitor != null;
}

// ─── Match Detail Data ──────────────────────────────────────────────────────

class MatchGoalEvent {
  final String playerName;
  final int goals;

  MatchGoalEvent({required this.playerName, required this.goals});

  factory MatchGoalEvent.fromJson(Map<String, dynamic> j) {
    final player = j['player'] as Map?;
    final name = player?['name'] as String? ?? '';
    final lastName = player?['lastName'] as String? ?? '';
    final fullName = '$name $lastName'.trim();
    return MatchGoalEvent(
      playerName: fullName,
      goals: _parseIntOrZero(j['goals']),
    );
  }
}

class MatchCardEvent {
  final String playerName;

  MatchCardEvent({required this.playerName});

  factory MatchCardEvent.fromJson(Map<String, dynamic> j) {
    final player = j['player'] as Map?;
    final name = player?['name'] as String? ?? '';
    final lastName = player?['lastName'] as String? ?? '';
    final fullName = '$name $lastName'.trim();
    return MatchCardEvent(playerName: fullName);
  }
}

class MatchDetailData {
  final String? status;
  final String? statusColor;
  final String? venueName;
  final String? venueAddress;
  final List<Map<String, String?>> referees;
  final List<MatchGoalEvent> goalsHome;
  final List<MatchGoalEvent> goalsAway;
  final List<MatchCardEvent> yellowCardsHome;
  final List<MatchCardEvent> yellowCardsAway;
  final List<MatchCardEvent> redCardsHome;
  final List<MatchCardEvent> redCardsAway;
  final List<MatchCardEvent> doubleYellowCardsHome;
  final List<MatchCardEvent> doubleYellowCardsAway;

  MatchDetailData({
    this.status,
    this.statusColor,
    this.venueName,
    this.venueAddress,
    this.referees = const [],
    this.goalsHome = const [],
    this.goalsAway = const [],
    this.yellowCardsHome = const [],
    this.yellowCardsAway = const [],
    this.redCardsHome = const [],
    this.redCardsAway = const [],
    this.doubleYellowCardsHome = const [],
    this.doubleYellowCardsAway = const [],
  });

  factory MatchDetailData.fromJson(Map<String, dynamic> j) {
    final statusMap = j['status'] as Map?;
    final venueMap = j['venue'] as Map?;
    final refList = j['referees'] as List? ?? [];

    List<T> _parseList<T>(dynamic raw, T Function(Map<String, dynamic>) fn) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => fn(Map<String, dynamic>.from(e)))
          .toList();
    }

    return MatchDetailData(
      status:      statusMap?['name'] as String?,
      statusColor: statusMap?['color'] as String?,
      venueName:   venueMap?['name'] as String?,
      venueAddress: venueMap?['address'] as String?,
      referees: refList.whereType<Map>().map((r) => {
        'name':     r['name'] as String?,
        'lastName': r['lastName'] as String?,
        'logo':     r['logo'] as String?,
      }).toList(),
      goalsHome:   _parseList(j['eventGoalsListHome'], MatchGoalEvent.fromJson),
      goalsAway:   _parseList(j['eventGoalsListAway'], MatchGoalEvent.fromJson),
      yellowCardsHome:      _parseList(j['eventYellowCardsListHome'], MatchCardEvent.fromJson),
      yellowCardsAway:      _parseList(j['eventYellowCardsListAway'], MatchCardEvent.fromJson),
      redCardsHome:         _parseList(j['eventRedCardsListHome'], MatchCardEvent.fromJson),
      redCardsAway:         _parseList(j['eventRedCardsListAway'], MatchCardEvent.fromJson),
      doubleYellowCardsHome: _parseList(j['eventDoubleYellowCardsListHome'], MatchCardEvent.fromJson),
      doubleYellowCardsAway: _parseList(j['eventDoubleYellowCardsListAway'], MatchCardEvent.fromJson),
    );
  }
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
