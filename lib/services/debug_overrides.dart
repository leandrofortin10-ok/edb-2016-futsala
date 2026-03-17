/// In-memory overrides injected from the debug screen.
/// HomeScreen reads these when rendering and clears them after a real API load.
class DebugOverrides {
  // Próximo partido / Fixture (primer partido sin resultado)
  static String? nextMatchDate;  // 'YYYY-MM-DD'
  static String? nextMatchTime;  // 'HH:MM'

  // Fixture: nombre del rival del segundo partido (índice 1)
  static String? fixtureRivalName;

  // Tabla de posiciones: posición visual de Estrella (1-based)
  static int? myTablePosition;

  // Plantel: nombre del primer jugador y jugador extra a mostrar
  static String? firstPlayerName;
  static String? extraPlayer;

  static bool get hasAny =>
      nextMatchDate != null ||
      nextMatchTime != null ||
      fixtureRivalName != null ||
      myTablePosition != null ||
      firstPlayerName != null ||
      extraPlayer != null;

  static void clear() {
    nextMatchDate    = null;
    nextMatchTime    = null;
    fixtureRivalName = null;
    myTablePosition  = null;
    firstPlayerName  = null;
    extraPlayer      = null;
  }
}
