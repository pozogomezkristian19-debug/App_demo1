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
    final mixedUnlocked = _mixedUnlocked();
    final level1Done = byTopic.keys.length - _missingLevel1Topics().length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Practicar',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'Avanza por niveles como en Duolingo: 5 preguntas por nivel, y para pasar necesitas 4 de 5. Tus errores se guardan y se repasan hasta que los aciertes. Todo se guarda en el teléfono.',
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
        // Examen mixto: reto final, bloqueado hasta pasar el Nivel 1 de todo.
        Card(
          child: ListTile(
            leading: Icon(
              mixedUnlocked ? Icons.assignment : Icons.lock,
              size: 32,
            ),
            title: const Text('Examen mixto',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(mixedUnlocked
                ? '24 preguntas mezcladas de todos los temas, con más peso en tus temas débiles.'
                : 'Pasa el Nivel 1 de los 8 temas para desbloquearlo ($level1Done/8).'),
            trailing: mixedUnlocked
                ? Text('Mejor: ${progress.bestScore('mixto')}%')
                : Text('$level1Done/8'),
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
        ),
        const SizedBox(height: 16),
        const Text('Niveles por tema',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final entry in byTopic.entries)
          _TopicLevelsCard(
            topic: entry.key,
            bankCount: entry.value.length,
            levelCount: _levelCount(entry.key),
            onLevelTap: (level) => _start(
              _QuizSpec(kind: 'level', topic: entry.key, level: level),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'Banco total: ${allQuestions.length} preguntas únicas, más preguntas nuevas generadas con números distintos cada vez.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _TopicLevelsCard extends StatelessWidget {
  const _TopicLevelsCard({
    required this.topic,
    required this.bankCount,
    required this.levelCount,
    required this.onLevelTap,
  });

  final String topic;
  final int bankCount;
  final int levelCount;
  final ValueChanged<int> onLevelTap;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressService.instance;
    final unlocked = progress.unlockedLevel(topic);
    var best = 0;
    for (var i = 1; i <= levelCount; i++) {
      final s = progress.bestScore('level:$topic:$i');
      if (s > best) best = s;
    }
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.quiz_outlined),
        title: Text(topicNames[topic] ?? topic,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            'Nivel ${unlocked > levelCount ? levelCount : unlocked} de $levelCount · Mejor: $best%'),
        children: [
          for (var level = 1; level <= levelCount; level++)
            _LevelRow(
              topic: topic,
              level: level,
              levelCount: levelCount,
              bankCount: bankCount,
              unlocked: level <= unlocked,
              onTap: () => onLevelTap(level),
            ),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.topic,
    required this.level,
    required this.levelCount,
    required this.bankCount,
    required this.unlocked,
    required this.onTap,
  });

  final String topic;
  final int level;
  final int levelCount;
  final int bankCount;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressService.instance;
    final best = progress.bestScore('level:$topic:$level');
    final passed = best >= _passPercent;
    // Niveles sin preguntas del banco: solo preguntas nuevas generadas.
    final generatedOnly = (level - 1) * _levelSize >= bankCount;
    return ListTile(
      leading: Icon(
        passed
            ? Icons.check_circle
            : unlocked
                ? Icons.play_circle_outline
                : Icons.lock_outline,
        color: passed
            ? Colors.teal
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      title: Text('Nivel $level',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(unlocked
          ? generatedOnly
              ? 'Preguntas nuevas · Mejor: $best%'
              : 'Mejor: $best%'
          : 'Completa el Nivel ${level - 1} para desbloquearlo'),
      trailing: unlocked
          ? const Icon(Icons.chevron_right)
          : null,
      onTap: unlocked
          ? onTap
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Primero pasa el Nivel ${level - 1} con 4 de 5.'),
                ),
              );
            },
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
