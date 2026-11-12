// Ronda #6, ítem 1 + corrección (eliminación total): Niveles muestra
// SOLO el camino de niveles. La "Pregunta del día" se eliminó POR
// COMPLETO de la app (tarjeta, diálogo, lógica, puntos, logro,
// widget) y "marcar como dominado" también (botones, estados,
// filtros y textos). Estos tests comprueban que en Niveles no queda
// rastro visible de ninguna de las dos cosas y que el camino sigue.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/questions.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
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

  /// Busca un texto SOLO dentro de la pantalla Niveles (el menú
  /// hamburguesa, cerrado, sigue teniendo "Examen con tiempo" como
  /// entrada, y la barra inferior repite "Niveles").
  Finder inNiveles(String text) => find.descendant(
        of: find.byType(PracticarScreen),
        matching: find.text(text),
      );

  group('Niveles solo niveles (fix6, ronda #6)', () {
    testWidgets('no queda rastro visible de la pregunta del día',
        (tester) async {
      await pumpNiveles(tester);
      expect(inNiveles('Pregunta del día'), findsNothing);
      expect(inNiveles('Responder'), findsNothing);
      expect(find.text('Pregunta del día'), findsNothing);
      expect(
          find.textContaining(
              RegExp('pregunta del día', caseSensitive: false)),
          findsNothing);
    });

    testWidgets(
        'ya no sale "Practicar de otra forma" en Niveles, pero el '
        'Examen con tiempo sigue en el menú', (tester) async {
      await pumpNiveles(tester);
      expect(inNiveles(tr('practiceOtherWays')), findsNothing);
      expect(inNiveles(tr('timedTitle')), findsNothing);
      // La pantalla sigue existiendo: el menú la abre. El cajón no
      // está en el árbol cerrado: hay que abrirlo para ver sus
      // entradas (como en test/fix4_drawer_sim_test.dart).
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('timedTitle')), findsOneWidget);
    });

    testWidgets('el camino de niveles sigue presente', (tester) async {
      await pumpNiveles(tester);
      expect(inNiveles(tr('levelsTitle')), findsOneWidget);
      // Rediseño Duolingo §3.2.2: ya NO hay etiqueta "Nivel N" bajo
      // cada nodo. El nodo actual sigue mostrando su número "1" y el
      // banner lleva "NIVEL 1 DE 6 · MEJOR: 0 %" (mayúsculas,
      // decisión de Kristian, ronda 3).
      expect(find.text('1'), findsWidgets);
      expect(find.textContaining('NIVEL 1 DE 6'), findsWidgets);
      // El trofeo final del camino y el texto del banco siguen.
      expect(find.text(tr('mixedTitle')), findsWidgets);
      expect(find.textContaining(tr('bankWord')), findsWidgets);
    });

    testWidgets(
        'la tarjeta de repaso inteligente sigue en Niveles cuando hay '
        'errores pendientes', (tester) async {
      final lab =
          allQuestions.firstWhere((q) => q.topic == 'laboratorio');
      // Error de AYER: el repaso inteligente solo resurge errores
      // de días anteriores (addFailed fecha hoy lo que no trae
      // fecha, y dueFailed excluye el día actual).
      ProgressService.instance.addFailed(FailedEntry(
        id: 'bank:laboratorio:${lab.question}',
        topic: 'laboratorio',
        question: lab.question,
        failedDate: ProgressService.dateKey(
            DateTime.now().subtract(const Duration(days: 1))),
      ));
      await pumpNiveles(tester);
      expect(find.text(tr('smartReviewTitle')), findsOneWidget);
      // Y aun con la tarjeta de repaso, nada de pregunta del día
      // ni de "Practicar de otra forma" en Niveles.
      expect(inNiveles('Pregunta del día'), findsNothing);
      expect(inNiveles(tr('practiceOtherWays')), findsNothing);
    });

    testWidgets('no queda rastro visible de "marcar como dominado"',
        (tester) async {
      await pumpNiveles(tester);
      expect(find.text('Dominado'), findsNothing);
      expect(find.text('Marcar como dominado'), findsNothing);
      expect(find.textContaining('Temas dominados'), findsNothing);
      expect(find.textContaining('dominado'), findsNothing);
    });
  });
}
