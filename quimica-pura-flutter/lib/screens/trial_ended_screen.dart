// Pantalla "Se acabó tu prueba" (Kristian 2026-11-16): cuando
// terminan los 3 días gratis, sale UNA vez una pantalla que lo
// dice claro y explica que las pantallas que se bloquean
// (Aprender, Resolver, repasar errores) necesitan Premium, que se
// paga por Transfermóvil. No es un candado: se puede cerrar con
// "Seguir gratis" y la app sigue con las secciones bloqueadas y
// la tabla periódica gratis, como siempre.
//
// La pantalla NO decide cuándo sale: eso lo hace la HomeScreen
// con shouldShowTrialEnded() (prueba que existió y terminó, sin
// Premium, sin haberla enseñado ya). Esta pantalla solo se pinta
// y avisa con sus dos botones.

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/premium_service.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';

class TrialEndedScreen extends StatelessWidget {
  const TrialEndedScreen({super.key});

  void _seePremium(BuildContext context) {
    // Cerrar primero y luego pedir el paywall: el paywall se abre
    // desde la HomeScreen, encima de la app, no encima de esta
    // pantalla.
    Navigator.of(context).pop();
    PremiumService.requestPaywall();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final mutedColor =
        isDark ? const Color(0xFFB8C4C9) : const Color(0xFF777777);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const LucideIcon(LucideIcons.x),
          tooltip: tr('closeWord'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Sin título en la barra: el título va grande en el cuerpo,
        // como en el resto de pantallas de aviso.
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Reloj grande en círculo con tinte del acento.
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                  ),
                  alignment: Alignment.center,
                  child: LucideIcon(
                    LucideIcons.clock,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr('trialEndedTitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr('trialEndedBody'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: textColor),
              ),
              const SizedBox(height: 16),
              // Nota del pago por Transfermóvil.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LucideIcon(
                      LucideIcons.qrCode,
                      size: 22,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr('trialEndedPayNote'),
                        style: TextStyle(fontSize: 15, color: textColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr('trialEndedFreeNote'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: mutedColor),
              ),
              const SizedBox(height: 32),
              DuoButton.primary(
                label: tr('trialEndedSeePremium').toUpperCase(),
                onPressed: () => _seePremium(context),
              ),
              const SizedBox(height: 12),
              DuoButton.secondary(
                label: tr('trialEndedContinueFree').toUpperCase(),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
