import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/ai_config.dart';
import 'services/auth_service.dart';
import 'services/notifications.dart';
import 'services/background_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();
  await AuthService.initialize();
  await initNotifications();
  await initBackgroundSync();
  runApp(const EstrellaApp());
}

/// App Check (Fraud Defense / reCAPTCHA Enterprise, invisible) es requisito
/// del asistente con IA.
/// Si falla (por ejemplo, un navegador que bloquea reCAPTCHA) la app sigue
/// funcionando; solo el asistente no va a poder responder.
Future<void> _activateAppCheck() async {
  if (kRecaptchaSiteKey.isEmpty) return;
  try {
    await FirebaseAppCheck.instance
        .activate(providerWeb: ReCaptchaEnterpriseProvider(kRecaptchaSiteKey))
        .timeout(const Duration(seconds: 5));
  } catch (_) {}
}

class EstrellaApp extends StatelessWidget {
  const EstrellaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estrella de Boedo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1e83bd),
          primary: const Color(0xFF1e83bd),
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0d1117),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF388bfd)),
              ),
            );
          }
          if (snapshot.data == null) return const LoginScreen();
          return const HomeScreen();
        },
      ),
    );
  }
}
