// Quiz reutilizable (v5): lo usan el examen con tiempo y cualquier
// quiz corto. Registra las respuestas en ProgressService igual que el
// quiz de Niveles (aciertos por tema y errores para repasar), con
// sonido y vibración al contestar. Puntos por dificultad en cada
// respuesta (v6). Vidas: NINGUNA (fix4, punto 5): las vidas son solo
// de los niveles; aquí salir no cuesta nada.
//
// - `durationSeconds`: si se pasa, hay cuenta atrás y al llegar a cero
//   se entrega el quiz automáticamente.
// - `playerName`: etiqueta del jugador que está contestando.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'duo_button.dart';
import 'lucide_icons.dart';

import '../models.dart';
import '../services/localization.dart';
import '../services/numeric_answer.dart';
import '../services/points.dart';
import 'report_question.dart';
import '../services/progress.dart';
import '../services/sound_service.dart';
import '../screens/calculator_screen.dart';
import 'twin_avatars.dart';

/// Tokens claros (paleta propia de Melli-Qui, sin verde Duolingo):
/// teal #00C2A8 como color principal, teal oscuro #00A18D.
const _teal = Color(0xFF00C2A8);
const _tealDark = Color(0xFF00A18D);

/// Estado visual de una opción de respuesta: sin contestar, o
/// juzgada al momento (el flujo original: tocar la opción la
/// juzga, sin paso de COMPROBAR).
enum QuizOptionState { normal, correct, wrong }

/// Botón de opción de respuesta (rediseño Duolingo, spec §1.5/§3.3.4):
/// cara sólida, radio 12, borde 2 pt + labio 2 pt (sombra sólida
/// desplazada, sin desenfoque). Sin degradado, sin brillo, sin sombra
/// borrosa. El color del texto lo fija el ESTADO (spec §2), no el
/// parámetro [textColor], que se conserva solo por compatibilidad con
/// los llamadores antiguos (lab, tabla): se ignora.
///
/// Lo usan el quiz de Niveles, el de laboratorio y el de la tabla
/// periódica (además del SimpleQuizRunner: duelos, torneos y examen
/// con tiempo).
class QuizOptionButton extends StatelessWidget {
  const QuizOptionButton({
    super.key,
    required this.text,
    required this.state,
    required this.textColor,
    required this.onPressed,
    this.fontSize = 17,
  });

  final String text;
  final QuizOptionState state;

  /// Compatibilidad: los llamadores antiguos lo pasan, pero el color
  /// real lo decide [state] (spec §2). Se ignora a propósito.
  final Color textColor;
  final VoidCallback onPressed;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF4B4B4B);
    const line = Color(0xFFE5E5E5);
    final (Color bg, Color edge, Color label) = switch (state) {
      QuizOptionState.normal => (
          Colors.white,
          line,
          ink,
        ),
      QuizOptionState.correct => (
          const Color(0xFFCCFBF1),
          _teal,
          _tealDark,
        ),
      QuizOptionState.wrong => (
          const Color(0xFFFFDFE0),
          const Color(0xFFFF4B4B),
          const Color(0xFFEA2B2B),
        ),
    };
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: edge, width: 2),
        // Labio 2 pt: sombra sólida (sin desenfoque) desplazada 2 px
        // hacia abajo, del mismo color que el borde.
        boxShadow: [
          BoxShadow(color: edge, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            foregroundColor: label,
            alignment: Alignment.centerLeft,
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: label,
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de progreso Duolingo (spec §1.11/§3.3.1): 12 pt de alto,
/// radio píldora, pista #E5E5E5, relleno teal con brillo superior
/// #14D3B8 (una franja sólida de 3 px arriba, no un degradado).
class DuoProgressBar extends StatelessWidget {
  const DuoProgressBar({super.key, required this.value});

  /// 0.0 – 1.0.
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 12,
        color: const Color(0xFFE5E5E5),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: 12,
              color: _teal,
              child: const Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: 3,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFF14D3B8)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón de acción fijado abajo en el quiz: ancho completo, texto
/// 17 pt peso 800 en mayúsculas. Es el botón de Duolingo, que
/// SIEMPRE se ve abajo: gris deshabilitado (#E5E5E5 / texto
/// #AFAFAF, sin acción) hasta elegir respuesta, y teal sólido con
/// labio al contestar (DuoButton primario). Que se vea en gris
/// antes de contestar no cambia el flujo: sin respuesta no se
/// puede avanzar, igual que en v6 (donde no se veía botón); solo
/// es la referencia visual de dónde va la acción, como en la
/// captura real de Duolingo. DuoButton no tiene variante
/// deshabilitada, así que ese estado se pinta aquí con su misma
/// forma (píldora, mismo padding).
class DuoCheckButton extends StatelessWidget {
  const DuoCheckButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (onPressed == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5E5),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFFAFAFAF),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: DuoButton.primary(
        label: label.toUpperCase(),
        onPressed: onPressed,
        fontSize: 17,
      ),
    );
  }
}

