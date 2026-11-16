// Contraseña para cuentas de Google (Kristian 2026-11-15, en Cuenta):
// la tarjeta sale siempre para cuentas de Google sin contraseña (el
// recordatorio es una notificación cada hora, no la tarjeta), y la
// hoja enlaza la contraseña a la cuenta actual sin cambiar de uid.
// Desde 2026-11-16 (Kristian): CREAR CONTRASEÑA pide PRIMERO un
// OTP al correo para comprobar que la cuenta es suya, y después
// se abre la hoja — SIN el correo de restablecer de Firebase.
// Aquí se usa el FakeAuthProvider del servicio, nunca el plugin real.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/account_screen.dart';
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
  late InMemoryAnalyticsRepository fakeRepo;
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
    fakeAuth = FakeAuthProvider();
    AuthService.setProviderForTests(fakeAuth);
    fakeRepo = InMemoryAnalyticsRepository();
    AnalyticsSync.setRepositoryForTests(fakeRepo);
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
  });

  /// Cuenta de Google (sin contraseña, salvo [withPassword]).
  void googleAccount({bool withPassword = false}) {
    fakeAuth.uid = 'fake-google-uid';
    fakeAuth.googleLinked = true;
    fakeAuth.emailLinked = withPassword;
    fakeAuth.email = 'kristian@gmail.com';
    fakeAuth.displayName = 'Kristian';
  }

  /// Pumps acotados en vez de pumpAndSettle: la tarjeta
  /// "¡Completa tu perfil!" ya NO respira en bucle (la
  /// MascotMotion se quitó con la mascota, 2026-11-16), pero el
  /// avance acotado se queda. 3×300 ms cubren las animaciones de
  /// una vez (pop 400 ms, entradas 300 ms, salida de sugerencia
  /// 300 ms).
  /// Va ANTES de pumpAccount: Dart no eleva funciones locales.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pumpAccount(WidgetTester tester) async {
    // Ventana alta (360x1200): la lista de Cuenta es perezosa
    // (ListView) y la tarjeta solo se construye si cabe en
    // pantalla.
    tester.view.physicalSize = const Size(360 * 2, 1200 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: AccountScreen(
            // UniqueKey: cada pump es un estado nuevo (al entrar en
            // Cuenta de nuevo), como en la app al volver a la
            // pestaña; sin ella, Flutter reutiliza el State y el
            // aviso no se recalcula.
            key: UniqueKey(),
            onOpenScreen: (_) {},
            onShowAbout: () {},
            onShowShareApp: () {},
            trackTopics: const ['estequiometria'],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await settle(tester);
  }

  /// Botón GUARDAR CONTRASEÑA de la hoja.
  DuoButton saveButton(WidgetTester tester) => tester.widget<DuoButton>(
        find.ancestor(
          of: find.text(tr('accountSetPasswordSave').toUpperCase()),
          matching: find.byType(DuoButton),
        ),
      );

  /// Escribe un código OTP en las 6 casillas de la página de OTP.
  Future<void> enterOtp(WidgetTester tester, String code) async {
    final boxes = find.byType(TextField);
    expect(boxes, findsNWidgets(6));
    for (var i = 0; i < 6; i++) {
      await tester.enterText(boxes.at(i), code[i]);
    }
    await settle(tester);
  }

  /// Abre la hoja desde la tarjeta: primero el OTP (Kristian
  /// 2026-11-16) y después la hoja, y escribe la contraseña.
  Future<void> openSheetWithPassword(
    WidgetTester tester,
    String password,
  ) async {
    await tester.tap(
      find.text(tr('accountSetPasswordButton').toUpperCase()),
    );
    await settle(tester);
    // El OTP, no la hoja directa: el código se manda al correo y
    // ningún correo de restablecer sale de aquí.
    expect(find.text(tr('obSetPasswordOtpTitle')), findsOneWidget);
    expect(
      fakeOtp.lastCode('kristian@gmail.com', OtpPurpose.setPassword),
      '123456',
    );
    expect(fakeAuth.resetEmailsSent, isEmpty);
    await enterOtp(tester, '123456');
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await settle(tester);
    expect(find.text(tr('obPasswordTitle')), findsOneWidget);
    // El correo sale una sola vez, en la hoja: la fila de Google
    // (que también lo mostraba) vive ahora en Ajustes, sección
    // CUENTA (perfil estilo Duolingo, 2026-11-16).
    expect(find.text('kristian@gmail.com'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), password);
    await tester.pump();
  }

  testWidgets('la tarjeta sale para cuentas de Google sin contraseña',
      (tester) async {
    googleAccount();
    await pumpAccount(tester);
    expect(find.text(tr('accountSetPasswordTitle')), findsOneWidget);
    expect(
      find.text(tr('accountSetPasswordButton').toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('la tarjeta no sale con contraseña ya puesta', (tester) async {
    googleAccount(withPassword: true);
    await pumpAccount(tester);
    expect(find.text(tr('accountSetPasswordTitle')), findsNothing);
    expect(
      find.text(tr('accountSetPasswordButton').toUpperCase()),
      findsNothing,
    );
  });

  testWidgets('la tarjeta no sale sin Google', (tester) async {
    fakeAuth.uid = 'fake-anon-uid';
    fakeAuth.googleLinked = false;
    fakeAuth.emailLinked = false;
    await pumpAccount(tester);
    expect(find.text(tr('accountSetPasswordTitle')), findsNothing);
  });

  testWidgets('la tarjeta sigue al entrar de nuevo en Cuenta', (tester) async {
    googleAccount();
    await pumpAccount(tester);
    expect(find.text(tr('accountSetPasswordTitle')), findsOneWidget);
    // Segunda entrada a Cuenta: el recordatorio es la notificación
    // de cada hora, así que la tarjeta (donde se pone la
    // contraseña) sigue ahí, sin límite de días.
    await pumpAccount(tester);
    expect(find.text(tr('accountSetPasswordTitle')), findsOneWidget);
  });

  testWidgets('CREAR CONTRASEÑA pide primero el OTP, no la hoja directa',
      (tester) async {
    googleAccount();
    await pumpAccount(tester);
    await tester.tap(
      find.text(tr('accountSetPasswordButton').toUpperCase()),
    );
    await settle(tester);
    // OTP, no la hoja: el código se manda al correo con el
    // servicio OTP y la contraseña se crea después dentro de la
    // app. Ningún correo de restablecer sale de aquí (Kristian
    // 2026-11-16).
    expect(find.text(tr('obSetPasswordOtpTitle')), findsOneWidget);
    expect(find.text('kristian@gmail.com'), findsOneWidget);
    expect(find.text(tr('obPasswordTitle')), findsNothing);
    expect(
      fakeOtp.lastCode('kristian@gmail.com', OtpPurpose.setPassword),
      '123456',
    );
    expect(fakeAuth.resetEmailsSent, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OTP incorrecto en Cuenta: error y no se abre la hoja',
      (tester) async {
    googleAccount();
    await pumpAccount(tester);
    await tester.tap(
      find.text(tr('accountSetPasswordButton').toUpperCase()),
    );
    await settle(tester);
    await enterOtp(tester, '000000');
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await settle(tester);
    expect(find.text(tr('obOtpInvalid')), findsOneWidget);
    expect(find.text(tr('obSetPasswordOtpTitle')), findsOneWidget);
    expect(find.text(tr('obPasswordTitle')), findsNothing);
    expect(fakeAuth.emailLinked, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('crear la contraseña enlaza y la tarjeta desaparece',
      (tester) async {
    googleAccount();
    await pumpAccount(tester);
    await openSheetWithPassword(tester, 'abc');
    // Débil: el botón de guardar sigue deshabilitado.
    expect(saveButton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Abcdef1!');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);
    await tester.tap(
      find.text(tr('accountSetPasswordSave').toUpperCase()),
    );
    await settle(tester);
    // La hoja se cerró, la tarjeta desapareció y la cuenta sigue
    // siendo la misma (el uid NO cambió).
    expect(find.text(tr('obPasswordTitle')), findsNothing);
    expect(find.text(tr('accountSetPasswordTitle')), findsNothing);
    expect(
      find.text(tr('accountSetPasswordSaved')),
      findsOneWidget,
    );
    expect(fakeAuth.emailLinked, isTrue);
    expect(fakeAuth.uid, 'fake-google-uid');
    // Sin correo de restablecer en ningún paso, y el índice ya
    // marca que la cuenta tiene contraseña.
    expect(fakeAuth.resetEmailsSent, isEmpty);
    final doc = await fakeRepo.getDoc('emails', 'kristian@gmail.com');
    expect(doc, isNotNull);
    expect(doc!['hasPassword'], isTrue);
  });

  testWidgets(
      'si el correo ya está tomado, el error sale en la hoja y no se cierra',
      (tester) async {
    googleAccount();
    fakeAuth.emailAccounts['kristian@gmail.com'] = 'otra-contrasena';
    fakeAuth.simulateEmailAlreadyInUse = true;
    await pumpAccount(tester);
    await openSheetWithPassword(tester, 'Abcdef1!');
    await tester.tap(
      find.text(tr('accountSetPasswordSave').toUpperCase()),
    );
    await settle(tester);
    // El error sale en una línea y la hoja SIGUE abierta; la
    // cuenta sigue siendo la misma (el uid NO cambió).
    expect(find.text(tr('obEmailInUse')), findsOneWidget);
    expect(find.text(tr('obPasswordTitle')), findsOneWidget);
    expect(fakeAuth.emailLinked, isFalse);
    expect(fakeAuth.uid, 'fake-google-uid');
  });
}
