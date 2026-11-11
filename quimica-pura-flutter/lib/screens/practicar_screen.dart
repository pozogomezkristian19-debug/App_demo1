import 'dart:math';
import 'package:flutter/material.dart';
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

// Alturas fijas del camino: el pintor del sendero y las filas usan las
// mismas, así la línea pasa justo por el centro de cada nodo.
const double _headerH = 76.0;
const double _rowH = 100.0;
// Aire entre el cartel del tema y el primer nodo (fix4, punto 13
// REVISADO y retoque del halo): la bolita del nivel 1 chocaba con
// el cartel; con 28 px el halo del nodo actual queda a 26 px del
// cartel en reposo y a ~21 px en su pulso máximo, y la bolita a 32.
const double _pathTopGap = 28.0;
const double _nodeSize = 64.0;
const double _nodeCenterY = 36.0; // centro del nodo dentro de su fila

// Desplazamiento horizontal de cada nodo (px desde el centro): el camino
// serpentea izquierda-centro-derecha, como en Duolingo.
const List<double> _pathOffsets = [0, -52, -78, -52, 0, 52, 78, 52];

const Map<String, LucideIconData> _topicIcons = {
  'estequiometria': LucideIcons.sigma,
  'gases': LucideIcons.wind,
  'disoluciones': LucideIcons.droplet,
  'acido-base': LucideIcons.flaskConical,
  'equilibrio': LucideIcons.scale,
  'termo-cinetica': LucideIcons.thermometer,
  'tabla': LucideIcons.layoutGrid,
  'enlace': LucideIcons.link,
  'organica': LucideIcons.hexagon,
  'laboratorio': LucideIcons.dna,
  'bach-estequiometria': LucideIcons.sigma,
  'bach-gases': LucideIcons.wind,
  'bach-disoluciones': LucideIcons.droplet,
  'bach-acido-base': LucideIcons.flaskConical,
};

