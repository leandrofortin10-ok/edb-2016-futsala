import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../models/match_media.dart';
import '../services/media_service.dart';
import '../services/auth_service.dart';

const _kBlue    = Color(0xFF388bfd);
const _kBg      = Color(0xFF0d1117);
const _kSurface = Color(0xFF161b22);
const _kSurface2 = Color(0xFF21262d);
const _kBorder  = Color(0xFF30363d);
const _kMuted   = Color(0xFF8b949e);
const _kGreen   = Color(0xFF3fb950);
const _kRed     = Color(0xFFf85149);
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

  Match get m => widget.match;
  bool get isHome => m.localInscriptionId == _kMyInscriptionId;

  @override
  Widget build(BuildContext context) {
    final played = m.hasResult;
    final us    = isHome ? m.scoreLocal    : m.scoreVisitor;
    final them  = isHome ? m.scoreVisitor  : m.scoreLocal;

    Color resultColor = _kBorder;
    if (played && us != null && them != null) {
      if (us > them)       resultColor = _kGreen;
      else if (us < them)  resultColor = _kRed;
      else                 resultColor = const Color(0xFFd29922);
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
      body: Column(
        children: [
          _buildMatchHeader(resultColor, played),
          Expanded(child: _buildMediaGrid()),
        ],
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

  Widget _buildMatchHeader(Color resultColor, bool played) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
              color: played ? resultColor : _kBorder, width: played ? 3 : 1),
          top:    const BorderSide(color: _kBorder),
          right:  const BorderSide(color: _kBorder),
          bottom: const BorderSide(color: _kBorder),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              m.localName ?? '—',
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isHome ? _kBlue : Colors.white,
                fontWeight: isHome ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: played
                ? Text(
                    '${m.scoreLocal}  –  ${m.scoreVisitor}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('vs',
                          style: TextStyle(color: _kMuted, fontSize: 14)),
                      if (m.date != null)
                        Text(
                          _formatDate(m.date!, m.time),
                          style: TextStyle(color: _kMuted, fontSize: 11),
                        ),
                    ],
                  ),
          ),
          Expanded(
            child: Text(
              m.visitorName ?? '—',
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: !isHome ? _kBlue : Colors.white,
                fontWeight: !isHome ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid() {
    return StreamBuilder<List<MatchMedia>>(
      stream: MediaService.watchMatchMedia(m.id.toString()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kBlue));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: _kRed)),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) =>
              _buildMediaTile(items, index),
        );
      },
    );
  }

  Widget _buildMediaTile(List<MatchMedia> items, int index) {
    final item = items[index];
    return GestureDetector(
      onTap: () => _openViewer(items, index),
      onLongPress: AuthService.isAdmin ? () => _showDeleteDialog(item) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: item.type == MediaType.image
            ? CachedNetworkImage(
                imageUrl: item.url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: _kSurface2,
                  child: const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kBlue)),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: _kSurface2,
                  child: const Icon(Icons.broken_image, color: _kMuted),
                ),
              )
            : Container(
                color: _kSurface2,
                child: const Center(
                  child: Icon(Icons.play_circle_filled,
                      color: Colors.white, size: 40),
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
          SnackBar(
              content: Text('Error al subir: $e'),
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
            return InteractiveViewer(
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: item.url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white)),
                  errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 64),
                ),
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
