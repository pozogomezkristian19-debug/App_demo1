import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';
import '../data/i18n/content_i18n.dart';
import '../data/periodic_table.dart';
import '../data/reference_tables.dart';
import '../models.dart';
import '../services/localization.dart';
import '../services/accent.dart';

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

  /// Ancho de la rejilla en modo angosto: 18 columnas × 40 px
  /// (celda mínima legible, fix3 punto 14).
  static const double _narrowGridWidth = 18 * 40.0;

  /// Altura completa de la rejilla angosta: 10 filas × (40 / 0,85)
  /// + padding 8 + 16, para que se vean TODAS las filas sin cortes.
  static const double _narrowGridHeight = 495.0;

  List<ChemicalElement> get _visible {
    return allElements.where((e) {
      if (_filterCategory != null && e.category != _filterCategory)
        return false;
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

  /// Elemento de allElements por número atómico (sin copiar datos):
  /// así las celdas de La (57) y Ac (89) de la rejilla principal
  /// usan las mismas entradas que las filas separadas de abajo.
  static ChemicalElement _elementByAtomicNumber(int z) =>
      allElements.firstWhere((e) => e.atomicNumber == z);

  /// Botones flotantes (rediseño Tabla 2026-11-12, Kristian,
  /// aprobado en mockup_tabla_botones_flotantes.png): las dos
  /// tarjetas grandes ("Quiz de la tabla periódica" y "Comparar
  /// elementos") se quitaron; quedan Comparar y Quiz como píldoras
  /// flotantes abajo a la derecha, una encima de la otra, encima
  /// del contenido, con sombrita. Comparar arriba, Quiz abajo
  /// (como en el mockup). La cabecera queda solo con buscador +
  /// chips, la rejilla sube y es lo principal, y la página se hace
  /// más corta. El quiz NO se borra como función: su botoncito
  /// abre TableQuizScreen. Como antes, con filtro activo
  /// desaparecen; al volver a "Todos" reaparecen.
  Widget _floatingActions(BuildContext context) {
    if (_filterCategory != null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _FloatingPill(
          icon: LucideIcons.arrowLeftRight,
          label: tr('compareShort'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CompareScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _FloatingPill(
          icon: LucideIcons.circleHelp,
          label: tr('quizShort'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TableQuizScreen()),
            );
          },
        ),
      ],
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
          // Sin negro: el borde es blanco suave (la celda ya es de
          // color; el blanco la define sin la línea negra fea).
          border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          // Línea bajo las pestañas (rediseño Tabla 2026-11-12,
          // Kristian): fina (1 pt) y del color de línea del tema,
          // no la línea pesada por defecto.
          dividerColor:
              isDark ? const Color(0xFF37464F) : const Color(0xFFE5E5E5),
          dividerHeight: 1,
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
    // Cabecera común (búsqueda + chips): la misma en los tres
    // modos (búsqueda, tabla normal y tabla angosta). Los chips
    // quedan justo debajo del buscador (las tarjetas se quitaron)
    // y la rejilla debajo, como contenido principal.
    final header = <Widget>[
      _searchField(),
      _chipsRow(context),
    ];
    final legend = _legend(context);
    final Widget content;
    if (searching) {
      content = Column(
        children: [
          ...header,
          Expanded(child: _searchList(context)),
          legend,
        ],
      );
    } else if (MediaQuery.sizeOf(context).width - 16 < 340) {
      // Tabla angosta (fix4, punto 1): SOLO cuando el ancho disponible
      // es realmente estrecho (< 340 dp) la rejilla mide 18 × 40 px y
      // se desplaza en horizontal. En cualquier teléfono normal la
      // tabla es la rejilla original de 18 columnas SIN scroll (como
      // en v6): el modo scroll era solo para teléfonos incompatibles
      // o angostos, no para todos. En el modo angosto la página entera
      // se desplaza en vertical y la rejilla tiene su altura completa
      // (10 filas), así se ven TODAS las filas sin cortes.
      content = SingleChildScrollView(
        child: Column(
          children: [
            ...header,
            _narrowGrid(context, grid),
            legend,
          ],
        ),
      );
    } else {
      // Modo normal (fix5, punto 3): la página ENTERA se desplaza en
      // vertical (SingleChildScrollView + Column), con la rejilla
      // COMPLETA de 10 filas dibujada entera (shrinkWrap, sin scroll
      // interno) y la leyenda debajo — exactamente como ya hace el
      // modo angosto y como era en v6 ("como estaban"). El Column con
      // Expanded anterior se comía la altura: la cabecera dejaba a la
      // rejilla solo lo que quedaba (~3,5 filas en el Redmi de
      // Kristian) y la leyenda quedaba fijada debajo. Ya no hay
      // Expanded que recorte la rejilla. Sin las tarjetas, la página
      // se hace más corta: a la leyenda se llega con menos
      // deslizamiento que antes.
      content = SingleChildScrollView(
        child: Column(
          children: [
            ...header,
            _normalGrid(context, grid),
            legend,
          ],
        ),
      );
    }
    // Botones flotantes fijos abajo a la derecha, encima del
    // contenido: no se desplazan con el scroll de la página.
    return Stack(
      children: [
        content,
        Positioned(
          right: 16,
          bottom: 16,
          child: _floatingActions(context),
        ),
      ],
    );
  }

  /// Campo de búsqueda de elementos (cabecera de la pestaña).
  Widget _searchField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      // Compacto (re-verificación Zona D, test grande 430x900):
      // padding superior 4 (antes 8); el campo mide 44 pt de alto
      // (compacto, rediseño Tabla) y el tap no cambia.
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: TextField(
        decoration: InputDecoration(
          labelText: tr('searchHint'),
          // Lupa pequeña (fix2, item 9): el tamaño por defecto
          // (24) se veía enorme en la cajita de búsqueda.
          prefixIcon: const LucideIcon(LucideIcons.search, size: 18),
          // Campo de texto Duolingo §1.6: radio 16, borde 2 pt
          // #E5E5E5 en claro (#37464F en oscuro, auditoría 7.2);
          // al enfocar, borde #5EEAD4. Sin sombra. Compacto
          // (rediseño Tabla 2026-11-12, Kristian): la barra se veía
          // muy grande; padding vertical 10 y alto mínimo 44.
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: const BoxConstraints(minHeight: 44),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color:
                    isDark ? const Color(0xFF37464F) : const Color(0xFFE5E5E5),
                width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color:
                    isDark ? const Color(0xFF37464F) : const Color(0xFFE5E5E5),
                width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF5EEAD4), width: 2),
          ),
        ),
        onChanged: (v) => setState(() => _query = v.trim()),
      ),
    );
  }

  /// Fila de chips de filtro con desplazamiento horizontal y un
  /// degradado claro en el borde derecho (64 px): el chip cortado
  /// se lee como "hay más" y no como un error.
  Widget _chipsRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Chips según el tema (auditoría 7.2): en blanco fijo se veían
    // como píldoras claras en oscuro, con el texto oscuro del tema
    // claro encima. Seleccionado: teal + blanco en los dos temas.
    final chipBg = isDark ? scheme.surfaceContainerHighest : Colors.white;
    final chipInk = isDark ? scheme.onSurface : BrandColors.ink;
    // Sin borde en oscuro (Kristian, 2026-11-13): el relleno
    // del chip lo distingue del fondo; en claro queda el gris suave.
    final chipEdge = isDark ? Colors.transparent : const Color(0xFFE8E8E8);
    return // Fila de chips con desplazamiento horizontal (fix3, punto 8):
        // "Alcalinotérreo" quedaba cortado a mitad en el borde derecho
        // y parecía un error. El degradado del borde derecho hace que
        // el chip cortado se lea como "hay más", y el respiro final
        // deja que el último chip entre entero en la vista. El fade
        // es solo visual (IgnorePointer): no tapa los toques.
        Stack(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Compacto (re-verificación Zona D, test grande 430x900):
          // vertical 4 (antes 6); los chips no cambian de tamaño.
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              ChoiceChip(
                label: Text(tr('allWord'),
                    style: TextStyle(
                        color: _filterCategory == null ? Colors.white : chipInk,
                        fontWeight: FontWeight.w700)),
                selected: _filterCategory == null,
                onSelected: (_) => setState(() => _filterCategory = null),
                // Píldora 3D (ronda de diseño 7.0): teal + texto
                // blanco + sombra tintada al seleccionar; blanco con
                // sombra suave y borde gris claro sin seleccionar.
                // Se mantiene ChoiceChip (los tests lo buscan por tipo);
                // el degradado no cabe en un chip de Material.
                selectedColor: const Color(0xFF00C2A8),
                backgroundColor: chipBg,
                elevation: 3,
                shadowColor: const Color(0xFF00C2A8).withValues(alpha: 0.35),
                selectedShadowColor:
                    const Color(0xFF00C2A8).withValues(alpha: 0.45),
                checkmarkColor: Colors.white,
                side: BorderSide(
                    color: _filterCategory == null
                        ? const Color(0xFF00A18D)
                        : chipEdge),
                shape: const StadiumBorder(),
              ),
              for (var i = 0; i < categoryNames.length; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(categoryNames[i],
                        style: TextStyle(
                            color:
                                _filterCategory == i ? Colors.white : chipInk,
                            fontWeight: FontWeight.w700)),
                    selected: _filterCategory == i,
                    onSelected: (_) => setState(() =>
                        _filterCategory = _filterCategory == i ? null : i),
                    selectedColor: const Color(0xFF00C2A8),
                    backgroundColor: chipBg,
                    elevation: 3,
                    shadowColor:
                        const Color(0xFF00C2A8).withValues(alpha: 0.35),
                    selectedShadowColor:
                        const Color(0xFF00C2A8).withValues(alpha: 0.45),
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                        color: _filterCategory == i
                            ? const Color(0xFF00A18D)
                            : chipEdge),
                    shape: const StadiumBorder(),
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
              width: 64,
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
    );
  }

  /// Lista de resultados al buscar o filtrar por categoría.
  Widget _searchList(BuildContext context) {
    return ListView(
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
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            title: Text(localizedElementName(e)),
            subtitle: Text(
                'Z = ${e.atomicNumber} · ${tr('massWord')} ${e.mass} · ${localizedCategoryName(e.category)}'),
            onTap: () => _showDetail(e),
          ),
      ],
    );
  }

  /// Rejilla de 18 columnas con el ancho dado. Las celdas llevan
  /// su elemento; en la rejilla principal los huecos de los bloques
  /// f (fila 6, columna 3 y fila 7, columna 3) son las celdas
  /// REALES de Lantano (La, 57) y Actinio (Ac, 89), buscadas por
  /// número atómico en allElements — tocables y con su hoja de
  /// detalle como cualquier elemento. Las dos filas separadas de
  /// abajo (lantánidos/actínidos, filas 9 y 10) no se tocan: La y
  /// Ac aparecen también allí, como en la tabla clásica. En modo
  /// normal (fix5, punto 3) se dibuja ENTERA dentro de la página con
  /// scroll: shrinkWrap + NeverScrollableScrollPhysics (sin scroll
  /// interno). En modo angosto se deja el comportamiento de siempre
  /// (rejilla con su propia altura fija, _narrowGridHeight, y
  /// aspecto 0,85).
  Widget _gridView(
    List<ChemicalElement?> grid,
    double width, {
    bool shrinkWrap = false,
    ScrollPhysics? physics,
    double childAspectRatio = 0.85,
  }) {
    return SizedBox(
      width: width,
      child: GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 18,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: grid.length,
        itemBuilder: (context, i) {
          // Lantano (La, 57) y Actinio (Ac, 89) en la rejilla
          // principal: celdas de elemento REALES, buscadas por
          // número atómico en allElements (sin copiar los datos),
          // con el mismo estilo y la misma hoja de detalle que
          // cualquier elemento. Las filas 9 y 10 de abajo (bloques
          // f) las dibuja _cell desde la rejilla y no se tocan.
          if (i == (6 - 1) * 18 + (3 - 1)) {
            return _cell(context, _elementByAtomicNumber(57));
          }
          if (i == (7 - 1) * 18 + (3 - 1)) {
            return _cell(context, _elementByAtomicNumber(89));
          }
          return _cell(context, grid[i]);
        },
      ),
    );
  }

  /// Tabla completa SIN scroll propio (teléfono normal): la rejilla
  /// original de 18 columnas, como en v6, dibujada ENTERA dentro de
  /// la página con scroll vertical (fix5, punto 3): shrinkWrap y
  /// sin scroll interno, así ninguna fila queda recortada.
  ///
  /// Afinado por tamaño (fix5, punto 3): la altura de celda se
  /// adapta al ancho. La celda siempre mide ancho/18; su alto es
  /// ancho/aspecto con aspecto = anchoCelda/22,5, entre 0,85 y
  /// 1,02: en teléfonos chicos la celda queda alta (0,85, como
  /// siempre, para que el número y el símbolo quepan legibles y se
  /// puedan tocar) y en los grandes la celda, más ancha, no
  /// necesita ser tan alta — la altura de celda se queda en
  /// ~22,5 dp en todos los tamaños y la rejilla entera ocupa
  /// ~225 dp de alto, así en un teléfono grande (430x900) caben
  /// la rejilla completa Y la leyenda sin desplazar. El padding
  /// inferior es 8 (la leyenda ya trae 12 arriba).
  Widget _normalGrid(BuildContext context, List<ChemicalElement?> grid) {
    final available = MediaQuery.sizeOf(context).width - 16;
    final cellW = available / 18;
    final aspect = (cellW / 22.5).clamp(0.85, 1.02).toDouble();
    return Padding(
      // Compacto (re-verificación Zona D, test grande 430x900):
      // vertical 4 (antes 8); la rejilla no cambia de geometría.
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: _gridView(
        grid,
        available,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: aspect,
      ),
    );
  }

  /// Tabla angosta (< 340 dp): rejilla de 18 × 40 px con scroll
  /// horizontal y su degradado (64 px) en el borde derecho. La altura
  /// es la completa de las 10 filas (_narrowGridHeight): la página
  /// entera se desplaza en vertical y ninguna fila queda cortada.
  Widget _narrowGrid(BuildContext context, List<ChemicalElement?> grid) {
    return SizedBox(
      height: _narrowGridHeight,
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: _gridView(grid, _narrowGridWidth),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                key: const Key('gridScrollFade'),
                width: 64,
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
    );
  }

  /// Leyenda de categorías (solo sin filtro activo, ronda #2): si
  /// hay un filtro, no se muestra nada.
  Widget _legend(BuildContext context) {
    if (_filterCategory != null) return const SizedBox.shrink();
    return // filtro de categoría activo no se muestra. En flujo normal,
        // debajo de la rejilla/lista — sin Stack ni Positioned, sin
        // flotar ni tapar nada — con padding inferior para que la
        // línea "118 elementos" no quede pegada al borde ni la tape
        // la barra de navegación inferior.
        //
        // Compacta (re-verificación Zona D, test grande 430x900):
        // con Nunito la leyenda creció ~90 dp y la línea final
        // quedaba 89,5 dp fuera del viewport. Ajuste mínimo de
        // espaciados: huecos 4 (antes 8), padding inferior 4
        // (antes 8), runSpacing 3 (antes 8) y etiquetas a 13 pt
        // (antes el cuerpo por defecto), para que el Wrap ocupe
        // menos filas. La primera pasada ahorró ~91 dp y quedaban
        // 2,5 dp fuera: el runSpacing 3 (antes 4) los compensa.
        // El tap de cada categoría no cambia.
        Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('legendWord'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 3,
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
                      Text(
                        localizedCategoryName(i),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
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
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF37464F)
                    : const Color(0xFFE5E5E5)),
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
              title: Text('${i + 1}. ${_activityName(metalActivitySeries[i])}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  localizedReferenceString(metalActivitySeries[i].reaction)),
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
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

/// Píldora flotante de la Tabla (44 pt): icono + texto corto en
/// horizontal, radio píldora. Como en el mockup aprobado por
/// Kristian: cara del tema (blanca en claro, oscura en oscuro),
/// borde 2 pt teal, icono y texto teal, con sombrita suave (la
/// sombrita es la del mockup aprobado; sin degradado, sin brillo).
class _FloatingPill extends StatelessWidget {
  const _FloatingPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final LucideIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = scheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppAccent.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LucideIcon(icon, size: 20, color: accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
