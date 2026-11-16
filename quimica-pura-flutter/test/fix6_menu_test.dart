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
import 'package:quimica_pura/widgets/theme_toggle.dart';
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

    testWidgets('invitado: Tabla, Amigos y Torneos NO salen en el '
        'menú', (tester) async {
      await openDrawer(tester);
      // Un invitado no ve lo de buscar otra gente (Kristian
      // 2026-11-16): ni Tabla de posiciones, ni Amigos, ni
      // Torneos. Se baja hasta el último ítem para que el
      // ListView construya todo lo que hay — si esas entradas
      // existieran, aparecerían al bajar.
      await reveal(tester, tr('compareTitle'));
      expect(find.text(tr('accountLeaderboard')), findsNothing);
      expect(find.text(tr('accountFriends')), findsNothing);
      expect(find.text(tr('accountTournaments')), findsNothing);
      // Lo propio sí sale: el examen con tiempo y las ramas.
      expect(find.text(tr('timedTitle')), findsOneWidget);
      expect(find.text(tr('menuBranches')), findsOneWidget);
      expect(tester.takeException(), isNull);
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
      // Rediseño Duolingo (§3.15, Zona A): las filas YA NO viven
      // dentro de tarjetas (bloques redondeados radio 20) — son
      // filas planas sobre el fondo del drawer, separadas por un
      // Divider de 1 pt #E5E5E5. La afirmación de las tarjetas
      // queda sustituida por esta.
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
      expect(cardFinder, findsNothing);
      final dividerFinder = find.descendant(
        of: find.byType(Drawer),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Divider &&
              w.color == const Color(0xFFE5E5E5) &&
              w.height == 1,
        ),
      );
      expect(dividerFinder, findsAtLeastNWidgets(3));
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
      // La cabecera se comprueba ANTES de deslizar: el ListView
      // del menú es perezoso y al bajar hasta el pie desmonta la
      // cabecera (desde que el interruptor Tema vive al pie, el
      // contenido ya no cabe en la ventana de 1700 px).
      expect(find.text('Quemia'), findsOneWidget);
      for (final key in expectedTitles) {
        await reveal(tester, tr(key));
        expect(find.text(tr(key)), findsOneWidget);
      }
      expect(find.text(tr('notesTitle')), findsNothing);
      await reveal(tester, 'Mezcla, mira el pH y el color');
      final widget =
          tester.widget<Text>(find.text('Mezcla, mira el pH y el color'));
      expect(widget.overflow, isNot(TextOverflow.ellipsis));
      expect(widget.maxLines, isNull);
    });

    testWidgets('el interruptor Tema del menú cambia claro/oscuro',
        (tester) async {
      // 7.7 (Kristian 2026-11-14: el botón claro/oscuro va "En el
      // menú lateral"): el mismo interruptor Lottie que vivía en
      // la tarjeta de Cuenta vive ahora al pie del menú, en su
      // sección "TEMA", y cambia el tema en el acto sin abrir nada.
      await UserPrefs.saveThemeMode('claro');
      await openDrawer(tester);
      // Pie FIJO del menú (Kristian 2026-11-14): el interruptor
      // se ve nada más abrir el menú, sin bajar hasta el fondo.
      // Se comprueba que está visible SIN deslizar: si fallara,
      // es que volvió a quedar dentro del ListView.
      expect(find.byType(ThemeToggle), findsOneWidget);
      expect(find.text(tr('themeTitle')), findsOneWidget);
      // Se toca la etiqueta "Tema" del propio interruptor (la
      // sección de arriba dice "TEMA" en mayúsculas, así que no
      // hay ambigüedad): tocar el centro de la fila fallaba en el
      // test porque cae en el Spacer entre la etiqueta y la
      // animación. Es el mismo gesto que antes en Cuenta.
      await tester.tap(find.text(tr('themeTitle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(UserPrefs.themeMode, 'oscuro');
    });
  });
}
