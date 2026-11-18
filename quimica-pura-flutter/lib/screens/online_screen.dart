// Pantalla Online (2026-11-17, reorganización de Kristian):
// TODO lo online en un solo sitio, con la barra de abajo (el
// mundito). NO es una lista de botones uno debajo del otro como
// siempre (Kristian 2026-11-17): arriba las sugerencias de
// amigos que se deslizan, debajo una REJILLA de 2 columnas con
// Estadísticas, Amigos, Tabla de posiciones, Torneos, Referidos,
// Tienda y Canjear código. Amigos, Tabla y Torneos solo salen
// con sesión (igual que en Cuenta); Estadísticas, Referidos,
// Tienda y Canjear salen también de invitado. De invitado, en
// lugar de las sugerencias, sale una tarjeta que invita a crear
// el perfil: al tocarla se abre el MISMO inicio de la app
// (Google, entrar con correo o registrarse con correo).
import 'package:flutter/material.dart';

import '../services/accent.dart';
import '../services/auth_service.dart';
import '../services/localization.dart';
import '../services/sound_service.dart';
import '../widgets/duo_button.dart';
import '../widgets/friend_suggestions.dart';
import '../widgets/lucide_icons.dart';
import 'onboarding_screen.dart';
import 'public_profile_screen.dart';

/// Una casilla de la rejilla: icono, título, subtítulo y la
/// pantalla que abre por su clave (_openScreenKey en main).
class _OnlineItem {
  const _OnlineItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.screenKey,
    this.signedInOnly = false,
  });

  final LucideIconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String screenKey;
  final bool signedInOnly;
}

const _violet = Color(0xFF8B5CF6);
const _amber = Color(0xFFF59E0B);
const _rose = Color(0xFFEF4444);

class OnlineScreen extends StatelessWidget {
  const OnlineScreen({super.key, required this.onOpenScreen});

  final void Function(String key) onOpenScreen;

  /// ¿Hay sesión (Google o correo vinculada)? Lo social solo sale
  /// con sesión: sugerencias, Amigos, Tabla y Torneos (Kristian
  /// 2026-11-16, igual que en Cuenta).
  bool get _signedIn =>
      AuthService.isGoogleLinked || AuthService.isEmailLinked;

  void _openPublicProfile(BuildContext context, String uid) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(uid: uid),
      ),
    );
  }

  /// Tarjeta de invitado tocada (Kristian 2026-11-17): el que no
  /// tiene sesión, al tocar Online, ve que le pedimos iniciar
  /// sesión. Se abre el MISMO flujo de inicio de la app
  /// (OnboardingScreen desde Cuenta: elección crear perfil /
  /// entrar con Google / entrar con correo, con registro por
  /// correo incluido), y al terminar se vuelve a Online ya con
  /// la sesión puesta (el cambio de sesión repinta la pantalla
  /// por el listener de authVersion en main).
  void _openSignIn(BuildContext context) {
    SoundService.tap();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingScreen(
          fromAccount: true,
          onFinished: () => Navigator.of(context).pop(),
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  List<_OnlineItem> get _items => [
        _OnlineItem(
          icon: LucideIcons.chartColumn,
          color: _violet,
          title: tr('accountStats'),
          subtitle: tr('accountStatsSub'),
          screenKey: 'stats',
        ),
        _OnlineItem(
          icon: LucideIcons.userRound,
          color: AppAccent.primary,
          title: tr('accountFriends'),
          subtitle: tr('accountFriendsSub'),
          screenKey: 'friends',
          signedInOnly: true,
        ),
        _OnlineItem(
          icon: LucideIcons.trophy,
          color: _amber,
          title: tr('accountLeaderboard'),
          subtitle: tr('accountLeaderboardSub'),
          screenKey: 'leaderboard',
          signedInOnly: true,
        ),
        _OnlineItem(
          icon: LucideIcons.award,
          color: _amber,
          title: tr('accountTournaments'),
          subtitle: tr('accountTournamentsSub'),
          screenKey: 'tournaments',
          signedInOnly: true,
        ),
        _OnlineItem(
          icon: LucideIcons.heart,
          color: _rose,
          title: tr('accountReferrals'),
          subtitle: tr('accountReferralsSub'),
          screenKey: 'referrals',
        ),
        _OnlineItem(
          icon: LucideIcons.shoppingBag,
          color: _violet,
          title: tr('accountShop'),
          subtitle: tr('accountShopSub'),
          screenKey: 'shop',
        ),
        _OnlineItem(
          icon: LucideIcons.ticket,
          color: AppAccent.primary,
          title: tr('accountRedeem'),
          subtitle: tr('accountRedeemSub'),
          screenKey: 'redeem',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final signedIn = _signedIn;
    final visible =
        _items.where((i) => signedIn || !i.signedInOnly).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr('tabOnline'),
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: onSurface),
        ),
        const SizedBox(height: 6),
        if (signedIn)
          FriendSuggestionsSection(
            // Al aparecer la sesión con la pantalla abierta, la
            // sección se vuelve a montar y carga las sugerencias.
            key: ValueKey(signedIn),
            onOpenProfile: (uid) => _openPublicProfile(context, uid),
          ),
        if (!signedIn)
          _SignInInviteCard(onTap: () => _openSignIn(context)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // Casillas casi cuadradas: cabe icono + título de 2
          // líneas + subtítulo de 2 líneas sin desbordar.
          childAspectRatio: 1.0,
          children: [
            for (final item in visible) _OnlineTile(item: item, onTap: () {
              SoundService.tap();
              onOpenScreen(item.screenKey);
            }),
          ],
        ),
      ],
    );
  }
}

/// Una casilla de la rejilla: tarjeta blanca (radio 20, borde
/// 1 pt, sin sombra), icono en chip de color arriba, título en
/// negrita y subtítulo gris, todo centrado.
class _OnlineTile extends StatelessWidget {
  const _OnlineTile({required this.item, required this.onTap});

  final _OnlineItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // En modo oscuro, los iconos llevan el color del acento
    // (igual que las filas de Cuenta).
    final iconColor =
        isDark ? Theme.of(context).colorScheme.primary : item.color;
    final border =
        isDark ? AppAccent.darkBorder : const Color(0xFFE5E5E5);
    final card = isDark ? AppAccent.darkCard : Colors.white;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final inkSoft =
        isDark ? AppAccent.darkInkSoft : const Color(0xFF777777);
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: LucideIcon(item.icon, color: iconColor, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta que invita al invitado a crear su perfil (2026-11-17,
/// Kristian): ocupa el sitio de las sugerencias cuando NO hay
/// sesión. Sin enseñar a nadie: solo dice que inicie sesión para
/// ver Amigos, Tabla de posiciones y Torneos, y el botón abre el
/// inicio de la app (Google, correo o registro por correo).
class _SignInInviteCard extends StatelessWidget {
  const _SignInInviteCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppAccent.darkCard : Colors.white;
    final border =
        isDark ? AppAccent.darkBorder : const Color(0xFFE5E5E5);
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final inkSoft =
        isDark ? AppAccent.darkInkSoft : const Color(0xFF777777);
    return Container(
      key: const ValueKey('onlineSignInInvite'),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppAccent.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: LucideIcon(
                    LucideIcons.userRound,
                    color: AppAccent.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('obCreateProfile'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr('onlineGuestBody'),
                        style: TextStyle(fontSize: 14, color: inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DuoButton.primary(
              key: const ValueKey('onlineSignInButton'),
              label: tr('onlineSignInButton').toUpperCase(),
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