/// X de cierre de la lección (spec §3.3.1): icono 24 pt #4B4B4B con
/// área táctil de 44 pt. Mantiene la misma salida que el botón
/// "Salir" de antes (con su aviso cuando cuesta una vida).
class DuoCloseButton extends StatelessWidget {
  const DuoCloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: const Icon(
          Icons.close,
          size: 24,
          color: Color(0xFF4B4B4B),
        ),
      ),
    );
  }
}

/// Título de una línea encima de la barra de progreso (spec §3.3.1):
/// 14 pt peso 500 gris.
class DuoQuizTitle extends StatelessWidget {
  const DuoQuizTitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF777777),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class SimpleQuizRunner extends StatefulWidget {
  const SimpleQuizRunner({
    super.key,
    required this.title,
    required this.items,
    required this.onFinished,
    required this.onExit,
    this.durationSeconds,
    this.playerName,
    this.onRepeat,
    this.itemIds,
    this.shuffleSeed,
  });

  final String title;
  final List<QuizQuestion> items;

  /// (correctas, respondidas). En un quiz con tiempo, "respondidas" es
  /// cuántas preguntas se llegaron a contestar antes de que se acabara
  /// el tiempo, no el tamaño de la lista (la lista no tiene fin real).
  final void Function(int score, int total) onFinished;
  final VoidCallback onExit;
  final int? durationSeconds;
  final String? playerName;
  final VoidCallback? onRepeat;

  /// Id de cada pregunta ('bank:...' o 'gen:...'), para guardar los
  /// errores con el id correcto. Si no se pasa, se asume banco.
  final List<String>? itemIds;

  /// Semilla para el orden de las opciones: solo la usan las previews
  /// (goldens deterministas). null (por defecto, en la app) = orden
  /// aleatorio como siempre, distinto en cada intento; con semilla,
  /// el orden es estable por pregunta (semilla + índice) y distinto
  /// entre preguntas. Sin ella, un golden que captura opciones
  /// acierta el orden aleatorio solo 1 de cada 24 veces.
  final int? shuffleSeed;

  @override
  State<SimpleQuizRunner> createState() => _SimpleQuizRunnerState();
}

