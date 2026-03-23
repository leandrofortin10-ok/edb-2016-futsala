import 'package:firebase_auth/firebase_auth.dart';

// Fallback durante la transición: emails que se consideran admin
// aunque aún no tengan el custom claim seteado.
// Una vez ejecutado scripts/set_admin_claim.js, este fallback es irrelevante.
const _adminEmailFallback = <String>{
  'leandrofortin10@gmail.com',
};

class AuthService {
  static final _auth = FirebaseAuth.instance;

  // Cache sincrónico del custom claim.
  // Se actualiza en initialize(), signIn() y signOut().
  static bool _adminClaimed = false;

  /// Llamar una vez desde main() después de Firebase.initializeApp().
  static Future<void> initialize() async {
    await _refreshAdminCache(_auth.currentUser);
    _auth.authStateChanges().listen((user) async {
      await _refreshAdminCache(user);
    });
  }

  static Future<void> _refreshAdminCache(User? user) async {
    if (user == null) {
      _adminClaimed = false;
      return;
    }
    try {
      final result = await user.getIdTokenResult();
      _adminClaimed = result.claims?['admin'] == true;
    } catch (_) {
      _adminClaimed = false;
    }
  }

  static User? get currentUser => _auth.currentUser;

  /// Síncrono. True si el token tiene claim admin=true,
  /// o si el email está en el fallback (durante la transición).
  static bool get isAdmin {
    if (_adminClaimed) return true;
    final email = _auth.currentUser?.email;
    return email != null && _adminEmailFallback.contains(email.toLowerCase());
  }

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      await _refreshAdminCache(_auth.currentUser);
      return null;
    } on FirebaseAuthException catch (_) {
      return 'Email o contraseña incorrectos';
    }
  }

  static Future<void> signOut() async {
    _adminClaimed = false;
    await _auth.signOut();
  }
}
