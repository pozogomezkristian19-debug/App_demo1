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

import 'package:flutter/material.dart';
import '../services/accent.dart';

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
  /// 'badge_atomo' | 'badge_cohete', o null sin insignia.
  final String? badgeId;

  /// Puesto en la tabla (1 = oro...): null o > 10 = sin marco de rango.
  final int? rank;

  /// Conservado por compatibilidad con la API: ya no cambia el
  /// disco (sin foto, todos usan la misma cara por defecto).
  final bool uniformTeal;

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
    final badgeSize = size * 0.55;
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
    return SizedBox(
      width: (rankColor != null ? size + 6 : size) +
          (badge != null ? badgeSize * 0.4 : 0),
      height: (rankColor != null ? size + 6 : size) +
          (badge != null ? badgeSize * 0.4 : 0),
      child: Stack(
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
            Positioned(
              right: -2,
              bottom: -2,
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
