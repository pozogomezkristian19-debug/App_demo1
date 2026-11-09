import 'dart:math';
import 'package:flutter/material.dart';
import '../data/questions.dart';
import '../models.dart';
import '../services/progress.dart';
import '../services/question_generator.dart';

// Practicar estilo Duolingo: niveles por tema, repaso de errores y memoria
// que no se borra al cerrar la app (todo vive en ProgressService, que
// guarda en SharedPreferences).
//
// - Cada tema se parte en niveles de 5 preguntas. Para pasar de nivel hay
//   que sacar al menos 4 de 5 (80%); al pasarlo se desbloquea el siguiente.
//   Los niveles usan primero las preguntas del banco, en orden, y después
//   preguntas nuevas generadas, así un nivel siempre tiene 5 preguntas.
// - El examen mixto (24 preguntas) es el reto final: se desbloquea cuando
//   se pasa el Nivel 1 de los 8 temas. Sus preguntas pesan hacia los temas
//   más débiles del usuario.
// - Cada error se guarda. 'Repasar mis errores' repite solo las preguntas
//   falladas: acertar una la saca de la lista, fallarla la deja.
// - Cada nivel empieza con hasta 2 errores pendientes de ese tema.

const int _levelSize = 5;
const int _passNeeded = 4; // 4 de 5 = 80%
const int _passPercent = (_passNeeded * 100) ~/ _levelSize; // 80%
const int _extraGeneratedLevels = 2; // niveles extra solo con preguntas nuevas
const int _mixedSize = 24;
const int _reviewMax = 20;

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
};

String bankId(QuizQuestion q) => 'bank:${q.topic}:${q.question}';

class _QuizItem {
  const _QuizItem({required this.id, required this.question});
  final String id; // 'bank:...' o 'gen:...'
  final QuizQuestion question;
}

class _QuizSpec {
  const _QuizSpec({required this.kind, this.topic, this.level = 0});
  final String kind; // 'level', 'review' o 'mixto'
  final String? topic;
  final int level;
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

