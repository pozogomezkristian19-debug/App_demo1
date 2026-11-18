// Registro por correo: correo tomado ANTES de la contraseña +
// pantalla entera de correo tomado + bug del OTP "error y luego
// avanza" (Kristian 2026-11-15, confirmación "Sí" 23:02):
//   1) justo después del paso del correo, la app consulta el
//      índice propio de correos (Firestore, colección 'emails')
//      y dice ahí mismo si ya está cogido — antes de pedir la
//      contraseña. Firebase no lo dice (protección de
//      enumeración), así que el índice es nuestro.
//   2) el aviso de correo tomado es una PANTALLA ENTERA, no un
//      cuadradito, y antes verifica si la cuenta ya tiene
//      contraseña: con contraseña ofrece entrar (nunca ponerle
//      una de nuevo); sin contraseña ofrece entrar con Google o
//      ponerle una (OTP, no enlace de restablecimiento — Kristian
//      2026-11-16: el código confirma que el correo es suyo y la
//      contraseña se crea después dentro de la app).
//   3) OTP: un código correcto NUNCA muestra error ni avanza dos
//      veces; uno incorrecto NUNCA avanza; el error se limpia en
//      cuanto se escribe un código nuevo. Causa raíz del bug:
//      _busy se soltaba antes de enlazar la cuenta, así que un
//      segundo toque volvía a comprobar el código ya consumido
//      ("incorrecto") mientras la primera comprobación avanzaba.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/otp_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadNunitoFonts();
  });

  late FakeAuthProvider fakeAuth;
  late FakeOtpTransport fakeOtp;
  late InMemoryAnalyticsRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (call) async => null,
    );
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
    UserPrefs.isDark = false;
    UserPrefs.onboardingDone = true;
    UserPrefs.userName = 'kristian';
    UserPrefs.publicUsername = '';
    AppLang.code = 'es';
    fakeAuth = FakeAuthProvider();
    AuthService.setProviderForTests(fakeAuth);
    repo = InMemoryAnalyticsRepository();
    AnalyticsSync.setRepositoryForTests(repo);
    fakeOtp = FakeOtpTransport();
    OtpService.setTransportForTests(fakeOtp);
  });

  tearDown(() {
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    OtpService.resetForTests();
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    UserPrefs.userName = '';
    UserPrefs.publicUsername = '';
  });

  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> goToRegisterPage(WidgetTester tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onFinished: () {})),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obCreateProfile').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obVamos').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obSourceInstagram')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obLevel1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obGoal10')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obGoalSave').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obNotifEnable').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text('Ir a Ajustes'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    // Widget (2026-11-18): tras las notificaciones va la pantalla
    // del widget; con MÁS TARDE se sigue a la racha.
    await tester.tap(find.text(tr('obWidgetLater').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obStreakStart').toUpperCase()));
    await tester.pumpAndSettle();
    // Aviso "¡No pierdas tu progreso!" (Duolingo) antes del registro.
    expect(find.text(tr('obNudgeTitle')), findsOneWidget);
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr('obRegisterTitle')), findsOneWidget);
  }

  Future<void> enterHint(
      WidgetTester tester, String hint, String text) async {
    await tester.enterText(
      find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == hint),
      text,
    );
    await tester.pumpAndSettle();
  }

  /// Entra en el flujo del correo y escribe el correo (sin pulsar
  /// CONTINUAR): el paso 0, donde va la comprobación temprana.
  Future<void> goToEmailStep(WidgetTester tester, String email) async {
    await goToRegisterPage(tester);
    await tester.tap(find.text(tr('obRegisterEmail').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr('obEmailTitle')), findsOneWidget);
    await enterHint(tester, tr('obEmailFieldHint'), email);
  }

  /// Camina el flujo del correo hasta "¿Cómo te llamas?" (correo
  /// -> contraseña -> nombre), sin pulsar CREAR PERFIL.
  Future<void> goToNameStep(WidgetTester tester) async {
    await goToEmailStep(tester, 'jorge@example.com');
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr('obPasswordTitle')), findsOneWidget);
    await enterHint(tester, tr('obPasswordHint'), 'Secreto123!');
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr('obNameTitle')), findsOneWidget);
  }

  /// Camina el flujo del correo hasta la pantalla del OTP
  /// (correo -> contraseña -> nombre -> CREAR PERFIL).
  Future<void> goToOtpStep(WidgetTester tester) async {
    await goToNameStep(tester);
    await enterHint(tester, tr('obFirstNameHint'), 'Jorge');
    await enterHint(tester, tr('obLastNameHint'), 'Pozo');
    await tester.tap(find.text(tr('obCreateProfile').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr('obOtpTitle')), findsOneWidget);
  }

  Future<void> enterOtp(WidgetTester tester, String code) async {
    final boxes = find.byType(TextField);
    expect(boxes, findsNWidgets(6));
    for (var i = 0; i < 6; i++) {
      await tester.enterText(boxes.at(i), code[i]);
    }
    await tester.pumpAndSettle();
  }

  group('correo tomado antes de la contraseña (índice de correos)', () {
    testWidgets(
        'correo tomado con contraseña: pantalla entera y "Entrar" abre el inicio con el correo puesto',
        (tester) async {
      await repo.setDoc('emails', 'jorge@example.com',
          {'uid': 'other-uid', 'hasPassword': true});
      await goToEmailStep(tester, 'jorge@example.com');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      // Se dice ahí mismo, ANTES de la contraseña: no se llegó al
      // paso de la contraseña.
      expect(find.text(tr('obPasswordTitle')), findsNothing);
      // Pantalla entera, no un cuadradito.
      expect(find.text(tr('obTakenTitle')), findsOneWidget);
      expect(find.text(tr('obTakenHasPasswordBody')), findsOneWidget);
      expect(find.text('jorge@example.com'), findsOneWidget);
      // Con contraseña NO se ofrece ponerle una (sería pedirlo de
      // nuevo): se ofrece entrar.
      expect(
          find.text(tr('obTakenSetPassword').toUpperCase()), findsNothing);
      expect(find.text(tr('obTakenSignIn').toUpperCase()), findsOneWidget);
      expect(
          find.text(tr('obEmailTakenGoogle').toUpperCase()), findsOneWidget);
      await tester.tap(find.text(tr('obTakenSignIn').toUpperCase()));
      await tester.pumpAndSettle();
      // El inicio de sesión trae el correo ya puesto.
      expect(find.text(tr('obSignInTitle')), findsOneWidget);
      expect(find.text('jorge@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'correo tomado sin contraseña: ofrece Google o ponerle una, y ponerle una pide un OTP (sin correo de restablecer)',
        (tester) async {
      await repo.setDoc('emails', 'jorge@example.com',
          {'uid': 'other-uid', 'hasPassword': false});
      await goToEmailStep(tester, 'jorge@example.com');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obPasswordTitle')), findsNothing);
      expect(find.text(tr('obTakenTitle')), findsOneWidget);
      expect(find.text(tr('obTakenNoPasswordBody')), findsOneWidget);
      // Sin contraseña NO se ofrece entrar con el correo (no tiene
      // con qué entrar): Google o ponerle una.
      expect(find.text(tr('obTakenSignIn').toUpperCase()), findsNothing);
      expect(
          find.text(tr('obTakenSetPassword').toUpperCase()), findsOneWidget);
      expect(
          find.text(tr('obEmailTakenGoogle').toUpperCase()), findsOneWidget);
      await tester.tap(find.text(tr('obTakenSetPassword').toUpperCase()));
      await tester.pumpAndSettle();
      // OTP, no correo de restablecer (Kristian 2026-11-16): el
      // código se manda al correo con el servicio OTP y la
      // contraseña se crea después dentro de la app.
      expect(find.text(tr('obSetPasswordOtpTitle')), findsOneWidget);
      expect(find.text('jorge@example.com'), findsOneWidget);
      expect(
        fakeOtp.lastCode('jorge@example.com', OtpPurpose.setPassword),
        '123456',
      );
      expect(fakeAuth.resetEmailsSent, isEmpty);
      expect(find.text(tr('obResetLinkSent')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('correo libre: sigue al paso de contraseña', (tester) async {
      await goToEmailStep(tester, 'libre@example.com');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obTakenTitle')), findsNothing);
      expect(find.text(tr('obPasswordTitle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'sin conexión (el índice no se puede leer): se sigue normal a la contraseña',
        (tester) async {
      await goToRegisterPage(tester);
      repo.failAll = true;
      await tester.tap(find.text(tr('obRegisterEmail').toUpperCase()));
      await tester.pumpAndSettle();
      await enterHint(tester, tr('obEmailFieldHint'), 'jorge@example.com');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      // La comprobación falló en silencio: se sigue como antes y
      // el aviso tardío del enlace queda como red de seguridad.
      expect(find.text(tr('obTakenTitle')), findsNothing);
      expect(find.text(tr('obPasswordTitle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('OTP: error y luego avanza (causa raíz)', () {
    testWidgets('OTP correcto: no muestra error y avanza una sola vez',
        (tester) async {
      await goToOtpStep(tester);
      await enterOtp(tester, '123456');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obOtpInvalid')), findsNothing);
      expect(find.text(tr('obOtpTitle')), findsNothing);
      expect(AuthService.isEmailLinked, isTrue);
      expect(find.text(tr('obReferralTitle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OTP incorrecto: error y no se avanza', (tester) async {
      await goToOtpStep(tester);
      await enterOtp(tester, '000000');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obOtpInvalid')), findsOneWidget);
      expect(find.text(tr('obOtpTitle')), findsOneWidget);
      expect(AuthService.isEmailLinked, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el error se limpia en cuanto se escribe un código nuevo',
        (tester) async {
      await goToOtpStep(tester);
      await enterOtp(tester, '000000');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obOtpInvalid')), findsOneWidget);
      // Se escribe un dígito nuevo: el error viejo se va.
      await tester.enterText(find.byType(TextField).at(0), '1');
      await tester.pump();
      expect(find.text(tr('obOtpInvalid')), findsNothing);
      expect(find.text(tr('obOtpTitle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'doble toque mientras el enlace va por la red: no sale error y se avanza una sola vez',
        (tester) async {
      // El enlace tarda 5 s: antes del arreglo, el botón se
      // reactivaba en ese rato y el segundo toque volvía a
      // comprobar el código ya consumido ("incorrecto") mientras
      // la primera comprobación avanzaba.
      fakeAuth.linkEmailDelay = const Duration(seconds: 5);
      await goToOtpStep(tester);
      await enterOtp(tester, '123456');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pump();
      await tester.pump();
      // La pantalla del OTP sigue ahí, con el botón deshabilitado.
      expect(find.text(tr('obOtpTitle')), findsOneWidget);
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(tr('obOtpInvalid')), findsNothing);
      expect(find.text(tr('obReferralTitle')), findsOneWidget);
      expect(AuthService.isEmailLinked, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('el índice se llena al crear/enlazar', () {
    testWidgets(
        'tras enlazar con correo, el índice tiene el correo con hasPassword true',
        (tester) async {
      await goToOtpStep(tester);
      await enterOtp(tester, '123456');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obReferralTitle')), findsOneWidget);
      final doc = await repo.getDoc('emails', 'jorge@example.com');
      expect(doc, isNotNull);
      expect(doc!['hasPassword'], isTrue);
      expect(doc['uid'], isNotEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'tras enlazar con Google, el índice tiene el correo con hasPassword false',
        (tester) async {
      await goToRegisterPage(tester);
      await AuthService.linkWithGoogle();
      await tester.pumpAndSettle();
      final doc = await repo.getDoc('emails', 'test@example.com');
      expect(doc, isNotNull);
      expect(doc!['hasPassword'], isFalse);
      expect(doc['uid'], isNotEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
