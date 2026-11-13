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
//     y hay FALLBACK (Quemia 7.3): se entra en esa cuenta con
//     signInWithCredential (el uid pasa a ser el de Google) y ANTES
//     de perder nada se MIGRA todo el progreso del anónimo al uid
//     de Google (fusión best-of: nivel y puntos mayores, días
//     unidos; el progreso local —vidas, cosméticos, avatar, amigos,
//     errores, logros, grupos, estadísticas— vive en el teléfono y
//     no depende del uid, así que sobrevive al cambio). Si la
//     migración falla, el inicio devuelve false con el motivo en
//     [AuthService.lastGoogleError]: mejor fallar con mensaje claro
//     que dejar al usuario sin su progreso.
//   - El error REAL ya no se traga (Quemia 7.3): si el selector de
//     cuentas ni siquiera sale (fallo en initialize() o en
//     authenticate(), p. ej. error 10 DEVELOPER_ERROR por huella
//     SHA-1 o cliente OAuth mal configurado), el código queda en
//     [AuthService.lastGoogleError] y en el log, no solo en un
//     "Inténtalo de nuevo" genérico.
//   - Una cuenta que también es de administrador (p. ej.
//     pozogomezkristian19@gmail.com) entra y JUEGA como un jugador
//     normal: la app principal NO tiene ningún chequeo de rol ni
//     bloquea cuentas admin (no hay isAdmin/admin@/rol en lib/).
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

  /// Código del último fallo de Google (p. ej.
  /// 'google_sign_in:unknownError', 'firebase_auth:
  /// credential-already-in-use', 'migration_failed'), o null si el
  /// último intento salió bien o no hubo ninguno. La UI lo enseña
  /// junto al mensaje genérico para diagnosticar (Quemia 7.3).
  String? get lastGoogleError;
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

  /// Código del último fallo de Google en ESTE proveedor (estático:
  /// AuthService crea una instancia nueva en cada acceso, así que el
  /// estado no puede vivir en la instancia). Lo lee
  /// [AuthService.lastGoogleError].
  static String? _lastGoogleError;

  @override
  String? get lastGoogleError => _lastGoogleError;

  /// Inicialización de google_sign_in: se hace EXACTAMENTE UNA VEZ
  /// (lo exige el plugin v7) y se guarda el Future para que dos
  /// llamadas seguidas no la repitan. Si falla, se limpia para que
  /// un reintento posterior pueda volver a intentarlo, y el motivo
  /// queda registrado (Quemia 7.3: antes este fallo era invisible y
  /// el selector no salía ni en la primera instalación sin que
  /// quedara ninguna pista).
  static Future<void>? _googleSignInInit;

  static Future<void> _ensureGoogleSignInInitialized() {
    var pending = _googleSignInInit;
    if (pending == null) {
      pending = GoogleSignIn.instance
          .initialize(serverClientId: _kWebClientId);
      _googleSignInInit = pending;
      pending.catchError((Object e) {
        _googleSignInInit = null;
        _lastGoogleError = 'google_sign_in:init_failed';
        debugPrint('[Google] initialize() falló: $e');
      });
    }
    return pending;
  }

  /// Selector nativo de cuentas de Google → credencial de Firebase.
  /// null si el usuario cancela el selector, si no llega idToken o
  /// si falla cualquier paso (sin internet, mal configurado...).
  /// Nunca lanza, pero el motivo REAL queda registrado en
  /// [_lastGoogleError] y en el log (Quemia 7.3): antes TODAS las
  /// GoogleSignInException se tragaban devolviendo null y la UI
  /// solo podía decir "Inténtalo de nuevo".
  static Future<OAuthCredential?> _nativeGoogleCredential() async {
    try {
      await _ensureGoogleSignInInitialized();
      final account = await GoogleSignIn.instance
          .authenticate()
          .timeout(kGoogleAuthenticateTimeout);
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        _lastGoogleError = 'google_sign_in:no_id_token';
        debugPrint('[Google] authenticate() sin idToken.');
        return null;
      }
      // google_sign_in v7 ya no expone accessToken (eso vive en el
      // cliente de autorización); a Firebase le basta el idToken.
      return GoogleAuthProvider.credential(idToken: idToken);
    } on TimeoutException {
      // El selector o la obtención del token se quedó colgado
      // (conexión muy lenta): no dejar "Vinculando…" para siempre.
      _lastGoogleError = 'google_sign_in:timeout_auth';
      debugPrint('[Google] authenticate() agotó 60 s.');
      return null;
    } on GoogleSignInException catch (e) {
      // Cancelado por el usuario: fallo silencioso, pero el código
      // queda registrado para diagnosticar (no es un error).
      _lastGoogleError = 'google_sign_in:${e.code.name}';
      debugPrint('[Google] authenticate() falló: ${e.code.name} '
          '${e.description ?? ''}');
      return null;
    } catch (e) {
      _lastGoogleError = 'google_sign_in:unknown';
      debugPrint('[Google] authenticate() falló: $e');
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

  /// Timeout del inicio anónimo al ENLAZAR Google (Quemia 7.4,
  /// Kristian): con VPN en Cuba tarda más de 5 s; el timeout viejo
  /// de 5 s lanzaba TimeoutException y salía 'link:unknown' sin que
  /// apareciera el selector. Ahora 15 s.
  static const kAnonymousLinkTimeout = Duration(seconds: 15);

  /// Timeout de cada llamada a Firebase Auth al enlazar/entrar con
  /// Google (Quemia 7.5): linkWithCredential y signInWithCredential
  /// NO llevaban timeout y con la conexión lenta se quedaban
  /// colgadas para siempre en "Vinculando…". 20 s: suficiente para
  /// una conexión lenta, pero la pantalla nunca se queda colgada.
  static const kGoogleLinkTimeout = Duration(seconds: 20);

  /// Timeout del selector de Google + obtención del idToken
  /// (Quemia 7.5): 60 s, generoso porque el usuario tarda en elegir
  /// su cuenta; solo salta si la llamada se queda colgada de verdad.
  static const kGoogleAuthenticateTimeout = Duration(seconds: 60);

  /// Espera el inicio anónimo con el timeout de enlace. Se extrae
  /// para poder probarlo sin Firebase: el test pasa un Future lento
  /// y comprueba que no se rinde antes de 15 s, y que al agotarse
  /// deja el código 'link:timeout_anon' (no un 'unknown' opaco).
  @visibleForTesting
  static Future<T?> waitForAnonymous<T>(Future<T> future) async {
    try {
      final value = await future.timeout(kAnonymousLinkTimeout);
      // Sin error en este paso: limpiar el código anterior para que
      // un fallo viejo no se confunda con el intento actual.
      _lastGoogleError = null;
      return value;
    } on TimeoutException {
      _lastGoogleError = 'link:timeout_anon';
      debugPrint('[Google] linkWithGoogle: el inicio anónimo agotó '
          '15 s (conexión lenta).');
      return null;
    }
  }

  @override
  Future<bool> linkWithGoogle() async {
    try {
      var user = _auth.currentUser;
      if (user == null) {
        // El anónimo es solo el paso previo al enlace: si falla
        // (apagado en Firebase, sin red, lento), Google NO se
        // bloquea (Quemia 7.5): se entra directo con la cuenta.
        try {
          final cred =
              await waitForAnonymous(_auth.signInAnonymously());
          user = cred?.user;
        } catch (e) {
          debugPrint('[Google] anónimo falló, se sigue sin él: $e');
          user = null;
        }
      }
      final credential = await _nativeGoogleCredential();
      if (credential == null) return false;
      if (user == null) {
        // Sin sesión anónima: entrar directo con Google (la cuenta
        // ya existe en Firebase o se crea ahora).
        try {
          final cred = await _auth
              .signInWithCredential(credential)
              .timeout(kGoogleLinkTimeout);
          if (cred.user == null) return false;
          _lastGoogleError = null;
          return true;
        } on FirebaseAuthException catch (e) {
          _lastGoogleError = 'firebase_auth:${e.code}';
          debugPrint('[Google] signInWithCredential falló: ${e.code}');
          return false;
        } on TimeoutException {
          _lastGoogleError = 'link:timeout_signin';
          debugPrint('[Google] signInWithCredential agotó 20 s.');
          return false;
        }
      }
      try {
        await user
            .linkWithCredential(credential)
            .timeout(kGoogleLinkTimeout);
        _lastGoogleError = null;
        return true;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'provider-already-linked') {
          _lastGoogleError = null;
          return true;
        }
        if (e.code == 'credential-already-in-use') {
          // FALLBACK (Quemia 7.3): esa cuenta de Google ya vive en
          // otro uid (otro teléfono). Antes el enlace fallaba y
          // punto; ahora se ENTRA en esa cuenta con
          // signInWithCredential (el uid pasa a ser el de Google) y
          // la fachada [AuthService.linkWithGoogle] migra el
          // progreso del anónimo antes de perderlo. El progreso
          // local no se toca aquí: vive en el teléfono y no
          // depende del uid.
          debugPrint('[Google] linkWithCredential: cuenta ya en otro '
              'uid; fallback a signInWithCredential.');
          try {
            final cred = await _auth
                .signInWithCredential(credential)
                .timeout(kGoogleLinkTimeout);
            if (cred.user == null) return false;
            _lastGoogleError = null;
            return true;
          } on FirebaseAuthException catch (e2) {
            _lastGoogleError = 'firebase_auth:${e2.code}';
            debugPrint('[Google] fallback signInWithCredential '
                'falló: ${e2.code}');
            return false;
          } on TimeoutException {
            _lastGoogleError = 'link:timeout_signin';
            debugPrint('[Google] fallback signInWithCredential '
                'agotó 20 s.');
            return false;
          }
        }
        _lastGoogleError = 'firebase_auth:${e.code}';
        debugPrint('[Google] linkWithCredential falló: ${e.code}');
        return false;
      } on TimeoutException {
        _lastGoogleError = 'link:timeout_link';
        debugPrint('[Google] linkWithCredential agotó 20 s.');
        return false;
      }
    } catch (e) {
      // Quemia 7.5: guardar el CÓDIGO real de Firebase (no solo el
      // tipo), para diagnosticar el fallo de verdad. Antes todo
      // salía como 'link:FirebaseAuthException' y no se sabía si
      // era red, permiso o credencial.
      if (e is FirebaseAuthException) {
        _lastGoogleError = 'link:${e.code}';
      } else {
        _lastGoogleError = 'link:${e.runtimeType}';
      }
      debugPrint('[Google] linkWithGoogle falló: $e');
      return false;
    }
  }

  @override
  Future<bool> signInWithGoogle() async {
    try {
      final credential = await _nativeGoogleCredential();
      if (credential == null) return false;
      final cred = await _auth
          .signInWithCredential(credential)
          .timeout(kGoogleLinkTimeout);
      if (cred.user == null) return false;
      _lastGoogleError = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _lastGoogleError = 'firebase_auth:${e.code}';
      debugPrint('[Google] signInWithCredential falló: ${e.code}');
      return false;
    } on TimeoutException {
      _lastGoogleError = 'sign_in:timeout';
      debugPrint('[Google] signInWithCredential agotó 20 s.');
      return false;
    } catch (e) {
      _lastGoogleError = 'sign_in:unknown';
      debugPrint('[Google] signInWithGoogle falló: $e');
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

  /// Si es true, el selector de cuentas falla ANTES de dar
  /// credencial (simula initialize()/authenticate() roto, p. ej.
  /// error 10 DEVELOPER_ERROR): link/signIn devuelven false y el
  /// código queda en [lastGoogleError]. El código a simular va en
  /// [nativeErrorCode] (p. ej. 'unknownError').
  bool failNativeCredential = false;
  String nativeErrorCode = 'unknownError';

  /// Código del último fallo de Google simulado (o null).
  String? lastGoogleError;

  /// Si es true y googleUid es otro uid, linkWithGoogle simula el
  /// fallo 'credential-already-in-use' Y EL FALLBACK de la 7.3: se
  /// entra en la cuenta de Google (el uid pasa a ser googleUid) y
  /// devuelve true; la migración del progreso la hace la fachada
  /// [AuthService] con el hook de turno. (7.1: el enlace fallaba y
  /// no se entraba; la 7.3 cambia esa regla por orden de Kristian.)
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
    if (failNativeCredential) {
      lastGoogleError = 'google_sign_in:$nativeErrorCode';
      return false;
    }
    if (failLink) {
      lastGoogleError = 'firebase_auth:unknown';
      return false;
    }
    if (uid == null) {
      final anon = await ensureAnonymous();
      if (anon == null) return false;
    }
    if (simulateAlreadyInUse && googleUid != null && googleUid != uid) {
      // La cuenta de Google ya vive en otro uid (fallo
      // 'credential-already-in-use') + FALLBACK 7.3: se entra en
      // esa cuenta (el uid pasa a ser googleUid) y se devuelve
      // true; la fachada migra el progreso del anónimo.
      lastGoogleError = 'firebase_auth:credential-already-in-use';
      uid = googleUid;
      googleLinked = true;
      email ??= 'test@example.com';
      displayName ??= 'Test';
      return true;
    }
    googleUid = uid;
    googleLinked = true;
    lastGoogleError = null;
    email ??= 'test@example.com';
    displayName ??= 'Test';
    return true;
  }

  @override
  Future<bool> signInWithGoogle() async {
    if (failNativeCredential) {
      lastGoogleError = 'google_sign_in:$nativeErrorCode';
      return false;
    }
    if (googleUid != null) {
      uid = googleUid;
    } else {
      uid ??= 'fake-anon-uid';
      googleUid = uid;
    }
    googleLinked = true;
    lastGoogleError = null;
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

  /// Código del último fallo de Google (o null si el último intento
  /// salió bien): lo pone el proveedor ('google_sign_in:…' /
  /// 'firebase_auth:…') o la migración ('migration_failed'). La UI
  /// lo enseña junto al mensaje genérico para diagnosticar por qué
  /// ni siquiera salió el selector (Quemia 7.3).
  static String? _lastGoogleError;

  static String? get lastGoogleError => _lastGoogleError;

  /// Migración del progreso al cambiar de uid (Quemia 7.3): la
  /// pone main() con [AnalyticsSync.migrateAnonymousProgress]. Se
  /// llama con (uidAnónimo, uidGoogle) cuando el inicio de sesión
  /// cambia el uid (fallback credential-already-in-use o teléfono
  /// nuevo): fusiona el documento del anónimo en el de Google y
  /// sube la foto local. Si devuelve false, el inicio se da por
  /// fallido (con 'migration_failed'): el progreso local sigue
  /// intacto en el teléfono, así que nada se pierde. En los tests
  /// se inyecta un falso o se deja en null (sin migración).
  static Future<bool> Function(String fromUid, String toUid)?
      migrateProgressOnUidChange;

  /// Enlaza Google a la sesión anónima (el uid NO cambia si el
  /// enlace directo funciona; SI cambia con el fallback 7.3 cuando
  /// la cuenta ya vive en otro uid: se entra en ella y se migra el
  /// progreso del anónimo). Devuelve Future<bool> y NUNCA lanza
  /// (try/catch total): true = OK, false = falló por cualquier
  /// motivo (sin internet, cancelado, error). La UI muestra
  /// tr('googleSignInFailed') + [lastGoogleError] cuando devuelve
  /// false. El selector nativo de Google lo maneja el usuario
  /// (elige su cuenta): no lleva timeout de 5 s; solo el inicio
  /// anónimo previo, si hace falta, lo lleva.
  static Future<bool> linkWithGoogle() async {
    return _runGoogleAuth(() => _provider.linkWithGoogle());
  }

  /// Entra con Google (teléfono nuevo). Igual que linkWithGoogle:
  /// Future<bool> que NUNCA lanza; false = falló. Si había progreso
  /// anónimo en este teléfono, también se migra al uid de Google.
  static Future<bool> signInWithGoogle() async {
    return _runGoogleAuth(() => _provider.signInWithGoogle());
  }

  /// Núcleo común de link/signIn: corre el intento, recoge el error
  /// real del proveedor y, si el uid cambió, migra el progreso del
  /// anónimo al uid nuevo antes de dar el inicio por bueno.
  static Future<bool> _runGoogleAuth(
      Future<bool> Function() attempt) async {
    final uidBefore = currentUid;
    bool ok;
    try {
      ok = await attempt();
    } catch (_) {
      _lastGoogleError = 'unknown';
      return false;
    }
    _lastGoogleError = _provider.lastGoogleError;
    if (!ok) return false;
    final uidAfter = currentUid;
    if (uidAfter != null &&
        uidBefore != null &&
        uidBefore.isNotEmpty &&
        uidAfter != uidBefore &&
        migrateProgressOnUidChange != null) {
      final migrated =
          await migrateProgressOnUidChange!(uidBefore, uidAfter);
      if (!migrated) {
        // La sesión ya es la de Google, pero la fusión en la nube
        // no se pudo hacer: se da por fallido con motivo claro.
        // El progreso LOCAL sigue intacto (no depende del uid) y
        // la próxima subida con force lo vuelve a intentar.
        _lastGoogleError = 'migration_failed';
        return false;
      }
    }
    return true;
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
    _lastGoogleError = null;
    migrateProgressOnUidChange = null;
  }
}
