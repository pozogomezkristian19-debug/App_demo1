// Pruebas de la ronda fix3 2026-11-10 (punto 1: quitar los slugs
// internos de toda la UI): ningún id de tema ('bach-…', 'uni-…') llega
// a la pantalla; la cabecera del camino muestra el título completo
// de topics.dart y un id desconocido se muestra legible.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/data/questions.dart';
import 'package:quimica_pura/data/reference_tables.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/screens/reference_tables_screen.dart';
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
    // Reglas ya vistas: PracticarScreen.initState espera 900 ms y
    // abre el popup de reglas si no están vistas; con el flag no hay
    // temporizador pendiente al final del test. (El pref solo no
    // bastaría: UserPrefs.rulesSeenV6 es un estático que hay que
    // cargar con UserPrefs.load().)
    SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
    await UserPrefs.load();
    await ProgressService.load();
  });

  group('Cabecera del camino: título completo, nunca el slug', () {
    test('localizedTopicTitle usa el título de topics.dart', () {
      // El bug de la captura: la tarjeta bloqueada decía
      // 'bach-disoluciones' y tiene que decir esto.
      expect(localizedTopicTitle('bach-disoluciones'),
          'Disoluciones y concentración');
      expect(localizedTopicTitle('bach-estequiometria'),
          'Estequiometría y el mol');
      expect(localizedTopicTitle('bach-gases'), 'Gases ideales');
      expect(localizedTopicTitle('bach-acido-base'), 'Ácido-base y pH');
      expect(localizedTopicTitle('disoluciones'),
          'Disoluciones y concentración');
      expect(localizedTopicTitle('estequiometria'), 'Estequiometría y el mol');
      expect(localizedTopicTitle('organica'), 'Química orgánica');
      expect(localizedTopicTitle('laboratorio'), 'Laboratorio de química');
    });

    test('temas del camino sin ficha en Aprender usan el nombre corto',
        () {
      expect(localizedTopicTitle('tabla'), 'Periodicidad');
      expect(localizedTopicTitle('enlace'), 'Enlace químico');
    });
  });

  group('Ningún slug llega a la UI', () {
    test('todos los ids conocidos tienen nombre bonito sin prefijo', () {
      final ids = <String>{
        ...bachTopics,
        ...uniTopics,
        ...allQuestions.map((q) => q.topic),
      };
      expect(ids.length, 14);
      for (final id in ids) {
        for (final shown in [
          localizedTopicName(id),
          localizedTopicTitle(id),
        ]) {
          expect(shown, isNot(contains('bach-')), reason: id);
          expect(shown, isNot(contains('uni-')), reason: id);
          expect(shown, isNot(startsWith('bach')), reason: id);
          expect(shown, isNot(startsWith('uni')), reason: id);
          expect(shown, isNotEmpty, reason: id);
        }
      }
    });

    test('un id desconocido se muestra legible, sin guiones ni prefijos',
        () {
      expect(localizedTopicName('tema-que-no-existe'), 'Tema que no existe');
      expect(localizedTopicName('bach-tema-nuevo'), 'Tema nuevo');
      expect(localizedTopicName('uni-algo-raro'), 'Algo raro');
      expect(localizedTopicTitle('bach-tema-nuevo'), 'Tema nuevo');
      expect(humanizeTopicId('bach-disoluciones'), 'Disoluciones');
      expect(humanizeTopicId('uni-x'), 'X');
    });

    testWidgets(
        'con 1 error, Niveles NO muestra la tarjeta de Repasar mis '
        'errores (fix4, punto 4)',
        (tester) async {
      // La tarjeta grande ("Repasar mis errores" + burbuja de la
      // mascota) empujaba el camino de niveles muy abajo: se quitó
      // de Niveles. Quedan el chip de repaso de la barra superior
      // (en main.dart, no aquí) y la fila "Mis errores" de Cuenta.
      ProgressService.instance.addFailed(const FailedEntry(
        id: 'fix3-review-1',
        topic: 'bach-estequiometria',
        question: 'Pregunta de prueba',
        level: 1,
      ));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(
            body: PracticarScreen(onOpenScreen: _noop),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(tr('reviewTitle')), findsNothing);
      // Sin slugs en la pantalla, y el camino de niveles sí se ve
      // (el título "Niveles" sigue ahí; la pregunta del día se
      // eliminó por completo de la app en la ronda #6).
      expect(find.textContaining('bach-'), findsNothing);
      expect(find.textContaining('uni-'), findsNothing);
      expect(find.text(tr('levelsTitle')), findsOneWidget);
      expect(find.text('Pregunta del día'), findsNothing);
    });
  });

  group('Tabla periódica responsiva (fix3, punto 14)', () {
    testWidgets('a 360 px la rejilla ocupa todo el ancho, sin scroll '
        'horizontal (fix4, punto 1)', (tester) async {
      await pumpTabla(tester, logicalWidth: 360, logicalHeight: 800);
      // La tabla completa sin scroll es lo NORMAL: solo los
      // teléfonos realmente angostos (< 340 dp) deslizan. A 360 px
      // la rejilla mide 360 - 16 de padding = 344 px, como en v6.
      final grid = find.byType(GridView);
      expect(grid, findsOneWidget);
      expect(tester.getSize(grid).width, 344);
      // El único SingleChildScrollView horizontal es el de la fila
      // de chips: no hay fade de desplazamiento de rejilla.
      expect(_horizontalScrolls(tester), findsOneWidget);
      expect(find.byKey(const Key('gridScrollFade')), findsNothing);
      // La tabla arranca en la posición inicial: el hidrógeno
      // (columna 1) está a la izquierda y su símbolo se ve entero
      // y sin recortes (el Text centrado dentro de su celda queda
      // en x≈24).
      expect(find.text('H'), findsOneWidget);
      expect(tester.getTopLeft(find.text('H').first).dx, lessThan(40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 320 px (teléfono angosto) la rejilla desliza con '
        'celdas de 40 px y se ven todas las filas sin cortes '
        '(fix4, punto 1)', (tester) async {
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
      // La tabla arranca en la posición inicial: el hidrógeno (columna
      // 1) está a la izquierda y su símbolo se ve entero y sin recortes.
      expect(find.text('H'), findsOneWidget);
      expect(tester.getTopLeft(find.text('H').first).dx, lessThan(40));
      // La última fila se ve entera y sin cortes: el oganesón (118,
      // última fila) está dentro de la caja de la rejilla.
      expect(find.text('Og'), findsOneWidget);
      final gridBox = tester.getRect(grid);
      final ogBox = tester.getRect(find.text('Og').first);
      expect(ogBox.bottom, lessThanOrEqualTo(gridBox.bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 800 px la rejilla ocupa todo el ancho disponible',
        (tester) async {
      await pumpTabla(tester, logicalWidth: 800, logicalHeight: 800);
      final grid = find.byType(GridView);
      expect(grid, findsOneWidget);
      // 800 - 16 de padding lateral; las celdas quedan en ~43 px.
      expect(tester.getSize(grid).width, 784);
      // Aclaración 19:28: en ancho NO hay scroll horizontal para la
      // rejilla — el único SingleChildScrollView horizontal es el de
      // la fila de chips, y no hay fade de desplazamiento de rejilla.
      expect(_horizontalScrolls(tester), findsOneWidget);
      expect(find.byKey(const Key('gridScrollFade')), findsNothing);
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
  });

  group('Serie de actividad (fix3): nota arriba y el hidrógeno es (H)', () {
    test('la entrada de hidrógeno usa el símbolo H, sin H₂', () {
      final h = metalActivitySeries
          .firstWhere((e) => e.name.contains('Hidrógeno'));
      expect(h.symbol, 'H');
      expect(h.reaction, contains('al H de los ácidos'));
      expect(h.reaction, isNot(contains('H₂')));
      // Ninguna entrada de la serie usa H₂ como símbolo.
      expect(metalActivitySeries.any((e) => e.symbol.contains('₂')),
          isFalse);
    });

    testWidgets('la nota está al principio, antes de la lista de metales',
        (tester) async {
      // Pantalla alta (360x1800): las 20 tarjetas entran en la vista
      // y el avatar del hidrógeno (12.ª) queda construido.
      await pumpTabla(tester, logicalWidth: 360, logicalHeight: 1800);
      await tester.tap(find.text(tr('tabActivity')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // La nota localizada con (H) está visible y no queda ningún H₂
      // en toda la pantalla de Tabla.
      final note = find.text(tr('activityNote'));
      expect(note, findsOneWidget);
      expect(find.textContaining('H₂'), findsNothing);
      // La nota va antes que el primer metal (Potasio).
      final noteY = tester.getTopLeft(note).dy;
      final firstMetalY = tester.getTopLeft(find.text('1. Potasio')).dy;
      expect(noteY, lessThan(firstMetalY));
      // La entrada de hidrógeno muestra H en el avatar y su nombre.
      final avatarH = find.byWidgetPredicate((w) =>
          w is CircleAvatar &&
          w.child is Text &&
          (w.child as Text).data == 'H');
      expect(avatarH, findsOneWidget);
      expect(find.textContaining('Hidrógeno'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la nota también está al principio en Tablas de referencia',
        (tester) async {
      // La nota hardcodeada al final ("El hidrógeno (H₂) es la
      // referencia…") ya no existe: ahora es tr('activityNote'), con
      // (H) y antes de la lista, igual que en la pestaña Actividad.
      await tester.pumpWidget(
        const MaterialApp(
          home: ReferenceTablesScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final note = find.text(tr('activityNote'));
      expect(note, findsOneWidget);
      expect(find.textContaining('H₂'), findsNothing);
      final noteY = tester.getTopLeft(note).dy;
      final firstMetalY = tester.getTopLeft(find.text('1. Potasio')).dy;
      expect(noteY, lessThan(firstMetalY));
      expect(tester.takeException(), isNull);
    });
  });

  group('Fila de chips (fix3, punto 8)', () {
    testWidgets('fade en el borde derecho y respiro al final',
        (tester) async {
      await pumpTabla(tester, logicalWidth: 360, logicalHeight: 800);
      // A 360 px (modo normal, fix4, punto 1) el único degradado
      // del borde derecho es el de la fila de chips: la rejilla ya
      // no desliza, así que no hay fade de rejilla. Un Container con
      // LinearGradient transparente -> color de fondo.
      final fade = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).gradient is LinearGradient);
      expect(fade, findsOneWidget);
      expect(find.byKey(const Key('gridScrollFade')), findsNothing);
      // Respiro final de 24 px tras el último chip.
      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 24),
        findsOneWidget,
      );
      // Los chips siguen funcionando: filtrar por metal alcalino
      // oculta la leyenda (comportamiento ronda #2).
      await tester.tap(find.byType(ChoiceChip).at(1));
      await tester.pump();
      expect(find.text(tr('legendWord')), findsNothing);
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

void _noop(String key) {}
