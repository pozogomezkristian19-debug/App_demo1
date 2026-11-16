// Pantalla de mantenimiento: si el panel de Admin activa el modo
// mantenimiento ('maintenanceMode' en 'settings/app'), la app
// principal muestra esto en vez de la app normal, con el mensaje que
// escribió el admin ('maintenanceMessage'). Solo un botón:
// REINTENTAR vuelve a leer los ajustes y, si el modo ya está
// apagado, entra a la app normal.
//
// Diseño Quemia (tema claro siempre, aunque la app esté en oscuro),
// igual que la pantalla de suspensión: fondo blanco, tarjeta grande
// redondeada con sombra suave, teal #00C2A8, tipografía limpia.
// Nada rústico ni amontonado.

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/accent.dart';
import 'brand_logo.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({
    super.key,
    required this.message,
    required this.onRetry,
  });

  /// Mensaje del servidor (o el local si no hay).
  final String message;

  /// Vuelve a leer 'settings/app' y reconstruye la app.
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    // Colores fijos del sistema claro (no del tema): la pantalla se
    // ve igual en claro y en oscuro.
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppAccent.primary.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppAccent.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.build,
                        size: 44,
                        color: AppAccent.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr('maintenanceTitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: BrandColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: BrandColors.ink,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppAccent.primary,
                      foregroundColor: Colors.white,
                      shadowColor: AppAccent.primaryDark,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: () => onRetry(),
                    icon: const Icon(Icons.refresh, size: 20),
                    label: Text(tr('maintenanceRetry')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
