// Ronda #5, punto 3 (Quemia 6.2): la Tabla periódica en modo normal
// es una PÁGINA CON SCROLL VERTICAL: la rejilla COMPLETA de 10 filas
// dibujada entera (shrinkWrap, sin scroll interno) y la leyenda
// debajo — como el modo angosto y como era en v6. El Column con
// Expanded anterior recortaba la rejilla a lo que quedaba tras la
// cabecera (~3,5 filas en el Redmi de Kristian: "cagaste de nuevo
// la tabla periódica") y fijaba la leyenda debajo.
//
// Estos tests habrían cazado el bug en el banco de pruebas: con un
// viewport corto (393x600, lo que queda en el teléfono real tras la
// barra de arriba y la de navegación) la página vieja ni siquiera
// cabía y la rejilla quedaba recortada; la nueva desplaza hasta el
// final sin errores.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/tabla_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

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
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
  });

  /// La página con scroll vertical de la pestaña Periódica (la
  /// cabecera de chips también desliza, pero en horizontal).
  Finder verticalPageScroll(WidgetTester tester) =>
      find.byWidgetPredicate((w) =>
          w is SingleChildScrollView &&
          w.scrollDirection == Axis.vertical);

  /// El Scrollable VERTICAL de la página (el primero con eje
  /// hacia abajo: el de la rejilla queda dentro de él y el de los
  /// chips va en horizontal). Para scrollUntilVisible, que quiere
  /// UN solo Scrollable.
  Finder pageScrollable(WidgetTester tester) => find
      .byWidgetPredicate((w) =>
          w is Scrollable && w.axisDirection == AxisDirection.down)
      .first;
  /// ningún Expanded: nada recorta la rejilla (el Expanded del
  /// TabBarView queda POR ENCIMA de la página, no entre medias).
  bool gridHasNoExpandedAbove(
      WidgetTester tester, Finder gridFinder) {
    var sawExpanded = false;
    tester
        .element(gridFinder)
        .visitAncestorElements((ancestor) {
      final w = ancestor.widget;
      if (w is SingleChildScrollView &&
          w.scrollDirection == Axis.vertical) {
        return false; // llegamos a la página: parar
      }
      if (w is Expanded) sawExpanded = true;
      return true;
    });
    return !sawExpanded;
  }

  group('Tabla periódica con scroll (fix5, punto 3)', () {
    testWidgets('a 393x852 (Redmi de Kristian) la rejilla completa '
        'de 10 filas está en el árbol y la leyenda queda debajo de '
        'la última fila', (tester) async {
      await pumpTabla(tester, logicalWidth: 393, logicalHeight: 852);
      final grid = find.byType(GridView);
      expect(grid, findsOneWidget);
      // La rejilla mide todo el ancho (393 - 16 de padding).
      expect(tester.getSize(grid).width, 393 - 16);
      // Las 10 filas están en el árbol: la primera (H) y la última
      // (Og, fila 10) existen sin necesidad de buscar.
      expect(find.text('H'), findsOneWidget);
      expect(find.text('Og'), findsOneWidget);
      // La rejilla no tiene scroll propio: la página es la que
      // desplaza (shrinkWrap + NeverScrollableScrollPhysics).
      final gridView = tester.widget<GridView>(grid);
      expect(gridView.shrinkWrap, isTrue);
      expect(gridView.physics, isA<NeverScrollableScrollPhysics>());
      // Ningún Expanded recorta la rejilla entre ella y la página.
      expect(gridHasNoExpandedAbove(tester, grid), isTrue);
      // La leyenda queda DEBAJO de la última fila: su título
      // empieza por debajo del final del oganesón.
      final ogBottom =
          tester.getBottomRight(find.text('Og').first).dy;
      final legendTop =
          tester.getTopLeft(find.text(tr('legendWord'))).dy;
      expect(legendTop, greaterThan(ogBottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('con viewport corto (393x600, lo que queda tras las '
        'barras del teléfono) la página desplaza hasta la leyenda',
        (tester) async {
      await pumpTabla(tester, logicalWidth: 393, logicalHeight: 600);
      // La página desplaza en vertical (y solo ella: la fila de
      // chips es el único scroll horizontal).
      expect(verticalPageScroll(tester), findsOneWidget);
      expect(_horizontalScrolls(tester), findsOneWidget);
      expect(find.byKey(const Key('gridScrollFade')), findsNothing);
      // Al principio solo se ven las primeras filas; la última
      // fila y la leyenda se alcanzan DESPLAZANDO la página.
      expect(find.text('Og'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('118 ${tr('elementsWord')}.'),
        300,
        scrollable: pageScrollable(tester),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // La leyenda entera se ve: título, una categoría y el
      // recuento final, sin que nada la tape.
      expect(find.text(tr('legendWord')), findsOneWidget);
      expect(find.text('118 ${tr('elementsWord')}.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 360 px la rejilla ocupa todo el ancho, sin scroll '
        'horizontal', (tester) async {
      await pumpTabla(tester, logicalWidth: 360, logicalHeight: 800);
      final grid = find.byType(GridView);
      expect(grid, findsOneWidget);
      expect(tester.getSize(grid).width, 344);
      expect(_horizontalScrolls(tester), findsOneWidget);
      expect(find.byKey(const Key('gridScrollFade')), findsNothing);
      expect(find.text('H'), findsOneWidget);
      expect(tester.getTopLeft(find.text('H').first).dx, lessThan(40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tocar una celda abre la ficha del elemento (a 360 px)',
        (tester) async {
      await pumpTabla(tester, logicalWidth: 360, logicalHeight: 800);
      await tester.tap(find.text('H').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Hidrógeno'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 800 px la rejilla ocupa todo el ancho disponible',
        (tester) async {
      await pumpTabla(tester, logicalWidth: 800, logicalHeight: 800);
      final grid = find.byType(GridView);
      expect(grid, findsOneWidget);
      expect(tester.getSize(grid).width, 784);
      expect(_horizontalScrolls(tester), findsOneWidget);
      expect(find.byKey(const Key('gridScrollFade')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Modo angosto (fix5, punto 3): SIN CAMBIOS', () {
    testWidgets('a 320 px la rejilla desliza con celdas de 40 px y '
        'se ven todas las filas sin cortes', (tester) async {
      // Pantalla alta para que entre toda la página (búsqueda,
      // chips, rejilla de 495 px y leyenda) sin desplazar.
      await pumpTabla(tester, logicalWidth: 320, logicalHeight: 2000);
      // La rejilla mide 18 x 40 = 720 px y se desplaza en
      // horizontal para verla completa.
      final grid = find.byType(GridView);
      expect(grid, findsOneWidget);
      final gridWidth = tester.getSize(grid).width;
      expect(gridWidth, 720);
      expect(gridWidth / 18, greaterThanOrEqualTo(40));
      // En teléfono angosto SÍ hay scroll horizontal para la rejilla
      // (además del de la fila de chips): dos SingleChildScrollView
      // horizontales, y el fade del borde derecho avisa de que hay
      // más tabla a la derecha.
      expect(_horizontalScrolls(tester), findsNWidgets(2));
      expect(find.byKey(const Key('gridScrollFade')), findsOneWidget);
      // La página entera también desplaza en vertical (patrón que
      // ahora comparte el modo normal).
      expect(verticalPageScroll(tester), findsOneWidget);
      // La tabla arranca en la posición inicial: el hidrógeno
      // (columna 1) está a la izquierda y su símbolo se ve entero
      // y sin recortes.
      expect(find.text('H'), findsOneWidget);
      expect(tester.getTopLeft(find.text('H').first).dx, lessThan(40));
      // La última fila se ve entera y sin cortes: el oganesón
      // (118, última fila) está dentro de la caja de la rejilla.
      expect(find.text('Og'), findsOneWidget);
      final gridBox = tester.getRect(grid);
      final ogBox = tester.getRect(find.text('Og').first);
      expect(ogBox.bottom, lessThanOrEqualTo(gridBox.bottom));
      expect(tester.takeException(), isNull);
    });
  });
}

/// SingleChildScrollView horizontales en la pantalla (fila de chips
/// siempre; rejilla solo en teléfono angosto).
Finder _horizontalScrolls(WidgetTester tester) =>
    find.byWidgetPredicate((w) =>
        w is SingleChildScrollView &&
        w.scrollDirection == Axis.horizontal);

Future<void> pumpTabla(
  WidgetTester tester, {
  required double logicalWidth,
  required double logicalHeight,
}) async {
  tester.view.physicalSize = Size(logicalWidth * 2, logicalHeight * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(body: TablaScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}
