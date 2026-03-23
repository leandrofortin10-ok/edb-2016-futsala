// Generado para el proyecto Firebase: edb-estrella
// Para regenerar: flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
            'Plataforma no soportada: $defaultTargetPlatform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCnCLB7glTXLw_xvAD30oayZflG_gnDTEk',
    appId: '1:259850372896:web:12c891d2eb82e1b097f945',
    messagingSenderId: '259850372896',
    projectId: 'edb-estrella',
    storageBucket: 'edb-estrella.firebasestorage.app',
    authDomain: 'edb-estrella.firebaseapp.com',
    measurementId: 'G-Y5F9MG8BH7',
  );

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
