// Sugerencias de amigos (2026-11-17, reorganización Online):
// hasta 5 personas que rotan cada día, en cuadritos estilo
// Facebook que se deslizan a la derecha. Antes vivía dentro de
// Cuenta (lote 2026-11-16); ahora es un widget propio porque la
// sección se enseña en Online, junto a Amigos. La lógica es la
// misma de antes: seguir pasa a SIGUIENDO y la tarjeta sale en
// 300 ms para que entre la siguiente; la X descarta solo por hoy.
import 'package:flutter/material.dart';

import '../services/accent.dart';
import '../services/localization.dart';
import '../services/social_service.dart';
import '../services/sound_service.dart';
import 'duo_button.dart';
import 'lucide_icons.dart';
import 'motion.dart';
import 'social_avatar.dart';

/// Colores de tarjeta según el tema (los mismos de Cuenta):
/// en claro fondo blanco, tinta #4B4B4B, gris #777777, líneas
/// #E5E5E5; en oscuro, superficies oscuras del acento.
class _SuggestionColors {
  const _SuggestionColors({
    required this.ink,
    required this.inkSoft,
    required this.border,
    required this.card,
  });

  factory _SuggestionColors.of(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return _SuggestionColors(
        ink: Colors.white,
        inkSoft: AppAccent.darkInkSoft,
        border: AppAccent.darkBorder,
        card: AppAccent.darkCard,
      );
    }
    return const _SuggestionColors(
      ink: Color(0xFF4B4B4B),
      inkSoft: Color(0xFF777777),
      border: Color(0xFFE5E5E5),
      card: Colors.white,
    );
  }

  final Color ink;
  final Color inkSoft;
  final Color border;
  final Color card;
}

/// Sección de sugerencias de amigos: título + cuadritos
/// deslizables. Solo se monta con sesión (Online la monta solo
/// cuando hay sesión); sin sugerencias no ocupa nada.
class FriendSuggestionsSection extends StatefulWidget {
  const FriendSuggestionsSection({
    super.key,
    required this.onOpenProfile,
  });

  /// Al tocar una tarjeta: abrir el perfil público de esa persona.
  final void Function(String uid) onOpenProfile;

  @override
  State<FriendSuggestionsSection> createState() =>
      _FriendSuggestionsSectionState();
}

class _FriendSuggestionsSectionState extends State<FriendSuggestionsSection> {
  /// null = aún cargando; [] = no hay ninguna.
  List<FriendEntry>? _suggestions;

  /// ¿A cuáles de las sugerencias ya sigo? (para que el botón diga
  /// SIGUIENDO desde el principio).
  final _suggestionFollowing = <String, bool>{};

  /// ¿Cuáles de las sugerencias ME siguen a mí? (si sigo a una que
  /// me sigue, somos mutuos: el botón lleva corazón, no check).
  final _suggestionFollowedBy = <String, bool>{};

  /// Sugerencias en salida (al seguir, la tarjeta se desliza y se
  /// desvanece en 300 ms antes de que la sustituya la siguiente).
  final _exitingSuggestions = <String>{};