// Rediseño claro estilo Duolingo (color propio, teal de Melli-Qui):
// el camino, sus nodos y las cabeceras de tema usan todos el mismo
// teal de la marca; no hay un color distinto por tema. El icono de
// cada tema sigue distinto (ver _topicIcons).

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

  int _totalLevelCount() {
    var total = 0;
    for (final topic in _byTopic.keys) {
      total += _levelCount(topic);
    }
    return total;
  }

  int _passedLevelCount() {
    final progress = ProgressService.instance;
    var passed = 0;
    for (final topic in _byTopic.keys) {
      for (var level = 1; level <= _levelCount(topic); level++) {
        // Pasado = desbloqueado el siguiente (fix5, punto 13): con la
        // regla por conteo, un 4/5 puede guardar 73-80 % de nota y la
        // nota ya no dice si se pasó; unlockedLevel sí, siempre.
        if (progress.unlockedLevel(topic) > level) {
          passed++;
        }
      }
    }
    return passed;
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
    final passedCount = _passedLevelCount();
    final totalCount = _totalLevelCount();
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
          // Cabecera compacta (fix2, item 3): título + progreso en
          // una sola fila, sin el párrafo de introducción. El
          // camino va justo debajo (fix5, punto 2): al abrir
          // Niveles lo primero que se ve es el primer tema con su
          // nodo 1, sin deslizar. Los dos textos son flexibles con
          // puntos suspensivos (auditoría): sin eso, en otro idioma
          // o con fuente grande se desbordaba la fila 42 px a la
          // derecha.
          Row(
            children: [
              Flexible(
                child: Text(tr('levelsTitle'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${tr('passedWord')}: $passedCount / $totalCount',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
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
          if (progress.dueFailed().isNotEmpty)
            Card(
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
          // "Practicar de otra forma" (Examen con tiempo y Reto)
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

/// Pinta el sendero que une los nodos de una sección: una línea curva
/// punteada que va SOLO entre los nodos, nunca a través de ellos.
///
/// La línea se dibuja primero (está detrás de los nodos) y, además, cada
/// tramo punteado se recorta para que no entre dentro de ningún círculo:
/// se conserva un guión solo si su punto medio queda fuera de todos los
/// círculos (radio del nodo + margen). Así, dentro de cada círculo no hay
/// línea, ni siquiera en los nodos bloqueados, que son semitransparentes.
class _PathPainter extends CustomPainter {
  const _PathPainter({required this.levelCount, required this.color});
  final int levelCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (levelCount < 2) return;
    final centers = <Offset>[
      for (var i = 0; i < levelCount; i++)
        Offset(size.width / 2 + _pathOffsets[i % _pathOffsets.length],
            _headerH + _pathTopGap + i * _rowH + _nodeCenterY),
    ];
    // Curva suave que pasa por los centros: cada tramo va del punto
    // anterior al punto medio con el siguiente.
    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (var i = 1; i < centers.length; i++) {
      final prev = centers[i - 1];
      final curr = centers[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(centers.last.dx, centers.last.dy);
    // Línea punteada, solo en los huecos entre nodos.
    final keepOut = _nodeSize / 2 + 10; // radio del círculo + margen
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = min(12.0, metric.length - distance);
        final mid = metric.getTangentForOffset(distance + len / 2)?.position;
        final outside =
            mid != null && centers.every((c) => (mid - c).distance > keepOut);
        if (outside) {
          dashed.addPath(
              metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += 20.0;
      }
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.levelCount != levelCount || old.color != color;
}

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
    final scheme = Theme.of(context).colorScheme;
    final unlocked = locked ? 0 : progress.unlockedLevel(topic);
    var best = 0;
    for (var i = 1; i <= levelCount; i++) {
      final s = progress.bestScore('level:$topic:$i');
      if (s > best) best = s;
    }
    // Cabecera y camino en el color de acento (fix2, item 12; gris
    // si el tema está bloqueado): todos los temas comparten el color.
    return SizedBox(
      height: _headerH + _pathTopGap + levelCount * _rowH,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PathPainter(
                levelCount: levelCount,
                color: locked
                    ? const Color(0xFFD1D5DB)
                    : scheme.primary.withValues(alpha: 0.35),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(
                height: _headerH,
                child: Container(
                  decoration: BoxDecoration(
                    color: locked ? const Color(0xFFE5E7EB) : scheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        child: LucideIcon(
                            locked
                                ? LucideIcons.lock
                                : (_topicIcons[topic] ??
                                    LucideIcons.circleHelp),
                            color: locked
                                ? const Color(0xFF9CA3AF)
                                : scheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nombre del tema en MAYÚSCULAS (fix3,
                            // punto 12): el nombre completo se lee
                            // entero. La cabecera mide 76 px fijos:
                            // con 16 px caben 2 líneas del título
                            // más el subtítulo sin desbordar (antes
                            // el título a 18 px en 1 línea se
                            // recortaba con puntos suspensivos).
                            // Cabecera del camino (fix3): el título
                            // COMPLETO del tema (topics.dart), nunca
                            // el id interno: 'bach-disoluciones' se
                            // ve como 'Disoluciones y concentración',
                            // también en la tarjeta bloqueada.
                            Text(localizedTopicTitle(topic).toUpperCase(),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: locked
                                        ? BrandColors.ink.withValues(alpha: 0.6)
                                        : Colors.white),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            Text(
                              (locked
                                      ? tr('lockedWord')
                                      : '${tr('levelWord')} ${unlocked > levelCount ? levelCount : unlocked} ${tr('quizOf')} $levelCount · ${tr('bestWord')}: $best%')
                                  .toUpperCase(),
                              style: TextStyle(
                                color: locked
                                    ? BrandColors.ink.withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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
                  unlocked: !locked && level <= unlocked,
                  isCurrent: level == currentLevel,
                  onLevelTap: onLevelTap,
                ),
            ],
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
class _LevelNodeRow extends StatefulWidget {
  const _LevelNodeRow({
    super.key,
    required this.topic,
    required this.level,
    required this.bankCount,
    required this.unlocked,
    required this.isCurrent,
    required this.onLevelTap,
  });

  final String topic;
  final int level;
  final int bankCount;
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
    final progress = ProgressService.instance;
    final scheme = Theme.of(context).colorScheme;
    final best = progress.bestScore('level:${widget.topic}:${widget.level}');
    // La etiqueta es la PUNTUACIÓN del nivel (fix5, punto 15):
    // el promedio de todos los pases, no la mejor; sin registro
    // de promedio (pase anterior a esta versión) se sigue viendo
    // la mejor de antes.
    final avgNote =
        progress.levelNoteAverage('level:${widget.topic}:${widget.level}');
    final labelPercent =
        avgNote == null ? best : (avgNote * 20).round();
    // Pasado = desbloqueado el siguiente (fix5, punto 13): con la
    // regla por conteo, un 4/5 puede guardar 73-80 % de nota y la
    // nota ya no dice si se pasó; unlockedLevel sí, siempre. El
    // best solo se usa para la etiqueta "Nivel N · X %".
    final passed = progress.unlockedLevel(widget.topic) > widget.level;
    // Niveles sin preguntas del banco: solo preguntas nuevas generadas.
    final generatedOnly = (widget.level - 1) * _levelSize >= widget.bankCount;
    final offset = _pathOffsets[(widget.level - 1) % _pathOffsets.length];
    final Color bg;
    final Widget inner;
    if (passed) {
      // Nivel pasado: color de acento con palomita blanca.
      bg = scheme.primary;
      inner =
          const LucideIcon(LucideIcons.check, color: Colors.white, size: 34);
    } else if (widget.unlocked) {
      bg = scheme.primary;
      inner = Text('${widget.level}',
          style: const TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white));
    } else {
      // Nodo bloqueado: gris claro con candado gris.
      bg = const Color(0xFFE5E7EB);
      inner = const LucideIcon(LucideIcons.lock,
          color: Color(0xFF9CA3AF), size: 28);
    }
    return SizedBox(
      height: _rowH,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cx = constraints.maxWidth / 2 + offset;
          // Sin recorte (Clip.none): el halo del nodo actual mide
          // 76 px centrado en el nodo (36 px arriba y abajo) y en
          // su pulso máximo llega a 85 px, así que sobresale ~7 px
          // por encima de la fila; con el recorte por defecto del
          // Stack salía cortado en plano por arriba (la bolita no
          // se veía completa). El hueco _pathTopGap (28 px) lo
          // absorbe sin tocar el cartel del tema.
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (widget.isCurrent)
                Positioned(
                  left: cx - 38,
                  top: _nodeCenterY - 38,
                  child: AnimatedBuilder(
                    animation: _scale,
                    builder: (context, child) => Transform.scale(
                      scale: _scale.value,
                      child: child,
                    ),
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: 0.18),
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
              if (widget.isCurrent)
                Positioned(
                  left: offset >= 0
                      ? cx - _nodeSize / 2 - 72
                      : cx + _nodeSize / 2 + 32,
                  top: _nodeCenterY - 20,
                  child:
                      CompanionAvatar(companion: companionOfTheDay(), size: 40),
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
                      color: bg,
                      // El nodo actual lleva un anillo blanco (y un
                      // aro teal por fuera, para que el blanco se vea
                      // sobre el fondo blanco), además del halo.
                      border: widget.isCurrent
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: widget.isCurrent
                              ? scheme.primary.withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.15),
                          blurRadius: widget.isCurrent ? 0 : 4,
                          spreadRadius: widget.isCurrent ? 2 : 0,
                          offset: Offset(0, widget.isCurrent ? 0 : 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: inner,
                  ),
                ),
              ),
              Positioned(
                left: cx - 50,
                top: _nodeCenterY + _nodeSize / 2 + 4,
                width: 100,
                child: Text(
                  passed
                      ? '${tr('levelWord')} ${widget.level} · $labelPercent%'
                      : generatedOnly && widget.unlocked
                          ? '${tr('levelWord')} ${widget.level} · ${tr('newWord')}'
                          : '${tr('levelWord')} ${widget.level}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        widget.isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: widget.isCurrent
                        ? scheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
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
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? scheme.primary : const Color(0xFFE5E7EB),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: LucideIcon(
              unlocked ? LucideIcons.trophy : LucideIcons.lock,
              size: 44,
              color: unlocked ? Colors.white : const Color(0xFF9CA3AF),
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
        Card(
          margin: EdgeInsets.zero,
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

  /// Entradas del repaso que se dieron por superadas en esta sesión
  /// (3 aciertos seguidos en sus variantes).
  final Set<String> _clearedReview = {};

  @override
  void initState() {
    super.initState();
    _shuffleOptions();
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
      _clearedReview.clear();
      _shuffleOptions();
    }
  }

  void _shuffleOptions() {
    _order = [0, 1, 2, 3]..shuffle(Random());
    _selected = null;
  }

  _QuizItem get _item => widget.quiz.items[_index];

  QuizQuestion get _q => _item.question;

  void _answer(int displayedIndex) {
    if (_selected != null) return;
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
        _selected = displayedIndex;
        if (correct) _score++;
      });
    } else if (correct) {
      // Acertar un error lo saca de la lista de repaso.
      progress.removeFailed(_item.id);
      setState(() {
        _selected = displayedIndex;
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
      setState(() => _selected = displayedIndex);
    }
  }

  /// Respuesta de una pregunta de cálculo (fix3, punto 7): el valor
  /// tecleado en el teclado numérico se traduce al índice de opción
  /// que le corresponde y pasa por el mismo `_answer` de siempre, con
  /// los mismos puntos y repaso de errores (incluida la racha
  /// de variantes del repaso).
  void _answerNumeric(double value) {
    if (_selected != null) return;
    _answer(displayedIndexForNumericAnswer(
        typed: value, question: _q, order: _order));
  }

  void _next() {
    if (_index + 1 >= widget.quiz.items.length) {
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
    final scheme = Theme.of(context).colorScheme;
    if (_finished) {
      final total = widget.quiz.items.length;
      final percent = ((100 * _score) / total).round();
      final isLevel = widget.spec.kind == 'level';
      // Nota por puntos (v6): solo se muestra; pasar es acertar 4
      // o más de 5 preguntas (fix5, punto 13).
      final nota5 = levelScore5(
        widget.quiz.items.map((it) => it.question.difficulty).toList(),
        _correct,
      );
      final passedLevel = isLevel && levelPassed(_score, total);
      final remaining = ProgressService.instance.failedCount;
      // Puntuación del nivel (fix5, punto 15, CORREGIDO): el
      // promedio de todas las notas con las que se pasó. Se lee en
      // vivo del servicio (ya se registró en _next() antes de
      // llegar aquí) y vale también tras un replay fallido: la
      // puntuación registrada no se movió con el fallo.
      final noteAvg = isLevel
          ? ProgressService.instance.levelNoteAverage(widget.quiz.testId)
          : null;
      final notePasses = isLevel
          ? ProgressService.instance.levelNotePassCount(widget.quiz.testId)
          : 0;
      // Celebración al pasar de nivel: confeti cayendo sobre el
      // resultado durante unos segundos.
      final resultBody = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('quizResult'),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('$_score ${tr('quizOf')} $total ${tr('quizScore')}',
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center),
            Text('$percent%',
                style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary),
                textAlign: TextAlign.center),
            if (isLevel)
              Text(
                'Nota: ${nota5.toStringAsFixed(1)} / 5',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            // A4: la nota no es la puerta; se pasa con 4 de 5 aciertos.
            if (isLevel && passedLevel)
              Text(
                tr('quizPassNote'),
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            // Puntuación del nivel (fix5, punto 15): solo a partir
            // del segundo pase; en el primero el promedio es la
            // nota de este intento y ya está arriba en 'Nota:'.
            if (isLevel && noteAvg != null && notePasses >= 2)
              Text(
                tr('quizLevelAvg')
                    .replaceAll(
                        '{avg}',
                        noteAvg
                            .toStringAsFixed(1)
                            .replaceAll('.', ','))
                    .replaceAll('{n}', '$notePasses'),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            Text(
              '${tr('pointsTitle')}: ${_quizPoints >= 0 ? '+' : ''}$_quizPoints',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (_lifeRestored)
              Text(
                tr('livesRestored'),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            Text(
              passedLevel
                  ? '${tr('quizLevelPassed')} ${tr('levelWord')} ${widget.spec.level + 1}.'
                  : isLevel
                      ? tr('quizLevelFailed')
                      : widget.spec.kind == 'review'
                          ? remaining == 0
                              ? tr('quizNoErrors')
                              : _clearedReview.isNotEmpty
                                  ? '${tr('reviewCleared')} ($remaining ${tr('reviewQuestions')})'
                                  : '$remaining ${tr('reviewQuestions')}'
                          : percent >= _passPercent
                              ? tr('quizExcellent')
                              : percent >= 60
                                  ? tr('quizGood')
                                  : tr('quizKeepGoing'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            MascotBubble(
              companion: companionForTurn(total - 1),
              mood: passedLevel ? TwinMood.happy : TwinMood.soft,
              text: tr(mascotLineKey(companionForTurn(total - 1),
                  passedLevel ? MascotLine.praise : MascotLine.console, total)),
            ),
            const SizedBox(height: 24),
            // Botones tras GANAR un nivel (fix5, punto 13 + punto
            // 15.1, en este orden): [Pasar de nivel] [Volver]
            // [Repetir]. "Pasar de nivel" arranca el N+1 directo,
            // sin preguntar nada.
            if (passedLevel && widget.onNextLevel != null) ...[
              ElevatedButton(
                onPressed: widget.onNextLevel,
                child: Text(tr('quizPassLevel')),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: widget.onExit, child: Text(tr('quizBack'))),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: widget.onRepeat,
                child: Text(tr('quizRepeat')),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: widget.onRepeat,
                child: Text(tr('quizRepeat')),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: widget.onExit, child: Text(tr('quizBack'))),
            ],
          ],
        ),
      );
      if (!passedLevel) return resultBody;
      return Stack(
        children: [
          resultBody,
          const Positioned.fill(child: CelebrationOverlay()),
        ],
      );
    }

    final total = widget.quiz.items.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${widget.quiz.title} · ${tr('quizQuestion')} ${_index + 1} ${tr('quizOf')} $total',
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 8),
            // Botón Salir de verdad: grande, con borde y con icono.
            OutlinedButton.icon(
              onPressed: widget.onExit,
              icon: const LucideIcon(LucideIcons.logOut, size: 20),
              label: Text(tr('quizExit'), style: const TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: (_index + 1) / total),
        const SizedBox(height: 16),
        MascotBubble(
          companion: companionForTurn(_index),
          mood: _selected == null
              ? TwinMood.happy
              : (_order[_selected!] == _q.answer
                  ? TwinMood.happy
                  : TwinMood.soft),
          text: tr(_selected == null
              ? mascotLineKey(companionForTurn(_index), MascotLine.ask, _index)
              : (_order[_selected!] == _q.answer
                  ? mascotLineKey(
                      companionForTurn(_index), MascotLine.praise, _index)
                  : mascotLineKey(
                      companionForTurn(_index), MascotLine.console, _index))),
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
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
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
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selected == null
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : (_order[i] == _q.answer
                          ? scheme.primary
                          : (_selected == i
                              ? Colors.redAccent
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest)),
                  // El texto SIEMPRE legible (capturas 2026-11-10):
                  // antes heredaba el blanco del tema y sobre el
                  // fondo gris claro no se leía nada. Sobre fondo
                  // claro va tinta oscura; sobre teal/rojo, blanco.
                  foregroundColor: _selected != null &&
                          (_order[i] == _q.answer || _selected == i)
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(14),
                ),
                onPressed: () => _answer(i),
                child: Text(_q.options[_order[i]],
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
        if (_selected != null) ...[
          const SizedBox(height: 8),
          Card(
            color: _order[_selected!] == _q.answer
                ? scheme.primary.withValues(alpha: 0.2)
                : Colors.redAccent.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _order[_selected!] == _q.answer
                        ? tr('quizCorrect')
                        : '${tr('quizIncorrect')}. ${tr('quizCorrectIs')} ${_q.options[_q.answer]}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(_q.explanation),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _next,
            child:
                Text(_index + 1 >= total ? tr('quizResult') : tr('quizNext')),
          ),
        ],
      ],
    );
  }
}
