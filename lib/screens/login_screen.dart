import 'package:flutter/material.dart';
import '../services/auth_service.dart';

const _kBlue    = Color(0xFF388bfd);
const _kBg      = Color(0xFF0d1117);
const _kSurface = Color(0xFF161b22);
const _kBorder  = Color(0xFF30363d);
const _kMuted   = Color(0xFF8b949e);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;
  int _failedAttempts = 0;
  DateTime? _blockedUntil;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_blockedUntil != null && DateTime.now().isBefore(_blockedUntil!)) {
      final secs = _blockedUntil!.difference(DateTime.now()).inSeconds + 1;
      setState(() => _error = 'Demasiados intentos. Esperá $secs segundos.');
      return;
    }
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Completá los dos campos');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final err = await AuthService.signIn(email, password);
    if (err != null) {
      _failedAttempts++;
      if (_failedAttempts >= 3) {
        final seconds = (30 * (1 << (_failedAttempts - 3))).clamp(30, 300);
        _blockedUntil = DateTime.now().add(Duration(seconds: seconds));
      }
    } else {
      _failedAttempts = 0;
      _blockedUntil = null;
    }
    if (mounted) setState(() { _loading = false; _error = err; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⭐', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text('Estrella de Boedo',
                style: TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Torneo Joma · Futsala BA',
                style: TextStyle(color: _kMuted, fontSize: 13)),
              const SizedBox(height: 40),
              _field(_emailCtrl, 'Email', Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _field(_passwordCtrl, 'Contraseña', Icons.lock_outline,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                        color: _kMuted, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf85149).withOpacity(0.1),
                    border: Border.all(color: const Color(0xFFf85149).withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFf85149), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                          style: const TextStyle(color: Color(0xFFf85149), fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _kBlue.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Ingresar',
                          style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {bool obscure = false,
      TextInputType? keyboardType,
      Widget? suffix}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kMuted),
        prefixIcon: Icon(icon, color: _kMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _kSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBlue),
        ),
      ),
      onSubmitted: (_) => _submit(),
    );
  }
}
