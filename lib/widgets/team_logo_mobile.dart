import 'package:flutter/material.dart';

const _kBlue    = Color(0xFF388bfd);
const _kBorder  = Color(0xFF30363d);
const _kSurface2 = Color(0xFF21262d);
const _kMuted   = Color(0xFF8b949e);

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
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: _kSurface2,
        shape: BoxShape.circle,
        border: Border.all(
            color: isUs ? _kBlue : _kBorder, width: isUs ? 2 : 1),
      ),
      child: ClipOval(
        child: logoUrl != null
            ? Image.network(logoUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initials())
            : _initials(),
      ),
    );
  }

  Widget _initials() => Center(
    child: Text(_abbrev(name),
      style: TextStyle(
        color: isUs ? _kBlue : _kMuted,
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
      )),
  );

  static String _abbrev(String name) {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
