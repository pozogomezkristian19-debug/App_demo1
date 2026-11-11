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
// Pregunta del día: acertar suma el valor de la pregunta; fallar RESTA
// EL DOBLE de su valor (fácil −6, media −10, difícil −16).
//
// ## Pasar de nivel por puntos (sustituye al viejo 4/5 correctas)
// Cada pregunta del nivel vale puntos según su dificultad:
// fácil 4, media 5, difícil 6. Acertar suma ese máximo; fallar suma 0.
//   nota5 = (puntos ganados / puntos máximos) × 5
// Se pasa el nivel si nota5 > 4,0 (más del 80 % del máximo ponderado).
// Por eso fallar una pregunta fácil se puede compensar (vale poco) y
// fallar una difícil casi siempre suspende: como en un examen real, las
// preguntas difíciles pesan más. Con 5 preguntas medias, 4 aciertos dan
// 4,0 exactos y NO pasan: hay que sacar más de 4.
//
// ## Vidas
// 5 vidas. Abandonar un nivel en curso (botón Salir o botón atrás del
// móvil) cuesta 1 vida. Terminar un nivel (aprobado o suspendido) no
// cuesta nada. Con 0 vidas no se puede empezar ningún nivel hasta
// mañana: cada día nuevo las vidas vuelven a 5.
//
// Las vidas son SOLO de los niveles (fix4, punto 5): el Reto, el
// examen con tiempo, el quiz de la tabla periódica, el cuestionario
// del laboratorio, el repaso de errores y el examen mixto NUNCA
// quitan vidas — ni al salir ni al fallar — usan solo el sistema de
// puntos. Con 0 vidas solo se bloquean los niveles nuevos; las demás
// actividades se pueden jugar siempre.

/// Puntos que suma acertar una pregunta de esta dificultad (1-3).
int pointsForCorrect(int difficulty) {
  switch (difficulty) {
    case 1:
      return 3;
    case 3:
      return 8;
    default:
      return 5;
  }
}

/// Puntos que RESTA fallar una pregunta de esta dificultad (negativo).
/// El fallo pesa más que el acierto: se pierde ~1,5 veces lo ganado.
int pointsForWrong(int difficulty) {
  switch (difficulty) {
    case 1:
      return -5;
    case 3:
      return -12;
    default:
      return -8;
  }
}

/// Puntos de la pregunta del día: acertar suma el valor; fallar resta
/// EL DOBLE.
int qotdPoints(int difficulty, bool correct) {
  final v = pointsForCorrect(difficulty);
  return correct ? v : -2 * v;
}

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
/// Devuelve 0.0 si no hay preguntas.
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

/// ¿La nota sobre 5 aprueba el nivel? Tiene que ser MÁS de 4.
bool levelPassed(double score5) => score5 > 4.0;

/// Vidas: 5 como máximo, se reponen cada día nuevo.
const int maxLives = 5;

/// Vidas que quedan hoy, según las guardadas y la fecha guardada.
/// Si la fecha guardada no es hoy, hay día nuevo: vidas llenas.
int livesLeftToday(int storedLives, String? storedDate, String today) {
  if (storedDate != today) return maxLives;
  return storedLives.clamp(0, maxLives);
}

/// ¿Se puede empezar un nivel hoy?
bool canStartLevel(int storedLives, String? storedDate, String today) =>
    livesLeftToday(storedLives, storedDate, today) > 0;
