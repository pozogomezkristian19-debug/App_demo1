// Inicio de sesión con Google NATIVO (plugin google_sign_in + Firebase Auth).
//
// Flujo: selector de cuentas de Google DENTRO de la app (sin navegador) ->
// idToken de Google -> Firebase con GoogleAuthProvider.credential.
// El flujo anterior por navegador (signInWithProvider) abría Chrome externo
// a quemia-8410a.firebaseapp.com y fallaba en el APK firmado con
// "missing initial state ... signInWithRedirect in a storage-partitioned
// browser environment": el estado del redirect se perdía al volver del
// navegador. El flujo nativo no usa redirect y no abre Chrome.
//
// Requiere: huella SHA-1 registrada en Firebase (ya está) y el
// serverClientId (cliente OAuth web de google-services.json). La puerta de
// auth (solo cuentas en la colección 'admins') no cambia: ver main.dart.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Cliente OAuth web (de google-services.json) que Firebase usa para validar
/// el idToken. Es el mismo cliente que usa la app Quemia.
const String _kServerClientId =
    '898001909401-o2ins4m72vvgb5hg6v5rgsl0llgu9glj.apps.googleusercontent.com';

class GoogleAuthService {
  GoogleAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// google_sign_in exige initialize() exactamente una vez por proceso.
  static bool _googleSignInInitialized = false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Inicia sesión con Google y devuelve el [User] de Firebase.
  /// Lanza la excepción original si el usuario cancela o falla el login.
  /// Requiere el proveedor Google habilitado en la consola de Firebase.
  Future<User> signInWithGoogle() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: _kServerClientId,
      );
      _googleSignInInitialized = true;
    }
    // Selector de cuentas nativo dentro de la app. Si el usuario cancela,
    // authenticate() lanza GoogleSignInException (canceled): se propaga tal
    // cual para que la pantalla de login muestre su mensaje amistoso.
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError(
        'El inicio de sesión con Google no devolvió un idToken.',
      );
    }
    // En google_sign_in 7.x, authentication solo trae el idToken; el
    // accessToken vive en el cliente de autorización y Firebase no lo
    // necesita: el idToken basta para crear la credencial.
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
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
