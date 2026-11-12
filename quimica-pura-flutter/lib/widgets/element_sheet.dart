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
void showElementSheet(BuildContext context, ChemicalElement e) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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
        // Degradado suave superficie → tinte teal + sombra suave:
        // la hoja ya no es un plano.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface,
            scheme.primary.withValues(alpha: 0.06),
          ],
        ),
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
