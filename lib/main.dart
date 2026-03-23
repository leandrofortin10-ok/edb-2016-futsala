import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/notifications.dart';
import 'services/background_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initNotifications();
  await seedTestStateOnce();
  await initBackgroundSync();
  runApp(const EstrellaApp());
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
      home: const HomeScreen(),
    );
  }
}
