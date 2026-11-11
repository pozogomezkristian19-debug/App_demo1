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
  }

  /// Botón "Siguiente" (o "Resultado" en la última pregunta).
  Future<void> next(WidgetTester tester) async {
    final nextBtn = find.text(tr('quizNext'));
    final resultBtn = find.text(tr('quizResult'));
    final target =
        nextBtn.evaluate().isNotEmpty ? nextBtn : resultBtn;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Juega el Nivel 1 entero: las 5 bien (5/5, nota 5,0: pasa).
  Future<void> playLevelAllCorrect(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await answerCurrent(tester, correct: true);
      await next(tester);
    }
  }

  /// Juega el Nivel 1 fallando SOLO la última pregunta: 4/5,
  /// nota 4,0 (pasa por conteo, punto 13) y +12 puntos (4 medias
  /// a +5 y 1 mal a −8), el caso de Kristian.
  Future<void> playLevelFourOfFive(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await answerCurrent(tester, correct: true);
      await next(tester);
    }
    await answerCurrent(tester, correct: false);
    await next(tester);
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
      // Resultado: 5/5, +25 puntos (5 medias a +5) y confeti.
      expect(find.text('5 de 5 Aciertos'), findsOneWidget);
      expect(find.text('Resultado'), findsOneWidget);
      expect(find.text('Puntos: +25'), findsOneWidget);
      expect(find.byType(CelebrationOverlay), findsOneWidget);
      expect(p.livesLeft, 5);

      await tester.tap(find.text(tr('quizRepeat')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Pregunta 1 de 5, sin rastro del resultado ni del confeti.
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
      expect(find.text('5 de 5 Aciertos'), findsNothing);
      expect(find.text('Puntos: +25'), findsNothing);
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
      expect(find.text('5 de 5 Aciertos'), findsOneWidget);

      // Repetir y ganar OTRA vez: el segundo intento también
      // termina en resultado (el bug dejaba el primero pegado).
      await tester.tap(find.text(tr('quizRepeat')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
      await playLevelAllCorrect(tester);
      expect(find.text('5 de 5 Aciertos'), findsOneWidget);
      // Ganar dos veces el mismo nivel: 25 + 25 puntos.
      expect(find.text('Puntos: +25'), findsOneWidget);
      expect(p.points, 50);
      // El resultado tras ganar trae los tres botones (punto 13 +
      // 15.1): [Pasar de nivel] [Volver] [Repetir]; y la nota del
      // nivel ya es el promedio de los 2 pases (5,0 + 5,0 = 5,0).
      expect(find.text('Pasar de nivel'), findsOneWidget);
      expect(find.text(tr('quizRepeat')), findsOneWidget);
      expect(find.text(tr('quizBack')), findsOneWidget);
      expect(
          find.text('Puntuación del nivel: 5,0 · promedio de 2 intentos'),
          findsOneWidget);
      expect(p.bestScore('level:estequiometria:1'), 100);
      expect(p.unlockedLevel('estequiometria'), 2);

      // Volver tras ganar: sale directo a Niveles, sin aviso y
      // sin perder la vida que el bug quitaba.
      await tester.tap(find.text(tr('quizBack')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('exitLevelTitle')), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Nivel 1'), findsWidgets);
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

      await tester.tap(find.text(tr('quizExit')));
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
      expect(find.text('Nivel 1'), findsWidgets);
      expect(p.livesLeft, 4);
      expect(tester.takeException(), isNull);
    });
  });

  group('Puntuación del nivel: PROMEDIO de los pases (punto 15 '
      'CORREGIDO) + replay fallido neutro en puntos (A3)', () {
    testWidgets('pasar 4,0, repetir y pasar 5,0: nota registrada '
        '4,5; repetir y FALLAR: sigue 4,5, pasado y desbloqueado',
        (tester) async {
      await pumpNiveles(tester);
      final p = ProgressService.instance;
      const testId = 'level:estequiometria:1';
      await startLevel1(tester);

      // Primer pase 4/5: nota 4,0, +12 puntos. El promedio de un
      // solo pase es 4,0 y (todavía) no se muestra la línea del
      // promedio: en el primer pase ya está la 'Nota:' arriba.
      await playLevelFourOfFive(tester);
      expect(find.text('4 de 5 Aciertos'), findsOneWidget);
      expect(find.text('Nota: 4.0 / 5'), findsOneWidget);
      expect(find.text('Puntos: +12'), findsOneWidget);
      expect(p.points, 12);
      expect(p.levelNoteAverage(testId), closeTo(4.0, 0.001));
      expect(p.levelNotePassCount(testId), 1);
      expect(find.textContaining('Puntuación del nivel'), findsNothing);
      expect(p.unlockedLevel('estequiometria'), 2);

      // Segundo pase 5/5: nota 5,0. Promedio (4,0 + 5,0) / 2 = 4,5.
      await tester.tap(find.text(tr('quizRepeat')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
      await playLevelAllCorrect(tester);
      expect(find.text('5 de 5 Aciertos'), findsOneWidget);
      expect(find.text('Nota: 5.0 / 5'), findsOneWidget);
      expect(find.text('Puntos: +25'), findsOneWidget);
      expect(p.points, 37);
      expect(p.levelNoteAverage(testId), closeTo(4.5, 0.001));
      expect(p.levelNotePassCount(testId), 2);
      expect(
          find.text('Puntuación del nivel: 4,5 · promedio de 2 intentos'),
          findsOneWidget);

      // Replay FALLIDO (0/5): no entra en el promedio, no quita el
      // pase ni re-bloquea el 2, y es neutro en puntos (A3: el
      // saldo vuelve a 37, no cae a 37 − 40 = −3). El resultado
      // muestra Puntos +0: el intento no sumó nada.
      await tester.tap(find.text(tr('quizRepeat')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await playLevelAllWrong(tester);
      expect(find.text('0 de 5 Aciertos'), findsOneWidget);
      expect(find.text('Nota: 0.0 / 5'), findsOneWidget);
      expect(find.text('Puntos: +0'), findsOneWidget);
      expect(p.levelNoteAverage(testId), closeTo(4.5, 0.001));
      expect(p.levelNotePassCount(testId), 2);
      expect(p.bestScore(testId), 100);
      expect(p.unlockedLevel('estequiometria'), 2);
      expect(p.points, 37);
      expect(p.livesLeft, 5);
      // La puntuación registrada sigue mostrándose tras el fallo.
      expect(
          find.text('Puntuación del nivel: 4,5 · promedio de 2 intentos'),
          findsOneWidget);

      // Y el nodo del camino muestra el promedio (90 %), no la mejor.
      await tester.tap(find.text(tr('quizBack')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Nivel 1 · 90%'), findsOneWidget);
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
    testWidgets('pasar 4/5 fallando la difícil (nota 76 %) y '
        'repetir fallando 0/5: el saldo queda intacto', (tester) async {
      await pumpNiveles(tester);
      final p = ProgressService.instance;
      await startLevel1(tester);
      // Nivel 1 5/5: +25 y desbloquea el Nivel 2.
      await playLevelAllCorrect(tester);
      expect(find.text('5 de 5 Aciertos'), findsOneWidget);
      expect(p.points, 25);
      expect(p.unlockedLevel('estequiometria'), 2);

      // Volver al camino y entrar al Nivel 2 (su 5.ª pregunta es
      // la difícil: fallarla da 4/5 con nota 3,8 -> 76 % < 81,
      // el agujero de la vieja condición por nota).
      await tester.tap(find.text(tr('quizBack')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('2').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('2').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);

      // 4/5 fallando la difícil (última): 3 medias y 1 fácil bien
      // (+5+5+5+3) y la difícil mal (−12) = +6; nota 3,8 (76 %).
      await playLevelFourOfFive(tester);
      expect(find.text('4 de 5 Aciertos'), findsOneWidget);
      expect(find.text('Nota: 3.8 / 5'), findsOneWidget);
      expect(find.text('Puntos: +6'), findsOneWidget);
      expect(p.points, 31);
      expect(p.bestScore('level:estequiometria:2'), 76);
      expect(p.levelNoteAverage('level:estequiometria:2'),
          closeTo(3.8, 0.001));
      expect(p.levelNotePassCount('level:estequiometria:2'), 1);
      expect(p.unlockedLevel('estequiometria'), 3);

      // Repetir y fallar 0/5 (−41 sin protección): el saldo queda
      // en 31, intacto; el promedio, el pase y el desbloqueo, igual.
      await tester.tap(find.text(tr('quizRepeat')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await playLevelAllWrong(tester);
      expect(find.text('0 de 5 Aciertos'), findsOneWidget);
      expect(find.text('Puntos: +0'), findsOneWidget);
      expect(p.points, 31);
      expect(p.levelNoteAverage('level:estequiometria:2'),
          closeTo(3.8, 0.001));
      expect(p.levelNotePassCount('level:estequiometria:2'), 1);
      expect(p.bestScore('level:estequiometria:2'), 76);
      expect(p.unlockedLevel('estequiometria'), 3);
      expect(p.livesLeft, 5);
      expect(tester.takeException(), isNull);
    });
  });

  group('SimpleQuizRunner: mismo bug al reutilizar el State', () {
    testWidgets('Repetir con otro lote (como el cambio de turno del '
        'Reto): pregunta 1 del lote nuevo, marcador y tiempo a cero',
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
      }

      Future<void> nextSimple() async {
        final nextBtn = find.text(tr('quizNext'));
        final target = nextBtn.evaluate().isNotEmpty
            ? nextBtn
            : find.text(tr('quizResult'));
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
      await tester.tap(find.text(tr('quizResult')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Resultado del primer lote: +3 −8 +8 = +3.
      expect(find.text('Puntos: +3'), findsOneWidget);

      // Repetir: el padre cambia el lote (otro objeto de lista, sin
      // desmontar el runner, como el Reto al cambiar de jugador).
      await tester.tap(find.text(tr('quizRepeat')));
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
/// lote de preguntas al pulsar Repetir (el Reto hace lo mismo al
/// pasar del jugador 1 al 2: cambia `items` sin desmontar el runner).
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
