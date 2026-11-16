// Registro: apellido obligatorio (Kristian 2026-11-15, "Sí" 22:38):
//   en "¿Cómo te llamas?" el botón CREAR PERFIL solo se activa con
//   Nombre Y Apellido (antes bastaba el nombre).
// La pantalla de elegir usuario SE QUITÓ del registro (Kristian
// 2026-11-16, lote de perfil — REVIERTE su orden del 2026-11-15
// que la pedía ahí): tras crear/enlazar la cuenta (correo o
// Google) el registro sigue DIRECTO al referido, sin pantalla de
// usuario y sin reclamar nada. UsernameChoicePage sigue viva
// (reutilizada en Cuenta, flujo "¡Completa tu perfil!"): sus
// tests de widget quedan, más los de los parámetros nuevos
// (prefillField, onSkip, onBack, título propio). El inicio de
// sesión ("Ya tengo una cuenta") tampoco lleva esta pantalla: esos
// usuarios ya tienen nombre. El invitado sigue pidiendo solo el
// nombre (sin apellido).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/otp_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/referral_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/duo_button.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';
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
    AnalyticsSync.setRepositoryForTests(InMemoryAnalyticsRepository());
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

  /// Camina el flujo del correo hasta "¿Cómo te llamas?" (correo
  /// -> contraseña -> nombre), sin pulsar CREAR PERFIL.
  Future<void> goToNameStep(WidgetTester tester) async {
    await goToRegisterPage(tester);
    await tester.tap(find.text(tr('obRegisterEmail').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr('obEmailTitle')), findsOneWidget);
    await enterHint(tester, tr('obEmailFieldHint'), 'jorge@example.com');
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

  DuoButton createProfileButton(WidgetTester tester) =>
      tester.widget<DuoButton>(find.byWidgetPredicate((w) =>
          w is DuoButton &&
          w.label == tr('obCreateProfile').toUpperCase()));

  group('apellido obligatorio (registro por correo)', () {
    testWidgets('solo con nombre el botón está deshabilitado',
        (tester) async {
      await goToNameStep(tester);
      await enterHint(tester, tr('obFirstNameHint'), 'Jorge');
      expect(createProfileButton(tester).onPressed, isNull);
      // Tocarlo no hace nada: se sigue en el nombre.
      await tester.tap(find.text(tr('obCreateProfile').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obNameTitle')), findsOneWidget);
      expect(find.text(tr('obOtpTitle')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con nombre y apellido el botón se activa y pide el OTP',
        (tester) async {
      await goToNameStep(tester);
      await enterHint(tester, tr('obFirstNameHint'), 'Jorge');
      expect(createProfileButton(tester).onPressed, isNull);
      await enterHint(tester, tr('obLastNameHint'), 'Pozo');
      expect(createProfileButton(tester).onPressed, isNotNull);
      await tester.tap(find.text(tr('obCreateProfile').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obOtpTitle')), findsOneWidget);
      expect(
          fakeOtp.lastCode('jorge@example.com', OtpPurpose.register), '123456');
      expect(tester.takeException(), isNull);
    });
  });

  group('sin pantalla de usuario en el registro (lote 2026-11-16)', () {
    testWidgets('correo: tras el OTP va DIRECTO al referido, sin '
        'elegir usuario', (tester) async {
      await goToOtpStep(tester);
      await enterOtp(tester, '123456');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(AuthService.isEmailLinked, isTrue);
      // Sin pantalla de usuario: directo al referido, y NO se
      // reclama ningún nombre.
      expect(find.text(tr('obUsernameTitle')), findsNothing);
      expect(find.text(tr('obReferralTitle')), findsOneWidget);
      expect(UserPrefs.publicUsername, '');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Google: tras el inicio va DIRECTO al referido',
        (tester) async {
      fakeAuth.displayName = 'Kristian Pozo Gómez';
      fakeAuth.email = 'kristian@example.com';
      await goToRegisterPage(tester);
      await tester
          .ensureVisible(find.text(tr('obRegisterGoogle').toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obRegisterGoogle').toUpperCase()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(AuthService.isGoogleLinked, isTrue);
      expect(find.text('Kristian Pozo Gómez'), findsOneWidget);
      // Avance automático (1,5 s) al referido, sin elegir usuario.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      expect(find.text(tr('obUsernameTitle')), findsNothing);
      expect(find.text(tr('obReferralTitle')), findsOneWidget);
      expect(UserPrefs.publicUsername, '');
      expect(tester.takeException(), isNull);
    });

    testWidgets('inicio de sesión con Google: sin pantalla de usuario',
        (tester) async {
      fakeAuth.displayName = 'Kristian';
      fakeAuth.email = 'kristian@example.com';
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onFinished: () => finished = true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obEnterAccount')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obSignInWithGoogle').toUpperCase()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(AuthService.isGoogleLinked, isTrue);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(find.text(tr('obUsernameTitle')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('pantalla de elegir usuario (widget)', () {
    testWidgets('NO CAMBIAR reclama el sugerido', (tester) async {
      String? chosen;
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: UsernameChoicePage(
            base: 'Kristian',
            onConfirm: (name) async => chosen = name,
            isTaken: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(tr('obUsernameTitle')), findsOneWidget);
      expect(find.text('Kristian'), findsOneWidget);
      await tester.tap(find.text(tr('obUsernameKeep').toUpperCase()));
      await tester.pumpAndSettle();
      expect(chosen, 'Kristian');
      expect(tester.takeException(), isNull);
    });

    testWidgets('escribir otro libre lo reclama', (tester) async {
      String? chosen;
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: UsernameChoicePage(
            base: 'Kristian',
            onConfirm: (name) async => chosen = name,
            isTaken: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.hintText == tr('obUsernameHint')),
        'Ana',
      );
      await tester.pumpAndSettle();
      expect(find.text(tr('obUsernameFree')), findsWidgets);
      await tester
          .tap(find.text(tr('obUsernameUseThis').toUpperCase()));
      await tester.pumpAndSettle();
      expect(chosen, 'Ana');
      expect(tester.takeException(), isNull);
    });

    testWidgets('nombre cogido muestra sugerencias y tocar una la reclama',
        (tester) async {
      String? chosen;
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: UsernameChoicePage(
            base: 'Kristian',
            onConfirm: (name) async => chosen = name,
            isTaken: (c) async => c.toLowerCase() == 'kristian',
            suggest: (_) async => ['Kristian1234', 'Kristian5678'],
          ),
        ),
      );
      await tester.pumpAndSettle();
      // El sugerido está cogido: NO CAMBIAR deshabilitado y salen
      // las sugerencias para tocar una.
      expect(find.text(tr('obUsernameTaken')), findsOneWidget);
      expect(find.text('Kristian1234'), findsOneWidget);
      expect(find.text('Kristian5678'), findsOneWidget);
      await tester.tap(find.text('Kristian1234'));
      await tester.pumpAndSettle();
      expect(chosen, 'Kristian1234');
      expect(tester.takeException(), isNull);
    });

    testWidgets('nombre escrito cogido muestra sugerencias', (tester) async {
      String? chosen;
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: UsernameChoicePage(
            base: 'Ana',
            onConfirm: (name) async => chosen = name,
            isTaken: (c) async => c.toLowerCase() == 'kristian',
            suggest: (_) async => ['Kristian1234', 'Kristian5678'],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.hintText == tr('obUsernameHint')),
        'Kristian',
      );
      await tester.pumpAndSettle();
      expect(find.text(tr('obUsernameTaken')), findsOneWidget);
      expect(find.text('Kristian1234'), findsOneWidget);
      // El botón de usar este nombre no se puede pulsar.
      final useButton = tester.widget<DuoButton>(find.byWidgetPredicate(
          (w) =>
              w is DuoButton &&
              w.label == tr('obUsernameUseThis').toUpperCase()));
      expect(useButton.onPressed, isNull);
      await tester.tap(find.text('Kristian5678'));
      await tester.pumpAndSettle();
      expect(chosen, 'Kristian5678');
      expect(tester.takeException(), isNull);
    });

    testWidgets('la pantalla cabe en 393x852 sin desbordar',
        (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: UsernameChoicePage(
            base: 'Kristian',
            onConfirm: (_) async {},
            isTaken: (c) async => c.toLowerCase() == 'kristian',
            suggest: (_) async => ['Kristian1234', 'Kristian5678'],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('UsernameChoicePage para completar el perfil (nuevos '
      'parámetros, lote 2026-11-16)', () {
    testWidgets('prefillField: campo prellenado, sin NO CAMBIAR, '
        'con título propio', (tester) async {
      String? chosen;
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: UsernameChoicePage(
            base: 'Kristian',
            prefillField: true,
            titleText: tr('usernamePersonalizeTitle'),
            bodyText: tr('usernamePersonalizeBody'),
            onConfirm: (name) async => chosen = name,
            isTaken: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Título y cuerpo propios (de Cuenta, no del registro).
      expect(find.text(tr('usernamePersonalizeTitle')), findsOneWidget);
      expect(find.text(tr('usernamePersonalizeBody')), findsOneWidget);
      expect(find.text(tr('obUsernameTitle')), findsNothing);
      // El campo ya trae el sugerido, sin bloque de sugerido ni
      // botón NO CAMBIAR.
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller?.text, 'Kristian');
      expect(find.text(tr('obUsernameKeep').toUpperCase()), findsNothing);
      // El botón de usar este nombre está activo (el sugerido está
      // libre) y lo reclama.
      await tester.tap(find.text(tr('obUsernameUseThis').toUpperCase()));
      await tester.pumpAndSettle();
      expect(chosen, 'Kristian');
      expect(tester.takeException(), isNull);
    });

    testWidgets('onSkip: QUIZÁ MÁS TARDE salta sin reclamar',
        (tester) async {
      var skipped = false;
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: UsernameChoicePage(
            base: 'Kristian',
            prefillField: true,
            onConfirm: (_) async {},
            isTaken: (_) async => false,
            onSkip: () => skipped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(tr('usernameSkip').toUpperCase()), findsOneWidget);
      await tester.tap(find.text(tr('usernameSkip').toUpperCase()));
      await tester.pumpAndSettle();
      expect(skipped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onBack: la flecha atrás vuelve sin reclamar',
        (tester) async {
      var backed = false;
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: UsernameChoicePage(
            base: 'Kristian',
            prefillField: true,
            onConfirm: (_) async {},
            isTaken: (_) async => false,
            onBack: () => backed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final back = find.byWidgetPredicate(
        (w) => w is LucideIcon && w.icon == LucideIcons.arrowLeft,
      );
      expect(back, findsOneWidget);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(backed, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('reclamo sin internet', () {
    test('claimUsername guarda en local cuando no hay conexión', () async {
      SharedPreferences.setMockInitialValues({});
      await UserPrefs.load();
      UserPrefs.publicUsername = '';
      // Sin uid y sin repo online: _allowed es false, así que el
      // nombre queda guardado en local para reclamarlo después.
      final claimed = await ReferralService.claimUsername('Ana');
      expect(claimed, 'Ana');
      expect(UserPrefs.publicUsername, 'Ana');
    });
  });
}
