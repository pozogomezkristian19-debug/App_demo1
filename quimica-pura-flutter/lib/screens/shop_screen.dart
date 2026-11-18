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
import '../widgets/icon_animations.dart';
import '../services/accent.dart';
import 'buy_points_screen.dart';

import '../services/localization.dart';
import '../services/progress.dart';
import '../services/remote_shop_catalog.dart';
import '../services/social_service.dart';
import '../services/sound_service.dart';
import '../services/user_prefs.dart';
import '../widgets/avatar_frame_ring.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/online_gate.dart';
import '../widgets/profile_animation.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final online = await SocialService.online;
    if (!mounted) return;
    setState(() => _online = online);
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
                  // (2026-11-18, Kristian): la casilla
                  // Animación solo sale cuando hay al menos
                  // una animación ACTIVA en el catálogo.
                  // Sin animaciones la opción queda oculta;
                  // al subir una, la casilla aparece sola
                  // al reabrir la Tienda. Las demás
                  // secciones salen siempre.
                  final sections = _ShopSection.values
                      .where(
                        (s) =>
                            s != _ShopSection.animations ||
                            items.any((i) => i.kind == 'animation'),
                      )
                      .toList();
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
                      // Comprar puntos (2026-11-17, compra real):
                      // tarjeta arriba de la tienda que abre la
                      // pantalla de paquetes por Transfermóvil.
                      _BuyPointsCard(
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BuyPointsScreen(),
                          ),
                        ),
                      ),
                      // Rejilla de secciones (7.9, mockup aprobado):
                      // una tarjetica por sección — Temas, Avatares,
                      // Insignias, Marcos y Animación en el perfil —
                      // cada una abre su sección con sus artículos.
                      // Así cada cosa va separada y organizada, y la
                      // Tienda ya no es una lista larga de todo.
                      // Altura FIJA (200 dp) en vez de proporción:
                      // con childAspectRatio la casilla se quedaba
                      // 1 px corta en pantallas estrechas y el
                      // contenido se desbordaba.
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 200,
                        ),
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                        itemCount: sections.length,
                        itemBuilder: (context, index) {
                          final section = sections[index];
                          return _SectionTile(
                            section: section,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _ShopSectionScreen(
                                  section: section,
                                  items: items
                                      .where((i) => i.kind == section.kind)
                                      .toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

/// Secciones de la Tienda (7.9): una tarjetica por sección en la
/// rejilla. El `kind` es el del artículo (`ShopItem.kind`).
enum _ShopSection {
  themes('theme'),
  avatars('avatar'),
  badges('badge'),
  frames('frame'),
  animations('animation');

  const _ShopSection(this.kind);

  final String kind;

  String title(BuildContext context) => switch (this) {
        _ShopSection.themes => tr('shopThemes'),
        _ShopSection.avatars => tr('shopAvatars'),
        _ShopSection.badges => tr('shopBadges'),
        _ShopSection.frames => tr('shopFrames'),
        _ShopSection.animations => tr('shopAnimations'),
      };

  String subtitle(BuildContext context) => switch (this) {
        _ShopSection.themes => tr('shopThemesDesc'),
        _ShopSection.avatars => tr('shopAvatarsDesc'),
        _ShopSection.badges => tr('shopBadgesDesc'),
        _ShopSection.frames => tr('shopFramesDesc'),
        _ShopSection.animations => tr('shopAnimationsDesc'),
      };

  /// Icono y color del chip (mockup aprobado: gota violeta,
  /// cara azul, trofeo amarillo, imagen teal; la animación lleva
  /// destellos naranjas).
  (LucideIconData, Color) get chip => switch (this) {
        _ShopSection.themes => (LucideIcons.droplet, const Color(0xFF8B5CF6)),
        _ShopSection.avatars => (LucideIcons.smile, const Color(0xFF3B82F6)),
        _ShopSection.badges => (LucideIcons.trophy, const Color(0xFFFFC800)),
        _ShopSection.frames => (LucideIcons.image, const Color(0xFF00C2A8)),
        _ShopSection.animations =>
          (LucideIcons.sparkles, const Color(0xFFFF9600)),
      };
}

/// Tarjetica de sección (mockup aprobado): verde en oscuro, blanca
/// con borde en claro; arriba el chip del icono, debajo el título
/// en negrita y la frase. Al tocarla abre su sección.
class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section, required this.onTap});

  final _ShopSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (icon, chipColor) = section.chip;
    final ink = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final subInk = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          SoundService.tap();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2E7D52) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isDark
                ? null
                : Border.all(color: const Color(0xFFE5E5E5), width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: LucideIcon(icon, size: 30, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                section.title(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                section.subtitle(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: subInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla de una sección de la Tienda: los artículos de ese tipo
/// con sus tarjetas de siempre (comprar / equipar / quitar).
/// Carga sus propias compras y lo equipado, así al volver a la
/// rejilla no hace falta recargar nada.
class _ShopSectionScreen extends StatefulWidget {
  const _ShopSectionScreen({required this.section, required this.items});

  final _ShopSection section;
  final List<ShopItem> items;

  @override
  State<_ShopSectionScreen> createState() => _ShopSectionScreenState();
}

class _ShopSectionScreenState extends State<_ShopSectionScreen> {
  var _owned = <String>{};
  String? _equippedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final owned = await SocialService.ownedItemIds();
    final equipped =
        await SocialService.equippedItemId(widget.section.kind);
    if (!mounted) return;
    setState(() {
      _owned = owned;
      _equippedId = equipped;
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

  /// Quita lo equipado (animación, marco, insignia...): vuelve al
  /// perfil normal. La compra no se pierde.
  Future<void> _unequip(ShopItem item) async {
    await SocialService.unequipItem(item.kind);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final points = ProgressService.instance.points;
    final items = widget.items;
    return Scaffold(
      // Flecha de atrás de Lucide, no la de Material: la de
      // Material sale como un cuadradito ▯ en las fotos de prueba
      // (la fuente de iconos no carga en goldens).
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('shopSectionBack'),
          icon: const LucideIcon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.section.title(context)),
      ),
      body: items.isEmpty
          ? _CalmLine(
              text: widget.section == _ShopSection.animations
                  ? tr('shopNoAnimations')
                  : tr('shopEmpty'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
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
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final (i, item) in items.indexed)
                  FadeSlideIn(
                    delay: Duration(milliseconds: (i * 40).clamp(0, 400)),
                    child: RepaintBoundary(
                      child: _ItemCard(
                        item: item,
                        points: points,
                        owned: _owned.contains(item.id),
                        equipped: _equippedId == item.id,
                        onBuy: () => _buy(item),
                        onEquip: () => _equip(item),
                        onUnequip: () => _unequip(item),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Tarjeta "Comprar puntos" arriba de la Tienda (2026-11-17): abre
/// la pantalla de paquetes por Transfermóvil. La compra es real:
/// la solicitud va a Firestore y Kristian la aprueba (o niega).
/// Textos en español directo; se localizan en 6 idiomas cuando se
/// elija el diseño final.
class _BuyPointsCard extends StatelessWidget {
  const _BuyPointsCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: isDark ? AppAccent.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color:
                isDark ? AppAccent.darkBorder : const Color(0xFFE5E5E5),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const LucideIcon(
                    LucideIcons.star,
                    size: 28,
                    color: Color(0xFFFFC800),
                    filled: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¿Te faltan puntos?',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Compra puntos con Transfermóvil',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DuoButton.primary(
                label: 'COMPRAR PUNTOS',
                onPressed: onOpen,
              ),
            ],
          ),
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
    required this.onUnequip,
  });

  final ShopItem item;
  final int points;
  final bool owned;
  final bool equipped;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  /// Quita lo equipado (al tocar el chip "Equipado"): vuelve al
  /// perfil normal. La compra no se pierde.
  final VoidCallback onUnequip;

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

  /// Botón de acción del producto: equipado = chip "Equipado"
  /// (TOCABLE: lo quita y vuelve al perfil normal); comprado =
  /// "EQUIPAR"; sin comprar y con puntos = "COMPRAR · precio";
  /// sin puntos = SOLO el precio (Quemia 7.7, Kristian:
  /// que no diga "Te faltan X puntos", que ponga un precio y ya).
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
      label: '${item.price}',
      filled: false,
      withStar: true,
      // El precio lleva el color del artículo (cada tema con su
      // color: Coral naranja, Rosa rosa, Azul azul…).
      color: item.color == null ? null : Color(item.color!),
    );
  }

  /// Icono de la insignia (7.3: ADN, átomo y cohete se suman a
  /// estrella, trofeo y llama; 2026-11-18: corona, gema, rayo,
  /// corazón y medalla).
  LucideIconData _badgeIconData() => switch (item.badgeIcon) {
        'trophy' => LucideIcons.trophy,
        'flame' => LucideIcons.flame,
        'dna' => LucideIcons.dna,
        'atom' => LucideIcons.atom,
        'rocket' => LucideIcons.rocket,
        'crown' => LucideIcons.crown,
        'gem' => LucideIcons.gem,
        'zap' => LucideIcons.zap,
        'heart' => LucideIcons.heart,
        'medal' => LucideIcons.medal,
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
      // Vista previa del marco: el anillo 3D alrededor de una foto
      // (la del avatar dorado, como en el mockup). La foto mide 32
      // dp en todos los marcos; el dorado y el fuego son la foto
      // de referencia recortada, y su aire es una fracción de la
      // foto (medido en la foto misma).
      preview = AvatarFrameRing(
        frame: item,
        ringWidth: 6,
        photoSize: 32,
        child: ClipOval(
          child: Image.asset(
            'assets/avatar_dorado.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
    } else if (item.kind == 'animation') {
      // Vista previa de la animación: la Lottie en 44 dp (o el
      // icono de destellos mientras no se descarga). Sin fondo.
      preview = ProfileAnimation(animation: item, size: 44);
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
    final description = item.description.isNotEmpty
        ? item.description
        : (_avatarJokes[item.id] ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              // Quitar lo equipado (7.9): al tocarlo se quita el
              // artículo y el perfil vuelve a lo normal. La compra
              // no se pierde: se puede volver a equipar.
              if (equipped)
                TextButton(
                  onPressed: onUnequip,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    tr('shopUnequip'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurfaceVariant,
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
/// (regla 7); precio sin puntos = SÓLIDO con el color del artículo
/// (Quemia 7.7, Kristian 2026-11-13: los botones de precio en
/// blanco estaban feos; cada cosa con el color de su tema — el de
/// Coral naranja, el de Rosa rosa, el de Azul azul…), estrella y
/// precio en blanco, con labio 4 pt más oscuro del mismo color.
/// Alto fijo 56 pt: igual que el botón de compra con fuente 17, así
/// todas las tarjetas de la pantalla miden exactamente lo mismo
/// tengan botón o chip (regla 8).
class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.label,
    required this.filled,
    this.withStar = false,
    this.color,
  });
  final String label;
  final bool filled;
  final bool withStar;

  /// Color del artículo: si viene, el chip es sólido con ese color
  /// (precio según el tema). Si no viene, manda `filled` (teal) o
  /// el estilo transparente con borde.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = AppAccent.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Fondo: color del artículo si lo hay; si no, teal si es
    // "Equipado", transparente si no.
    final bg = color ?? (filled ? accent : null);
    final ink = bg != null
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;
    // Labio 4 pt más oscuro del mismo color (estilo Duolingo).
    final lip = bg == null ? null : Color.lerp(bg, Colors.black, 0.18);
    return Container(
      height: 56,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg ?? Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: bg != null
            ? Border(bottom: BorderSide(color: lip!, width: 4))
            : (filled
                ? null
                // Borde según el tema (auditoría 7.2).
                : Border.all(
                    color:
                        isDark ? AppAccent.darkBorder : const Color(0xFFE5E5E5),
                    width: 2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (withStar) ...[
            LucideIcon(LucideIcons.star, size: 18, color: ink),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
