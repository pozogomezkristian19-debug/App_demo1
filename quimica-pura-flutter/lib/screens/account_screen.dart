// Pantalla Cuenta (v6, rediseño claro 2026-11-10): el perfil del usuario.
// - Avatar de la gemela del día (Brenda/Britany, ilustrado), nombre,
//   saludo y selector del avatar propio del usuario.
// - La tarjeta de estadísticas (Vidas/Puntos/Racha/Meta del día/
//   Logros) vive AHORA aquí, debajo de la cabecera (fix 3): antes
//   estaba en Niveles, y la cabecera tenía su propia fila de
//   Puntos/Vidas/Racha/Logros. Ahora hay UNA sola presentación de
//   las estadísticas, en la tarjeta compartida (widgets/stats_card).
// - Aquí viven Idioma, Estadísticas, Cambiar versión y Errores, que
//   antes estaban sueltos en el menú hamburguesa: el menú queda libre
//   para el contenido. También están Favoritos, Recordatorio,
//   Compartir progreso (imagen), Compartir la app y Acerca de.
//
// La cabecera se dibuja con colores explícitos (fondo blanco, tarjeta
// blanca con borde y sombra suave) y sin animación de entrada, para
// que siempre se vea completa desde el primer fotograma: nada de la
// cabecera depende del tema ni de un FadeIn.

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../services/achievements.dart';
import '../services/localization.dart';
import '../services/progress.dart';
import '../services/sound_service.dart';
import '../services/user_prefs.dart';
import '../widgets/avatar.dart';
import '../widgets/brand_logo.dart';
import '../widgets/how_to_play.dart';
import '../widgets/icon_animations.dart';
import '../widgets/stats_card.dart';
import '../widgets/twin_avatars.dart';