class _SimpleQuizRunnerState extends State<SimpleQuizRunner> {
  int _index = 0;
  int _score = 0;
  int _answered = 0; // preguntas contestadas (no las vistas sin contestar)
  int _points = 0; // puntos netos de este quiz (ver points.dart)
  int? _selected;
  List<int> _order = [];
  bool _finished = false;
  Timer? _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _remaining = widget.durationSeconds ?? 0;
    _shuffleOptions();
    _startTimer();
  }

  /// Cuenta atrás del examen con tiempo: al llegar a cero se
  /// entrega solo. Extraída de initState porque didUpdateWidget
  /// también la necesita al resetear (fix5, punto Repetir).
  void _startTimer() {
    if (widget.durationSeconds == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _timer?.cancel();
        if (!_finished) _finish();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SimpleQuizRunner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cambio de cuestionario con el mismo State reutilizado (Repetir
    // con otro lote de preguntas). Sin resetear TODO el estado
    // interno, el segundo lote arrancaba en la pantalla de resultado
    // del primero (fix5, punto Repetir; mismo bug que en _QuizRunner
    // de Niveles). La lista es la identidad del cuestionario; el
    // examen con tiempo no se ve afectado: su Repetir desmonta el
    // runner y vuelve a la elección de duración.
    if (widget.items != oldWidget.items ||
        widget.durationSeconds != oldWidget.durationSeconds) {
      _timer?.cancel();
      _index = 0;
      _score = 0;
      _answered = 0;
      _points = 0;
      _finished = false;
      _remaining = widget.durationSeconds ?? 0;
      _shuffleOptions();
      _startTimer();
    }
  }

  void _shuffleOptions() {
    final seed = widget.shuffleSeed;
    _order = [0, 1, 2, 3]
      ..shuffle(
          seed == null ? Random() : Random(seed * 7919 + _index));
    _selected = null;
  }

  QuizQuestion get _q => widget.items[_index];

  String get _id {
    final ids = widget.itemIds;
    if (ids != null && _index < ids.length) return ids[_index];
    return 'bank:${_q.topic}:${_q.question}';
  }

  Future<void> _feedback(bool correct) async {
    if (correct) {
      await SoundService.correct();
    } else {
      await SoundService.wrong();
    }
  }

  /// Tocar una opción la juzga AL MOMENTO (flujo original, v6):
  /// puntos, errores y sonidos se registran al tocar, sin paso
  /// intermedio de COMPROBAR ni panel de inundación. La regla dura
  /// de Kristian (2026-11-11) prohíbe reestructurar este flujo con
  /// un cambio de diseño: el rediseño es solo aspecto (§3.3.6 y
  /// §3.3.7 quedan pendientes como cambios de flujo).
  void _answer(int displayedIndex) {
    if (_selected != null) return;
    final realIndex = _order[displayedIndex];
    final correct = realIndex == _q.answer;
    final progress = ProgressService.instance;
    // Puntos por dificultad (v6): el acierto suma, el fallo resta más
    // de lo que el acierto sumaría. Se suman AL CONTESTAR, así que
    // al salir de la partida los puntos ganados se quedan (fix4,
    // punto 5).
    final delta = correct
        ? pointsForCorrect(_q.difficulty)
        : pointsForWrong(_q.difficulty);
    progress.recordAnswer(_q.topic, correct);
    progress.addPoints(delta);
    _feedback(correct);
    if (correct) {
      progress.removeFailed(_id);
      setState(() {
        _selected = displayedIndex;
        _score++;
        _answered++;
        _points += delta;
      });
    } else {
      progress.addFailed(
          FailedEntry(id: _id, topic: _q.topic, question: _q.question));
      setState(() {
        _selected = displayedIndex;
        _answered++;
        _points += delta;
      });
    }
  }

  /// Respuesta de una pregunta de cálculo (fix3, punto 7): el valor
  /// tecleado en el teclado numérico se traduce al índice de opción
  /// que le corresponde y pasa por el mismo `_answer` de siempre, con
  /// los mismos puntos y repaso de errores (las vidas son solo de los
  /// niveles, fix4, punto 5).
  void _answerNumeric(double value) {
    if (_selected != null) return;
    // Las preguntas de cálculo no tienen opciones que seleccionar:
    // el valor tecleado se responde en un solo paso.
    _answer(displayedIndexForNumericAnswer(
        typed: value, question: _q, order: _order));
  }

  void _next() {
    if (_index + 1 >= widget.items.length) {
      _finish();
    } else {
      setState(() {
        _index++;
        _shuffleOptions();
      });
    }
  }

  void _finish() {
    _timer?.cancel();
    // Se entrega con lo respondido hasta ahora, no con la lista entera:
    // en el examen con tiempo la lista no tiene fin real.
    widget.onFinished(_score, _answered);
    setState(() => _finished = true);
  }

  /// Salir en medio de una partida (fix4, punto 5): este quiz NO
  /// cuesta vidas (las vidas son solo de los niveles): salir termina
  /// la partida y los puntos ganados hasta aquí se quedan. Se pide
  /// confirmación antes de salir. De un quiz ya terminado se sale
  /// directo, sin aviso.
  void _requestExit() {
    if (_finished) {
      widget.onExit();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('exitNoLivesTitle')),
        content: Text(tr('exitNoLivesBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('exitLevelStay')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              widget.onExit();
            },
            child: Text(tr('exitNoLivesLeave')),
          ),
        ],
      ),
    );
  }

  String get _timeText {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Colores del tema (no fijos): en claro onSurface es la tinta
    // #3C3C3C de siempre y en oscuro es casi blanco, así el título,
    // el botón Salir y la pregunta se leen en los dos temas.
    final scheme = Theme.of(context).colorScheme;
    if (_finished) {
      // En el examen con tiempo, "total" es lo respondido (la lista no
      // tiene fin); en los demás quizzes es el total de la lista.
      final total = _answered;
      final percent = total == 0 ? 0 : ((100 * _score) / total).round();
      final timed = widget.durationSeconds != null;
      final pointsText = _points >= 0 ? '+$_points' : '$_points';
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('quizResult'),
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (timed) ...[
              Text('${tr('timedAnswered')}: $total',
                  style: TextStyle(fontSize: 20, color: scheme.onSurface),
                  textAlign: TextAlign.center),
              Text('${tr('quizScore')}: $_score ${tr('quizOf')} $total',
                  style: TextStyle(fontSize: 20, color: scheme.onSurface),
                  textAlign: TextAlign.center),
            ] else
              Text('$_score ${tr('quizOf')} $total ${tr('quizScore')}',
                  style: TextStyle(fontSize: 20, color: scheme.onSurface),
                  textAlign: TextAlign.center),
            Text('$percent%',
                style: const TextStyle(
                    fontSize: 48, fontWeight: FontWeight.bold, color: _teal),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('${tr('pointsWord')}: $pointsText',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            MascotBubble(
              companion: companionForTurn(_index),
              mood: (total > 0 && _score * 5 >= total * 3)
                  ? TwinMood.happy
                  : TwinMood.soft,
              text: tr(mascotLineKey(
                  companionForTurn(_index),
                  total > 0 && _score * 5 >= total * 3
                      ? MascotLine.praise
                      : MascotLine.console,
                  _answered)),
            ),
            const SizedBox(height: 24),
            // Botones del resultado genérico (examen con tiempo,
            // duelos, torneos): texto en mayúsculas 17 pt.
            if (widget.onRepeat != null)
              DuoButton.primary(
                label: tr('quizRepeat').toUpperCase(),
                onPressed: widget.onRepeat,
                icon: LucideIcons.rotateCcw,
                fontSize: 17,
              ),
            if (widget.onRepeat != null) const SizedBox(height: 8),
            DuoButton.secondary(
              label: tr('quizBack').toUpperCase(),
              onPressed: widget.onExit,
              textColor: _tealDark,
              edgeColor: const Color(0xFF99E5D8),
              fontSize: 17,
            ),
          ],
        ),
      );
    }

    final timed = widget.durationSeconds != null;
    // Bloqueo de sesión (fix2, ronda 2): mientras la partida está
    // en curso, ni el botón atrás del sistema ni la flecha de la
    // barra pueden cerrar la partida directamente: muestran el
    // aviso de Salir (sin pérdida de vida: las vidas son solo de
    // los niveles, fix4, punto 5). Terminada la partida,
    // se sale libre.
    final titleLine = widget.playerName == null
        ? (timed
            // Sin "de N": en el examen con tiempo no hay un
            // total fijo, la meta es responder lo máximo.
            ? '${widget.title} · ${tr('quizQuestion')} ${_index + 1}'
            : '${widget.title} · ${tr('quizQuestion')} ${_index + 1} ${tr('quizOf')} ${widget.items.length}')
        : '${widget.playerName} · ${tr('quizQuestion')} ${_index + 1} ${tr('quizOf')} ${widget.items.length}';
    final wasCorrect =
        _selected != null && _order[_selected!] == _q.answer;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Barra superior Duolingo (§3.3.1): título en una sola
                // línea pequeña encima de la barra; X de cierre a la
                // izquierda y barra de progreso de 12 pt.
                DuoQuizTitle(text: titleLine),
                const SizedBox(height: 8),
                Row(
                  children: [
                    DuoCloseButton(onPressed: _requestExit),
                    const SizedBox(width: 12),
                    Expanded(
                      child: timed
                          ? Text(
                              '${tr('timedAnswered')}: $_answered · ${tr('quizScore')}: $_score · ${tr('pointsWord')}: ${_points >= 0 ? '+$_points' : '$_points'}',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF777777)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : DuoProgressBar(
                              value:
                                  (_index + 1) / widget.items.length,
                            ),
                    ),
                    if (timed) ...[
                      const SizedBox(width: 8),
                      Chip(
                        backgroundColor: scheme.surfaceContainerHighest,
                        side: BorderSide(color: scheme.outlineVariant),
                        avatar: const LucideIcon(LucideIcons.timer,
                            size: 18, color: _tealDark, threeD: true),
                        label: Text(_timeText,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface)),
                      ),
                    ],
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
                // las demás (solo para calcular a mano).
                QuestionCalculatorButton(
                  question: Text(_q.question,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4B4B4B))),
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
                        textColor: scheme.onSurface,
                        onPressed: () => _answer(i),
                      ),
                    ),
                // Quemia 7.0: reportar la pregunta — opción pequeña y
                // discreta bajo las opciones (regla 1: solo este texto).
                ReportQuestionButton(questionId: _id),
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
                          ? _tealDark
                          : const Color(0xFFEA2B2B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_q.explanation,
                      style: const TextStyle(
                          fontSize: 16, color: Color(0xFF4B4B4B))),
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
              label: _index + 1 >= widget.items.length
                  ? tr('quizResult')
                  : tr('quizNext'),
              onPressed: _selected == null ? null : _next,
            ),
          ),
        ],
      ),
    );
  }
}
