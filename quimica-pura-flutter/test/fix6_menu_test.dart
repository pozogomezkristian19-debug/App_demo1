// Ronda #6, ítem 5: rediseño del ASPECTO del menú hamburguesa.
// Solo cambia el aspecto (cabecera, tarjetas de sección, subtítulos
// completos) y quita la entrada "Mi cuaderno" (clave 'notes').
// Comportamiento y navegación, intactos: cada ítem sigue abriendo
// su pantalla con su misma clave.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
    await UserPrefs.load();
    await ProgressService.load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers.global/events'),
            (m) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers'), (m) async => null);
  });

  // El Scrollable del ListView del menú (no el del TextField de
  // búsqueda, que también es un Scrollable dentro del Drawer).
  Finder drawerScrollable() => find.descendant(
        of: find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(ListView),
        ),
        matching: find.byType(Scrollable),
      );

  Future<void> openDrawer(WidgetTester tester, {bool isDark = false}) async {
    tester.view.physicalSize = const Size(800, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: HomeScreen(
          isDark: isDark,
          onToggleTheme: () {},
          onTrackChanged: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Hace visible un texto del menú (el ListView puede necesitar
  // deslizar) y deja el árbol asentado.
  Future<void> reveal(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: drawerScrollable(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Todos los títulos que el menú debe seguir trayendo.
  const expectedTitles = [
    'menuBranches',
    'menuLab',
    'timedTitle',
    'challengeTitle',
    'tableQuizTitle',
    'labSimTitle',
    'menuTables',
    'menuFormulas',
    'menuConstants',
    'glossaryTitle',
    'compareTitle',
  ];

  // Todos los subtítulos del menú: ninguno puede cortarse.
  final expectedSubtitles = [
    'Orgánica, Inorgánica, Analítica, Química física',
    'Seguridad, cuestionario y simulador',
    tr('timedSub'),
    tr('challengeSub'),
    'Adivina el elemento',
    'Mezcla, mira el pH y el color',
    'Actividad de metales y solubilidad',
    'Todas las fórmulas juntas',
    'Constantes y conversor de unidades',
    'Términos de química explicados',
    'Dos elementos, cara a cara',
  ];

  group('menú hamburguesa rediseñado (ronda #6, ítem 5)', () {
    testWidgets('todos los ítems esperados están, en claro', (tester) async {
      await openDrawer(tester);
      for (final key in expectedTitles) {
        await reveal(tester, tr(key));
        expect(find.text(tr(key)), findsOneWidget);
      }
    });

    testWidgets('"Mi cuaderno" ya NO está en el menú', (tester) async {
      await openDrawer(tester);
      // La pantalla de notas sigue existiendo (se abre desde la
      // búsqueda), pero su entrada del menú se quitó.
      expect(find.text(tr('notesTitle')), findsNothing);
      expect(find.text('Tus notas por tema'), findsNothing);
    });

    testWidgets('los subtítulos se ven completos, sin ellipsis',
        (tester) async {
      await openDrawer(tester);
      for (final subtitle in expectedSubtitles) {
        await reveal(tester, subtitle);
        final textFinder = find.text(subtitle);
        expect(textFinder, findsOneWidget);
        final widget = tester.widget<Text>(textFinder);
        // Nada de puntos suspensivos que oculten información: el
        // texto se envuelve y se muestra entero.
        expect(widget.overflow, isNot(TextOverflow.ellipsis));
        expect(widget.maxLines, isNull);
        expect(widget.softWrap, isTrue);
      }
      // El subtítulo del simulador, el que se cortaba como
      // "Mezcla, mira el pH y el...", se lee entero.
      expect(find.text('Mezcla, mira el pH y el color'), findsOneWidget);
    });

    testWidgets('cabecera: logo Quemia + subtítulo, secciones con orden',
        (tester) async {
      await openDrawer(tester);
      expect(find.text('Quemia'), findsOneWidget);
      expect(find.text(tr('appSubtitle')), findsOneWidget);
      await reveal(tester, tr('labSimTitle'));
      expect(find.text(tr('drawerPractice').toUpperCase()), findsOneWidget);
      expect(find.text(tr('drawerReference').toUpperCase()), findsOneWidget);
      // El orden no cambió con las tarjetas: el simulador sigue en
      // Referencia, justo arriba de Tablas de referencia.
      final refY = tester
          .getTopLeft(find.text(tr('drawerReference').toUpperCase()))
          .dy;
      final simY = tester.getTopLeft(find.text(tr('labSimTitle'))).dy;
      final tablesY = tester.getTopLeft(find.text(tr('menuTables'))).dy;
      expect(simY, greaterThan(refY));
      expect(simY, lessThan(tablesY));
      // Las filas viven dentro de tarjetas (bloques redondeados),
      // no como lista plana suelta sobre el fondo del drawer:
      // 3 tarjetas (Explorar, Practicar, Referencia).
      final cardFinder = find.descendant(
        of: find.byType(Drawer),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Material &&
              w.shape is RoundedRectangleBorder &&
              (w.shape as RoundedRectangleBorder).borderRadius ==
                  BorderRadius.circular(20),
        ),
      );
      expect(cardFinder, findsAtLeastNWidgets(3));
    });

    testWidgets('tocar el simulador sigue abriendo el simulador',
        (tester) async {
      await openDrawer(tester);
      await reveal(tester, tr('labSimTitle'));
      final tile = find.ancestor(
        of: find.text(tr('labSimTitle')),
        matching: find.byType(ListTile),
      );
      expect(tile, findsOneWidget);
      tester.widget<ListTile>(tile).onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('labModeAcidBase')), findsOneWidget);
      expect(find.text('Fenolftaleína'), findsOneWidget);
    });

    testWidgets('en oscuro: mismos ítems, sin "Mi cuaderno"',
        (tester) async {
      await openDrawer(tester, isDark: true);
      for (final key in expectedTitles) {
        await reveal(tester, tr(key));
        expect(find.text(tr(key)), findsOneWidget);
      }
      expect(find.text(tr('notesTitle')), findsNothing);
      expect(find.text('Quemia'), findsOneWidget);
      await reveal(tester, 'Mezcla, mira el pH y el color');
      final widget =
          tester.widget<Text>(find.text('Mezcla, mira el pH y el color'));
      expect(widget.overflow, isNot(TextOverflow.ellipsis));
      expect(widget.maxLines, isNull);
    });
  });
}
