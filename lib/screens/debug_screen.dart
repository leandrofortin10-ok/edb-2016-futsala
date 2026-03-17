import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/debug_overrides.dart';

const _kBg      = Color(0xFF0d1117);
const _kSurface = Color(0xFF161b22);
const _kBorder  = Color(0xFF30363d);
const _kBlue    = Color(0xFF388bfd);
const _kMuted   = Color(0xFF8b949e);
const _kYellow  = Color(0xFFd29922);

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});
  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final _dateCtrl   = TextEditingController(text: DebugOverrides.nextMatchDate    ?? '');
  final _timeCtrl   = TextEditingController(text: DebugOverrides.nextMatchTime    ?? '');
  final _rivalCtrl  = TextEditingController(text: DebugOverrides.fixtureRivalName ?? '');
  final _posCtrl    = TextEditingController(text: DebugOverrides.myTablePosition?.toString() ?? '');
  final _playerCtrl = TextEditingController(text: DebugOverrides.firstPlayerName  ?? '');

  @override
  void dispose() {
    _dateCtrl.dispose(); _timeCtrl.dispose();
    _rivalCtrl.dispose(); _posCtrl.dispose(); _playerCtrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final prefs = await SharedPreferences.getInstance();

    // ── 1. Fecha/hora del próximo partido ────────────────────────────────────
    DebugOverrides.nextMatchDate = _dateCtrl.text.trim().isEmpty ? null : _dateCtrl.text.trim();
    DebugOverrides.nextMatchTime = _timeCtrl.text.trim().isEmpty ? null : _timeCtrl.text.trim();

    // Guardar en SP: actualizar el primer partido sin resultado
    final matchesJson = prefs.getString('last_matches') ?? '[]';
    final matchList   = (jsonDecode(matchesJson) as List).cast<Map<String, dynamic>>().toList();
    final matchIdx    = matchList.indexWhere((m) => m['hasResult'] == false);
    if (matchIdx >= 0) {
      matchList[matchIdx] = {
        ...matchList[matchIdx],
        'date': DebugOverrides.nextMatchDate,
        'time': DebugOverrides.nextMatchTime,
      };
      await prefs.setString('last_matches', jsonEncode(matchList));
    }

    // ── 2. Rival del segundo partido en fixture ───────────────────────────────
    DebugOverrides.fixtureRivalName = _rivalCtrl.text.trim().isEmpty ? null : _rivalCtrl.text.trim();

    // Guardar en SP: actualizar rivalName del segundo partido (índice 1)
    if (DebugOverrides.fixtureRivalName != null && matchList.length > 1) {
      // Re-leer por si cambió en el paso anterior
      final fresh = (jsonDecode(prefs.getString('last_matches') ?? '[]') as List)
          .cast<Map<String, dynamic>>().toList();
      fresh[1] = {...fresh[1], 'rivalName': DebugOverrides.fixtureRivalName};
      await prefs.setString('last_matches', jsonEncode(fresh));
    }

    // ── 3. Posición en tabla (UI + SP para notificación) ─────────────────────
    final pos = int.tryParse(_posCtrl.text.trim());
    DebugOverrides.myTablePosition = pos;
    if (pos != null && pos > 0) {
      await prefs.setInt('last_position', pos);
    }

    // ── 4. Nombre del primer jugador (UI + modifica SP para notificación) ────
    DebugOverrides.firstPlayerName = _playerCtrl.text.trim().isEmpty ? null : _playerCtrl.text.trim();
    if (DebugOverrides.firstPlayerName != null) {
      // Cambiar el nombre del primer jugador en last_players
      final savedJson = prefs.getString('last_players');
      if (savedJson != null) {
        final list = (jsonDecode(savedJson) as List).cast<String>();
        if (list.isNotEmpty) {
          list[0] = DebugOverrides.firstPlayerName!;
          await prefs.setString('last_players', jsonEncode(list));
        }
      }
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        foregroundColor: Colors.white,
        title: const Text('Valores de prueba', style: TextStyle(fontSize: 15)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hint('Cada campo modifica los datos mostrados en la app '
                'Y guarda el estado en caché. Al hacer refresh, la app '
                'detecta la diferencia con la API real y dispara la notificación correspondiente.'),
            const SizedBox(height: 20),

            _label('📅 Próximo partido — fecha y hora'),
            _card([
              _row([
                _field('Fecha (YYYY-MM-DD)', _dateCtrl, hint: 'Ej: 2025-06-15'),
                const SizedBox(width: 10),
                _field('Hora', _timeCtrl, hint: 'Ej: 20:30', flex: 1),
              ]),
            ]),
            const SizedBox(height: 14),

            _label('🏟️ Fixture — rival del segundo partido'),
            _card([
              _field('Nombre del rival', _rivalCtrl, hint: 'Ej: Los Primos FC'),
            ]),
            const SizedBox(height: 14),

            _label('📊 Tabla de posiciones — posición de Estrella'),
            _card([
              _field('Posición', _posCtrl,
                  hint: 'Ej: 3  → muestra en puesto 3 y notifica al refrescar',
                  keyboard: TextInputType.number),
            ]),
            const SizedBox(height: 14),

            _label('👤 Plantel'),
            _card([
              _field('Cambiar nombre del primer jugador', _playerCtrl, hint: 'Ej: Lionel Messi'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _actionBtn('+ Agregar jugador falso', () async {
                  const fakeName = 'Debug Player FC';
                  DebugOverrides.extraPlayer = fakeName;
                  final prefs = await SharedPreferences.getInstance();
                  final saved = prefs.getString('last_players');
                  if (saved != null) {
                    final list = (jsonDecode(saved) as List).cast<String>();
                    list.add(fakeName);
                    await prefs.setString('last_players', jsonEncode(list));
                  }
                })),
                const SizedBox(width: 8),
                Expanded(child: _actionBtn('− Eliminar primer jugador', () async {
                  final prefs = await SharedPreferences.getInstance();
                  final saved = prefs.getString('last_players');
                  if (saved != null) {
                    final list = (jsonDecode(saved) as List).cast<String>();
                    if (list.isNotEmpty) {
                      list.removeAt(0);
                      await prefs.setString('last_players', jsonEncode(list));
                    }
                  }
                })),
              ]),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Agregar: en el refresh detecta que "Debug Player FC" ya no está → notifica salida.\n'
                  'Eliminar: en el refresh detecta que volvió el jugador real → notifica ingreso.',
                  style: TextStyle(color: Color(0xFF8b949e), fontSize: 10, height: 1.4),
                ),
              ),
            ]),
            const SizedBox(height: 28),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue.withOpacity(0.2),
                  foregroundColor: _kBlue,
                  side: BorderSide(color: _kBlue.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Aplicar y volver a la app',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _hint(String text) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _kYellow.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kYellow.withOpacity(0.3)),
    ),
    child: Text(text, style: const TextStyle(color: _kYellow, fontSize: 12, height: 1.5)),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(
        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
  );

  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _kBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );

  Widget _row(List<Widget> children) => Row(children: children);

  Widget _actionBtn(String label, Future<void> Function() onTap) => SizedBox(
    height: 36,
    child: ElevatedButton(
      onPressed: () async {
        await onTap();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(label), duration: const Duration(seconds: 1),
              backgroundColor: const Color(0xFF21262d)));
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF21262d),
        foregroundColor: const Color(0xFF8b949e),
        side: const BorderSide(color: Color(0xFF30363d)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    ),
  );

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, TextInputType? keyboard, int flex = 2}) =>
    Expanded(
      flex: flex,
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: _kMuted, fontSize: 11),
          hintStyle: const TextStyle(color: _kMuted, fontSize: 11),
          filled: true, fillColor: _kBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _kBlue.withOpacity(0.8))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
}
