// Generado para el proyecto Firebase: edb-estrella
// Para regenerar: flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web no soportado');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
            'Plataforma no soportada: $defaultTargetPlatform');
    }
  }

  // Valores del proyecto edb-estrella
  // (extraídos del google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAI99fb7Cv7DJaaeT5uEFbkpbrqhNSAMC4',
    appId: '1:259850372896:android:2d38728474913bec97f945',
    messagingSenderId: '259850372896',
    projectId: 'edb-estrella',
    storageBucket: 'edb-estrella.firebasestorage.app',
  );
}
