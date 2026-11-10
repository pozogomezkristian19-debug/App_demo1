// Quiz de la tabla periódica (v5): adivina el elemento por su símbolo
// o el símbolo por el nombre. 10 rondas, 4 opciones. Se abre desde
// Tabla y desde la búsqueda.

import 'dart:math';

import 'package:flutter/material.dart';

import '../data/i18n/content_i18n.dart';
import '../data/periodic_table.dart';
import '../models.dart';
import '../services/localization.dart';
import '../services/progress.dart';

class TableQuizScreen extends StatefulWidget {
  const TableQuizScreen({super.key});
  @override
  State<TableQuizScreen> createState() => _TableQuizScreenState();
}

class _TableQuizScreenState extends State<TableQuizScreen> {
  bool _symbolToName = true;
  late List<ChemicalElement> _rounds;
  late List<List<ChemicalElement>> _options;
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    final rng = Random();
    final pool = List<ChemicalElement>.of(allElements)..shuffle(rng);
    _rounds = pool.take(10).toList();
    _options = _rounds.map((correct) {
      final others = List<ChemicalElement>.of(allElements)
        ..remove(correct)
        ..shuffle(rng);
      return ([correct, ...others.take(3)]..shuffle(rng));
    }).toList();
    _index = 0;
    _score = 0;
    _selected = null;
    _finished = false;
  }

  void _answer(int i) {
    if (_selected != null) return;
    final correct = _options[_index][i] == _rounds[_index];
    ProgressService.instance.recordAnswer('tabla', correct);
    setState(() {
      _selected = i;
      if (correct) _score++;
    });
  }

  void _next() {
    if (_index + 1 >= _rounds.length) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _index++;
        _selected = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('tableQuizTitle'))),
      body: _finished
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('quizResult'),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text('$_score ${tr('quizOf')} 10 ${tr('quizScore')}',
                      style: const TextStyle(fontSize: 20),
                      textAlign: TextAlign.center),
                  Text('${_score * 10}%',
                      style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.tealAccent),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(_newGame),
                    child: Text(tr('quizRepeat')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(tr('quizBack')),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                        value: true,
                        label: Text(tr('tableQuizSymToName'))),
                    ButtonSegment(
                        value: false,
                        label: Text(tr('tableQuizNameToSym'))),
                  ],
                  selected: {_symbolToName},
                  onSelectionChanged: (s) =>
                      setState(() => _symbolToName = s.first),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('tableQuizCounter')
                      .replaceFirst('%d', '${_index + 1}')
                      .replaceFirst('%d', '$_score'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _symbolToName
                          ? tr('tableQuizQSym')
                              .replaceFirst('%s', _rounds[_index].symbol)
                          : tr('tableQuizQName').replaceFirst(
                              '%s', localizedElementName(_rounds[_index])),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selected == null
                            ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                            : (_options[_index][i] == _rounds[_index]
                                ? Colors.teal
                                : (_selected == i
                                    ? Colors.redAccent
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest)),
                        padding: const EdgeInsets.all(14),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () => _answer(i),
                      child: Text(
                        _symbolToName
                            ? localizedElementName(_options[_index][i])
                            : _options[_index][i].symbol,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                if (_selected != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _options[_index][_selected!] == _rounds[_index]
                        ? tr('quizCorrect')
                        : '${tr('quizIncorrect')}. ${tr('quizCorrectIs')} ${_symbolToName ? localizedElementName(_rounds[_index]) : _rounds[_index].symbol}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _next,
                    child: Text(_index + 1 >= 10
                        ? tr('quizResult')
                        : tr('quizNext')),
                  ),
                ],
              ],
            ),
    );
  }
}
