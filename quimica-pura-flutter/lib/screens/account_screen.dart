// Pantalla Cuenta (v6, rediseño claro 2026-11-10): el perfil del usuario.
// - Cabecera con la FOTO de la compañera del día (48 px, con su aro
//   de color, junto a la línea "Hoy te acompaña [nombre]") + título
//   "Cuenta" y saludo con el nombre. Sin etiqueta de nombre bajo la
//   foto: el nombre ya está en la línea, no se repite.
// - El avatar del USUARIO (su foto y el selector) sigue QUITADO
//   (fix2, item 6): eso fue lo único que Kristian pidió quitar. La
//   foto de la compañera del día NO es el avatar del usuario y se
//   queda (corrección fix3: un agente anterior la quitó por error).
// - La tarjeta de estadísticas (Vidas/Puntos/Racha/Meta del día/
//   Logros) vive AHORA aquí, debajo de la cabecera (fix 3): antes
//   estaba en Niveles, y la cabecera tenía su propia fila de
//   Puntos/Vidas/Racha/Logros. Ahora hay UNA sola presentación de
//   las estadísticas, en la tarjeta compartida (widgets/stats_card).
// - Aquí viven Idioma, Estadísticas, Cambiar versión y Errores, que
//   antes estaban sueltos en el menú hamburguesa: el menú queda libre
//   para el contenido. También están Favoritos, Recordatorio,
//   Compartir progreso (imagen), Compartir la app, Buscar
//   actualización (fix4, punto 7: chequeo manual con la versión
//   instalada) y Acerca de.
//
// La cabecera se dibuja con colores explícitos (fondo blanco, tarjeta
// blanca con borde y sombra suave) y sin animación de entrada, para
// que siempre se vea completa desde el primer fotograma: nada de la
// cabecera depende del tema ni de un FadeIn.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/lucide_icons.dart';

import '../services/achievements.dart';
import '../services/localization.dart';
import '../services/accent.dart';

import '../services/progress.dart';
import '../services/sound_service.dart';
import '../services/update_check.dart';
import '../services/user_prefs.dart';
import '../widgets/brand_logo.dart';
import '../widgets/icon_animations.dart';
import '../widgets/stats_card.dart';
import '../widgets/twin_avatars.dart';
import 'theme_screen.dart';

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

/// Colores de Cuenta según el tema (auditoría fix2): en claro son los
/// de siempre (fondo blanco, tarjeta #F7F7F7, tinta oscura); en oscuro
/// son verdes oscuros, para que Cuenta no se quede blanca en modo
/// oscuro (item 8: oscuro verde, sin violeta/azul/ámbar). Las
/// gemelas (Brenda violeta, Britany azul) NO cambian: son las
/// mascotas, no el acento del tema.
class _CuentaColors {
  const _CuentaColors({
    required this.bg,
    required this.card,
    required this.ink,
    required this.inkSoft,
    required this.border,
  });

