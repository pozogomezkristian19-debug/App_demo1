/// Transporte OTP por Apps Script (Quemia 7.7): la app genera el
/// código, el script lo manda desde el Gmail de Kristian y la app lo
/// verifica en el teléfono. Sin servidor propio, sin Blaze.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quimica_pura/services/otp_service.dart';

void main() {
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
        isTrue,
      );
      // Un código ya usado no vale otra vez.
      expect(
        await transport.verifyCode(
          'jorge@example.com',
          capturedCode,
          OtpPurpose.register,
        ),
        isFalse,
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
        isFalse,
      );
      // El bueno sigue valiendo después de un fallo.
      expect(
        await transport.verifyCode(
          'jorge@example.com',
          capturedCode,
          OtpPurpose.register,
        ),
        isTrue,
      );
    });

    test('5 intentos fallidos borran el código', () async {
      await transport.sendCode('jorge@example.com', OtpPurpose.register);
      for (var i = 0; i < 5; i++) {
        expect(
          await transport.verifyCode(
            'jorge@example.com',
            '000000',
            OtpPurpose.register,
          ),
          isFalse,
        );
      }
      expect(
        await transport.verifyCode(
          'jorge@example.com',
          capturedCode,
          OtpPurpose.register,
        ),
        isFalse,
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
        isFalse,
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
        isFalse,
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
      expect(await t.sendCode('jorge@example.com', OtpPurpose.register),
          isTrue);
      expect(
          await t.verifyCode('jorge@example.com', code!, OtpPurpose.register),
          isTrue);
    });

    test('302 + GET {"ok": false} → no se guarda el código', () async {
      final transport = AppsScriptOtpTransport(
        endpoint: endpoint,
token: 'test-token',
        client: redirectClient(getBody: '{"ok": false, "error": "cooldown"}'),
      );
      expect(
          await transport.sendCode(
              'jorge@example.com', OtpPurpose.register),
          isFalse);
    });

    test('302 sin dirección → se toma como enviado', () async {
      final transport = AppsScriptOtpTransport(
        endpoint: endpoint,
token: 'test-token',
        client: MockClient(
            (_) async => http.Response('', 302)),
      );
      expect(
          await transport.sendCode(
              'jorge@example.com', OtpPurpose.register),
          isTrue);
    });
  });
}
