// Compatibilidad (ronda fix5, punto 1, Quemia 6.2): el DIÁLOGO
// "¿Cómo se juega?" ya NO existe: ahora es una pantalla completa
// (HowToPlayScreen, lib/screens/how_to_play_screen.dart) con las 5
// reglas visibles sin deslizar, que se abre desde la fila de Cuenta
// con onOpenScreen('howToPlay'). Este archivo queda solo con el
// alias de abajo, para no romper el test fix3 que invoca
// showHowToPlayDialog (test/fix3_polish_test.dart): ahora abre la
// pantalla en vez del diálogo, con el mismo título, las mismas 5
// reglas y el mismo botón de cerrar. Cuando ese test se actualice
// a la pantalla, este archivo se puede borrar.
//
// Los colores salen del tema (auditoría fix2): antes el fondo era
// blanco fijo y en modo oscuro la ventanita se quedaba blanca.

import 'package:flutter/material.dart';

import '../screens/how_to_play_screen.dart';

/// Abre "¿Cómo se juega?" como pantalla completa (antes, diálogo).
Future<void> showHowToPlayDialog(BuildContext context) async {
  await openHowToPlayScreen(context);
}