  /// Seguir en curso por uid (el botón no acepta otro toque
  /// mientras tanto).
  final _followBusy = <String>{};

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final list = await SocialService.friendSuggestions();
    if (!mounted) return;
    final following = <String, bool>{};
    final followedBy = <String, bool>{};
    for (final s in list) {
      following[s.deviceId] = await SocialService.isFollowing(s.deviceId);
      followedBy[s.deviceId] =
          await SocialService.isFollowedBy(s.deviceId);
    }
    if (!mounted) return;
    setState(() {
      _suggestions = list;
      _suggestionFollowing
        ..clear()
        ..addAll(following);
      _suggestionFollowedBy
        ..clear()
        ..addAll(followedBy);
    });
  }

  /// Seguir / dejar de seguir desde una sugerencia: el botón pasa
  /// a SIGUIENDO (o vuelve a SEGUIR). Al SEGUIR, la tarjeta se
  /// desliza/desvanece en 300 ms y la sustituye la siguiente
  /// sugerencia (pulido Duolingo 2026-11-16).
  Future<void> _toggleSuggestionFollow(FriendEntry user) async {
    final uid = user.deviceId;
    if (_followBusy.contains(uid)) return;
    setState(() => _followBusy.add(uid));
    final following = _suggestionFollowing[uid] ?? false;
    final ok = following
        ? await SocialService.unfollowUser(uid)
        : await SocialService.followUser(uid);
    if (!mounted) return;
    setState(() {
      _followBusy.remove(uid);
      if (ok) _suggestionFollowing[uid] = !following;
    });
    if (!ok) return;
    if (following) return;
    setState(() => _exitingSuggestions.add(uid));
    await Future.delayed(AppMotion.cardExit);
    if (!mounted) return;
    setState(() => _exitingSuggestions.remove(uid));
    await _loadSuggestions();
  }

  /// La X de una sugerencia: la descarta solo por hoy.
  Future<void> _dismissSuggestion(FriendEntry user) async {
    await SocialService.dismissSuggestion(user.deviceId);
    if (!mounted) return;
    setState(() => _suggestions = _suggestions
        ?.where((s) => s.deviceId != user.deviceId)
        .toList());
  }

  @override
  Widget build(BuildContext context) {
    if (_suggestions == null || _suggestions!.isEmpty) {
      return const SizedBox.shrink();
    }
    final c = _SuggestionColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: Text(
            tr('accountSuggestionsTitle').toUpperCase(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: c.inkSoft,
            ),
          ),
        ),
        // 232: la tarjeta mide avatar 56 + nombre + subtítulo de
        // 2 líneas + botón; con 200 la columna se desbordaba 8 px
        // abajo, y con 216 seguía 4,3 px cuando el avatar lleva
        // insignia (SocialAvatar con badge mide 56 + 12,3 px).
        SizedBox(
          height: 232,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: _suggestions!.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final s = _suggestions![i];
              // Al seguir, la tarjeta se desliza/desvanece en
              // 300 ms (solo opacidad con movimiento reducido).
              final exiting = _exitingSuggestions.contains(s.deviceId);
              return AnimatedOpacity(
                opacity: exiting ? 0 : 1,
                duration: AppMotion.cardExit,
                child: AnimatedSlide(
                  offset: exiting && !reducedMotion(context)
                      ? const Offset(0.3, 0)
                      : Offset.zero,
                  duration: AppMotion.cardExit,
                  child: FriendSuggestionCard(
                    entry: s,
                    following: _suggestionFollowing[s.deviceId] ?? false,
                    followedBy: _suggestionFollowedBy[s.deviceId] ?? false,
                    busy: _followBusy.contains(s.deviceId),
                    onFollow: () => _toggleSuggestionFollow(s),
                    onDismiss: () => _dismissSuggestion(s),
                    onOpen: () => widget.onOpenProfile(s.deviceId),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Un cuadrito de sugerencia estilo Facebook (avatar arriba,
/// nombre, "Es posible que se conozcan", botón SEGUIR/SIGUIENDO
/// y X para descartar).
class FriendSuggestionCard extends StatelessWidget {
  const FriendSuggestionCard({
    super.key,
    required this.entry,
    required this.following,
    required this.followedBy,
    required this.busy,
    required this.onFollow,
    required this.onDismiss,
    required this.onOpen,
  });

  final FriendEntry entry;
  final bool following;

  /// ¿Me sigue de vuelta? (mutuo: corazón en vez de check).
  final bool followedBy;
  final bool busy;
  final VoidCallback onFollow;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = _SuggestionColors.of(context);
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            SoundService.tap();
            onOpen();
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  children: [
                    SocialAvatar(
                      username: entry.username,
                      avatarAsset: entry.avatarAsset,
                      badgeId: entry.badgeId,
                      frameItem: entry.frameItem,
                      size: 56,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('accountSuggestionsSub'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: c.inkSoft),
                    ),
                    const Spacer(),
                    // Al pasar a SIGUIENDO el botón hace pop; el
                    // check hace pop con él, y si es mutuo (me
                    // sigue de vuelta) lleva corazón.
                    FollowPulse(
                      following: following,
                      child: DuoButton.secondary(
                        label: (following
                                ? tr('accountFollowingBtn')
                                : tr('accountFollow'))
                            .toUpperCase(),
                        icon: following
                            ? (followedBy
                                ? LucideIcons.heart
                                : LucideIcons.check)
                            : null,
                        onPressed: busy ? null : onFollow,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  icon: const LucideIcon(LucideIcons.x, size: 18),
                  color: c.inkSoft,
                  tooltip: tr('closeWord'),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
