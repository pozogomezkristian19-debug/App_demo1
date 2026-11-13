// Ficha de un elemento en una ventanita que sale desde abajo
// (modal bottom sheet arrastrable). La ventanita se expande arrastrando,
// así que no lleva botón "Ver más": todos los datos se ven directamente
// y la hoja se puede estirar hasta casi toda la pantalla.
//
// Se usa desde la Tabla y desde la búsqueda. La estrellita marca el
// elemento como favorito.

import '../data/i18n/content_i18n.dart';
import 'package:flutter/material.dart';
import 'lucide_icons.dart';

import '../data/element_details.dart';
import '../models.dart';
import '../services/favorites.dart';
import '../services/localization.dart';

/// Muestra la ficha de un elemento en un bottom sheet arrastrable.
/// OPACA (Zona F, 2026-11-12): el fondo es el surface sólido del
/// tema, sin transparencia — el degradado anterior terminaba en el
/// primario al 6 % y la tabla de detrás se transparentaba y se
/// mezclaba con los datos (captura de Kristian: la Leyenda y el
/// navbar se veían a través de la hoja). La barrera del modal
/// (negro al 54 % por defecto) oscurece lo de detrás, como en los
/// bottom sheets normales.
void showElementSheet(BuildContext context, ChemicalElement e) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) =>
          ElementSheet(element: e, scrollController: scrollController),
    ),
  );
}

class ElementSheet extends StatefulWidget {
  const ElementSheet(
      {super.key, required this.element, required this.scrollController});
  final ChemicalElement element;
  final ScrollController scrollController;

  @override
  State<ElementSheet> createState() => _ElementSheetState();
}

class _ElementSheetState extends State<ElementSheet> {
  static const List<Color> catColors = [
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

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.element;
    final en = electronegativity[e.atomicNumber];
    final scheme = Theme.of(context).colorScheme;
    final favId = 'el:${e.atomicNumber}';
    final isFav = FavoritesService.instance.isFav(favId);
    return Container(
      decoration: BoxDecoration(
        // Fondo SÓLIDO del surface del tema: nada de degradado
        // (el degradado a primario al 6 % era el que dejaba ver
        // la tabla a través de la hoja). Sin transparencia: el
        // contenido de detrás no se mezcla con los datos, en
        // claro ni en oscuro.
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: catColors[e.category],
                child: Text(e.symbol,
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localizedElementName(e),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(
                        'Z = ${e.atomicNumber} · ${localizedCategoryName(e.category)}'),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Favorito',
                icon: LucideIcon(
                  LucideIcons.star,
                  filled: isFav,
                  color: isFav ? Colors.amber : null,
                  size: 28,
                ),
                onPressed: () {
                  FavoritesService.instance.toggle(favId);
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _row(tr('oxidationWord'),
              oxidationStates[e.atomicNumber] ?? tr('noData')),
          _row(tr('electronegativityWord'),
              en == null ? tr('noData') : en.toStringAsFixed(2)),
          _row(tr('configWord'), electronConfig(e.atomicNumber)),
          _row(tr('stateWord'), elementState(e.atomicNumber)),
          _row(tr('massWord'), e.mass),
          _row(tr('periodWord'), '${e.period}'),
          _row(tr('groupWord'), '${e.column}'),
          _row(tr('blockWord'), e.block),
          _row(tr('categoryWord'), localizedCategoryName(e.category)),
          const SizedBox(height: 8),
          Text(
            'Los lantánidos (57–71) y actínidos (89–103) se muestran en las dos filas separadas de abajo, como en la tabla clásica.',
            style:
                TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}
