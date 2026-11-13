// Pantalla Cuenta (v6, rediseño claro 2026-11-10; rediseño
// Duolingo 7.0, Zona C; ORGANIZACIÓN 6.3 restaurada 2026-11-11):
// el perfil del usuario.
// - Cabecera en TARJETA redondeada (no banner teal a todo lo
//   ancho): título "Cuenta" + el CÍRCULO GRANDE del AVATAR DEL
//   USUARIO (96 dp, editable tocándolo: abre la galería de
//   avatares, alcance 9) + "Bienvenido/a [nombre]" SIN el
//   género escrito (alcance 10) + la línea "Hoy te acompaña
//   [compañero]" en el color del compañero, con su miniatura
//   de compañera (22 dp). El círculo grande ya NO es la
//   compañera del día. El avatar elegido se sigue mostrando en
//   Tabla de posiciones, Amigos y Torneos.
// - Estadísticas: UNA tarjeta (StatsCard) con 5 columnas CON
//   ICONOS: Vidas, Puntos, Racha, Meta del día y Logros (x/10).
// - Las 12 filas van cada una en su propia TARJETA redondeada
//   con separación (organización 6.3), con el icono en un chip
//   tintado — no filas planas con divisores. Orden 7.1 (Zona H):
//   Vincular con Google (prominente, primera fila), Estadísticas,
//   Mis errores, Amigos, Tabla de posiciones, Torneo, Grupos de
//   estudio, Tienda, Acerca de, Compartir, Soporte y Ajustes.
//   Todo lo demás (Tema, Recordatorios, Notificaciones, Cómo se
//   juega, Buscar actualización, Idioma, Cambiar versión,
//   Favoritos, Compartir progreso) vive en la pantalla Ajustes
//   (settings_screen.dart), no aquí.
// - El selector de foto del usuario (para subir una foto propia)
//   sigue QUITADO (fix2, item 6: eso fue lo único que Kristian
//   pidió quitar) — la galería de avatares (alcance 9) solo usa
//   las fotos predefinidas del proyecto, no subidas.
// - Aquí viven Estadísticas y Errores, que antes estaban sueltos
//   en el menú hamburguesa: el menú queda libre para el
//   contenido. También están Compartir la app (hoja nativa del
//   sistema, sin diálogo con el enlace) y Acerca de.
//
// El contenido lleva padding inferior = altura de la barra
// (MainBottomNav.barHeight, 64) + 16 pt, para que la barra no
// tape la última fila.
//
// El HUD superior (chips de vidas/repaso/campana) vive en el
// AppBar de main.dart, no en esta pantalla: su cambio a fondo
// transparente es de la zona que toca main.dart, no de esta.
//
// La cabecera se dibuja con colores explícitos y sin animación
// de entrada, para que siempre se vea completa desde el primer
// fotograma: nada de la cabecera depende del tema ni de un FadeIn.

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../services/achievements.dart';
import '../services/analytics_sync.dart';
import '../services/auth_service.dart';
import '../services/localization.dart';
import '../services/accent.dart';

import '../services/progress.dart';
import '../services/social_service.dart';
import '../services/sound_service.dart';
import '../services/user_prefs.dart';
import '../widgets/brand_logo.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/social_avatar.dart';
import '../widgets/stats_card.dart';
import '../widgets/twin_avatars.dart';

/// Tokens claros (rediseño Duolingo 7.0): texto #4B4B4B,
/// terciario #777777, líneas #E5E5E5; teal #00C2A8 como color
/// principal, teal oscuro #00A18D.
const _teal = Color(0xFF00C2A8);
const _ink = Color(0xFF4B4B4B);
const _inkSoft = Color(0xFF777777);
const _border = Color(0xFFE5E5E5);
const _violet = Color(0xFF8B5CF6);
const _blue = Color(0xFF3B82F6);
const _amber = Color(0xFFF59E0B);

