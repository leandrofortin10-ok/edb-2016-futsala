import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../models/match_media.dart';
import '../services/media_service.dart';
import '../services/auth_service.dart';
import '../api/api_service.dart';
import '../widgets/team_logo.dart';
import '../widgets/cdn_image.dart';

const _kBlue    = Color(0xFF388bfd);
const _kBg      = Color(0xFF0d1117);
const _kSurface = Color(0xFF161b22);
const _kSurface2 = Color(0xFF21262d);
const _kBorder  = Color(0xFF30363d);
const _kMuted   = Color(0xFF8b949e);
const _kGreen   = Color(0xFF3fb950);
const _kRed     = Color(0xFFf85149);
const _kYellow  = Color(0xFFd29922);
const _kMyInscriptionId = 2129;

class MatchDetailScreen extends StatefulWidget {
  final Match match;

  const MatchDetailScreen({super.key, required this.match});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  bool _uploading = false;
  double _uploadProgress = 0;
  MatchDetailData? _detail;
  bool _loadingDetail = false;

  Match get m => widget.match;
  bool get isHome => m.localInscriptionId == _kMyInscriptionId;

  @override
  void initState() {
    super.initState();
    if (m.tournamentMatchId != 0) {
      _fetchDetail();
    }
  }

  Future<void> _fetchDetail() async {
    if (!mounted) return;
    setState(() => _loadingDetail = true);
    try {
      final detail = await ApiService.fetchMatchDetail(m.tournamentMatchId);
      if (mounted) setState(() => _detail = detail);
    } catch (_) {
      // silently ignore errors
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final played = m.hasResult;
    final us    = isHome ? m.scoreLocal    : m.scoreVisitor;
    final them  = isHome ? m.scoreVisitor  : m.scoreLocal;

    Color resultColor = _kBorder;
    if (played && us != null && them != null) {
      if (us > them)       resultColor = _kGreen;
      else if (us < them)  resultColor = _kRed;
      else                 resultColor = _kYellow;
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          m.fechaLabel ?? 'Partido',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          AuthService.isAdmin
              ? IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  tooltip: 'Cerrar sesión admin',
                  onPressed: () async {
                    await AuthService.signOut();
                    if (mounted) setState(() {});
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.admin_panel_settings, size: 20),
                  tooltip: 'Acceso admin',
                  onPressed: _showLoginDialog,
                ),
        ],
      ),
      floatingActionButton: AuthService.isAdmin
          ? FloatingActionButton(
              backgroundColor: _kBlue,
              onPressed: _uploading ? null : _showUploadOptions,
              child: _uploading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        value: _uploadProgress > 0 ? _uploadProgress : null,
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_photo_alternate, color: Colors.white),
            )
          : null,
      body: _buildScrollBody(resultColor, played),
    );
  }

  Widget _buildScrollBody(Color resultColor, bool played) {
    return StreamBuilder<List<MatchMedia>>(
      stream: MediaService.watchMatchMedia(m.id.toString()),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildMatchHeader(resultColor, played)),
            SliverToBoxAdapter(child: _buildDetailSectionContent()),
            if (loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: _kBlue)),
                ),
              )
            else if (items.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.photo_library_outlined, size: 64, color: _kMuted),
                      const SizedBox(height: 16),
                      Text(
                        'No hay fotos ni videos aún.\n¡Sé el primero en agregar!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _kMuted, fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 13, color: _kMuted),
                      const SizedBox(width: 6),
                      const Text('Fotos del partido',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _kSurface2, borderRadius: BorderRadius.circular(10)),
                        child: Text('${items.length}', style: const TextStyle(color: _kMuted, fontSize: 10)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildMediaTile(items, index),
                    childCount: items.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDetailSectionContent() {
    if (m.tournamentMatchId == 0) return const SizedBox.shrink();
    if (_loadingDetail) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kMuted),
            ),
            const SizedBox(width: 8),
            Text('Cargando info...', style: TextStyle(color: _kMuted, fontSize: 12)),
          ],
        ),
      );
    }
    final d = _detail;
    if (d == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMatchInfoRow(d),
          if (_hasGoals(d)) _buildGoalsSection(d),
          if (_hasCards(d)) _buildCardsSection(d),
          if (m.spreadsheetPhotos.isNotEmpty) _buildSpreadsheetPhotos(),
        ],
      ),
    );
  }

  bool _hasGoals(MatchDetailData d) =>
      d.goalsHome.isNotEmpty || d.goalsAway.isNotEmpty;

  bool _hasRefereeReport() =>
      m.fieldState != null || m.payment != null || m.refereeClothing != null;

  bool _hasCards(MatchDetailData d) =>
      d.yellowCardsHome.isNotEmpty ||
      d.yellowCardsAway.isNotEmpty ||
      d.redCardsHome.isNotEmpty ||
      d.redCardsAway.isNotEmpty ||
      d.doubleYellowCardsHome.isNotEmpty ||
      d.doubleYellowCardsAway.isNotEmpty;

  // ── Reusable section card ────────────────────────────────────────────────
  Widget _sectionCard({required String title, required IconData icon, required Widget content}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(children: [
              Icon(icon, size: 14, color: _kMuted),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
          const Divider(height: 16, thickness: 1, color: _kBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: content,
          ),
        ],
      ),
    );
  }

  // ── Info chip (small pill with icon + label) ──────────────────────────────
  Widget _infoChip(IconData icon, String label, {Color? color}) {
    final c = color ?? _kMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        border: Border.all(color: c.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildMatchInfoRow(MatchDetailData d) {
    Color chipColor = _kSurface2;
    if (d.status != null && d.statusColor != null) {
      final hex = d.statusColor!.replaceAll('#', '');
      try { chipColor = Color(int.parse('FF$hex', radix: 16)); } catch (_) {}
    }

    String? refName;
    if (d.referees.isNotEmpty) {
      final ref = d.referees.first;
      final n = '${ref['name'] ?? ''} ${ref['lastName'] ?? ''}'.trim();
      if (n.isNotEmpty) refName = n;
    }

    final hasAny = d.status != null || d.venueName != null || refName != null;
    if (!hasAny) return const SizedBox.shrink();

    return _sectionCard(
      title: 'Información del partido',
      icon: Icons.info_outline,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.status != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: chipColor.withOpacity(0.18),
                border: Border.all(color: chipColor.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(d.status!,
                  style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
          ],
          if (d.venueName != null) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.place_outlined, size: 13, color: _kMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.venueName!,
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                  if (d.venueAddress != null)
                    Text(d.venueAddress!,
                        style: TextStyle(color: _kMuted, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
          ],
          if (refName != null) ...[
            Row(children: [
              Icon(Icons.sports_outlined, size: 13, color: _kMuted),
              const SizedBox(width: 6),
              Text('Árbitro: ', style: TextStyle(color: _kMuted, fontSize: 12)),
              Expanded(
                child: Text(refName,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ],
          if (_hasRefereeReport()) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (m.fieldState != null)
                _infoChip(Icons.grass_outlined, 'Campo: ${_capitalize(m.fieldState!)}'),
              if (m.payment != null)
                _infoChip(
                  m.payment == 'efectuado' ? Icons.check_circle_outline : Icons.cancel_outlined,
                  m.payment == 'efectuado' ? 'Pagado' : 'Sin pagar',
                  color: m.payment == 'efectuado' ? _kGreen : _kRed,
                ),
              if (m.refereeClothing != null)
                _infoChip(Icons.checkroom_outlined, _capitalize(m.refereeClothing!)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalsSection(MatchDetailData d) {
    final homeName = (m.localName ?? 'Local').split(' ').take(2).join(' ');
    final awayName = (m.visitorName ?? 'Visitante').split(' ').take(2).join(' ');
    return _sectionCard(
      title: 'Goles',
      icon: Icons.sports_soccer,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildGoalsList(d.goalsHome, homeName)),
          Container(width: 1, color: _kBorder, margin: const EdgeInsets.symmetric(horizontal: 8)),
          Expanded(child: _buildGoalsList(d.goalsAway, awayName)),
        ],
      ),
    );
  }

  Widget _buildGoalsList(List<MatchGoalEvent> goals, String teamName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(teamName,
            style: TextStyle(color: _kBlue, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        if (goals.isEmpty)
          Text('—', style: TextStyle(color: _kMuted, fontSize: 12))
        else
          ...goals.map((g) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('⚽', style: const TextStyle(fontSize: 10)),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  g.goals > 1 ? '${g.playerName} (${g.goals})' : g.playerName,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ]),
          )),
      ],
    );
  }

  Widget _cardBadge({bool yellow = false, bool red = false, bool doubleYellow = false}) {
    if (doubleYellow) {
      return SizedBox(
        width: 22, height: 16,
        child: Stack(children: [
          Positioned(left: 0, child: _singleCard(const Color(0xFFD4A017))),
          Positioned(left: 8, child: _singleCard(_kRed)),
        ]),
      );
    }
    return _singleCard(yellow ? const Color(0xFFD4A017) : _kRed);
  }

  Widget _singleCard(Color color) => Container(
    width: 12, height: 16,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
  );

  Widget _buildCardsSection(MatchDetailData d) {
    final hasYellow = d.yellowCardsHome.isNotEmpty || d.yellowCardsAway.isNotEmpty;
    final hasDoubleYellow = d.doubleYellowCardsHome.isNotEmpty || d.doubleYellowCardsAway.isNotEmpty;
    final hasRed = d.redCardsHome.isNotEmpty || d.redCardsAway.isNotEmpty;
    final homeName = (m.localName ?? 'Local').split(' ').take(2).join(' ');
    final awayName = (m.visitorName ?? 'Visitante').split(' ').take(2).join(' ');

    return _sectionCard(
      title: 'Tarjetas',
      icon: Icons.style_outlined,
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SizedBox(width: 26),
          Expanded(child: Text(homeName,
              style: TextStyle(color: _kBlue, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3),
              overflow: TextOverflow.ellipsis)),
          Container(width: 1, color: _kBorder, margin: const EdgeInsets.symmetric(horizontal: 8)),
          Expanded(child: Text(awayName,
              style: TextStyle(color: _kBlue, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3),
              overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        if (hasYellow) _buildCardRow(d.yellowCardsHome, d.yellowCardsAway, yellow: true),
        if (hasDoubleYellow) _buildCardRow(d.doubleYellowCardsHome, d.doubleYellowCardsAway, doubleYellow: true),
        if (hasRed) _buildCardRow(d.redCardsHome, d.redCardsAway, red: true),
      ]),
    );
  }

  Widget _buildCardRow(List<MatchCardEvent> home, List<MatchCardEvent> away,
      {bool yellow = false, bool red = false, bool doubleYellow = false}) {
    Widget playerList(List<MatchCardEvent> list) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: list.isEmpty
          ? [Text('—', style: TextStyle(color: _kMuted, fontSize: 12))]
          : list.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(c.playerName, style: const TextStyle(color: Colors.white, fontSize: 12)),
          )).toList(),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 26,
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: _cardBadge(yellow: yellow, red: red, doubleYellow: doubleYellow),
          ),
        ),
        Expanded(child: playerList(home)),
        Container(width: 1, color: _kBorder, margin: const EdgeInsets.symmetric(horizontal: 8)),
        Expanded(child: playerList(away)),
      ]),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _buildSpreadsheetPhotos() {
    return _sectionCard(
      title: 'Planilla',
      icon: Icons.assignment_outlined,
      content: SizedBox(
        height: 130,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: m.spreadsheetPhotos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) => CdnImage(
            url: m.spreadsheetPhotos[i],
            width: 130,
            height: 130,
            fit: BoxFit.cover,
            onTap: () => _openSpreadsheetViewer(i),
          ),
        ),
      ),
    );
  }

  void _openSpreadsheetViewer(int initialIndex) {
    final items = m.spreadsheetPhotos
        .map((url) => MatchMedia(id: url, matchId: m.id.toString(), url: url, type: MediaType.image, uploadedAt: DateTime.now()))
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _MediaViewerScreen(items: items, initialIndex: initialIndex),
      ),
    );
  }

  Future<void> _showLoginDialog() async {
    final emailCtrl    = TextEditingController();
    final passwordCtrl = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _kSurface,
          title: const Text('Acceso admin',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: _kMuted),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: _kBorder)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: _kBlue)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle: TextStyle(color: _kMuted),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: _kBorder)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: _kBlue)),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: _kRed, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            TextButton(
              child: const Text('Entrar',
                  style: TextStyle(color: _kBlue)),
              onPressed: () async {
                final err = await AuthService.signIn(
                    emailCtrl.text, passwordCtrl.text);
                if (err == null) {
                  Navigator.pop(ctx);
                  if (mounted) setState(() {});
                } else {
                  setDialogState(() => error = err);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamColumn(String? logoUrl, String? name, bool us, CrossAxisAlignment align) {
    return Expanded(
      child: Column(
        children: [
          if (logoUrl != null) ...[
            TeamLogo(logoUrl: logoUrl, name: name ?? '', isUs: us, size: 48, fontSize: 14),
            if (us)
              Container(
                width: 20, height: 3, margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(2)),
              ),
            const SizedBox(height: 6),
          ],
          Text(
            name ?? '—',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: us ? _kBlue : Colors.white,
              fontWeight: us ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchHeader(Color resultColor, bool played) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (played ? resultColor : _kBorder).withOpacity(0.18),
            _kSurface,
          ],
          stops: const [0.0, 0.45],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _teamColumn(m.localLogo, m.localName, isHome, CrossAxisAlignment.end),
          // Score / vs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: played
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${m.scoreLocal}',
                          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('-', style: TextStyle(color: _kMuted, fontSize: 26, fontWeight: FontWeight.w300)),
                      ),
                      Text('${m.scoreVisitor}',
                          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('vs', style: TextStyle(color: _kMuted, fontSize: 16, fontWeight: FontWeight.w300)),
                      if (m.date != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_formatDate(m.date!, m.time),
                              style: TextStyle(color: _kMuted, fontSize: 11)),
                        ),
                    ],
                  ),
          ),
          _teamColumn(m.visitorLogo, m.visitorName, !isHome, CrossAxisAlignment.start),
        ],
      ),
    );
  }

  Widget _buildMediaTile(List<MatchMedia> items, int index) {
    final item = items[index];
    if (item.type == MediaType.image) {
      return LayoutBuilder(
        builder: (context, constraints) => CdnImage(
          url: item.url,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          fit: BoxFit.cover,
          onTap: () => _openViewer(items, index),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _openViewer(items, index),
      onLongPress: AuthService.isAdmin ? () => _showDeleteDialog(item) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          color: _kSurface2,
          child: const Center(
            child: Icon(Icons.play_circle_filled, color: Colors.white, size: 40),
          ),
        ),
      ),
    );
  }

  void _openViewer(List<MatchMedia> items, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            _MediaViewerScreen(items: items, initialIndex: initialIndex),
      ),
    );
  }

  Future<void> _showDeleteDialog(MatchMedia item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        title: const Text('Eliminar',
            style: TextStyle(color: Colors.white)),
        content: const Text('¿Eliminar este contenido?',
            style: TextStyle(color: _kMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await MediaService.deleteMedia(item);
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.white),
              title: const Text('Tomar foto',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.camera, MediaType.image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white),
              title: const Text('Grabar video',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.camera, MediaType.video);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Foto de galería',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.gallery, MediaType.image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.white),
              title: const Text('Video de galería',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.gallery, MediaType.video);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source, MediaType type) async {
    final picker = ImagePicker();
    XFile? picked;
    if (type == MediaType.image) {
      picked = await picker.pickImage(source: source, imageQuality: 80);
    } else {
      picked = await picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 5));
    }
    if (picked == null || !mounted) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });
    try {
      await MediaService.uploadMedia(
        m.id.toString(),
        File(picked.path),
        type,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al subir el archivo. Intentá de nuevo.'),
              backgroundColor: _kRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  String _formatDate(String date, String? time) {
    try {
      final p = date.split('-');
      final d = '${p[2]}/${p[1]}';
      return time != null ? '$d $time' : d;
    } catch (_) {
      return date;
    }
  }
}

// ─── Media Viewer ──────────────────────────────────────────────────────────────

class _MediaViewerScreen extends StatefulWidget {
  final List<MatchMedia> items;
  final int initialIndex;

  const _MediaViewerScreen(
      {required this.items, required this.initialIndex});

  @override
  State<_MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<_MediaViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.items.length}',
          style: const TextStyle(fontSize: 14, color: _kMuted),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          if (item.type == MediaType.image) {
            final size = MediaQuery.of(context).size;
            return Center(
              child: CdnImage(
                url: item.url,
                width: size.width,
                height: size.height,
                fit: BoxFit.contain,
              ),
            );
          } else {
            return _VideoPlayerWidget(url: item.url);
          }
        },
      ),
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String url;
  const _VideoPlayerWidget({required this.url});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    return GestureDetector(
      onTap: () => setState(() {
        _controller.value.isPlaying
            ? _controller.pause()
            : _controller.play();
      }),
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),
              if (!_controller.value.isPlaying)
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 52),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
