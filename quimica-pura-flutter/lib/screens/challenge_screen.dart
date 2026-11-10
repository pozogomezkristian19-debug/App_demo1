// Reto de dos jugadores (v5): sin servidor y sin cuentas, porque la
// app es offline. Dos personas juegan en el mismo teléfono, por turnos:
// cada una contesta 5 preguntas distintas y gana quien acierte más.
// Al final se puede compartir el resultado por WhatsApp.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/questions.dart';
import '../models.dart';
import '../services/localization.dart';
import '../services/user_prefs.dart';
import '../widgets/simple_quiz.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});
  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  late final TextEditingController _p1;
  late final TextEditingController _p2;
  int _phase = 0; // 0 nombres, 1 juega P1, 2 juega P2, 3 resultado
  late final List<QuizQuestion> _q1;
  late final List<QuizQuestion> _q2;
  int _s1 = 0;
  int _s2 = 0;

  @override
  void initState() {
    super.initState();
    _p1 = TextEditingController(
        text: UserPrefs.userName.isEmpty ? 'Jugador 1' : UserPrefs.userName);
    _p2 = TextEditingController(text: 'Novia');
    final pool = List<QuizQuestion>.of(allQuestions)..shuffle(Random());
    _q1 = pool.sublist(0, 5);
    _q2 = pool.sublist(5, 10);
  }

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _shareResult() async {
    final winner = _s1 == _s2
        ? '¡Empate!'
        : _s1 > _s2
            ? '¡Ganó ${_p1.text}!'
            : '¡Ganó ${_p2.text}!';
    final text =
        'Reto de química en Melli-Qui: ${_p1.text} $_s1 - $_s2 ${_p2.text}. $winner';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('challengeTitle'))),
      body: _phase == 0
          ? _namesPhase(context)
          : _phase == 3
              ? _resultPhase(context)
              : SimpleQuizRunner(
                  title: tr('challengeTitle'),
                  items: _phase == 1 ? _q1 : _q2,
                  playerName: _phase == 1 ? _p1.text : _p2.text,
                  onFinished: (score, total) {
                    if (_phase == 1) {
                      setState(() {
                        _s1 = score;
                        _phase = 2;
                      });
                    } else {
                      setState(() {
                        _s2 = score;
                        _phase = 3;
                      });
                    }
                  },
                  onExit: () => Navigator.of(context).pop(),
                ),
    );
  }

  Widget _namesPhase(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.sports_esports, size: 64, color: Colors.teal),
          const SizedBox(height: 16),
          const Text(
            'El reto',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Dos jugadores, un teléfono, 5 preguntas cada uno. Gana quien acierte más. Pasad el teléfono al cambiar de turno.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _p1,
            decoration: const InputDecoration(labelText: 'Jugador 1'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _p2,
            decoration: const InputDecoration(labelText: 'Jugador 2'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (_p1.text.trim().isEmpty || _p2.text.trim().isEmpty) return;
              setState(() => _phase = 1);
            },
            child: const Text('Empezar el reto'),
          ),
        ],
      ),
    );
  }

  Widget _resultPhase(BuildContext context) {
    final winner = _s1 == _s2
        ? '¡Empate!'
        : _s1 > _s2
            ? '¡Ganó ${_p1.text}!'
            : '¡Ganó ${_p2.text}!';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
          const SizedBox(height: 16),
          Text(winner,
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('${_p1.text}: $_s1 de 5',
              style: const TextStyle(fontSize: 19),
              textAlign: TextAlign.center),
          Text('${_p2.text}: $_s2 de 5',
              style: const TextStyle(fontSize: 19),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _shareResult,
            icon: const Icon(Icons.share),
            label: const Text('Compartir resultado por WhatsApp'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setState(() {
              final pool = List<QuizQuestion>.of(allQuestions)
                ..shuffle(Random());
              _q1.clear();
              _q1.addAll(pool.sublist(0, 5));
              _q2.clear();
              _q2.addAll(pool.sublist(5, 10));
              _s1 = 0;
              _s2 = 0;
              _phase = 1;
            }),
            child: const Text('Revancha'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('quizBack')),
          ),
        ],
      ),
    );
  }
}
