// Inicio de sesión con Firebase Auth (ronda fix8, versión 6.5).
//
// NO se usa el plugin google_sign_in en ningún caso: el flujo de
// Google va por navegador con Firebase Auth
// (signInWithProvider/linkWithProvider con GoogleAuthProvider), que
// no necesita huella SHA-1 y funciona en el APK instalado
// directamente (sin Play Store).
//
// Flujo:
//   - Al abrir la app, Firebase Auth inicia sesión ANÓNIMA
//     automáticamente (ensureAnonymous). El uid anónimo persiste y
//     es la identidad del documento de Firestore.
//   - linkWithGoogle() enlaza la cuenta de Google a la anónima: el
//     uid NO cambia. Si esa cuenta de Google ya vive en otro uid
//     (otro teléfono), el enlace falla con credential-already-in-use
//     y se entra directamente en esa cuenta con signInWithProvider
//     (el uid pasa a ser el de la cuenta de Google).
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
  /// lo estaba); si la cuenta ya vive en otro uid, entra en ella y
  /// también devuelve true (el uid cambia al de esa cuenta).
  Future<bool> linkWithGoogle();

  /// Entra con Google (teléfono nuevo): si la cuenta ya existe, el
  /// uid pasa a ser el suyo.
  Future<bool> signInWithGoogle();

  /// Desvincula Google de la sesión actual.
  Future<bool> unlinkGoogle();

  /// Usuario actual, o null si no hay sesión.
  AuthUserInfo? get currentUser;
}

/// Implementación real con Firebase Auth (solo signInWithProvider y
/// linkWithProvider: NUNCA google_sign_in).
class FirebaseAuthProvider implements AuthProvider {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  static const _kGoogleProviderId = 'google.com';

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
      try {
        await user.linkWithProvider(GoogleAuthProvider());
        return true;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'provider-already-linked') return true;
        if (e.code == 'credential-already-in-use') {
          // Esa cuenta de Google ya vive en otro uid (otro teléfono):
          // entrar directamente en ella. El uid pasa a ser el suyo.
          final cred = await _auth.signInWithProvider(GoogleAuthProvider());
          return cred.user != null;
        }
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> signInWithGoogle() async {
    try {
      final cred = await _auth.signInWithProvider(GoogleAuthProvider());
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
  /// fallo 'credential-already-in-use' y entra en esa cuenta con
  /// signIn (el uid cambia al de la cuenta de Google).
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
    if (googleUid != null && googleUid != uid) {
      // La cuenta de Google ya vive en otro uid (con
      // simulateAlreadyInUse es el fallo 'credential-already-in-use'):
      // el enlace falla y se entra en esa cuenta. El uid cambia.
      uid = googleUid;
    } else {
      googleUid = uid;
    }
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

  /// Enlaza Google a la sesión anónima (el uid NO cambia, salvo que
  /// la cuenta ya viva en otro uid: entonces se entra en ella y el
  /// uid pasa a ser el suyo). Devuelve Future<bool> y NUNCA lanza
  /// (try/catch total): true = OK, false = falló por cualquier
  /// motivo (sin internet, cancelado, error). La UI muestra
  /// tr('googleSignInFailed') cuando devuelve false. El flujo de
  /// Google por navegador lo maneja el usuario (elige su cuenta):
  /// no lleva timeout de 5 s; solo el inicio anónimo previo, si
  /// hace falta, lo lleva.
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
