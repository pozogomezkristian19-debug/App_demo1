// Pruebas de la ronda #5 (Quemia 6.2), punto REPETIR.
// El botón "Repetir" no reiniciaba el nivel: _QuizRunnerState
// reutilizaba su State (mismo widget, sin Key) y didUpdateWidget
// solo reseteaba _lifeRestored, así que _finished seguía en true,
// la pantalla de resultado (con su confeti) se quedaba, y como
// _start() ya había puesto _finishedQuiz = false, el "Volver"
// creía que se abandonaba un nivel sin terminar y quitaba 1 vida.
// El arreglo: ValueKey por ejecución (_runId) + reset completo en
// didUpdateWidget. Las reglas de salida NO cambian: salir DESPUÉS
// de terminar no cuesta nada y sale directo; salir A MITAD de nivel
// sigue costando 1 vida con su diálogo de confirmación.
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
import 'package:quimica_pura/widgets/simple_quiz.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
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
  /// del banco, todas conceptuales) y toca la opción correcta (o
  /// una incorrecta si [correct] es false).
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
    // El toque va a la OPCIÓN (botón): tras fallar, la tarjeta de
    // explicación repite el texto de la opción correcta y un
    // find.text a secas podría tocar ese texto en vez del botón.
    final optionBtn = find.descendant(
      of: find.byType(ElevatedButton),
      matching: find.text(option),
    );
    await tester.tap(optionBtn.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Flujo original: tocar la opción la juzga al momento (sin
    // COMPROBAR); los puntos y errores ya están registrados.
  }

  /// Botón "SIGUIENTE" / "RESULTADO" (flujo original).
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

  /// La pregunta que se ve ahora mismo (búsqueda en el banco, como
  /// en [answerCurrent]).
  QuizQuestion _shownQuestion(WidgetTester tester) {
    final bank = localizedAllQuestions();
    for (final q in bank) {
      if (find.text(q.question).evaluate().isNotEmpty) return q;
    }
    throw StateError('No se ve ninguna pregunta del banco');
  }

  /// Juega el Nivel 1 entero: las 5 bien (5/5, nota 5,0: pasa).
  /// Devuelve las dificultades de las 5 preguntas que salieron
  /// (Quemia 7.3: sorteo del banco).
  Future<List<int>> playLevelAllCorrectTracked(WidgetTester tester) async {
    final difficulties = <int>[];
    for (var i = 0; i < 5; i++) {
      difficulties.add(_shownQuestion(tester).difficulty);
      await answerCurrent(tester, correct: true);
      await next(tester);
    }
    return difficulties;
  }

  /// Juega el Nivel 1 entero: las 5 bien (5/5, nota 5,0: pasa).
  Future<void> playLevelAllCorrect(WidgetTester tester) async {
    await playLevelAllCorrectTracked(tester);
  }

  /// Juega el Nivel 1 fallando SOLO la última pregunta: 4/5 (pasa
  /// por conteo, punto 13). Devuelve las dificultades de las 5
  /// preguntas que salieron (Quemia 7.3: sorteo del banco).
  Future<List<int>> playLevelFourOfFiveTracked(WidgetTester tester) async {
    final difficulties = <int>[];
    for (var i = 0; i < 4; i++) {
      difficulties.add(_shownQuestion(tester).difficulty);
      await answerCurrent(tester, correct: true);
      await next(tester);
    }
    difficulties.add(_shownQuestion(tester).difficulty);
    await answerCurrent(tester, correct: false);
    await next(tester);
    return difficulties;
  }

  /// Juega un nivel fallando SOLO la pregunta más difícil que sale
  /// (Quemia 7.3: las 5 preguntas son un sorteo de TODO el banco
  /// del tema, así que la nota y los puntos exactos dependen del
  /// sorteo). Regla secuencial: fallar la primera difícil (3); si
  /// no sale ninguna, la primera media (2); si tampoco, la última.
  /// Devuelve las dificultades de las 5 preguntas y el índice de la
  /// fallada, para calcular la nota y los puntos con lo visto.
  Future<({List<int> difficulties, int failedIndex})> playLevelFailHardest(
      WidgetTester tester) async {
    final difficulties = <int>[];
    var failedIndex = -1;
    for (var i = 0; i < 5; i++) {
      final q = _shownQuestion(tester);
      difficulties.add(q.difficulty);
      final shouldFail = failedIndex < 0 &&
          (q.difficulty == 3 ||
              (q.difficulty == 2 && i < 4) ||
              i == 4);
      if (shouldFail) failedIndex = i;
      await answerCurrent(tester, correct: !shouldFail);
      await next(tester);
    }
    expect(failedIndex, greaterThanOrEqualTo(0));
    return (difficulties: difficulties, failedIndex: failedIndex);
  }

  /// Juega el Nivel 1 fallando TODO: 0/5, nota 0,0 (suspende).
  Future<void> playLevelAllWrong(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await answerCurrent(tester, correct: false);
      await next(tester);
    }
  }

  group('Repetir reinicia el nivel de verdad', () {
    testWidgets('ganar 5/5, Repetir: pregunta 1 con marcador a cero, '
        'sin resultado ni confeti viejo', (tester) async {
      await pumpNiveles(tester);
      final p = ProgressService.instance;
      expect(p.livesLeft, 5);
      await startLevel1(tester);

      await playLevelAllCorrect(tester);
      // Resultado: 5/5, +N puntos (N depende del sorteo, Quemia
      // 7.3) y confeti.
      expect(find.text(tr('quizLevelPassed')), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('+${p.points}'), findsWidgets);
      expect(find.byType(CelebrationOverlay), findsOneWidget);
      expect(p.livesLeft, 5);

      await tester.tap(find.text(tr('quizRepeat').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Pregunta 1 de 5, sin rastro del resultado ni del confeti.
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
      expect(find.text(tr('quizLevelPassed')), findsNothing);
      expect(find.text('100%'), findsNothing);
      expect(find.byType(CelebrationOverlay), findsNothing);
      expect(p.livesLeft, 5);
      // Al ganar se programa la campana de racha 900 ms después
      // (Future.delayed en _next()): sin este avance el test
      // termina con ese temporizador pendiente y el binding falla
      // con '!timersPending'. No es un bug de la app: en el
      // teléfono el temporizador suena a los 900 ms sin más.
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Volver DESPUÉS de ganar no cuesta vida y sale '
        'directo, sin diálogo', (tester) async {
      await pumpNiveles(tester);
      final p = ProgressService.instance;
      await startLevel1(tester);
      await playLevelAllCorrect(tester);
      expect(find.text('100%'), findsOneWidget);
      // Quemia 7.3: cada intento sortea 5 preguntas distintas, así
      // que la ganancia de cada victoria depende del sorteo (antes
      // eran 25 puntos fijos).
      final firstWin = p.points;
      expect(firstWin, greaterThan(0));

      // Repetir y ganar OTRA vez: el segundo intento también
      // termina en resultado (el bug dejaba el primero pegado).
      await tester.tap(find.text(tr('quizRepeat').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
      await playLevelAllCorrect(tester);
      expect(find.text('100%'), findsOneWidget);
      // La segunda victoria suma sus propias 5 preguntas (sorteo
      // distinto): el resultado muestra la ganancia de ESTE intento.
      final secondWin = p.points - firstWin;
      expect(secondWin, greaterThan(0));
      expect(find.text('+$secondWin'), findsWidgets);
      expect(p.points, firstWin + secondWin);
      // El resultado tras ganar (§3.4): botón grande PASAR DE NIVEL
      // + enlaces REPETIR y VOLVER. La nota del nivel ya es el
      // promedio de los 2 pases (5,0 + 5,0 = 5,0), pero ya no se
      // muestra en pantalla: solo se guarda (ver asserts abajo).
      expect(find.text('PASAR DE NIVEL'), findsOneWidget);
      expect(find.text(tr('quizRepeat').toUpperCase()), findsOneWidget);
      expect(find.text(tr('quizBack').toUpperCase()), findsOneWidget);
      expect(p.bestScore('level:estequiometria:1'), 100);
      expect(p.unlockedLevel('estequiometria'), 2);

      // Volver tras ganar: sale directo a Niveles, sin aviso y
      // sin perder la vida que el bug quitaba.
      await tester.tap(find.text(tr('quizBack').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('exitLevelTitle')), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(tr('levelsTitle')), findsOneWidget);
      expect(p.livesLeft, 5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Salir A MITAD de nivel sigue costando 1 vida, con '
        'su diálogo de confirmación (esa regla no cambia)',
        (tester) async {
      await pumpNiveles(tester);
      final p = ProgressService.instance;
      expect(p.livesLeft, 5);
      await startLevel1(tester);
      await answerCurrent(tester, correct: true);
      await next(tester);
      expect(find.textContaining('Pregunta 2 de 5'), findsOneWidget);

      // Salir es ahora la X 24 pt de la barra superior (§3.3.1),
      // no la píldora "Salir".
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // El aviso, con sus dos botones.
      expect(find.text(tr('exitLevelTitle')), findsOneWidget);
      expect(find.text(tr('exitLevelStay')), findsOneWidget);
      expect(find.text(tr('exitLevelLeave')), findsOneWidget);
      expect(p.livesLeft, 5);

      await tester.tap(find.text(tr('exitLevelLeave')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('levelsTitle')), findsOneWidget);
      expect(p.livesLeft, 4);
      expect(tester.takeException(), isNull);
    });
  });

  group('Puntuación del nivel: PROMEDIO de los pases (punto 15 '
      'CORREGIDO) + replay fallido neutro en puntos (A3)', () {
    testWidgets('pasar 4/5, repetir y pasar 5/5: el promedio es '
        'la media de los pases; repetir y FALLAR: sigue igual, '
        'pasado y desbloqueado', (tester) async {
      await pumpNiveles(tester);
      final p = ProgressService.instance;
      const testId = 'level:estequiometria:1';
      await startLevel1(tester);

      // Primer pase 4/5: la nota y los puntos dependen del sorteo
      // (Quemia 7.3), así que se calculan con lo visto.
      final diffs1 = await playLevelFourOfFiveTracked(tester);
      expect(find.text('80%'), findsOneWidget);
      const correct1 = [true, true, true, true, false];
      final note1 = levelScore5(diffs1, correct1);
      var delta1 = 0;
      for (var i = 0; i < 5; i++) {
        delta1 += correct1[i]
            ? pointsForCorrect(diffs1[i])
            : pointsForWrong(diffs1[i]);
      }
      expect(find.text('+$delta1'), findsWidgets);
      expect(p.points, delta1);
      expect(p.levelNoteAverage(testId), closeTo(note1, 0.001));
      expect(p.levelNotePassCount(testId), 1);
      expect(find.textContaining('Puntuación del nivel'), findsNothing);
      expect(p.unlockedLevel('estequiometria'), 2);

      // Segundo pase 5/5: nota 5,0. Promedio (nota1 + 5,0) / 2.
      await tester.tap(find.text(tr('quizRepeat').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
      final diffs2 = await playLevelAllCorrectTracked(tester);
      expect(find.text('100%'), findsOneWidget);
      final delta2 =
          diffs2.fold<int>(0, (sum, d) => sum + pointsForCorrect(d));
      expect(find.text('+$delta2'), findsWidgets);
      expect(p.points, delta1 + delta2);
      expect(p.levelNoteAverage(testId),
          closeTo((note1 + 5.0) / 2, 0.001));
      expect(p.levelNotePassCount(testId), 2);

      // Replay FALLIDO (0/5): no entra en el promedio, no quita el
      // pase ni re-bloquea el 2, y es neutro en puntos (A3: el
      // saldo se queda en delta1 + delta2). El resultado muestra
      // Puntos +0: el intento no sumó nada.
      await tester.tap(find.text(tr('quizRepeat').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await playLevelAllWrong(tester);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('+0'), findsWidgets);
      expect(p.levelNoteAverage(testId),
          closeTo((note1 + 5.0) / 2, 0.001));
      expect(p.levelNotePassCount(testId), 2);
      expect(p.bestScore(testId), 100);
      expect(p.unlockedLevel('estequiometria'), 2);
      expect(p.points, delta1 + delta2);
      expect(p.livesLeft, 5);
      // La puntuación registrada sigue guardada tras el fallo
      // (ya no se muestra en la pantalla de resultado, §3.4).

      // Y el nodo del camino ya no lleva etiqueta "Nivel 1 · 90 %"
      // (§3.2.2): el nodo pasado muestra una estrella blanca y su
      // corona con 3 estrellas (mejor nota 100 %).
      await tester.tap(find.text(tr('quizBack').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.star), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    test('promedio directo en el servicio: 4,0 + 5,0 + 3,0 = 4,0 '
        '(la nota 3,0 con pase no sale jugando: con 4/5 la nota '
        'mínima es 3,5)', () {
      final p = ProgressService.instance;
      const testId = 'level:estequiometria:1';
      expect(p.levelNoteAverage(testId), isNull);
      expect(p.levelNotePassCount(testId), 0);
      p.recordLevelNote(testId, 4.0);
      expect(p.levelNoteAverage(testId), closeTo(4.0, 0.001));
      p.recordLevelNote(testId, 5.0);
      expect(p.levelNoteAverage(testId), closeTo(4.5, 0.001));
      expect(p.levelNotePassCount(testId), 2);
      p.recordLevelNote(testId, 3.0);
      expect(p.levelNoteAverage(testId), closeTo(4.0, 0.001));
      expect(p.levelNotePassCount(testId), 3);
    });

    test('pase anterior a esta versión: su mejor % siembra el '
        'promedio como primera nota', () {
      final p = ProgressService.instance;
      const testId = 'level:gases:1';
      // El nivel ya se pasó antes (solo quedó su mejor %, 100).
      p.recordScore(testId, 100);
      expect(p.levelNoteAverage(testId), isNull);
      // Primer pase CON registro: el mejor % viejo (100 -> 5,0)
      // entra como primera nota y este 4,0 es la segunda.
      p.recordLevelNote(testId, 4.0, prevBestPercent: 100);
      expect(p.levelNoteAverage(testId), closeTo(4.5, 0.001));
      expect(p.levelNotePassCount(testId), 2);
    });

    test('el promedio sobrevive a cerrar y volver a abrir (se '
        'guarda en SharedPreferences)', () async {
      final p = ProgressService.instance;
      const testId = 'level:estequiometria:1';
      p.recordLevelNote(testId, 4.0);
      p.recordLevelNote(testId, 5.0);
      await ProgressService.load();
      expect(p.levelNoteAverage(testId), closeTo(4.5, 0.001));
      expect(p.levelNotePassCount(testId), 2);
    });
  });

  group('A3: replay neutro con nota < 81 (el listón es '
      'unlockedLevel, no la nota)', () {
    testWidgets('pasar 4/5 fallando la más difícil y '
        'repetir fallando 0/5: el saldo queda intacto', (tester) async {
      await pumpNiveles(tester);
      final p = ProgressService.instance;
      await startLevel1(tester);
      // Nivel 1 5/5: desbloquea el Nivel 2 (los puntos exactos
      // dependen del sorteo, Quemia 7.3).
      await playLevelAllCorrect(tester);
      expect(find.text('100%'), findsOneWidget);
      expect(p.unlockedLevel('estequiometria'), 2);

      // Volver al camino y entrar al Nivel 2.
      await tester.tap(find.text(tr('quizBack').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('2').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('2').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);

      // 4/5 fallando la pregunta más difícil que sale: la nota y
      // los puntos dependen del sorteo, así que se calculan con lo
      // visto (levelScore5 y puntos por dificultad). La nota tiene
      // que quedar por debajo del 81 % (4,05): si el sorteo da una
      // nota mayor, se repite el nivel con un sorteo nuevo.
      const testId = 'level:estequiometria:2';
      final attemptNotes = <double>[];
      late List<int> difficulties;
      late int failedIndex;
      for (var attempt = 0; attempt < 3; attempt++) {
        final res = await playLevelFailHardest(tester);
        difficulties = res.difficulties;
        failedIndex = res.failedIndex;
        final correct = [
          for (var i = 0; i < 5; i++) i != failedIndex
        ];
        final attemptNote = levelScore5(difficulties, correct);
        attemptNotes.add(attemptNote);
        expect(find.text('80%'), findsOneWidget);
        if (attemptNote < 4.05) break;
        await tester.tap(find.text(tr('quizRepeat').toUpperCase()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
      }
      final correct = [
        for (var i = 0; i < 5; i++) i != failedIndex
      ];
      final note = levelScore5(difficulties, correct);
      expect(note, lessThan(4.05));
      // Ganancia del ÚLTIMO intento (el resultado muestra la de
      // este intento): aciertos según su dificultad, fallo según
      // la suya.
      var delta = 0;
      for (var i = 0; i < 5; i++) {
        delta += correct[i]
            ? pointsForCorrect(difficulties[i])
            : pointsForWrong(difficulties[i]);
      }
      expect(find.text('+$delta'), findsWidgets);
      // El nivel pasó (el listón es unlockedLevel, no la nota) y
      // la nota quedó registrada: promedio de los pases, mejor % y
      // contador según los intentos que hicieron falta.
      expect(p.unlockedLevel('estequiometria'), 3);
      final meanNote =
          attemptNotes.reduce((a, b) => a + b) / attemptNotes.length;
      expect(p.levelNoteAverage(testId), closeTo(meanNote, 0.001));
      expect(p.levelNotePassCount(testId), attemptNotes.length);
      final bestNote = attemptNotes.reduce((a, b) => a > b ? a : b);
      expect(p.bestScore(testId), (bestNote * 20).round());

      // Instantánea ANTES del replay fallido.
      final snapshotPoints = p.points;
      final snapshotAvg = p.levelNoteAverage(testId);
      final snapshotCount = p.levelNotePassCount(testId);
      final snapshotBest = p.bestScore(testId);

      // Repetir y fallar 0/5: el intento es neutro — el saldo, el
      // promedio, el pase y el desbloqueo quedan intactos.
      await tester.tap(find.text(tr('quizRepeat').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await playLevelAllWrong(tester);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('+0'), findsWidgets);
      expect(p.points, snapshotPoints);
      expect(p.levelNoteAverage(testId), closeTo(snapshotAvg ?? 0, 0.001));
      expect(p.levelNotePassCount(testId), snapshotCount);
      expect(p.bestScore(testId), snapshotBest);
      expect(p.unlockedLevel('estequiometria'), 3);
      expect(p.livesLeft, 5);
      expect(tester.takeException(), isNull);
    });
  });

  group('SimpleQuizRunner: mismo bug al reutilizar el State', () {
    testWidgets('Repetir con otro lote: pregunta 1 del lote nuevo, '
        'marcador y tiempo a cero',
        (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: _SwapHarness()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      Future<void> answer(String option) async {
        await tester.tap(find.text(option));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        // Flujo original: tocar la opción la juzga al momento.
      }

      Future<void> nextSimple() async {
        final nextFinder = find.text(tr('quizNext').toUpperCase());
        final target = nextFinder.evaluate().isNotEmpty
            ? nextFinder
            : find.text(tr('quizResult').toUpperCase());
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Pregunta A1'), findsOneWidget);
      await answer('A fácil');
      await nextSimple();
      await answer('A media'); // mal: la buena es la B
      await nextSimple();
      await answer('C difícil');
      await nextSimple();
      // Resultado del primer lote: +3 −8 +8 = +3.
      expect(find.text('Puntos: +3'), findsOneWidget);

      // Repetir: el padre cambia el lote (otro objeto de lista, sin
      // desmontar el runner, como al cambiar de lote).
      await tester.tap(find.text(tr('quizRepeat').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Con tiempo no hay total fijo: la cabecera es
      // 'Prueba · Pregunta 1' (sin "de 3").
      expect(find.text('Prueba · Pregunta 1'), findsOneWidget);
      expect(find.text('Pregunta B1'), findsOneWidget);
      expect(find.text('Puntos: +3'), findsNothing);
      // El temporizador también se reinicia (60:00, no 59:5x).
      expect(find.text('60:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Padre de prueba que reutiliza el mismo SimpleQuizRunner con otro
/// lote de preguntas al pulsar Repetir (cambia `items` sin desmontar
/// el runner).
class _SwapHarness extends StatefulWidget {
  const _SwapHarness();
  @override
  State<_SwapHarness> createState() => _SwapHarnessState();
}

class _SwapHarnessState extends State<_SwapHarness> {
  var _second = false;

  static const _a = [
    QuizQuestion(
      topic: 'tabla',
      question: 'Pregunta A1',
      options: ['A fácil', 'B fácil', 'C fácil', 'D fácil'],
      answer: 0,
      explanation: 'Por qué la A.',
      difficulty: 1,
    ),
    QuizQuestion(
      topic: 'tabla',
      question: 'Pregunta A2',
      options: ['A media', 'B media', 'C media', 'D media'],
      answer: 1,
      explanation: 'Por qué la B.',
      difficulty: 2,
    ),
    QuizQuestion(
      topic: 'tabla',
      question: 'Pregunta A3',
      options: ['A difícil', 'B difícil', 'C difícil', 'D difícil'],
      answer: 2,
      explanation: 'Por qué la C.',
      difficulty: 3,
    ),
  ];

  static const _b = [
    QuizQuestion(
      topic: 'tabla',
      question: 'Pregunta B1',
      options: ['X1', 'Y1', 'Z1', 'W1'],
      answer: 3,
      explanation: 'Por qué la W.',
      difficulty: 1,
    ),
    QuizQuestion(
      topic: 'tabla',
      question: 'Pregunta B2',
      options: ['X2', 'Y2', 'Z2', 'W2'],
      answer: 0,
      explanation: 'Por qué la X.',
      difficulty: 1,
    ),
    QuizQuestion(
      topic: 'tabla',
      question: 'Pregunta B3',
      options: ['X3', 'Y3', 'Z3', 'W3'],
      answer: 2,
      explanation: 'Por qué la Z.',
      difficulty: 1,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SimpleQuizRunner(
      title: 'Prueba',
      items: _second ? _b : _a,
      // Examen con tiempo largo: el temporizador no caduca durante
      // la prueba y permite verificar que Repetir lo reinicia.
      durationSeconds: 3600,
      onFinished: (_, __) {},
      onExit: () {},
      onRepeat: () => setState(() => _second = true),
    );
  }
}
