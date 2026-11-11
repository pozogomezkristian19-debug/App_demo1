// Reto de dos jugadores (v5): sin servidor y sin cuentas, porque la
// app es offline. Dos personas juegan en el mismo teléfono, por turnos:
// cada una contesta 5 preguntas distintas y gana quien acierte más.
// Al final se puede compartir el resultado por WhatsApp.

import 'dart:math';

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/i18n/content_i18n.dart';
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
  // Ids de error en español, en paralelo a _q1/_q2 (v6: los ids no
  // dependen del idioma en que se muestran las preguntas).
  late final List<String> _ids1;
  late final List<String> _ids2;
  int _s1 = 0;
  int _s2 = 0;

  @override
  void initState() {
    super.initState();
    // Jugador 1: el nombre del perfil del usuario, con "(tú)" al lado
    // (p. ej. "Kristian (tú)"). Es un campo editable: se puede cambiar.
    // Jugador 2: empieza VACÍO, sin ningún nombre de ejemplo: la otra
    // persona escribe su propio nombre.
    _p1 = TextEditingController(
        text: UserPrefs.userName.isEmpty
            ? ''
            : '${UserPrefs.userName} ${tr('challengeYouSuffix')}');
    _p2 = TextEditingController();
    final pool = List<QuizQuestion>.of(allQuestions)..shuffle(Random());
    _q1 = [
      for (final q in pool.sublist(0, 5))
        localizedQuestionAt(allQuestions.indexOf(q))
    ];
    _q2 = [
      for (final q in pool.sublist(5, 10))
        localizedQuestionAt(allQuestions.indexOf(q))
    ];
    _ids1 = [
      for (final q in pool.sublist(0, 5)) 'bank:${q.topic}:${q.question}'
    ];
    _ids2 = [
      for (final q in pool.sublist(5, 10)) 'bank:${q.topic}:${q.question}'
    ];
  }

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  /// "¡Empate!" o "¡Ganó <nombre>!" (en el idioma de la app).
  String _winnerText() {
    if (_s1 == _s2) return tr('challengeDraw');
    final name = _s1 > _s2 ? _p1.text : _p2.text;
    return tr('challengeWon').replaceFirst('%s', name);
  }

  Future<void> _shareResult() async {
    final winner = _winnerText();
    final text =
        '${tr('challengeTitle')}: ${_p1.text} $_s1 - $_s2 ${_p2.text}. $winner';
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
                  itemIds: _phase == 1 ? _ids1 : _ids2,
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
    // Fix3, punto 4 (segunda pasada): el CTA principal es una
    // pastilla teal rellena como el del examen con tiempo, no la
    // pastilla con borde de antes.
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // El mando, en su propio círculo tintado (fix2, item 7):
          // el icono (ancho y bajo) ya no se pega ni se distorsiona
          // con el texto: tiene su hueco definido y el título va
          // DEBAJO, centrado y con altura flexible.
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const LucideIcon(LucideIcons.gamepad2,
                  size: 48, color: Colors.teal),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('challengeIntroTitle'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            tr('challengeIntroBody'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Fix3, punto 4 (segunda pasada): cada campo tiene su
          // icono de persona y un texto de ayuda (hint) visible
          // mientras está vacío. El jugador 1 ya viene prellenado
          // con el nombre del perfil + "(tú)" (ver initState); el
          // jugador 2 empieza vacío.
          TextField(
            controller: _p1,
            decoration: InputDecoration(
              labelText: tr('challengePlayer1Hint'),
              hintText: tr('challengePlayer1Placeholder'),
              prefixIcon: LucideIcon(LucideIcons.userRound,
                  size: 20, color: scheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _p2,
            decoration: InputDecoration(
              labelText: tr('challengePlayer2Hint'),
              hintText: tr('challengePlayer2Placeholder'),
              prefixIcon: LucideIcon(LucideIcons.userRound,
                  size: 20, color: scheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (_p1.text.trim().isEmpty || _p2.text.trim().isEmpty) return;
              setState(() => _phase = 1);
            },
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
            ),
            child: Text(
              tr('challengeStart'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultPhase(BuildContext context) {
    final winner = _winnerText();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // El trofeo, en su propio círculo tintado (auditoría):
          // un LucideIcon suelto en una Column con stretch se
          // estira a todo el ancho y se dibuja gigante detrás del
          // texto (lo mismo que le pasaba al mando del Reto).
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const LucideIcon(LucideIcons.trophy,
                  size: 48, color: Colors.amber),
            ),
          ),
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
            icon: const LucideIcon(LucideIcons.share2),
            label: Text(tr('challengeShareResult')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setState(() {
              final pool = List<QuizQuestion>.of(allQuestions)
                ..shuffle(Random());
              _q1.clear();
              _q1.addAll([
                for (final q in pool.sublist(0, 5))
                  localizedQuestionAt(allQuestions.indexOf(q))
              ]);
              _q2.clear();
              _q2.addAll([
                for (final q in pool.sublist(5, 10))
                  localizedQuestionAt(allQuestions.indexOf(q))
              ]);
              _ids1.clear();
              _ids1.addAll([
                for (final q in pool.sublist(0, 5))
                  'bank:${q.topic}:${q.question}'
              ]);
              _ids2.clear();
              _ids2.addAll([
                for (final q in pool.sublist(5, 10))
                  'bank:${q.topic}:${q.question}'
              ]);
              _s1 = 0;
              _s2 = 0;
              _phase = 1;
            }),
            child: Text(tr('challengeRematch')),
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
