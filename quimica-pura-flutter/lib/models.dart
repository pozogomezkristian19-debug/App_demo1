// Modelos de datos de Química Pura.

class ChemicalElement {
  const ChemicalElement({
    required this.atomicNumber,
    required this.symbol,
    required this.name,
    required this.mass,
    required this.column,
    required this.row,
    required this.category,
  });

  final int atomicNumber;
  final String symbol;
  final String name;
  final String mass; // Masa atómica estándar; entre corchetes si es sintético.
  final int column; // 1-18 en la rejilla principal.
  final int row; // 1-7 principal; 9 = lantánidos, 10 = actínidos.
  final int category; // Índice en categoryNames.

  double get numericMass {
    final cleaned = mass.replaceAll('[', '').replaceAll(']', '');
    return double.tryParse(cleaned) ?? 0;
  }

  int get period => row <= 7 ? row : (row == 9 ? 6 : 7);

  String get block {
    if (category == 8) return 'f (lantánidos)';
    if (category == 9) return 'f (actínidos)';
    if (column <= 2) return 's';
    if (column >= 13) return 'p';
    return 'd';
  }
}

class StudyTopic {
  const StudyTopic({
    required this.slug,
    required this.title,
    required this.level,
    required this.summary,
    required this.formulas,
    required this.exampleTitle,
    required this.exampleSteps,
    required this.exampleAnswer,
    required this.errors,
    required this.tip,
    this.molecules = const [],
  });

  final String slug;
  final String title;
  final String level;
  final List<String> summary;
  final List<Formula> formulas;
  final String exampleTitle;
  final List<String> exampleSteps;
  final String exampleAnswer;
  final List<String> errors;
  final String tip;

  /// Claves de moléculas para dibujar con CustomPaint (ball-and-stick),
  /// por ejemplo 'metano', 'eteno', 'benceno'. Vacío si no aplica.
  final List<String> molecules;
}

class Formula {
  const Formula({required this.name, required this.expr, required this.note});
  final String name;
  final String expr;
  final String note;
}

class QuizQuestion {
  const QuizQuestion({
    required this.topic,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    this.difficulty = 2,
    this.numericAnswer,
    this.numericUnit,
  });

  final String topic; // slug del tema, o "tabla" / "enlace" / "atomos"
  final String question;
  final List<String> options; // 4 opciones
  final int answer; // índice de la correcta en options
  final String explanation;

  /// Dificultad 1 (fácil), 2 (media) o 3 (difícil). Manda en los
  /// puntos que vale la pregunta y en la nota del nivel (ver points.dart).
  final int difficulty;

  /// Respuesta numérica exacta (solo en preguntas de cálculo generadas,
  /// ver question_generator.dart): si no es null, la pregunta se
  /// contesta con el teclado numérico en vez de con las 4 opciones
  /// (ver widgets/numeric_keypad.dart y services/numeric_answer.dart).
  /// Las preguntas del banco y las conceptuales generadas lo dejan null
  /// y siguen con opciones.
  final double? numericAnswer;

  /// Unidad que se muestra junto al campo del teclado ('mol', 'g', 'L',
  /// 'M', 'pH', 'kJ'...). Null = sin unidad (p. ej. el Qc, adimensional).
  final String? numericUnit;

  /// ¿Esta pregunta se contesta con el teclado numérico?
  bool get isNumeric => numericAnswer != null;

  QuizQuestion copyWith({
    String? topic,
    String? question,
    List<String>? options,
    int? answer,
    String? explanation,
    int? difficulty,
    double? numericAnswer,
    String? numericUnit,
  }) =>
      QuizQuestion(
        topic: topic ?? this.topic,
        question: question ?? this.question,
        options: options ?? this.options,
        answer: answer ?? this.answer,
        explanation: explanation ?? this.explanation,
        difficulty: difficulty ?? this.difficulty,
        numericAnswer: numericAnswer ?? this.numericAnswer,
        numericUnit: numericUnit ?? this.numericUnit,
      );
}

class ExamTip {
  const ExamTip({required this.title, required this.body});
  final String title;
  final String body;
}
