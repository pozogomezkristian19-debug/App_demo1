import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/social_service.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/profile_animation.dart';
import '../widgets/social_avatar.dart';
import 'duel_screen.dart';

const _lineLight = Color(0xFFE5E5E5);
const _lineDark = Color(0xFF37464F);

/// Perfil sencillo de un amigo (Kristian 2026-11-15): avatar con
/// cara, nombre, puntos, niveles, racha y trofeos, con botón Retar.
///
/// Se abre al tocar un amigo en la lista de Amigos o en los
/// resultados de la búsqueda. Nunca se abre para quien no es amigo:
/// las filas de no amigos no son táctiles.
class FriendProfileScreen extends StatelessWidget {
  const FriendProfileScreen({
    super.key,
    required this.friend,
    this.isGoogleLinked,
    this.onLinkGoogle,
  });

  final FriendEntry friend;
  final bool? isGoogleLinked;
  final Future<bool> Function()? onLinkGoogle;

  void _challenge(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DuelScreen(
          opponentUsername: friend.username,
          isGoogleLinked: isGoogleLinked,
          onLinkGoogle: onLinkGoogle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final line = isDark ? _lineDark : _lineLight;
    return Scaffold(
      appBar: AppBar(title: Text(tr('friendsProfileTitle'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          children: [
            // Cabecera DINÁMICA (7.9): sin animación, el avatar con
            // su marco va CENTRADO; con animación, avatar+marco a
            // la IZQUIERDA y animación a la DERECHA. Todo les sale
            // a todos, igual que el avatar.
            ProfileHeaderAvatar(
              size: 96,
              resolveAnimation: () => friend.animationItem,
              avatar: (s) => SocialAvatar(
                username: friend.username,
                avatarAsset: friend.avatarAsset,
                badgeId: friend.badgeId,
                frameItem: friend.frameItem,
                frameRingWidth: 6,
                size: s,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              friend.username,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _StatRow(
              icon: LucideIcons.star,
              color: const Color(0xFFF59E0B),
              label: tr('pointsWord'),
              value: '${friend.points}',
            ),
            Divider(height: 1, thickness: 1, color: line),
            _StatRow(
              icon: LucideIcons.layers,
              color: const Color(0xFF8B5CF6),
              label: tr('lbLevels'),
              value: '${friend.levelsPassedTotal}',
            ),
            Divider(height: 1, thickness: 1, color: line),
            _StatRow(
              icon: LucideIcons.flame,
              color: const Color(0xFFF97316),
              label: tr('streakWord'),
              value: '${friend.streak}',
            ),
            if (friend.trophiesTotal > 0) ...[
              Divider(height: 1, thickness: 1, color: line),
              _StatRow(
                icon: LucideIcons.trophy,
                color: const Color(0xFFF59E0B),
                label: tr('trophiesWord'),
                value: '${friend.trophiesWon}/${friend.trophiesTotal}',
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: DuoButton.primary(
                label: tr('friendsChallenge').toUpperCase(),
                onPressed: () => _challenge(context),
                shine: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final LucideIconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          LucideIcon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
