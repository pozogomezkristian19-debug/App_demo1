/// Códigos OTP por correo (Quemia 7.7, Kristian): el registro con
/// correo pide correo+contraseña y después un código de 6 dígitos que
/// llega al correo.
///
/// Firebase Auth NO manda códigos de 6 dígitos (manda enlaces), así
/// que el código lo manda el Gmail de Kristian por una aplicación
/// web de Google Apps Script ("Quemia OTP", en su cuenta): la app
/// GENERA el código, lo guarda EN EL TELÉFONO (30 minutos, 5
/// intentos; sobrevive si la app se cierra o se apaga el teléfono)
/// y le pide al script que lo mande; la app lo comprueba también
/// en el teléfono. El script solo envía — nunca genera ni verifica
/// nada. Gratis, sin tarjeta, unas 100 al día (límite de
/// Gmail por Apps Script). La contraseña de su Gmail NUNCA entra en
/// la app: el script la usa en el servidor de Google y la app solo
/// conoce la URL del script + una clave compartida.
///
/// Olvidar contraseña ya NO usa OTP: Firebase manda su enlace
/// gratis (AuthService.sendPasswordResetEmail). Ponerle una
/// contraseña a una cuenta de Google SÍ usa OTP (propósito
/// [OtpPurpose.setPassword]): el código confirma que el correo es
/// suyo y después la contraseña se crea DENTRO de la app, sin
/// ningún correo de restablecer (Kristian 2026-11-16).
///
/// La versión con Cloud Function (functions/index.js) sigue en este
/// archivo como alternativa, pero NO es la que se usa: desplegarla
/// necesitaría Blaze. En los tests se inyecta [FakeOtpTransport].
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'otp_web_fetch_stub.dart'
    if (dart.library.js_interop) 'otp_web_fetch.dart' as web_fetch;

/// Para qué es el código: registro, ponerle una contraseña a una
/// cuenta de Google, o recuperación de contraseña.
enum OtpPurpose {
  /// Registro con correo: el código confirma que el correo es suyo
  /// antes de crear la cuenta.
  register,

  /// Ponerle una contraseña a una cuenta creada con Google (sin
  /// contraseña): el código confirma que el correo es suyo antes
  /// de dejarle crearla dentro de la app, SIN el correo de
  /// restablecer de Firebase (Kristian 2026-11-16).
  setPassword,

  /// Recuperación: YA NO USA OTP (olvidar contraseña usa el enlace
  /// gratis de Firebase). El valor queda por compatibilidad con el
  /// transporte viejo.
  reset,
}

extension on OtpPurpose {
  String get apiValue => switch (this) {
        OtpPurpose.register => 'register',
        OtpPurpose.setPassword => 'setPassword',
        OtpPurpose.reset => 'reset',
      };
}

/// Resultado de comprobar un código: la UI lo usa para decirle al
/// usuario QUÉ pasó en vez de un genérico "incorrecto".
enum OtpVerifyResult {
  /// El código es correcto (y se consume: no vale otra vez).
  valid,

  /// El código no coincide con el guardado.
  wrong,

  /// El código caducó: hay que pedir uno nuevo.
  expired,

  /// Se agotaron los 5 intentos: el código se borró, hay que pedir
  /// uno nuevo.
  exhausted,

  /// No hay ningún código pendiente para ese correo (nunca se
  /// mandó, ya se usó, o la app se reinstaló).
  missing,
}

/// Transporte del OTP: la app solo pide y verifica; el código lo
/// genera y lo guarda el servidor. Inyectable para los tests.
abstract class OtpTransport {
  /// Pide al servidor que genere un código y lo mande al correo.
  /// true si el servidor lo aceptó.
  Future<bool> sendCode(String email, OtpPurpose purpose);

  /// Comprueba el código. Devuelve por qué falló cuando no es
  /// válido, para que la UI lo diga claro en vez de "incorrecto".
  Future<OtpVerifyResult> verifyCode(
      String email, String code, OtpPurpose purpose);

  /// Cambia la contraseña de la cuenta tras verificar el código
  /// (solo para [OtpPurpose.reset]). true si quedó cambiada.
  Future<bool> resetPassword(String email, String code, String newPassword);
}

