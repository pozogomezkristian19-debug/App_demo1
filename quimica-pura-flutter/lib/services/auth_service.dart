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

import 'email_index.dart';

/// Datos mínimos del usuario actual (anónimo y/o con Google).
class AuthUserInfo {
  const AuthUserInfo({
    required this.uid,
    this.email,
    this.displayName,
    this.googleLinked = false,
    this.emailLinked = false,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final bool googleLinked;

  /// ¿La sesión actual tiene correo+contraseña enlazado?
  final bool emailLinked;
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

  /// Enlaza correo+contraseña a la sesión actual (mismo patrón que
  /// Google: si la cuenta ya vive en otro uid, fallback a entrar en
  /// ella con signInWithCredential). true si quedó enlazada (o ya lo
  /// estaba). La cuenta se crea en Firebase al enlazar: el correo
  /// queda verificado por el código OTP que la app pide ANTES de
  /// llamar aquí (ver OtpService).
  Future<bool> linkWithEmail(String email, String password);

  /// Enlaza correo+contraseña a la sesión ACTUAL, sin cambiar de
  /// cuenta (Kristian 2026-11-15: cuentas de Google que quieren
  /// ponerle una contraseña para entrar con correo). A diferencia
  /// de [linkWithEmail], aquí NO hay fallback a entrar en otra
  /// cuenta: si el correo ya vive en otro uid
  /// ('email-already-in-use'), devuelve false y el uid NO cambia.
  /// 'provider-already-linked' (la contraseña ya está puesta) vale
  /// como éxito. NUNCA lanza: false + el motivo en
  /// [lastEmailError].
  Future<bool> linkPassword(String email, String password);

  /// Entra con correo+contraseña (teléfono nuevo o cuenta ya
  /// creada). true si se entró; false con el motivo en
  /// [lastEmailError] ('firebase_auth:invalid-credential' si el
  /// correo no existe o la contraseña no coincide).
  Future<bool> signInWithEmail(String email, String password);

  /// Manda el correo de Firebase para cambiar la contraseña (un
  /// enlace, gratis en Spark; NO usa código OTP). true si Firebase
  /// lo aceptó. NUNCA lanza. Si el correo no tiene cuenta, Firebase
  /// devuelve true igualmente (no revela si existe), así que la UI
  /// siempre dice que se mandó el enlace.
  Future<bool> sendPasswordResetEmail(String email);

  /// Código del último fallo de correo ('firebase_auth:…' /
  /// 'email:timeout_…'), o null si el último intento salió bien.
  String? get lastEmailError;

  /// Desvincula Google de la sesión actual.
  Future<bool> unlinkGoogle();

  /// Cierra la sesión por completo (Google/correo) y deja la
  /// sesión sin usuario. La fachada vuelve a entrar como
  /// invitado después. NUNCA lanza.
  Future<void> signOut();

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
      pending = GoogleSignIn.instance.initialize(serverClientId: _kWebClientId);
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
      final cred =
          await _auth.signInAnonymously().timeout(const Duration(seconds: 5));
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

  /// Inicio con Google EN WEB (2026-11-15): el plugin google_sign_in
  /// NO tiene authenticate() en web — su código lanza
  /// UnimplementedError siempre ('authenticate is not supported on
  /// the web. Instead, use renderButton...'), así que ningún arreglo
  /// de meta tag ni de orígenes autorizados podía hacer funcionar el
  /// selector. En web se usa el popup de Firebase Auth, que abre la
  /// ventana de Google en el dominio de autenticación del proyecto.
  /// En móvil esta rama no existe (kIsWeb es false) y el flujo del
  /// plugin no cambia. El popup REEMPLAZA la sesión anónima por la
  /// de Google: la fachada (_runGoogleAuth) ve el cambio de uid y
  /// migra el progreso del anónimo, igual que en el fallback 7.3.
  Future<bool> _googlePopupWeb() async {
    try {
      final cred = await _auth
          .signInWithPopup(GoogleAuthProvider())
          .timeout(kGoogleLinkTimeout);
      if (cred.user == null) return false;
      _lastGoogleError = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _lastGoogleError = 'google_popup:${e.code}';
      debugPrint('[Google] signInWithPopup falló: ${e.code}');
      return false;
    } on TimeoutException {
      _lastGoogleError = 'google_popup:timeout';
      debugPrint('[Google] signInWithPopup agotó 20 s.');
      return false;
    } catch (e) {
      _lastGoogleError = 'google_popup:unknown';
      debugPrint('[Google] signInWithPopup falló: $e');
      return false;
    }
  }

  @override
  Future<bool> linkWithGoogle() async {
    if (kIsWeb) return _googlePopupWeb();
    try {
      var user = _auth.currentUser;
      if (user == null) {
        // El anónimo es solo el paso previo al enlace: si falla
        // (apagado en Firebase, sin red, lento), Google NO se
        // bloquea (Quemia 7.5): se entra directo con la cuenta.
        try {
          final cred = await waitForAnonymous(_auth.signInAnonymously());
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
        await user.linkWithCredential(credential).timeout(kGoogleLinkTimeout);
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
    if (kIsWeb) return _googlePopupWeb();
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

  /// Código del último fallo de correo en ESTE proveedor (estático,
  /// igual que el de Google: AuthService crea una instancia nueva en
  /// cada acceso). Lo lee [AuthService.lastEmailError].
  static String? _lastEmailError;

  @override
  String? get lastEmailError => _lastEmailError;

  /// Timeout de cada llamada a Firebase Auth al enlazar/entrar con
  /// correo+contraseña (igual que el de Google, 20 s): con la
  /// conexión lenta de Cuba la pantalla nunca se queda colgada en
  /// "Creando cuenta…" o "Entrando…".
  static const kEmailLinkTimeout = Duration(seconds: 20);

  /// Enlaza correo+contraseña a la sesión actual. Espejo de
  /// [linkWithGoogle]: si no hay sesión, se crea la anónima
  /// primero (15 s); si el enlace directo falla porque la cuenta ya
  /// vive en otro uid ('email-already-in-use'), fallback a
  /// signInWithCredential (el uid pasa a ser el de esa cuenta y la
  /// fachada migra el progreso del anónimo). NUNCA lanza: false +
  /// [_lastEmailError] con el motivo real.
  @override
  Future<bool> linkWithEmail(String email, String password) async {
    try {
      var user = _auth.currentUser;
      if (user == null) {
        try {
          final cred = await waitForAnonymous(_auth.signInAnonymously());
          user = cred?.user;
        } catch (e) {
          debugPrint('[Correo] anónimo falló, se sigue sin él: $e');
          user = null;
        }
      }
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      if (user == null) {
        try {
          final cred = await _auth
              .signInWithCredential(credential)
              .timeout(kEmailLinkTimeout);
          if (cred.user == null) return false;
          _lastEmailError = null;
          return true;
        } on FirebaseAuthException catch (e) {
          _lastEmailError = 'firebase_auth:${e.code}';
          debugPrint('[Correo] signInWithCredential falló: ${e.code}');
          return false;
        } on TimeoutException {
          _lastEmailError = 'email:timeout_signin';
          debugPrint('[Correo] signInWithCredential agotó 20 s.');
          return false;
        }
      }
      try {
        await user.linkWithCredential(credential).timeout(kEmailLinkTimeout);
        _lastEmailError = null;
        return true;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'provider-already-linked') {
          _lastEmailError = null;
          return true;
        }
        if (e.code == 'email-already-in-use' ||
            e.code == 'credential-already-in-use') {
          // Esa cuenta de correo ya vive en otro uid (otro
          // teléfono): se ENTRA en ella y la fachada migra el
          // progreso del anónimo (igual que el fallback 7.3 de
          // Google).
          debugPrint('[Correo] linkWithCredential: cuenta ya en otro '
              'uid; fallback a signInWithCredential.');
          try {
            final cred = await _auth
                .signInWithCredential(credential)
                .timeout(kEmailLinkTimeout);
            if (cred.user == null) return false;
            _lastEmailError = null;
            return true;
          } on FirebaseAuthException catch (e2) {
            // La causa raíz es que el correo ya vive en otra cuenta
            // y la contraseña que se escribió no es la de esa
            // cuenta: se guarda ESE motivo, no el del fallback,
            // para que la UI sepa que el correo ya está tomado
            // (Kristian 2026-11-15: el diálogo del correo ya
            // tomado). Otros códigos del fallback se guardan tal
            // cual (sin internet, etc.).
            if (e2.code == 'wrong-password' ||
                e2.code == 'invalid-credential') {
              _lastEmailError = 'firebase_auth:email-already-in-use';
            } else {
              _lastEmailError = 'firebase_auth:${e2.code}';
            }
            debugPrint('[Correo] fallback signInWithCredential '
                'falló: ${e2.code}');
            return false;
          } on TimeoutException {
            _lastEmailError = 'email:timeout_signin';
            debugPrint('[Correo] fallback signInWithCredential '
                'agotó 20 s.');
            return false;
          }
        }
        _lastEmailError = 'firebase_auth:${e.code}';
        debugPrint('[Correo] linkWithCredential falló: ${e.code}');
        return false;
      } on TimeoutException {
        _lastEmailError = 'email:timeout_link';
        debugPrint('[Correo] linkWithCredential agotó 20 s.');
        return false;
      }
    } catch (e) {
      if (e is FirebaseAuthException) {
        _lastEmailError = 'email:${e.code}';
      } else {
        _lastEmailError = 'email:${e.runtimeType}';
      }
      debugPrint('[Correo] linkWithEmail falló: $e');
      return false;
    }
  }

  /// Enlaza correo+contraseña a la sesión actual SIN cambiar de
  /// cuenta (Kristian 2026-11-15: ponerle contraseña a una cuenta
  /// de Google). Sin fallback a entrar en otra cuenta y sin crear
  /// anónimo: sin sesión actual, false. 'provider-already-linked'
  /// (la contraseña ya está puesta) vale como éxito. NUNCA lanza:
  /// false + [_lastEmailError] con el motivo real.
  @override
  Future<bool> linkPassword(String email, String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _lastEmailError = 'email:no-user';
        return false;
      }
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      try {
        await user.linkWithCredential(credential).timeout(kEmailLinkTimeout);
        _lastEmailError = null;
        return true;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'provider-already-linked') {
          _lastEmailError = null;
          return true;
        }
        _lastEmailError = 'firebase_auth:${e.code}';
        debugPrint('[Correo] linkPassword falló: ${e.code}');
        return false;
      } on TimeoutException {
        _lastEmailError = 'email:timeout_link';
        debugPrint('[Correo] linkPassword agotó 20 s.');
        return false;
      }
    } catch (e) {
      _lastEmailError =
          e is FirebaseAuthException ? 'email:${e.code}' : 'email:unknown';
      debugPrint('[Correo] linkPassword falló: $e');
      return false;
    }
  }

  /// Entra con correo+contraseña. NUNCA lanza: false +
  /// [_lastEmailError] con el motivo real ('invalid-credential' si
  /// el correo no existe o la contraseña no coincide — Firebase ya
  /// no distingue ambos casos).
  @override
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      final cred = await _auth
          .signInWithCredential(credential)
          .timeout(kEmailLinkTimeout);
      if (cred.user == null) return false;
      _lastEmailError = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _lastEmailError = 'firebase_auth:${e.code}';
      debugPrint('[Correo] signInWithEmail falló: ${e.code}');
      return false;
    } on TimeoutException {
      _lastEmailError = 'email:timeout_signin';
      debugPrint('[Correo] signInWithEmail agotó 20 s.');
      return false;
    } catch (e) {
      _lastEmailError = 'email:unknown';
      debugPrint('[Correo] signInWithEmail falló: $e');
      return false;
    }
  }

