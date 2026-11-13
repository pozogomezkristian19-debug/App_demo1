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

import '../services/accent.dart';
import '../services/localization.dart';
import '../services/social_service.dart';
import '../services/sound_service.dart';
import '../services/user_prefs.dart';
import 'shop_screen.dart';

/// Tokens de la pantalla (diseño Duolingo §2/§3.15): teal #00C2A8
/// como color principal, teal oscuro #00A18D, texto #4B4B4B,
/// secundario #777777, borde #E5E5E5.
const _teal = Color(0xFF00C2A8);
const _ink = Color(0xFF4B4B4B);
const _inkSoft = Color(0xFF777777);
const _card = Color(0xFFF7F7F7);
const _border = Color(0xFFE5E5E5);
const _violet = Color(0xFF8B5CF6);

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
      // Fondo y tarjetas según el acento (fix4, punto 2).
      return _ThemeColors(
        bg: AppAccent.darkBackground,
        card: AppAccent.darkCard,
        ink: Colors.white,
        inkSoft: AppAccent.darkInkSoft,
        border: AppAccent.darkBorder,
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
/// de Cuenta ("Verde · Claro"). Quemia 7.0: un tema comprado en la
/// tienda manda sobre Verde/Violeta (su nombre sale del catálogo).
String themeAccentName() {
  final shop = SocialService.equippedThemeName;
  if (shop != null) return shop;
  return UserPrefs.themeAccent == 'violeta'
      ? tr('themeViolet')
      : tr('themeGreen');
}

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
String themeSelectionSubtitle() => '${themeAccentName()} · ${themeModeName()}';

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  /// Temas de la tienda ya comprados (para poder elegirlos aquí).
  Set<String> _ownedThemes = {};

  @override
  void initState() {
    super.initState();
    _loadOwned();
  }

  Future<void> _loadOwned() async {
    final owned = await SocialService.ownedItemIds();
    if (!mounted) return;
    setState(() => _ownedThemes = owned);
  }

  /// Al elegir Verde o Violeta se quita el tema de tienda equipado:
  /// si no, el tema de la tienda seguiría mandando (AppAccent lo
  /// lee primero) y el cambio no se vería.
  void _pickStock(String accent) {
    UserPrefs.saveThemeAccent(accent);
    SocialService.clearEquippedTheme();
  }

  /// Los 3 temas de la tienda (coral, rosa, azul).
  List<ShopItem> get _shopThemeItems =>
      kShopCatalog.where((i) => i.kind == 'theme').toList();

  /// Una miniatura de tema de tienda: si ya lo tienes, se equipa
  /// al tocarla; si no, abre la tienda. Al volver de la tienda se
  /// recarga lo comprado.
  Widget _shopThemeTile(ShopItem item) {
    final owned = _ownedThemes.contains(item.id);
    return _ShopThemeTile(
      item: item,
      selected: SocialService.equippedThemeId == item.id,
      locked: !owned,
      onTap: () {
        if (!owned) {
          Navigator.of(context)
              .push(
                MaterialPageRoute(builder: (_) => const ShopScreen()),
              )
              .then((_) => _loadOwned());
          return;
        }
        SocialService.equipItem(item);
        UserPrefs.themeAccentNotifier.value = item.id;
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _ThemeColors.of(context);
    final current = UserPrefs.themeAccent;
    final mode = UserPrefs.themeMode;
    // (Kristian, 2026-11-13, por foto: en el tema CLARO el botón
    // Claro se deja claro y el Oscuro lleva un toque más oscuro;
    // en el tema OSCURO el botón Oscuro se deja así y el Claro va
    // un poco más claro. Por eso los dos botones de modo dependen
    // del tema en el que se está viendo la pantalla.)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final claroColor = isDark
        ? Color.lerp(AppAccent.primaryLightest, Colors.white, 0.3)!
        : AppAccent.primaryLightest;
    final oscuroColor = isDark
        ? AppAccent.primaryDark
        : Color.lerp(AppAccent.primaryDark, Colors.black, 0.25)!;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(tr('themeTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            tr('themeSub'),
            style: TextStyle(fontSize: 16, color: c.inkSoft),
          ),
          const SizedBox(height: 16),
          // Color: Verde (el de antes) o Violeta (el actual).
          Row(
            children: [
              _OptionTile(
                selected:
                    current == 'verde' && SocialService.equippedThemeId == null,
                onTap: () => _pickStock('verde'),
                onChanged: () => setState(() {}),
                label: tr('themeGreen'),
                color: _teal,
              ),
              const SizedBox(width: 10),
              _OptionTile(
                selected: current == 'violeta' &&
                    SocialService.equippedThemeId == null,
                onTap: () => _pickStock('violeta'),
                onChanged: () => setState(() {}),
                label: tr('themeViolet'),
                color: _violet,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Quemia 7.0: temas comprados en la tienda. Los que ya
          // tienes se eligen aquí mismo; los demás se ven con su
          // precio y abren la tienda al tocarlos.
          Text(
            tr('themeShop'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _shopThemeItems.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _shopThemeTile(_shopThemeItems[i]),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Text(
            tr('themeModeLabel'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
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
                // (Kristian, 2026-11-13: el botón Claro es el más
                // claro; en oscuro va un poco más claro todavía.)
                color: claroColor,
                icon: LucideIcons.sun,
              ),
              const SizedBox(width: 10),
              _OptionTile(
                selected: mode == 'oscuro',
                onTap: () => UserPrefs.saveThemeMode('oscuro'),
                onChanged: () => setState(() {}),
                label: tr('darkWord'),
                // (Kristian, 2026-11-13: el botón Oscuro lleva el
                // color del tema, más oscuro que el botón de claro;
                // en claro lleva un toque más oscuro todavía.)
                color: oscuroColor,
                icon: LucideIcons.moon,
              ),
              const SizedBox(width: 10),
              _OptionTile(
                selected: mode == 'sistema',
                onTap: () => UserPrefs.saveThemeMode('sistema'),
                onChanged: () => setState(() {}),
                label: tr('themeSystem'),
                // Sistema va con un color NEUTRO (gris pizarra),
                // ni claro ni oscuro.
                color: const Color(0xFF64748B),
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
            // Tinte sólido del color al seleccionar (antes un
            // degradado suave + sombra tintada). El círculo con
            // su anillo de 2 px NO se toca (lo afirman los tests).
            color: selected ? color.withValues(alpha: 0.12) : null,
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
                  style: TextStyle(fontWeight: FontWeight.bold, color: c.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una miniatura de tema de la tienda (Quemia 7.0): mismo tamaño
/// para propios y bloqueados — la nota de precio ocupa una línea
/// también cuando está vacía, para que la fila no quede dispareja.
/// Propio seleccionado: relleno del color + ✓. Bloqueado: candado
/// en el círculo y "En la tienda por X puntos" debajo del nombre.
class _ShopThemeTile extends StatelessWidget {
  const _ShopThemeTile({
    required this.item,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final ShopItem item;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = _ThemeColors.of(context);
    final color = Color(item.color ?? 0xFF00C2A8);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          SoundService.tap();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            // Igual que la opción de color: tinte sólido al
            // seleccionar. El círculo con su anillo de 2 px NO
            // se toca (lo afirman los tests).
            color: selected ? color.withValues(alpha: 0.12) : null,
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
                    : locked
                        ? LucideIcon(LucideIcons.lock, size: 16, color: color)
                        : null,
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                style: TextStyle(fontWeight: FontWeight.bold, color: c.ink),
              ),
              Text(
                locked
                    ? tr('themeShopLocked').replaceFirst('%s', '${item.price}')
                    : '',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: c.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
