// Pruebas de la ronda fix6, ítem 6 (Reto: jugador 1 fijo):
// el jugador 1 es el nombre del perfil del onboarding + " (tú)"
// (p. ej. "kristian (tú)") como TEXTO FIJO no editable — ya no hay
// campo de texto para él — y el jugador 2 sigue empezando vacío y
// editable como antes. La lógica del juego no cambia.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/challenge_screen.dart';
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
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.onboardingDone = true;
    UserPrefs.isDark = false;
  });

  tearDown(() {
    UserPrefs.userName = '';
    UserPrefs.rulesSeenV6 = false;
  });

  Future<void> pumpChallenge(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const ChallengeScreen(),
      ),
    );
    await tester.pump();
  }

  group('fix6 reto: jugador 1 fijo', () {
    testWidgets('el jugador 1 muestra "nombre (tú)" y NO es editable',
        (tester) async {
      UserPrefs.userName = 'kristian';
      await pumpChallenge(tester);
      // El nombre fijo del perfil + " (tú)" está visible.
      expect(find.text('kristian (tú)'), findsOneWidget);
      // Solo queda UN campo de texto: el del jugador 2.
      expect(find.byType(TextField), findsOneWidget);
      // Y el nombre fijo no vive dentro de ningún TextField.
      expect(
          find.descendant(
              of: find.byType(TextField),
              matching: find.text('kristian (tú)')),
          findsNothing);
      // La etiqueta del jugador 1 sigue presente en la fila fija.
      expect(find.text(tr('challengePlayer1Hint')), findsOneWidget);
    });

    testWidgets('el jugador 2 empieza vacío y sí es editable',
        (tester) async {
      UserPrefs.userName = 'kristian';
      await pumpChallenge(tester);
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.length, 1);
      expect(fields.first.controller?.text, '');
      await tester.enterText(find.byType(TextField), 'Britany');
      await tester.pump();
      expect(fields.first.controller?.text, 'Britany');
    });

    testWidgets('con el jugador 2 relleno, el Reto empieza',
        (tester) async {
      UserPrefs.userName = 'kristian';
      await pumpChallenge(tester);
      await tester.enterText(find.byType(TextField), 'Britany');
      await tester.tap(find.text(tr('challengeStart')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Fase de juego del jugador 1 (nombre fijo, con sus puntos).
      expect(find.textContaining('Pregunta 1 de'), findsOneWidget);
    });

    testWidgets('sin nombre en el jugador 2, el Reto no empieza',
        (tester) async {
      UserPrefs.userName = 'kristian';
      await pumpChallenge(tester);
      await tester.tap(find.text(tr('challengeStart')));
      await tester.pump();
      // Seguimos en la fase de nombres.
      expect(find.text(tr('challengeStart')), findsOneWidget);
      expect(find.text('kristian (tú)'), findsOneWidget);
    });

    testWidgets('sin nombre de perfil, el jugador 1 fijo muestra la ayuda',
        (tester) async {
      UserPrefs.userName = '';
      await pumpChallenge(tester);
      expect(find.text(tr('challengePlayer1Placeholder')), findsOneWidget);
      // Sigue habiendo un solo campo editable: el del jugador 2.
      expect(find.byType(TextField), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.byType(TextField))
              .controller
              ?.text,
          '');
    });
  });
}
