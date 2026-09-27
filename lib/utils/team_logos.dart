import 'team_logos.g.dart';

// Escudos empaquetados como assets (ver scripts/fetch_team_logos.ps1).
// cdn.weball.me no envía CORS, así que en web no se pueden dibujar con Image.network.

const _accents = {'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N'};

/// Misma normalización que Get-LogoKey en el script: mayúsculas, sin acentos, [A-Z0-9_].
String teamLogoKey(String name) {
  final upper = name.trim().toUpperCase().split('').map((c) => _accents[c] ?? c).join();
  return upper
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Ruta del asset del escudo, o null si no está empaquetado.
String? teamLogoAsset(String name) {
  final key = teamLogoKey(name);
  return teamLogoKeys.contains(key) ? 'assets/logos/$key.png' : null;
}
