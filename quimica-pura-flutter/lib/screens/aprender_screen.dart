import 'package:flutter/material.dart';
import '../services/accent.dart';
import '../widgets/lucide_icons.dart';
import '../data/i18n/content_i18n.dart';
import '../data/topics.dart';
import '../services/localization.dart';
import 'glossary_screen.dart';
import 'notes_screen.dart';
import 'tips_screen.dart';
import 'topic_detail_screen.dart';

class AprenderScreen extends StatefulWidget {
  const AprenderScreen({super.key});
  @override
  State<AprenderScreen> createState() => _AprenderScreenState();
}

class _AprenderScreenState extends State<AprenderScreen> {
  @override
  Widget build(BuildContext context) {
    // Organización 6.3 (corrección de Kristian, 2026-11-11): las
    // dos píldoras con borde teal, la tarjeta "Tips de examen" y
    // el "Formulario rápido" en su propia tarjeta grande.
    // Corrección 2026-11-12 (Zona F): la lista de temas también
    // es de tarjetas — antes eran filas planas con líneas
    // divisorias rústicas y se veían feas junto al resto.
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppAccent.darkCard : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF37464F) : const Color(0xFFE5E5E5);
    final visibleTopics = topics
        .where((t) => t.slug != 'organica' && t.slug != 'laboratorio')
        .map(localizedTopic)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr('learnTitle'),
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: onSurface),
        ),
        const SizedBox(height: 6),
        Text(tr('learnIntro'),
            style: TextStyle(fontSize: 16, color: onSurface)),
        const SizedBox(height: 12),
        // Glosario y cuaderno: píldoras con borde teal (2 pt),
        // fondo transparente, icono y texto en teal y negrita.
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GlossaryScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent, width: 2),
                  foregroundColor: accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  textStyle: const TextStyle(
                      // Sin fontFamily explícita, styleFrom REEMPLAZA
                      // el labelLarge del tema y la etiqueta quedaba
                      // sin fuente (bloques en las capturas, Roboto
                      // en el teléfono): Nunito como en toda la app.
                      fontFamily: 'Nunito',
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                icon: const LucideIcon(LucideIcons.bookOpen, size: 18),
                label: Text(tr('glossaryTitle')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotesScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent, width: 2),
                  foregroundColor: accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  textStyle: const TextStyle(
                      // Sin fontFamily explícita, styleFrom REEMPLAZA
                      // el labelLarge del tema y la etiqueta quedaba
                      // sin fuente (bloques en las capturas, Roboto
                      // en el teléfono): Nunito como en toda la app.
                      fontFamily: 'Nunito',
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                icon: const LucideIcon(LucideIcons.notebookPen, size: 18),
                label: Text(tr('notesTitle')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Tips de examen: tarjeta redondeada propia, bombilla a la
        // izquierda, título + subtítulo y flecha a la derecha.
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TipsScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  LucideIcon(LucideIcons.lightbulb,
                      size: 28, color: onSurface),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('tipsExamCard'),
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: onSurface)),
                        const SizedBox(height: 2),
                        Text(tr('tipsExamSub'),
                            style: TextStyle(
                                fontSize: 15,
                                color: onSurface.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const LucideIcon(LucideIcons.chevronRight,
                      color: Color(0xFFAFAFAF)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tr('formulary'),
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: onSurface),
        ),
        const SizedBox(height: 8),
        // Formulario rápido: una sola tarjeta grande con las
        // fórmulas dentro (etiqueta a la izquierda, fórmula a la
        // derecha), sin divisores entre filas.
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < formulary.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                              localizedFormularyName(
                                  formulary[i]['name'] ?? ''),
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: onSurface)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(formulary[i]['expr'] ?? '',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  // 15 pt (antes 16): la fila de
                                  // Dalton no cabe en una línea a 16
                                  // y dejaba "total" sola en la
                                  // segunda (Zona F, 2026-11-12).
                                  fontSize: 15, color: onSurface)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Aprender guarda los temas de estudio principales. Orgánica y
        // Laboratorio viven en el menú de hamburguesa (Ramas y
        // Laboratorio), no aquí, para que nada esté escondido.
        // Cada tema es su propia tarjeta redondeada (título +
        // subtítulo + chevron, con espacio entre tarjetas): al
        // tocarla se abre su pantalla propia completa
        // (TopicDetailScreen, la misma que usan las Ramas y la
        // búsqueda). Nada se despliega dentro de la tarjeta.
        for (var i = 0; i < visibleTopics.length; i++)
          _TopicCard(
            title: visibleTopics[i].title,
            subtitle: visibleTopics[i].level,
            cardColor: cardColor,
            borderColor: borderColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => TopicDetailScreen(topic: visibleTopics[i])),
              );
            },
          ),
      ],
    );
  }
}

/// Una tarjeta de tema de Aprender (corrección 2026-11-12, Zona F):
/// cada tema es su propia tarjeta redondeada (radio 16, color y
/// borde del tema, sin sombra), título 17 pt peso 700, subtítulo
/// 15 pt a color entero (antes gris al 80 %: en oscuro se leía
/// apagado) y chevron gris, con espacio entre tarjetas. Antes era
/// una fila plana con líneas divisorias rústicas entre temas.
class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.title,
    this.subtitle,
    required this.onTap,
    required this.cardColor,
    required this.borderColor,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color cardColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: onSurface)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: TextStyle(
                              fontSize: 15, color: onSurface)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const LucideIcon(LucideIcons.chevronRight,
                  color: Color(0xFFAFAFAF)),
            ],
          ),
        ),
      ),
    );
  }
}
