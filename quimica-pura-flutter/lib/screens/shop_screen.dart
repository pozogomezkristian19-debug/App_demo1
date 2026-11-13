// Tienda de puntos (Quemia 7.0; rediseño Duolingo 7.0, Zona C):
// gastar los puntos en cosméticos (temas/colores, fotos de avatar
// premium, insignias de perfil). Solo cosmético, nada de pagar
// para ganar. La compra se guarda en local y se sincroniza cuando
// hay backend; los temas equipados cambian el acento de la app y
// la foto de avatar equipada es la foto del usuario (Cuenta,
// Amigos, tabla). Sin Google, la puerta. Los marcos de avatar no
// existen (ronda 2e): el que compra no tiene avatar donde poner
// el marco.
//
// DISEÑO 7.0: un solo azul de compra (#1CB0F6) en toda la
// pantalla, con el precio dentro del botón ("COMPRAR · 200");
// tarjetas con borde neutro 2 pt #E5E5E5, sin sombra; avatares
// premium grandes (120 dp) con nombre y frase graciosa; "Tus
// puntos" como chip del HUD (estrella + número).

import 'package:flutter/material.dart';
import '../services/accent.dart';

import '../services/localization.dart';
import '../services/progress.dart';
import '../services/social_service.dart';
import '../services/user_prefs.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/online_gate.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    this.isGoogleLinked,
    this.onLinkGoogle,
  });

  final bool? isGoogleLinked;
  final Future<bool> Function()? onLinkGoogle;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  var _online = true;
  var _owned = <String>{};
  String? _equippedThemeId;
  String? _equippedAvatarId;
  String? _equippedBadgeId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final online = await SocialService.online;
    final owned = await SocialService.ownedItemIds();
    final theme = await SocialService.equippedItemId('theme');
    final avatar = await SocialService.equippedItemId('avatar');
    final badge = await SocialService.equippedItemId('badge');
    if (!mounted) return;
    setState(() {
      _online = online;
      _owned = owned;
      _equippedThemeId = theme;
      _equippedAvatarId = avatar;
      _equippedBadgeId = badge;
    });
  }

  Future<void> _buy(ShopItem item) async {
    final ok = await SocialService.buyItem(item);
    if (!mounted) return;
    if (ok) {
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('shopBought'))),
      );
    }
  }

  Future<void> _equip(ShopItem item) async {
    await SocialService.equipItem(item);
    if (item.kind == 'theme') {
      // Avisa a la app de que el acento cambió (AppAccent lo lee
      // de SocialService, no de UserPrefs, que solo guarda
      // 'verde'/'violeta').
      UserPrefs.themeAccentNotifier.value = item.id;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = ProgressService.instance.points;
    return Scaffold(
      appBar: AppBar(title: Text(tr('shopTitle'))),
      body: OnlineGate(
        isGoogleLinked: widget.isGoogleLinked,
        onLinkGoogle: widget.onLinkGoogle,
        child: !_online
            ? _CalmLine(text: tr('socialOffline'))
            : FutureBuilder<List<ShopItem>>(
                future: SocialService.shopItems(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return _CalmLine(text: tr('shopEmpty'));
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      // "Tus puntos": ya no es una tarjeta con borde
                      // ámbar — es un chip del HUD (rediseño Duolingo
                      // 7.0): estrella amarilla + número, sin tarjeta
                      // y sin borde.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                        child: Row(
                          children: [
                            const LucideIcon(
                              LucideIcons.star,
                              size: 20,
                              color: Color(0xFFFFC800),
                              filled: true,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$points',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _SectionTitle(text: tr('shopThemes')),
                      for (final item in items.where((i) => i.kind == 'theme'))
                        _ItemCard(
                          item: item,
                          points: points,
                          owned: _owned.contains(item.id),
                          equipped: _equippedThemeId == item.id,
                          onBuy: () => _buy(item),
                          onEquip: () => _equip(item),
                        ),
                      _SectionTitle(text: tr('shopAvatars')),
                      for (final item in items.where((i) => i.kind == 'avatar'))
                        _ItemCard(
                          item: item,
                          points: points,
                          owned: _owned.contains(item.id),
                          equipped: _equippedAvatarId == item.id,
                          onBuy: () => _buy(item),
                          onEquip: () => _equip(item),
                        ),
                      _SectionTitle(text: tr('shopBadges')),
                      for (final item in items.where((i) => i.kind == 'badge'))
                        _ItemCard(
                          item: item,
                          points: points,
                          owned: _owned.contains(item.id),
                          equipped: _equippedBadgeId == item.id,
                          onBuy: () => _buy(item),
                          onEquip: () => _equip(item),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _CalmLine extends StatelessWidget {
  const _CalmLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, height: 1.5),
        ),
      ),
    );
  }
}

/// Tarjeta de producto (rediseño Duolingo 7.0): borde neutro 2 pt
/// #E5E5E5, radio 16, sin sombra y sin bordes tintados por producto.
/// El precio ya no va en una línea aparte: vive dentro del botón
/// de compra ("COMPRAR · 200"). Los avatares premium se ven
/// GRANDES (foto a 120 dp) con su nombre y una frase graciosa
/// debajo, y el botón de compra a ancho completo debajo.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.points,
    required this.owned,
    required this.equipped,
    required this.onBuy,
    required this.onEquip,
  });

  final ShopItem item;
  final int points;
  final bool owned;
  final bool equipped;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  /// Frase graciosa de cada avatar premium (el catálogo no trae
  /// descripción: vive aquí, en la pantalla).
  static const _avatarJokes = <String, String>{
    'avatar_dorado':
        'El rey de la química. Solo para los que llegan a 200 puntos.',
    'avatar_violeta':
        'Violeta como Brenda. Para que te vean desde la última fila.',
    'avatar_teal': 'Teal como la app. Discreto por fuera, crack por dentro.',
  };

  static const _line = Color(0xFFE5E5E5);
  static const _lineDark = Color(0xFF37464F);

  /// Botón de acción del producto: equipado = chip "Equipado";
  /// comprado = "EQUIPAR"; sin comprar y con puntos = "COMPRAR ·
  /// precio"; sin puntos = chip "Te faltan X puntos".
  Widget _action(BuildContext context) {
    if (equipped) {
      return _StateChip(label: tr('shopEquipped'), filled: true);
    }
    if (owned) {
      return _BuyButton(
        label: tr('shopEquip').toUpperCase(),
        onPressed: onEquip,
        withStar: false,
      );
    }
    if (points >= item.price) {
      return _BuyButton(
        label: '${tr('shopBuy').toUpperCase()} · ${item.price}',
        onPressed: onBuy,
        withStar: true,
      );
    }
    return _StateChip(
      label: tr('shopNeedMore').replaceFirst('%s', '${item.price - points}'),
      filled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget preview;
    if (item.kind == 'avatar') {
      // La foto premium en venta, completa y GRANDE (120 dp): el
      // producto ES la foto, no un marco.
      preview = ClipOval(
        child: Image.asset(
          item.asset ?? 'assets/avatar_teal.png',
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      );
    } else if (item.kind == 'badge') {
      final icon = switch (item.badgeIcon) {
        'trophy' => LucideIcons.trophy,
        'flame' => LucideIcons.flame,
        _ => LucideIcons.star,
      };
      preview = Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFFFC800),
        ),
        alignment: Alignment.center,
        // Icono oscuro sobre el amarillo: el blanco sobre #FFC800
        // apenas se lee (regla 6: el contraste se verifica).
        child: LucideIcon(icon, size: 22, color: Color(0xFF4B4B4B)),
      );
    } else {
      final base = item.color == null ? AppAccent.primary : Color(item.color!);
      preview = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: base,
        ),
      );
    }
    // El botón de compra a ancho completo (avatares) o a la derecha
    // de la fila (temas e insignias): en ambos casos el MISMO azul.
    final action = _action(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? _lineDark : _line,
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: item.kind == 'avatar'
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    preview,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _avatarJokes[item.id] ?? '',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: action),
              ],
            )
          : Row(
              children: [
                preview,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                // Flexible: "Te faltan 300 puntos" es largo (y en otros
                // idiomas más aún); sin él la fila desborda.
                Flexible(child: action),
              ],
            ),
    );
  }
}

