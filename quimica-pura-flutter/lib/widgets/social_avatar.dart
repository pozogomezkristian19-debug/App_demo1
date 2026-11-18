// Avatar con CARA, nunca con inicial (rediseño Duolingo 7.0,
// Zona A, §0 regla 3 y §3.5.7): Duolingo jamás muestra un círculo
// con una letra. Sin foto premium, el disco es la cara por defecto
// `assets/avatar_default.png`.
//
// RANGO (diseño 7.0): con [rank] el avatar muestra el rango en la
// tabla de posiciones — 1º marco dorado + corona, 2º marco
// plateado + medalla de plata, 3º marco bronce + medalla de
// bronce, 4º-10º marco del color del acento, 11º en adelante avatar normal.
// Los marcos son anillos PLANOS de 3 px con colores SÓLIDOS
// (oro #FFC800, plata #D6D6D6, bronce #CD7F32, acento):
// sin degradado, sin sombra borrosa.
//
// Las insignias de rango (corona 1º, medalla 2º/3º) y las
// insignias [badgeId] (estrella/trofeo/llama) se quedan, con
// colores sólidos.
//
// La foto premium [avatarAsset] se queda: va dentro del marco de
// rango cuando lo hay. [uniformTeal] se conserva por
// compatibilidad con la API pública pero ya no cambia el disco:
// sin foto, todos usan la misma cara por defecto.
//
// Se mantiene la misma API pública (username, size, avatarAsset,
// badgeId, rank, uniformTeal) para no romper a las demás zonas.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/accent.dart';
import '../services/shop_item.dart';

import 'avatar_frame_ring.dart';
import 'lucide_icons.dart';

class SocialAvatar extends StatelessWidget {
  const SocialAvatar({
    super.key,
    required this.username,
    this.size = 36,
    this.avatarAsset,
    this.avatarImageFile,
    this.badgeId,
    this.rank,
    this.uniformTeal = false,
    this.frameItem,
    this.frameRingWidth = 3,
    this.framePadding,
  });

  final String username;
  final double size;

  /// Foto de avatar premium equipada (asset 'assets/avatar_*.png'),
  /// o null: la cara por defecto `assets/avatar_default.png`.
  final String? avatarAsset;

  /// Foto de avatar REMOTA equipada (ya descargada en la caché en
  /// disco, ShopImageCache): manda sobre [avatarAsset] cuando no
  /// es null. Los avatares nuevos de la tienda (7.3) no tienen
  /// asset empaquetado, solo `imageUrl`.
  final File? avatarImageFile;

  /// 'badge_star' | 'badge_trophy' | 'badge_flame' | 'badge_adn' |
  /// 'badge_atomo' | 'badge_cohete' | 'badge_corona' |
  /// 'badge_gema' | 'badge_rayo' | 'badge_corazon' |
  /// 'badge_medalla', o null sin insignia.
  final String? badgeId;

  /// Puesto en la tabla (1 = oro...): null o > 10 = sin marco de rango.
  final int? rank;

  /// Conservado por compatibilidad con la API: ya no cambia el
  /// disco (sin foto, todos usan la misma cara por defecto).
  final bool uniformTeal;

  /// Marco de la tienda equipado (7.9): se dibuja como anillo 3D
  /// alrededor de la foto, POR FUERA del marco de rango si lo
  /// hay. Null = sin marco. Es el marco que los demás ven: les
  /// sale a todo el mundo igual que el avatar.
  final ShopItem? frameItem;

  /// Grosor del anillo del marco (3 dp en las listas, para que no
  /// se coma el hueco de la fila).
  final double frameRingWidth;

  /// Aire que un marco dibujado FUERA de este widget añade
  /// alrededor de la foto (en dp): solo sirve para colocar la
  /// insignia sobre el borde exterior del disco. En Cuenta el
  /// marco lo dibuja el AvatarFrameRing de fuera, así que aquí
  /// no se vuelve a dibujar (no se pasa [frameItem]), solo se
  /// pasa su aire por aquí. Null = sin marco fuera.
  final double? framePadding;

  /// Color SÓLIDO del marco de rango: oro, plata, bronce o acento.
  Color? get _rankColor => switch (rank ?? 0) {
        1 => const Color(0xFFFFC800),
        2 => const Color(0xFFD6D6D6),
        3 => const Color(0xFFCD7F32),
        >= 4 && <= 10 => AppAccent.primary,
        _ => null,
      };

  /// Insignia del rango: corona para el 1º, medalla para el 2º y 3º.
  LucideIconData? get _rankBadgeIcon => switch (rank) {
        1 => LucideIcons.crown,
        2 || 3 => LucideIcons.award,
        _ => null,
      };

