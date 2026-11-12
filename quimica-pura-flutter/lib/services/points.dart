// Sistema de puntos y vidas de Melli-Qui (v6). Lógica pura: se puede
// probar sin Flutter (ver test/v6_logic_test.dart).
//
// ## Puntos por pregunta (por dificultad)
//   | Dificultad | Acierto | Fallo |
//   |------------|---------|-------|
//   | 1 Fácil    | +3      | −5    |
//   | 2 Media    | +5      | −8    |
//   | 3 Difícil  | +8      | −12   |
// El fallo pesa MÁS que el acierto (pierdes ~1,5 veces lo que ganarías):
// un fallo no es un cero, es un castigo. El saldo total de puntos vive
// en ProgressService y se guarda en el teléfono.
//
// ## Pasar de nivel por aciertos (fix5, punto 13)
// Se pasa el nivel acertando 4 o más de 5 preguntas, sin importar la
// dificultad: es lo que promete el mensaje de la app ("necesitas 4
// de 5"). La nota ponderada por dificultad (abajo) se sigue mostrando
// como nota, pero YA NO es la puerta: con la regla vieja (nota5 >
// 4,0), 4 medias de 5 daban 4,0 exactos y NO pasaban, y la app le
// decía al usuario que con 4 de 5 bastaba. Cada pregunta del nivel
// sigue valiendo puntos según su dificultad para la nota:
// fácil 4, media 5, difícil 6. Acertar suma ese máximo; fallar suma 0.
//   nota5 = (puntos ganados / puntos máximos) × 5
//
// ## Vidas
// 5 vidas. Abandonar un nivel en curso (botón Salir o botón atrás del
// móvil) cuesta 1 vida. Terminar un nivel (aprobado o suspendido) no
// cuesta nada. Con 0 vidas no se puede empezar ningún nivel hasta
// mañana: cada día nuevo las vidas vuelven a 5.
//
// Las vidas son SOLO de los niveles (fix4, punto 5): el
// examen con tiempo, el quiz de la tabla periódica, el cuestionario
// del laboratorio, el repaso de errores y el examen mixto NUNCA
// quitan vidas — ni al salir ni al fallar — usan solo el sistema de
// puntos. Con 0 vidas solo se bloquean los niveles nuevos; las demás
// actividades se pueden jugar siempre.
//
// Ronda fix8: los valores de esta tabla ya no son constantes fijas:
// salen de RemoteTuning, que el servidor (settings/app) puede
// cambiar; sin valores remotos, mandan los locales de siempre.

import 'remote_tuning.dart';

/// Puntos que suma acertar una pregunta de esta dificultad (1-3).
int pointsForCorrect(int difficulty) => RemoteTuning.correctFor(difficulty);

/// Puntos que RESTA fallar una pregunta de esta dificultad (negativo).
/// El fallo pesa más que el acierto: se pierde ~1,5 veces lo ganado.
int pointsForWrong(int difficulty) => RemoteTuning.wrongFor(difficulty);

/// Puntos máximos de una pregunta de un nivel (para la nota sobre 5).
int levelMaxPoints(int difficulty) {
  switch (difficulty) {
    case 1:
      return 4;
    case 3:
      return 6;
    default:
      return 5;
  }
}

/// Nota de un nivel sobre 5, con las dificultades de sus preguntas.
/// [earned] son los puntos ganados (0 o máximo por pregunta).
/// Devuelve 0.0 si no hay preguntas. Solo es la nota que se muestra:
/// pasar ya no depende de ella (ver levelPassed).
double levelScore5(List<int> difficulties, List<bool> correct) {
  if (difficulties.isEmpty) return 0.0;
  var max = 0;
  var earned = 0;
  for (var i = 0; i < difficulties.length; i++) {
    final m = levelMaxPoints(difficulties[i]);
    max += m;
    if (i < correct.length && correct[i]) earned += m;
  }
  if (max == 0) return 0.0;
  return earned / max * 5.0;
}

/// ¿Se pasa el nivel? Acertar [RemoteTuning.passRequired] o más de 5
/// preguntas, por conteo de aciertos y sin importar la dificultad:
/// 4/5 siempre pasa (falle la fácil, la media o la difícil) y 3/5
/// nunca pasa, con el umbral local de 4. [correct] aciertos, [total]
/// preguntas del nivel.
bool levelPassed(int correct, int total) =>
    total > 0 && correct * 5 >= total * RemoteTuning.passRequired;

/// Vidas: 5 como máximo, se reponen cada día nuevo. El máximo puede
/// venir del servidor (RemoteTuning); sin él, 5, como siempre.
int get maxLives => RemoteTuning.maxLives;

/// Vidas que quedan hoy, según las guardadas y la fecha guardada.
/// Si la fecha guardada no es hoy, hay día nuevo: vidas llenas.
int livesLeftToday(int storedLives, String? storedDate, String today) {
  if (storedDate != today) return maxLives;
  return storedLives.clamp(0, maxLives);
}

/// ¿Se puede empezar un nivel hoy?
bool canStartLevel(int storedLives, String? storedDate, String today) =>
    livesLeftToday(storedLives, storedDate, today) > 0;
