// Índice de búsqueda global (v5): temas, solucionadores, elementos,
// fórmulas, glosario y pantallas de la app. La búsqueda compara sin
// tildes (ver `fold` en extra_content.dart).

import '../data/extra_content.dart';
import '../data/periodic_table.dart';
import '../data/questions.dart';
import '../data/topics.dart';
import '../screens/resolver_screen.dart';
import 'i18n/content_i18n.dart';

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
  ('branches', 'Ramas de la química', 'Orgánica, Inorgánica, Analítica y Química física', 'hub'),
  ('lab', 'Laboratorio', 'Seguridad, material, cuestionario y simulador', 'biotech'),
  ('stats', 'Mis estadísticas', 'Racha, niveles, logros y progreso', 'bar_chart'),
  ('timed', 'Examen con tiempo', 'Elige el tiempo y responde todo lo que puedas', 'timer'),
  ('leaderboard', 'Tabla de posiciones', 'Los mejores de Quemia', 'leaderboard'),
  ('friends', 'Amigos', 'Tus amigos y sus duelos', 'friends'),
  ('tournaments', 'Torneos', 'Compite y gana puntos', 'tournament'),
  ('shop', 'Tienda', 'Gasta tus puntos en cosméticos', 'shop'),
  ('groups', 'Grupos de estudio', 'Estudia con tu grupo', 'groups'),
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
  ('theme', 'Tema', 'Color y modo claro u oscuro', 'style'),
  ('notifications', 'Notificaciones', 'Avisos y centro de notificaciones', 'alarm'),
  ('howToPlay', '¿Cómo se juega?', 'Las reglas del juego', 'quiz'),
  ('tips', 'Tips', 'Consejos para estudiar y rendir mejor', 'book'),
  ('tableQuiz', 'Quiz de la tabla periódica', 'Adivina el elemento por su símbolo', 'quiz'),
  ('labSim', 'Simulador de laboratorio', 'Mezcla ácido y base y mira el color', 'science'),
  ('review', 'Repasar mis errores', 'Las preguntas que fallaste', 'replay'),
];

List<SearchEntry> buildSearchEntries() {
  final entries = <SearchEntry>[];
  // Temas de estudio (Aprender + ramas).
  for (final t in [...topics, ...branchTopics]) {
    final lt = localizedTopic(t);
    entries.add(SearchEntry(
      kind: 'topic',
      title: lt.title,
      subtitle: 'Tema · ${lt.level}',
      icon: 'menu_book',
      target: t.slug,
    ));
  }
  // Temas de niveles (camino de Niveles).
  for (final slug in topicNames.keys) {
    entries.add(SearchEntry(
      kind: 'levels',
      title: 'Niveles: ${localizedTopicName(slug)}',
      subtitle: 'Camino de niveles',
      icon: 'route',
      target: slug,
    ));
  }
  // Solucionadores.
  for (final s in solverEntries) {
    final ls = localizedSolver(s.id);
    entries.add(SearchEntry(
      kind: 'solver',
      title: ls?.title ?? s.title,
      subtitle: 'Solucionador · ${localizedSolverGroup(s.group)}',
      icon: 'calculate',
      target: s.title,
    ));
  }
  // Elementos.
  for (final e in allElements) {
    entries.add(SearchEntry(
      kind: 'element',
      title: localizedElementName(e),
      subtitle:
          '${e.symbol} · Z = ${e.atomicNumber} · ${localizedCategoryName(e.category)}',
      icon: 'grid_view',
      target: '${e.atomicNumber}',
    ));
  }
  // Fórmulas del formulario.
  for (final f in formulary) {
    entries.add(SearchEntry(
      kind: 'formula',
      title: localizedFormularyName(f['name'] ?? ''),
      subtitle:
          '${f['expr'] ?? ''} · ${localizedFormularyGroup(f['group'] ?? '')}',
      icon: 'functions',
      target: f['name'] ?? '',
    ));
  }
  // Glosario.
  for (final g in localizedGlossary()) {
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