  /// Primer nivel sin pasar (tema y nivel), o null si ya pasó todo.
  ({int topicIndex, int level})? _firstUnpassed() {
    final topics = _byTopic.keys.toList();
    for (var i = 0; i < topics.length; i++) {
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

  Map<String, List<QuizQuestion>> get _byTopic {
    final byTopic = <String, List<QuizQuestion>>{};
    for (final q in allQuestions) {
      byTopic.putIfAbsent(q.topic, () => []).add(q);
    }
    return byTopic;
  }

  int _levelCount(String topic) {
    final bank = _byTopic[topic]?.length ?? 0;
    return (bank / _levelSize).ceil() + _extraGeneratedLevels;
  }

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
    // Después, las preguntas del banco de este nivel, en orden.
    final start = (level - 1) * _levelSize;
    if (start < bank.length) {
      final end = min(start + _levelSize, bank.length);
      for (final q in bank.sublist(start, end)) {
        final id = bankId(q);
        if (used.add(id)) items.add(_QuizItem(id: id, question: q));
      }
    }
    // Y preguntas nuevas generadas hasta completar 5.
    final rng = Random();
    var guard = 0;
    while (items.length < _levelSize && guard < 60) {
      guard++;
      final g = generateForTopic(topic, rng);
      if (used.add(g.id)) {
        items.add(_QuizItem(id: g.id, question: g.question));
      }
    }
    return items;
  }

  List<_QuizItem> _buildReviewQuestions() {
    final progress = ProgressService.instance;
    final items = <_QuizItem>[];
    final entries = List<FailedEntry>.of(progress.failedEntries)..shuffle();
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
    var guard = 0;
    while (items.length < _mixedSize && guard < 200) {
      guard++;
      final g = generateAdaptive(weakest, rng);
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
        return _buildReviewQuestions();
      default:
        return _buildMixedQuestions();
    }
  }

  String _titleFor(_QuizSpec spec) {
    switch (spec.kind) {
      case 'level':
        return '${topicNames[spec.topic] ?? spec.topic} · Nivel ${spec.level}';
      case 'review':
        return 'Repasar mis errores';
      default:
        return 'Examen mixto';
    }
  }

  void _start(_QuizSpec spec) {
    final questions = _buildQuestions(spec);
    if (questions.isEmpty) return;
    _scrolledToCurrent = false;
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
        onExit: () => setState(() => _quiz = null),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Niveles',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Avanza por el camino: 5 preguntas por nivel, y para pasar necesitas 4 de 5. Tus errores se guardan y se repasan hasta que los aciertes. Todo se guarda en el teléfono.',
          ),
          const SizedBox(height: 12),
          Text(
            'Has superado $passedCount de $totalCount niveles.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          // Repaso de errores, solo si hay algo que repasar.
          if (progress.failedCount > 0)
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.15),
              child: ListTile(
                leading: const Icon(Icons.replay_circle_filled, size: 32),
                title: const Text('Repasar mis errores',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${progress.failedCount} ${progress.failedCount == 1 ? 'pregunta' : 'preguntas'} por corregir'),
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
              currentLevel:
                  current != null && current.topicIndex == i ? current.level : 0,
              currentKey:
                  current != null && current.topicIndex == i ? _currentKey : null,
              onLevelTap: (level, unlocked) {
                if (unlocked) {
                  _start(_QuizSpec(
                      kind: 'level', topic: topics[i], level: level));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Primero pasa el Nivel ${level - 1} con 4 de 5.'),
                    ),
                  );
                }
              },
            ),
          // Examen mixto: trofeo final del camino, bloqueado hasta pasar
          // el Nivel 1 de los 8 temas.
          _FinalExamSection(
            unlocked: mixedUnlocked,
            level1Done: level1Done,
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
                    content: Text(
                        'Te falta el Nivel 1 de: $missing. Pásalo con 4 de 5 y el examen se desbloquea.'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Banco total: ${allQuestions.length} preguntas únicas, más preguntas nuevas generadas con números distintos cada vez.',
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
/// punteada que pasa por el centro de cada nivel.
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
    // Línea punteada a partir del camino.
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = min(12.0, metric.length - distance);
        dashed.addPath(
            metric.extractPath(distance, distance + len), Offset.zero);
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
/// camino serpenteante, como una unidad de Duolingo.
class _TopicPathSection extends StatelessWidget {
  const _TopicPathSection({
    required this.topic,
    required this.bankCount,
    required this.levelCount,
    required this.currentLevel,
    required this.currentKey,
    required this.onLevelTap,
  });

  final String topic;
  final int bankCount;
  final int levelCount;

  /// Nivel actual del tema (0 si ninguno es el actual).
  final int currentLevel;
  final GlobalKey? currentKey;
  final void Function(int level, bool unlocked) onLevelTap;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressService.instance;
    final unlocked = progress.unlockedLevel(topic);
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
                color: scheme.primary.withValues(alpha: 0.35),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(
                height: _headerH,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: color.withValues(alpha: 0.18),
                      child: Icon(
                          _topicIcons[topic] ?? Icons.quiz_outlined,
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
                            'Nivel ${unlocked > levelCount ? levelCount : unlocked} de $levelCount · Mejor: $best%',
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
              for (var level = 1; level <= levelCount; level++)
                _LevelNodeRow(
                  key: level == currentLevel ? currentKey : null,
                  topic: topic,
                  level: level,
                  bankCount: bankCount,
                  unlocked: level <= unlocked,
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
/// o derecha para que el camino serpentee.
class _LevelNodeRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final progress = ProgressService.instance;
    final best = progress.bestScore('level:$topic:$level');
    final passed = best >= _passPercent;
    // Niveles sin preguntas del banco: solo preguntas nuevas generadas.
    final generatedOnly = (level - 1) * _levelSize >= bankCount;
    final scheme = Theme.of(context).colorScheme;
    final offset = _pathOffsets[(level - 1) % _pathOffsets.length];
    final Color bg;
    final Widget inner;
    if (passed) {
      bg = const Color(0xFFFFB300);
      inner = const Icon(Icons.check, color: Color(0xFF5D4037), size: 34);
    } else if (unlocked) {
      bg = scheme.primary;
      inner = Text('$level',
          style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white));
    } else {
      bg = scheme.onSurface.withValues(alpha: 0.12);
      inner = Icon(Icons.lock,
          color: scheme.onSurface.withValues(alpha: 0.5), size: 28);
    }
    return SizedBox(
      height: _rowH,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cx = constraints.maxWidth / 2 + offset;
          return Stack(
            children: [
              if (isCurrent)
                Positioned(
                  left: cx - 38,
                  top: _nodeCenterY - 38,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              Positioned(
                left: cx - _nodeSize / 2,
                top: _nodeCenterY - _nodeSize / 2,
                child: GestureDetector(
                  onTap: () => onLevelTap(level, unlocked),
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
                      ? 'Nivel $level · $best%'
                      : generatedOnly && unlocked
                          ? 'Nivel $level · Nuevas'
                          : 'Nivel $level',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent
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

/// El trofeo final del camino: el examen mixto de 24 preguntas.
class _FinalExamSection extends StatelessWidget {
  const _FinalExamSection({
    required this.unlocked,
    required this.level1Done,
    required this.isCurrent,
    required this.currentKey,
    required this.onTap,
  });

  final bool unlocked;
  final int level1Done;
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
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Examen final',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('El reto final del camino'),
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
                  : scheme.onSurface.withValues(alpha: 0.12),
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
                  : scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          unlocked
              ? (best > 0
                  ? 'Examen mixto · Mejor: $best%'
                  : 'Examen mixto · 24 preguntas')
              : 'Examen mixto · $level1Done/8',
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        if (!unlocked)
          Text(
            'Pasa el Nivel 1 de los 8 temas para desbloquearlo.',
            style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
      ],
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
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Resultado',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('$_score de $total correctas',
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
                  ? '¡Nivel superado! Se desbloqueó el Nivel ${widget.spec.level + 1}.'
                  : isLevel
                      ? 'Te faltó poco: necesitas 4 de 5 para pasar de nivel. Tus errores quedaron guardados para repasarlos.'
                      : widget.spec.kind == 'review'
                          ? remaining == 0
                              ? '¡Sin errores pendientes! Lo corregiste todo.'
                              : 'Te quedan $remaining ${remaining == 1 ? 'error' : 'errores'} por repasar.'
                          : percent >= _passPercent
                              ? 'Excelente, nivel de examen.'
                              : percent >= 60
                                  ? 'Bien, repasa los temas fallidos en Aprender.'
                                  : 'Sigue practicando: revisa cada explicación y repite el test.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.onRepeat,
              child: const Text('Repetir este test'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: widget.onExit, child: const Text('Elegir otro test')),
          ],
        ),
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
                '${widget.quiz.title} · Pregunta ${_index + 1} de $total',
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 8),
            // Botón Salir de verdad: grande, con borde y con icono.
            OutlinedButton.icon(
              onPressed: widget.onExit,
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Salir', style: TextStyle(fontSize: 16)),
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
                        ? 'Correcto ✓'
                        : 'Incorrecto. Correcta: ${_q.options[_q.answer]}',
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
                ? 'Ver resultado'
                : 'Siguiente pregunta'),
          ),
        ],
      ],
    );
  }
}
