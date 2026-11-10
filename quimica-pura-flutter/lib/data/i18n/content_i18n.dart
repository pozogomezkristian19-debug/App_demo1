// Acceso al contenido traducido de Melli-Qui (v6).
// El contenido original vive en español (banco de preguntas, temas,
// glosario, solucionadores, elementos, constantes, formulario, consejos).
// Las traducciones viven en content_en/fr/it/pt/ru.dart. Estos
// accesores devuelven el contenido en el idioma activo de la app
// (AppLang.code) y, si es español o falta la traducción, el original.
//
// Regla importante: los ids persistentes (errores guardados, etc.) se
// construyen SIEMPRE con el texto español, para que no dependan del
// idioma activo. La traducción es solo de presentación.

import '../../models.dart';
import '../../services/localization.dart';
import '../extra_content.dart';
import '../periodic_table.dart';
import '../questions.dart';
import '../topics.dart';
import 'content_en.dart';
import 'content_fr.dart';
import 'content_it.dart';
import 'content_pt.dart';
import 'content_ru.dart';
import 'content_types.dart';
import 'generator_i18n.dart';

/// Idioma de contenido activo; null = español (contenido original).
String? get _lang => AppLang.code == 'es' ? null : AppLang.code;

/// ¿El contenido se está mostrando traducido?
bool get contentIsTranslated => _lang != null;

/// Sincroniza el idioma del generador de preguntas con el de la app.
/// Llamar al arrancar y cada vez que cambia el idioma (main.dart).
void syncGeneratorLang() {
  genLang = AppLang.code;
}

Map<int, TranslatedQuestion>? get _bank => switch (_lang) {
      'en' => bankEn,
      'fr' => bankFr,
      'it' => bankIt,
      'pt' => bankPt,
      'ru' => bankRu,
      _ => null,
    };

Map<String, TranslatedTopic>? get _topicsMap => switch (_lang) {
      'en' => topicsEn,
      'fr' => topicsFr,
      'it' => topicsIt,
      'pt' => topicsPt,
      'ru' => topicsRu,
      _ => null,
    };

Map<String, String>? get _topicNames => switch (_lang) {
      'en' => topicNamesEn,
      'fr' => topicNamesFr,
      'it' => topicNamesIt,
      'pt' => topicNamesPt,
      'ru' => topicNamesRu,
      _ => null,
    };

Map<String, TranslatedGlossaryTerm>? get _glossaryMap => switch (_lang) {
      'en' => glossaryEn,
      'fr' => glossaryFr,
      'it' => glossaryIt,
      'pt' => glossaryPt,
      'ru' => glossaryRu,
      _ => null,
    };

Map<String, TranslatedSolver>? get _solversMap => switch (_lang) {
      'en' => solversEn,
      'fr' => solversFr,
      'it' => solversIt,
      'pt' => solversPt,
      'ru' => solversRu,
      _ => null,
    };

Map<String, String>? get _solverGroups => switch (_lang) {
      'en' => solverGroupsEn,
      'fr' => solverGroupsFr,
      'it' => solverGroupsIt,
      'pt' => solverGroupsPt,
      'ru' => solverGroupsRu,
      _ => null,
    };

Map<String, String>? get _solverStrings => switch (_lang) {
      'en' => solverStringsEn,
      'fr' => solverStringsFr,
      'it' => solverStringsIt,
      'pt' => solverStringsPt,
      'ru' => solverStringsRu,
      _ => null,
    };

Map<int, String>? get _elementFactsMap => switch (_lang) {
      'en' => elementFactsEn,
      'fr' => elementFactsFr,
      'it' => elementFactsIt,
      'pt' => elementFactsPt,
      'ru' => elementFactsRu,
      _ => null,
    };

Map<int, String>? get _elementNamesMap => switch (_lang) {
      'en' => elementNamesEn,
      'fr' => elementNamesFr,
      'it' => elementNamesIt,
      'pt' => elementNamesPt,
      'ru' => elementNamesRu,
      _ => null,
    };

List<String>? get _categoryNamesList => switch (_lang) {
      'en' => categoryNamesEn,
      'fr' => categoryNamesFr,
      'it' => categoryNamesIt,
      'pt' => categoryNamesPt,
      'ru' => categoryNamesRu,
      _ => null,
    };

Map<String, String>? get _constantNotes => switch (_lang) {
      'en' => constantNotesEn,
      'fr' => constantNotesFr,
      'it' => constantNotesIt,
      'pt' => constantNotesPt,
      'ru' => constantNotesRu,
      _ => null,
    };

Map<String, String>? get _formularyNames => switch (_lang) {
      'en' => formularyNamesEn,
      'fr' => formularyNamesFr,
      'it' => formularyNamesIt,
      'pt' => formularyNamesPt,
      'ru' => formularyNamesRu,
      _ => null,
    };

Map<String, String>? get _formularyGroups => switch (_lang) {
      'en' => formularyGroupsEn,
      'fr' => formularyGroupsFr,
      'it' => formularyGroupsIt,
      'pt' => formularyGroupsPt,
      'ru' => formularyGroupsRu,
      _ => null,
    };

Map<String, String>? get _referenceStrings => switch (_lang) {
      'en' => referenceStringsEn,
      'fr' => referenceStringsFr,
      'it' => referenceStringsIt,
      'pt' => referenceStringsPt,
      'ru' => referenceStringsRu,
      _ => null,
    };

