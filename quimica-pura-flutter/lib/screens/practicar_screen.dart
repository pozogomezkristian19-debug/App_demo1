import '../widgets/duo_button.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/accent.dart';
import '../widgets/lucide_icons.dart';
import '../data/i18n/content_i18n.dart';
import '../data/questions.dart';
import '../models.dart';
import '../services/home_widget_service.dart';

import '../services/localization.dart';
import '../services/nav_requests.dart';
import '../services/numeric_answer.dart';
import '../services/points.dart';
import '../services/progress.dart';
import '../services/question_generator.dart';
import '../services/sound_service.dart';
import '../services/user_prefs.dart';
import '../widgets/brand_logo.dart';
import '../widgets/celebration.dart';
import '../widgets/report_question.dart';
import '../widgets/simple_quiz.dart';
import '../screens/calculator_screen.dart';
import '../widgets/twin_avatars.dart';

// Practicar estilo Duolingo: niveles por tema, repaso de errores y memoria
// que no se borra al cerrar la app (todo vive en ProgressService, que
// guarda en SharedPreferences).
//
// - Cada tema se parte en niveles de 5 preguntas. Para pasar de nivel
//   hay que acertar 4 o más de 5 preguntas (fix5, punto 13: por conteo
//   de aciertos, sin importar la dificultad — es lo que promete el
//   mensaje "necesitas 4 de 5"). La nota ponderada sobre 5 se sigue
//   mostrando, pero ya no es la puerta: con la regla vieja (nota > 4,0)
//   4 medias de 5 daban 4,0 exactos y NO pasaban. Al pasarlo se
//   desbloquea el siguiente.
//   Cada respuesta suma o resta puntos del saldo total (ver points.dart).
// - Abandonar un nivel en curso (Salir o atrás) cuesta 1 vida; hay 5 al
//   día y se reponen cada día nuevo. Con 0 vidas no se puede empezar.
//   Ganar un nivel completo devuelve 1 vida (hasta 5). Las reglas
//   ("¿Cómo se juega?") viven como PANTALLA COMPLETA en Cuenta
//   (ronda fix5, punto 1): el auto-show de la primera entrada a
//   Niveles ya no existe, al abrir la app lo primero que se ve son
//   los niveles.
// - El repaso es POR NIVEL y con VARIANTES (v6): no se repite la misma
//   pregunta, sino el mismo concepto con otros datos, y hacen falta 3
//   aciertos seguidos para dar un error por superado.
//   Los niveles usan primero las preguntas del banco, en orden, y después
//   preguntas nuevas generadas, así un nivel siempre tiene 5 preguntas.
// - El examen mixto es el reto final: se desbloquea cuando se pasa el
//   Nivel 1 de todos los temas de la pista. Sus preguntas pesan hacia los
//   temas más débiles del usuario.
// - Cada error se guarda. 'Repasar mis errores' repite solo las preguntas
//   falladas: acertar una la saca de la lista, fallarla la deja.
// - Cada nivel empieza con hasta 2 errores pendientes de ese tema.
// - Dos pistas: Bachillerato (4 temas, examen mixto de 16) y Universidad
//   (10 temas, examen mixto de 24). Cada pista tiene su propio progreso
//   guardado (ver ProgressService.setTrack).

const int _levelSize = 5;

/// Umbral del porcentaje guardado (nota5 x 20) para la etiqueta
/// "Excelente" en los quizzes que NO son de nivel (fix5, punto 13:
/// ya NO es la puerta de los niveles: pasar es acertar 4 de 5, y si
/// un nivel está pasado se sabe por unlockedLevel, no por la nota).
const int _passPercent = 81;
const int _mixedSize = 24; // examen mixto de Universidad
const int _mixedSizeBach = 16; // examen mixto de Bachillerato
const int _reviewMax = 20;

/// Temas de la pista Universidad, en orden.
const List<String> uniTopics = [
  'estequiometria',
  'gases',
  'disoluciones',
  'acido-base',
  'equilibrio',
  'termo-cinetica',
  'tabla',
  'enlace',
  'organica',
  'laboratorio',
];

/// Temas de la pista Bachillerato, en orden.
const List<String> bachTopics = [
  'bach-estequiometria',
  'bach-disoluciones',
  'bach-gases',
  'bach-acido-base',
];

// ---- Camino de niveles (estilo Duolingo / Candy Crush) ----

// Alturas fijas del camino: las filas usan las mismas, así el
// camino queda centrado en cada nodo.
const double _headerH = 140.0; // banner de unidad Duolingo (§3.2.4)
const double _rowH = 100.0;
// Aire entre el cartel del tema y el primer nodo (fix4, punto 13
// REVISADO y retoque del halo): la bolita del nivel 1 chocaba con
// el cartel; con 28 px el halo del nodo actual queda a 26 px del
// cartel en reposo y a ~21 px en su pulso máximo, y la bolita a 32.
const double _pathTopGap = 28.0;
// Nodo Duolingo (§3.2.1): 80 dp, cara sólida teal + labio 4 px.
const double _nodeSize = 80.0;
const double _nodeCenterY = 50.0; // centro del nodo dentro de su fila

// Desplazamiento horizontal de cada nodo (px desde el centro): el camino
// serpentea izquierda-centro-derecha, como en Duolingo.
const List<double> _pathOffsets = [0, -52, -78, -52, 0, 52, 78, 52];



// Rediseño claro estilo Duolingo (color propio, teal de Melli-Qui):
// el camino, sus nodos y las cabeceras de tema usan todos el mismo
// teal de la marca; no hay un color distinto por tema. (El mapa de
// iconos por tema se quitó en el rediseño: el banner lleva la
// mascota ilustrada en lugar del círculo con el símbolo del tema.)

String bankId(QuizQuestion q) => 'bank:${q.topic}:${q.question}';

class _QuizItem {
  const _QuizItem(
      {required this.id, required this.question, this.reviewEntryId});

  final String id; // 'bank:...' o 'gen:...'
  final QuizQuestion question;

  /// En el repaso de variantes: la entrada fallada original que esta
  /// variante está repasando (su id). null en niveles y mixto.
  final String? reviewEntryId;
}

class _QuizSpec {
  const _QuizSpec(
      {required this.kind, this.topic, this.level = 0, this.reviewOnly});
  final String kind; // 'level', 'review' o 'mixto'
  final String? topic;
  final int level;

  /// Repaso inteligente: solo estas entradas (los errores de días
  /// anteriores). null = todos los errores.
  final List<FailedEntry>? reviewOnly;
}

class PracticarScreen extends StatefulWidget {
  const PracticarScreen({super.key, this.onOpenScreen, this.onSessionChanged});

  /// Abre una pantalla del menú por su clave (examen con tiempo,
  /// reto…): lo resuelve HomeScreen con _openScreenKey.
  final void Function(String key)? onOpenScreen;

  /// Avisa a HomeScreen cuando empieza/termina una sesión de juego
  /// (quiz de nivel, repaso o examen mixto en línea): mientras hay
  /// sesión activa, la barra inferior y la barra de arriba se
  /// ocultan, y la única salida es el botón Salir (fix2).
  final void Function(bool inSession)? onSessionChanged;

  @override
  State<PracticarScreen> createState() => _PracticarScreenState();
}

class _PracticarScreenState extends State<PracticarScreen> {
  _QuizState? _quiz;
  _QuizSpec? _spec;

  /// ¿El quiz abierto ya terminó (resultado en pantalla)? Solo
  /// abandonar ANTES de terminar cuesta una vida.
  var _finishedQuiz = false;

  /// Contador de inicios de quiz: cada _start() lo sube, y el
  /// _QuizRunner lleva un ValueKey con él, así que Repetir crea un
  /// State nuevo y limpio en vez de reutilizar el del intento
  /// anterior (fix5, punto Repetir: el resultado viejo se quedaba
  /// y el confeti volvía a caer).
  var _runId = 0;

  // Para volver al punto donde va el usuario al abrir el camino.
  final _currentKey = GlobalKey();
  var _scrolledToCurrent = false;
  var _backRegistered = false;

