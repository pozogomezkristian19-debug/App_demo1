// Pruebas de la ronda #5 (Quemia 6.2), punto 13: EL NIVEL 2 NO SE
// DESBLOQUEA CON 4/5.
//
// El bug: la puerta era la nota ponderada (nota5 > 4,0), pero el
// mensaje de la app decía "necesitas 4 de 5". Con 4/5 en preguntas
// medias la nota es 4,0 exactos y NO pasaba: la app le decía a
// Kristian que con 4 de 5 bastaba, él tenía 4 de 5 (+12 puntos, el
// caso exacto del Nivel 1 de Estequiometría: 5 medias, 4 aciertos),
// y el nivel 2 no se desbloqueaba ni al cerrar y reabrir la app.
//
// El arreglo: pasar es acertar 4 o más de 5 preguntas (por conteo,
// sin importar la dificultad); la nota se sigue mostrando, pero ya
// no es la puerta. Y el nodo pasado ya no se deduce de la nota
// (bestScore >= 81: un 4/5 puede guardar 73-80 %), sino de
// unlockedLevel. En el resultado tras pasar, botón "Pasar de nivel"
// que arranca el N+1 ahí mismo.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/models.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/points.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/celebration.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // MaterialIcons además de Roboto: el nodo pasado lleva una
  // estrella Material (Icons.star); sin la fuente, la captura
  // muestra un cuadrado vacío en vez de la estrella.
  setUpAll(() async {
    await loadRobotoFonts();
    await loadMaterialIcons();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
    ProgressService.track = ProgressService.trackUni;
    await UserPrefs.load();
    await ProgressService.load();
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
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.onboardingDone = true;
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.onboardingDone = false;
  });

  /// Viewport de teléfono real (393x852, dpr 2).
  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../melli-qui-v6-previews/$name'),
    );
  }

  /// Precarga las imágenes de los compañeros. OJO: sin runAsync la
  /// decodificación real del motor nunca completa sobre la caché
  /// fría y el test se queda colgado (mismo aviso que en
  /// preview_fix8/preview_fix6: solo funcionaba antes porque otros
  /// tests del archivo ya habían calentado la caché).
  Future<void> warmCompanions(WidgetTester tester) async {
    final ctx = tester.element(find.byType(MaterialApp));
    for (final c in Companion.values) {
      await tester.runAsync(() async {
        await precacheImage(AssetImage(companionAsset(c)), ctx);
      });
    }
    await tester.pump();
  }

  Future<void> pumpNiveles(WidgetTester tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: PracticarScreen(onOpenScreen: (_) {}),
        ),
      ),
    );
    await tester.pump();
    // El camino se desplaza hasta el nivel actual (animación de
    // 400 ms): sin esta espera el toque en el nodo puede fallar.
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Empieza el Nivel 1 del primer tema (Estequiometría): el nodo
  /// es un círculo con el número "1" dentro.
  Future<void> startLevel1(WidgetTester tester) async {
    await tester.ensureVisible(find.text('1').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('1').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
  }

  /// Contesta la pregunta visible: busca su texto en el banco
  /// (el Nivel 1 de Estequiometría son las 5 primeras preguntas
  /// del banco, todas conceptuales y todas medias) y toca la
  /// opción correcta (o una incorrecta si [correct] es false).
  Future<void> answerCurrent(
    WidgetTester tester, {
    required bool correct,
  }) async {
    final bank = localizedAllQuestions();
    QuizQuestion? shown;
    for (final q in bank) {
      if (find.text(q.question).evaluate().isNotEmpty) {
        shown = q;
        break;
      }
    }
    expect(shown, isNotNull,
        reason: 'No se ve ninguna pregunta del banco');
    final q = shown!;
    final option = correct
        ? q.options[q.answer]
        : q.options.firstWhere((o) => o != q.options[q.answer]);
    await tester.tap(find.text(option).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Flujo original: tocar la opción la juzga al momento (sin
    // COMPROBAR); los puntos y errores ya están registrados.
  }

  /// Botón "SIGUIENTE" / "RESULTADO" (flujo original): avanza a la
  /// siguiente pregunta (o al resultado en la última).
  Future<void> next(WidgetTester tester) async {
    final nextFinder = find.text(tr('quizNext').toUpperCase());
    final target = nextFinder.evaluate().isNotEmpty
        ? nextFinder
        : find.text(tr('quizResult').toUpperCase());
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Juega el Nivel 1 entero con el patrón de aciertos dado
  /// (5 valores: true = acierta, false = falla).
  Future<void> playLevel1(
    WidgetTester tester,
    List<bool> results,
  ) async {
    assert(results.length == 5);
    for (final r in results) {
      await answerCurrent(tester, correct: r);
      await next(tester);
    }
    // Al pasar un nivel y cumplirse la meta del día, _next() programa
    // la campana de racha a 900 ms: sin este bombeo el test termina
    // con el temporizador pendiente y falla ("A Timer is still
    // pending even after the widget tree was disposed").
    await tester.pump(const Duration(seconds: 1));
  }

  group('La regla nueva: 4 de 5 pasa siempre (por conteo)', () {
    test('4/5 pasa falle la fácil, la media o la difícil', () {
      expect(levelPassed(4, 5), isTrue);
      // La nota ponderada cambia según qué se falló, pero la
      // puerta es el conteo, no la nota.
      expect(levelScore5([2, 2, 2, 2, 2], [true, true, true, true, false]),
          4.0);
      expect(levelScore5([2, 2, 2, 2, 1], [true, true, true, true, false]),
          closeTo(4.17, 0.01));
      // Fallar la difícil: nota 3,85 — antes NO pasaba; ahora sí.
      expect(levelScore5([2, 2, 2, 2, 3], [true, true, true, true, false]),
          closeTo(3.85, 0.01));
    });

    test('3/5 no pasa', () {
      expect(levelPassed(3, 5), isFalse);
    });

    test('la nota ponderada se sigue calculando', () {
      expect(levelScore5([2, 2, 2, 2, 2], [true, true, true, true, true]),
          5.0);
      expect(levelScore5([2, 2, 2, 2, 2], [true, true, true, false, false]),
          3.0);
    });
  });

  group('El caso de Kristian: 4/5 en el Nivel 1 desbloquea el 2', () {
    testWidgets('4/5 (5 medias, +12 puntos, nota 4,0): pasa, '
        'desbloquea el 2 y el botón "Pasar de nivel" está',
        (tester) async {
      await pumpNiveles(tester);
      final p = ProgressService.instance;
      expect(p.unlockedLevel('estequiometria'), 1);
      await startLevel1(tester);

      // 4 aciertos y 1 fallo: el caso exacto que reportó Kristian.
      await playLevel1(tester, [true, true, true, true, false]);

      // Resultado (§3.4): título amarillo, XP grande "+12" (arriba
      // y en la tarjeta PUNTOS) y tarjeta PRECISIÓN "80 %".
      expect(find.text(tr('quizLevelPassed')), findsOneWidget);
      expect(find.text('+12'), findsWidgets);
      expect(find.text('80%'), findsOneWidget);
      expect(find.byType(CelebrationOverlay), findsOneWidget);
      // La nota guardada es 80, no 81: con la vieja deducción por
      // nota el nodo se habría visto como no pasado.
      expect(p.bestScore('level:estequiometria:1'), 80);
      // Pero el desbloqueo es real: el nivel 2 está abierto.
      expect(p.unlockedLevel('estequiometria'), 2);
      // Y el botón para saltar ahí mismo está en pantalla.
      expect(find.text('PASAR DE NIVEL'), findsOneWidget);
      // Orden tras ganar (§3.4.5): el botón grande [PASAR DE NIVEL]
      // arriba; [REPETIR] y [VOLVER] son enlaces en una fila debajo.
      final yPass = tester.getCenter(find.text('PASAR DE NIVEL')).dy;
      final yBack =
          tester.getCenter(find.text(tr('quizBack').toUpperCase())).dy;
      final yRepeat =
          tester.getCenter(find.text(tr('quizRepeat').toUpperCase())).dy;
      expect(yPass, lessThan(yBack));
      expect(yPass, lessThan(yRepeat));
      expect((yBack - yRepeat).abs(), lessThan(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('pasar el 1 y cerrar/reabrir la app: el 2 sigue '
        'desbloqueado y se puede tocar', (tester) async {
      await pumpNiveles(tester);
      final p = ProgressService.instance;
      await startLevel1(tester);
      await playLevel1(tester, [true, true, true, true, false]);
      expect(p.unlockedLevel('estequiometria'), 2);

      // Simular cerrar y reabrir: releer todo desde
      // SharedPreferences, como hace un arranque nuevo.
      await ProgressService.load();
      expect(ProgressService.instance.unlockedLevel('estequiometria'), 2);
      // Y el valor guardado en el teléfono es el desbloqueo, no
      // solo la nota: "estequiometria":2 en melli_progress_levels.
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('melli_progress_levels') ?? '';
      expect(jsonDecode(stored)['estequiometria'], 2);

      // Volver al camino y tocar el nodo 2: empieza el Nivel 2.
      await tester.tap(find.text(tr('quizBack').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // El '2' primero en el árbol es la corona del nodo 1 pasado:
      // su conteo de estrellas es "2" (mejor nota 80 % → 2 estrellas,
      // §3.2.1). El nodo 2 es el segundo '2'.
      await tester.ensureVisible(find.text('2').at(1));
      await tester.pump();
      await tester.tap(find.text('2').at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
      expect(find.textContaining('Nivel 2'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Pasar de nivel" arranca el Nivel 2 ahí mismo: '
        'pregunta 1, marcador a cero', (tester) async {
      await pumpNiveles(tester);
      await startLevel1(tester);
      await playLevel1(tester, [true, true, true, true, false]);
      expect(find.text('PASAR DE NIVEL'), findsOneWidget);

      await tester.tap(find.text('PASAR DE NIVEL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
      expect(find.textContaining('Nivel 2'), findsWidgets);
      expect(find.text(tr('quizLevelPassed')), findsNothing);
      expect(find.byType(CelebrationOverlay), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3/5 no pasa: sin "Pasar de nivel", sin desbloqueo, '
        'el mensaje sigue siendo "necesitas 4 de 5"',
        (tester) async {
      await pumpNiveles(tester);
      final p = ProgressService.instance;
      await startLevel1(tester);
      await playLevel1(tester, [true, true, true, false, false]);

      expect(find.text('60%'), findsOneWidget);
      expect(find.text(tr('quizLevelFailed')), findsOneWidget);
      expect(find.text('PASAR DE NIVEL'), findsNothing);
      expect(find.byType(CelebrationOverlay), findsNothing);
      expect(p.unlockedLevel('estequiometria'), 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('Previews fix5 punto 13', () {
    testWidgets('fix5_resultado_pasar_nivel: resultado 4/5 con el '
        'botón PASAR DE NIVEL y las 3 tarjetas (§3.4)',
        (tester) async {
      await pumpNiveles(tester);
      await warmCompanions(tester);
      await startLevel1(tester);
      await playLevel1(tester, [true, true, true, true, false]);
      expect(find.text('PASAR DE NIVEL'), findsOneWidget);
      // El confeti dura 4,2 s: pasado ese tiempo se desmonta y la
      // captura es determinista (solo el resultado y el botón).
      await tester.pump(const Duration(seconds: 5));
      await shot(tester, 'fix5_resultado_pasar_nivel.png');
    });

    testWidgets('fix5_camino_desbloqueado: camino con el nivel 1 '
        'pasado (palomita) y el 2 desbloqueado', (tester) async {
      await pumpNiveles(tester);
      await warmCompanions(tester);
      await startLevel1(tester);
      await playLevel1(tester, [true, true, true, true, false]);
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text(tr('quizBack').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(ProgressService.instance.unlockedLevel('estequiometria'), 2);
      await shot(tester, 'fix5_camino_desbloqueado.png');
    });
  });
}