  LucideIconData? get _badgeIconData => switch (badgeId) {
        'badge_star' => LucideIcons.star,
        'badge_trophy' => LucideIcons.trophy,
        'badge_flame' => LucideIcons.flame,
        'badge_adn' => LucideIcons.dna,
        'badge_atomo' => LucideIcons.atom,
        'badge_cohete' => LucideIcons.rocket,
        // Insignias nuevas (2026-11-18).
        'badge_corona' => LucideIcons.crown,
        'badge_gema' => LucideIcons.gem,
        'badge_rayo' => LucideIcons.zap,
        'badge_corazon' => LucideIcons.heart,
        'badge_medalla' => LucideIcons.medal,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final badge = _badgeIconData;
    final rankColor = _rankColor;
    final rankBadgeIcon = _rankBadgeIcon;
    // El disco: la foto premium si la hay (remota cacheada antes
    // que el asset); si no, la cara por defecto. NUNCA una inicial.
    final file = avatarImageFile;
    Widget avatar = ClipOval(
      child: file != null
          ? Image.file(
              file,
              key: ValueKey('social-avatar-$username'),
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            )
          : Image.asset(
              avatarAsset ?? 'assets/avatar_default.png',
              key: ValueKey('social-avatar-$username'),
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
    );
    // Marco de rango: anillo PLANO de 3 px con el color sólido
    // del rango. Sin degradado, sin sombra borrosa.
    if (rankColor != null) {
      avatar = Container(
        width: size + 6,
        height: size + 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: rankColor,
        ),
        alignment: Alignment.center,
        child: avatar,
      );
    }
    // Marco de la tienda (7.9): anillo 3D alrededor de todo (el
    // marco de rango, si lo hay, queda dentro). Les sale a todos.
    final frame = frameItem;
    var extra = 0.0;
    // La foto que envuelve el marco: el avatar con el marco de
    // rango dentro, si lo hay.
    final framedPhotoSize = size + (rankColor != null ? 6 : 0);
    if (frame != null) {
      avatar = AvatarFrameRing(
        frame: frame,
        ringWidth: frameRingWidth,
        photoSize: framedPhotoSize,
        child: avatar,
      );
      // El fuego ocupa más aire que el grosor del anillo; el
      // marco-imagen, una fracción de la foto.
      extra = AvatarFrameRing.paddingFor(frame, frameRingWidth,
              photoSize: framedPhotoSize) *
          2;
    }
    final base = size + (rankColor != null ? 6 : 0) + extra;
    final badgeSize = size * 0.38;
    // Insignia de rango (arriba a la derecha): corona o medalla en
    // su mini-círculo con el color sólido del marco.
    final rankBadge = rankBadgeIcon == null
        ? null
        : Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rankColor,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            alignment: Alignment.center,
            child: LucideIcon(
              rankBadgeIcon,
              size: badgeSize * 0.6,
              // La insignia de plata es clara: el icono va en gris
              // oscuro; en oro, bronce y acento va en blanco.
              color: rank == 2 ? const Color(0xFF424242) : Colors.white,
            ),
          );
    if (badge == null && rankBadge == null) return avatar;
    // La foto va CENTRADA en la caja (2026-11-18: antes quedaba
    // en la esquina y, con marco dibujado fuera, se veía
    // desplazada hacia arriba a la izquierda dentro del disco,
    // con el brillo dorado asomando abajo: el avatar se veía
    // chiquito). El centro del círculo es el centro de la caja.
    final boxSize = base + (badge != null ? badgeSize * 0.4 : 0);
    final circleCenter = boxSize / 2;
    // Radio del borde exterior: sin marco es la foto (base/2);
    // con marco dibujado fuera es la caja/2 + su aire, y con
    // marco dibujado aquí es base/2 (el anillo es la caja).
    final outerRadius = framePadding != null
        ? circleCenter + framePadding!
        : base / 2;
    final badgeCx = circleCenter - outerRadius / math.sqrt(2);
    final badgeCy = circleCenter + outerRadius / math.sqrt(2);
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (rankBadge != null)
            Positioned(
              right: -2,
              top: -2,
              child: rankBadge,
            ),
          if (badge != null)
            // Insignia abajo a la IZQUIERDA (7:30, espejo del
            // lapicito a las 4:30): el CENTRO del chip queda sobre
            // el borde exterior del círculo, mitad fuera y mitad
            // dentro, con el marco pasando por detrás.
            Positioned(
              left: badgeCx - badgeSize / 2,
              top: badgeCy - badgeSize / 2,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF59E0B),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: LucideIcon(
                  badge,
                  size: badgeSize * 0.6,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