/// Colores de Cuenta según el tema (auditoría fix2): en claro son los
/// de siempre (fondo blanco, tinta #4B4B4B, gris #777777, líneas
/// #E5E5E5); en oscuro son verdes oscuros, para que Cuenta no se
/// quede blanca en modo oscuro (item 8: oscuro verde, sin
/// violeta/azul/ámbar). Las gemelas (Brenda violeta, Britany azul)
/// NO cambian: son las mascotas, no el acento del tema.
class _CuentaColors {
  const _CuentaColors({
    required this.bg,
    required this.ink,
    required this.inkSoft,
    required this.border,
    required this.card,
  });

  factory _CuentaColors.of(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      // Fondo y tarjetas según el acento (fix4, punto 2).
      return _CuentaColors(
        bg: AppAccent.darkBackground,
        ink: Colors.white,
        inkSoft: AppAccent.darkInkSoft,
        border: AppAccent.darkBorder,
        card: AppAccent.darkCard,
      );
    }
    return const _CuentaColors(
      bg: Colors.white,
      ink: _ink,
      inkSoft: _inkSoft,
      border: _border,
      card: Colors.white,
    );
  }

  final Color bg;
  final Color ink;
  final Color inkSoft;
  final Color border;

  /// Fondo de las tarjetas (cabecera y filas): blanco en claro,
  /// superficie oscura en oscuro (6.3).
  final Color card;
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
  @override
  void initState() {
    super.initState();
    _loadGoogleState();
  }

  /// Estado del enlace con Google (ronda #8, cambio 09:08).
  bool _googleLinked = false;
  String? _googleEmail;

  Future<void> _loadGoogleState() async {
    final linked = AuthService.isGoogleLinked;
    final String? email = AuthService.googleEmail;
    if (!mounted) return;
    setState(() {
      _googleLinked = linked;
      _googleEmail = email;
    });
  }

  /// Fila "Vincular con Google" tocada (09:13): mientras se firma,
  /// la fila muestra "Vinculando…" y no acepta otro toque; si
  /// linkWithGoogle() devuelve false, UNA sola línea con el motivo
  /// (sin internet, o fallo al iniciar sesión), sin diálogo de
  /// error y sin quedarse en carga. Si devuelve true, se trae el
  /// respaldo y la fila muestra el correo.
  var _googleBusy = false;

  Future<void> _onGoogleRowTap() async {
    if (_googleBusy) return;
    if (_googleLinked) {
      await _showUnlinkDialog();
      return;
    }
    setState(() => _googleBusy = true);
    final ok = await AuthService.linkWithGoogle();
    if (!mounted) return;
    if (!ok) {
      setState(() => _googleBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AnalyticsSync.firebaseReady
              ? tr('googleSignInFailed')
              : tr('googleNeedInternet')),
        ),
      );
      return;
    }
    await AnalyticsSync.restoreFromCloud();
    if (!mounted) return;
    await _loadGoogleState();
    if (!mounted) return;
    setState(() => _googleBusy = false);
  }

  /// Diálogo de desvincular: muestra el correo vinculado y pide
  /// confirmar; desvincular NO borra el progreso del teléfono.
  Future<void> _showUnlinkDialog() async {
    final unlink = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('accountLinkGoogle')),
        content: Text(_googleEmail ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('closeWord')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('accountUnlinkGoogle')),
          ),
        ],
      ),
    );
    if (unlink != true || !mounted) return;
    await AuthService.unlinkGoogle();
    await _loadGoogleState();
  }

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    // Colores según el tema (auditoría fix2): en oscuro, Cuenta es
    // verde oscura, no blanca.
    final c = _CuentaColors.of(context);
    // La compañera del día (API nueva: los tres, incluido Kristian):
    // su MINIATURA (22 dp) va junto a la línea "Hoy te
    // acompaña…". El CÍRCULO GRANDE (96 dp) ya NO es la
    // compañera (alcance 9, 7.1): es el AVATAR DEL USUARIO,
    // editable tocándolo (abre la galería); la foto y la línea
    // ya no tienen que coincidir.
    final companion = companionOfTheDay();
    final accent = companionAccent(companion);
    // Logros desbloqueados de los 10 que hay (Mis estadísticas
    // usa la misma cuenta): la tarjeta de estadísticas muestra
    // "x/10".
    final unlockedCount = allAchievements
        .where((a) => achievementUnlocked(a.id, p, widget.trackTopics))
        .length;
    // Saludo SIN el género escrito (alcance 10, 7.1): solo
    // "Bienvenido/a [nombre]". El género sigue usándose por
    // dentro (el saludo mismo es Bienvenido/Bienvenida según el
    // género, y el avatar por defecto), pero no se muestra.
    final greetingLine = UserPrefs.greeting;
    // greeting ya devuelve "Hola" sin nombre guardado: no hace
    // falta (ni se debe) caer al título "Cuenta", que repetiría
    // el título de la tarjeta.

    return Container(
      color: c.bg,
      child: ListView(
        // Con padding lateral: cabecera, estadísticas y filas son
        // tarjetas contenidas. El padding inferior es altura de
        // la barra (64) + 16 pt.
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MainBottomNav.barHeight + 16),
        children: [
          // Tarjeta de cabecera redondeada (organización 6.3):
          // título "Cuenta" + CÍRCULO GRANDE del avatar del
          // usuario (96 dp, editable: toca y abre la galería) +
          // saludo SIN el género escrito + línea "Hoy te
          // acompaña…" con su miniatura de compañera (22 dp).
          Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar del usuario (alcance 9): el círculo se
                // repinta solo al elegir otro en la galería
                // (SocialService avisa con el notifier).
                ListenableBuilder(
                  listenable:
                      SocialService.equippedAvatarIdNotifier,
                  builder: (context, _) => _UserAvatarCircle(
                    asset: SocialService.displayAvatarAssetForGender(
                        UserPrefs.userGender),
                    onTap: () => widget.onOpenScreen('avatar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('accountTitle'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        greetingLine,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          CompanionAvatar(
                            companion: companion,
                            size: 22,
                            ring: false,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tr(companionOfDayKey(companion)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Estadísticas: UNA tarjeta con 5 columnas CON ICONOS
          // (StatsCard, organización 6.3): Vidas, Puntos, Racha,
          // Meta del día y Logros.
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: StatsCard(
              achievementsLabel:
                  '$unlockedCount/${allAchievements.length}',
            ),
          ),
          // Orden de Cuenta (Quemia 7.1, Zona H): la cabecera y la
          // tarjeta de estadísticas NO cambian; debajo van, en este
          // orden exacto, Vincular con Google (prominente, primera
          // fila: es la puerta a todo lo online), Estadísticas,
          // Mis errores, Amigos, Tabla de posiciones, Torneo,
          // Grupos de estudio, Tienda, Acerca de, Compartir,
          // Soporte y Ajustes. Todo lo demás (Tema, Recordatorios,
          // Notificaciones, Cómo se juega, Buscar actualización,
          // Idioma, Cambiar versión, Favoritos, Compartir
          // progreso) vive en la pantalla Ajustes.
          // Ronda #8 (cambio 09:08): vincular con Google — respaldo
          // con la cuenta de Google (el mismo uid recupera el
          // progreso en otro teléfono). Si está vinculada, la fila
          // muestra el correo y al tocar ofrece desvincular.
          _Row(
            icon: LucideIcons.link,
            iconColor: _blue,
            title: tr('accountLinkGoogle'),
            subtitle: _googleBusy
                ? tr('googleLinking')
                : _googleLinked && _googleEmail != null
                    ? _googleEmail!
                    : tr('accountLinkGoogleSub'),
            onTap: _onGoogleRowTap,
          ),
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
          // Quemia 7.0: social (amigos, torneos, tienda, grupos).
          _Row(
            icon: LucideIcons.userRound,
            iconColor: _teal,
            title: tr('accountFriends'),
            subtitle: tr('accountFriendsSub'),
            onTap: () => widget.onOpenScreen('friends'),
          ),
          // Ronda #8 (Quemia 6.5): tabla de posiciones.
          // (Diseño 7.0: la fila "Compartir mi progreso" se quitó
          // de aquí: compartir es automático con Google vinculada,
          // sin preguntar nada; la fila vive ahora en Ajustes y
          // abre Mis estadísticas.)
          _Row(
            icon: LucideIcons.trophy,
            iconColor: _amber,
            title: tr('accountLeaderboard'),
            subtitle: tr('accountLeaderboardSub'),
            onTap: () => widget.onOpenScreen('leaderboard'),
          ),
          _Row(
            icon: LucideIcons.award,
            iconColor: _amber,
            title: tr('accountTournaments'),
            subtitle: tr('accountTournamentsSub'),
            onTap: () => widget.onOpenScreen('tournaments'),
          ),
          _Row(
            icon: LucideIcons.network,
            iconColor: _blue,
            title: tr('accountGroups'),
            subtitle: tr('accountGroupsSub'),
            onTap: () => widget.onOpenScreen('groups'),
          ),
          _Row(
            icon: LucideIcons.gift,
            iconColor: _violet,
            title: tr('accountShop'),
            subtitle: tr('accountShopSub'),
            onTap: () => widget.onOpenScreen('shop'),
          ),
          _Row(
            icon: LucideIcons.info,
            iconColor: _violet,
            title: tr('accountAbout'),
            subtitle: tr('appSubtitle'),
            onTap: widget.onShowAbout,
          ),
          _Row(
            icon: LucideIcons.share2,
            iconColor: _blue,
            title: tr('accountShareApp'),
            subtitle: tr('menuShare'),
            onTap: widget.onShowShareApp,
          ),
          // Soporte (7.0, Kristian 09:52): ya NO abre WhatsApp
          // directo — abre la ventanita dentro de la app (hilo +
          // compositor); la opción de WhatsApp vive DENTRO de la
          // ventanita y solo si el interruptor remoto está
          // encendido. La fila sigue siendo una opción más, igual
          // que las demás: fila plana, icono de mensaje teal,
          // título "Soporte", chevron.
          _Row(
            icon: LucideIcons.messageCircle,
            iconColor: _teal,
            title: tr('supportWord'),
            subtitle: tr('supportSub'),
            onTap: () => widget.onOpenScreen('support'),
          ),
          // Ajustes (7.1): última fila; abre su propia pantalla
          // con Tema, Recordatorios, Notificaciones, Cómo se
          // juega, Buscar actualización, Idioma, Cambiar versión,
          // Favoritos y Compartir progreso.
          _Row(
            icon: LucideIcons.settings,
            iconColor: _violet,
            title: tr('settingsTitle'),
            subtitle: tr('settingsSub'),
            onTap: () => widget.onOpenScreen('settings'),
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

/// Círculo grande del avatar del USUARIO (alcance 9, 7.1): la
/// foto equipada (o la de por defecto según el género) en 96 dp,
/// con un distintivo de lápiz que dice que se puede cambiar.
/// Al tocarlo se abre la galería de avatares. Usa SocialAvatar,
/// el mismo widget que en Amigos, tabla y torneos: sin inicial,
/// siempre una cara.
class _UserAvatarCircle extends StatelessWidget {
  const _UserAvatarCircle({
    required this.asset,
    required this.onTap,
  });

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr('avatarTitle'),
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            SoundService.tap();
            onTap();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SocialAvatar(
                username: UserPrefs.userName,
                size: 96,
                avatarAsset: asset,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _teal,
                    border:
                        Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const LucideIcon(
                    LucideIcons.pencil,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una fila de Cuenta como TARJETA redondeada (organización
/// 6.3): cada fila en su propia tarjeta con separación, icono
/// en un chip tintado, título 17 pt peso 700, subtítulo 15 pt
/// gris, chevron gris a la derecha. Sin sombra borrosa (estilo
/// Duolingo aprobado): la tarjeta es plana, con borde de 1 pt.
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
    // Tarjeta (organización 6.3): radio 16, borde de 1 pt, sin
    // sombra borrosa. La separación entre tarjetas la da el
    // margen inferior de 12 pt.
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            SoundService.tap();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: LucideIcon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 15,
                          color: c.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                LucideIcon(
                  LucideIcons.chevronRight,
                  size: 20,
                  color: c.inkSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
