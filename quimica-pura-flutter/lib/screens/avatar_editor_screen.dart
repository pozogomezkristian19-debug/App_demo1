// Editor de avatar (Quemia 7.1, alcance 9): galería de avatares
// predefinidos estilo la cuenta de Microsoft de Minecraft —
// rejilla de caras, la elegida queda marcada con aro teal y
// check. Se abre tocando el círculo grande de la cabecera de
// Cuenta (que ya NO es la compañera del día).
//
// Libres: neutro, Brenda, Britany y Kristian (los assets de foto
// que ya existen). Premium: dorado, violeta y teal, del catálogo
// de la tienda: solo se pueden elegir si ya se compraron; si no,
// se ven bloqueados (foto atenuada + candado) y al tocarlos se
// abre la Tienda. Elegir equipa con SocialService.equipItem —
// mismo campo equippedAvatar local y misma sincronización que los
// premium — así el avatar se ve en Cuenta, Amigos, tabla y
// torneos. El avatar por defecto va según el género del
// onboarding (Femenino → Brenda, Masculino → Kristian, sin
// género → neutro).

import 'package:flutter/material.dart';

import '../services/accent.dart';
import '../services/localization.dart';
import '../services/social_service.dart';
import '../services/sound_service.dart';
import '../services/user_prefs.dart';
import '../widgets/lucide_icons.dart';

/// Colores del editor según el tema: los mismos que Cuenta y
/// Ajustes (fondo blanco y tinta #4B4B4B en claro; fondo y
/// tarjetas oscuros según el acento en oscuro).
class _AvatarColors {
  const _AvatarColors({
    required this.bg,
    required this.ink,
    required this.inkSoft,
  });

  factory _AvatarColors.of(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return _AvatarColors(
        bg: AppAccent.darkBackground,
        ink: Colors.white,
        inkSoft: AppAccent.darkInkSoft,
      );
    }
    return const _AvatarColors(
      bg: Colors.white,
      ink: Color(0xFF4B4B4B),
      inkSoft: Color(0xFF777777),
    );
  }

  final Color bg;
  final Color ink;
  final Color inkSoft;
}

/// Un avatar de la galería: id (el que se guarda en
/// equippedAvatar), nombre que se muestra y asset de la foto.
class _GalleryAvatar {
  const _GalleryAvatar({
    required this.id,
    required this.name,
    required this.asset,
    required this.premium,
  });

  final String id;
  final String name;
  final String asset;

  /// true = premium de la tienda (bloqueado si no se compró).
  final bool premium;
}

class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen({
    super.key,
    required this.onOpenScreen,
  });

  /// Abre una pantalla por su clave ('shop' para los premium
  /// bloqueados). Lo resuelve HomeScreen con _openScreenKey,
  /// igual que las filas de Cuenta.
  final void Function(String key) onOpenScreen;

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  /// Ids de tienda ya comprados (para los premium).
  var _owned = <String>{};

  /// Id del avatar que se muestra como elegido (el equipado, o el
  /// de por defecto según el género si no hay ninguno).
  var _selectedId =
      SocialService.displayAvatarIdForGender(UserPrefs.userGender);

  /// Al volver de la Tienda hay que recargar lo comprado: el
  /// premium que se acaba de comprar ya no sale bloqueado.
  var _needsOwnedReload = false;

  @override
  void initState() {
    super.initState();
    _loadOwned();
  }

  Future<void> _loadOwned() async {
    // Se baja la bandera antes de esperar: si build vuelve a
    // correr mientras carga, no se lanza otra carga encima.
    _needsOwnedReload = false;
    final owned = await SocialService.ownedItemIds();
    if (!mounted) return;
    setState(() {
      _owned = owned;
    });
  }

  /// La galería: primero los 4 libres, luego los 3 premium del
  /// catálogo de la tienda (mismo orden que en la Tienda).
  List<_GalleryAvatar> get _gallery {
    const freeNames = {
      'avatar_default': 'Neutro',
      'avatar_brenda': 'Brenda',
      'avatar_britany': 'Britany',
      'avatar_kristian': 'Kristian',
    };
    final items = <_GalleryAvatar>[
      for (final e in SocialService.freeAvatarAssets.entries)
        _GalleryAvatar(
          id: e.key,
          name: freeNames[e.key] ?? e.key,
          asset: e.value,
          premium: false,
        ),
      for (final item
          in kShopCatalog.where((i) => i.kind == 'avatar'))
        _GalleryAvatar(
          id: item.id,
          name: item.name,
          asset: item.asset ?? 'assets/avatar_teal.png',
          premium: true,
        ),
    ];
    return items;
  }

  /// Tocar un avatar: si es libre o ya comprado, se equipa al
  /// instante (mismo campo que los premium); si es premium y está
  /// bloqueado, se abre la Tienda.
  Future<void> _onTileTap(_GalleryAvatar avatar) async {
    SoundService.tap();
    if (avatar.premium && !_owned.contains(avatar.id)) {
      // Al volver de la Tienda, recargar lo comprado.
      _needsOwnedReload = true;
      widget.onOpenScreen('shop');
      return;
    }
    final item = avatar.premium
        ? kShopCatalog.firstWhere((i) => i.id == avatar.id)
        : ShopItem(
            id: avatar.id,
            name: avatar.name,
            kind: 'avatar',
            price: 0,
            asset: avatar.asset,
          );
    await SocialService.equipItem(item);
    if (!mounted) return;
    setState(() {
      _selectedId = avatar.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Al volver de la Tienda (la ruta de encima se cierra y esta
    // se repinta), recargar lo comprado para que el premium
    // comprado ya no salga bloqueado.
    if (_needsOwnedReload) _loadOwned();
    final c = _AvatarColors.of(context);
    final gallery = _gallery;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(tr('avatarTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            tr('avatarSub'),
            style: TextStyle(fontSize: 16, color: c.inkSoft),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 20,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: gallery.length,
            itemBuilder: (context, index) {
              final avatar = gallery[index];
              final selected = avatar.id == _selectedId;
              final locked =
                  avatar.premium && !_owned.contains(avatar.id);
              return _AvatarTile(
                avatar: avatar,
                selected: selected,
                locked: locked,
                onTap: () => _onTileTap(avatar),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Una cara de la galería: foto circular de 84 dp con su nombre
/// debajo. La elegida lleva aro teal de 3 pt + check; la premium
/// bloqueada, foto atenuada + candado.
class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.avatar,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final _GalleryAvatar avatar;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = _AvatarColors.of(context);
    // Quemia 7.3: el aro + check de la elegida siguen al acento
    // (antes teal fijo también con el tema violeta).
    final teal = AppAccent.primary;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? teal : Colors.transparent,
                    width: 3,
                  ),
                ),
                alignment: Alignment.center,
                child: Opacity(
                  opacity: locked ? 0.45 : 1.0,
                  child: ClipOval(
                    child: Image.asset(
                      avatar.asset,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: teal,
                    ),
                    alignment: Alignment.center,
                    child: const LucideIcon(
                      LucideIcons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (locked)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4B4B4B),
                    ),
                    alignment: Alignment.center,
                    child: const LucideIcon(
                      LucideIcons.lock,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            avatar.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
        ],
      ),
    );
  }
}
