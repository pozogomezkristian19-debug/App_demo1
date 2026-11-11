// Tablas de referencia estándar: serie de actividad (reactividad) de
// los metales y tabla de solubilidad de sales comunes.
//
// Serie de actividad: orden estándar de los libros de texto
// (K > Na > Li > Ca > Mg > Al > Zn > Fe > Ni > Sn > Pb > H > Cu > Ag >
// Hg > Pt > Au). Un metal desplaza de su compuesto a cualquier metal
// que esté por debajo de él en la serie.
//
// Solubilidad: reglas estándar (nitratos, acetatos, sales de metales
// alcalinos y de amonio siempre solubles; haluros insolubles solo con
// Ag+, Pb2+ y Hg2(2+); sulfatos insolubles solo con Ba2+, Sr2+, Pb2+
// y poco solubles con Ca2+ y Ag+; carbonatos, fosfatos e hidróxidos
// insolubles salvo alcalinos y amonio; sulfuros insolubles salvo
// alcalinos, amonio y alcalinotérreos).

/// Una entrada de la serie de actividad de los metales.
class ActivityEntry {
  const ActivityEntry({
    required this.symbol,
    required this.name,
    required this.reaction,
  });
  final String symbol;
  final String name;
  final String reaction;
}

/// Serie de actividad (reactividad) de los metales, de mayor a menor.
const List<ActivityEntry> metalActivitySeries = [
  ActivityEntry(
    symbol: 'K',
    name: 'Potasio',
    reaction: 'Reacciona violentamente con agua fría',
  ),
  ActivityEntry(
    symbol: 'Na',
    name: 'Sodio',
    reaction: 'Reacciona violentamente con agua fría',
  ),
  ActivityEntry(
    symbol: 'Li',
    name: 'Litio',
    reaction: 'Reacciona con agua fría',
  ),
  ActivityEntry(
    symbol: 'Ca',
    name: 'Calcio',
    reaction: 'Reacciona con agua fría',
  ),
  ActivityEntry(
    symbol: 'Mg',
    name: 'Magnesio',
    reaction: 'Reacciona con agua caliente y con vapor',
  ),
  ActivityEntry(
    symbol: 'Al',
    name: 'Aluminio',
    reaction: 'Reacciona con vapor de agua y con ácidos diluidos',
  ),
  ActivityEntry(
    symbol: 'Zn',
    name: 'Zinc',
    reaction: 'Reacciona con vapor de agua y con ácidos diluidos',
  ),
  ActivityEntry(
    symbol: 'Fe',
    name: 'Hierro',
    reaction: 'Reacciona con vapor de agua y con ácidos diluidos',
  ),
  ActivityEntry(
    symbol: 'Ni',
    name: 'Níquel',
    reaction: 'Reacciona con ácidos diluidos',
  ),
  ActivityEntry(
    symbol: 'Sn',
    name: 'Estaño',
    reaction: 'Reacciona con ácidos diluidos',
  ),
  ActivityEntry(
    symbol: 'Pb',
    name: 'Plomo',
    reaction: 'Reacciona con ácidos diluidos (lentamente)',
  ),
  ActivityEntry(
    symbol: 'H',
    name: 'Hidrógeno (referencia)',
    reaction: 'Límite: los metales de arriba desplazan al H de los ácidos',
  ),
  ActivityEntry(
    symbol: 'Cu',
    name: 'Cobre',
    reaction: 'No reacciona con agua ni con ácidos diluidos',
  ),
  ActivityEntry(
    symbol: 'Ag',
    name: 'Plata',
    reaction: 'No reacciona con agua ni con ácidos diluidos',
  ),
  ActivityEntry(
    symbol: 'Hg',
    name: 'Mercurio',
    reaction: 'No reacciona con agua ni con ácidos diluidos',
  ),
  ActivityEntry(
    symbol: 'Pt',
    name: 'Platino',
    reaction: 'No reacciona con agua ni con ácidos diluidos',
  ),
  ActivityEntry(
    symbol: 'Au',
    name: 'Oro',
    reaction: 'No reacciona con agua ni con ácidos diluidos',
  ),
];

/// Grupos de cationes de las columnas de la tabla de solubilidad.
const List<String> solubilityColumns = [
  'Alcalinos\n(Na⁺, K⁺) y NH₄⁺',
  'Ca²⁺, Sr²⁺\ny Ba²⁺',
  'Ag⁺',
  'Pb²⁺',
  'Otros\nmetales',
];

/// Una fila de la tabla de solubilidad: anión + solubilidad por columna.
/// 'S' = soluble, 'I' = insoluble, 'PS' = poco soluble.
class SolubilityRow {
  const SolubilityRow({
    required this.anion,
    required this.name,
    required this.cells,
  });
  final String anion;
  final String name;
  final List<String> cells;
}

const List<SolubilityRow> solubilityTable = [
  SolubilityRow(
    anion: 'NO₃⁻',
    name: 'Nitratos',
    cells: ['S', 'S', 'S', 'S', 'S'],
  ),
  SolubilityRow(
    anion: 'CH₃COO⁻',
    name: 'Acetatos',
    cells: ['S', 'S', 'S', 'S', 'S'],
  ),
  SolubilityRow(
    anion: 'Cl⁻',
    name: 'Cloruros',
    cells: ['S', 'S', 'I', 'PS', 'S'],
  ),
  SolubilityRow(
    anion: 'Br⁻',
    name: 'Bromuros',
    cells: ['S', 'S', 'I', 'PS', 'S'],
  ),
  SolubilityRow(
    anion: 'I⁻',
    name: 'Yoduros',
    cells: ['S', 'S', 'I', 'I', 'S'],
  ),
  SolubilityRow(
    anion: 'SO₄²⁻',
    name: 'Sulfatos',
    cells: ['S', 'I', 'PS', 'I', 'S'],
  ),
  SolubilityRow(
    anion: 'CO₃²⁻',
    name: 'Carbonatos',
    cells: ['S', 'I', 'I', 'I', 'I'],
  ),
  SolubilityRow(
    anion: 'PO₄³⁻',
    name: 'Fosfatos',
    cells: ['S', 'I', 'I', 'I', 'I'],
  ),
  SolubilityRow(
    anion: 'OH⁻',
    name: 'Hidróxidos',
    cells: ['S', 'PS', 'I', 'I', 'I'],
  ),
  SolubilityRow(
    anion: 'S²⁻',
    name: 'Sulfuros',
    cells: ['S', 'S', 'I', 'I', 'I'],
  ),
];

/// Reglas de solubilidad (texto, para mostrar debajo de la tabla).
const List<String> solubilityRules = [
  'Nitratos, acetatos y sales de metales alcalinos y de amonio: siempre solubles.',
  'Haluros (Cl⁻, Br⁻, I⁻): solubles, excepto con Ag⁺, Pb²⁺ y Hg₂²⁺.',
  'Sulfatos (SO₄²⁻): solubles, excepto con Ba²⁺, Sr²⁺ y Pb²⁺; poco solubles con Ca²⁺ y Ag⁺.',
  'Carbonatos (CO₃²⁻) y fosfatos (PO₄³⁻): insolubles, excepto con alcalinos y NH₄⁺.',
  'Hidróxidos (OH⁻): insolubles, excepto con alcalinos y NH₄⁺; poco solubles con Ca²⁺, Sr²⁺ y Ba²⁺.',
  'Sulfuros (S²⁻): insolubles, excepto con alcalinos, NH₄⁺ y alcalinotérreos.',
];
