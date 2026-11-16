// Envío del OTP solo para la vista previa web (Kristian 2026-11-15).
//
// El Apps Script contesta el POST con un 302 hacia su servicio
// "echo", y el navegador sigue ese desvío con un GET que el echo
// rechaza o no deja leer (sin CORS): el POST normal siempre parece
// fallar aunque el correo ya se mandó. Con fetch en modo manual no
// se sigue el desvío: que el fetch se resuelva prueba que el
// servidor contestó, y el doPost ya mandó el correo antes de
// contestar el 302. No se lee la respuesta (no se puede), solo se
// comprueba que el servidor respondió.
//
// Solo existe en web: el móvil usa el POST normal de otp_service.dart.
import 'dart:async';
import 'dart:js_interop';

@JS('fetch')
external JSPromise<JSObject> _fetch(JSString url, JSObject init);

/// Manda [body] (JSON) a [url] con POST simple (text/plain, sin
/// preflight CORS) y sin seguir desvíos. true si el servidor
/// contestó (el correo se mandó); false si hubo fallo de red o
/// se agotó el tiempo.
Future<bool> postOtpNoFollow(String url, String body) async {
  try {
    final JSObject init = <String, Object?>{
      'method': 'POST',
      'headers': <String, String>{'Content-Type': 'text/plain'},
      'body': body,
      'redirect': 'manual',
    }.jsify() as JSObject;
    await _fetch(url.toJS, init).toDart.timeout(const Duration(seconds: 20));
    return true;
  } catch (_) {
    return false;
  }
}
