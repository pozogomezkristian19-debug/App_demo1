// Índice de búsqueda global (v5): temas, solucionadores, elementos,
// fórmulas, glosario y pantallas de la app. La búsqueda compara sin
// tildes (ver `fold` en extra_content.dart).

import '../data/extra_content.dart';
import '../data/periodic_table.dart';
import '../data/questions.dart';
import '../data/topics.dart';
import '../screens/resolver_screen.dart';

/// Una entrada buscable.
class SearchEntry {
  const SearchEntry({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.target,
  });

  /// 'topic' | 'solver' | 'element' | 'formula' | 'glossary' | 'screen' | 'levels'
  final String kind;
  final String title;
  final String subtitle;

  /// Nombre del icono (se resuelve en la pantalla de búsqueda).
  final String icon;

  /// Para 'topic': slug del tema. Para 'solver': título exacto del
  /// solucionador. Para 'element': número atómico como texto. Para
  /// 'screen': clave de la pantalla. Para 'levels': slug del tema.
  final String target;
}

/// Pantallas de la app que se pueden abrir desde la búsqueda o el menú.
const List<(String, String, String, String)> appScreens = [
  // (clave, título, subtítulo, icono)
  ('branches', 'Ramas de la química', 'Orgánica, Inorgánica, Analítica y Fisicoquímica', 'hub'),
  ('lab', 'Laboratorio', 'Seguridad, material, cuestionario y simulador', 'biotech'),
  ('stats', 'Mis estadísticas', 'Racha, niveles, logros y progreso', 'bar_chart'),
  ('flashcards', 'Tarjetas de memoria', 'Repasar fórmulas y elementos', 'style'),
  ('timed', 'Examen con tiempo', 'Simulacro de 24 preguntas en 30 minutos', 'timer'),
  ('challenge', 'Reto', 'Duelo de dos jugadores en el mismo teléfono', 'sports_esports'),
  ('glossary', 'Glosario', 'Términos de química explicados', 'book'),
  ('compare', 'Comparar elementos', 'Dos elementos lado a lado', 'compare_arrows'),
  ('notes', 'Mi cuaderno', 'Tus notas por tema', 'note'),
  ('tables', 'Tablas de referencia', 'Actividad de los metales y solubilidad', 'table_chart'),
  ('formulas', 'Formulario rápido', 'Todas las fórmulas en una pantalla', 'functions'),
  ('constants', 'Constantes y conversiones', 'Constantes y conversor de unidades', 'swap_horiz'),
  ('favorites', 'Favoritos', 'Elementos, temas y fórmulas guardados', 'star'),
  ('reminder', 'Recordatorio de estudio', 'Aviso diario para practicar', 'alarm'),
  ('version', 'Cambiar versión', 'Bachillerato o Universidad', 'swap_horizontal_circle'),
  ('language', 'Idioma', 'Español, English, Français, Italiano, Português, Русский', 'language'),
  ('tableQuiz', 'Quiz de la tabla periódica', 'Adivina el elemento por su símbolo', 'quiz'),
  ('labSim', 'Simulador de laboratorio', 'Mezcla ácido y base y mira el color', 'science'),
  ('review', 'Repasar mis errores', 'Las preguntas que fallaste', 'replay'),
];

List<SearchEntry> buildSearchEntries() {
  final entries = <SearchEntry>[];
  // Temas de estudio (Aprender + ramas).
  for (final t in [...topics, ...branchTopics]) {
    entries.add(SearchEntry(
      kind: 'topic',
      title: t.title,
      subtitle: 'Tema · ${t.level}',
      icon: 'menu_book',
      target: t.slug,
    ));
  }
  // Temas de niveles (camino de Niveles).
  for (final slug in topicNames.keys) {
    entries.add(SearchEntry(
      kind: 'levels',
      title: 'Niveles: ${topicNames[slug]}',
      subtitle: 'Camino de niveles',
      icon: 'route',
      target: slug,
    ));
  }
  // Solucionadores.
  for (final s in solverEntries) {
    entries.add(SearchEntry(
      kind: 'solver',
      title: s.title,
      subtitle: 'Solucionador · ${s.group}',
      icon: 'calculate',
      target: s.title,
    ));
  }
  // Elementos.
  for (final e in allElements) {
    entries.add(SearchEntry(
      kind: 'element',
      title: e.name,
      subtitle: '${e.symbol} · Z = ${e.atomicNumber} · ${categoryNames[e.category]}',
      icon: 'grid_view',
      target: '${e.atomicNumber}',
    ));
  }
  // Fórmulas del formulario.
  for (final f in formulary) {
    entries.add(SearchEntry(
      kind: 'formula',
      title: f['name'] ?? '',
      subtitle: '${f['expr'] ?? ''} · ${f['group'] ?? ''}',
      icon: 'functions',
      target: f['name'] ?? '',
    ));
  }
  // Glosario.
  for (final g in glossary) {
    entries.add(SearchEntry(
      kind: 'glossary',
      title: g.term,
      subtitle: 'Glosario',
      icon: 'book',
      target: g.term,
    ));
  }
  // Pantallas de la app.
  for (final (key, title, subtitle, icon) in appScreens) {
    entries.add(SearchEntry(
      kind: 'screen',
      title: title,
      subtitle: subtitle,
      icon: icon,
      target: key,
    ));
  }
  return entries;
}

/// Busca en el índice: coincide si la consulta (sin tildes) aparece en
/// el título o el subtítulo. Devuelve como mucho 30 resultados.
List<SearchEntry> searchEntries(List<SearchEntry> all, String query) {
  final q = fold(query.trim());
  if (q.isEmpty) return <SearchEntry>[];
  final out = <SearchEntry>[];
  for (final e in all) {
    if (fold(e.title).contains(q) || fold(e.subtitle).contains(q)) {
      out.add(e);
      if (out.length >= 30) break;
    }
  }
  return out;
}
