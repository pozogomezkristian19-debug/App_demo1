// Tienda de puntos (Quemia 7.3; rediseño Duolingo 7.0, Zona C,
// catálogo remoto 7.3):
// gastar los puntos en cosméticos (temas/colores, fotos de avatar
// premium, insignias de perfil y marcos de avatar). Solo
// cosmético, nada de pagar para ganar. La compra se guarda en
// local y se sincroniza cuando hay backend; los temas equipados
// cambian el acento de la app, la foto de avatar equipada es la
// foto del usuario (Cuenta, Amigos, tabla) y el marco equipado es
// el anillo alrededor de esa foto. Sin Google, la puerta.
//
// CATÁLOGO 7.3: remoto (Firestore 'shop_items', con caché local
// y respaldo offline `kShopCatalog`). Los artículos nuevos traen
// `imageUrl`: la foto se descarga y queda en caché en disco
// (ShopImageCache); sin internet o sin descargar, la tarjeta
// muestra una cara por defecto — nunca un cuadro roto.
//
// DISEÑO 7.3 (mockup del agente de diseño): un solo azul de
// compra (#1CB0F6) en toda la pantalla, con el precio dentro del
// botón ("COMPRAR · 200"); tarjetas con borde neutro 2 pt #E5E5E5
// (sin borde en oscuro), radio 16, sin sombra; TODAS las tarjetas
// con la misma estructura — arriba vista previa + nombre, abajo
// la acción a ancho completo — para que midan exactamente lo
// mismo; avatares premium grandes (120 dp) con nombre y frase
// graciosa; "Tus puntos" como chip del HUD (estrella + número).

import 'dart:io';

import 'package:flutter/material.dart';
import '../services/accent.dart';

import '../services/localization.dart';
import '../services/progress.dart';
import '../services/remote_shop_catalog.dart';
import '../services/social_service.dart';
import '../services/user_prefs.dart';
import '../widgets/avatar_frame_ring.dart';
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
  String? _equippedFrameId;

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
    final frame = await SocialService.equippedItemId('frame');
    if (!mounted) return;
    setState(() {
      _online = online;
      _owned = owned;
      _equippedThemeId = theme;
      _equippedAvatarId = avatar;
      _equippedBadgeId = badge;
      _equippedFrameId = frame;
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
                  // Las recompensas de referidos (referralOnly) no
                  // se venden aquí: solo se consiguen invitando
                  // amigos (ver referral_rewards.dart).
                  final items = (snapshot.data ?? [])
                      .where((i) => !i.referralOnly)
                      .toList();
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
                      if (items.any((i) => i.kind == 'frame')) ...[
                        _SectionTitle(text: tr('shopFrames')),
                        for (final item in items.where((i) => i.kind == 'frame'))
                          _ItemCard(
                            item: item,
                            points: points,
                            owned: _owned.contains(item.id),
                            equipped: _equippedFrameId == item.id,
                            onBuy: () => _buy(item),
                            onEquip: () => _equip(item),
                          ),
                      ],
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

/// Foto de avatar de la tienda (7.3): el asset empaquetado si lo
/// hay; si no, la foto remota (`imageUrl`) ya descargada en la
/// caché en disco; si aún no se descargó o no hay internet, una
/// CARA por defecto (regla 5: nunca iniciales). La tarjeta nunca
/// queda sin imagen ni con un cuadro roto.
class _AvatarPhoto extends StatefulWidget {
  const _AvatarPhoto({required this.item, required this.size});

  final ShopItem item;
  final double size;

  @override
  State<_AvatarPhoto> createState() => _AvatarPhotoState();
}

class _AvatarPhotoState extends State<_AvatarPhoto> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _AvatarPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.imageUrl != widget.item.imageUrl ||
        oldWidget.item.asset != widget.item.asset) {
      _file = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final url = widget.item.imageUrl;
    if (url == null || url.isEmpty) return;
    final file = await ShopImageCache.ensureCached(url);
    if (!mounted) return;
    setState(() => _file = file);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final size = widget.size;
    final file = _file;
    final Widget image;
    if (item.asset != null) {
      image = Image.asset(
        item.asset!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    } else if (file != null) {
      image = Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    } else {
      image = Image.asset(
        'assets/avatar_default.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    }
    return ClipOval(child: image);
  }
}

/// Tarjeta de producto (rediseño Duolingo 7.0, estructura 7.3 del
/// mockup): borde neutro 2 pt #E5E5E5, radio 16, sin sombra y sin
/// bordes tintados por producto. TODAS las tarjetas tienen la
/// misma estructura — arriba vista previa + nombre (y frase en
/// avatares), abajo la acción a ancho completo — para que las de
/// cada sección midan exactamente lo mismo (regla 8). El precio ya
/// no va en una línea aparte: vive dentro del botón de compra
/// ("COMPRAR · 200"). Los avatares premium se ven GRANDES (foto a
/// 120 dp) con su nombre y una frase graciosa debajo.
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

  /// Frase graciosa de cada avatar premium (respaldo: el catálogo
  /// remoto ya trae `description`; esto solo cubre un artículo sin
  /// descripción).
  static const _avatarJokes = <String, String>{
    'avatar_dorado':
        'El rey de la química. Solo para los que llegan a 200 puntos.',
    'avatar_violeta':
        'Violeta como Brenda. Para que te vean desde la última fila.',
    'avatar_teal': 'Teal como la app. Discreto por fuera, crack por dentro.',
  };

  static const _line = Color(0xFFE5E5E5);

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

  /// Icono de la insignia (7.3: ADN, átomo y cohete se suman a
  /// estrella, trofeo y llama).
  LucideIconData _badgeIconData() => switch (item.badgeIcon) {
        'trophy' => LucideIcons.trophy,
        'flame' => LucideIcons.flame,
        'dna' => LucideIcons.dna,
        'atom' => LucideIcons.atom,
        'rocket' => LucideIcons.rocket,
        _ => LucideIcons.star,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget preview;
    if (item.kind == 'avatar') {
      // La foto premium en venta, completa y GRANDE (120 dp): el
      // producto ES la foto, no un marco.
      preview = _AvatarPhoto(item: item, size: 120);
    } else if (item.kind == 'badge') {
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
        child: LucideIcon(_badgeIconData(),
            size: 22, color: const Color(0xFF4B4B4B)),
      );
    } else if (item.kind == 'frame') {
      // Vista previa del marco: el anillo alrededor de una foto
      // (la del avatar dorado, como en el mockup). Foto de 36 dp +
      // anillo de 4 dp = 44 dp, igual que el resto de vistas
      // previas de fila.
      preview = AvatarFrameRing(
        frame: item,
        ringWidth: 4,
        child: ClipOval(
          child: Image.asset(
            'assets/avatar_dorado.png',
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
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
    final action = _action(context);
    final description =
        item.description.isNotEmpty ? item.description : (_avatarJokes[item.id] ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        // Sin borde en oscuro (Kristian, 2026-11-13).
        border: isDark
            ? null
            : Border.all(
                color: _line,
                width: 2,
              ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              preview,
              const SizedBox(width: 12),
              Expanded(
                child: item.kind == 'avatar'
                    ? Column(
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
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      )
                    : Text(
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
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: action),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 56,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: filled ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: filled
            ? null
            // Borde según el tema (auditoría 7.2).
            : Border.all(
                color: isDark ? AppAccent.darkBorder : const Color(0xFFE5E5E5),
                width: 2),
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
