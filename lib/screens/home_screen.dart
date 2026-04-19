import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/api_service.dart';
import '../models/category_config.dart';
import '../models/models.dart';
import '../services/background_sync.dart';
import '../services/debug_overrides.dart';
import '../services/notifications.dart';
import '../services/weather_service.dart';
import '../utils/birthdays.dart';
import '../widgets/team_logo.dart';
import 'debug_screen.dart';
import 'match_detail_screen.dart';

const _kBlue   = Color(0xFF388bfd);
const _kBg     = Color(0xFF0d1117);
const _kSurface = Color(0xFF161b22);
const _kSurface2 = Color(0xFF21262d);
const _kBorder = Color(0xFF30363d);
const _kMuted  = Color(0xFF8b949e);
const _kGreen  = Color(0xFF3fb950);
const _kRed    = Color(0xFFf85149);
const _kYellow = Color(0xFFd29922);
const _myInscriptionId = 2129;


const _monthNames = [
  '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CategoryConfig _selectedCategory = CategoryConfig.all.first;
  List<ClasificationEntry> _standings = [];
  List<Match> _matches = [];
  List<Player> _players = [];
  Map<int, MatchDetailData> _matchDetails = {};
  bool _loading = true;
  String? _error;
  DateTime? _lastUpdate;
  Timer? _refreshTimer;
  WeatherInfo? _weather;
  bool _showNotifBanner = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _loadAll();
    if (kIsWeb && notifPermission != 'granted') {
      setState(() => _showNotifBanner = true);
    }
    // Auto-refresh cada 5 minutos mientras la app está en primer plano
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _loadAll());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _switchCategory(CategoryConfig cat) {
    if (_selectedCategory.year == cat.year) return;
    setState(() {
      _selectedCategory = cat;
      _standings    = [];
      _matches      = [];
      _players      = [];
      _matchDetails = {};
      _loading      = true;
    });
    _loadAll();
  }

  Future<void> _enableNotifications() async {
    await initNotifications();
    await showNotification(
      '🔔 Notificaciones activas',
      'Te avisaremos cuando haya cambios en Estrella de Boedo',
    );
    if (mounted) setState(() => _showNotifBanner = false);
  }

  Future<void> _loadAll() async {
    if (mounted) setState(() => _error = null);

    final cat = _selectedCategory;

    // Fase 1: mostrar datos guardados instantáneamente (stale-while-revalidate)
    if (_standings.isEmpty) {
      final stale = await ApiService.loadStaleSnapshot(cat);
      if (stale != null && mounted) {
        setState(() {
          _standings = stale.standings;
          _matches   = stale.matches;
          _players   = stale.players;
          _loading   = false;
        });
      }
    }

    // Fase 2: traer datos frescos (desde cache si TTL vigente, si no desde red)
    // Solo muestra spinner si todavía no tenemos nada que mostrar
    if (_standings.isEmpty && mounted) setState(() => _loading = true);

    try {
      final results = await Future.wait([
        ApiService.fetchClasification(cat),
        ApiService.fetchMatches(cat),
        ApiService.fetchPlayers(cat),
      ]);
      final standings = results[0] as List<ClasificationEntry>;
      final matches   = results[1] as List<Match>;
      final players   = results[2] as List<Player>;
      // Notificar cambios solo para la categoría principal
      if (cat.year == CategoryConfig.all.first.year) {
        await checkForChanges(matches: matches, standings: standings, players: players);
      }

      // Fetch details for played matches (to get scorer/card data)
      final played = matches.where((m) => m.hasResult && m.tournamentMatchId != 0).toList();
      final details = await Future.wait(
        played.map((m) => ApiService.fetchMatchDetail(m.tournamentMatchId)),
      );
      final detailMap = <int, MatchDetailData>{};
      for (int i = 0; i < played.length; i++) {
        detailMap[played[i].tournamentMatchId] = details[i];
      }

      // Cargar clima ANTES de limpiar overrides
      final next = matches.firstWhere((m) => !_isPast(m), orElse: () => matches.last);
      final weatherDate = DebugOverrides.nextMatchDate ?? next.date;
      final weatherTime = DebugOverrides.nextMatchDate != null
          ? DebugOverrides.nextMatchTime : next.time;
      DebugOverrides.clear();
      WeatherInfo? weather;
      if (weatherDate != null) {
        weather = await WeatherService.getForecast(weatherDate, weatherTime);
      }

      setState(() {
        _standings    = standings;
        _matches      = matches;
        _players      = players;
        _matchDetails = detailMap;
        _weather      = weather;
        _loading      = false;
        _lastUpdate   = DateTime.now();
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        // Solo mostrar error si no tenemos datos previos que mostrar
        if (_standings.isEmpty) _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_showNotifBanner && kIsWeb) _buildNotifBanner(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _kBlue))
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _loadAll,
                          color: _kBlue,
                          backgroundColor: _kSurface,
                          child: _buildBody(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          if (!kReleaseMode)
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DebugScreen()))
                .then((changed) async {
                  if (changed != true) return;
                  WeatherInfo? w;
                  if (DebugOverrides.nextMatchDate != null) {
                    w = await WeatherService.getForecast(
                      DebugOverrides.nextMatchDate!, DebugOverrides.nextMatchTime);
                  }
                  if (mounted) setState(() { if (w != null) _weather = w; });
                }),
              child: const Icon(Icons.bug_report_outlined, color: _kMuted, size: 18)),
          const Spacer(),
          if (_loading)
            const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2)),
        ],
      ),
    );
  }

  Widget _buildBannerImage() {
    return Center(
      child: SizedBox(
        width: 240,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/bandera_categoria.jpeg',
                width: 240,
                fit: BoxFit.contain,
              ),
            ),
            // Bordes difuminados con gradientes simples (mucho más liviano que ShaderMask)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [_kBg, Colors.transparent, Colors.transparent, _kBg],
                      stops: const [0.0, 0.08, 0.92, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_kBg, Colors.transparent, Colors.transparent, _kBg],
                      stops: const [0.0, 0.08, 0.92, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotifBanner() {
    return Material(
      color: const Color(0xFF1f3a6e),
      child: InkWell(
        onTap: _enableNotifications,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.notifications_outlined, color: _kBlue, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Activar notificaciones de partidos y resultados',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const Icon(Icons.chevron_right, color: _kMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return _buildBodyDesktop();
        }
        return _buildBodyMobile();
      },
    );
  }

  Widget _buildCategorySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Wrap(
        spacing: 8,
        children: CategoryConfig.all.map((cat) {
          final selected = cat.year == _selectedCategory.year;
          return GestureDetector(
            onTap: () => _switchCategory(cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? _kBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? _kBlue : _kBorder),
              ),
              child: Text(
                cat.label,
                style: TextStyle(
                  color: selected ? Colors.white : _kMuted,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBodyMobile() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      cacheExtent: 2000,
      children: [
        _buildBannerImage(),
        const SizedBox(height: 12),
        _buildCategorySelector(),
        const SizedBox(height: 8),
        RepaintBoundary(child: _buildNextMatch()),
        const SizedBox(height: 12),
        RepaintBoundary(child: _buildQuickStats()),
        const SizedBox(height: 28),
        RepaintBoundary(child: _buildSection('Tabla de posiciones', _buildStandings())),
        const SizedBox(height: 28),
        RepaintBoundary(child: _buildSection('Fixture · Estrella de Boedo', _buildFixture())),
        const SizedBox(height: 28),
        RepaintBoundary(child: _buildSection('Goleadores · Estrella de Boedo', _buildScorers())),
        const SizedBox(height: 28),
        RepaintBoundary(child: _buildSection('Plantel', _buildPlayers())),
      ],
    );
  }

  Widget _buildBodyDesktop() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna izquierda: bandera + próximo partido + fixture
                Expanded(
                  flex: 55,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBannerImage(),
                      const SizedBox(height: 12),
                      _buildCategorySelector(),
                      const SizedBox(height: 8),
                      RepaintBoundary(child: _buildNextMatch()),
                      const SizedBox(height: 12),
                      RepaintBoundary(child: _buildQuickStats()),
                      const SizedBox(height: 32),
                      RepaintBoundary(child: _buildSection(
                          'Fixture · Estrella de Boedo', _buildFixture())),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Columna derecha: tabla + plantel
                Expanded(
                  flex: 45,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RepaintBoundary(child: _buildSection(
                          'Tabla de posiciones', _buildStandings())),
                      const SizedBox(height: 32),
                      RepaintBoundary(child: _buildSection(
                          'Goleadores · Estrella de Boedo', _buildScorers())),
                      const SizedBox(height: 32),
                      RepaintBoundary(child: _buildSection('Plantel',
                          _buildPlayersDesktop())),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
          style: const TextStyle(
            color: _kMuted, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        content,
      ],
    );
  }

  // ── Próximo partido ────────────────────────────────────────────────────────
  Widget _buildNextMatch() {
    if (_matches.isEmpty) {
      return _emptyCard('Sin partidos encontrados');
    }
    final next = _matches.firstWhere((m) => !_isPast(m), orElse: () => _matches.last);
    final isHome = next.localInscriptionId == _myInscriptionId;
    final played = next.hasResult;
    // Apply debug overrides for date/time
    final displayDate = DebugOverrides.nextMatchDate ?? next.date;
    final displayTime = DebugOverrides.nextMatchDate != null
        ? DebugOverrides.nextMatchTime
        : next.time;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0d1f3c), Color(0xFF161b22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF1f3a6e)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            played ? 'ÚLTIMO RESULTADO' : 'PRÓXIMO PARTIDO',
            style: const TextStyle(color: _kBlue, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _nmTeam(next.localName ?? '—', isHome, logoUrl: next.localLogo)),
              _nmCenter(next, played),
              Expanded(child: _nmTeam(next.visitorName ?? '—', !isHome, logoUrl: next.visitorLogo)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today, size: 12, color: _kMuted),
              const SizedBox(width: 5),
              Text(
                displayDate != null
                    ? _formatDate(displayDate, displayTime)
                    : 'Fecha y hora a confirmar',
                style: TextStyle(
                  fontSize: 12,
                  color: displayDate != null ? _kMuted : _kYellow,
                  fontStyle: displayDate != null ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ],
          ),
          if (_weather != null && displayDate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kSurface2,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_weather!.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(
                    '${_weather!.tempRounded}°C · ${_weather!.description}',
                    style: const TextStyle(color: _kMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Quick Stats (racha + countdown + stats + compartir) ────────────────────
  Widget _buildQuickStats() {
    if (_matches.isEmpty || _standings.isEmpty) return const SizedBox.shrink();

    final us = _standings.cast<ClasificationEntry?>().firstWhere(
        (e) => e!.inscriptionId == _myInscriptionId, orElse: () => null);

    return Column(
      children: [
        // Row 1: Racha + Countdown
        Row(
          children: [
            Expanded(child: _buildStreak()),
            const SizedBox(width: 8),
            Expanded(child: _buildCountdown()),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: Stats rápidas
        if (us != null) _buildStatsRow(us),
        const SizedBox(height: 8),
        // Row 3: Compartir por WhatsApp
        _buildShareButton(),
      ],
    );
  }

  /// Calcula la racha actual: victorias/empates/derrotas consecutivas.
  Widget _buildStreak() {
    final played = _matches.where((m) => m.hasResult).toList();
    if (played.isEmpty) return const SizedBox.shrink();

    // Construir lista de resultados de más reciente a más antiguo
    final results = <String>[];
    for (final m in played.reversed) {
      final isHome = m.localInscriptionId == _myInscriptionId;
      final us   = isHome ? m.scoreLocal! : m.scoreVisitor!;
      final them = isHome ? m.scoreVisitor! : m.scoreLocal!;
      if (us > them) results.add('W');
      else if (us < them) results.add('L');
      else results.add('D');
    }

    // Contar racha actual
    final current = results.first;
    int count = 0;
    for (final r in results) {
      if (r == current) count++;
      else break;
    }

    final Color streakColor;
    final String streakLabel;
    final IconData streakIcon;
    switch (current) {
      case 'W':
        streakColor = _kGreen;
        streakLabel = count == 1 ? '1 victoria' : '$count victorias';
        streakIcon = Icons.local_fire_department;
        break;
      case 'L':
        streakColor = _kRed;
        streakLabel = count == 1 ? '1 derrota' : '$count derrotas';
        streakIcon = Icons.trending_down;
        break;
      default:
        streakColor = _kYellow;
        streakLabel = count == 1 ? '1 empate' : '$count empates';
        streakIcon = Icons.trending_flat;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: streakColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(streakIcon, color: streakColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RACHA', style: TextStyle(
                    color: _kMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(streakLabel, style: TextStyle(
                    color: streakColor, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Últimos 5 resultados
          Row(
            children: results.take(5).map((r) {
              final c = r == 'W' ? _kGreen : r == 'L' ? _kRed : _kYellow;
              return Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Countdown al próximo partido.
  Widget _buildCountdown() {
    final next = _matches.cast<Match?>().firstWhere(
        (m) => !_isPast(m!), orElse: () => null);
    if (next == null || next.date == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kSurface,
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: _kMuted, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DÍAS PARA EL PRÓXIMO PARTIDO', style: TextStyle(
                      color: _kMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text('A confirmar', style: TextStyle(
                      color: _kYellow, fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final matchDate = DateTime.tryParse(next.date!);
    if (matchDate == null) return const SizedBox.shrink();

    DateTime matchDateTime = matchDate;
    if (next.time != null) {
      final parts = next.time!.split(':');
      if (parts.length == 2) {
        matchDateTime = DateTime(matchDate.year, matchDate.month, matchDate.day,
            int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
      }
    }

    final diff = matchDateTime.difference(DateTime.now());
    final String countdownText;
    if (diff.isNegative) {
      countdownText = 'En curso / Jugado';
    } else if (diff.inDays > 0) {
      countdownText = 'Faltan ${diff.inDays}d ${diff.inHours % 24}h';
    } else if (diff.inHours > 0) {
      countdownText = 'Faltan ${diff.inHours}h ${diff.inMinutes % 60}m';
    } else {
      countdownText = 'Faltan ${diff.inMinutes}m';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBlue.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: _kBlue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DÍAS PARA EL PRÓXIMO PARTIDO', style: TextStyle(
                    color: _kMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(countdownText, style: const TextStyle(
                    color: _kBlue, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Stats rápidas del equipo.
  Widget _buildStatsRow(ClasificationEntry us) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem('PJ', '${us.pj}', Colors.white),
          _statItem('PG', '${us.pg}', _kGreen),
          _statItem('PE', '${us.pe}', _kYellow),
          _statItem('PP', '${us.pp}', _kRed),
          _statItem('GF', '${us.gf}', _kGreen),
          _statItem('GC', '${us.gc}', _kRed),
          _statItem('DG', us.dg >= 0 ? '+${us.dg}' : '${us.dg}',
              us.dg > 0 ? _kGreen : us.dg < 0 ? _kRed : _kMuted),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(
            color: valueColor, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(
            color: _kMuted, fontSize: 9, fontWeight: FontWeight.w600)),
      ],
    );
  }

  /// Botón de compartir por WhatsApp.
  Widget _buildShareButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _shareViaWhatsApp,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF25D366).withOpacity(0.1),
            border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.share, color: Color(0xFF25D366), size: 16),
              SizedBox(width: 8),
              Text('Compartir por WhatsApp',
                  style: TextStyle(color: Color(0xFF25D366), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  void _shareViaWhatsApp() {
    if (_matches.isEmpty || _standings.isEmpty) return;

    final us = _standings.cast<ClasificationEntry?>().firstWhere(
        (e) => e!.inscriptionId == _myInscriptionId, orElse: () => null);

    // Último resultado
    final played = _matches.where((m) => m.hasResult).toList();
    String lastResult = '';
    if (played.isNotEmpty) {
      final m = played.last;
      lastResult = '${m.localName} ${m.scoreLocal} - ${m.scoreVisitor} ${m.visitorName}';
    }

    // Próximo partido
    final next = _matches.cast<Match?>().firstWhere(
        (m) => !_isPast(m!), orElse: () => null);
    String nextMatch = '';
    if (next != null) {
      nextMatch = '${next.localName} vs ${next.visitorName}';
      if (next.date != null) {
        nextMatch += ' · ${_formatDate(next.date!, next.time)}';
      }
    }

    final pos = us != null
        ? _standings.indexOf(us) + 1
        : '?';

    final lines = <String>[
      'Estrella de Boedo · ${_selectedCategory.label}',
    ];
    if (lastResult.isNotEmpty) lines.add('Último: $lastResult');
    if (nextMatch.isNotEmpty) lines.add('Próximo: $nextMatch');
    if (us != null) lines.add('Posición: $pos° · ${us.pts} pts');
    lines.add('');
    lines.add('https://edb-estrella.web.app');

    final text = Uri.encodeComponent(lines.join('\n'));
    final url = 'https://wa.me/?text=$text';

    if (kIsWeb) {
      html.window.open(url, '_blank');
    }
  }

  Widget _nmTeam(String name, bool isUs, {String? logoUrl}) {
    return Column(
      children: [
        TeamLogo(logoUrl: logoUrl, name: name, isUs: isUs, size: 56, fontSize: 16),
        const SizedBox(height: 8),
        Text(name,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isUs ? _kBlue : Colors.white,
            fontWeight: isUs ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _nmCenter(Match m, bool played) {
    if (played) {
      final isHome = m.localInscriptionId == _myInscriptionId;
      final us   = isHome ? m.scoreLocal! : m.scoreVisitor!;
      final them = isHome ? m.scoreVisitor! : m.scoreLocal!;
      Color c = _kMuted;
      if (us > them) c = _kGreen;
      else if (us < them) c = _kRed;
      else c = _kYellow;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _scoreBox('${m.scoreLocal}', c),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('–', style: TextStyle(color: _kMuted, fontSize: 14)),
                  ),
                  _scoreBox('${m.scoreVisitor}', c),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                us > them ? 'Victoria' : us < them ? 'Derrota' : 'Empate',
                style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: _kBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(m.fechaLabel ?? '',
                style: const TextStyle(color: _kBlue, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          const Text('VS', style: TextStyle(
              color: _kMuted, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _scoreBox(String val, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kSurface2,
        border: Border.all(color: c.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(val,
          style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.w800)),
    );
  }

  // ── Tabla de posiciones ────────────────────────────────────────────────────
  Widget _buildStandings() {
    if (_standings.isEmpty) return _emptyCard('Sin datos de tabla');
    var sorted = [..._standings]..sort((a, b) {
      final c = b.pts.compareTo(a.pts);
      return c != 0 ? c : b.dg.compareTo(a.dg);
    });
    // Aplicar override de posición visual
    final posOverride = DebugOverrides.myTablePosition;
    if (posOverride != null) {
      final idx = sorted.indexWhere((e) => e.inscriptionId == _myInscriptionId);
      if (idx >= 0) {
        final entry = sorted.removeAt(idx);
        final target = (posOverride - 1).clamp(0, sorted.length);
        sorted.insert(target, entry);
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: const BoxDecoration(
              color: _kSurface2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 22, child: Text('#', style: TextStyle(color: _kMuted, fontSize: 11, fontWeight: FontWeight.w700))),
                SizedBox(width: 8),
                Expanded(child: Text('Equipo', style: TextStyle(color: _kMuted, fontSize: 11, fontWeight: FontWeight.w700))),
                _SH('PTS'), _SH('PJ'), _SH('PG'), _SH('PE'), _SH('PP'), _SH('GF'), _SH('GC'), _SH('DG'),
              ],
            ),
          ),
          ...sorted.asMap().entries.map((e) => _standingsRow(e.key + 1, e.value, e.key == sorted.length - 1)),
        ],
      ),
    );
  }

  Widget _standingsRow(int pos, ClasificationEntry e, bool isLast) {
    final isUs = e.inscriptionId == _myInscriptionId;
    final dg = e.dg;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
      decoration: BoxDecoration(
        color: isUs ? _kBlue.withOpacity(0.08) : Colors.transparent,
        border: Border(
          bottom: isLast ? BorderSide.none : const BorderSide(color: _kBorder, width: 0.5),
          left: isUs ? const BorderSide(color: _kBlue, width: 2) : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 22,
            child: Text('$pos', style: TextStyle(
              color: isUs ? _kBlue : _kMuted,
              fontSize: 12, fontWeight: isUs ? FontWeight.bold : FontWeight.normal))),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(e.inscriptionName ?? '?',
                    style: TextStyle(color: isUs ? _kBlue : Colors.white,
                        fontSize: 12, fontWeight: isUs ? FontWeight.bold : FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                ),
                if (isUs) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(10)),
                    child: const Text('Vos', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
          _SC('${e.pts}', bold: true, color: isUs ? _kBlue : Colors.white),
          _SC('${e.pj}'),
          _SC('${e.pg}', color: _kGreen),
          _SC('${e.pe}', color: _kYellow),
          _SC('${e.pp}', color: _kRed),
          _SC('${e.gf}'),
          _SC('${e.gc}'),
          _SC(dg >= 0 ? '+$dg' : '$dg',
              color: dg > 0 ? _kGreen : dg < 0 ? _kRed : _kMuted),
        ],
      ),
    );
  }

  // ── Fixture ────────────────────────────────────────────────────────────────
  Widget _buildFixture() {
    if (_matches.isEmpty) return _emptyCard('Sin partidos');
    return Column(
      children: _matches.asMap().entries.map((e) {
        final rivalOverride = (e.key == 1) ? DebugOverrides.fixtureRivalName : null;
        return _fixtureRow(e.value, rivalOverride: rivalOverride);
      }).toList(),
    );
  }

  Widget _fixtureRow(Match m, {String? rivalOverride}) {
    final isHome = m.localInscriptionId == _myInscriptionId;
    final played = m.hasResult;
    final pastNoResult = !played && _isPast(m); // jugado pero sin resultado en API
    final us    = isHome ? m.scoreLocal  : m.scoreVisitor;
    final them  = isHome ? m.scoreVisitor : m.scoreLocal;

    Color resultColor = _kBorder;
    if (played && us != null && them != null) {
      if (us > them) resultColor = _kGreen;
      else if (us < them) resultColor = _kRed;
      else resultColor = _kYellow;
    } else if (pastNoResult) {
      resultColor = _kMuted; // gris: jugado sin resultado cargado
    }

    final localName = (!isHome && rivalOverride != null) ? rivalOverride : (m.localName ?? '—');
    final visitorName = (isHome && rivalOverride != null) ? rivalOverride : (m.visitorName ?? '—');

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MatchDetailScreen(match: m),
        ),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: played ? resultColor : _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            // Fecha label
            Align(
              alignment: Alignment.centerLeft,
              child: Text(m.fechaLabel ?? '',
                style: const TextStyle(color: _kMuted, fontSize: 10,
                    fontWeight: FontWeight.w600, letterSpacing: 0.3)),
            ),
            const SizedBox(height: 8),
            // Equipos
            Row(
              children: [
                // Local
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(localName,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isHome ? _kBlue : Colors.white,
                            fontWeight: isHome ? FontWeight.bold : FontWeight.w500,
                            fontSize: 11,
                          )),
                      ),
                      const SizedBox(width: 6),
                      _fixLogo(m.localLogo, localName, isHome),
                    ],
                  ),
                ),
                // Centro: score o vs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: played
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          _fixScoreBox('${m.scoreLocal}', isHome && us! > them!),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 3),
                            child: Text('–', style: TextStyle(color: _kMuted, fontSize: 12)),
                          ),
                          _fixScoreBox('${m.scoreVisitor}', !isHome && them! > us!),
                        ])
                      : pastNoResult
                          ? Column(mainAxisSize: MainAxisSize.min, children: [
                              Text('?–?', style: TextStyle(color: _kMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text('sin resultado', style: TextStyle(color: _kMuted, fontSize: 8, fontStyle: FontStyle.italic)),
                            ])
                          : Column(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: _kBorder),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('vs', style: TextStyle(color: _kMuted, fontSize: 10)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                m.date != null ? _formatDate(m.date!, m.time) : 'A confirmar',
                                style: TextStyle(
                                  color: m.date != null ? _kMuted : _kYellow,
                                  fontSize: 9,
                                  fontStyle: m.date != null ? FontStyle.normal : FontStyle.italic,
                                ),
                              ),
                            ]),
                ),
                // Visitante
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _fixLogo(m.visitorLogo, visitorName, !isHome),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(visitorName,
                          textAlign: TextAlign.left,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: !isHome ? _kBlue : Colors.white,
                            fontWeight: !isHome ? FontWeight.bold : FontWeight.w500,
                            fontSize: 11,
                          )),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _fixLogo(String? logoUrl, String name, bool isUs) {
    // Usa iniciales de texto en vez de platform view para mejor performance de scroll
    final abbrev = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    final initials = abbrev.length >= 2
        ? '${abbrev[0][0]}${abbrev[1][0]}'.toUpperCase()
        : (abbrev.isNotEmpty ? abbrev[0][0].toUpperCase() : '?');
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: _kSurface2,
        shape: BoxShape.circle,
        border: Border.all(
          color: isUs ? _kBlue : _kBorder,
          width: isUs ? 2 : 1,
        ),
      ),
      child: Center(
        child: Text(initials,
          style: TextStyle(
            color: isUs ? _kBlue : _kMuted,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          )),
      ),
    );
  }

  Widget _fixScoreBox(String val, bool highlight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _kSurface2,
        border: Border.all(color: highlight ? _kGreen : _kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(val, style: TextStyle(
          color: highlight ? _kGreen : Colors.white,
          fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  // ── Goleadores ───────────────────────────────────────────────────────────
  List<MapEntry<String, int>> _computeScorers() {
    final scorers = <String, int>{};
    for (final m in _matches.where((m) => m.hasResult)) {
      final detail = _matchDetails[m.tournamentMatchId];
      if (detail == null) continue;
      final isHome = m.localInscriptionId == _myInscriptionId;
      final goals = isHome ? detail.goalsHome : detail.goalsAway;
      for (final g in goals) {
        if (g.playerName.isNotEmpty) {
          scorers[g.playerName] = (scorers[g.playerName] ?? 0) + g.goals;
        }
      }
    }
    final sorted = scorers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  Widget _buildScorers() {
    final scorers = _computeScorers();
    if (scorers.isEmpty) return _emptyCard('Sin goles registrados aún');
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: scorers.asMap().entries.map((e) {
          final idx = e.key;
          final scorer = e.value;
          final isLast = idx == scorers.length - 1;
          final isTop = idx == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: isLast ? BorderSide.none : const BorderSide(color: _kBorder, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Position
                SizedBox(
                  width: 24,
                  child: Text(
                    '${idx + 1}',
                    style: TextStyle(
                      color: isTop ? _kYellow : _kMuted,
                      fontSize: 12,
                      fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                // Goal icon
                Icon(Icons.sports_soccer, size: 14,
                    color: isTop ? _kYellow : _kMuted),
                const SizedBox(width: 8),
                // Player name
                Expanded(
                  child: Text(
                    scorer.key,
                    style: TextStyle(
                      color: isTop ? Colors.white : _kMuted,
                      fontSize: 12,
                      fontWeight: isTop ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Goal count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isTop ? _kYellow.withOpacity(0.15) : _kSurface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${scorer.value}',
                    style: TextStyle(
                      color: isTop ? _kYellow : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Plantel ────────────────────────────────────────────────────────────────

  /// Busca el cumpleaños de un jugador por su apellido.
  (int, int)? _playerBirthday(Player p) => birthdayForLastName(p.lastName ?? '');

  /// Próximo cumpleaños del plantel (o hoy).
  (Player, int month, int day, bool isToday)? _nextBirthday() {
    final now = DateTime.now();
    (Player, int, int, int)? best; // player, month, day, daysUntil
    for (final p in _players) {
      final bd = _playerBirthday(p);
      if (bd == null) continue;
      final (m, d) = bd;
      var next = DateTime(now.year, m, d);
      if (next.isBefore(DateTime(now.year, now.month, now.day))) {
        next = DateTime(now.year + 1, m, d);
      }
      final diff = next.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (best == null || diff < best.$4) {
        best = (p, m, d, diff);
      }
    }
    if (best == null) return null;
    return (best.$1, best.$2, best.$3, best.$4 == 0);
  }

  Widget _buildPlayers() => _buildPlayersList(columns: 1);
  Widget _buildPlayersDesktop() => _buildPlayersList(columns: 1);

  Widget _buildPlayersList({required int columns}) {
    if (_players.isEmpty) return _emptyCard('Sin jugadores cargados aún');

    final nextBd = _nextBirthday();
    final extra = DebugOverrides.extraPlayer;

    // Ordenar jugadores por fecha de cumpleaños (mes, día). Sin cumpleaños al final.
    final sorted = List<Player>.from(_players)..sort((a, b) {
      final bdA = _playerBirthday(a);
      final bdB = _playerBirthday(b);
      if (bdA == null && bdB == null) return 0;
      if (bdA == null) return 1;
      if (bdB == null) return -1;
      final cmp = bdA.$1.compareTo(bdB.$1);
      return cmp != 0 ? cmp : bdA.$2.compareTo(bdB.$2);
    });

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Próximo cumpleaños banner
          if (nextBd != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: nextBd.$4
                    ? _kYellow.withOpacity(0.12)
                    : _kSurface2,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  Text(nextBd.$4 ? '🎂' : '🎈', style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: nextBd.$4 ? '¡Hoy cumple! ' : 'Próximo cumple: ',
                          style: TextStyle(
                            color: nextBd.$4 ? _kYellow : _kMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: nextBd.$1.fullName,
                          style: TextStyle(
                            color: nextBd.$4 ? Colors.white : _kBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: ' · ${nextBd.$3} ${_monthNames[nextBd.$2]}',
                          style: const TextStyle(color: _kMuted, fontSize: 11),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          if (nextBd != null)
            const Divider(height: 1, color: _kBorder),
          // Player list
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (int i = 0; i < sorted.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  _playerCard(sorted[i]),
                ],
                if (extra != null) ...[
                  const SizedBox(height: 6),
                  _playerCardRaw(extra, highlight: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// DiceBear avatar URL — estilo "bottts" (robots, neutro).
  String _avatarUrl(String name) {
    final seed = Uri.encodeComponent(name.trim());
    return 'https://api.dicebear.com/9.x/bottts-neutral/png?seed=$seed&size=80&backgroundColor=161b22';
  }

  Widget _playerCard(Player p) {
    final bd = _playerBirthday(p);
    final now = DateTime.now();
    final isToday = bd != null && bd.$1 == now.month && bd.$2 == now.day;
    final displayName = p.fullName;

    return Container(
      decoration: BoxDecoration(
        color: isToday ? _kYellow.withOpacity(0.06) : Colors.transparent,
        border: Border.all(color: isToday ? _kYellow.withOpacity(0.4) : _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          // Birthday badge on the right
          if (bd != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isToday ? _kYellow.withOpacity(0.15) : _kSurface2,
                borderRadius: BorderRadius.circular(12),
                border: isToday ? Border.all(color: _kYellow.withOpacity(0.4)) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isToday ? Icons.cake : Icons.cake_outlined,
                    size: 13,
                    color: isToday ? _kYellow : _kMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${bd.$2} ${_monthNames[bd.$1]}',
                    style: TextStyle(
                      color: isToday ? _kYellow : _kMuted,
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _playerCardRaw(String name, {bool highlight = false}) {
    final color = highlight ? _kYellow : _kBlue;
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: highlight ? _kYellow.withOpacity(0.5) : _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kSurface2,
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              _avatarUrl(name),
              width: 40, height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(_initials(name),
                  style: TextStyle(color: color,
                      fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
              style: TextStyle(color: highlight ? _kYellow : Colors.white,
                  fontWeight: FontWeight.w600, fontSize: 11),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: _kMuted),
            const SizedBox(height: 16),
            const Text('No se pudo cargar', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('No se pudo cargar los datos. Verificá tu conexión e intentá de nuevo.', style: TextStyle(color: _kMuted, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: Text(msg, style: const TextStyle(color: _kMuted, fontSize: 13))),
    );
  }

  // Un partido es "pasado" si tiene resultado cargado, O si su fecha ya ocurrió
  bool _isPast(Match m) {
    if (m.hasResult) return true;
    if (m.date == null) return false;
    final d = DateTime.tryParse(m.date!);
    if (d == null) return false;
    final today = DateTime.now();
    return d.isBefore(DateTime(today.year, today.month, today.day));
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatDate(String date, String? time) {
    try {
      final p = date.split('-');
      final d = '${p[2]}/${p[1]}';
      return time != null ? '$d $time' : d;
    } catch (_) { return date; }
  }
}

// ── Tabla helpers ──────────────────────────────────────────────────────────
class _SH extends StatelessWidget {
  final String t;
  const _SH(this.t);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 26,
    child: Text(t, textAlign: TextAlign.center,
        style: const TextStyle(color: _kMuted, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

class _SC extends StatelessWidget {
  final String t;
  final bool bold;
  final Color? color;
  const _SC(this.t, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 26,
    child: Text(t, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color ?? _kMuted)),
  );
}
