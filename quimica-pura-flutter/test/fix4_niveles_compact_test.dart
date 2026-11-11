// Ronda #4, punto 13 REVISADO (y ronda #6: la "Pregunta del día" se
// eliminó por completo de la app, así que los tests de su tarjeta
// ancha y su diálogo se quitaron de este archivo). Quedan los tests
// que no eran de la pregunta: el texto "Hoy te acompaña…" ya NO sale
// en Niveles (el acompañante sigue en su avatar junto al nodo y en
// los demás sitios), el camino va lo primero y la bolita del nivel 1
// ya no choca con el cartel del tema: hay 28 px de aire entre el
// cartel y el primer nodo, y el Stack de la fila no recorta
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

  group('inicio de Niveles (fix4, punto 13 REVISADO; ronda #6: sin pregunta del día)', () {
    testWidgets('ya no sale "Hoy te acompaña…" en Niveles',
        (tester) async {
      await pumpNiveles(tester);
      expect(find.text(tr(companionOfDayKey(companionOfTheDay()))),
          findsNothing);
      expect(find.textContaining('acompaña'), findsNothing);
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
      // (fix6, ronda #6): la pregunta del día se eliminó por
      // completo de la app y "Practicar de otra forma" ya no está
      // en Niveles: queda solo el camino.
      expect(find.text('Pregunta del día'), findsNothing);
      expect(find.text(tr('practiceOtherWays')), findsNothing);
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

}
