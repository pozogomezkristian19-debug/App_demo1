// Aviso de desconexión en mitad de una partida (Quemia 7.0, regla
// 09:17): una línea amable con el nombre del rival que perdió el
// internet, y las dos opciones del jugador que queda: esperar un
// poco, o terminar la partida ganando por abandono (sin perder
// vidas ni puntos). Nunca una pantalla congelada: el aviso es una
// tarjeta encima de la partida, que sigue viva debajo.
//
// Diseño 7.0: tarjeta con degradado cálido (ámbar claro → blanco),
// sombra suave ámbar, sin borde negro; la advertencia con su
// insignia ámbar; los dos botones APILADOS a lo ancho, en píldora
// 3D — el de abandono en teal con el texto en UNA sola línea
// (fontSize 14) y "Esperar un poco" en blanco con texto ámbar.

import 'package:flutter/material.dart';

import '../services/localization.dart';
import 'duo_button.dart';
import 'lucide_icons.dart';

class DisconnectBanner extends StatelessWidget {
  const DisconnectBanner({
    super.key,
    required this.opponentName,
    required this.onWait,
    required this.onForfeit,
  });

  final String opponentName;
  final VoidCallback onWait;
  final VoidCallback onForfeit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const ValueKey('disconnect-banner'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        // En oscuro, cara oscura sólida (auditoría 7.2): el
        // degradado claro dejaba el texto onSurface claro
        // invisible sobre fondo claro. En claro queda el
        // degradado cálido de siempre.
        color: isDark ? scheme.surfaceContainerHighest : null,
        gradient: isDark
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFBEB), Color(0xFFFFFFFF)],
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Insignia ámbar con el triángulo de aviso.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFFF59E0B).withValues(alpha: 0.40),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const LucideIcon(
                  LucideIcons.triangleAlert,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('duelOpponentOffline')
                      .replaceFirst('%s', opponentName),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Botones apilados, a lo ancho: el texto del de abandono
          // cabe en una sola línea (fontSize 14 + FittedBox).
          DuoButton.primary(
            label: tr('duelWinByForfeit').toUpperCase(),
            onPressed: onForfeit,
            fontSize: 14,
          ),
          const SizedBox(height: 10),
          DuoButton.secondary(
            label: tr('duelWaitABit').toUpperCase(),
            onPressed: onWait,
            textColor: const Color(0xFF92400E),
            edgeColor: const Color(0xFFFDE68A),
            fontSize: 15,
          ),
        ],
      ),
    );
  }
}
