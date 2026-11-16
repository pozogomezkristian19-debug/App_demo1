/// Índice de correos registrados (Quemia 7.7, Kristian
/// 2026-11-15): el registro por correo tiene que avisar "ese correo
/// ya está tomado" ANTES de pedir la contraseña, pero Firebase Auth
/// NO dice si un correo existe (protección de enumeración: ni
/// fetchSignInMethodsForEmail lo revela). Así que la app guarda su
/// propio índice en Firestore:
///
///   colección 'emails', documento = correo en minúsculas,
///   campos: {uid, hasPassword?}
///
/// Solo lo necesario para la comprobación: ni nombres ni datos
/// personales. PRECIO HONESTO (Kristian lo pidió así): cualquiera
/// que adivine un correo y tenga sesión (hasta anónima) puede saber
/// si está registrado — la regla deja leer el documento a
/// cualquier sesión, como 'usernames' y 'referral_codes'.
///
/// Cómo se llena (sin Cloud Function: el plan es Spark):
///   - al enlazar con correo o al entrar con correo: hasPassword
///     = true (la fachada [AuthService] lo registra);
///   - al enlazar/entrar con Google: hasPassword = false (una
///     cuenta de Google no tiene contraseña), salvo que el índice
///     ya diga true — [recordGoogle] nunca baja de true a false;
///   - al ponerle contraseña a una cuenta (linkPassword): true;
///   - al abrir la app con sesión y correo (main): si la entrada
///     falta, se escribe — así las cuentas viejas, creadas antes
///     del índice, se van completando solas.
///
/// Límite honesto: si alguien pone contraseña por el enlace de
/// restablecimiento (página de Firebase, fuera de la app), el
/// índice no se entera hasta que esa persona entra con
/// correo+contraseña en la app; hasta entonces la pantalla de
/// correo tomado no ofrece "ponerle una contraseña" cuando no sabe
/// (ofrece entrar, que es lo seguro).
library;

import 'analytics_sync.dart';
import 'online_common.dart';

/// Una entrada del índice: a quién pertenece el correo y si se
/// sabe que tiene contraseña (null = no se sabe: el doc existe pero
/// nunca se registró ese dato).
class EmailIndexEntry {
  const EmailIndexEntry({required this.uid, this.hasPassword});

  final String uid;

  /// true = tiene contraseña; false = se creó con Google y no se
  /// le puso ninguna; null = no se sabe.
  final bool? hasPassword;
}

/// Índice de correos registrados en Firestore. NUNCA lanza: las
/// lecturas devuelven null si no se pudo comprobar y las escrituras
/// se pierden en silencio (el aviso tardío del enlace queda como
/// red de seguridad).
class EmailIndex {
  EmailIndex._();

  static const _collection = 'emails';

  static AnalyticsRepository get _repo => AnalyticsSync.repository;

  /// Correo normalizado: el id del documento (minúsculas, sin
  /// espacios). Dos correos que solo difieren en mayúsculas son el
  /// mismo documento.
  static String normalize(String email) => email.trim().toLowerCase();

  /// ¿Está cogido este correo? Devuelve la entrada si existe, o
  /// null si está libre, si no hay internet, si cuelga o si no hay
  /// permiso. Quien llama trata null como "no se sabe: se sigue
  /// normal" (el enlace al final lo dirá, como antes).
  static Future<EmailIndexEntry?> lookup(String email) async {
    final normalized = normalize(email);
    if (normalized.isEmpty || !normalized.contains('@')) return null;
    final doc = await OnlineCommon.call(
        () => _repo.getDoc(_collection, normalized));
    if (doc == null) return null;
    return EmailIndexEntry(
      uid: doc['uid'] as String? ?? '',
      hasPassword: doc['hasPassword'] as bool?,
    );
  }

  /// Registra (o actualiza) el correo de [uid] en el índice. Con
  /// merge: true, así escribir solo el uid no borra un hasPassword
  /// que ya estaba. Nunca lanza.
  static Future<void> record({
    required String email,
    required String uid,
    bool? hasPassword,
  }) async {
    final normalized = normalize(email);
    if (normalized.isEmpty || uid.isEmpty) return;
    final data = <String, dynamic>{'uid': uid};
    if (hasPassword != null) data['hasPassword'] = hasPassword;
    await OnlineCommon.write(
        () => _repo.setDoc(_collection, normalized, data));
  }

  /// Registra el correo de una cuenta de Google: una cuenta de
  /// Google NO tiene contraseña, salvo que el índice ya diga que
  /// sí (registro por correo y luego Google) — el índice nunca baja
  /// de true a false, porque la pantalla de correo tomado no debe
  /// ofrecer "ponerle una contraseña" a quien ya la tiene.
  /// Si la comprobación no se puede hacer (sin conexión), se anota
  /// false igualmente: el peor caso es ofrecer el enlace de
  /// restablecimiento, que sigue funcionando.
  static Future<void> recordGoogle({
    required String email,
    required String uid,
  }) async {
    try {
      final entry = await lookup(email);
      if (entry?.hasPassword == true) {
        await record(email: email, uid: uid);
      } else {
        await record(email: email, uid: uid, hasPassword: false);
      }
    } catch (_) {}
  }

  /// Auto-reparación: si la sesión actual tiene correo, escribe su
  /// entrada (solo uid) si falta. Para las cuentas creadas antes
  /// del índice. Nunca lanza.
  static Future<void> ensureIndexed({
    required String? email,
    required String? uid,
  }) async {
    if (email == null || email.isEmpty || uid == null || uid.isEmpty) {
      return;
    }
    await record(email: email, uid: uid);
  }
}