/// Botón de compra (rediseño Duolingo 7.0): UN SOLO color en toda
/// la pantalla — azul #1CB0F6 con labio más oscuro — para comprar
/// y para equipar. El texto lleva el precio dentro ("COMPRAR ·
/// 200", con icono de estrella), 17 pt peso 800 en mayúsculas.
/// Se le pasa `shine: false` al DuoButton actual (cara sólida,
/// sin degradado ni brillo): la Zona A lo reescribe con esa cara
/// por defecto, así que el parámetro es temporal.
class _BuyButton extends StatelessWidget {
  const _BuyButton({
    required this.label,
    required this.onPressed,
    required this.withStar,
  });

  final String label;
  final VoidCallback onPressed;
  final bool withStar;

  static const _buyBlue = Color(0xFF1CB0F6);
  static const _buyBlueLip = Color(0xFF1899D6);

  @override
  Widget build(BuildContext context) {
    return DuoButton.primary(
      label: label,
      onPressed: onPressed,
      topColor: _buyBlue,
      bottomColor: _buyBlue,
      edgeColor: _buyBlueLip,
      icon: withStar ? LucideIcons.star : null,
      fontSize: 17,
      shine: false,
    );
  }
}

/// Chip de estado (rediseño Duolingo 7.0): plano, sin degradado y
/// sin sombra. Equipado = teal sólido con texto blanco en negrita
/// (regla 7); "Te faltan X puntos" = transparente con borde
/// neutro. Alto fijo 56 pt: igual que el botón de compra con
/// fuente 17, así todas las tarjetas de la pantalla miden
/// exactamente lo mismo tengan botón o chip (regla 8).
class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.filled});
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final accent = AppAccent.primary;
    return Container(
      height: 56,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: filled ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: filled
            ? null
            : Border.all(color: const Color(0xFFE5E5E5), width: 2),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: filled
              ? Colors.white
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
