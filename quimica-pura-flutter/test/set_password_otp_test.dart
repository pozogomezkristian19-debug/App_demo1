// Crear contraseña con OTP, sin correo de restablecer (Kristian
// 2026-11-16): en la pantalla de correo tomado, PONERLE UNA
// CONTRASEÑA pide un OTP al correo para comprobar que la cuenta
// es de uno, después se entra con Google (Firebase solo deja
// ponerle contraseña a quien tenga la sesión abierta como dueño)
// y después se crea la contraseña DENTRO de la app, en la
// pantalla CREA TU CONTRASEÑA. El correo de restablecer de
// Firebase DESAPARECE de este flujo: no se manda ningún enlace
// en ningún paso.
//
// Con contraseña, la pantalla de crearla NUNCA se ofrece (ni en
// correo tomado ni en Cuenta — eso lo cubren
// registration_email_taken_test y fix9_account_password_test).
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
import 'package:quimica_pura/widgets/duo_button.dart';
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

  /// Camina hasta la pantalla de correo tomado (sin contraseña),
  /// con la cuenta de Google que se va a elegir ya fijada.
  Future<void> goToTakenPage(WidgetTester tester) async {
    await repo.setDoc('emails', 'jorge@example.com',
        {'uid': 'other-uid', 'hasPassword': false});
    await goToRegisterPage(tester);
    await tester.tap(find.text(tr('obRegisterEmail').toUpperCase()));
    await tester.pumpAndSettle();
    await enterHint(tester, tr('obEmailFieldHint'), 'jorge@example.com');
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr('obTakenTitle')), findsOneWidget);
    expect(find.text(tr('obTakenNoPasswordBody')), findsOneWidget);
  }

  Future<void> enterOtp(WidgetTester tester, String code) async {
    final boxes = find.byType(TextField);
    expect(boxes, findsNWidgets(6));
    for (var i = 0; i < 6; i++) {
      await tester.enterText(boxes.at(i), code[i]);
    }
    await tester.pumpAndSettle();
  }

  /// Del OTP a la pantalla CREA TU CONTRASEÑA (con la cuenta de
  /// Google ya fijada en el falso).
  Future<void> goToSetPasswordPage(WidgetTester tester) async {
    await tester.tap(find.text(tr('obTakenSetPassword').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr('obSetPasswordOtpTitle')), findsOneWidget);
    await enterOtp(tester, '123456');
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr('obSetPasswordGoogleTitle')), findsOneWidget);
    await tester.tap(find.text(tr('obEmailTakenGoogle').toUpperCase()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(AuthService.isGoogleLinked, isTrue);
    expect(find.text(tr('obPasswordTitle')), findsOneWidget);
  }

  group('correo tomado sin contraseña: OTP → Google → crear contraseña',
      () {
    testWidgets('camino feliz: se crea dentro de la app y se sigue al usuario',
        (tester) async {
      // La cuenta de Google que se va a elegir es la del correo tomado.
      fakeAuth.email = 'jorge@example.com';
      fakeAuth.displayName = 'Jorge';
      await goToTakenPage(tester);
      await tester.tap(find.text(tr('obTakenSetPassword').toUpperCase()));
      await tester.pumpAndSettle();
      // 1) OTP al correo, sin correo de restablecer.
      expect(find.text(tr('obSetPasswordOtpTitle')), findsOneWidget);
      expect(find.text('jorge@example.com'), findsOneWidget);
      expect(
        fakeOtp.lastCode('jorge@example.com', OtpPurpose.setPassword),
        '123456',
      );
      expect(fakeAuth.resetEmailsSent, isEmpty);
      await enterOtp(tester, '123456');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      // 2) Entrar con Google para confirmar que la cuenta es suya.
      expect(find.text(tr('obSetPasswordGoogleTitle')), findsOneWidget);
      expect(find.textContaining('jorge@example.com'), findsOneWidget);
      await tester.tap(find.text(tr('obEmailTakenGoogle').toUpperCase()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(AuthService.isGoogleLinked, isTrue);
      // 3) CREA TU CONTRASEÑA dentro de la app.
      expect(find.text(tr('obPasswordTitle')), findsOneWidget);
      expect(find.text('jorge@example.com'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Secreto123!');
      await tester.pump();
      await tester.tap(
        find.text(tr('accountSetPasswordSave').toUpperCase()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // La contraseña quedó puesta y se sigue como si se hubiera
      // entrado con Google: "Ya has iniciado sesión" → usuario.
      expect(AuthService.isEmailLinked, isTrue);
      expect(fakeAuth.resetEmailsSent, isEmpty);
      final doc = await repo.getDoc('emails', 'jorge@example.com');
      expect(doc, isNotNull);
      expect(doc!['hasPassword'], isTrue);
      expect(find.text('Jorge'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      expect(find.text(tr('obReferralTitle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OTP incorrecto: error y no se avanza', (tester) async {
      await goToTakenPage(tester);
      await tester.tap(find.text(tr('obTakenSetPassword').toUpperCase()));
      await tester.pumpAndSettle();
      await enterOtp(tester, '000000');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obOtpInvalid')), findsOneWidget);
      expect(find.text(tr('obSetPasswordOtpTitle')), findsOneWidget);
      expect(find.text(tr('obSetPasswordGoogleTitle')), findsNothing);
      expect(AuthService.isEmailLinked, isFalse);
      expect(AuthService.isGoogleLinked, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el error se limpia en cuanto se escribe un código nuevo',
        (tester) async {
      await goToTakenPage(tester);
      await tester.tap(find.text(tr('obTakenSetPassword').toUpperCase()));
      await tester.pumpAndSettle();
      await enterOtp(tester, '000000');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obOtpInvalid')), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '1');
      await tester.pump();
      expect(find.text(tr('obOtpInvalid')), findsNothing);
      expect(find.text(tr('obSetPasswordOtpTitle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Google con otro correo: vuelve a la pantalla de tomado con el aviso',
        (tester) async {
      // La cuenta de Google elegida NO es la del correo tomado.
      fakeAuth.email = 'otro@example.com';
      fakeAuth.displayName = 'Otro';
      await goToTakenPage(tester);
      await tester.tap(find.text(tr('obTakenSetPassword').toUpperCase()));
      await tester.pumpAndSettle();
      await enterOtp(tester, '123456');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obSetPasswordGoogleTitle')), findsOneWidget);
      await tester.tap(find.text(tr('obEmailTakenGoogle').toUpperCase()));
      await tester.pumpAndSettle();
      // De vuelta en la pantalla de correo tomado, con el aviso;
      // nunca se le puso la contraseña a otra cuenta.
      expect(find.text(tr('obTakenTitle')), findsOneWidget);
      expect(
        find.text(
          tr('obSetPasswordGoogleMismatch')
              .replaceFirst('%s', 'jorge@example.com'),
        ),
        findsOneWidget,
      );
      expect(find.text(tr('obPasswordTitle')), findsNothing);
      expect(AuthService.isEmailLinked, isFalse);
      expect(fakeAuth.resetEmailsSent, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la contraseña débil no deja guardar', (tester) async {
      fakeAuth.email = 'jorge@example.com';
      fakeAuth.displayName = 'Jorge';
      await goToTakenPage(tester);
      await goToSetPasswordPage(tester);
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      final save = tester.widget(
        find.ancestor(
          of: find.text(tr('accountSetPasswordSave').toUpperCase()),
          matching: find.byType(DuoButton),
        ),
      ) as DuoButton;
      expect(save.onPressed, isNull);
      expect(AuthService.isEmailLinked, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
