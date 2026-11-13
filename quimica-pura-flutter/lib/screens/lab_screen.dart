// Laboratorio (v5): su propia pantalla en el menú. Muestra el tema de
// laboratorio completo (seguridad, material, técnicas) y los botones del
// cuestionario y del simulador.

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../services/localization.dart';
import '../services/accent.dart';

import 'lab_quiz_screen.dart';
import 'lab_sim_screen.dart';
import 'topic_detail_screen.dart';

class LabScreen extends StatelessWidget {
  const LabScreen({super.key});

  // Tarjeta de acción con icono ARRIBA y texto DEBAJO (fix2): los
  // botones viejos eran ElevatedButton.icon (icono a la izquierda) y
  // el texto se partía en 3 líneas apretado. Mismo patrón que las
  // tarjetas de Tabla y de "Practicar de otra forma": círculo
  // tintado con el icono, texto centrado debajo, ambas tarjetas
  // exactamente iguales de alto (IntrinsicHeight).
  Widget _actionCard(
    BuildContext context, {
    required LucideIconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      // Tarjeta con vida (ronda de diseño 7.0): degradado suave
      // blanco → menta + sombra tintada teal, nunca el gris plano.
      // Sigue siendo un Card (los tests lo buscan por tipo): el
      // degradado va en un Container dentro, con clip.
      child: Card(
        margin: EdgeInsets.zero,
        color: isDark ? AppAccent.darkCard : Colors.white,
        elevation: 3,
        shadowColor: AppAccent.primary.withValues(alpha: 0.20),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [AppAccent.darkCard, AppAccent.darkCard]
                  : const [Colors.white, Color(0xFFE9FBF8)],
            ),
          ),
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
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withValues(alpha: 0.22),
                          accent.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(27),
                    ),
                    alignment: Alignment.center,
                    // Icono 3D (fix3, punto 6): degradado del acento
                    // en el trazo + brillito, como el corazón.
                    child:
                        LucideIcon(icon, size: 28, color: accent, threeD: true),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 34),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topic = findTopic('laboratorio');
    return Scaffold(
      appBar: AppBar(title: Text(tr('menuLab'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // El SIMULADOR va PRIMERO (fix2, item 4): antes
                  // que el cuestionario, en el menú de Laboratorio.
                  _actionCard(
                    context,
                    icon: LucideIcons.flaskConical,
                    label: tr('labSimTitle'),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LabSimScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _actionCard(
                    context,
                    icon: LucideIcons.circleHelp,
                    label: tr('labQuizButton'),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LabQuizPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: topic == null
                ? const Center(child: Text('Sin contenido'))
                : TopicDetailView(topic: topic),
          ),
        ],
      ),
    );
  }
}