  factory _CuentaColors.of(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      // Fondo y tarjetas según el acento (fix4, punto 2).
      return _CuentaColors(
        bg: AppAccent.darkBackground,
        card: AppAccent.darkCard,
        ink: Colors.white,
        inkSoft: AppAccent.darkInkSoft,
        border: AppAccent.darkBorder,
      );
    }
    return const _CuentaColors(
      bg: Colors.white,
      card: _card,
      ink: _ink,
      inkSoft: _inkSoft,
      border: _border,
    );
  }

  final Color bg;
  final Color card;
  final Color ink;
  final Color inkSoft;
  final Color border;
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.onOpenScreen,
    required this.onShowAbout,
    required this.onShowShareApp,
    required this.trackTopics,
  });

  /// Abre una pantalla por su clave ('language', 'stats', 'version',
  /// 'review', 'favorites', 'reminder', 'theme').
  final void Function(String key) onOpenScreen;
  final VoidCallback onShowAbout;
  final VoidCallback onShowShareApp;
  final List<String> trackTopics;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  /// Comprobación manual en curso (para no lanzar dos a la vez).
  bool _checkingUpdate = false;

  /// Comprobación manual de actualización (fix4, punto 7): fuerza
  /// el chequeo y dice qué pasó. El diálogo ya salió solo si hay
  /// versión nueva; si no, un aviso abajo.
  Future<void> _manualUpdateCheck() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    final result = await UpdateCheckService.checkForUpdateManual(context);
    if (!mounted) return;
    setState(() => _checkingUpdate = false);
    switch (result) {
      case ManualUpdateResult.upToDate:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('checkUpdateLatest'))),
        );
      case ManualUpdateResult.checkFailed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('checkUpdateFailed'))),
        );
      case ManualUpdateResult.updateAvailable:
        // El diálogo ya se mostró; nada más que avisar.
        break;
    }
  }

  /// Abre el chat de WhatsApp del creador (fix4, punto 11): el mismo
  /// enlace de siempre, https://wa.me/5356519431, sin texto
  /// pre-escrito. Igual que _openWhatsApp en main.dart: primero
  /// wa.me (en Android lo abre directo en WhatsApp si está
  /// instalada) y, si falla, el esquema propio de WhatsApp.
  Future<void> _openWhatsApp() async {
    final waMe = Uri.parse('https://wa.me/5356519431');
    final appScheme = Uri.parse('whatsapp://send?phone=5356519431');
    var opened = false;
    try {
      if (await canLaunchUrl(waMe)) {
        opened = await launchUrl(waMe, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      try {
        if (await canLaunchUrl(appScheme)) {
          opened =
              await launchUrl(appScheme, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se pudo abrir WhatsApp: revisa tu conexión')),
      );
    }
  }

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
    // Colores según el tema (auditoría fix2): en oscuro, Cuenta es
    // verde oscura, no blanca.
    final c = _CuentaColors.of(context);
    // La compañera del día (API nueva: los tres, incluido Kristian):
    // su foto de 48 px con el aro de su color, junto a la línea
    // "Hoy te acompaña…". El avatar del USUARIO y su selector siguen
    // quitados (fix2, item 6: eso fue lo único que pidió quitar);
    // la foto de la compañera no es el avatar del usuario.
    final companion = companionOfTheDay();
    final accent = companionAccent(companion);
    final genderLabel =
        UserPrefs.userGender.isEmpty ? '' : ' · ${UserPrefs.userGender}';

    return Container(
      color: c.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          // Cabecera del perfil: foto de la compañera del día (48 px,
          // con su aro de color, auditoría de tamaños: como el
          // banner de Niveles 36 y la burbuja 52, 48 es la foto de
          // cabecera de perfil) JUNTO A los textos — título
          // "Cuenta", saludo con el nombre ("Bienvenido/a [nombre]"
          // o "Hola" sin nombre) y la línea "Hoy te acompaña…".
          // Sin nombre bajo la foto: el nombre ya está en la línea.
          // El avatar del usuario y su selector NO están aquí
          // (quitados en fix2, item 6). Las estadísticas van en la
          // tarjeta de abajo (fix 3).
          Container(
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CompanionAvatar(companion: companion, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('accountTitle'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${UserPrefs.greeting}$genderLabel',
                        style: TextStyle(color: c.inkSoft),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(companionOfDayKey(companion)),
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
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
          // Orden de Cuenta (ronda fix6, ítem 4): las TRES primeras
          // filas son Estadísticas, Mis errores y Cómo se juega. El
          // resto sigue en su mismo orden de siempre (Tema, Idioma,
          // Cambiar versión, Favoritos, Recordatorio, Compartir…).
          _Row(
            icon: LucideIcons.chartColumn,
            iconColor: _violet,
            title: tr('accountStats'),
            subtitle: tr('accountStatsSub'),
            onTap: () => widget.onOpenScreen('stats'),
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
            onTap: () => widget.onOpenScreen('howToPlay'),
          ),
          // Tema (fix3, último cambio de la ronda): ya NO es una
          // tarjeta inline en Cuenta. Es una fila táctil como las
          // demás, con el subtítulo de la selección actual (p. ej.
          // "Verde · Claro"), que abre su propia pantalla dedicada
          // (ThemeScreen) con el color y el modo. El subtítulo se
          // reconstruye solo al cambiar el tema (los dos notifiers)
          // sin falta de volver a entrar a Cuenta.
          ListenableBuilder(
            listenable: Listenable.merge([
              UserPrefs.themeAccentNotifier,
              UserPrefs.themeModeNotifier,
            ]),
            builder: (context, _) => _Row(
              icon: LucideIcons.sparkles,
              iconColor: _violet,
              title: tr('themeTitle'),
              subtitle: themeSelectionSubtitle(),
              onTap: () => widget.onOpenScreen('theme'),
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
            icon: LucideIcons.refreshCw,
            iconColor: _amber,
            title: tr('accountVersion'),
            subtitle: ProgressService.track == ProgressService.trackBach
                ? tr('trackBach')
                : tr('trackUni'),
            onTap: () => widget.onOpenScreen('version'),
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
            icon: LucideIcons.download,
            iconColor: _teal,
            title: tr('checkUpdateTitle'),
            subtitle: tr('checkUpdateSub').replaceFirst('%s', kAppVersion),
            onTap: _manualUpdateCheck,
          ),
          _Row(
            icon: LucideIcons.info,
            iconColor: _violet,
            title: tr('accountAbout'),
            subtitle: tr('appSubtitle'),
            onTap: widget.onShowAbout,
          ),
          // Soporte, última opción de Cuenta (fix4, punto 11,
          // corrección final): UNA OPCIÓN MÁS, igual que las demás
          // filas — tarjeta gris, icono de mensaje en círculo
          // tintado teal, título "Soporte", subtítulo "Escríbeme por
          // WhatsApp", chevron. Nada de botón verde llamativo ni de
          // logo de WhatsApp. El enlace es el de siempre (wa.me
          // vacío, sin texto pre-escrito). El Soporte del menú
          // hamburguesa está ELIMINADO (no hay versión normal
          // tampoco).
          _Row(
            icon: LucideIcons.messageCircle,
            iconColor: _teal,
            title: tr('supportWord'),
            subtitle: tr('supportWriteMe'),
            onTap: _openWhatsApp,
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 28),
                const SizedBox(width: 8),
                Text(
                  'Quemia',
                  style: TextStyle(fontWeight: FontWeight.bold, color: c.ink),
                ),
                Text(
                  ' · ${tr('creatorWord')}: CraigKamer',
                  style: TextStyle(color: c.inkSoft),
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
    final c = _CuentaColors.of(context);
    // En modo oscuro, los iconos llevan el color del acento
    // (menta con Verde, violeta claro con Violeta): el "nada de
    // violeta en oscuro" era de la ronda #2, cuando el oscuro era
    // verde fijo; con el oscuro violeta (fix4, punto 2) el icono
    // sigue al acento.
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.primary
        : this.iconColor;
    return Card(
      color: c.card,
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
              style: TextStyle(fontWeight: FontWeight.w600, color: c.ink)),
          subtitle: Text(subtitle, style: TextStyle(color: c.inkSoft)),
          trailing:
              LucideIcon(LucideIcons.chevronRight, size: 18, color: c.inkSoft),
          onTap: () {
            SoundService.tap();
            onTap();
          },
        ),
      ),
    );
  }
}
