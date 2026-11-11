// Ronda fix5, punto 1 (Quemia 6.2): "Cómo se juega" YA NO es un
// diálogo ni sale solo en la primera entrada a Niveles: es una
// pantalla completa (HowToPlayScreen) con el título, las 5 reglas
// visibles sin deslizar y un botón para cerrar/volver, que se abre
// desde la fila de Cuenta.
// - La pantalla muestra las 5 reglas completas sin scroll a 393x852.
// - El botón Cerrar vuelve atrás.
// - La fila de Cuenta abre la pantalla (y Cerrar vuelve a Cuenta).
// - Al entrar a Niveles NO sale nada automáticamente, con el flag
//   rulesSeenV6 en true o en false: el flag ya no se usa (nada en
//   lib/ lo lee ni lo escribe; se conserva dormido en UserPrefs
//   para no romper los tests viejos que lo tocan en su setUp).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/how_to_play_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/lives_chip.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadRobotoFonts();
    await loadMaterialIcons();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    await NotificationInbox.load();
    // Sin mock, el AudioPlayer estático de SoundService activa el
    // stream global de audioplayers y lanza MissingPluginException
    // (error asíncrono que el test reporta como fallo).
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
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
    UserPrefs.isDark = false;
    UserPrefs.onboardingDone = true;
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    NotificationInbox.resetForTests();
  });

  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  }

  /// Las 5 reglas, con sus iconos: corazón, rayo, estrella,
  /// birrete y flecha circular.
  void expectFiveRules() {
    expect(find.text(tr('howToPlayTitle')), findsOneWidget);
    expect(find.text(tr('howToPlayLives')), findsOneWidget);
    expect(find.text(tr('howToPlayNoLives')), findsOneWidget);
    expect(find.text(tr('howToPlayPoints')), findsOneWidget);
    expect(find.text(tr('howToPlayPass')), findsOneWidget);
    expect(find.text(tr('howToPlayReview')), findsOneWidget);
    expect(find.byType(LivesHeart), findsOneWidget);
    expect(
        find.byWidgetPredicate(
            (w) => w is LucideIcon && w.icon == LucideIcons.star),
        findsOneWidget);
    expect(
        find.byWidgetPredicate((w) =>
            w is LucideIcon && w.icon == LucideIcons.graduationCap),
        findsOneWidget);
    expect(
        find.byWidgetPredicate(
            (w) => w is LucideIcon && w.icon == LucideIcons.refreshCw),
        findsOneWidget);
  }

  testWidgets('la pantalla muestra las 5 reglas sin scroll a 393x852',
      (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: HowToPlayScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expectFiveRules();
    // Ya NO es un diálogo.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(HowToPlayScreen), findsOneWidget);
    // Sin scroll: el contenido cabe entero en la pantalla
    // (maxScrollExtent 0) y el botón de cerrar se ve entero.
    final closeCtx = tester.element(find.text(tr('closeWord')));
    final position = Scrollable.of(closeCtx).position;
    expect(position.maxScrollExtent, 0.0);
    final closeRect = tester.getRect(find.text(tr('closeWord')));
    expect(closeRect.bottom, lessThan(852));
    expect(closeRect.top, greaterThan(0));
  });

  testWidgets('el botón Cerrar vuelve atrás', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => openHowToPlayScreen(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HowToPlayScreen), findsOneWidget);
    await tester.tap(find.text(tr('closeWord')));
    await tester.pump();
    // La salida de la ruta dura 300 ms: hacen falta dos pulsos
    // para que la pantalla desaparezca del árbol.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HowToPlayScreen), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('la fila de Cuenta abre la pantalla', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    // Ir a Cuenta (quinta pestaña).
    await tester.tap(find.text(tr('accountTitle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // La fila "¿Cómo se juega?" puede quedar bajo el pliegue en
    // Cuenta: se lleva a la vista antes de tocarla.
    await tester.ensureVisible(find.text(tr('howToPlayTitle')));
    await tester.pump();
    await tester.tap(find.text(tr('howToPlayTitle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HowToPlayScreen), findsOneWidget);
    expectFiveRules();
    expect(find.byType(AlertDialog), findsNothing);
    // Cerrar vuelve a Cuenta (dos pulsos: la salida de la ruta
    // dura 300 ms).
    await tester.tap(find.text(tr('closeWord')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HowToPlayScreen), findsNothing);
    expect(find.text(tr('howToPlayTitle')), findsOneWidget);
  });

  testWidgets('al entrar a Niveles no sale nada automáticamente',
      (tester) async {
    UserPrefs.rulesSeenV6 = false;
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(HowToPlayScreen), findsNothing);
    expect(find.text(tr('howToPlayTitle')), findsNothing);
    // Lo primero que se ve son los niveles: el camino arranca
    // arriba, con el primer tema visible sin deslizar. 'Niveles'
    // sale dos veces: la cabecera grande y la etiqueta de la
    // pestaña inferior.
    expect(find.text(tr('levelsTitle')), findsWidgets);
  });

  testWidgets(
      'el flag rulesSeenV6 ya no se usa: con true tampoco sale nada '
      'y nada lo guarda', (tester) async {
    UserPrefs.rulesSeenV6 = true;
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(HowToPlayScreen), findsNothing);
    expect(find.text(tr('howToPlayTitle')), findsNothing);
    // Nada volvió a guardar el flag: entrar a Niveles no escribe
    // 'melli_rules_seen_v6' en las preferencias.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('melli_rules_seen_v6'), isNull);
  });
}
