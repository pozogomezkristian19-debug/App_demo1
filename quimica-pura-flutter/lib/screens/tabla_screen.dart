import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';
import '../data/i18n/content_i18n.dart';
import '../data/periodic_table.dart';
import '../data/reference_tables.dart';
import '../models.dart';
import '../services/localization.dart';
import '../services/nav_requests.dart';
import '../widgets/brand_logo.dart';
import '../widgets/element_sheet.dart';
import 'compare_screen.dart';
import 'table_quiz_screen.dart';

class TablaScreen extends StatefulWidget {
  const TablaScreen({super.key});
  @override
  State<TablaScreen> createState() => _TablaScreenState();
}

class _TablaScreenState extends State<TablaScreen>
    with SingleTickerProviderStateMixin {
  String _query = '';
  int? _filterCategory;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _consumeNavRequests();
  }

  @override
  void didUpdateWidget(TablaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _consumeNavRequests();
  }

  /// Consume las peticiones de la búsqueda o del menú (NavRequests).
  /// Antes solo se miraban en didChangeDependencies: si ya estabas
  /// en Tabla al pedir un filtro desde la búsqueda, no se aplicaba
  /// nada (auditoría fix2).
  void _consumeNavRequests() {
    // Peticiones de la búsqueda o del menú: filtrar por texto o abrir
    // una pestaña concreta.
    if (NavRequests.tableQuery != null) {
      _query = NavRequests.tableQuery!;
      NavRequests.tableQuery = null;
    }
    if (NavRequests.tableTab != null) {
      _tabController.animateTo(NavRequests.tableTab!);
      NavRequests.tableTab = null;
    }
  }

  static const List<Color> _catColors = [
    Color(0xFFF4A261),
    Color(0xFFE9C46A),
    Color(0xFF8ECAE6),
    Color(0xFFA7C4A0),
    Color(0xFFB8B8D0),
    Color(0xFF90E0A8),
    Color(0xFFF2CC8F),
    Color(0xFFCDB4DB),
    Color(0xFFFFB4A2),
    Color(0xFFE5989B),
  ];

  List<ChemicalElement> get _visible {
    return allElements.where((e) {
      if (_filterCategory != null && e.category != _filterCategory) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return e.name.toLowerCase().contains(q) ||
          localizedElementName(e).toLowerCase().contains(q) ||
          e.symbol.toLowerCase() == q;
    }).toList();
  }

  void _showDetail(ChemicalElement e) {
    showElementSheet(context, e);
  }

  /// Tarjeta de acción superior (quiz / comparar): mismo patrón que
  /// "Practicar de otra forma" — icono arriba en círculo tintado,
  /// texto abajo centrado. El texto NO se recorta: sin maxLines ni
  /// ellipsis, envuelve libremente ("Quiz de la tabla periódica"
  /// ocupa 3 líneas en español) y el alto mínimo de 3 líneas
  /// (51 px) más IntrinsicHeight + stretch hacen que ambas
  /// tarjetas midan exactamente lo mismo.
  Widget _actionCard(
    BuildContext context, {
    required LucideIconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        // Gris fijo en oscuro dejaba el texto (blanco) invisible:
        // superficie oscura en modo oscuro (mismo bug que Niveles).
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF122B24)
            : BrandColors.cardGray,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(27),
                  ),
                  alignment: Alignment.center,
                  child: LucideIcon(icon, size: 28, color: accent),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 51),
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, ChemicalElement? e) {
    if (e == null) return const SizedBox.shrink();
    final dimmed = _filterCategory != null && e.category != _filterCategory;
    return GestureDetector(
      onTap: () => _showDetail(e),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: dimmed
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)
              : _catColors[e.category],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
        ),
        // Solo símbolo + número atómico, con FittedBox: nada puede
        // salirse de la cuadrícula, por estrecha que sea la pantalla.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(e.atomicNumber.toString(),
                  style: const TextStyle(fontSize: 7, color: Colors.black87)),
              Text(e.symbol,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: tr('tabPeriodic')),
            Tab(text: tr('tabActivity')),
            Tab(text: tr('tabSolubility')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _periodicTab(context),
              _activityTab(context),
              _solubilityTab(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodicTab(BuildContext context) {
    // Rejilla 18 columnas × 10 filas (filas 9 y 10 = bloques f).
    final grid = List<ChemicalElement?>.filled(18 * 10, null);
    for (final e in allElements) {
      final idx = (e.row - 1) * 18 + (e.column - 1);
      if (idx >= 0 && idx < grid.length) grid[idx] = e;
    }
    final searching = _query.isNotEmpty || _filterCategory != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              labelText: tr('searchHint'),
              // Lupa pequeña (fix2, item 9): el tamaño por defecto
              // (24) se veía enorme en la cajita de búsqueda.
              prefixIcon: const LucideIcon(LucideIcons.search, size: 18),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        // Dos acciones superiores con el MISMO patrón que las tarjetas
        // "Practicar de otra forma": icono ARRIBA en un círculo
        // tintado, texto ABAJO centrado. El OutlinedButton.icon
        // anterior ponía icono y texto en horizontal y el título
        // "Quiz de la tabla periódica" se partía en 3 líneas feas
        // ("Quiz de la / tabla / periódica"). IntrinsicHeight +
        // stretch igualan ambas tarjetas a la altura de la más alta.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _actionCard(
                  context,
                  icon: LucideIcons.circleHelp,
                  label: tr('tableQuizTitle'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const TableQuizScreen()),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _actionCard(
                  context,
                  icon: LucideIcons.arrowLeftRight,
                  label: tr('compareTitle'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const CompareScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // Fila de chips con desplazamiento horizontal (fix3, punto 8):
        // "Alcalinotérreo" quedaba cortado a mitad en el borde derecho
        // y parecía un error. El degradado del borde derecho hace que
        // el chip cortado se lea como "hay más", y el respiro final
        // deja que el último chip entre entero en la vista. El fade
        // es solo visual (IgnorePointer): no tapa los toques.
        Stack(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(tr('allWord')),
                    selected: _filterCategory == null,
                    onSelected: (_) => setState(() => _filterCategory = null),
                  ),
                  for (var i = 0; i < categoryNames.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(categoryNames[i]),
                        selected: _filterCategory == i,
                        onSelected: (_) => setState(() =>
                            _filterCategory = _filterCategory == i ? null : i),
                      ),
                    ),
                  // Respiro final: el último chip puede deslizarse
                  // entero dentro de la vista sin pegarse al borde.
                  const SizedBox(width: 24),
                ],
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Theme.of(context)
                            .scaffoldBackgroundColor
                            .withValues(alpha: 0),
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: searching
              ? ListView(
                  // Padding inferior normal (24): al hacer scroll
                  // hasta el final el último elemento se ve completo.
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  children: [
                    Text('${_visible.length} ${tr('elementsWord')}',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        )),
                    for (final e in _visible)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _catColors[e.category],
                          child: Text(e.symbol,
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(localizedElementName(e)),
                        subtitle: Text(
                            'Z = ${e.atomicNumber} · ${tr('massWord')} ${e.mass} · ${localizedCategoryName(e.category)}'),
                        onTap: () => _showDetail(e),
                      ),
                  ],
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // Rejilla responsiva (fix3, punto 14; aclaración
                    // 19:28): con 18 columnas fijas, en un teléfono
                    // estrecho (~360 px) cada celda quedaba en ~20 px:
                    // símbolo ilegible y todo apretado y feo. Paso
                    // mínimo de celda 40 px (contenido ~38 px con los
                    // márgenes de 1 px). La regla final es explícita:
                    // si el ancho alcanza para celdas legibles
                    // (18 × 40 = 720 px), la tabla se muestra ENTERA
                    // sin scroll horizontal — sin SingleChildScrollView,
                    // sin física ni barra de desplazamiento — y llena
                    // todo el ancho disponible. SOLO en teléfono
                    // angosto la rejilla mide 720 px, se desplaza en
                    // horizontal y un degradado en el borde derecho
                    // avisa de que hay más tabla a la derecha. El
                    // desplazamiento vertical sigue siendo el del
                    // propio GridView.
                    const minCellPitch = 40.0;
                    const minGridWidth = 18 * minCellPitch;
                    final available = constraints.maxWidth.isFinite
                        ? constraints.maxWidth - 16
                        : minGridWidth;
                    final fits = available >= minGridWidth;
                    final gridWidth = fits ? available : minGridWidth;
                    final gridView = SizedBox(
                      width: gridWidth,
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 18,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: grid.length,
                        itemBuilder: (context, i) {
                          // Marcadores 57–71 y 89–103 en la rejilla principal.
                          if (i == (6 - 1) * 18 + (3 - 1)) {
                            return Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: _catColors[8],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('57–71',
                                    style: TextStyle(
                                        fontSize: 7,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold)),
                              ),
                            );
                          }
                          if (i == (7 - 1) * 18 + (3 - 1)) {
                            return Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: _catColors[9],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('89–103',
                                    style: TextStyle(
                                        fontSize: 7,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold)),
                              ),
                            );
                          }
                          return _cell(context, grid[i]);
                        },
                      ),
                    );
                    // Padding inferior (16): la última fila de la
                    // rejilla no queda pegada al borde inferior.
                    if (fits) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                        child: gridView,
                      );
                    }
                    return Stack(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                          child: gridView,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: Container(
                              key: const Key('gridScrollFade'),
                              width: 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Theme.of(context)
                                        .scaffoldBackgroundColor
                                        .withValues(alpha: 0),
                                    Theme.of(context)
                                        .scaffoldBackgroundColor,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        // Leyenda (fix2, item 10; fix3 punto 2 REVISADO): solo con
        // el filtro "Todos" (_filterCategory == null). Con cualquier
        // filtro de categoría activo no se muestra. En flujo normal,
        // debajo de la rejilla/lista — sin Stack ni Positioned, sin
        // flotar ni tapar nada — con padding inferior para que la
        // línea "118 elementos" no quede pegada al borde ni la tape
        // la barra de navegación inferior.
        if (_filterCategory == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('legendWord'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < categoryNames.length; i++)
                      InkWell(
                        onTap: () => setState(() => _filterCategory = i),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _catColors[i],
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(localizedCategoryName(i)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '118 ${tr('elementsWord')}.',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _activityTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(tr('activityIntro'),
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.8))),
        const SizedBox(height: 12),
        // Nota al principio (fix3): el hidrógeno es la referencia de
        // la serie; antes estaba al final de la lista y se perdía.
        // Aviso suave con icono, no texto gris suelto entre la intro
        // y la lista: así se lee como lo que es, la clave de la serie.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LucideIcon(
                LucideIcons.info,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('activityNote'),
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.85)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < metalActivitySeries.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: i < 11
                    ? Colors.teal.withValues(alpha: 0.18)
                    : Colors.grey.withValues(alpha: 0.25),
                child: Text(
                  metalActivitySeries[i].symbol,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              title: Text(
                  '${i + 1}. ${_activityName(metalActivitySeries[i])}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(localizedReferenceString(
                  metalActivitySeries[i].reaction)),
            ),
          ),
      ],
    );
  }

  Widget _solubilityTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color cellColor(String v) {
      switch (v) {
        case 'S':
          return Colors.green.withValues(alpha: 0.25);
        case 'I':
          return Colors.red.withValues(alpha: 0.18);
        default:
          return Colors.amber.withValues(alpha: 0.30);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(tr('solubilityIntro'),
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.8))),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 56,
            dataRowMinHeight: 40,
            columns: [
              const DataColumn(label: Text('Anión')),
              for (final c in solubilityColumns)
                DataColumn(
                    label: Text(localizedReferenceString(c),
                        textAlign: TextAlign.center)),
            ],
            rows: [
              for (final row in solubilityTable)
                DataRow(
                  cells: [
                    DataCell(Text(
                        '${row.anion}\n${localizedReferenceString(row.name)}',
                        style: const TextStyle(fontSize: 12))),
                    for (final v in row.cells)
                      DataCell(
                        Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cellColor(v),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(v,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Reglas',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final rule in solubilityRules)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(rule)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Nombre del metal en el idioma activo: la serie guarda el nombre en
/// español; se resuelve el elemento por su símbolo.
String _activityName(ActivityEntry a) {
  final el = allElements.where((e) => e.symbol == a.symbol).firstOrNull;
  return el == null ? a.name : localizedElementName(el);
}
