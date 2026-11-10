import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/extra_content.dart';
import '../data/questions.dart';
import '../models.dart';
import '../services/localization.dart';
import '../services/nav_requests.dart';
import '../services/progress.dart';
import '../services/question_generator.dart';
import '../services/user_prefs.dart';
import '../widgets/celebration.dart';
import '../widgets/element_sheet.dart';

// Practicar estilo Duolingo: niveles por tema, repaso de errores y memoria
// que no se borra al cerrar la app (todo vive en ProgressService, que
// guarda en SharedPreferences).
//
// - Cada tema se parte en niveles de 5 preguntas. Para pasar de nivel hay
//   que sacar al menos 4 de 5 (80%); al pasarlo se desbloquea el siguiente.
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
const int _passNeeded = 4; // 4 de 5 = 80%
const int _passPercent = (_passNeeded * 100) ~/ _levelSize; // 80%
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
const double _nodeSize = 64.0;
const double _nodeCenterY = 36.0; // centro del nodo dentro de su fila

// Desplazamiento horizontal de cada nodo (px desde el centro): el camino
// serpentea izquierda-centro-derecha, como en Duolingo.
const List<double> _pathOffsets = [0, -52, -78, -52, 0, 52, 78, 52];

const Map<String, IconData> _topicIcons = {
  'estequiometria': Icons.functions,
  'gases': Icons.air,
  'disoluciones': Icons.water_drop,
  'acido-base': Icons.science,
  'equilibrio': Icons.balance,
  'termo-cinetica': Icons.thermostat,
  'tabla': Icons.grid_view,
  'enlace': Icons.link,
  'organica': Icons.hub,
  'laboratorio': Icons.biotech,
  'bach-estequiometria': Icons.functions,
  'bach-gases': Icons.air,
  'bach-disoluciones': Icons.water_drop,
  'bach-acido-base': Icons.science,
};

const Map<String, Color> _topicColors = {
  'estequiometria': Color(0xFF14B8A6),
  'gases': Color(0xFF38BDF8),
  'disoluciones': Color(0xFF22D3EE),
  'acido-base': Color(0xFFA78BFA),
  'equilibrio': Color(0xFFF59E0B),
  'termo-cinetica': Color(0xFFEF4444),
  'tabla': Color(0xFF22C55E),
  'enlace': Color(0xFFEC4899),
  'organica': Color(0xFF84CC16),
  'laboratorio': Color(0xFFF97316),
  'bach-estequiometria': Color(0xFF14B8A6),
  'bach-gases': Color(0xFF38BDF8),
  'bach-disoluciones': Color(0xFF22D3EE),
  'bach-acido-base': Color(0xFFA78BFA),
};

String bankId(QuizQuestion q) => 'bank:${q.topic}:${q.question}';

class _QuizItem {
  const _QuizItem({required this.id, required this.question});
  final String id; // 'bank:...' o 'gen:...'
  final QuizQuestion question;
}

class _QuizSpec {
  const _QuizSpec({required this.kind, this.topic, this.level = 0, this.reviewOnly});
  final String kind; // 'level', 'review' o 'mixto'
  final String? topic;
  final int level;

  /// Repaso inteligente: solo estas entradas (los errores de días
  /// anteriores). null = todos los errores.
  final List<FailedEntry>? reviewOnly;
}

class PracticarScreen extends StatefulWidget {
  const PracticarScreen({super.key});
  @override
  State<PracticarScreen> createState() => _PracticarScreenState();
}

class _PracticarScreenState extends State<PracticarScreen> {
  _QuizState? _quiz;
  _QuizSpec? _spec;

  // Para volver al punto donde va el usuario al abrir el camino.
  final _currentKey = GlobalKey();
  var _scrolledToCurrent = false;
  var _backRegistered = false;

  @override
  void dispose() {
    if (_backRegistered) BackNav.unregister(_closeQuiz);
    super.dispose();
  }