  @override
  void dispose() {
    if (_backRegistered) BackNav.unregister(_closeQuiz);
    super.dispose();
  }

  /// Cierra el quiz abierto (manejador del botón atrás): abandonar un
  /// nivel en curso cuesta 1 vida, igual que el botón Salir, así que
  /// también pide confirmación antes de salir.
  bool _closeQuiz() {
    if (_quiz == null) return false;
    _requestExitQuiz();
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _consumeNavRequests();
  }

  @override
  void didUpdateWidget(PracticarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _consumeNavRequests();
  }

  /// Consume la petición de repaso (NavRequests.startReview).
  /// Antes solo se miraba en didChangeDependencies: si ya estabas
  /// en Niveles al tocar "Repasar mis errores" en la barra, la
  /// petición se perdía sin hacer nada (auditoría fix2).
  void _consumeNavRequests() {
    // Petición del menú ("Repasar mis errores"): empieza el repaso.
    if (NavRequests.startReview) {
      NavRequests.startReview = false;
      if (ProgressService.instance.failedCount > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _start(const _QuizSpec(kind: 'review')));
      }
    }
  }

  /// ¿El tema i está desbloqueado? En orden: hay que completar TODOS
  /// los niveles del tema anterior para abrir el siguiente. El primer
  /// tema siempre está abierto.
  bool _topicUnlocked(int i) {
    if (i == 0) return true;
    final topics = _byTopic.keys.toList();
    final prev = topics[i - 1];
    return ProgressService.instance.isTopicComplete(prev);
  }

  /// Primer nivel sin pasar (tema y nivel), o null si ya pasó todo.
  /// Solo mira temas desbloqueados: con temas en orden, el primero sin
  /// pasar es siempre el tema actual.
  ({int topicIndex, int level})? _firstUnpassed() {
    final topics = _byTopic.keys.toList();
    for (var i = 0; i < topics.length; i++) {
      if (!_topicUnlocked(i)) return null;
      final unlocked = ProgressService.instance.unlockedLevel(topics[i]);
      if (unlocked <= _levelCount(topics[i])) {
        return (topicIndex: i, level: unlocked);
      }
    }
    return null;
  }

  /// Desplaza el camino hasta el nodo actual (o al trofeo final si ya
  /// pasó todo), solo cuando ese nodo queda fuera de la primera pantalla.
  void _scrollToCurrent() {
    final ctx = _currentKey.currentContext;
    if (ctx == null) return;
    final current = _firstUnpassed();
    final needsScroll =
        current == null || current.topicIndex > 0 || current.level > 2;
    if (!needsScroll) return;
    Scrollable.ensureVisible(ctx,
        alignment: 0.45, duration: const Duration(milliseconds: 400));
  }

  /// Temas y preguntas del banco de la pista actual, en el idioma
  /// activo, en el orden de la pista.
  Map<String, List<QuizQuestion>> get _byTopic {
    final wanted = ProgressService.track == ProgressService.trackBach
        ? bachTopics
        : uniTopics;
    final byTopic = <String, List<QuizQuestion>>{
      for (final t in wanted) t: <QuizQuestion>[],
    };
    for (final q in localizedAllQuestions()) {
      byTopic[q.topic]?.add(q);
    }
    return byTopic;
  }

  /// Lo mismo, pero con los textos españoles: los ids persistentes de
  /// los errores se construyen SIEMPRE con el texto español, para que
  /// no dependan del idioma activo.
  Map<String, List<QuizQuestion>> get _spanishByTopic {
    final wanted = ProgressService.track == ProgressService.trackBach
        ? bachTopics
        : uniTopics;
    final byTopic = <String, List<QuizQuestion>>{
      for (final t in wanted) t: <QuizQuestion>[],
    };
    for (final q in allQuestions) {
      byTopic[q.topic]?.add(q);
    }
    return byTopic;
  }

  int _levelCount(String topic) => ProgressService.levelCountForTopic(topic);

  /// Resuelve una entrada fallada a su pregunta (banco o generada),
  /// en el idioma activo.
  QuizQuestion? _resolveFailed(FailedEntry f) {
    if (f.id.startsWith('gen:')) {
      return rebuildGenerated(f.id)?.question;
    }
    for (var i = 0; i < allQuestions.length; i++) {
      final q = allQuestions[i];
      if (q.topic == f.topic && q.question == f.question) {
        return localizedQuestionAt(i);
      }
    }
    return null;
  }

  List<_QuizItem> _buildLevelQuestions(String topic, int level) {
    final progress = ProgressService.instance;
    final bank = _byTopic[topic] ?? <QuizQuestion>[];
    final spanishBank = _spanishByTopic[topic] ?? <QuizQuestion>[];
    final items = <_QuizItem>[];
    final used = <String>{};
    // Hasta 2 errores pendientes del tema, primero.
    for (final f in progress.failedForTopic(topic).take(2)) {
      final q = _resolveFailed(f);
      if (q != null && used.add(f.id)) {
        items.add(_QuizItem(id: f.id, question: q));
      }
    }
    // Después, las preguntas del banco de este nivel, en orden, hasta
    // completar 5 en total (los errores pendientes ocupan su sitio).
    // El id se calcula con la pregunta española (índice alineado).
    final start = (level - 1) * _levelSize;
    if (start < bank.length && items.length < _levelSize) {
      final end = min(start + (_levelSize - items.length), bank.length);
      for (var i = start; i < end; i++) {
        final id = bankId(spanishBank[i]);
        if (used.add(id)) items.add(_QuizItem(id: id, question: bank[i]));
      }
    }
    // Y preguntas nuevas generadas hasta completar 5 (solo si el tema
    // tiene generador; orgánica y laboratorio son solo de banco).
    if (topicGeneratorTypes.containsKey(topic)) {
      final rng = Random();
      var guard = 0;
      while (items.length < _levelSize && guard < 60) {
        guard++;
        final g = generateForTopic(topic, rng);
        if (used.add(g.id)) {
          items.add(_QuizItem(id: g.id, question: g.question));
        }
      }
    }
    return items;
  }

  /// Repaso con VARIANTES (v6): nunca se muestra la misma pregunta
  /// que se falló. Cada error se repasa con al menos 3 preguntas nuevas
  /// del mismo concepto y con otros datos: del generador si el tema
  /// tiene (o del mismo tipo si la fallada era generada), y de otras
  /// preguntas del banco del mismo tema si no (orgánica, laboratorio).
  /// Cada variante lleva el id de la entrada original, para que al
  /// contestarla se sume su racha de repaso (3 seguidos = superada).
  List<_QuizItem> _buildReviewQuestions([List<FailedEntry>? only]) {
    final progress = ProgressService.instance;
    final items = <_QuizItem>[];
    final entries = List<FailedEntry>.of(only ?? progress.failedEntries)
      ..shuffle();
    final rng = Random();
    for (final f in entries) {
      if (items.length >= _reviewMax) break;
      var made = 0;
      var guard = 0;
      while (made < 3 && guard < 12 && items.length < _reviewMax) {
        guard++;
        GeneratedQuestion? g;
        if (f.id.startsWith('gen:')) {
          g = generateVariantForFailed(f.id, f.topic, rng);
        } else if (topicGeneratorTypes.containsKey(f.topic)) {
          g = generateForTopic(f.topic, rng);
        }
        if (g != null) {
          if (items.any((it) => it.id == g!.id)) continue;
          items.add(
              _QuizItem(id: g.id, question: g.question, reviewEntryId: f.id));
          made++;
        } else {
          // Sin generador: otras preguntas del banco del mismo tema
          // (nunca la fallada), con id español estable.
          final bank = _byTopic[f.topic] ?? <QuizQuestion>[];
          final spanishBank = _spanishByTopic[f.topic] ?? <QuizQuestion>[];
          final pool = <int>[];
          for (var i = 0; i < bank.length; i++) {
            if (bank[i].question != f.question) pool.add(i);
          }
          pool.shuffle(rng);
          for (final i in pool) {
            if (made >= 3 || items.length >= _reviewMax) break;
            final id = bankId(spanishBank[i]);
            if (items.any((it) => it.id == id)) continue;
            // La pregunta se muestra en el idioma activo.
            items
                .add(_QuizItem(id: id, question: bank[i], reviewEntryId: f.id));
            made++;
          }
          break; // sin generador no hay más variantes que probar
        }
      }
      if (made == 0) {
        // No se pudo hacer ninguna variante: la pregunta original.
        final q = _resolveFailed(f);
        if (q != null && items.length < _reviewMax) {
          items.add(_QuizItem(id: f.id, question: q, reviewEntryId: f.id));
        }
      }
    }
    items.shuffle(rng);
    return items;
  }

  List<_QuizItem> _buildMixedQuestions() {
    final progress = ProgressService.instance;
    final weakest = progress
        .weakestTopics(_byTopic.keys.toList()); // del más débil al más fuerte
    final size = ProgressService.track == ProgressService.trackBach
        ? _mixedSizeBach
        : _mixedSize;
    final rng = Random();
    final items = <_QuizItem>[];
    final used = <String>{};
    // 2 preguntas del banco por tema, empezando por los más débiles.
    // El id se calcula con la pregunta española (índice alineado).
    for (final topic in weakest) {
      final pool = List<QuizQuestion>.of(_byTopic[topic] ?? <QuizQuestion>[]);
      final spanishPool = _spanishByTopic[topic] ?? <QuizQuestion>[];
      final order = List<int>.generate(pool.length, (i) => i)..shuffle(rng);
      for (final i in order.take(2)) {
        final id = bankId(spanishPool[i]);
        if (used.add(id)) items.add(_QuizItem(id: id, question: pool[i]));
      }
    }
    // El resto, preguntas nuevas pesando hacia los temas más débiles.
    // Solo cuentan los temas con generador (orgánica y laboratorio no
    // tienen: sus preguntas ya están en el banco de arriba).
    final adaptiveTopics =
        weakest.where((t) => topicGeneratorTypes.containsKey(t)).toList();
    var guard = 0;
    while (items.length < size && guard < 200) {
      guard++;
      final g = generateAdaptive(
          adaptiveTopics.isEmpty ? weakest : adaptiveTopics, rng);
      if (used.add(g.id)) {
        items.add(_QuizItem(id: g.id, question: g.question));
      }
    }
    items.shuffle(rng);
    return items;
  }

  List<_QuizItem> _buildQuestions(_QuizSpec spec) {
    switch (spec.kind) {
      case 'level':
        return _buildLevelQuestions(spec.topic!, spec.level);
      case 'review':
        return _buildReviewQuestions(spec.reviewOnly);
      default:
        return _buildMixedQuestions();
    }
  }

  String _titleFor(_QuizSpec spec) {
    switch (spec.kind) {
      case 'level':
        return '${localizedTopicName(spec.topic!)} · ${tr('levelWord')} ${spec.level}';
      case 'review':
        return spec.reviewOnly != null
            ? tr('smartReviewTitle')
            : tr('reviewTitle');
      default:
        return tr('mixedTitle');
    }
  }

  void _start(_QuizSpec spec) {
    // Sin vidas no se puede empezar un nivel (v6): hay que esperar a
    // mañana, cuando se reponen las 5.
    if (spec.kind == 'level' && !ProgressService.instance.canStartLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('livesEmptyBody')),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    final questions = _buildQuestions(spec);
    if (questions.isEmpty) return;
    _scrolledToCurrent = false;
    if (!_backRegistered) {
      BackNav.register(_closeQuiz);
      _backRegistered = true;
    }
    // Replay de un nivel ya pasado (fix5, A3): "ya pasado" es
    // unlockedLevel > level — el mismo listón que usa el nodo del
    // camino —, NO la mejor nota: un 4/5 fallando la difícil
    // guarda 76 % (< 81) y con la nota como listón la protección
    // no saltaba. El snapshot es el saldo de antes de empezar.
    final progress = ProgressService.instance;
    final replayOfPassed = spec.kind == 'level' &&
        progress.unlockedLevel(spec.topic!) > spec.level;
    final pointsSnapshot = progress.points;
    setState(() {
      _spec = spec;
      _finishedQuiz = false;
      _runId++;
      _quiz = _QuizState(
        testId: spec.kind == 'level'
            ? 'level:${spec.topic}:${spec.level}'
            : spec.kind,
        title: _titleFor(spec),
        items: questions,
        replayOfPassed: replayOfPassed,
        pointsSnapshot: pointsSnapshot,
      );
    });
    widget.onSessionChanged?.call(true);
  }

  void _exitQuiz() {
    if (_backRegistered) {
      BackNav.unregister(_closeQuiz);
      _backRegistered = false;
    }
    // Abandonar un nivel en curso cuesta 1 vida (v6). Terminarlo
    // (aprobado o suspendido) no cuesta nada.
    if (_spec != null && _spec!.kind == 'level' && !_finishedQuiz) {
      ProgressService.instance.loseLifeOnAbandon();
    }
    setState(() => _quiz = null);
    widget.onSessionChanged?.call(false);
  }

  /// Salir de un quiz pidiendo confirmación cuando cuesta una vida:
  /// de un nivel sin terminar se sale solo si el usuario confirma el
  /// aviso ("Si sales ahora, pierdes una vida, ¿seguro?"). De un
  /// examen, un repaso o un quiz ya terminado se sale directo.
  void _requestExitQuiz() {
    if (_spec != null && _spec!.kind == 'level' && !_finishedQuiz) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('exitLevelTitle')),
          content: Text(tr('exitLevelBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('exitLevelStay')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _exitQuiz();
              },
              child: Text(tr('exitLevelLeave')),
            ),
          ],
        ),
      );
      return;
    }
    _exitQuiz();
  }

  void _repeat() {
    if (_spec != null) _start(_spec!);
  }

  /// Salta al nivel siguiente del mismo tema (fix5, punto 13): usa
  /// el mismo arranque que Repetir, así el nivel nuevo empieza de
  /// verdad (pregunta 1, marcador a cero).
  void _nextLevel() {
    if (_spec != null && _spec!.kind == 'level') {
      _start(_QuizSpec(
          kind: 'level', topic: _spec!.topic, level: _spec!.level + 1));
    }
  }

  bool _mixedUnlocked() {
    final progress = ProgressService.instance;
    // Desbloqueado cuando el Nivel 1 está pasado en todos los temas:
    // pasar el Nivel 1 sube el nivel desbloqueado a 2.
    return _byTopic.keys.every((topic) => progress.unlockedLevel(topic) >= 2);
  }

  List<String> _missingLevel1Topics() {
    final progress = ProgressService.instance;
    return _byTopic.keys
        .where((topic) => progress.unlockedLevel(topic) < 2)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_quiz != null) {
      return _QuizRunner(
        key: ValueKey('quiz-run-$_runId'),
        quiz: _quiz!,
        spec: _spec!,
        onExit: _requestExitQuiz,
        onRepeat: _repeat,
        onFinished: () => _finishedQuiz = true,
        // "Pasar de nivel" (fix5, punto 13): solo en niveles y solo
        // si hay uno después; en el último nivel del tema no hay
        // botón (el resultado solo ofrece Repetir y Volver).
        onNextLevel: _spec!.kind == 'level' &&
                _spec!.level < _levelCount(_spec!.topic!)
            ? _nextLevel
            : null,
      );
    }
    final progress = ProgressService.instance;
    final byTopic = _byTopic;
    final topics = byTopic.keys.toList();
    final mixedUnlocked = _mixedUnlocked();
    final level1Done = topics.length - _missingLevel1Topics().length;
    final current = _firstUnpassed();
    if (!_scrolledToCurrent) {
      _scrolledToCurrent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }

    final bankTotal =
        byTopic.values.fold<int>(0, (sum, list) => sum + list.length);
    final mixedSize = ProgressService.track == ProgressService.trackBach
        ? _mixedSizeBach
        : _mixedSize;
    // Una sección del camino (tema + sus niveles). Es un cierre para
    // poder poner el PRIMER tema antes que el resto (fix5, punto 2):
    // el camino es lo primero que se ve al abrir Niveles.
    Widget topicSection(int i) {
      return _TopicPathSection(
        topic: topics[i],
        bankCount: byTopic[topics[i]]!.length,
        levelCount: _levelCount(topics[i]),
        locked: !_topicUnlocked(i),
        currentLevel:
            current != null && current.topicIndex == i ? current.level : 0,
        currentKey:
            current != null && current.topicIndex == i ? _currentKey : null,
        onLevelTap: (level, unlocked) {
          if (!_topicUnlocked(i)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('topicLocked'))),
            );
            return;
          }
          if (unlocked) {
            _start(_QuizSpec(kind: 'level', topic: topics[i], level: level));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${tr('quizLevelFailed')} (${tr('levelWord')} ${level - 1})'),
              ),
            );
          }
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera compacta (fix2, item 3): solo el título, sin
          // el párrafo de introducción y sin el "Superado: 0 / 55"
          // (rediseño Duolingo §3.2.5: ese dato vive en Estadísticas
          // y en el HUD). El camino va justo debajo (fix5, punto 2).
          Text(tr('levelsTitle'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          // El recordatorio ("es hora de practicar") sigue aquí arriba
          // cuando toca; la tarjeta de estadísticas (vidas/puntos/
          // racha/meta) ya NO está en Niveles: vive en Cuenta (fix 3),
          // así el camino empieza más arriba y se ve más.
          const _ReminderCard(),
          // EL CAMINO PRIMERO (fix5, punto 2): el primer tema con su
          // nodo 1 va justo debajo de la cabecera. Así, al abrir
          // Niveles, el camino domina la primera pantalla y el nodo
          // 1 se ve sin deslizar (a 393x852 el nodo 1 queda a
          // ~215 dp, con los nodos 1-5 visibles). (fix6, ronda #6:
          // Niveles es SOLO el camino: la pregunta del día se
          // eliminó por completo de la app y "Practicar de otra
          // forma" ya no está aquí.)
          topicSection(0),
          const SizedBox(height: 20),
          // Repaso inteligente: errores de días anteriores que resurgen.
          // Tarjeta 3D (ronda de diseño 7.0): sombra suave tintada y
          // radio 16 en vez de la Card plana de antes.
          if (progress.dueFailed().isNotEmpty)
            Card(
              elevation: 3,
              shadowColor: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                // Icono 3D (fix3, punto 6): ámbar con degradado +
                // brillito, como el corazón de las vidas.
                leading: const LucideIcon(LucideIcons.sparkles,
                    size: 32, color: BrandColors.amber, threeD: true),
                title: Text(tr('smartReviewTitle'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${progress.dueFailed().length} ${tr('reviewQuestions')} de días anteriores'),
                trailing: const LucideIcon(LucideIcons.chevronRight),
                onTap: () => _start(_QuizSpec(
                    kind: 'review', reviewOnly: progress.dueFailed())),
              ),
            ),
          if (progress.dueFailed().isNotEmpty) const SizedBox(height: 8),
          // La tarjeta "Repasar mis errores" POR NIVEL ya NO está en
          // Niveles (fix4, punto 4): con un solo error empujaba el
          // camino de niveles muy abajo. El repaso sigue en el chip
          // de la barra superior y en "Mis errores" de Cuenta (los
          // dos abren el repaso general, sin grupos por nivel).
          // (fix6, ronda #6): Niveles es SOLO el camino. La
          // "Pregunta del día" se eliminó por completo de la app;
          // "Practicar de otra forma" (Examen con tiempo)
          // sigue existiendo y se abre desde la búsqueda.
          // El resto de temas del camino.
          for (var i = 1; i < topics.length; i++) topicSection(i),
          // Examen mixto: trofeo final del camino, bloqueado hasta pasar
          // el Nivel 1 de todos los temas de la pista.
          _FinalExamSection(
            unlocked: mixedUnlocked,
            level1Done: level1Done,
            topicCount: topics.length,
            mixedSize: mixedSize,
            isCurrent: current == null,
            currentKey: current == null ? _currentKey : null,
            onTap: () {
              if (mixedUnlocked) {
                _start(const _QuizSpec(kind: 'mixto'));
              } else {
                final missing = _missingLevel1Topics()
                    .map((t) => localizedTopicName(t))
                    .join(', ');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${tr('mixedLocked')}: $missing.'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          Text(
            '$bankTotal ${tr('questionsWord')} ${tr('bankWord')} + ${tr('newWord')}',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// (Rediseño Duolingo §3.2.3: la línea discontinua que conectaba los
// nodos se borró — el _PathPainter que la pintaba se eliminó.)

/// Una sección del camino: un tema con su cabecera y sus niveles en
/// camino serpenteante, como una unidad de Duolingo. El camino de cada
/// tema lleva su propio color; un tema bloqueado (todavía no se terminó
/// el anterior) se ve con candado y no se puede abrir.
class _TopicPathSection extends StatelessWidget {
  const _TopicPathSection({
    required this.topic,
    required this.bankCount,
    required this.levelCount,
    required this.locked,
    required this.currentLevel,
    required this.currentKey,
    required this.onLevelTap,
  });

  final String topic;
  final int bankCount;
  final int levelCount;

  /// true si el tema anterior no está completo todavía.
  final bool locked;

  /// Nivel actual del tema (0 si ninguno es el actual).
  final int currentLevel;
  final GlobalKey? currentKey;
  final void Function(int level, bool unlocked) onLevelTap;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressService.instance;
    final unlocked = locked ? 0 : progress.unlockedLevel(topic);
    var best = 0;
    for (var i = 1; i <= levelCount; i++) {
      final s = progress.bestScore('level:$topic:$i');
      if (s > best) best = s;
    }
    // Cabecera y camino en el color de acento (fix2, item 12; gris
    // si el tema está bloqueado): todos los temas comparten el color.
    // Las linecitas punteadas entre nodos volvieron (corrección de
    // Kristian, 2026-11-11): el camino serpenteante las llevaba en
    // la 6.3 y el rediseño Duolingo las había quitado.
    return SizedBox(
      height: _headerH + _pathTopGap + levelCount * _rowH,
      child: Column(
        children: [
              SizedBox(
                height: _headerH,
                child: Container(
                  // Banner de unidad Duolingo (§3.2.4): teal SÓLIDO
                  // (sin degradado, sin brillo, sin sombra), 140 pt
                  // de alto, radio 16. Título en MAYÚSCULAS 20 pt
                  // peso 800 blanco (decisión de Kristian, ronda 3:
                  // los nombres de tema del camino van en mayúsculas,
                  // y el subtítulo también); subtítulo 15 pt peso 500
                  // blanco al 85 %. A la derecha, la mascota ilustrada
                  // (Brenda/Britany, sin aro) en lugar del círculo
                  // blanco con el símbolo del tema.
                  decoration: BoxDecoration(
                    color: locked
                        ? const Color(0xFFE5E5E5)
                        : AppAccent.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cabecera del camino (fix3): el título
                            // COMPLETO del tema (topics.dart), nunca
                            // el id interno: 'bach-disoluciones' se
                            // ve como 'Disoluciones y concentración',
                            // también en la tarjeta bloqueada.
                            // Título auto-escalado (alcance 8,
                            // 2026-11-12): el título NUNCA parte una
                            // palabra ni se corta ("ESTEQUIOMETRÍ /
                            // A Y EL MOL" en la captura). Base 20 pt
                            // en MAYÚSCULAS; si no cabe en 2 líneas,
                            // el FittedBox lo reduce hasta que quepa.
                            // Las palabras solo se parten entre
                            // ellas: el salto se decide al tamaño
                            // base, donde la palabra más larga
                            // ("ESTEQUIOMETRÍA") cabe en la línea.
                            // La caja fija de 54 pt (= 2 líneas a
                            // 20 pt) es lo que hace que el FittedBox
                            // escale: sin altura acotada no hay nada
                            // contra lo que escalar. Sin maxLines ni
                            // ellipsis: nada se corta. Vale para
                            // los 14 temas del camino (10 Uni + 4
                            // Bach) en sus dos versiones
                            // (bloqueado/desbloqueado) y los dos
                            // temas (claro/oscuro).
                            LayoutBuilder(
                              builder: (context, constraints) => SizedBox(
                                height: 54,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    child: Text(
                                        localizedTopicTitle(topic)
                                            .toUpperCase(),
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: locked
                                                ? BrandColors.ink
                                                    .withValues(alpha: 0.6)
                                                : Colors.white)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              locked
                                  ? tr('lockedWord').toUpperCase()
                                  : '${tr('levelWord')} ${unlocked > levelCount ? levelCount : unlocked} ${tr('quizOf')} $levelCount · ${tr('bestWord')}: $best%'
                                      .toUpperCase(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: locked
                                    ? BrandColors.ink.withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Mascota ilustrada a la derecha (sin aro, sin
                      // círculo blanco): Brenda los días pares y
                      // Britany los impares.
                      ClipOval(
                        child: Image.asset(
                          companionAsset(DateTime.now().day.isEven
                              ? Companion.brenda
                              : Companion.britany),
                          width: 104,
                          height: 104,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Aire entre el cartel y el primer nodo (fix4, punto 13
              // REVISADO): sin esto la bolita del nivel 1 tocaba el
              // cartel. El pintor usa el mismo hueco (_pathTopGap).
              const SizedBox(height: _pathTopGap),
              for (var level = 1; level <= levelCount; level++)
                _LevelNodeRow(
                  key: level == currentLevel ? currentKey : null,
                  topic: topic,
                  level: level,
                  bankCount: bankCount,
                  isLast: level == levelCount,
                  unlocked: !locked && level <= unlocked,
                  isCurrent: level == currentLevel,
                  onLevelTap: onLevelTap,
                ),
        ],
      ),
    );
  }
}

/// Una fila del camino: un nodo de nivel, desplazado a izquierda, centro
/// o derecha para que el camino serpentee. El nodo actual respira con
/// una animación suave (halo que crece y encoge), para que se vea dónde
/// va el usuario sin buscarlo.
/// La linecilla punteada que une un nodo con el siguiente (como
/// en la 6.3): puntos a lo largo del segmento que va del centro de
/// este nodo al centro del siguiente. Se pinta detrás de los
/// nodos, así que los círculos tapan los puntos que caen debajo
/// de ellos y solo se ve el tramo del hueco entre nodos.
class _NodeConnectorPainter extends CustomPainter {
  const _NodeConnectorPainter({
    required this.fromX,
    required this.toX,
    required this.color,
  });

  final double fromX;
  final double toX;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final from = Offset(fromX, _nodeCenterY);
    final to = Offset(toX, _nodeCenterY + _rowH);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final dist = (to - from).distance;
    const step = 10.0;
    const radius = 2.5;
    if (dist <= 0) return;
    final count = (dist / step).floor();
    for (var i = 0; i <= count; i++) {
      final t = (i * step) / dist;
      final p = Offset.lerp(from, to, t)!;
      canvas.drawCircle(p, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_NodeConnectorPainter old) =>
      fromX != old.fromX || toX != old.toX || color != old.color;
}

class _LevelNodeRow extends StatefulWidget {
  const _LevelNodeRow({
    super.key,
    required this.topic,
    required this.level,
    required this.bankCount,
    required this.isLast,
    required this.unlocked,
    required this.isCurrent,
    required this.onLevelTap,
  });

  final String topic;
  final int level;
  final int bankCount;

  /// true si es el último nivel del tema: no hay conector hacia
  /// ningún nodo siguiente.
  final bool isLast;
  final bool unlocked;
  final bool isCurrent;
  final void Function(int level, bool unlocked) onLevelTap;

  @override
  State<_LevelNodeRow> createState() => _LevelNodeRowState();
}

class _LevelNodeRowState extends State<_LevelNodeRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    if (widget.isCurrent) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_LevelNodeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isCurrent && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppAccent.primary;
    final accentDark = AppAccent.primaryDark;
    final progress = ProgressService.instance;
    final best = progress.bestScore('level:${widget.topic}:${widget.level}');
    // Pasado = desbloqueado el siguiente (fix5, punto 13): con la
    // regla por conteo, un 4/5 puede guardar 73-80 % de nota y la
    // nota ya no dice si se pasó; unlockedLevel sí, siempre.
    final passed = progress.unlockedLevel(widget.topic) > widget.level;
    // Estrellas de la corona del nodo pasado (§3.2.1): de la mejor
    // nota del nivel (≥90 %: 3, ≥70 %: 2, si no: 1).
    final stars = best >= 90 ? 3 : (best >= 70 ? 2 : 1);
    final offset = _pathOffsets[(widget.level - 1) % _pathOffsets.length];
    // Nodo Duolingo (§3.2.1): 80 dp, cara SÓLIDA teal + labio 4 px
    // #00A18D (sombra sólida sin desenfoque), sin degradado, sin
    // brillo, sin halo. Bloqueado: #E5E5E5 + candado #AFAFAF.
    final bool nodeLit = passed || widget.unlocked;
    final Widget inner;
    if (passed) {
      // Nivel pasado: estrella blanca rellena (nunca el número).
      inner = const Icon(Icons.star, color: Colors.white, size: 36);
    } else if (widget.unlocked) {
      inner = Text('${widget.level}',
          style: const TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white));
    } else {
      // Nodo bloqueado: gris claro con candado gris.
      inner = const LucideIcon(LucideIcons.lock,
          color: Color(0xFFAFAFAF), size: 32);
    }
    return SizedBox(
      height: _rowH,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cx = constraints.maxWidth / 2 + offset;
          // Centro del nodo siguiente en las coordenadas de esta
          // fila (una fila más abajo): la linecilla punteada va
          // del centro de este nodo a ese centro.
          final nextOffset =
              _pathOffsets[widget.level % _pathOffsets.length];
          final nextCx = constraints.maxWidth / 2 + nextOffset;
          // Sin recorte (Clip.none): el halo del nodo actual mide
          // 92 px centrado en el nodo y en su pulso máximo llega a
          // ~103 px, así que sobresale un poco por encima de la
          // fila; con el recorte por defecto del Stack salía cortado
          // en plano por arriba. El hueco _pathTopGap (28 px) lo
          // absorbe sin tocar el cartel del tema.
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Linecilla punteada hacia el nodo siguiente
              // (corrección de Kristian, 2026-11-11): detrás de
              // todo, para que los nodos la tapen por donde pasan.
              if (!widget.isLast)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _NodeConnectorPainter(
                      fromX: cx,
                      toX: nextCx,
                      color: Theme.of(context).brightness ==
                              Brightness.dark
                          ? const Color(0xFF667885)
                          : const Color(0xFFBDBDBD),
                    ),
                  ),
                ),
              if (widget.isCurrent)
                Positioned(
                  left: cx - 46,
                  top: _nodeCenterY - 46,
                  child: AnimatedBuilder(
                    animation: _scale,
                    builder: (context, child) => Transform.scale(
                      scale: _scale.value,
                      child: child,
                    ),
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppAccent.primary.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
              // La gemela del día, junto al nodo actual, como en
              // Duolingo: a un lado del camino, con aire de sobra
              // (más de 20 dp hasta el halo incluso en su pulso
              // máximo), para que la cara no tape ni roce el
              // círculo del nivel ni su número. El hueco es el
              // mismo a ambos lados y no se sale de la pantalla en
              // ningún desplazamiento del camino: el nodo más a la
              // izquierda lleva la mascota a la derecha y al revés.
              // Rediseño Duolingo (§3.2.7): sin anillo teal.
              if (widget.isCurrent)
                Positioned(
                  left: offset >= 0
                      ? cx - _nodeSize / 2 - 72
                      : cx + _nodeSize / 2 + 32,
                  top: _nodeCenterY - 20,
                  child: CompanionAvatar(
                      companion: companionOfTheDay(),
                      size: 40,
                      ring: false),
                ),
              Positioned(
                left: cx - _nodeSize / 2,
                top: _nodeCenterY - _nodeSize / 2,
                child: GestureDetector(
                  onTap: () {
                    SoundService.tap();
                    widget.onLevelTap(widget.level, widget.unlocked);
                  },
                  child: Container(
                    width: _nodeSize,
                    height: _nodeSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: nodeLit
                          ? accent
                          : const Color(0xFFE5E5E5),
                      // Labio 4 px: sombra sólida (sin desenfoque)
                      // del color oscuro, solo en nodos con color.
                      boxShadow: nodeLit
                          ? [
                              BoxShadow(
                                color: accentDark,
                                offset: Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: inner,
                  ),
                ),
              ),
              // Corona amarilla con el conteo de estrellas encima
              // del nodo pasado (§3.2.1).
              if (passed)
                Positioned(
                  left: cx - 34,
                  top: _nodeCenterY - _nodeSize / 2 - 20,
                  width: 68,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: const Color(0xFFE5E5E5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const LucideIcon(LucideIcons.crown,
                              size: 18, color: Color(0xFFFFC800)),
                          const SizedBox(width: 2),
                          Text('$stars',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4B4B4B))),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// El trofeo final del camino: el examen mixto de la pista.
class _FinalExamSection extends StatelessWidget {
  const _FinalExamSection({
    required this.unlocked,
    required this.level1Done,
    required this.topicCount,
    required this.mixedSize,
    required this.isCurrent,
    required this.currentKey,
    required this.onTap,
  });

  final bool unlocked;
  final int level1Done;
  final int topicCount;
  final int mixedSize;
  final bool isCurrent;
  final GlobalKey? currentKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressService.instance;
    final best = progress.bestScore('mixto');
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: BrandColors.amber.withValues(alpha: 0.15),
              child: const LucideIcon(LucideIcons.trophy,
                  color: BrandColors.amber, threeD: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('mixedTitle'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(tr('mixedBody')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          key: isCurrent ? currentKey : null,
          onTap: onTap,
          // Trofeo Duolingo (§3.2.1, mismo patrón que los nodos):
          // cara sólida teal + labio 4 px, sin degradado, sin
          // brillo, sin sombra borrosa.
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked
                  ? AppAccent.primary
                  : const Color(0xFFE5E5E5),
              boxShadow: unlocked
                  ? [
                      BoxShadow(
                        color: AppAccent.primaryDark,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: LucideIcon(
              unlocked ? LucideIcons.trophy : LucideIcons.lock,
              size: 44,
              color: unlocked ? Colors.white : const Color(0xFFAFAFAF),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          unlocked
              ? (best > 0
                  ? '${tr('mixedTitle')} · ${tr('bestWord')}: $best%'
                  : '${tr('mixedTitle')} · $mixedSize ${tr('questionsWord')}')
              : '${tr('mixedTitle')} · $level1Done/$topicCount',
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        if (!unlocked)
          Text(
            tr('mixedLocked'),
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

/// Recordatorio ("es hora de practicar") en lo alto de Niveles.
/// Antes vivía dentro de la tarjeta de estadísticas, que se mudó a
/// Cuenta (fix 3): el recordatorio se queda aquí, solo cuando toca
/// (recordatorio activo, aún no se practicó hoy y ya pasó la hora).
/// Si no toca, no ocupa nada.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard();

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final now = DateTime.now();
    final reminderDue = UserPrefs.reminderOn &&
        !p.practiceDays.contains(ProgressService.dateKey(now)) &&
        (now.hour > UserPrefs.reminderHour ||
            (now.hour == UserPrefs.reminderHour &&
                now.minute >= UserPrefs.reminderMinute));
    if (!reminderDue) return const SizedBox.shrink();
    return Column(
      children: [
        // Tarjeta 3D (ronda de diseño 7.0): sombra suave tintada y
        // radio 16 en vez de la Card plana de antes.
        Card(
          margin: EdgeInsets.zero,
          elevation: 3,
          shadowColor: BrandColors.amber.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: const ListTile(
            // Icono 3D (fix3, punto 6): ámbar con degradado + brillo.
            leading: LucideIcon(LucideIcons.alarmClock,
                color: BrandColors.amber, threeD: true),
            title: Text('Es hora de practicar',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle:
                Text('Tu recordatorio de estudio: aún no practicaste hoy.'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Repaso POR NIVEL (v6): los errores agrupados por tema y nivel.
/// Cada grupo se repasa con variantes (mismo concepto, otros datos) y
/// hacen falta 3 aciertos seguidos para darlo por superado.
class _QuizState {
  _QuizState(
      {required this.testId,
      required this.title,
      required List<_QuizItem> items,
      this.replayOfPassed = false,
      this.pointsSnapshot = 0})
      : items = List<_QuizItem>.of(items);

  final String testId;
  final String title;
  final List<_QuizItem> items;

  /// Replay de un nivel ya pasado (fix5, A3): "ya pasado" es
  /// unlockedLevel > level — el mismo listón que usa el nodo del
  /// camino —, NO la mejor nota: con la vieja condición (mejor %
  /// >= 81) un 4/5 fallando la difícil guardaba 76 % y la
  /// protección no saltaba. Si el replay se falla, los puntos
  /// vuelven al saldo de antes de empezar (ver _next()).
  final bool replayOfPassed;

  /// Saldo de puntos al empezar el quiz: a él se vuelve si un
  /// replay de un nivel ya pasado se falla (A3).
  final int pointsSnapshot;
}

class _QuizRunner extends StatefulWidget {
  const _QuizRunner({
    super.key,
    required this.quiz,
    required this.spec,
    required this.onExit,
    required this.onRepeat,
    required this.onFinished,
    this.onNextLevel,
  });

  final _QuizState quiz;
  final _QuizSpec spec;
  final VoidCallback onExit;
  final VoidCallback onRepeat;

  /// "Pasar de nivel" (fix5, punto 13): salta al nivel siguiente
  /// del mismo tema, solo tras pasarlo y solo si hay un nivel
  /// siguiente; null si es el último nivel del tema.
  final VoidCallback? onNextLevel;

  /// Avisa de que el quiz terminó (resultado en pantalla): salir
  /// después ya no cuesta una vida.
  final VoidCallback onFinished;

  @override
  State<_QuizRunner> createState() => _QuizRunnerState();
}

class _QuizRunnerState extends State<_QuizRunner> {
  int _index = 0;
  int _score = 0;
  int? _selected; // índice en las opciones barajadas
  List<int> _order = [];
  bool _finished = false;

  /// Respuestas en orden (para la nota por puntos) y puntos del quiz.
  final List<bool> _correct = [];
  var _quizPoints = 0;

  /// ¿Este nivel aprobado devolvió una vida? (Se muestra en el resultado.)
  var _lifeRestored = false;

  /// Cronómetro del intento (para la tarjeta TIEMPO del resultado,
  /// §3.4): arranca al empezar el quiz y se para al terminarlo.
  final _stopwatch = Stopwatch();
  var _elapsedMs = 0;

  /// Entradas del repaso que se dieron por superadas en esta sesión
  /// (3 aciertos seguidos en sus variantes).
  final Set<String> _clearedReview = {};

  @override
  void initState() {
    super.initState();
    _shuffleOptions();
    _stopwatch.start();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _QuizRunner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Repetir (o empezar otro quiz) con el mismo State reutilizado:
    // hay que resetear TODO el estado interno, no solo la vida
    // devuelta (fix5, punto Repetir). Sin esto, _finished seguía en
    // true y la pantalla de resultado (con su confeti) se quedaba.
    // Normalmente el ValueKey por ejecución ya crea un State nuevo
    // y limpio, pero esto cubre cualquier reutilización del widget.
    if (widget.quiz != oldWidget.quiz) {
      _index = 0;
      _score = 0;
      _finished = false;
      _correct.clear();
      _quizPoints = 0;
      _lifeRestored = false;
      _elapsedMs = 0;
      _clearedReview.clear();
      _shuffleOptions();
      _stopwatch
        ..reset()
        ..start();
    }
  }

  void _shuffleOptions() {
    _order = [0, 1, 2, 3]..shuffle(Random());
    _selected = null;
  }

  _QuizItem get _item => widget.quiz.items[_index];

  QuizQuestion get _q => _item.question;

  /// Tocar una opción la juzga AL MOMENTO (flujo original, v6):
  /// puntos, errores y sonidos se registran al tocar, sin paso
  /// intermedio de COMPROBAR ni panel de inundación. La regla dura
  /// de Kristian (2026-11-11) prohíbe reestructurar este flujo con
  /// un cambio de diseño: el rediseño es solo aspecto (§3.3.6 y
  /// §3.3.7 quedan pendientes como cambios de flujo).
  void _answer(int displayedIndex) {
    if (_selected != null) return;
    _selected = displayedIndex;
    final realIndex = _order[displayedIndex];
    final correct = realIndex == _q.answer;
    final progress = ProgressService.instance;
    progress.recordAnswer(_q.topic, correct);
    // Sonidos propios (v6): campanita al acertar, zumbido al fallar.
    if (correct) {
      SoundService.correct();
    } else {
      SoundService.wrong();
    }
    // Puntos (v6; inmediatos desde la fix4, punto 5): cada respuesta
    // suma o resta según la dificultad, y los puntos van al saldo
    // total EN EL MOMENTO de contestar — no al terminar el quiz.
    // Así, salir de un repaso o de un examen mixto a mitad no pierde
    // los puntos ganados hasta ahí (en los niveles, salir a mitad
    // sigue costando 1 vida, pero los puntos se quedan igual).
    _correct.add(correct);
    final delta = correct
        ? pointsForCorrect(_q.difficulty)
        : pointsForWrong(_q.difficulty);
    progress.addPoints(delta);
    _quizPoints += delta;
    if (widget.spec.kind == 'review' && _item.reviewEntryId != null) {
      // Repaso de variantes: la respuesta suma racha de la entrada
      // original (3 seguidos = superada). Fallar no crea un error
      // nuevo: la variante no es una pregunta del banco.
      final cleared =
          progress.recordReviewAnswer(_item.reviewEntryId!, correct);
      if (cleared) _clearedReview.add(_item.reviewEntryId!);
      setState(() {
        if (correct) _score++;
      });
    } else if (correct) {
      // Acertar un error lo saca de la lista de repaso.
      progress.removeFailed(_item.id);
      setState(() {
        _score++;
      });
    } else {
      // Fallar guarda el error para repasarlo después, con su nivel.
      progress.addFailed(FailedEntry(
        id: _item.id,
        topic: _q.topic,
        question: _q.question,
        level: widget.spec.kind == 'level' ? widget.spec.level : 0,
      ));
      setState(() {});
    }
  }

  /// Respuesta de una pregunta de cálculo (fix3, punto 7): el valor
  /// tecleado en el teclado numérico se traduce al índice de opción
  /// que le corresponde y pasa por el mismo `_check` de siempre, con
  /// los mismos puntos y repaso de errores (incluida la racha
  /// de variantes del repaso). Sin opciones que seleccionar, el
  /// valor tecleado selecciona y comprueba en un solo paso.
  void _answerNumeric(double value) {
    if (_selected != null) return;
    // Las preguntas de cálculo no tienen opciones que seleccionar:
    // el valor tecleado se responde en un solo paso.
    _answer(displayedIndexForNumericAnswer(
        typed: value, question: _q, order: _order));
  }

  void _next() {
    if (_index + 1 >= widget.quiz.items.length) {
      // Fin del quiz: se para el cronómetro (tarjeta TIEMPO, §3.4).
      _stopwatch.stop();
      _elapsedMs = _stopwatch.elapsedMilliseconds;
      // Los puntos ya se sumaron al saldo total al contestar cada
      // pregunta (fix4, punto 5): aquí no se añade nada más.
      final progress = ProgressService.instance;
      // Nota por puntos (v6): cada pregunta vale según su dificultad
      // (fácil 4, media 5, difícil 6). La nota se guarda como mejor
      // puntuación, pero pasar ya NO depende de ella (fix5, punto 13):
      // se pasa acertando 4 o más de 5 preguntas.
      final nota5 = levelScore5(
        widget.quiz.items.map((it) => it.question.difficulty).toList(),
        _correct,
      );
      final percent = (nota5 * 20).round();
      // Mejor % ANTES de este intento (fix5, punto 15): si el nivel
      // ya se pasó en una versión anterior a la del promedio, solo
      // quedó su mejor %; recordLevelNote lo toma como primera nota
      // del promedio. Se lee antes de recordScore porque este ya
      // incluye el intento actual.
      final prevBest = progress.bestScore(widget.quiz.testId);
      progress.recordScore(widget.quiz.testId, percent);
      if (widget.spec.kind == 'level' &&
          levelPassed(_score, widget.quiz.items.length)) {
        final wasGoalDone = progress.dailyGoalDone;
        // Ganar el nivel completo devuelve 1 vida (hasta 5).
        _lifeRestored = progress.restoreLifeOnPass();
        progress.recordLevelPass(widget.spec.topic!, widget.spec.level);
        // Puntuación del nivel (fix5, punto 15, CORREGIDO): el
        // PROMEDIO de todas las notas con las que se pasó, no la
        // mejor ni la primera. Un replay fallido no llama aquí:
        // no entra en el promedio, no quita el pase y no re-bloquea
        // nada. Los puntos del monedero de un replay que PASA se
        // quedan como cualquier intento (sus puntos suman); los de
        // un replay FALLIDO se neutralizan en el else-if de abajo
        // (A3: no mueven el saldo).
        progress.recordLevelNote(widget.quiz.testId, nota5,
            prevBestPercent: prevBest);
        SoundService.levelUp();
        // Meta del día recién cumplida: campana de racha después de la
        // fanfarria (la fanfarria dura 0,74 s).
        if (!wasGoalDone && progress.dailyGoalDone) {
          Future.delayed(
              const Duration(milliseconds: 900), SoundService.streak);
        }
      } else if (widget.quiz.replayOfPassed) {
        // Replay FALLIDO de un nivel ya pasado (fix5, A3): el
        // intento es neutro en puntos — el saldo vuelve al de
        // antes de empezar el replay. La nota NO se toca (el
        // promedio solo suma pases: este fallo no llama a
        // recordLevelNote), el pase y el desbloqueo tampoco (aquí
        // no se llama a recordLevelPass). Los errores fallados SÍ
        // quedan para repasarlos (eso es útil, no es puntuación).
        // La línea de puntos del resultado muestra +0: el intento
        // no sumó nada al saldo.
        final delta = widget.quiz.pointsSnapshot - progress.points;
        if (delta != 0) progress.addPoints(delta);
        _quizPoints = 0;
      }
      widget.onFinished();
      // El widget de inicio muestra los puntos, vidas y racha nuevos.
      HomeWidgetService.update();
      setState(() => _finished = true);
    } else {
      setState(() {
        _index++;
        _shuffleOptions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return _buildResult(context);
    }

    final total = widget.quiz.items.length;
    final wasCorrect =
        _selected != null && _order[_selected!] == _q.answer;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Barra superior Duolingo (§3.3.1): título en una sola
              // línea pequeña encima de la barra; X de cierre a la
              // izquierda y barra de progreso de 12 pt.
              DuoQuizTitle(
                  text:
                      '${widget.quiz.title} · ${tr('quizQuestion')} ${_index + 1} ${tr('quizOf')} $total'),
              const SizedBox(height: 8),
              Row(
                children: [
                  DuoCloseButton(onPressed: widget.onExit),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DuoProgressBar(value: (_index + 1) / total),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              MascotBubble(
                companion: companionForTurn(_index),
                mood: _selected == null
                    ? TwinMood.happy
                    : (wasCorrect ? TwinMood.happy : TwinMood.soft),
                text: tr(_selected == null
                    ? mascotLineKey(
                        companionForTurn(_index), MascotLine.ask, _index)
                    : (wasCorrect
                        ? mascotLineKey(companionForTurn(_index),
                            MascotLine.praise, _index)
                        : mascotLineKey(companionForTurn(_index),
                            MascotLine.console, _index))),
              ),
              const SizedBox(height: 16),
              // Botoncito de teclado (fix5, punto B, corrección 00:26):
              // sale en (casi) todas las preguntas, a un ladito del
              // texto; al tocarlo se abre la PANTALLA de la calculadora
              // (página completa, no un panel inline) y al cerrarla se
              // vuelve a la pregunta intacta. Científica en las de
              // cálculo (al volver se responde con el valor), normal en
              // las demás (solo para calcular a mano). Este runner es el
              // mismo para niveles, repaso de errores y examen mixto,
              // así que el icono llega a los tres.
              QuestionCalculatorButton(
                question: Text(_q.question,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface)),
                scientific: _q.isNumeric,
                unit: _q.numericUnit,
                onResult: _q.isNumeric ? _answerNumeric : null,
              ),
              const SizedBox(height: 16),
              // En las preguntas de cálculo las opciones dejan paso al
              // teclado (que ahora se abre con el icono); las
              // conceptuales siguen con las opciones de siempre.
              if (!_q.isNumeric)
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: QuizOptionButton(
                      text: _q.options[_order[i]],
                      state: _selected == null
                          ? QuizOptionState.normal
                          : (_order[i] == _q.answer
                              ? QuizOptionState.correct
                              : (_selected == i
                                  ? QuizOptionState.wrong
                                  : QuizOptionState.normal)),
                      // El color del texto lo fija el estado dentro
                      // de QuizOptionButton (spec §2); se pasa el
                      // de siempre solo por compatibilidad.
                      textColor: Theme.of(context).colorScheme.onSurface,
                      onPressed: () => _answer(i),
                    ),
                  ),
              // Quemia 7.0: reportar la pregunta — opción pequeña y
              // discreta bajo las opciones (regla 1: solo este texto).
              ReportQuestionButton(questionId: _item.id),
              // Retroalimentación (flujo original): al contestar se
              // muestra el resultado con la explicación, dentro de
              // la lista. Sin panel de inundación (§3.3.6, pendiente).
              if (_selected != null) ...[
                const SizedBox(height: 16),
                Text(
                  wasCorrect
                      ? tr('quizCorrect')
                      : '${tr('quizIncorrect')}. ${tr('quizCorrectIs')} ${_q.options[_q.answer]}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: wasCorrect
                        ? AppAccent.primaryDark
                        : const Color(0xFFEA2B2B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(_q.explanation,
                    style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        // Botón inferior fijado (siempre visible, como en Duolingo):
        // gris sin acción hasta contestar; teal al contestar.
        // Etiqueta en mayúsculas dentro de DuoCheckButton.
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, 16 + MediaQuery.of(context).padding.bottom),
          child: DuoCheckButton(
            label: _index + 1 >= widget.quiz.items.length
                ? tr('quizResult')
                : tr('quizNext'),
            onPressed: _selected == null ? null : _next,
          ),
        ),
      ],
    );
  }

  /// Pantalla de resultado de nivel (spec §3.4): celebración a
  /// pantalla completa con fondo oscuro #131F24, mascota grande
  /// celebrando, confeti, título amarillo, XP grande y 3 tarjetas
  /// de color sólido (PUNTOS amarilla, PRECISIÓN teal, TIEMPO azul).
  /// Un solo botón grande azul + "Repetir"/"Volver" como enlaces de
  /// texto discretos. El mismo patrón cubre el repaso y el examen
  /// mixto (sin "Pasar de nivel": su botón grande es REPETIR).
  Widget _buildResult(BuildContext context) {
    const dark = Color(0xFF131F24);
    const muted = Color(0xFFAFAFAF);
    final total = widget.quiz.items.length;
    final percent = ((100 * _score) / total).round();
    final isLevel = widget.spec.kind == 'level';
    final passedLevel = isLevel && levelPassed(_score, total);
    final remaining = ProgressService.instance.failedCount;
    final pointsText = '${_quizPoints >= 0 ? '+' : ''}$_quizPoints';
    final elapsed = _fmtElapsed(_elapsedMs);
    // Título: al pasar, "¡Nivel superado!" en amarillo; si no, el
    // mensaje que ya mostraba la pantalla (fallo, repaso, mixto).
    final String title;
    final Color titleColor;
    if (passedLevel) {
      title = tr('quizLevelPassed');
      titleColor = const Color(0xFFFFC800);
    } else if (isLevel) {
      title = tr('quizLevelFailed');
      titleColor = Colors.white;
    } else if (widget.spec.kind == 'review') {
      title = remaining == 0
          ? tr('quizNoErrors')
          : _clearedReview.isNotEmpty
              ? '${tr('reviewCleared')} ($remaining ${tr('reviewQuestions')})'
              : '$remaining ${tr('reviewQuestions')}';
      titleColor = Colors.white;
    } else {
      title = percent >= _passPercent
          ? tr('quizExcellent')
          : percent >= 60
              ? tr('quizGood')
              : tr('quizKeepGoing');
      titleColor = Colors.white;
    }
    // Botón grande: "PASAR DE NIVEL" solo tras pasarlo y si hay un
    // nivel siguiente (fix5, punto 13); si no, REPETIR.
    final bool canPass = passedLevel && widget.onNextLevel != null;
    final ctaLabel = canPass ? tr('quizPassLevel') : tr('quizRepeat');
    final VoidCallback ctaAction =
        canPass ? widget.onNextLevel! : widget.onRepeat;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: dark,
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mascota grande celebrando (200+ dp, sin aro),
                        // título y XP grande.
                        Column(
                          children: [
                            Center(
                              child: ClipOval(
                                child: Image.asset(
                                  companionAsset(companionForTurn(total - 1)),
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(title,
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: titleColor),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            // XP grande: los puntos del intento.
                            Text(pointsText,
                                style: const TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white),
                                textAlign: TextAlign.center),
                            if (_lifeRestored) ...[
                              const SizedBox(height: 4),
                              Text(tr('livesRestored'),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF14D3B8)),
                                  textAlign: TextAlign.center),
                            ],
                          ],
                        ),
                        // Las 3 tarjetas EXACTAMENTE iguales (mismo
                        // alto y ancho, texto blanco en negrita sobre
                        // el color, también en la amarilla de PUNTOS).
                        Row(
                          children: [
                            _ResultStatCard(
                              color: const Color(0xFFFFC800),
                              label: tr('pointsTitle'),
                              value: pointsText,
                            ),
                            const SizedBox(width: 12),
                            _ResultStatCard(
                              color: AppAccent.primary,
                              label: tr('quizAccuracy'),
                              value: '$percent%',
                            ),
                            const SizedBox(width: 12),
                            _ResultStatCard(
                              color: const Color(0xFF1CB0F6),
                              label: tr('quizTime'),
                              value: elapsed,
                            ),
                          ],
                        ),
                        // Un solo botón grande azul + "Repetir" y
                        // "Volver" como enlaces de texto discretos.
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: DuoButton.primary(
                                label: ctaLabel.toUpperCase(),
                                onPressed: ctaAction,
                                topColor: const Color(0xFF1CB0F6),
                                bottomColor: const Color(0xFF1CB0F6),
                                edgeColor: const Color(0xFF1899D6),
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // "Repetir" y "Volver" como enlaces
                            // discretos, no botones (§3.4.5). Si el
                            // botón grande ya es REPETIR, no se repite
                            // el enlace.
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (canPass)
                                  TextButton(
                                    onPressed: widget.onRepeat,
                                    child: Text(tr('quizRepeat').toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: muted)),
                                  ),
                                TextButton(
                                  onPressed: widget.onExit,
                                  child: Text(tr('quizBack').toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: muted)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (passedLevel)
            const Positioned.fill(child: CelebrationOverlay()),
        ],
      ),
    );
  }
}

/// Una tarjeta de estadística del resultado (§3.4.4): color sólido
/// con el texto BLANCO en negrita dentro (también en la amarilla
/// de PUNTOS; la lección de Kristian: texto oscuro sobre tarjeta
/// de color no se lee). Las 3 tarjetas son idénticas en tamaño.
class _ResultStatCard extends StatelessWidget {
  const _ResultStatCard(
      {required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// ms → "1:23" o "48 s".
String _fmtElapsed(int ms) {
  final s = (ms / 1000).round();
  if (s < 60) return '$s s';
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
