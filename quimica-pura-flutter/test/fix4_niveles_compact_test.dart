// Ronda #4, punto 13 REVISADO (Kristian vio la captura lado a lado y
// la descartó): la "Pregunta del día" vuelve a ser la tarjeta ANCHA
// de antes (título, puntos, botón "Responder"), pero con la FOTO del
// acompañante del día DENTRO de la tarjeta. El texto "Hoy te
// acompaña…" ya NO sale en Niveles (el acompañante sigue en su
// avatar junto al nodo y en los demás sitios). Además, la bolita del
// nivel 1 ya no choca con el cartel del tema: hay 28 px de aire
// entre el cartel y el primer nodo, y el Stack de la fila no recorta
// (Clip.none), así el halo del nodo actual se ve COMPLETO (antes
// salía cortado en plano por arriba).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
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
    // Al contestar la pregunta, la app actualiza el widget de inicio
    // (HomeWidgetService.update): sin mock, el canal 'home_widget'
    // lanza MissingPluginException en los tests.
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

  Future<void> pumpNiveles(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MelliQuiApp());
    // Sin pumpAndSettle: el corazón de las vidas late sin parar
    // (PulseWidget repite cada 1200 ms).
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  }

  group('inicio de Niveles (fix4, punto 13 REVISADO)', () {
    testWidgets('ya no sale "Hoy te acompaña…" en Niveles',
        (tester) async {
      await pumpNiveles(tester);
      expect(find.text(tr(companionOfDayKey(companionOfTheDay()))),
          findsNothing);
      expect(find.textContaining('acompaña'), findsNothing);
    });

    testWidgets(
        'la pregunta del día es ancha y lleva la foto del acompañante',
        (tester) async {
      await pumpNiveles(tester);
      expect(find.text(tr('qotdTitle')), findsOneWidget);
      // La tarjeta es ancha: casi todo el ancho de la pantalla
      // (360 lógicos, con 16 px de margen a cada lado).
      final qotdCard = tester.getRect(find.ancestor(
        of: find.text(tr('qotdTitle')),
        matching: find.byType(Card),
      ));
      expect(qotdCard.left, lessThan(20));
      expect(qotdCard.right, greaterThan(340));
      // La foto del acompañante está DENTRO de esa tarjeta: la
      // tarjeta de la pregunta tiene un CompanionAvatar dentro.
      final qotdAvatar = find.descendant(
        of: find.ancestor(
          of: find.text(tr('qotdTitle')),
          matching: find.byType(Card),
        ),
        matching: find.byType(CompanionAvatar),
      );
      expect(qotdAvatar, findsOneWidget);
      // Y los puntos se ven (no se recortaron).
      expect(find.textContaining('Vale'), findsOneWidget);
    });

    testWidgets('el botón Responder sigue existiendo', (tester) async {
      await pumpNiveles(tester);
      expect(find.text(tr('qotdAnswer')), findsOneWidget);
      // El BOTÓN (no solo su texto, que va centrado): a todo lo
      // ancho de la tarjeta. En la ronda fix5 el camino va primero
      // y la tarjeta de la pregunta queda más abajo, así que ya no
      // se le exige estar dentro del primer alto de pantalla.
      final buttonRect = tester.getRect(find.ancestor(
        of: find.text(tr('qotdAnswer')),
        matching: find.byType(FilledButton),
      ));
      expect(buttonRect.left, lessThan(40));
      expect(buttonRect.right, greaterThan(320));
    });

    testWidgets(
        'el camino es lo primero: el primer nivel se ve sin desplazar',
        (tester) async {
      await pumpNiveles(tester);
      // La pantalla es 360x800 lógicos. En la ronda fix5 el camino
      // va primero: la cabecera del primer tema (en mayúsculas) y
      // su primer nodo se ven al abrir, sin desplazar.
      const height = 800.0;
      final firstTopic = tester.getRect(find.text(
          localizedTopicTitle(bachTopics.first).toUpperCase()));
      expect(firstTopic.top, lessThan(height));
      // La pregunta del día y "Practicar de otra forma" siguen
      // existiendo, pero ahora van después del primer tema.
      expect(find.text(tr('qotdTitle')), findsOneWidget);
      expect(find.text(tr('practiceOtherWays')), findsOneWidget);
    });

    testWidgets('el nodo 1 ya no choca con el cartel del tema',
        (tester) async {
      await pumpNiveles(tester);
      // El cartel: el Container con la decoración que envuelve el
      // título del primer tema.
      final headerRect = tester.getRect(find
          .ancestor(
            of: find.text(
                localizedTopicTitle(bachTopics.first).toUpperCase()),
            matching: find.byType(Container),
          )
          .first);
      // El nodo 1: el círculo de 64x64 que envuelve su número.
      Rect rectOf(Element e) {
        final box = e.renderObject! as RenderBox;
        return box.localToGlobal(Offset.zero) & box.size;
      }

      final nodeNumber = find.text('1');
      expect(nodeNumber, findsWidgets);
      final nodeRect = tester
          .elementList(find.ancestor(
            of: nodeNumber,
            matching: find.byType(Container),
          ))
          .map(rectOf)
          .firstWhere((r) => r.width == 64.0 && r.height == 64.0);
      // Aire visible: la bolita empieza al menos 15 px debajo del
      // cartel (el hueco es de 28 px; la bolita, 32).
      expect(nodeRect.top - headerRect.bottom, greaterThanOrEqualTo(15));
    });
  });

  group('la pregunta del día desaparece al contestarla (fix4, retoque final)',
      () {
    testWidgets('con la pregunta ya contestada hoy, la tarjeta no sale',
        (tester) async {
      ProgressService.instance.recordQotd(DateTime.now());
      await pumpNiveles(tester);
      expect(find.text(tr('qotdTitle')), findsNothing);
      expect(find.text(tr('qotdAnswer')), findsNothing);
    });

    testWidgets('con la pregunta contestada, todo lo de abajo sube',
        (tester) async {
      ProgressService.instance.recordQotd(DateTime.now());
      await pumpNiveles(tester);
      // Sin la tarjeta, "Practicar de otra forma" queda más arriba
      // que con la tarjeta puesta (con la tarjeta estaría más abajo).
      final answeredTop =
          tester.getRect(find.text(tr('practiceOtherWays'))).top;
      // Vuelta a empezar sin la pregunta contestada: hay que
      // limpiar la instancia cacheada de SharedPreferences, no
      // solo los valores iniciales del mock, y desmontar la app
      // (bompear el mismo MelliQuiApp const reutilizaría el árbol
      // y el estado viejo).
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await ProgressService.load();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      await pumpNiveles(tester);
      final unansweredTop =
          tester.getRect(find.text(tr('practiceOtherWays'))).top;
      expect(answeredTop, lessThan(unansweredTop));
      // Y el primer nivel sigue viéndose sin desplazar.
      final firstTopic = tester.getRect(find.text(
          localizedTopicTitle(bachTopics.first).toUpperCase()));
      expect(firstTopic.top, lessThan(800));
    });

    testWidgets('al día siguiente la pregunta vuelve a salir',
        (tester) async {
      // Contestada AYER: hoy no está marcada y la tarjeta sale.
      ProgressService.instance
          .recordQotd(DateTime.now().subtract(const Duration(days: 1)));
      await pumpNiveles(tester);
      expect(find.text(tr('qotdTitle')), findsOneWidget);
      expect(find.text(tr('qotdAnswer')), findsOneWidget);
    });

    testWidgets('al contestarla en vivo, la tarjeta desaparece',
        (tester) async {
      await pumpNiveles(tester);
      expect(find.text(tr('qotdTitle')), findsOneWidget);
      // La tarjeta queda más abajo desde la ronda fix5 (el camino
      // va primero): hay que llevarla a la vista antes de tocarla.
      await tester.ensureVisible(find.text(tr('qotdAnswer')));
      await tester.pump();
      await tester.tap(find.text(tr('qotdAnswer')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // El diálogo de la pregunta: 4 opciones (ElevatedButton).
      expect(find.byType(ElevatedButton), findsNWidgets(4));
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // El diálogo de resultado: botón "Cerrar" (FilledButton).
      await tester.tap(find.text(tr('closeWord')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('qotdTitle')), findsNothing);
      expect(find.text(tr('qotdAnswer')), findsNothing);
    });
  });
}
