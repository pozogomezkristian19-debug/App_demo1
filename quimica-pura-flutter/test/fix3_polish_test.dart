// Pruebas de la ronda fix3, pulido del coordinador (puntos 1, 4, 9, 10):
// "¿Cómo se juega?" en filas con iconos, botón principal del examen
// con tiempo como pastilla teal rellena sin título duplicado, botones
// del elemento del día en una fila limpia, y "Pendiente" sin dominar
// sobre los números de la tarjeta de estadísticas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/challenge_screen.dart';
import 'package:quimica_pura/screens/stats_screen.dart';
import 'package:quimica_pura/screens/timed_exam_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/animated_number.dart';
import 'package:quimica_pura/widgets/how_to_play.dart';
import 'package:quimica_pura/widgets/lives_chip.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';
import 'package:quimica_pura/widgets/stats_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = true;
    UserPrefs.isDark = false;
    ProgressService.instance.markElementDayShown();
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
  });

  Finder lucide(LucideIconData icon) => find.byWidgetPredicate(
        (w) => w is LucideIcon && w.icon == icon,
      );

  Future<void> pumpDialog(
      WidgetTester tester, Future<void> Function(BuildContext) show) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => show(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('fix3 pulido: punto 1 (¿Cómo se juega?)', () {
    test('las 4 reglas tienen clave i18n en los 6 idiomas, sin huecos', () {
      const keys = [
        'howToPlayLives',
        'howToPlayPoints',
        'howToPlayPass',
        'howToPlayReview',
      ];
      final maps = AppLang.allStrings;
      for (final e in maps.entries) {
        for (final k in keys) {
          expect(e.value[k], isNotEmpty, reason: '${e.key}.$k');
        }
        // La cadena-muro ya no existe en ningún idioma: ninguna regla
        // puede caer al español por falta de clave.
        expect(e.value.containsKey('howToPlayBody'), isFalse,
            reason: e.key);
      }
      // El contenido es el mismo: vidas, puntos con signo, media > 4
      // y 3 aciertos seguidos para borrar el error.
      expect(AppLang.t('howToPlayLives'), contains('5 vidas'));
      expect(AppLang.t('howToPlayPoints'), contains('+3'));
      expect(AppLang.t('howToPlayPoints'), contains('−12'));
      expect(AppLang.t('howToPlayPass'), contains('4 de promedio'));
      expect(AppLang.t('howToPlayReview'), contains('3 seguidas'));
    });

    testWidgets('el diálogo muestra 4 filas con sus iconos, no un muro',
        (tester) async {
      await pumpDialog(tester, showHowToPlayDialog);
      expect(find.text(tr('howToPlayTitle')), findsOneWidget);
      expect(find.text(tr('howToPlayLives')), findsOneWidget);
      expect(find.text(tr('howToPlayPoints')), findsOneWidget);
      expect(find.text(tr('howToPlayPass')), findsOneWidget);
      expect(find.text(tr('howToPlayReview')), findsOneWidget);
      // Corazón (vidas), estrella (puntos), birrete (pasar) y
      // flecha circular (repaso).
      expect(find.byType(LivesHeart), findsOneWidget);
      expect(lucide(LucideIcons.star), findsOneWidget);
      expect(lucide(LucideIcons.graduationCap), findsOneWidget);
      expect(lucide(LucideIcons.refreshCw), findsOneWidget);
      // Cerrar sigue siendo la pastilla teal del diálogo.
      expect(find.text(tr('closeWord')), findsOneWidget);
      await tester.tap(find.text(tr('closeWord')));
      await tester.pump();
    });
  });

  group('fix3 pulido: punto 4 (examen con tiempo)', () {
    testWidgets('sin título duplicado y botón principal relleno',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const TimedExamScreen(),
        ),
      );
      await tester.pump();
      // La AppBar ya no lleva título: el único "Examen con tiempo"
      // es el encabezado del contenido.
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.title, isNull);
      expect(find.text(tr('timedTitle')), findsOneWidget);
      // El botón es una pastilla rellena (FilledButton), no el
      // ElevatedButton débil de antes; el resto queda igual.
      expect(find.byType(ElevatedButton), findsNothing);
      final start = tester.widget<FilledButton>(
          find.ancestor(
              of: find.text(tr('timedStart')),
              matching: find.byType(FilledButton)));
      expect(start.onPressed, isNotNull);
      // Los chips de duración (5–30 min) y "Mejor: 0%" quedan como están.
      expect(find.byType(ChoiceChip), findsNWidgets(6));
      expect(find.textContaining('Mejor: 0%'), findsOneWidget);
    });
  });

  group('fix3 pulido: punto 9 (elemento del día)', () {
    testWidgets('los dos botones van en la misma fila, mismo alto',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'melli_progress_element_day_shown', '2000-01-01');
      await tester.pumpWidget(const MelliQuiApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(find.text(tr('elementDayTitle')), findsOneWidget);
      // Secundario con borde a la izquierda, primario relleno a la
      // derecha; ya no hay enlace de texto (TextButton) apilado.
      final closeBtn = find.descendant(
          of: dialog, matching: find.byType(OutlinedButton));
      final sheetBtn = find.descendant(
          of: dialog, matching: find.byType(FilledButton));
      expect(closeBtn, findsOneWidget);
      expect(sheetBtn, findsOneWidget);
      expect(
          find.descendant(of: dialog, matching: find.byType(TextButton)),
          findsNothing);
      expect(
          find.descendant(
              of: closeBtn, matching: find.text(tr('closeWord'))),
          findsOneWidget);
      expect(
          find.descendant(
              of: sheetBtn, matching: find.text(tr('elementDaySeeMore'))),
          findsOneWidget);
      // Misma fila y mismo alto: mismo centro vertical y misma altura.
      final closeBox = tester.getRect(closeBtn);
      final sheetBox = tester.getRect(sheetBtn);
      expect((closeBox.center.dy - sheetBox.center.dy).abs(),
          lessThan(2.0));
      expect(closeBox.height, moreOrLessEquals(sheetBox.height, epsilon: 1.0));
      expect(closeBox.left, lessThan(sheetBox.left));

      // "Ver ficha completa" abre la ficha y cierra el popup.
      await tester.tap(find.text(tr('elementDaySeeMore')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });
  });

  group('fix3 pulido: punto 2 segunda pasada (estadísticas sin duplicar)',
      () {
    Future<void> pumpStats(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const StatsScreen(trackTopics: ['estequiometria']),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('cada cifra aparece una sola vez en toda la vista',
        (tester) async {
      await pumpStats(tester);
      // Resumen (la tarjeta que se comparte): cada cifra una vez.
      expect(find.textContaining('Racha:'), findsOneWidget);
      expect(find.textContaining('Puntos'), findsOneWidget);
      expect(find.textContaining('Vidas'), findsOneWidget);
      expect(find.textContaining('Errores por repasar'), findsOneWidget);
      expect(find.textContaining('Respuestas correctas'), findsOneWidget);
      // La tarjeta de racha ya no repite la racha actual: solo la
      // mejor racha y la meta del día, que no están en el resumen.
      expect(find.textContaining('Mejor racha'), findsOneWidget);
      expect(find.textContaining('Meta del día'), findsOneWidget);
      // La lista de detalle ya no repite nada del resumen.
      expect(find.textContaining('Respuestas totales'), findsNothing);
      expect(find.textContaining('(hoy)'), findsNothing);
      // Lo que queda en el detalle es solo información nueva.
      expect(find.textContaining('Niveles pasados'), findsNWidgets(2));
      expect(find.textContaining('Examen mixto'), findsOneWidget);
      expect(find.textContaining('Temas dominados'), findsOneWidget);
      expect(find.textContaining('Días practicando'), findsOneWidget);
    });
  });

  group('fix3 pulido: punto 4 segunda pasada (Reto)', () {
    test('los placeholders tienen clave i18n en los 6 idiomas', () {
      final maps = AppLang.allStrings;
      for (final e in maps.entries) {
        expect(e.value['challengePlayer1Placeholder'], isNotEmpty,
            reason: e.key);
        expect(e.value['challengePlayer2Placeholder'], isNotEmpty,
            reason: e.key);
      }
    });

    testWidgets('jugador 1 prellenado con nombre + (tú) y CTA relleno',
        (tester) async {
      UserPrefs.userName = 'Kristian';
      addTearDown(() => UserPrefs.userName = '');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const ChallengeScreen(),
        ),
      );
      await tester.pump();
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.length, 2);
      // Jugador 1: el nombre del perfil + "(tú)" (especificación v6).
      expect(fields.first.controller?.text, 'Kristian (tú)');
      // Jugador 2: empieza vacío.
      expect(fields.last.controller?.text, '');
      // El CTA principal es una pastilla rellena, como el del examen.
      expect(find.byType(ElevatedButton), findsNothing);
      expect(
          find.ancestor(
              of: find.text(tr('challengeStart')),
              matching: find.byType(FilledButton)),
          findsOneWidget);
    });

    testWidgets('con el perfil vacío, ambos campos muestran su ayuda',
        (tester) async {
      UserPrefs.userName = '';
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const ChallengeScreen(),
        ),
      );
      await tester.pump();
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.first.controller?.text, '');
      expect(fields.last.controller?.text, '');
      expect(fields.first.decoration?.hintText,
          tr('challengePlayer1Placeholder'));
      expect(fields.last.decoration?.hintText,
          tr('challengePlayer2Placeholder'));
      // Icono de persona en cada campo.
      expect(lucide(LucideIcons.userRound), findsNWidgets(2));
    });
  });

  group('fix3 pulido: punto 10 (stats: Pendiente)', () {
    testWidgets('la palabra de la meta va en tamaño menor que los números',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(body: StatsCard()),
        ),
      );
      await tester.pump();
      // Sin niveles pasados hoy, la meta está pendiente.
      final pending = tester.widget<Text>(find.text(tr('pendingWord')));
      expect(pending.style?.fontSize, 13);
      // Los números siguen a 16: la palabra ya no domina la fila.
      final lives = tester.widget<AnimatedNumber>(
          find.byType(AnimatedNumber).first);
      expect(lives.style?.fontSize, 16);
    });
  });
}
