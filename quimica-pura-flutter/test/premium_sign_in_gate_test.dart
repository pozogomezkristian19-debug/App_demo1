// Puerta de sesión de Premium, v4 (solo web): regresión de los
// dos defectos graves de v3, verificados EN VIVO 2026-11-15
// 20:18-20:22 como invitado:
//   DEFECTO 1: DESBLOQUEAR CON PREMIUM como invitado iba DIRECTO
//   al paywall, sin pedir sesión. La puerta anterior llamaba a
//   linkWithGoogle() directamente y su popup se completó SOLO con
//   la sesión de Google guardada en ese navegador.
//   DEFECTO 2: visitar el paywall cambiaba la sesión del
//   invitado (el enlace silencioso subía authVersion y dejaba
//   isGoogleLinked en true, y el diamante —hoy eliminado—
//   aparecía y se quedaba).
// En v4 el invitado llega primero a la PÁGINA DE ELECCIÓN
// (PremiumSignInChoiceScreen: Google o correo) y solo si ahí
// inicia sesión se abre el paywall; la puerta re-chequea la
// sesión en vivo antes de abrirlo. Estos tests reproducen los
// dos síntomas en vivo a nivel de widget: si vuelven, fallan.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quimica_pura/screens/premium_paywall_screen.dart';
import 'package:quimica_pura/screens/premium_sign_in_choice_screen.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/premium_service.dart';
import 'package:quimica_pura/services/remote_tuning.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadNunitoFonts();
  });

  late FakeAuthProvider fakeAuth;

  /// Lo que devolvió la página de elección (true = inició sesión,
  /// false/null = canceló). Lo escribe el host de abajo.
  bool? lastChoiceResult;

  setUp(() {
    lastChoiceResult = null;
    RemoteTuning.resetForTests();
    PremiumService.resetForTests();
    // Invitado: uid anónimo, ni Google ni correo enlazados.
    fakeAuth = FakeAuthProvider()..uid = 'fake-anon-uid';
    AuthService.setProviderForTests(fakeAuth);
  });

  tearDown(() {
    PremiumService.resetForTests();
    RemoteTuning.resetForTests();
    AuthService.resetForTests();
  });

  /// Host que abre la página de elección al tocar un botón y
  /// guarda lo que devuelve (true = inició sesión, false/null =
  /// canceló). Es el papel que hace _openPaywall en el shell.
  Future<void> pumpChoiceHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  lastChoiceResult = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const PremiumSignInChoiceScreen(),
                    ),
                  );
                },
                child: const Text('ABRIR ELECCIÓN'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ABRIR ELECCIÓN'));
    await tester.pumpAndSettle();
    expect(find.text('Inicia sesión para continuar'), findsOneWidget);
  }

  testWidgets('elección: ofrece Google y correo, sin paywall',
      (tester) async {
    await pumpChoiceHost(tester);
    expect(find.text('CONTINUAR CON GOOGLE'), findsOneWidget);
    expect(find.text('CONTINUAR CON CORREO'), findsOneWidget);
    // No hay paywall detrás: ni planes ni comparación.
    expect(find.text('Quemia Premium'), findsNothing);
    expect(find.text('250 CUP'), findsNothing);
  });

  testWidgets('elección fija: cabe en 393x852 sin deslizar',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await pumpChoiceHost(tester);
    await tester.pumpAndSettle();
    expect(find.byType(Scrollable), findsNothing);
    expect(find.text('CONTINUAR CON GOOGLE'), findsOneWidget);
  });

  testWidgets('DEFECTO 1: Google falla → no hay paywall, la página sigue',
      (tester) async {
    fakeAuth.failLink = true;
    await pumpChoiceHost(tester);
    await tester.tap(find.text('CONTINUAR CON GOOGLE'));
    await tester.pumpAndSettle();
    // Sigue en la elección, con el error a la vista.
    expect(find.text('CONTINUAR CON CORREO'), findsOneWidget);
    expect(find.textContaining('No se pudo iniciar sesión con Google'),
        findsOneWidget);
    expect(find.text('Quemia Premium'), findsNothing);
    expect(lastChoiceResult, isNull);
    expect(PremiumService.isSignedIn, isFalse);
  });

  testWidgets('Google entra → la página devuelve true', (tester) async {
    await pumpChoiceHost(tester);
    await tester.tap(find.text('CONTINUAR CON GOOGLE'));
    await tester.pumpAndSettle();
    expect(lastChoiceResult, isTrue);
    expect(PremiumService.isSignedIn, isTrue);
    expect(fakeAuth.googleLinked, isTrue);
  });

  testWidgets('cancelar (Volver) → devuelve false, sigue invitado',
      (tester) async {
    await pumpChoiceHost(tester);
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(lastChoiceResult, isFalse);
    expect(PremiumService.isSignedIn, isFalse);
    expect(fakeAuth.googleLinked, isFalse);
  });

  testWidgets('correo: cuenta existente entra, contraseña mala se queda',
      (tester) async {
    fakeAuth.emailAccounts['a@b.com'] = 'clave123';
    await pumpChoiceHost(tester);
    await tester.tap(find.text('CONTINUAR CON CORREO'));
    await tester.pumpAndSettle();
    expect(find.text('Entra con tu correo'), findsOneWidget);
    await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.hintText == 'Tu correo electrónico'),
        'a@b.com');
    await tester.enterText(
        find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.hintText == 'Contraseña'),
        'mala');
    // Sin este pump el botón ENTRAR seguiría deshabilitado (se
    // habilita al repintar tras escribir en los campos).
    await tester.pump();
    await tester.tap(find.text('ENTRAR'));
    await tester.pumpAndSettle();
    // Contraseña mala: sigue en el formulario, con error.
    expect(find.text('Entra con tu correo'), findsOneWidget);
    expect(find.text('El correo o la contraseña no son correctos.'),
        findsOneWidget);
    expect(lastChoiceResult, isNull);
    // La buena: entra y la página devuelve true.
    await tester.enterText(
        find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.hintText == 'Contraseña'),
        'clave123');
    await tester.pump();
    await tester.tap(find.text('ENTRAR'));
    await tester.pumpAndSettle();
    expect(lastChoiceResult, isTrue);
    expect(PremiumService.isSignedIn, isTrue);
    expect(fakeAuth.emailLinked, isTrue);
  });

  testWidgets('correo fijo: cabe en 393x852 sin deslizar',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await pumpChoiceHost(tester);
    await tester.tap(find.text('CONTINUAR CON CORREO'));
    await tester.pumpAndSettle();
    // La pantalla es fija: sin vista de desplazamiento propia
    // (los campos de texto llevan su propio Scrollable interno
    // horizontal, eso no cuenta como deslizar la pantalla).
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('ENTRAR'), findsOneWidget);
  });

  testWidgets(
      'DEFECTO 2: el invitado sigue siendo invitado después de '
      'visitar el paywall (y ya NO hay diamante que aparezca)',
      (tester) async {
    // El diamante flotante se ELIMINÓ (Kristian 2026-11-15:
    // tapaba el botón DESBLOQUEAR): este test ya no lo monta.
    // Lo que se sigue reproduciendo es el defecto de v3: visitar
    // el paywall NO debe cambiar la sesión del invitado.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox.shrink()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Invitado: sin diamante en ningún lado (el widget ya no
    // existe en la app).
    expect(find.byKey(const ValueKey('premiumDiamondFab')), findsNothing);

    // Visitar el paywall y volver SIN iniciar sesión: el defecto
    // de v3 cambiaba la sesión justo aquí.
    final context = tester.element(find.byType(Scaffold));
    unawaited(Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Quemia Premium'), findsOneWidget);
    Navigator.of(context).pop();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('premiumDiamondFab')), findsNothing);
    expect(PremiumService.isSignedIn, isFalse);

    // Solo DESPUÉS de un inicio explícito con Google la sesión
    // cambia (y sigue sin haber diamante en ningún lado).
    final ok = await AuthService.linkWithGoogle();
    expect(ok, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(PremiumService.isSignedIn, isTrue);
    expect(find.byKey(const ValueKey('premiumDiamondFab')), findsNothing);
  });
}