  /// Cierra el quiz abierto (manejador del botón atrás).
  bool _closeQuiz() {
    if (_quiz == null) return false;
    setState(() => _quiz = null);
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
        if (progress.bestScore('level:$topic:$level') >= _passPercent) {
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
    Scrollable.ensureVisible(ctx, alignment: 0.45, duration: const Duration(milliseconds: 400));
  }

  /// Temas y preguntas del banco de la pista actual, en el orden de la
  /// pista. Cambia al cambiar de pista (ver el selector de arriba).
  Map<String, List<QuizQuestion>> get _byTopic {
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

  int _levelCount(String topic) =>
      ProgressService.levelCountForTopic(topic);

  /// Resuelve una entrada fallada a su pregunta (banco o generada).
  QuizQuestion? _resolveFailed(FailedEntry f) {
    if (f.id.startsWith('gen:')) {
      return rebuildGenerated(f.id)?.question;
    }
    for (final q in allQuestions) {
      if (q.topic == f.topic && q.question == f.question) return q;
    }
    return null;
  }

  List<_QuizItem> _buildLevelQuestions(String topic, int level) {
    final progress = ProgressService.instance;
    final bank = _byTopic[topic] ?? <QuizQuestion>[];
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
    final start = (level - 1) * _levelSize;
    if (start < bank.length && items.length < _levelSize) {
      final end = min(start + (_levelSize - items.length), bank.length);
      for (final q in bank.sublist(start, end)) {
        final id = bankId(q);
        if (used.add(id)) items.add(_QuizItem(id: id, question: q));
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

  /// Preguntas del repaso: todos los errores, o solo los que se pasen
  /// (repaso inteligente: los de días anteriores).
  List<_QuizItem> _buildReviewQuestions([List<FailedEntry>? only]) {
    final progress = ProgressService.instance;
    final items = <_QuizItem>[];
    final entries = List<FailedEntry>.of(only ?? progress.failedEntries)
      ..shuffle();
    for (final f in entries.take(_reviewMax)) {
      final q = _resolveFailed(f);
      if (q != null) items.add(_QuizItem(id: f.id, question: q));
    }
    return items;
  }

  List<_QuizItem> _buildMixedQuestions() {
    final progress = ProgressService.instance;
    final weakest =
        progress.weakestTopics(_byTopic.keys.toList()); // del más débil al más fuerte
    final size = ProgressService.track == ProgressService.trackBach
        ? _mixedSizeBach
        : _mixedSize;
    final rng = Random();
    final items = <_QuizItem>[];
    final used = <String>{};
    // 2 preguntas del banco por tema, empezando por los más débiles.
    for (final topic in weakest) {
      final pool = List<QuizQuestion>.of(_byTopic[topic] ?? <QuizQuestion>[])
        ..shuffle(rng);
      for (final q in pool.take(2)) {
        final id = bankId(q);
        if (used.add(id)) items.add(_QuizItem(id: id, question: q));
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
        return '${topicNames[spec.topic] ?? spec.topic} · ${tr('levelWord')} ${spec.level}';
      case 'review':
        return spec.reviewOnly != null
            ? tr('smartReviewTitle')
            : tr('reviewTitle');
      default:
        return tr('mixedTitle');
    }
  }

  void _start(_QuizSpec spec) {
    final questions = _buildQuestions(spec);
    if (questions.isEmpty) return;
    _scrolledToCurrent = false;
    if (!_backRegistered) {
      BackNav.register(_closeQuiz);
      _backRegistered = true;
    }
    setState(() {
      _spec = spec;
      _quiz = _QuizState(
        testId: spec.kind == 'level'
            ? 'level:${spec.topic}:${spec.level}'
            : spec.kind,
        title: _titleFor(spec),
        items: questions,
      );
    });
  }

  void _exitQuiz() {
    if (_backRegistered) {
      BackNav.unregister(_closeQuiz);
      _backRegistered = false;
    }
    setState(() => _quiz = null);
  }

  void _repeat() {
    if (_spec != null) _start(_spec!);
  }

  bool _mixedUnlocked() {
    final progress = ProgressService.instance;
    // Desbloqueado cuando el Nivel 1 está pasado en todos los temas:
    // pasar el Nivel 1 sube el nivel desbloqueado a 2.
    return _byTopic.keys
        .every((topic) => progress.unlockedLevel(topic) >= 2);
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
        quiz: _quiz!,
        spec: _spec!,
        onExit: _exitQuiz,
        onRepeat: _repeat,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('levelsTitle'),
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(tr('levelsIntro')),
          const SizedBox(height: 12),
          // Racha, meta del día y recordatorio, en una fila.
          _DailyStrip(),
          const SizedBox(height: 12),
          // Pregunta del día y elemento del día.
          _QuestionOfTheDayCard(),
          const SizedBox(height: 8),
          _ElementOfTheDayCard(
            onOpen: (e) => showElementSheet(context, e),
          ),
          const SizedBox(height: 12),
          Text(
            '${tr('passedWord')}: $passedCount / $totalCount',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          // Repaso inteligente: errores de días anteriores que resurgen.
          if (progress.dueFailed().isNotEmpty)
            Card(
              color: Colors.amber.withValues(alpha: 0.18),
              child: ListTile(
                leading: const Icon(Icons.auto_awesome, size: 32),
                title: Text(tr('smartReviewTitle'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${progress.dueFailed().length} ${tr('reviewQuestions')} de días anteriores'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _start(_QuizSpec(
                    kind: 'review', reviewOnly: progress.dueFailed())),
              ),
            ),
          if (progress.dueFailed().isNotEmpty) const SizedBox(height: 8),
          // Repaso de errores, solo si hay algo que repasar.
          if (progress.failedCount > 0)
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.15),
              child: ListTile(
                leading: const Icon(Icons.replay_circle_filled, size: 32),
                title: Text(tr('reviewTitle'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${progress.failedCount} ${tr('reviewQuestions')}'),
                trailing: Chip(label: Text('${progress.failedCount}')),
                onTap: () => _start(const _QuizSpec(kind: 'review')),
              ),
            ),
          if (progress.failedCount > 0) const SizedBox(height: 8),
          for (var i = 0; i < topics.length; i++)
            _TopicPathSection(
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
                  _start(_QuizSpec(
                      kind: 'level', topic: topics[i], level: level));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${tr('quizLevelFailed')} (${tr('levelWord')} ${level - 1})'),
                    ),
                  );
                }
              },
            ),
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
                    .map((t) => topicNames[t] ?? t)
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
            _headerH + i * _rowH + _nodeCenterY),
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
        final outside = mid != null &&
            centers.every((c) => (mid - c).distance > keepOut);
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
    final unlocked = locked ? 0 : progress.unlockedLevel(topic);
    var best = 0;
    for (var i = 1; i <= levelCount; i++) {
      final s = progress.bestScore('level:$topic:$i');
      if (s > best) best = s;
    }
    final color =
        _topicColors[topic] ?? Theme.of(context).colorScheme.primary;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _headerH + levelCount * _rowH,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PathPainter(
                levelCount: levelCount,
                // El sendero de cada tema lleva el color del tema.
                color: color.withValues(alpha: locked ? 0.15 : 0.45),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(
                height: _headerH,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: locked ? 0.06 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: color.withValues(alpha: 0.18),
                        child: Icon(
                            locked
                                ? Icons.lock
                                : (_topicIcons[topic] ?? Icons.quiz_outlined),
                            color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(topicNames[topic] ?? topic,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            Text(
                              locked
                                  ? tr('lockedWord')
                                  : '${tr('levelWord')} ${unlocked > levelCount ? levelCount : unlocked} ${tr('quizOf')} $levelCount · ${tr('bestWord')}: $best%',
                              style: TextStyle(
                                color:
                                    scheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
    final best = progress.bestScore('level:${widget.topic}:${widget.level}');
    final passed = best >= _passPercent;
    // Niveles sin preguntas del banco: solo preguntas nuevas generadas.
    final generatedOnly =
        (widget.level - 1) * _levelSize >= widget.bankCount;
    final scheme = Theme.of(context).colorScheme;
    final offset = _pathOffsets[(widget.level - 1) % _pathOffsets.length];
    final Color bg;
    final Widget inner;
    if (passed) {
      bg = const Color(0xFFFFB300);
      inner = const Icon(Icons.check, color: Color(0xFF5D4037), size: 34);
    } else if (widget.unlocked) {
      bg = scheme.primary;
      inner = Text('${widget.level}',
          style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white));
    } else {
      // Nodo bloqueado: fondo bastante opaco para que el círculo se vea
      // como círculo (la línea del camino ya no lo atraviesa).
      bg = scheme.onSurface.withValues(alpha: 0.30);
      inner = Icon(Icons.lock,
          color: scheme.onSurface.withValues(alpha: 0.6), size: 28);
    }
    return SizedBox(
      height: _rowH,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cx = constraints.maxWidth / 2 + offset;
          return Stack(
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
              Positioned(
                left: cx - _nodeSize / 2,
                top: _nodeCenterY - _nodeSize / 2,
                child: GestureDetector(
                  onTap: () => widget.onLevelTap(widget.level, widget.unlocked),
                  child: Container(
                    width: _nodeSize,
                    height: _nodeSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bg,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 3),
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
                      ? '${tr('levelWord')} ${widget.level} · $best%'
                      : generatedOnly && widget.unlocked
                          ? '${tr('levelWord')} ${widget.level} · ${tr('newWord')}'
                          : '${tr('levelWord')} ${widget.level}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: widget.isCurrent
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: widget.isCurrent
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: 0.7),
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
              backgroundColor: Colors.amber.withValues(alpha: 0.18),
              child: const Icon(Icons.emoji_events, color: Colors.amber),
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
              color: unlocked
                  ? const Color(0xFFFFB300)
                  : scheme.onSurface.withValues(alpha: 0.30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              unlocked ? Icons.emoji_events : Icons.lock,
              size: 44,
              color: unlocked
                  ? const Color(0xFF5D4037)
                  : scheme.onSurface.withValues(alpha: 0.6),
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
            style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

/// Racha, meta del día y recordatorio, en la parte de arriba de Niveles.
class _DailyStrip extends StatelessWidget {
  const _DailyStrip();

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final now = DateTime.now();
    final reminderDue = UserPrefs.reminderOn &&
        !p.practiceDays.contains(ProgressService.dateKey(now)) &&
        (now.hour > UserPrefs.reminderHour ||
            (now.hour == UserPrefs.reminderHour &&
                now.minute >= UserPrefs.reminderMinute));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Colors.deepOrange, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${tr('streakWord')}: ${p.streakNow} ${p.streakNow == 1 ? 'día' : 'días'}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            Text('Mejor: ${p.streakBest} días',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: p.dailyGoalDone ? 1 : 0,
                              strokeWidth: 4,
                            ),
                            Icon(
                              p.dailyGoalDone
                                  ? Icons.check
                                  : Icons.flag_outlined,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('dailyGoalTitle'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                              p.dailyGoalDone
                                  ? 'Hecha: 1 nivel hoy'
                                  : 'Pasa 1 nivel hoy',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (reminderDue) ...[
          const SizedBox(height: 8),
          Card(
            color: Colors.amber.withValues(alpha: 0.18),
            child: const ListTile(
              leading: Icon(Icons.alarm),
              title: Text('Es hora de practicar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle:
                  Text('Tu recordatorio de estudio: aún no practicaste hoy.'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Pregunta del día: la misma para todos durante el día, con sus 4
/// opciones. Al contestarla queda guardada como contestada ese día.
class _QuestionOfTheDayCard extends StatefulWidget {
  const _QuestionOfTheDayCard();
  @override
  State<_QuestionOfTheDayCard> createState() => _QuestionOfTheDayCardState();
}

class _QuestionOfTheDayCardState extends State<_QuestionOfTheDayCard> {
  late final QuizQuestion _q;
  int? _selected;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _q = questionOfTheDay(DateTime.now());
    _answered =
        ProgressService.instance.qotdAnsweredOn(DateTime.now());
  }

  void _answer(int i) {
    if (_answered) return;
    final correct = i == _q.answer;
    final progress = ProgressService.instance;
    progress.recordAnswer(_q.topic, correct);
    progress.recordQotd(DateTime.now());
    final id = 'bank:${_q.topic}:${_q.question}';
    if (correct) {
      progress.removeFailed(id);
    } else {
      progress.addFailed(
          FailedEntry(id: id, topic: _q.topic, question: _q.question));
    }
    setState(() {
      _selected = i;
      _answered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primary.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 8),
                Text(tr('qotdTitle'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_answered)
                  const Icon(Icons.check_circle,
                      color: Colors.teal, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(_q.question,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_answered
                          ? scheme.surfaceContainerHighest
                          : (i == _q.answer
                              ? Colors.teal
                              : (_selected == i
                                  ? Colors.redAccent
                                  : scheme.surfaceContainerHighest)),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: () => _answer(i),
                    child: Text(_q.options[i],
                        style: const TextStyle(fontSize: 15)),
                  ),
                ),
              ),
            if (_answered) ...[
              const SizedBox(height: 4),
              Text(_q.explanation),
            ],
          ],
        ),
      ),
    );
  }
}

/// Elemento del día: uno distinto cada día, con su dato curioso.
class _ElementOfTheDayCard extends StatelessWidget {
  const _ElementOfTheDayCard({required this.onOpen});
  final void Function(ChemicalElement element) onOpen;

  @override
  Widget build(BuildContext context) {
    final e = elementOfTheDay(DateTime.now());
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(e.symbol,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: Text('${tr('elementDayTitle')}: ${e.name}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(elementFact(e)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => onOpen(e),
      ),
    );
  }
}

class _QuizState {
  _QuizState(
      {required this.testId, required this.title, required List<_QuizItem> items})
      : items = List<_QuizItem>.of(items);

  final String testId;
  final String title;
  final List<_QuizItem> items;
}

class _QuizRunner extends StatefulWidget {
  const _QuizRunner({
    required this.quiz,
    required this.spec,
    required this.onExit,
    required this.onRepeat,
  });

  final _QuizState quiz;
  final _QuizSpec spec;
  final VoidCallback onExit;
  final VoidCallback onRepeat;

  @override
  State<_QuizRunner> createState() => _QuizRunnerState();
}

class _QuizRunnerState extends State<_QuizRunner> {
  int _index = 0;
  int _score = 0;
  int? _selected; // índice en las opciones barajadas
  List<int> _order = [];
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _shuffleOptions();
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
    if (UserPrefs.soundOn) {
      if (correct) {
        HapticFeedback.lightImpact();
        SystemSound.play(SystemSoundType.click);
      } else {
        HapticFeedback.vibrate();
      }
    }
    if (correct) {
      // Acertar un error lo saca de la lista de repaso.
      progress.removeFailed(_item.id);
      setState(() {
        _selected = displayedIndex;
        _score++;
      });
    } else {
      // Fallar guarda el error para repasarlo después.
      progress.addFailed(FailedEntry(
        id: _item.id,
        topic: _q.topic,
        question: _q.question,
      ));
      setState(() => _selected = displayedIndex);
    }
  }

  void _next() {
    if (_index + 1 >= widget.quiz.items.length) {
      final percent =
          ((100 * _score) / widget.quiz.items.length).round();
      final progress = ProgressService.instance;
      progress.recordScore(widget.quiz.testId, percent);
      if (widget.spec.kind == 'level' && percent >= _passPercent) {
        progress.recordLevelPass(widget.spec.topic!, widget.spec.level);
      }
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
      final total = widget.quiz.items.length;
      final percent = ((100 * _score) / total).round();
      final isLevel = widget.spec.kind == 'level';
      final passedLevel = isLevel && percent >= _passPercent;
      final remaining =
          ProgressService.instance.failedCount;
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
                style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.tealAccent),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              passedLevel
                  ? '${tr('quizLevelPassed')} ${tr('levelWord')} ${widget.spec.level + 1}.'
                  : isLevel
                      ? tr('quizLevelFailed')
                      : widget.spec.kind == 'review'
                          ? remaining == 0
                              ? tr('quizNoErrors')
                              : '$remaining ${tr('reviewQuestions')}'
                          : percent >= _passPercent
                              ? tr('quizExcellent')
                              : percent >= 60
                                  ? tr('quizGood')
                                  : tr('quizKeepGoing'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.onRepeat,
              child: Text(tr('quizRepeat')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: widget.onExit, child: Text(tr('quizBack'))),
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
              icon: const Icon(Icons.logout, size: 20),
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
        Text(_q.question,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selected == null
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : (_order[i] == _q.answer
                        ? Colors.teal
                        : (_selected == i
                            ? Colors.redAccent
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest)),
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
                ? Colors.teal.withValues(alpha: 0.2)
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
            child: Text(_index + 1 >= total
                ? tr('quizResult')
                : tr('quizNext')),
          ),
        ],
      ],
    );
  }
}
