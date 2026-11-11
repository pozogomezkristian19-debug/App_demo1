// Pantalla dedicada "Tema" (fix3, último cambio de la ronda): el
// selector de color (Verde / Violeta) Y de modo (Claro / Oscuro /
// Sistema) ya NO vive como tarjeta dentro de Cuenta: en Cuenta hay
// una fila táctil "Tema" (con el subtítulo de la selección actual,
// p. ej. "Verde · Claro") que abre esta pantalla. Mismo contenido,
// mismo aspecto (los 5 círculos paralelos: anillo en las 5, relleno
// solo la seleccionada) y mismo comportamiento que tenía la tarjeta:
// cambia el acento y el brillo de toda la app en el acto y se guarda
// en el teléfono (UserPrefs.saveThemeAccent / saveThemeMode).

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../services/localization.dart';
import '../services/sound_service.dart';
import '../services/user_prefs.dart';

/// Tokens de la pantalla, los mismos de la tarjeta de Cuenta: teal
/// #00C2A8 como color principal, teal oscuro #00A18D.
const _teal = Color(0xFF00C2A8);
const _ink = Color(0xFF3C3C3C);
const _inkSoft = Color(0xFF6E6E6E);
const _card = Color(0xFFF7F7F7);
const _border = Color(0xFFE8E8E8);
const _violet = Color(0xFF8B5CF6);
const _blue = Color(0xFF3B82F6);
const _amber = Color(0xFFF59E0B);

/// Colores según el tema (igual que en Cuenta): en claro fondo
/// blanco y tarjeta #F7F7F7; en oscuro verde oscuro, sin violeta,
/// azul ni ámbar de fondo (las gemelas no cambian: son mascotas).
class _ThemeColors {
  const _ThemeColors({
    required this.bg,
    required this.card,
    required this.ink,
    required this.inkSoft,
    required this.border,
  });

  factory _ThemeColors.of(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return const _ThemeColors(
        bg: Color(0xFF0A1F1A),
        card: Color(0xFF122B24),
        ink: Colors.white,
        inkSoft: Color(0xFFB8CFC8),
        border: Color(0xFF1E4D42),
      );
    }
    return const _ThemeColors(
      bg: Colors.white,
      card: _card,
      ink: _ink,
      inkSoft: _inkSoft,
      border: _border,
    );
  }

  final Color bg;
  final Color card;
  final Color ink;
  final Color inkSoft;
  final Color border;
}

/// Nombre localizado del color actual, para el subtítulo de la fila
/// de Cuenta ("Verde · Claro").
String themeAccentName() => UserPrefs.themeAccent == 'violeta'
    ? tr('themeViolet')
    : tr('themeGreen');

/// Nombre localizado del modo actual, para el subtítulo de la fila
/// de Cuenta ("Verde · Claro").
String themeModeName() {
  switch (UserPrefs.themeMode) {
    case 'oscuro':
      return tr('darkWord');
    case 'sistema':
      return tr('themeSystem');
    default:
      return tr('lightWord');
  }
}

/// Subtítulo de la fila "Tema" de Cuenta: "Verde · Claro".
String themeSelectionSubtitle() =>
    '${themeAccentName()} · ${themeModeName()}';

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  @override
  Widget build(BuildContext context) {
    final c = _ThemeColors.of(context);
    final current = UserPrefs.themeAccent;
    final mode = UserPrefs.themeMode;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(tr('themeTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            tr('themeSub'),
            style: TextStyle(fontSize: 15, color: c.inkSoft),
          ),
          const SizedBox(height: 16),
          // Color: Verde (el de antes) o Violeta (el actual).
          Row(
            children: [
              _OptionTile(
                selected: current == 'verde',
                onTap: () => UserPrefs.saveThemeAccent('verde'),
                onChanged: () => setState(() {}),
                label: tr('themeGreen'),
                color: _teal,
              ),
              const SizedBox(width: 10),
              _OptionTile(
                selected: current == 'violeta',
                onTap: () => UserPrefs.saveThemeAccent('violeta'),
                onChanged: () => setState(() {}),
                label: tr('themeViolet'),
                color: _violet,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            tr('themeModeLabel'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 10),
          // Modo: Claro, Oscuro o Sistema.
          Row(
            children: [
              _OptionTile(
                selected: mode == 'claro',
                onTap: () => UserPrefs.saveThemeMode('claro'),
                onChanged: () => setState(() {}),
                label: tr('lightWord'),
                color: _amber,
                icon: LucideIcons.sun,
              ),
              const SizedBox(width: 10),
              _OptionTile(
                selected: mode == 'oscuro',
                onTap: () => UserPrefs.saveThemeMode('oscuro'),
                onChanged: () => setState(() {}),
                label: tr('darkWord'),
                // Pizarra medio (no azul marino): el anillo hueco
                // y la luna se ven en tarjeta blanca y en la
                // verde oscura del modo oscuro.
                color: const Color(0xFF64748B),
                icon: LucideIcons.moon,
              ),
              const SizedBox(width: 10),
              _OptionTile(
                selected: mode == 'sistema',
                onTap: () => UserPrefs.saveThemeMode('sistema'),
                onChanged: () => setState(() {}),
                label: tr('themeSystem'),
                // Azul propio (no el teal de Verde): cada una de
                // las 5 opciones tiene su color.
                color: _blue,
                icon: LucideIcons.settings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Una opción seleccionable (color o modo): el círculo con su anillo
/// de 2 px SIEMPRE (sin seleccionar es solo un anillo hueco del
/// color, con su icono si lo tiene; al seleccionar se rellena del
/// color y lleva el ✓ blanco) y la etiqueta debajo. Igual que en la
/// antigua tarjeta de Cuenta.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.selected,
    required this.onTap,
    required this.onChanged,
    required this.label,
    required this.color,
    this.icon,
  });

  final bool selected;
  final VoidCallback onTap;

  /// Lo llama el padre tras guardar, para reconstruir la pantalla y
  /// mover el ✓ y el relleno a la opción tocada.
  final VoidCallback onChanged;
  final String label;
  final Color color;
  final LucideIconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = _ThemeColors.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (!selected) {
            SoundService.tap();
            onTap();
            onChanged();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                alignment: Alignment.center,
                child: selected
                    ? const LucideIcon(LucideIcons.check,
                        size: 18, color: Colors.white)
                    : icon == null
                        ? null
                        : LucideIcon(icon!, size: 18, color: color),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: c.ink)),
            ],
          ),
        ),
      ),
    );
  }
}
