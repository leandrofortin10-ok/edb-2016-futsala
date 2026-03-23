import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const _kSurface2 = Color(0xFF21262d);
const _kBlue = Color(0xFF388bfd);
const _kMuted = Color(0xFF8b949e);

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
    final img = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => Container(
          width: width, height: height,
          color: _kSurface2,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)),
        ),
        errorWidget: (_, __, ___) => Container(
          width: width, height: height,
          color: _kSurface2,
          child: const Icon(Icons.broken_image, color: _kMuted),
        ),
      ),
    );
    if (onTap != null) return GestureDetector(onTap: onTap, child: img);
    return img;
  }
}
