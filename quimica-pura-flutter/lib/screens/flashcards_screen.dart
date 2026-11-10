// Tarjetas de memoria (v5): dos mazos — fórmulas y elementos — para
// repasar como flashcards. Toca la tarjeta para darle la vuelta, marca
// si la sabías o no, y baraja el mazo. Las conocidas se guardan en el
// teléfono.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/periodic_table.dart';
import '../data/topics.dart';
import '../services/localization.dart';

class _FlashCard {
  const _FlashCard({required this.id, required this.front, required this.back});
  final String id;
  final String front;
  final String back;
}

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});
  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  String _deck = 'formulas';
  late List<_FlashCard> _cards;
  int _index = 0;
  bool _flipped = false;
  Set<String> _known = <String>{};
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _cards = _buildDeck(_deck);
    _loadKnown();
  }

  List<_FlashCard> _buildDeck(String deck) {
    if (deck == 'elementos') {
      return allElements
          .map((e) => _FlashCard(
                id: 'el:${e.atomicNumber}',
                front: e.symbol,
                back: '${e.name}\nZ = ${e.atomicNumber} · ${categoryNames[e.category]}',
              ))
          .toList();
    }
    final cards = <_FlashCard>[];
    for (final f in formulary) {
      cards.add(_FlashCard(
        id: 'f:${f['name']}',
        front: f['name'] ?? '',
        back: f['expr'] ?? '',
      ));
    }
    for (final t in topics) {
      for (final f in t.formulas) {
        cards.add(_FlashCard(
          id: 'f:${f.name}',
          front: f.name,
          back: '${f.expr}\n${f.note}',
        ));
      }
    }
    // Sin duplicados por nombre.
    final seen = <String>{};
    return cards.where((c) => seen.add(c.id)).toList();
  }

  Future<void> _loadKnown() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    setState(() {
      _known = (prefs.getStringList('melli_flash_known') ?? <String>[]).toSet();
    });
  }

  void _saveKnown() {
    _prefs?.setStringList('melli_flash_known', _known.toList());
  }

  void _setDeck(String deck) {
    setState(() {
      _deck = deck;
      _cards = _buildDeck(deck);
      _index = 0;
      _flipped = false;
    });
  }

  void _shuffle() {
    setState(() {
      _cards.shuffle(Random());
      _index = 0;
      _flipped = false;
    });
  }

  void _mark(bool known) {
    final id = _cards[_index].id;
    setState(() {
      if (known) {
        _known.add(id);
      } else {
        _known.remove(id);
      }
      _saveKnown();
      _next();
    });
  }

  void _next() {
    if (_index + 1 < _cards.length) {
      setState(() {
        _index++;
        _flipped = false;
      });
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() {
        _index--;
        _flipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _cards[_index];
    final knownCount = _cards.where((c) => _known.contains(c.id)).length;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('flashcardsTitle'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'formulas', label: Text('Fórmulas')),
                ButtonSegment(value: 'elementos', label: Text('Elementos')),
              ],
              selected: {_deck},
              onSelectionChanged: (s) => _setDeck(s.first),
            ),
            const SizedBox(height: 12),
            Text(
              'Tarjeta ${_index + 1} de ${_cards.length} · Sabidas: $knownCount',
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _flipped = !_flipped),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) {
                    final rotate = Tween<double>(begin: 0.85, end: 1.0)
                        .animate(animation);
                    return ScaleTransition(scale: rotate, child: child);
                  },
                  child: Card(
                    key: ValueKey('$_index-$_flipped'),
                    color: _flipped
                        ? scheme.primary.withValues(alpha: 0.15)
                        : null,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _flipped ? card.back : card.front,
                          style: TextStyle(
                            fontSize: _flipped ? 20 : 44,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Toca la tarjeta para darle la vuelta.',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _mark(false),
                    icon: const Icon(Icons.close),
                    label: const Text('No la sé'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _mark(true),
                    icon: const Icon(Icons.check),
                    label: const Text('La sé'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _prev,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Anterior'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shuffle,
                    icon: const Icon(Icons.shuffle),
                    label: const Text('Barajar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _next,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Siguiente'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
