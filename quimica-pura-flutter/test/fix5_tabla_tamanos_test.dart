// Tests de lógica de la ronda #5, punto 3 afinado por tamaño
// (Quemia 6.2): la Tabla periódica se verifica por GEOMETRÍA,
// sin capturas ni goldens (cambio de flujo 00:35).
//
// - Teléfono CHICO (360x680, alto corto): toda la rejilla
//   (18 columnas x 10 filas) se alcanza bajando con el scroll de
//   la página, cada fila se puede ver ENTERA (sin cortes a mitad
//   de fila), las celdas son lo más grandes que caben en el ancho
//   y tocables (tocar Fe abre su hoja), y la leyenda se alcanza
//   bajando.
// - Teléfono GRANDE (430x900): rejilla completa + leyenda visibles
//   de una vez, sin desplazar.
// - Modo ANGOSTO (< 340 dp): sin cambios (rejilla 18 x 40 px con
//   scroll horizontal).
// - Regresión 400x852 (punto 3): la página con scroll sigue igual.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/tabla_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/main_bottom_nav.dart';
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
    required double width,
    required double height,
  }) async {
    tester.view.physicalSize = Size(width * 2, height * 2);
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

  /// El Scrollable VERTICAL de la página de Tabla (el primero con
  /// eje hacia abajo: el de la rejilla queda dentro de él y el de
  /// los chips va en horizontal).
  Finder pageScrollable(WidgetTester tester) => find
      .byWidgetPredicate((w) =>
          w is Scrollable && w.axisDirection == AxisDirection.down)
      .first;

  /// Rect visible de la página (área entre la barra de pestañas y
  /// la barra de navegación inferior).
  Rect viewportRect(WidgetTester tester) =>
      tester.getRect(pageScrollable(tester));

  /// Posición de scroll de la página.
  ScrollPosition pagePosition(WidgetTester tester) =>
      tester.state<ScrollableState>(pageScrollable(tester)).position;

  /// Salta el scroll de la página a [offset] y repinta.
  Future<void> jumpTo(WidgetTester tester, double offset) async {
    pagePosition(tester).jumpTo(offset);
    await tester.pump();
  }

  /// App real y pestaña Tabla.
  Future<void> pumpAppTabla(
    WidgetTester tester, {
    required double width,
    required double height,
  }) async {
    await setPhone(tester, width: width, height: height);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    await tester.tap(find.descendant(
      of: find.byType(MainBottomNav),
      matching: find.text(tr('tabTable')),
    ));
    await tester.pump();
    // Cambio de pestaña con fundido (AnimatedSwitcher, 250 ms).
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Regla de tamaño de celda del modo normal (la misma que
  /// _normalGrid en tabla_screen.dart): la celda mide ancho/18 y
  /// su alto es ancho/aspecto, con aspecto = anchoCelda/22,5
  /// entre 0,85 y 1,02 — la altura de celda se queda en ~22,5 dp
  /// en todos los tamaños.
  double aspectFor(double cellW) =>
      (cellW / 22.5).clamp(0.85, 1.02).toDouble();

  /// Un elemento está "entero en pantalla" si su rect cae por
  /// completo dentro del área visible de la página.
  bool fullyVisible(WidgetTester tester, Finder finder) {
    if (finder.evaluate().isEmpty) return false;
    final r = tester.getRect(finder);
    final v = viewportRect(tester);
    return r.top >= v.top - 0.5 && r.bottom <= v.bottom + 0.5;
  }

  /// Representantes de las filas con elementos de la rejilla
  /// principal: fila 1 H, 2 Li, 3 Na, 4 K, 5 Rb, 6 Cs, 7 Fr,
  /// 9 La (bloque f), 10 Lr (bloque f). La fila 8 es el hueco
  /// entre la tabla principal y los bloques f.
  const rowReps = ['H', 'Li', 'Na', 'K', 'Rb', 'Cs', 'Fr', 'La', 'Lr'];

  /// Recorre TODO el scroll de la página en pasos de una fila y
  /// anota qué filas (y la leyenda) se llegaron a ver ENTERAS en
  /// algún momento. Así se demuestra que ninguna fila queda
  /// recortada a mitad de alto de forma permanente: cada una se
  /// puede traer entera a la vista bajando.
  Future<Map<String, bool>> scanRows(
    WidgetTester tester, {
    required double step,
  }) async {
    final seen = {for (final s in rowReps) s: false, 'leyenda': false};
    final max = pagePosition(tester).maxScrollExtent;
    var offset = 0.0;
    while (true) {
      await jumpTo(tester, offset);
      for (final s in rowReps) {
        if (!seen[s]! && fullyVisible(tester, find.text(s).first)) {
          seen[s] = true;
        }
      }
      if (!seen['leyenda']! &&
          fullyVisible(tester, find.text('118 ${tr('elementsWord')}.'))) {
        seen['leyenda'] = true;
      }
      if (offset >= max) break;
      offset = (offset + step).clamp(0.0, max);
    }
    return seen;
  }

  Finder legendLine(WidgetTester tester) =>
      find.text('118 ${tr('elementsWord')}.');

  testWidgets('chico 360x680: celdas al maximo del ancho, filas '
      'alcanzables enteras, leyenda alcanzable', (tester) async {
    await pumpAppTabla(tester, width: 360, height: 680);

    // La celda sale del ancho disponible: (360 - 16) / 18.
    final gridRect = tester.getRect(find.byType(GridView).first);
    final cellW = gridRect.width / 18;
    expect(cellW, closeTo((360 - 16) / 18, 0.6));
    // 10 filas de alto = ancho / aspecto por fila (a 360 el
    // aspecto es 0,85, como siempre).
    expect(gridRect.height, closeTo(10 * cellW / aspectFor(cellW), 1.0));
    // Símbolo legible: a 19 dp de celda el texto no se encoge
    // (FittedBox scaleDown no recorta la fuente de 11).
    expect(tester.getSize(find.text('H').first).height, greaterThan(9.5));

    // Arriba, la primera fila se ve entera.
    expect(fullyVisible(tester, find.text('H').first), isTrue);
    // La página necesita scroll en un teléfono chico y corto.
    expect(pagePosition(tester).maxScrollExtent, greaterThan(0));

    // Barrido completo: cada fila y la leyenda se ven enteras en
    // algún punto del recorrido, ninguna queda cortada a mitad.
    final seen = await scanRows(tester, step: cellW / aspectFor(cellW));
    for (final s in rowReps) {
      expect(seen[s], isTrue, reason: 'fila de $s nunca entera');
    }
    expect(seen['leyenda'], isTrue);

    // Abajo del todo: última fila + leyenda enteras a la vez.
    await jumpTo(tester, pagePosition(tester).maxScrollExtent);
    expect(fullyVisible(tester, find.text('Lr').first), isTrue);
    expect(fullyVisible(tester, find.text('La').first), isTrue);
    expect(fullyVisible(tester, legendLine(tester)), isTrue);
    expect(fullyVisible(tester, find.text(tr('legendWord'))), isTrue);

    // Celda tocable: tocar Fe (fila 4) abre su hoja de detalle.
    await tester.scrollUntilVisible(
      find.text('Fe').first,
      200,
      scrollable: pageScrollable(tester),
    );
    await tester.pump();
    await tester.tap(find.text('Fe').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hierro'), findsOneWidget);
  });

  testWidgets('grande 430x900: rejilla completa + leyenda sin '
      'desplazar', (tester) async {
    await pumpAppTabla(tester, width: 430, height: 900);

    // Celdas más cómodas en el ancho grande: (430 - 16) / 18.
    final gridRect = tester.getRect(find.byType(GridView).first);
    final cellW = gridRect.width / 18;
    expect(cellW, closeTo((430 - 16) / 18, 0.6));
    expect(cellW, greaterThan(22.0));
    // Rejilla compacta por el aspecto adaptado: ~22,5 dp por fila.
    expect(gridRect.height, closeTo(10 * cellW / aspectFor(cellW), 1.0));
    // Símbolo legible también en celda baja: el texto no se
    // encoge por debajo de ~10 dp de alto.
    expect(tester.getSize(find.text('H').first).height, greaterThan(9.5));

    // Sin desplazar: primera y última fila y leyenda enteras.
    expect(fullyVisible(tester, find.text('H').first), isTrue);
    expect(fullyVisible(tester, find.text('Lr').first), isTrue);
    expect(fullyVisible(tester, find.text('La').first), isTrue);
    expect(fullyVisible(tester, find.text(tr('legendWord'))), isTrue);
    expect(fullyVisible(tester, legendLine(tester)), isTrue);
  });

  testWidgets('angosto 320: modo estrecho sin cambios', (tester) async {
    await setPhone(tester, width: 320, height: 2000);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: TablaScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Rejilla angosta de siempre: 18 x 40 px + degradado de scroll.
    final gridRect = tester.getRect(find.byType(GridView).first);
    expect(gridRect.width, closeTo(18 * 40.0, 0.5));
    expect(find.byKey(const Key('gridScrollFade')), findsOneWidget);
    // Con 2000 dp de alto la página entera cabe: filas y leyenda
    // visibles sin desplazar.
    expect(fullyVisible(tester, find.text('H').first), isTrue);
    expect(fullyVisible(tester, find.text('Lr').first), isTrue);
    expect(fullyVisible(tester, legendLine(tester)), isTrue);
  });

  testWidgets('regresion 400x852: punto 3 sigue en verde',
      (tester) async {
    await pumpAppTabla(tester, width: 400, height: 852);

    final gridRect = tester.getRect(find.byType(GridView).first);
    final cellW = gridRect.width / 18;
    expect(cellW, closeTo((400 - 16) / 18, 0.6));
    expect(gridRect.height, closeTo(10 * cellW / aspectFor(cellW), 1.0));
    expect(fullyVisible(tester, find.text('H').first), isTrue);
    expect(pagePosition(tester).maxScrollExtent, greaterThan(0));

    final seen = await scanRows(tester, step: cellW / aspectFor(cellW));
    for (final s in rowReps) {
      expect(seen[s], isTrue, reason: 'fila de $s nunca entera');
    }
    expect(seen['leyenda'], isTrue);
  });
}