  /// Manda el enlace de Firebase para cambiar la contraseña. NUNCA
  /// lanza: false + [_lastEmailError] con el motivo real.
  @override
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth
          .sendPasswordResetEmail(email: email)
          .timeout(kEmailLinkTimeout);
      _lastEmailError = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _lastEmailError = 'firebase_auth:${e.code}';
      debugPrint('[Correo] sendPasswordResetEmail falló: ${e.code}');
      return false;
    } on TimeoutException {
      _lastEmailError = 'email:timeout_reset';
      debugPrint('[Correo] sendPasswordResetEmail agotó 20 s.');
      return false;
    } catch (e) {
      _lastEmailError = 'email:unknown';
      debugPrint('[Correo] sendPasswordResetEmail falló: $e');
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

  /// Cierra la sesión de Firebase y de Google (para que el próximo
  /// inicio enseñe el selector de cuentas en vez de entrar solo
  /// con la misma). NUNCA lanza.
  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
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
        googleLinked:
            u.providerData.any((p) => p.providerId == _kGoogleProviderId),
        emailLinked: u.providerData.any((p) => p.providerId == 'password'),
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

  /// Cuentas de correo registradas por el falso (correo →
  /// contraseña). linkWithEmail crea la cuenta; signInWithEmail
  /// comprueba la contraseña.
  final Map<String, String> emailAccounts = {};

  /// Correos a los que el falso "mandó" el enlace de Firebase para
  /// cambiar la contraseña (siempre acepta, como Firebase real: no
  /// revela si el correo tiene cuenta).
  final List<String> resetEmailsSent = [];

  /// ¿La sesión actual tiene correo+contraseña enlazado?
  bool emailLinked = false;

  /// Código del último fallo de correo simulado (o null).
  String? lastEmailError;

  /// Si es true, linkWithEmail simula 'email-already-in-use' + el
  /// fallback: se entra en la cuenta de correo (el uid pasa a ser
  /// [emailUid]) y devuelve true.
  bool simulateEmailAlreadyInUse = false;
  String emailUid = 'fake-email-uid';

  /// Retraso artificial en linkWithEmail (para reproducir el bug
  /// del doble toque en el OTP: mientras el enlace va por la red,
  /// el botón CONTINUAR debe seguir deshabilitado).
  Duration linkEmailDelay = Duration.zero;

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
  Future<bool> linkWithEmail(String email, String password) async {
    if (linkEmailDelay > Duration.zero) {
      await Future.delayed(linkEmailDelay);
    }
    if (failLink) {
      lastEmailError = 'firebase_auth:unknown';
      return false;
    }
    if (uid == null) {
      final anon = await ensureAnonymous();
      if (anon == null) return false;
    }
    if (simulateEmailAlreadyInUse && emailAccounts.containsKey(email)) {
      // La cuenta de correo ya vive en otro uid + FALLBACK: si la
      // contraseña que se escribió no es la de esa cuenta, el
      // fallback falla y el motivo que queda es que el correo ya
      // está tomado (el diálogo del correo ya tomado); si es la
      // suya, se entra en ella (el uid pasa a ser emailUid).
      if (emailAccounts[email] != password) {
        lastEmailError = 'firebase_auth:email-already-in-use';
        return false;
      }
      lastEmailError = 'firebase_auth:email-already-in-use';
      uid = emailUid;
      emailLinked = true;
      this.email = email;
      return true;
    }
    emailAccounts[email] = password;
    emailLinked = true;
    lastEmailError = null;
    this.email = email;
    return true;
  }

  /// Enlaza correo+contraseña a la sesión actual SIN cambiar de
  /// cuenta (igual que el real): si el correo ya vive en otra
  /// cuenta ([simulateEmailAlreadyInUse] y registrado), devuelve
  /// false y el uid NO cambia. Sin sesión, false.
  @override
  Future<bool> linkPassword(String email, String password) async {
    if (uid == null) {
      lastEmailError = 'email:no-user';
      return false;
    }
    if (simulateEmailAlreadyInUse && emailAccounts.containsKey(email)) {
      lastEmailError = 'firebase_auth:email-already-in-use';
      return false;
    }
    emailAccounts[email] = password;
    emailLinked = true;
    lastEmailError = null;
    this.email = email;
    return true;
  }

  @override
  Future<bool> signInWithEmail(String email, String password) async {
    if (emailAccounts[email] != password) {
      lastEmailError = 'firebase_auth:invalid-credential';
      return false;
    }
    uid = emailUid;
    emailLinked = true;
    lastEmailError = null;
    this.email = email;
    return true;
  }

  @override
  Future<bool> sendPasswordResetEmail(String email) async {
    resetEmailsSent.add(email.trim().toLowerCase());
    lastEmailError = null;
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

  /// Cierra la sesión en el falso: se va Google/correo y se
  /// vuelve a un anónimo nuevo (como el real tras signOut +
  /// ensureAnonymous).
  @override
  Future<void> signOut() async {
    googleLinked = false;
    emailLinked = false;
    email = null;
    displayName = null;
    uid = 'fake-anon-uid';
  }

  @override
  AuthUserInfo? get currentUser => uid == null
      ? null
      : AuthUserInfo(
          uid: uid!,
          email: email,
          displayName: displayName,
          googleLinked: googleLinked,
          emailLinked: emailLinked,
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

  /// Aviso de cambio de sesión (link / inicio / unlink): la UI
  /// Premium (diamante flotante) lo escucha para aparecer o
  /// desaparecer sin tener que cambiar de pestaña. Solo sube; el
  /// valor de verdad se lee en [isGoogleLinked]/[isEmailLinked].
  /// Cambio 6 (2026-11-15): el diamante solo le sale a quien
  /// inició sesión.
  static final ValueNotifier<int> authVersion = ValueNotifier<int>(0);

  static void _bumpAuthVersion() => authVersion.value++;

  /// Código del último fallo de Google (o null si el último intento
  /// salió bien). La UI lo enseña junto al mensaje genérico para
  /// diagnosticar por qué ni siquiera salió el selector (Quemia 7.3).
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

  /// Código del último fallo de correo (o null si el último intento
  /// salió bien): lo pone el proveedor ('firebase_auth:…' /
  /// 'email:…'). La UI lo enseña junto al mensaje genérico para
  /// diagnosticar (igual que [lastGoogleError]).
  static String? _lastEmailError;

  static String? get lastEmailError => _lastEmailError;

  /// ¿La sesión actual tiene correo+contraseña enlazado?
  static bool get isEmailLinked {
    try {
      return _provider.currentUser?.emailLinked ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Correo de la cuenta enlazada (Google o correo+contraseña).
  static String? get accountEmail {
    try {
      return _provider.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  /// Enlaza correo+contraseña a la sesión anónima (el uid NO cambia
  /// si el enlace directo funciona; SI cambia con el fallback
  /// cuando la cuenta ya vive en otro uid: se entra en ella y se
  /// migra el progreso del anónimo). NUNCA lanza: true = OK, false
  /// = falló. La UI muestra el mensaje genérico + [lastEmailError]
  /// cuando devuelve false.
  static Future<bool> linkWithEmail(String email, String password) {
    return _runEmailAuth(() => _provider.linkWithEmail(email, password),
        email: email);
  }

  /// Enlaza correo+contraseña a la sesión actual SIN cambiar de
  /// cuenta (Kristian 2026-11-15: ponerle contraseña a una cuenta
  /// de Google). NUNCA lanza: true = OK, false = falló (ver
  /// [lastEmailError]). A diferencia de [linkWithEmail], aquí no
  /// hay fallback ni migración: el uid no se toca.
  static Future<bool> linkPassword(String email, String password) async {
    try {
      final ok = await _provider.linkPassword(email, password);
      _lastEmailError = _provider.lastEmailError;
      if (ok) {
        _bumpAuthVersion();
        // Índice de correos: ponerle contraseña a una cuenta prueba
        // que ya la tiene.
        _recordEmailIndex(email, hasPassword: true);
      }
      return ok;
    } catch (_) {
      _lastEmailError = 'unknown';
      return false;
    }
  }

  /// Entra con correo+contraseña. NUNCA lanza: true = OK, false =
  /// falló (ver [lastEmailError]). Si había progreso anónimo en
  /// este teléfono, también se migra al uid de la cuenta.
  static Future<bool> signInWithEmail(String email, String password) {
    return _runEmailAuth(() => _provider.signInWithEmail(email, password),
        email: email);
  }

  /// Manda el enlace de Firebase para cambiar la contraseña.
  /// NUNCA lanza: true = OK, false = falló (ver [lastEmailError]).
  /// No mueve el uid ni migra nada (solo manda el correo).
  static Future<bool> sendPasswordResetEmail(String email) async {
    try {
      final ok = await _provider.sendPasswordResetEmail(email);
      _lastEmailError = _provider.lastEmailError;
      return ok;
    } catch (_) {
      _lastEmailError = 'unknown';
      return false;
    }
  }

  /// Registra el correo en el índice de correos (Kristian
  /// 2026-11-15): para avisar "correo ya tomado" antes de pedir la
  /// contraseña. En segundo plano, nunca bloquea el inicio ni
  /// lanza: si no hay internet, la entrada se escribe la próxima
  /// vez que se entre. [hasPassword] solo se pasa cuando se sabe
  /// (entrar con correo prueba que la tiene); con Google lo anota
  /// [EmailIndex.recordGoogle] (false, sin bajar de true).
  static void _recordEmailIndex(String email, {bool? hasPassword}) {
    final uid = currentUid;
    if (uid == null || uid.isEmpty) return;
    unawaited(EmailIndex.record(
        email: email, uid: uid, hasPassword: hasPassword));
  }

  /// Núcleo común de link/signIn con correo: igual que
  /// [_runGoogleAuth] (recoge el error real del proveedor y, si el
  /// uid cambió, migra el progreso del anónimo al uid nuevo antes
  /// de dar el inicio por bueno).
  static Future<bool> _runEmailAuth(Future<bool> Function() attempt,
      {String? email}) async {
    final uidBefore = currentUid;
    bool ok;
    try {
      ok = await attempt();
    } catch (_) {
      _lastEmailError = 'unknown';
      return false;
    }
    _lastEmailError = _provider.lastEmailError;
    if (!ok) return false;
    final uidAfter = currentUid;
    if (uidAfter != null &&
        uidBefore != null &&
        uidBefore.isNotEmpty &&
        uidAfter != uidBefore &&
        migrateProgressOnUidChange != null) {
      final migrated = await migrateProgressOnUidChange!(uidBefore, uidAfter);
      if (!migrated) {
        _lastEmailError = 'migration_failed';
        return false;
      }
    }
    _bumpAuthVersion();
    // Índice de correos: entrar con correo prueba que la cuenta
    // tiene contraseña.
    if (email != null) _recordEmailIndex(email, hasPassword: true);
    return true;
  }

  /// Núcleo común de link/signIn: corre el intento, recoge el error
  /// real del proveedor y, si el uid cambió, migra el progreso del
  /// anónimo al uid nuevo antes de dar el inicio por bueno.
  static Future<bool> _runGoogleAuth(Future<bool> Function() attempt) async {
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
      final migrated = await migrateProgressOnUidChange!(uidBefore, uidAfter);
      if (!migrated) {
        // La sesión ya es la de Google, pero la fusión en la nube
        // no se pudo hacer: se da por fallido con motivo claro.
        // El progreso LOCAL sigue intacto (no depende del uid) y
        // la próxima subida con force lo vuelve a intentar.
        _lastGoogleError = 'migration_failed';
        return false;
      }
    }
    _bumpAuthVersion();
    // Índice de correos: una cuenta de Google no tiene contraseña
    // (salvo que ya la tuviera de antes: recordGoogle no baja de
    // true a false).
    final googleEmail = accountEmail;
    final uid = currentUid;
    if (googleEmail != null && uid != null && uid.isNotEmpty) {
      unawaited(EmailIndex.recordGoogle(email: googleEmail, uid: uid));
    }
    return true;
  }

  /// Desvincula Google de la sesión actual. Tampoco lanza nunca.
  static Future<bool> unlinkGoogle() async {
    try {
      final ok = await _provider.unlinkGoogle();
      if (ok) _bumpAuthVersion();
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Cierra la sesión (2026-11-16, Kristian: botón en Cuenta).
  /// Se va Google/correo y se vuelve a entrar como invitado
  /// (anónimo nuevo): el progreso LOCAL se queda en el teléfono
  /// y la nube de la cuenta vieja queda intacta; al volver a
  /// entrar con la misma cuenta de Google, la migración best-of
  /// lo restaura. Devuelve true si quedó como invitado. NUNCA
  /// lanza.
  static Future<bool> signOut() async {
    try {
      await _provider
          .signOut()
          .timeout(const Duration(seconds: 5), onTimeout: () {});
    } catch (_) {}
    final anon = await ensureAnonymous();
    _bumpAuthVersion();
    return anon != null;
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
    authVersion.value = 0;
  }
}
