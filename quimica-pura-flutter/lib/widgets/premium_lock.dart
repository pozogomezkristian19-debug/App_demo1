// Candado Premium: contenido desvanecido con candado.
//
// El usuario gratis PUEDE ENTRAR a Aprender / Resolver / Temas /
// Mis errores, pero el contenido queda desvanecido y NADA dentro
// se puede abrir (AbsorbPointer). NO hay tarjeta central: el
// bloqueo va ABAJO (2026-11-15, Kristian) — una barra fija con el
// candado, el texto y el botón 'DESBLOQUEAR CON PREMIUM'. NO
// cambia los diseños existentes: solo AGREGA el desvanecido +
// bloqueo encima del contenido tal como está. La Tabla periódica
// nunca lleva este candado.
//
// El desvanecido es la excepción aprobada a la regla "sin
// degradados": es el efecto de bloqueo de la maqueta, no
// decoración. El resto sigue el sistema Duolingo (sólido + labio
// 4 pt, Nunito, 17 pt extra-bold MAYÚSCULAS solo en el botón).

import 'package:flutter/material.dart';

import '../services/accent.dart';
import '../services/premium.dart';
import '../services/premium_service.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';

/// Envuelve el contenido de una sección con candado (gratis).
/// Con Premium, devuelve [child] tal cual, sin tocarlo.
class PremiumLockedContent extends StatelessWidget {
  const PremiumLockedContent({
    super.key,
    required this.child,
    required this.section,
    this.title = 'Contenido Premium',
    this.body =
        'Esta sección es Premium. Desbloquéala para estudiar sin límites.',
  });

  final Widget child;
  final PremiumLockedSection section;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PremiumService.premiumNotifier,
      builder: (context, isPremium, _) {
        // Candado: el usuario gratis ve el contenido desvanecido.
        if (!premiumSectionLocked(
          isPremium: isPremium,
          section: section,
        )) {
          return child;
        }
        return _LockedView(child: child, title: title, body: body);
      },
    );
  }
}

class _LockedView extends StatelessWidget {
  const _LockedView({
    required this.child,
    required this.title,
    required this.body,
  });

  final Widget child;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Color del fondo para el desvanecido inferior: el fondo de la
    // pantalla, para que el contenido se pierda en él.
    final bg = scheme.surface;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Contenido tal cual, atenuado y SIN interacción.
        AbsorbPointer(
          absorbing: true,
          child: Opacity(opacity: 0.35, child: child),
        ),
        // Desvanecido: transparente arriba, fondo sólido abajo (la
        // excepción aprobada: efecto de bloqueo, no decoración).
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bg.withValues(alpha: 0.0),
                  bg.withValues(alpha: 0.55),
                  bg,
                ],
                stops: const [0.0, 0.45, 0.85],
              ),
            ),
          ),
        ),
        // Bloqueo ABAJO (no tarjeta central): barra fija con el
        // candado, el título + texto y el botón de desbloqueo.
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: isDark ? AppAccent.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? AppAccent.darkBorder
                    : const Color(0xFFE5E5E5),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFC800),
                      ),
                      alignment: Alignment.center,
                      child: const LucideIcon(
                        LucideIcons.lock,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DuoButton.primary(
                  label: 'DESBLOQUEAR CON PREMIUM',
                  onPressed: PremiumService.requestPaywall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
