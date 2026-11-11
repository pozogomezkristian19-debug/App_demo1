// Inicio de sesión con Google usando SOLO Firebase Auth.
//
// Se usa signInWithProvider(GoogleAuthProvider()): el flujo por navegador no
// necesita huella SHA-1 y funciona en el APK instalado directamente (sin
// Play Store). NO se usa ningún plugin de inicio de sesión de Google: en un
// APK release sin keystore firmado ese plugin falla. La puerta de auth (solo
// cuentas en la colección 'admins') no cambia: ver main.dart.

import 'package:firebase_auth/firebase_auth.dart';

class GoogleAuthService {
  GoogleAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Inicia sesión con Google y devuelve el [User] de Firebase.
  /// Lanza la excepción original si el usuario cancela o falla el login.
  /// Requiere el proveedor Google habilitado en la consola de Firebase.
  Future<User> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    final result = await _auth.signInWithProvider(provider);
    final user = result.user;
    if (user == null) {
      throw StateError('El inicio de sesión con Google no devolvió usuario.');
    }
    return user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
