// Pantalla que pide el widget en el registro (2026-11-18, diseño v3
// aprobado por Kristian: tarjeta estilo Duolingo con la miniatura
// del widget de verdad, título, cuerpo, AGREGAR WIDGET +
// MÁS TARDE). La miniatura sigue el tema: blanca en claro y oscura
// en oscuro, como el widget real.
//
// Va justo después de la página de permiso de notificaciones (las
// dos son avisos del sistema: permiso y fijar el widget) y NO es
// obligatoria: con MÁS TARDE se avanza igual. AGREGAR WIDGET abre
// el diálogo del sistema para fijar el widget (requestPinAppWidget,
// Android 8+); si el sistema no lo muestra o el usuario lo cierra,
// se avanza igual — el widget se puede poner luego.
//
// La miniatura es el widget de verdad en pequeño: cara de Brenda,
// llama + racha, tip del día, meta del día con su barra y estado,
// corazón + vidas sobre 10 y rayo + puntos, con los datos del
// usuario. La tarjeta sigue el tema de la app: blanca en claro y
// oscura en oscuro (como el widget real).

import 'package:flutter/material.dart';

import '../data/i18n/content_i18n.dart';
import '../services/home_widget_service.dart';
import '../services/localization.dart';
import '../services/points.dart';
import '../services/progress.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';

class OnboardingWidgetPage extends StatefulWidget {
  const OnboardingWidgetPage({super.key, required this.onNext});

  /// Avanza a la siguiente pantalla del onboarding.
  final VoidCallback onNext;

  @override
  State<OnboardingWidgetPage> createState() => _OnboardingWidgetPageState();
}

class _OnboardingWidgetPageState extends State<OnboardingWidgetPage> {
  var _busy = false;

  /// Pide fijar el widget con el diálogo del sistema y avanza lo
  /// mismo se pueda o no: poner el widget no es obligatorio.
  Future<void> _add() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Datos frescos antes de fijarlo: el proveedor pinta lo que
    // hay guardado; si el widget se fija, que salga al día.
    await HomeWidgetService.update();
    await HomeWidgetService.requestPin();
    if (!mounted) return;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    // Contraste (zona E): título y cuerpo con el on-surface del
    // tema (#4B4B4B en claro, casi blanco en oscuro); el #4B4B4B y
    // el #777777 fijos eran ilegibles sobre el fondo oscuro.
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final bodyColor = isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : const Color(0xFF777777);
    // Botones ABAJO como en el resto del inicio (Quemia 7.7,
    // Kristian 2026-11-13: el botón quedaba a mitad de pantalla
    // mientras en las demás pantallas va pegado abajo, como
    // Duolingo).
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    // Miniatura del widget: así se verá en la
                    // pantalla principal.
                    const _WidgetMiniPreview(),
                    const SizedBox(height: 28),
                    Text(
                      tr('obWidgetTitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('obWidgetBody'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: bodyColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: DuoButton.primary(
              label: tr('obWidgetAdd').toUpperCase(),
              onPressed: _busy ? null : _add,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: DuoButton.secondary(
              label: tr('obWidgetLater').toUpperCase(),
              onPressed: widget.onNext,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniatura del widget mejorado (v3): cara de Brenda, llama +
/// racha, tip del día, meta del día con su barra y estado, corazón
/// + vidas sobre 10 y rayo + puntos. Datos en vivo del usuario; la
/// tarjeta sigue el tema de la app — blanca en claro, oscura
/// (superficie 0xFF1F2E35, borde 0xFF33454E) en oscuro — como el
/// widget real. La barra teal, la llama, el corazón y el rayo
/// quedan iguales en los dos temas.
class _WidgetMiniPreview extends StatelessWidget {
  const _WidgetMiniPreview();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1F2E35) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF33454E)
        : const Color(0xFFE5E5E5);
    // Labio sólido abajo (estilo Duolingo, como los botones): en
    // claro es el borde; en oscuro, más oscuro que la tarjeta para
    // que se note el relieve.
    final lipColor = isDark
        ? const Color(0xFF152228)
        : const Color(0xFFE5E5E5);
    final ink = isDark
        ? const Color(0xFFF5F7FA)
        : const Color(0xFF0F172A);
    final tipColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF475569);
    final track = borderColor;
    const teal = Color(0xFF14B8A6);
    final p = ProgressService.instance;
    final tip = tipOfTheDay(DateTime.now());
    final tipText = tip.body.isEmpty
        ? 'Tip: ${tip.title}'
        : 'Tip: ${tip.title} — ${tip.body}';
    final goalDone = p.dailyGoalDone;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        // Labio sólido abajo (estilo Duolingo, como los botones).
        boxShadow: [
          BoxShadow(color: lipColor, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundImage: AssetImage('assets/brenda.png'),
                backgroundColor: Colors.transparent,
              ),
              const SizedBox(width: 10),
              Text(
                'Quemia',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const Spacer(),
              const LucideIcon(
                LucideIcons.flame,
                size: 18,
                color: Color(0xFFFF9600),
              ),
              const SizedBox(width: 4),
              Text(
                '${p.streakNow}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF9600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tipText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: tipColor),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                tr('obWidgetGoal'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const Spacer(),
              Text(
                goalDone
                    ? tr('obWidgetGoalDone')
                    : '${p.levelsPassedToday()}/1',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(3)),
            child: LinearProgressIndicator(
              value: goalDone ? 1 : 0,
              minHeight: 6,
              backgroundColor: track,
              valueColor: const AlwaysStoppedAnimation(teal),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const LucideIcon(
                LucideIcons.heart,
                size: 16,
                color: Color(0xFFFF4B4B),
              ),
              const SizedBox(width: 6),
              Text(
                '${p.livesLeft}/$maxLives',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const Spacer(),
              const LucideIcon(
                LucideIcons.zap,
                size: 16,
                color: Color(0xFFFFC800),
              ),
              const SizedBox(width: 6),
              Text(
                '${p.points}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
