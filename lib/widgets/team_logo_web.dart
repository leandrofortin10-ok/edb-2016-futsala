// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

const _kBlue    = Color(0xFF388bfd);
const _kBorder  = Color(0xFF30363d);
const _kSurface2 = Color(0xFF21262d);
const _kMuted   = Color(0xFF8b949e);

final _registered = <String>{};

class TeamLogo extends StatelessWidget {
  final String? logoUrl;
  final String name;
  final bool isUs;
  final double size;
  final double fontSize;

  const TeamLogo({
    super.key,
    required this.logoUrl,
    required this.name,
    required this.isUs,
    required this.size,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null) {
      final borderColor = isUs ? '#388bfd' : '#30363d';
      final borderWidth = isUs ? '2px' : '1px';
      final viewId = 'tlogo-${logoUrl.hashCode.abs()}';

      if (!_registered.contains(viewId)) {
        _registered.add(viewId);
        final url = logoUrl!;
        final abbrev = _abbrev(name);
        final textColor = isUs ? '#388bfd' : '#8b949e';
        ui_web.platformViewRegistry.registerViewFactory(viewId, (_) {
          final div = html.DivElement()
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.borderRadius = '50%'
            ..style.overflow = 'hidden'
            ..style.border = '$borderWidth solid $borderColor'
            ..style.backgroundColor = '#21262d'
            ..style.boxSizing = 'border-box'
            ..style.position = 'relative'
            ..style.display = 'flex'
            ..style.alignItems = 'center'
            ..style.justifyContent = 'center';

          final fallback = html.SpanElement()
            ..text = abbrev
            ..style.color = textColor
            ..style.fontWeight = 'bold'
            ..style.fontSize = '${fontSize.toInt()}px'
            ..style.fontFamily = 'sans-serif'
            ..style.position = 'absolute';

          final img = html.ImageElement()
            ..src = url
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = 'cover'
            ..style.display = 'block'
            ..style.position = 'absolute'
            ..style.top = '0'
            ..style.left = '0';

          div.append(fallback);
          div.append(img);

          img.onError.listen((_) => img.style.display = 'none');
          img.onLoad.listen((_) => fallback.style.display = 'none');

          return div;
        });
      }

      return SizedBox(
        width: size,
        height: size,
        child: HtmlElementView(viewType: viewId),
      );
    }

    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: _kSurface2,
        shape: BoxShape.circle,
        border: Border.all(
            color: isUs ? _kBlue : _kBorder, width: isUs ? 2 : 1),
      ),
      child: Center(
        child: Text(_abbrev(name),
          style: TextStyle(
            color: isUs ? _kBlue : _kMuted,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          )),
      ),
    );
  }

  static String _abbrev(String name) {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
