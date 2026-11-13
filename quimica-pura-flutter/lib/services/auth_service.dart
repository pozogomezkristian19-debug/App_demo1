// Inicio de sesión con Firebase Auth (ronda fix8, versión 6.5;
// flujo nativo con google_sign_in desde la 7.1).
//
// Google va NATIVO con el plugin google_sign_in (7.2.0): el selector
// de cuentas de Google se abre DENTRO de la app y devuelve un idToken,
// que se entrega a Firebase Auth con GoogleAuthProvider.credential
// (linkWithCredential / signInWithCredential). NUNCA el flujo por
// navegador (signInWithProvider/linkWithProvider con
// GoogleAuthProvider): ese abre Chrome externo a
// quemia-8410a.firebaseapp.com y en este teléfono pierde el estado al
// volver ("missing initial state ... signInWithRedirect in a
// storage-partitioned browser environment", 7.0).
//
// Flujo:
//   - Al abrir la app, Firebase Auth inicia sesión ANÓNIMA
//     automáticamente (ensureAnonymous). El uid anónimo persiste y
//     es la identidad del documento de Firestore.
//   - linkWithGoogle() enlaza la cuenta de Google a la anónima: el
//     uid NO cambia. Si esa cuenta de Google ya vive en otro uid
//     (otro teléfono), el enlace falla con credential-already-in-use
//     y devuelve false SIN entrar en esa cuenta y SIN tocar nada
//     local: la sesión anónima sigue intacta. Para entrar en esa
//     cuenta hay que usar signInWithGoogle() (teléfono nuevo).
//   - signInWithGoogle() es el camino del teléfono NUEVO: entra en
//     la cuenta de Google que ya existe y el uid pasa a ser el suyo;
//     después se restaura el progreso con
//     AnalyticsSync.restoreFromCloud().
//   - unlinkGoogle() desvincula Google (la sesión anónima sigue).
//
// Todo falla en silencio (try/catch + timeout): sin internet la app
// sigue 100% offline. Para los tests, el acceso a Firebase Auth vive
// detrás de [AuthProvider]: la app usa [FirebaseAuthProvider] y los
// tests inyectan [FakeAuthProvider].

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Datos mínimos del usuario actual (anónimo y/o con Google).
class AuthUserInfo {
  const AuthUserInfo({
    required this.uid,
    this.email,
    this.displayName,
    this.googleLinked = false,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final bool googleLinked;
}

/// Acceso a Firebase Auth, inyectable: la app usa Firebase y los
/// tests un falso en memoria.
abstract class AuthProvider {
  /// Sesión anónima (o la que ya haya): devuelve el uid, o null si
  /// no se pudo (sin internet, sin Firebase).
  Future<String?> ensureAnonymous();

  /// Enlaza Google a la sesión actual. true si quedó enlazada (o ya
  /// lo estaba); si la cuenta ya vive en otro uid, el enlace FALLA
  /// (false) y el uid NO cambia: no se entra en esa cuenta ni se
  /// toca nada local.
  Future<bool> linkWithGoogle();

  /// Entra con Google (teléfono nuevo): si la cuenta ya existe, el
  /// uid pasa a ser el suyo.
  Future<bool> signInWithGoogle();

  /// Desvincula Google de la sesión actual.
  Future<bool> unlinkGoogle();

  /// Usuario actual, o null si no hay sesión.
  AuthUserInfo? get currentUser;
}

/// Implementación real con Firebase Auth + google_sign_in nativo
/// (selector de cuentas dentro de la app, sin navegador).
class FirebaseAuthProvider implements AuthProvider {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  static const _kGoogleProviderId = 'google.com';

  /// Cliente OAuth web (tipo 3) de google-services.json: Firebase lo
  /// necesita como serverClientId para que el inicio nativo devuelva
  /// un idToken que Firebase pueda verificar.
  static const _kWebClientId =
      '898001909401-o2ins4m72vvgb5hg6v5rgsl0llgu9glj.apps.googleusercontent.com';

  /// Inicialización de google_sign_in: se hace EXACTAMENTE UNA VEZ
  /// (lo exige el plugin v7) y se guarda el Future para que dos
  /// llamadas seguidas no la repitan. Si falla, se limpia para que
  /// un reintento posterior pueda volver a intentarlo.
  static Future<void>? _googleSignInInit;

  static Future<void> _ensureGoogleSignInInitialized() {
    var pending = _googleSignInInit;
    if (pending == null) {
      pending = GoogleSignIn.instance
          .initialize(serverClientId: _kWebClientId);
      _googleSignInInit = pending;
      pending.catchError((_) {
        _googleSignInInit = null;
      });
    }
    return pending;
  }

  /// Selector nativo de cuentas de Google → credencial de Firebase.
  /// null si el usuario cancela el selector, si no llega idToken o
  /// si falla cualquier paso (sin internet, mal configurado...).
  /// Nunca lanza.
  static Future<OAuthCredential?> _nativeGoogleCredential() async {
    try {
      await _ensureGoogleSignInInitialized();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return null;
      // google_sign_in v7 ya no expone accessToken (eso vive en el
      // cliente de autorización); a Firebase le basta el idToken.
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      // Cancelado por el usuario (o interrumpido): fallo silencioso.
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> ensureAnonymous() async {
    try {
      final current = _auth.currentUser;
      if (current != null) return current.uid;
      final cred = await _auth
          .signInAnonymously()
          .timeout(const Duration(seconds: 5));
      return cred.user?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> linkWithGoogle() async {
    try {
      var user = _auth.currentUser;
      if (user == null) {
        final cred = await _auth
            .signInAnonymously()
            .timeout(const Duration(seconds: 5));
        user = cred.user;
      }
      if (user == null) return false;
      final credential = await _nativeGoogleCredential();
      if (credential == null) return false;
      try {
        await user.linkWithCredential(credential);
        return true;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'provider-already-linked') return true;
        // credential-already-in-use: esa cuenta de Google ya vive en
        // otro uid (otro teléfono). El enlace FALLA y punto: NO se
        // entra en esa cuenta y NO se toca nada local (el uid y el
        // progreso anónimo siguen intactos).
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> signInWithGoogle() async {
    try {
      final credential = await _nativeGoogleCredential();
      if (credential == null) return false;
      final cred = await _auth.signInWithCredential(credential);
      return cred.user != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> unlinkGoogle() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      await user.unlink(_kGoogleProviderId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  AuthUserInfo? get currentUser {
    try {
      final u = _auth.currentUser;
      if (u == null) return null;
      return AuthUserInfo(
        uid: u.uid,
        email: u.email,
        displayName: u.displayName,
        googleLinked: u.providerData
            .any((p) => p.providerId == _kGoogleProviderId),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Falso en memoria para los tests.
class FakeAuthProvider implements AuthProvider {
  /// Uid de la sesión actual (null = sin sesión). Se puede fijar a
  /// mano para simular un teléfono concreto. ensureAnonymous() crea
  /// 'fake-anon-uid' si no hay ninguno.
  String? uid;

  /// Uid de la cuenta de Google (fijarlo simula que esa cuenta ya
  /// existe en otro teléfono: signInWithGoogle entra en ese uid).
  String? googleUid;

  String? email;
  String? displayName;
  bool googleLinked = false;

  /// Si es true, ensureAnonymous falla (simula no tener internet).
  bool failAnonymous = false;

  /// Si es true, ensureAnonymous no termina nunca (simula una red
  /// colgada: la fachada debe cortarla con el timeout de 5 s).
  bool hangAnonymous = false;

  /// Si es true, linkWithGoogle falla siempre (fallo total).
  bool failLink = false;

  /// Si es true y googleUid es otro uid, linkWithGoogle simula el
  /// fallo 'credential-already-in-use': devuelve false, el uid NO
  /// cambia y no se entra en la cuenta de Google (7.1: el antiguo
  /// "entra en esa cuenta y el uid cambia" está prohibido).
  bool simulateAlreadyInUse = false;

  @override
  Future<String?> ensureAnonymous() async {
    if (uid != null) return uid;
    if (hangAnonymous) return await Completer<String?>().future;
    if (failAnonymous) return null;
    uid = 'fake-anon-uid';
    return uid;
  }

  @override
  Future<bool> linkWithGoogle() async {
    if (failLink) return false;
    if (uid == null) {
      final anon = await ensureAnonymous();
      if (anon == null) return false;
    }
    if (simulateAlreadyInUse && googleUid != null && googleUid != uid) {
      // La cuenta de Google ya vive en otro uid (fallo
      // 'credential-already-in-use'): el enlace FALLA, el uid NO
      // cambia y no se entra en esa cuenta ni se toca nada local.
      return false;
    }
    googleUid = uid;
    googleLinked = true;
    email ??= 'test@example.com';
    displayName ??= 'Test';
    return true;
  }

  @override
  Future<bool> signInWithGoogle() async {
    if (googleUid != null) {
      uid = googleUid;
    } else {
      uid ??= 'fake-anon-uid';
      googleUid = uid;
    }
    googleLinked = true;
    email ??= 'test@example.com';
    displayName ??= 'Test';
    return true;
  }

  @override
  Future<bool> unlinkGoogle() async {
    if (!googleLinked) return false;
    googleLinked = false;
    email = null;
    displayName = null;
    return true;
  }

  @override
  AuthUserInfo? get currentUser => uid == null
      ? null
      : AuthUserInfo(
          uid: uid!,
          email: email,
          displayName: displayName,
          googleLinked: googleLinked,
        );
}

class AuthService {
  AuthService._();

  static AuthProvider? _providerOverride;

  static AuthProvider get _provider =>
      _providerOverride ?? FirebaseAuthProvider();

  /// Sesión anónima automática al abrir la app (o la que ya haya).
  /// null si falla (sin internet): la app sigue 100% offline. Con
  /// timeout de 5 s: si Firebase no responde, no se queda colgada.
  static Future<String?> ensureAnonymous() async {
    try {
      return await _provider
          .ensureAnonymous()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  /// Uid de la sesión actual (anónimo o con Google), o null.
  /// Es la identidad del documento de Firestore.
  static String? get currentUid {
    try {
      return _provider.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// ¿La sesión actual tiene Google enlazado?
  static bool get isGoogleLinked {
    try {
      return _provider.currentUser?.googleLinked ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Correo de la cuenta de Google enlazada, o null.
  static String? get googleEmail {
    try {
      return _provider.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  /// Nombre de la cuenta de Google enlazada, o null.
  static String? get googleDisplayName {
    try {
      return _provider.currentUser?.displayName;
    } catch (_) {
      return null;
    }
  }

  /// Enlaza Google a la sesión anónima (el uid NO cambia nunca: si
  /// la cuenta ya vive en otro uid, el enlace falla y la sesión
  /// anónima sigue intacta). Devuelve Future<bool> y NUNCA lanza
  /// (try/catch total): true = OK, false = falló por cualquier
  /// motivo (sin internet, cancelado, error). La UI muestra
  /// tr('googleSignInFailed') cuando devuelve false. El selector
  /// nativo de Google lo maneja el usuario (elige su cuenta): no
  /// lleva timeout de 5 s; solo el inicio anónimo previo, si hace
  /// falta, lo lleva.
  static Future<bool> linkWithGoogle() async {
    try {
      return await _provider.linkWithGoogle();
    } catch (_) {
      return false;
    }
  }

  /// Entra con Google (teléfono nuevo). Igual que linkWithGoogle:
  /// Future<bool> que NUNCA lanza; false = falló.
  static Future<bool> signInWithGoogle() async {
    try {
      return await _provider.signInWithGoogle();
    } catch (_) {
      return false;
    }
  }

  /// Desvincula Google de la sesión actual. Tampoco lanza nunca.
  static Future<bool> unlinkGoogle() async {
    try {
      return await _provider.unlinkGoogle();
    } catch (_) {
      return false;
    }
  }

  /// Solo para tests: inyecta un proveedor (el falso en memoria).
  @visibleForTesting
  static void setProviderForTests(AuthProvider provider) {
    _providerOverride = provider;
  }

  /// Solo para tests: vuelve al proveedor real.
  @visibleForTesting
  static void resetForTests() {
    _providerOverride = null;
  }
}