List<List<String>>? get _generalTipsList => switch (_lang) {
      'en' => generalTipsEn,
      'fr' => generalTipsFr,
      'it' => generalTipsIt,
      'pt' => generalTipsPt,
      'ru' => generalTipsRu,
      _ => null,
    };

// ---- Preguntas del banco ----

List<QuizQuestion>? _cachedBank;
String? _cachedBankLang;

/// El banco completo (175) en el idioma activo. Se cachea por idioma.
List<QuizQuestion> localizedAllQuestions() {
  final bank = _bank;
  if (bank == null) return allQuestions;
  if (_cachedBank != null && _cachedBankLang == _lang) return _cachedBank!;
  final out = <QuizQuestion>[];
  for (var i = 0; i < allQuestions.length; i++) {
    final q = allQuestions[i];
    final t = bank[i];
    out.add(t == null
        ? q
        : q.copyWith(
            question: t.question,
            options: t.options,
            explanation: t.explanation,
          ));
  }
  _cachedBank = out;
  _cachedBankLang = _lang;
  return out;
}

/// Una pregunta del banco por su índice (0-174), en el idioma activo.
QuizQuestion localizedQuestionAt(int index) =>
    localizedAllQuestions()[index];

// ---- Temas de Aprender ----

/// Un tema de estudio en el idioma activo (fórmulas incluidas).
StudyTopic localizedTopic(StudyTopic t) {
  final tr = _topicsMap?[t.slug];
  if (tr == null) return t;
  return StudyTopic(
    slug: t.slug,
    title: tr.title,
    level: tr.level,
    summary: tr.summary,
    formulas: tr.formulas
        .map((f) => Formula(name: f.name, expr: f.expr, note: f.note ?? ''))
        .toList(),
    exampleTitle: tr.exampleTitle,
    exampleSteps: tr.exampleSteps,
    exampleAnswer: tr.exampleAnswer,
    errors: tr.errors,
    tip: tr.tip,
    molecules: t.molecules,
  );
}

/// Nombre corto de un tema (para chips y títulos).
String localizedTopicName(String slug) {
  final name = _topicNames?[slug];
  if (name != null) return name;
  for (final t in topics) {
    if (t.slug == slug) return t.title;
  }
  return slug;
}

// ---- Elementos, categorías y curiosidades ----

/// Nombre de un elemento en el idioma activo.
String localizedElementName(ChemicalElement e) =>
    _elementNamesMap?[e.atomicNumber] ?? e.name;

/// Nombre de una categoría de la tabla (por índice).
String localizedCategoryName(int category) {
  final list = _categoryNamesList;
  if (list != null && category >= 0 && category < list.length) {
    return list[category];
  }
  return categoryNames[category];
}

/// Curiosidad de un elemento en el idioma activo.
String localizedElementFact(ChemicalElement e) {
  final manual = _elementFactsMap?[e.atomicNumber] ?? elementFacts[e.atomicNumber];
  if (manual != null) return manual;
  // Sin curiosidad escrita: línea de datos reales (igual en todos
  // los idiomas, con el nombre y la categoría traducidos).
  return '${localizedElementName(e)} (${e.symbol}) — Z = ${e.atomicNumber}, '
      '${localizedCategoryName(e.category).toLowerCase()}, ${e.mass} u.';
}

// ---- Glosario ----

/// Un término del glosario en el idioma activo.
GlossaryTerm localizedGlossaryTerm(GlossaryTerm g) {
  final tr = _glossaryMap?[g.term];
  if (tr == null) return g;
  return GlossaryTerm(term: tr.term, definition: tr.definition);
}

/// El glosario completo en el idioma activo.
List<GlossaryTerm> localizedGlossary() =>
    glossary.map(localizedGlossaryTerm).toList();

// ---- Solucionadores ----

/// Título y subtítulo traducidos de un solucionador (por su id).
TranslatedSolver? localizedSolver(String id) => _solversMap?[id];

/// Nombre de un grupo de solucionadores.
String localizedSolverGroup(String group) =>
    _solverGroups?[group] ?? group;

/// Cadena de texto de un solucionador (etiquetas, resultados).
/// Si no está en el mapa, se devuelve el texto español.
String localizedSolverString(String es) => _solverStrings?[es] ?? es;

// ---- Constantes, formulario y consejos ----

/// Nota de una constante (clave = texto español de la nota).
String localizedConstantNote(String note) =>
    _constantNotes?[note] ?? note;

/// Nombre de una entrada del formulario.
String localizedFormularyName(String name) =>
    _formularyNames?[name] ?? name;

/// Nombre de un grupo del formulario.
String localizedFormularyGroup(String group) =>
    _formularyGroups?[group] ?? group;

/// Cadena de las tablas de referencia (serie de actividad, solubilidad).
String localizedReferenceString(String es) =>
    _referenceStrings?[es] ?? es;

/// Los 10 consejos generales de estudio en el idioma activo.
List<ExamTip> localizedGeneralTips() {
  final list = _generalTipsList;
  if (list == null) return generalTips;
  return list
      .map((t) => ExamTip(title: t[0], body: t.length > 1 ? t[1] : ''))
      .toList();
}
