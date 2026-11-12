// Celebración de victoria en torneo (Quemia 7.0): lluvia de
// confeti (la misma de pasar de nivel, que se desmonta sola) +
// trofeo dorado que entra con un salto y el texto de campeón.
// Es una capa encima de la pantalla de clasificación; "Seguir"
// la cierra.

import 'package:flutter/material.dart';

import '../services/localization.dart';
import 'celebration.dart';
import 'duo_button.dart';
import 'lucide_icons.dart';

class TournamentVictory extends StatefulWidget {
  const TournamentVictory({
    super.key,
    required this.prizePoints,
    required this.onClose,
  });

  final int prizePoints;
  final VoidCallback onClose;

  @override
  State<TournamentVictory> createState() => _TournamentVictoryState();
}

class _TournamentVictoryState extends State<TournamentVictory>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: Stack(
        children: [
          const CelebrationOverlay(),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.4, end: 1.0).animate(
                      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
                    ),
                    // Trofeo plano (re-verificación Zona D, reglas 1,
                    // 2 y 3): disco blanco sólido + borde 4 pt dorado
                    // #FFD700 + trofeo en dorado oscuro #D9A400. Sin
                    // degradado dorado, sin banda de brillo blanca y
                    // sin sombra borrosa con resplandor.
                    child: Container(
                      key: const ValueKey('tournament-trophy'),
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border:
                            Border.all(color: const Color(0xFFFFD700), width: 4),
                      ),
                      alignment: Alignment.center,
                      child: const LucideIcon(
                        LucideIcons.trophy,
                        size: 64,
                        color: Color(0xFFD9A400),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr('tournWin'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('tournWinPrize')
                        .replaceFirst('%s', '${widget.prizePoints}'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  // Botón primario §1.4: la etiqueta llega en
                  // mayúsculas (el test espera "SEGUIR").
                  DuoButton.primary(
                    label: tr('tournClose').toUpperCase(),
                    onPressed: widget.onClose,
                    icon: LucideIcons.trophy,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
