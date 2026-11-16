/// Transporte OTP por Apps Script (Quemia 7.7): la app genera el
/// código, el script lo manda desde el Gmail de Kristian y la app lo
/// verifica en el teléfono. Sin servidor propio, sin Blaze.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quimica_pura/services/otp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Cada prueba empieza sin códigos guardados en el teléfono.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppsScriptOtpTransport', () {
    late String capturedCode;
    late AppsScriptOtpTransport transport;

    setUp(() {
      capturedCode = '';
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        capturedCode = body['code'] as String;
        return http.Response('{"ok": true}', 200);
      });
      transport = AppsScriptOtpTransport(
        endpoint: 'https://script.google.com/macros/s/falso/exec',
        token: 'token-prueba',
        client: client,
      );
    });

    test('manda el código y lo verifica', () async {
      expect(
        await transport.sendCode('jorge@example.com', OtpPurpose.register),
        isTrue,
      );
      expect(capturedCode, hasLength(6));
      expect(
        await transport.verifyCode(
          'jorge@example.com',
          capturedCode,
          OtpPurpose.register,
        ),
        OtpVerifyResult.valid,
      );
      // Un código ya usado no vale otra vez.
      expect(
        await transport.verifyCode(
          'jorge@example.com',
          capturedCode,
          OtpPurpose.register,
        ),
        OtpVerifyResult.missing,
      );
    });

    test('un código malo no verifica', () async {
      await transport.sendCode('jorge@example.com', OtpPurpose.register);
      expect(
        await transport.verifyCode(
          'jorge@example.com',
          '000000',
          OtpPurpose.register,
        ),
        OtpVerifyResult.wrong,
      );
      // El bueno sigue valiendo después de un fallo.
      expect(
        await transport.verifyCode(
          'jorge@example.com',
          capturedCode,
          OtpPurpose.register,
        ),
        OtpVerifyResult.valid,
      );
    });

    test('5 intentos fallidos borran el código', () async {
      await transport.sendCode('jorge@example.com', OtpPurpose.register);
      for (var i = 0; i < 4; i++) {
        expect(
          await transport.verifyCode(
            'jorge@example.com',
            '000000',
            OtpPurpose.register,
          ),
          OtpVerifyResult.wrong,
        );
      }
      // El 5.º intento fallido agota el código.
      expect(
        await transport.verifyCode(
          'jorge@example.com',
          '000000',
          OtpPurpose.register,
        ),
        OtpVerifyResult.exhausted,
      );
      expect(
        await transport.verifyCode(
          'jorge@example.com',
          capturedCode,
          OtpPurpose.register,
        ),
        OtpVerifyResult.missing,
      );
    });

    test('el código es de otro correo no vale', () async {
      await transport.sendCode('jorge@example.com', OtpPurpose.register);
      expect(
        await transport.verifyCode(
          'otro@example.com',
          capturedCode,
          OtpPurpose.register,
        ),
        OtpVerifyResult.missing,
      );
    });

    test('si el script lo rechaza, no se guarda el código', () async {
      final refusing = AppsScriptOtpTransport(
        endpoint: 'https://script.google.com/macros/s/falso/exec',
        token: 'token-prueba',
        client: MockClient(
          (_) async => http.Response('{"ok": false}', 200),
        ),
      );
      expect(
        await refusing.sendCode('jorge@example.com', OtpPurpose.register),
        isFalse,
      );
      expect(
        await refusing.verifyCode(
          'jorge@example.com',
          '123456',
          OtpPurpose.register,
        ),
        OtpVerifyResult.missing,
      );
    });

    test('sin URL del script no manda nada', () async {
      final placeholder = AppsScriptOtpTransport(
        endpoint: 'https://script.google.com/macros/s/AUN_SIN_DESPLEGAR/exec',
        token: 'test-token',
      );
      expect(
        await placeholder.sendCode(
          'jorge@example.com',
          OtpPurpose.register,
        ),
        isFalse,
      );
    });

    test('resetPassword no existe con Apps Script', () async {
      expect(
        await transport.resetPassword(
          'jorge@example.com',
          '123456',
          'Nueva123!',
        ),
        isFalse,
      );
    });
  });

  group('Apps Script: redirección 302 (verificado en vivo 2026-11-14)', () {
    const endpoint = 'https://script.google.com/macros/s/falso/exec';
    const location = 'https://script.googleusercontent.com/macros/echo?x=1';

    /// Cliente que responde 302 al POST y lo que diga [getBody] al GET.
    MockClient redirectClient({String getBody = '{"ok": true}'}) {
      return MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response('', 302, headers: {'location': location});
        }
        return http.Response(getBody, 200);
      });
    }

    test('302 + GET {"ok": true} → el código se guarda y verifica', () async {
      String? code;
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          code = (jsonDecode(request.body) as Map)['code'] as String;
          return http.Response('', 302, headers: {'location': location});
        }
        return http.Response('{"ok": true}', 200);
      });
      final t = AppsScriptOtpTransport(
        endpoint: endpoint,
        token: 'test-token',
        client: client,
      );
      expect(
          await t.sendCode('jorge@example.com', OtpPurpose.register), isTrue);
      expect(
          await t.verifyCode('jorge@example.com', code!, OtpPurpose.register),
          OtpVerifyResult.valid);
    });

    test('302 + GET {"ok": false} → no se guarda el código', () async {
      final transport = AppsScriptOtpTransport(
        endpoint: endpoint,
        token: 'test-token',
        client: redirectClient(getBody: '{"ok": false, "error": "cooldown"}'),
      );
      expect(await transport.sendCode('jorge@example.com', OtpPurpose.register),
          isFalse);
    });

    test('302 sin dirección → se toma como enviado', () async {
      final transport = AppsScriptOtpTransport(
        endpoint: endpoint,
        token: 'test-token',
        client: MockClient((_) async => http.Response('', 302)),
      );
      expect(await transport.sendCode('jorge@example.com', OtpPurpose.register),
          isTrue);
    });
  });

  group('AppsScriptOtpTransport: el código sobrevive a cerrar la app', () {
    MockClient okClient(void Function(String code) onCode) {
      return MockClient((request) async {
        if (request.method == 'POST') {
          onCode((jsonDecode(request.body) as Map)['code'] as String);
        }
        return http.Response('{"ok": true}', 200);
      });
    }

    test('el código vale en otra instancia del transporte (reinicio)',
        () async {
      String code = '';
      final a = AppsScriptOtpTransport(
        endpoint: 'https://script.google.com/macros/s/falso/exec',
        token: 'token-prueba',
        client: okClient((c) => code = c),
      );
      expect(
        await a.sendCode('jorge@example.com', OtpPurpose.register),
        isTrue,
      );
      // Otra instancia (como tras cerrar y abrir la app): el
      // código sigue valiendo porque está guardado en el teléfono.
      final b = AppsScriptOtpTransport(
        endpoint: 'https://script.google.com/macros/s/falso/exec',
        token: 'token-prueba',
        client: okClient((_) {}),
      );
      expect(
        await b.verifyCode('jorge@example.com', code, OtpPurpose.register),
        OtpVerifyResult.valid,
      );
    });

    test('el código caducado dice que caducó', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'otp_pending_codes_v1',
          jsonEncode({
            'jorge@example.com|register': {
              'code': '654321',
              'expiresAtMs': DateTime.now().millisecondsSinceEpoch - 1000,
              'attempts': 0,
            },
          }));
      final transport = AppsScriptOtpTransport(
        endpoint: 'https://script.google.com/macros/s/falso/exec',
        token: 'token-prueba',
        client: okClient((_) {}),
      );
      expect(
        await transport.verifyCode(
          'jorge@example.com',
          '654321',
          OtpPurpose.register,
        ),
        OtpVerifyResult.expired,
      );
    });
  });
}
