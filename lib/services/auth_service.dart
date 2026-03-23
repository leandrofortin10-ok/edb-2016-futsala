import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;
  static bool get isAdmin => _auth.currentUser != null;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      return null; // sin error
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'user-not-found'  => 'Usuario no encontrado',
        'wrong-password'  => 'Contraseña incorrecta',
        'invalid-email'   => 'Email inválido',
        'invalid-credential' => 'Credenciales incorrectas',
        _ => 'Error: ${e.message}',
      };
    }
  }

  static Future<void> signOut() => _auth.signOut();
}
