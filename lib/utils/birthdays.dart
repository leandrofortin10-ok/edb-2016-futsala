const bdMonthNames = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

const birthdays = <String, (int, int)>{
  'DEL BAO':    (1, 25),  // Camilo – 25 ene
  'SASSANO':    (4, 5),   // Gian – 5 abr
  'CERMELLI':   (4, 8),   // Noah – 8 abr
  'VENEGAS':    (5, 17),  // Gio – 17 may
  'MIGLIO':     (6, 25),  // Franco – 25 jun
  'OLMO':       (8, 7),   // Agustín – 7 ago
  'STAMBULSKY': (8, 24),  // Gonzalo/Pipi – 24 ago
  'GAMON':      (8, 25),  // Uri – 25 ago
  'FLEITAS':    (9, 20),  // Tatu – 20 sep
};

/// Devuelve el cumpleaños (mes, día) del jugador con ese apellido, o null.
(int, int)? birthdayForLastName(String lastName) {
  final ln = lastName.toUpperCase().trim();
  for (final entry in birthdays.entries) {
    if (ln.contains(entry.key) || entry.key.contains(ln)) {
      return entry.value;
    }
  }
  return null;
}
