// Animación de perfil (Quemia 7.9): la Lottie que va a la
// derecha de la foto en la cabecera del perfil (mockup v3:
// dragón dorado a la derecha, foto a la izquierda).
//
// - SIEMPRE sin fondo: la Lottie es transparente y flota, sin
//   caja. El cuadro es FIJO (mismo alto que la foto) y no puede
//   romper la pantalla ni chocar con el lapicito de cambiar el
//   avatar (ese vive dentro de la foto; la animación va separada
//   con un hueco).
// - La animación es REMOTA (`imageUrl` del artículo, el JSON
//   Lottie): se descarga y queda en caché en disco
//   (ShopImageCache, igual que las fotos remotas). Sin URL, sin
//   descargar o con el archivo roto, el cuadro enseña un icono
//   de destellos — nunca un cuadro roto ni un hueco vacío.
// - Suena UNA sola vez al aparecer y luego se queda quieta
//   (Kristian 2026-11-14: la animación es al abrir o ir a ese
//   apartado; después, en esa pantalla, está quieta). En pruebas
//   no anima: queda fija en el cuadro de descanso para que las
//   fotos sean deterministas.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../services/platform_check.dart';
import '../services/remote_shop_catalog.dart';
import '../services/shop_item.dart';
import 'lucide_icons.dart';

/// La animación de perfil en su espacio fijo: un cuadro del mismo
/// alto que la foto, sin fondo. [animation] es el artículo de la
/// tienda (kind 'animation'); su `imageUrl` es el JSON Lottie.
class ProfileAnimation extends StatefulWidget {
  const ProfileAnimation({
    super.key,
    required this.animation,
    required this.size,
  });

  final ShopItem animation;

  /// Lado del cuadro (mismo alto que la foto del perfil).
  final double size;

  @override
  State<ProfileAnimation> createState() => _ProfileAnimationState();
}

class _ProfileAnimationState extends State<ProfileAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  File? _file;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ProfileAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation.imageUrl != widget.animation.imageUrl) {
      _file = null;
      _ctrl.value = 0;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final url = widget.animation.imageUrl;
    if (url == null || url.isEmpty) return;
    final file = await ShopImageCache.ensureCached(url);
    if (!mounted) return;
    setState(() => _file = file);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: file == null
          ? _Placeholder(size: widget.size)
          : Lottie.file(
              file,
              controller: _ctrl,
              fit: BoxFit.contain,
              onLoaded: (composition) {
                _ctrl.duration = composition.duration;
                if (isFlutterTest) {
                  _ctrl.value = 1.0;
                } else if (!_ctrl.isAnimating && _ctrl.value == 0) {
                  _ctrl.animateTo(1.0).then((_) {
                    if (mounted) _ctrl.value = 1.0;
                  });
                }
              },
              errorBuilder: (context, error, stackTrace) =>
                  _Placeholder(size: widget.size),
            ),
    );
  }
}

/// El cuadro mientras la animación no está (sin URL, sin
/// descargar, archivo roto): destellos ámbar, sin caja ni borde.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LucideIcon(
        LucideIcons.sparkles,
        size: size * 0.4,
        color: const Color(0xFFFFC800),
      ),
    );
  }
}

/// Cabecera de perfil DINÁMICA (Cuenta + perfil público, Kristian
/// 2026-11-17):
/// - Sin animación equipada: el avatar CENTRADO (perfil normal,
///   como hoy).
/// - Con animación equipada: avatar con su marco a la IZQUIERDA y
///   animación a la DERECHA, del mismo alto que la foto, con un
///   hueco entre ambos para que no choquen con el lapicito.
/// El tamaño se adapta al ancho disponible: en un teléfono
/// angosto la foto y la animación se achican juntas, nunca se
/// salen de la pantalla.
///
/// [avatar] construye el círculo del avatar con el tamaño dado
/// (la foto con su marco y su lapicito). [resolveAnimation]
/// devuelve la animación equipada (o null); [animationListenable]
/// es el notifier que avisa cuando cambia lo equipado (en Cuenta,
/// `SocialService.equippedAnimationIdNotifier`): la cabecera
/// repinta al instante al equipar o quitar la animación.
class ProfileHeaderAvatar extends StatefulWidget {
  const ProfileHeaderAvatar({
    super.key,
    required this.avatar,
    required this.resolveAnimation,
    this.animationListenable,
    this.size = 160,
    this.gap = 16,
  });

  final Widget Function(double size) avatar;
  final ShopItem? Function() resolveAnimation;
  final Listenable? animationListenable;

  /// Diámetro de la foto sin animación (160 dp en Cuenta).
  final double size;

  /// Hueco entre la foto y la animación.
  final double gap;

  @override
  State<ProfileHeaderAvatar> createState() => _ProfileHeaderAvatarState();
}

class _ProfileHeaderAvatarState extends State<ProfileHeaderAvatar> {
  @override
  void initState() {
    super.initState();
    widget.animationListenable?.addListener(_onAnimationChanged);
    RemoteShopCatalog.catalogVersion.addListener(_onAnimationChanged);
  }

  void _onAnimationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ProfileHeaderAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationListenable != widget.animationListenable) {
      oldWidget.animationListenable?.removeListener(_onAnimationChanged);
      widget.animationListenable?.addListener(_onAnimationChanged);
    }
  }

  @override
  void dispose() {
    widget.animationListenable?.removeListener(_onAnimationChanged);
    RemoteShopCatalog.catalogVersion.removeListener(_onAnimationChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = widget.resolveAnimation();
    if (animation == null) {
      return Center(child: widget.avatar(widget.size));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        // La fila es: avatar CON su marco + hueco + animación.
        // El avatar con marco es más ancho que la foto: el Dorado
        // (el marco más grueso) mide 1.294 × la foto, así que la
        // fila necesita s × (1.294 + 1) + hueco ≤ disponible, o sea
        // s ≤ (disponible − hueco) / 2.3. Con / 2 se salía 22 px
        // a la derecha en un teléfono de 393 dp y el dragón
        // quedaba fuera de la pantalla (2026-11-18).
        final side = available.isFinite
            ? (available - widget.gap) / 2.3
            : widget.size;
        final s = side < widget.size ? side : widget.size;
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            widget.avatar(s),
            SizedBox(width: widget.gap),
            ProfileAnimation(animation: animation, size: s),
          ],
        );
      },
    );
  }
}
