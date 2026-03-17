import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherInfo {
  final double temperature;
  final int code;
  WeatherInfo(this.temperature, this.code);

  String get emoji {
    if (code == 0)                  return '☀️';
    if (code <= 2)                  return '🌤️';
    if (code == 3)                  return '☁️';
    if (code <= 48)                 return '🌫️';
    if (code <= 55)                 return '🌦️';
    if (code <= 67)                 return '🌧️';
    if (code <= 77)                 return '❄️';
    if (code <= 82)                 return '🌧️';
    return '⛈️';
  }

  String get description {
    if (code == 0)           return 'Despejado';
    if (code == 1)           return 'Mayormente despejado';
    if (code == 2)           return 'Parcialmente nublado';
    if (code == 3)           return 'Nublado';
    if (code <= 48)          return 'Niebla';
    if (code <= 55)          return 'Llovizna';
    if (code <= 65)          return 'Lluvia';
    if (code <= 67)          return 'Lluvia helada';
    if (code <= 77)          return 'Nieve';
    if (code <= 82)          return 'Chaparrones';
    return 'Tormenta';
  }

  int get tempRounded => temperature.round();
}

class WeatherService {
  static const _lat = -34.6037;
  static const _lon = -58.3816;

  /// Returns forecast for a specific date and hour in Buenos Aires.
  /// [date] format: 'YYYY-MM-DD', [time] format: 'HH:MM' (nullable → uses noon).
  static Future<WeatherInfo?> getForecast(String date, String? time) async {
    try {
      final hour = int.tryParse(time?.split(':').first ?? '12') ?? 12;
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$_lat&longitude=$_lon'
        '&hourly=temperature_2m,weathercode'
        '&timezone=America%2FArgentina%2FBuenos_Aires'
        '&start_date=$date&end_date=$date',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final body    = jsonDecode(res.body) as Map<String, dynamic>;
      final hourly  = body['hourly'] as Map<String, dynamic>;
      final times   = (hourly['time'] as List).cast<String>();
      final temps   = (hourly['temperature_2m'] as List).cast<num>();
      final codes   = (hourly['weathercode'] as List).cast<int>();

      // Find the index matching the target hour
      final target  = '${date}T${hour.toString().padLeft(2, '0')}:00';
      final idx     = times.indexOf(target);
      if (idx < 0) return null;

      return WeatherInfo(temps[idx].toDouble(), codes[idx]);
    } catch (_) {
      return null;
    }
  }
}
