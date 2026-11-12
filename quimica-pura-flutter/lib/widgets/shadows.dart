// Sombras de Quemia (rediseño Duolingo 7.0): Duolingo NO usa
// sombras borrosas en las tarjetas — la estructura es espacio en
// blanco + líneas finas (#E5E5E5). La única sombra del sistema es
// la "Nivel 2" para elementos FLOTANTES: el círculo central de la
// barra inferior, las hojas inferiores y los diálogos.
//
// `standardShadow` queda como no-op deprecado: la sombra borrosa
// estándar (desplazamiento (0,4), blur 10, alfa 0.25) ya no
// existe. Se conserva la firma para no romper los ~39 usos de
// otras zonas mientras cada zona los quita en esta ronda; cuando
// ya no quede ningún uso, se borra del todo (ver informe Zona A).
// Los usos que queden devuelven una sombra transparente: la
// tarjeta queda plana, que es el estado final deseado.

import 'package:flutter/material.dart';

/// La única sombra del sistema (Nivel 2 Duolingo):
/// `0 3px 8px rgba(0,0,0,0.15)`. Solo para elementos flotantes
/// (círculo central, hojas inferiores, diálogos). NUNCA en
/// tarjetas de lista ni en botones (el labio ES su sombra).
const BoxShadow floatingShadow = BoxShadow(
  color: Color.fromRGBO(0, 0, 0, 0.15),
  blurRadius: 8,
  offset: Offset(0, 3),
);

/// Tinte neutro histórico para tarjetas y botones sin color propio.
/// Se conserva solo como argumento de los usos pendientes de
/// limpiar por otras zonas; no se usa en código nuevo.
const kShadowNeutralTint = Color(0xFF6B7280);

/// Sombra estándar borrosa — ELIMINADA (rediseño Duolingo 7.0).
/// Devuelve una sombra transparente (sin efecto visual).
/// (Sin anotación @Deprecated a propósito: los ~39 usos de otras
/// zonas siguen compilando sin avisos mientras cada zona los
/// quita; cuando ya no quede ningún uso, se borra esta función.)
BoxShadow standardShadow(Color tint) => const BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0),
      blurRadius: 0,
      offset: Offset.zero,
    );

// Constantes históricas de la sombra estándar, conservadas solo
// para que el código de otras zonas que aún las referencia siga
// compilando mientras las limpia. No se usan en código nuevo.
const kShadowOffset = Offset(0, 4);
const kShadowBlur = 10.0;
const kShadowAlpha = 0.25;