/// Transporte real: Cloud Functions por HTTPS (POST JSON, respuesta
/// JSON `{ok: true/false}`). Con el paquete `http` (no HttpClient
/// de dart:io) para que también compile en la vista previa web del
/// inicio: en web no existe dart:io.
class CloudFunctionOtpTransport implements OtpTransport {
  CloudFunctionOtpTransport({String? baseUrl, http.Client? client})
      : _baseUrl = baseUrl ?? kOtpFunctionBaseUrl,
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// URL base de las funciones OTP (2nd gen, us-central1). Se
  /// actualiza aquí cuando se despliegue con otro nombre/región.
  static const kOtpFunctionBaseUrl =
      'https://us-central1-quemia-8410a.cloudfunctions.net';

  final String _baseUrl;
  final http.Client _client;

  /// true si el cliente es nuestro (lo cerramos nosotros); false
  /// si lo inyectó quien llama (lo cierra quien lo creó).
  final bool _ownsClient;

  static const _kTimeout = Duration(seconds: 20);

  Future<Map<String, dynamic>?> _post(
      String path, Map<String, dynamic> body) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_kTimeout);
      if (response.statusCode != 200) {
        debugPrint('[OTP] $path HTTP ${response.statusCode}.');
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded;
    } catch (e) {
      debugPrint('[OTP] $path falló: $e');
      return null;
    } finally {
      // El cliente inyectado por quien llama lo cierra quien lo
      // creó; el propio se cierra aquí.
      if (_ownsClient) _client.close();
    }
  }

  @override
  Future<bool> sendCode(String email, OtpPurpose purpose) async {
    final res = await _post('sendOtp', {
      'email': email,
      'purpose': purpose.apiValue,
    });
    return res?['ok'] == true;
  }

  @override
  Future<OtpVerifyResult> verifyCode(
      String email, String code, OtpPurpose purpose) async {
    final res = await _post('verifyOtp', {
      'email': email,
      'code': code,
      'purpose': purpose.apiValue,
    });
    return res?['ok'] == true ? OtpVerifyResult.valid : OtpVerifyResult.wrong;
  }

  @override
  Future<bool> resetPassword(
      String email, String code, String newPassword) async {
    final res = await _post('resetPasswordWithOtp', {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
    return res?['ok'] == true;
  }
}

/// Código pendiente (en el teléfono): expira a los 30 minutos y se
/// borra con 5 intentos fallidos. Se persiste en SharedPreferences
/// para que sobreviva si la app se cierra o se apaga el teléfono.
class _PendingCode {
  const _PendingCode({
    required this.code,
    required this.expiresAtMs,
    this.attempts = 0,
  });

  factory _PendingCode.fromJson(Map<String, dynamic> json) => _PendingCode(
        code: json['code'] as String? ?? '',
        expiresAtMs: (json['expiresAtMs'] as num?)?.toInt() ?? 0,
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      );

  final String code;
  final int expiresAtMs;
  final int attempts;

  Map<String, dynamic> toJson() => {
        'code': code,
        'expiresAtMs': expiresAtMs,
        'attempts': attempts,
      };

  _PendingCode withAttempt() => _PendingCode(
      code: code, expiresAtMs: expiresAtMs, attempts: attempts + 1);
}

/// Transporte real: Google Apps Script por HTTPS. La app genera el
/// código (6 dígitos, aleatorio seguro), lo guarda en el teléfono
/// (memoria + SharedPreferences, para que sobreviva si la app se
/// cierra) y le pide al script que lo mande desde el Gmail de
/// Kristian; la verificación también es local. El script solo envía.
///
/// El transporte es un singleton de [OtpService]: los códigos viven
/// en su mapa (memoria + guardado en el teléfono, así sobreviven
/// si la app se cierra); NO se crea una instancia nueva en cada
/// llamada.
class AppsScriptOtpTransport implements OtpTransport {
  AppsScriptOtpTransport({String? endpoint, String? token, http.Client? client})
      : _endpoint = endpoint ?? kAppsScriptOtpUrl,
        _token = token ?? kAppsScriptOtpToken,
        _client = client;

  /// URL de la aplicación web del script "Quemia OTP" (termina en
  /// /exec), desplegada 2026-11-14 08:04 en su cuenta.
  /// Mientras esté el marcador AUN_SIN_DESPLEGAR, mandar el código
  /// falla y la UI lo dice claro ("No se pudo mandar el código").
  static const kAppsScriptOtpUrl =
      'https://script.google.com/macros/s/AKfycbwUQ0dk5btxw1SOzeGOqg4V-7f__aIEInP7Gf2F82I44ZbXkKgtfczZomAIb9tbHB4/exec';

  /// Clave compartida con el script (la misma que lleva el Code.gs):
  /// solo prueba que quien llama es la app. NO es la contraseña de
  /// Gmail (esa nunca sale de Google).
  static const kAppsScriptOtpToken = 'bb272ff60c1ee931202e00546a86232e';

  static const _kTimeout = Duration(seconds: 20);

  /// El código vale 30 minutos (Kristian 2026-11-15: el correo no
  /// tardó; lo que fallaba era que el código se perdía al cerrar
  /// la app; 30 minutos dan margen sin dejarlo abierto mucho
  /// tiempo).
  static const _kCodeTtlMs = 30 * 60 * 1000;

  /// Intentos máximos antes de borrar el código.
  static const _kMaxAttempts = 5;

  /// Dónde se guardan los códigos pendientes (un solo JSON:
  /// correo|propósito → {code, expiresAtMs, attempts}).
  static const _kPendingPrefsKey = 'otp_pending_codes_v1';

  final String _endpoint;
  final String _token;

  /// Cliente inyectado (tests); null = `http.post` directo, que
  /// crea y cierra su propio cliente en cada llamada.
  final http.Client? _client;

  /// Códigos pendientes (clave: correo + propósito).
  final Map<String, _PendingCode> _pending = {};

  /// true cuando ya se cargaron los códigos guardados en el
  /// teléfono (una vez por instancia; el transporte es singleton).
  bool _persistedLoaded = false;

  /// Carga los códigos guardados en el teléfono (si la app se
  /// cerró después de mandar el código, ahí siguen). Los caducados
  /// también se cargan: así, al comprobarlos, la UI dice que
  /// caducaron en vez de "incorrecto". Si el guardado falla, se
  /// sigue solo con la memoria: el OTP no se rompe por eso.
  Future<void> _ensureLoaded() async {
    if (_persistedLoaded) return;
    _persistedLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) continue;
        _pending[entry.key] = _PendingCode.fromJson(value);
      }
    } catch (e) {
      debugPrint('[OTP] No se pudo leer el código guardado: $e');
    }
  }

  /// Guarda los códigos pendientes en el teléfono (después de
  /// cada cambio: mandar, fallar, caducar, usar). Los caducados se
  /// podan al guardar, para que no se acumulen. Si el guardado
  /// falla, se sigue solo con la memoria.
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final map = <String, dynamic>{
        for (final e in _pending.entries)
          if (e.value.expiresAtMs > now) e.key: e.value.toJson(),
      };
      await prefs.setString(_kPendingPrefsKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[OTP] No se pudo guardar el código: $e');
    }
  }

  String _key(String email, OtpPurpose purpose) =>
      '${email.trim().toLowerCase()}|${purpose.apiValue}';

  String _newCode() => (Random.secure().nextInt(900000) + 100000).toString();

  /// Pide al script que mande el código. true si el script lo
  /// aceptó. Apps Script ejecuta el doPost en la PRIMERA petición
  /// y responde 302 con la dirección del resultado (verificado en
  /// vivo 2026-11-14: el POST manda el correo y el GET a esa
  /// dirección devuelve {"ok":true}); por eso, si el POST devuelve
  /// una redirección, se sigue con un GET y se lee ESA respuesta.
  /// Si el GET falla, el 302 también vale como enviado: el correo
  /// ya se mandó en el POST, el GET solo trae el recibo.
  @override
  Future<bool> sendCode(String email, OtpPurpose purpose) async {
    if (_endpoint.contains('AUN_SIN_DESPLEGAR')) return false;
    // Antes de guardar el código nuevo, se cargan los que ya
    // había guardados: si no, al guardar se borrarían.
    await _ensureLoaded();
    final code = _newCode();
    bool sent;
    try {
      final uri = Uri.parse(_endpoint);
      final body = jsonEncode({
        'token': _token,
        'to': email.trim(),
        'code': code,
        'purpose': purpose.apiValue,
      });
      // CORS (vista previa web, Kristian 2026-11-15): en el
      // navegador, 'application/json' obliga al preflight CORS
      // (OPTIONS) y Apps Script no lo contesta, así que el POST
      // muere antes de llegar al script y el código nunca se
      // manda. Con 'text/plain' la petición es simple (sin
      // preflight) y el script lee el mismo cuerpo JSON crudo
      // (doPost hace JSON.parse del contenido, no mira el tipo).
      // En el móvil no cambia nada (ahí no hay CORS).
      if (kIsWeb) {
        // Web (vista previa, Kristian 2026-11-15): el navegador
        // sigue el 302 de Apps Script con un GET que el echo
        // rechaza o no deja leer (sin CORS), así que el POST
        // normal siempre parece fallar aunque el correo ya se
        // mandó. Con fetch en modo manual no se sigue el desvío:
        // que se resuelva prueba que el servidor contestó, y el
        // doPost ya mandó el correo antes de contestar el 302.
        sent = await web_fetch
            .postOtpNoFollow(uri.toString(), body)
            .timeout(_kTimeout);
      } else {
        const headers = {'Content-Type': 'text/plain'};
        final response = _client != null
            ? await _client
                .post(uri, headers: headers, body: body)
                .timeout(_kTimeout)
            : await http
                .post(uri, headers: headers, body: body)
                .timeout(_kTimeout);
        if (!_isRedirect(response.statusCode)) {
          if (response.statusCode != 200) {
            debugPrint('[OTP] Apps Script HTTP ${response.statusCode}.');
            return false;
          }
          // Si el cuerpo se lee y dice ok:false, el script lo rechazó
          // (clave mala, espera de 60 s, correo malo).
          sent = _bodySaysOk(response.body);
        } else {
          // Redirección: el correo ya se mandó en el POST; el GET a
          // la dirección trae el resultado del doPost.
          final location = response.headers['location'];
          if (location == null || location.isEmpty) {
            sent = true;
          } else {
            try {
              final follow = _client != null
                  ? await _client.get(Uri.parse(location)).timeout(_kTimeout)
                  : await http.get(Uri.parse(location)).timeout(_kTimeout);
              sent = follow.statusCode != 200 ? true : _bodySaysOk(follow.body);
            } catch (_) {
              sent = true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[OTP] Apps Script falló: $e');
      return false;
    }

    if (!sent) return false;
    _pending[_key(email, purpose)] = _PendingCode(
      code: code,
      expiresAtMs: DateTime.now().millisecondsSinceEpoch + _kCodeTtlMs,
    );
    await _save();
    return true;
  }

  /// ¿Este código es una redirección al resultado de Apps Script?
  static bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  /// ¿El cuerpo dice que el script aceptó el envío? Un cuerpo que
  /// no se puede leer (p. ej. una página de error) se toma como
  /// enviado: el correo ya se mandó en la primera petición.
  static bool _bodySaysOk(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['ok'] == false) {
        debugPrint('[OTP] Apps Script rechazó: ${decoded['error']}.');
        return false;
      }
    } catch (_) {
      // Cuerpo ilegible: el correo ya se mandó.
    }
    return true;
  }

  /// Comprueba el código contra el guardado en el teléfono (el
  /// guardado se carga si la app se había cerrado). Devuelve por
  /// qué falló para que la UI lo diga claro.
  @override
  Future<OtpVerifyResult> verifyCode(
      String email, String code, OtpPurpose purpose) async {
    await _ensureLoaded();
    final key = _key(email, purpose);
    final pending = _pending[key];
    if (pending == null) return OtpVerifyResult.missing;
    if (DateTime.now().millisecondsSinceEpoch > pending.expiresAtMs) {
      _pending.remove(key);
      await _save();
      return OtpVerifyResult.expired;
    }
    if (pending.attempts >= _kMaxAttempts) {
      _pending.remove(key);
      await _save();
      return OtpVerifyResult.exhausted;
    }
    if (pending.code != code.trim()) {
      final next = pending.withAttempt();
      if (next.attempts >= _kMaxAttempts) {
        _pending.remove(key);
        await _save();
        return OtpVerifyResult.exhausted;
      }
      _pending[key] = next;
      await _save();
      return OtpVerifyResult.wrong;
    }
    _pending.remove(key);
    await _save();
    return OtpVerifyResult.valid;
  }

  /// No existe con Apps Script: olvidar contraseña usa el enlace
  /// gratis de Firebase (AuthService.sendPasswordResetEmail).
  @override
  Future<bool> resetPassword(
      String email, String code, String newPassword) async {
    return false;
  }
}

/// Falso en memoria para los tests: guarda el código que "manda" y
/// lo verifica localmente. El código es siempre '123456' para que
/// los tests lo puedan escribir.
class FakeOtpTransport implements OtpTransport {
  /// Código que el falso usa siempre.
  static const kFakeCode = '123456';

  /// Códigos "mandados" (clave: correo + propósito).
  final Map<String, String> sentCodes = {};

  /// Si es true, sendCode falla (simula la función caída o sin
  /// desplegar).
  bool failSend = false;

  String _key(String email, OtpPurpose purpose) =>
      '${email.trim().toLowerCase()}|${purpose.apiValue}';

  /// Último código mandado a ese correo para ese propósito (o null).
  String? lastCode(String email, OtpPurpose purpose) =>
      sentCodes[_key(email, purpose)];

  @override
  Future<bool> sendCode(String email, OtpPurpose purpose) async {
    if (failSend) return false;
    sentCodes[_key(email, purpose)] = kFakeCode;
    return true;
  }

  @override
  Future<OtpVerifyResult> verifyCode(
      String email, String code, OtpPurpose purpose) async {
    final sent = sentCodes[_key(email, purpose)];
    if (sent == null) return OtpVerifyResult.missing;
    return sent == code ? OtpVerifyResult.valid : OtpVerifyResult.wrong;
  }

  @override
  Future<bool> resetPassword(
      String email, String code, String newPassword) async {
    return sentCodes[_key(email, OtpPurpose.reset)] == code;
  }
}

/// Fachada del OTP: la UI solo usa estos tres métodos. NUNCA lanza.
class OtpService {
  OtpService._();

  static OtpTransport? _transportOverride;

  /// Transporte de verdad (singleton: los códigos pendientes viven
  /// en su mapa en memoria; crear uno nuevo en cada llamada los
  /// perdería entre mandar y comprobar).
  static final OtpTransport _defaultTransport = AppsScriptOtpTransport();

  static OtpTransport get _transport => _transportOverride ?? _defaultTransport;

  /// Pide el código al correo. true si se mandó.
  static Future<bool> requestCode(String email, OtpPurpose purpose) async {
    try {
      return await _transport.sendCode(email, purpose);
    } catch (_) {
      return false;
    }
  }

  /// Comprueba el código. Devuelve el resultado (válido o por qué
  /// falló); si el transporte lanza, se toma como incorrecto.
  static Future<OtpVerifyResult> verifyCode(
      String email, String code, OtpPurpose purpose) async {
    try {
      return await _transport.verifyCode(email, code, purpose);
    } catch (_) {
      return OtpVerifyResult.wrong;
    }
  }

  /// Cambia la contraseña tras verificar el código (recuperación).
  /// true si quedó cambiada.
  static Future<bool> resetPassword(
      String email, String code, String newPassword) async {
    try {
      return await _transport.resetPassword(email, code, newPassword);
    } catch (_) {
      return false;
    }
  }

  /// Solo para tests: inyecta un transporte falso.
  @visibleForTesting
  static void setTransportForTests(OtpTransport transport) {
    _transportOverride = transport;
  }

  /// Solo para tests: vuelve al transporte real.
  @visibleForTesting
  static void resetForTests() {
    _transportOverride = null;
  }
}