/// Tokens claros (paleta propia de Melli-Qui, sin verde Duolingo):
/// teal #00C2A8 como color principal, teal oscuro #00A18D.
const _teal = Color(0xFF00C2A8);
const _ink = Color(0xFF3C3C3C);
const _inkSoft = Color(0xFF6E6E6E);
const _card = Color(0xFFF7F7F7);
const _border = Color(0xFFE8E8E8);
const _violet = Color(0xFF8B5CF6);
const _blue = Color(0xFF3B82F6);
const _amber = Color(0xFFF59E0B);

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.onOpenScreen,
    required this.onShowAbout,
    required this.onShowShareApp,
    required this.trackTopics,
  });

  /// Abre una pantalla por su clave ('language', 'stats', 'version',
  /// 'review', 'favorites', 'reminder').
  final void Function(String key) onOpenScreen;
  final VoidCallback onShowAbout;
  final VoidCallback onShowShareApp;
  final List<String> trackTopics;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  int get _achievementsUnlocked {
    final p = ProgressService.instance;
    var n = 0;
    for (final a in allAchievements) {
      if (achievementUnlocked(a.id, p, widget.trackTopics)) n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    // La gemela del día: su avatar ilustrado preside la cabecera.
    final twinA = twinOfTheDay();
    final twinAccent = twinA ? _violet : _blue;
    final genderLabel = UserPrefs.userGender.isEmpty
        ? ''
        : ' · ${UserPrefs.userGender}';

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          // Cabecera del perfil: avatar + nombre + saludo + selector
          // de avatar. Compacta: las estadísticas ya no van aquí
          // dentro, van en la tarjeta de abajo (fix 3).
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: twinAccent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: twinA
                              ? const TwinAvatarA(size: 72)
                              : const TwinAvatarB(size: 72),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          twinName(twinA),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: twinAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            UserPrefs.userName.isEmpty
                                ? tr('accountTitle')
                                : UserPrefs.userName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${UserPrefs.greeting}$genderLabel',
                            style: const TextStyle(color: _inkSoft),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr(twinOfDayKey(twinA)),
                            style: TextStyle(
                              color: twinAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: _border),
                const SizedBox(height: 12),
                _AvatarPickerRow(onChanged: () => setState(() {})),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tarjeta de estadísticas (fix 3): la de Niveles, mudada.
          // Vidas (corazón + número), Puntos, Racha, Meta del día y
          // Logros: cada número UNA sola vez en toda la Cuenta.
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: StatsCard(
              achievementsLabel:
                  '$_achievementsUnlocked/${allAchievements.length}',
            ),
          ),
          const SizedBox(height: 16),
          _Row(
            icon: LucideIcons.globe,
            iconColor: _blue,
            title: tr('accountLanguage'),
            subtitle: AppLang.supported
                .firstWhere((e) => e.$1 == AppLang.code,
                    orElse: () => AppLang.supported.first)
                .$2,
            onTap: () => widget.onOpenScreen('language'),
          ),
          _Row(
            icon: LucideIcons.chartColumn,
            iconColor: _violet,
            title: tr('accountStats'),
            subtitle: tr('accountStatsSub'),
            onTap: () => widget.onOpenScreen('stats'),
          ),
          _Row(
            icon: LucideIcons.refreshCw,
            iconColor: _amber,
            title: tr('accountVersion'),
            subtitle: ProgressService.track == ProgressService.trackBach
                ? tr('trackBach')
                : tr('trackUni'),
            onTap: () => widget.onOpenScreen('version'),
          ),
          _Row(
            icon: LucideIcons.rotateCcw,
            iconColor: _teal,
            title: tr('accountReview'),
            subtitle: '${p.failedCount} ${tr('reviewTitle')}',
            onTap: () => widget.onOpenScreen('review'),
          ),
          _Row(
            icon: LucideIcons.circleHelp,
            iconColor: _blue,
            title: tr('howToPlayTitle'),
            subtitle: tr('howToPlaySub'),
            onTap: () => showHowToPlayDialog(context),
          ),
          _Row(
            icon: LucideIcons.star,
            iconColor: _amber,
            title: tr('accountFavorites'),
            subtitle: tr('menuFavoritesSub'),
            onTap: () => widget.onOpenScreen('favorites'),
          ),
          _Row(
            icon: LucideIcons.alarmClock,
            iconColor: _violet,
            title: tr('accountReminder'),
            subtitle: UserPrefs.reminderOn
                ? tr('menuReminderOn')
                : tr('menuReminderOff'),
            onTap: () => widget.onOpenScreen('reminder'),
          ),
          _Row(
            icon: LucideIcons.image,
            iconColor: _teal,
            title: tr('accountShareProgress'),
            subtitle: tr('accountShareProgressSub'),
            onTap: () => widget.onOpenScreen('stats'),
          ),
          _Row(
            icon: LucideIcons.share2,
            iconColor: _blue,
            title: tr('accountShareApp'),
            subtitle: tr('menuShare'),
            onTap: widget.onShowShareApp,
          ),
          _Row(
            icon: LucideIcons.info,
            iconColor: _violet,
            title: tr('accountAbout'),
            subtitle: tr('appSubtitle'),
            onTap: widget.onShowAbout,
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Melli-Qui',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: _ink),
                ),
                Text(
                  ' · ${tr('creatorWord')}: CraigKamer',
                  style: const TextStyle(color: _inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final LucideIconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: LucideIcon(icon, color: iconColor, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: _ink)),
        subtitle: Text(subtitle, style: const TextStyle(color: _inkSoft)),
        trailing: const LucideIcon(LucideIcons.chevronRight, size: 18, color: _inkSoft),
        onTap: () {
          SoundService.tap();
          onTap();
        },
        ),
      ),
    );
  }
}

/// Selector del avatar propio del usuario (3 estilos por género,
/// guardado en UserPrefs.avatar). Se muestra en línea dentro de la
/// cabecera de Cuenta, para que el avatar por género siga teniendo
/// entrada visible: el elegido queda marcado con el anillo teal.
class _AvatarPickerRow extends StatelessWidget {
  const _AvatarPickerRow({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final styles = MelliAvatar.stylesForGender(UserPrefs.userGender);
    final current = MelliAvatar.isValidId(UserPrefs.avatar)
        ? UserPrefs.avatar
        : MelliAvatar.defaultForGender(UserPrefs.userGender);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('accountAvatarTitle'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final id in styles)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    SoundService.tap();
                    UserPrefs.saveAvatar(id);
                    onChanged();
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: id == current ? _teal : _border,
                        width: id == current ? 3 : 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: MelliAvatar(avatarId: id, size: 48),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Text(
                tr('accountChangeAvatar'),
                style: const TextStyle(fontSize: 13, color: _inkSoft),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
