// Tipos compartidos para las traducciones de contenido de Melli-Qui (v6).
//
// Cada idioma tiene su propio archivo `content_<código>.dart` que exporta
// mapas con estas clases. Reglas para todos los idiomas:
// - Las opciones de cada pregunta van en el MISMO orden que en español:
//   la respuesta correcta no cambia de sitio.
// - Las fórmulas químicas (H₂SO₄, CO₂, CH₃COOH…), los números, las
//   unidades y los símbolos NO se traducen: se copian tal cual.
// - Los nombres de elementos químicos se traducen al nombre habitual del
//   idioma (Hydrogen, Hydrogène, Idrogeno, Hidrogênio, Водород…).
// - La química debe ser correcta: nada de traducciones literales que
//   cambien el sentido (p. ej. "reactivo limitante" = limiting reactant,
//   no "reagent limited").

/// Una pregunta del banco traducida (pregunta, 4 opciones en orden,
/// explicación).
class TranslatedQuestion {
  const TranslatedQuestion({
    required this.question,
    required this.options,
    required this.explanation,
  });
  final String question;
  final List<String> options;
  final String explanation;
}

/// Una fórmula de un tema traducida (la expresión NO se traduce).
class TranslatedFormula {
  const TranslatedFormula({
    required this.name,
    required this.expr,
    this.note,
  });
  final String name;
  final String expr;
  final String? note;
}

/// Un tema de estudio traducido (Aprender y ramas).
class TranslatedTopic {
  const TranslatedTopic({
    required this.title,
    required this.level,
    required this.summary,
    required this.formulas,
    required this.exampleTitle,
    required this.exampleSteps,
    required this.exampleAnswer,
    required this.errors,
    required this.tip,
    this.molecules,
  });
  final String title;
  final String level;
  final List<String> summary;
  final List<TranslatedFormula> formulas;
  final String exampleTitle;
  final List<String> exampleSteps;
  final String exampleAnswer;
  final List<String> errors;
  final String tip;
  final List<String>? molecules;
}

/// Título y descripción de un solucionador (entrada de la lista).
class TranslatedSolver {
  const TranslatedSolver({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

/// Un término del glosario traducido.
class TranslatedGlossaryTerm {
  const TranslatedGlossaryTerm({required this.term, required this.definition});
  final String term;
  final String definition;
}
