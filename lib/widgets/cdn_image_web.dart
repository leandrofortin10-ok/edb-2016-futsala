// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

const _kSurface2 = Color(0xFF21262d);
const _kMuted = Color(0xFF8b949e);

final _registered = <String>{};
final _callbacks = <String, VoidCallback?>{};


class CdnImage extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final VoidCallback? onTap;

  const CdnImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final viewId = 'cdnimg-${url.hashCode.abs()}';

    // Always keep the callback up to date so rebuilds are reflected.
    _callbacks[viewId] = onTap;

    if (!_registered.contains(viewId)) {
      _registered.add(viewId);
      final imgUrl = url;
      final fitStr = fit == BoxFit.contain ? 'contain' : 'cover';
      ui_web.platformViewRegistry.registerViewFactory(viewId, (_) {
        final img = html.ImageElement()
          ..src = imgUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = fitStr
          ..style.display = 'block'
          ..style.borderRadius = '6px';

        img.onError.listen((_) {
          img.style.display = 'none';
          img.parent?.children.add(html.SpanElement()
            ..style.color = '#8b949e'
            ..style.fontSize = '24px'
            ..text = '🖼');
        });

        // HtmlElementView intercepts pointer events, so GestureDetector won't
        // fire. Wire taps directly on the native element instead.
        img.onClick.listen((_) => _callbacks[viewId]?.call());
        img.style.cursor = 'pointer';

        return img;
      });
    }

    return SizedBox(
      width: width,
      height: height,
      child: HtmlElementView(viewType: viewId),
    );
  }
}
