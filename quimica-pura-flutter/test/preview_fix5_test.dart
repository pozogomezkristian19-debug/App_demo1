// Vistas previas de la ronda #5 (Quemia 6.2), ACTUALIZADAS con los
// 2 puntos nuevos de Kristian (2026-11-11 00:10):
// - fix5_niveles_primero.png: Niveles al abrir, 393x852: el camino
//   es lo primero que se ve (cabecera del primer tema + nodo 1 sin
//   deslizar); la pregunta del día y "Practicar de otra forma"
//   siguen, después del primer tema. Sin ningún popup (el día NO
//   está marcado: nada suprime el popup, es que ya no hay popup;
//   y "Cómo se juega" ya no sale solo: ahora es pantalla desde
//   Cuenta).
// - fix5_como_se_juega_pantalla.png: "Cómo se juega" como PANTALLA
//   COMPLETA (ya no diálogo), abierta desde la fila de Cuenta:
//   título + las 5 reglas + botón Cerrar, todo visible sin scroll.
// Se ejecuta con --update-goldens para ESCRIBIR los PNG en
// ~/workspace/melli-qui-v6-previews/ (nombres fix5_*). Viewport
// 393x852 (dpr 2), Roboto real. Los PNG se leen y se verifican a
// mano antes de informar.
// OBSOLETOS (no se regeneran: los retira el coordinador):
// fix5_sin_elemento_niveles.png (el layout de Niveles cambió) y
// fix5_como_se_juega.png (el diálogo ya no existe).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/how_to_play_screen.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
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
    // A PROPÓSITO no se llama a markElementDayShown(): la prueba
    // es que sin suprimir nada, el popup ya no sale.
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    NotificationInbox.resetForTests();
  });

  Future<void> setPhone(
    WidgetTester tester, {
    double width = 393,
    double height = 852,
  }) async {
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../melli-qui-v6-previews/$name'),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  }

  /// Calienta la caché de imágenes de los tres acompañantes antes
  /// de la captura: el PNG (1600x1600) se decodifica de forma
  /// asíncrona y, con la caché fría, la primera captura de un
  /// proceso lo pilla sin cargar (círculo vacío en vez de la foto).
  Future<void> warmCompanions(WidgetTester tester) async {
    final ctx = tester.element(find.byType(MaterialApp));
    for (final c in Companion.values) {
      await precacheImage(AssetImage(companionAsset(c)), ctx);
    }
    await tester.pump();
  }

  // Calentamiento: decodifica las imágenes de los acompañantes ANTES
  // de la primera captura (patrón de preview_fix2_test.dart).
  testWidgets('warm-up imágenes', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Row(
            key: Key('warmup'),
            children: [
              Image(
                  image: AssetImage('assets/brenda.png'),
                  width: 40,
                  height: 40),
              Image(
                  image: AssetImage('assets/britany.png'),
                  width: 40,
                  height: 40),
              Image(
                  image: AssetImage('assets/kristian.png'),
                  width: 40,
                  height: 40),
              Image(
                  image: AssetImage('assets/whatsapp.png'),
                  width: 40,
                  height: 40),
            ],
          ),
        ),
      ),
    );
    final context = tester.element(find.byKey(const Key('warmup')));
    await tester.runAsync(() async {
      for (final name in ['brenda', 'britany', 'kristian']) {
        await precacheImage(AssetImage('assets/$name.png'), context);
      }
    });
    await settle(tester);
  });

  testWidgets(
      'fix5_niveles_primero: Niveles al abrir, el camino lo primero, '
      'nodo 1 visible sin deslizar', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    // Prueba de que ningún popup salió aunque nada lo suprimió.
    expect(find.text(tr('elementDayTitle')), findsNothing);
    expect(find.text(tr('howToPlayTitle')), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    // La pregunta del día y "Practicar de otra forma" SIGUEN en
    // Niveles (después del primer tema, no se quitaron).
    expect(find.text(tr('qotdTitle')), findsOneWidget);
    expect(find.text(tr('practiceOtherWays')), findsOneWidget);
    // El nodo 1: el círculo de 64x64 que envuelve su número, entero
    // por encima del pliegue (la barra inferior empieza a 772).
    Rect rectOf(Element e) {
      final box = e.renderObject! as RenderBox;
      return box.localToGlobal(Offset.zero) & box.size;
    }

    final nodeRect = tester
        .elementList(find.ancestor(
          of: find.text('1'),
          matching: find.byType(Container),
        ))
        .map(rectOf)
        .firstWhere((r) => r.width == 64.0 && r.height == 64.0);
    expect(nodeRect.top, lessThan(772));
    expect(nodeRect.bottom, lessThanOrEqualTo(772));
    // Y la cabecera del primer tema está justo debajo de la
    // cabecera de Niveles: el camino domina la primera pantalla.
    final firstTopic = tester.getRect(find.text(
        localizedTopicTitle(uniTopics.first).toUpperCase()));
    expect(firstTopic.top, lessThan(200));
    await warmCompanions(tester);
    await shot(tester, 'fix5_niveles_primero.png');
  });

  testWidgets(
      'fix5_como_se_juega_pantalla: "Cómo se juega" como pantalla '
      'completa desde Cuenta, todo visible sin scroll', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    await tester.tap(find.text(tr('accountTitle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text(tr('howToPlayTitle')));
    await tester.pump();
    await tester.tap(find.text(tr('howToPlayTitle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HowToPlayScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(tr('howToPlayLives')), findsOneWidget);
    expect(find.text(tr('howToPlayNoLives')), findsOneWidget);
    expect(find.text(tr('howToPlayPoints')), findsOneWidget);
    expect(find.text(tr('howToPlayPass')), findsOneWidget);
    expect(find.text(tr('howToPlayReview')), findsOneWidget);
    // Todo visible sin deslizar: el botón de cerrar se ve entero.
    final closeRect = tester.getRect(find.text(tr('closeWord')));
    expect(closeRect.bottom, lessThan(852));
    final closeCtx = tester.element(find.text(tr('closeWord')));
    expect(Scrollable.of(closeCtx).position.maxScrollExtent, 0.0);
    await shot(tester, 'fix5_como_se_juega_pantalla.png');
  });
}
