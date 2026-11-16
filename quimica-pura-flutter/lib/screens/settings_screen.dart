// Pantalla Ajustes (Quemia 7.1, Zona H) — POR CATEGORÍAS como
// Duolingo (Kristian 2026-11-16): la última fila de Cuenta ya no
// existe (el engranaje de la Cuenta aparte abre esta pantalla) y
// aquí vive MÁS de lo que había en Cuenta, organizado en
// secciones: CUENTA (Vincular con Google, Tema, Idioma,
// Recordatorios, Notificaciones, Favoritos, Compartir progreso)
// y SOPORTE (Cómo se juega, Acerca de,
// Compartir la app, Buscar actualización). Tienda y Premium
// volvieron a Cuenta (Kristian 2026-11-16: "saca tienda y
// premium de configuraciones, déjalo en cuenta"). Nada se borra:
// todo lo que estaba en Cuenta sigue existiendo, repartido entre
// el perfil y estas categorías.
//
// Las filas usan el MISMO estilo de tarjeta redondeada que Cuenta
// (organización 6.3): tarjeta con borde de 1 pt, icono en chip
// tintado, título 17 pt peso 700, subtítulo 15 pt, chevron a la
// derecha. La fila es un duplicado fiel de la _Row de Cuenta (que
// es privada de su archivo) para no tocar su código mientras otra
// zona lo edita.
//
// La comprobación manual de actualización es la misma que tenía
// Cuenta (fix4, punto 7): fuerza el chequeo y dice qué pasó. El
// diálogo ya salió solo si hay versión nueva; si no, un aviso abajo.

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/accent.dart';
import '../services/analytics_sync.dart';
import '../services/auth_service.dart';
import '../services/localization.dart';
import '../services/sound_service.dart';
import '../services/update_check.dart';
import '../services/user_prefs.dart';
import '../widgets/lucide_icons.dart';
import 'onboarding_screen.dart';
import 'theme_screen.dart';

/// Colores de Ajustes según el tema: los mismos que Cuenta (fondo
/// blanco y tinta #4B4B4B en claro; fondo y tarjetas oscuros según
/// el acento en oscuro).
class _SettingsColors {
  const _SettingsColors({
    required this.bg,
    required this.ink,
    required this.inkSoft,
    required this.border,
    required this.card,
  });

  factory _SettingsColors.of(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return _SettingsColors(
        bg: AppAccent.darkBackground,
        ink: Colors.white,
        inkSoft: AppAccent.darkInkSoft,
        border: AppAccent.darkBorder,
        card: AppAccent.darkCard,
      );
    }
    return const _SettingsColors(
      bg: Colors.white,
      ink: Color(0xFF4B4B4B),
      inkSoft: Color(0xFF777777),
      border: Color(0xFFE5E5E5),
      card: Colors.white,
    );
  }

  final Color bg;
  final Color ink;
  final Color inkSoft;
  final Color border;

  /// Fondo de las tarjetas: blanco en claro, superficie oscura
  /// en oscuro.
  final Color card;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.onOpenScreen,
  });

  /// Abre una pantalla por su clave ('theme', 'reminder',
  /// 'notifications', 'howToPlay', 'language', 'version',
  /// 'favorites', 'stats'). Lo resuelve HomeScreen con
  /// _openScreenKey, igual que las filas de Cuenta.
  final void Function(String key) onOpenScreen;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    _loadGoogleState();
  }

  /// Comprobación manual en curso (para no lanzar dos a la vez).
  bool _checkingUpdate = false;

  /// Estado del enlace con Google (mudado de Cuenta, perfil estilo
  /// Duolingo 2026-11-16): la fila vive ahora en la sección
  /// CUENTA de Ajustes. El enlace y la desvinculación son los
  /// mismos de antes (ronda #8, cambio 09:08).
  bool _googleLinked = false;
  String? _googleEmail;
  var _googleBusy = false;

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
  ///
  /// Sin perfil local (el usuario entró "sin conexión" y no tiene
  /// nombre ni género guardados): NO se enlaza directo. Se abre el
  /// MISMO flujo de inicio (Quemia 7.7, Kristian 2026-11-13: "como
  /// si fuera la pantalla desde el principio") — elección crear
  /// perfil / entrar con Google — y al terminar se vuelve a
  /// Ajustes ya con la cuenta puesta. Con perfil local, se enlaza
  /// directo como antes (vincular Google a la cuenta que ya tiene).
  Future<void> _onGoogleRowTap() async {
    if (_googleBusy) return;
    if (_googleLinked) {
      await _showUnlinkDialog();
      return;
    }
    if (UserPrefs.userName.isEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OnboardingScreen(
            fromAccount: true,
            onFinished: () {
              Navigator.of(context).pop();
              _loadGoogleState();
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      );
      return;
    }
    setState(() => _googleBusy = true);
    final ok = await AuthService.linkWithGoogle();
    if (!mounted) return;
    if (!ok) {
      setState(() => _googleBusy = false);
      // Quemia 7.3: además del mensaje genérico, el CÓDIGO real del
      // fallo (p. ej. google_sign_in:unknownError si el selector ni
      // salió, o migration_failed): sin él no se puede diagnosticar.
      final code = AuthService.lastGoogleError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AnalyticsSync.firebaseReady
              ? (code == null
                  ? tr('googleSignInFailed')
                  : '${tr('googleSignInFailed')} [$code]')
              : tr('googleNeedInternet')),
        ),
      );
      return;
    }
    // Enlazado: quitar "Vinculando…" YA y enseñar el correo. El
    // respaldo de la nube se trae en segundo plano (Quemia 7.5):
    // con la conexión lenta tardaba y la fila se quedaba colgada
    // en "Vinculando…" aunque el enlace ya había salido bien.
    setState(() => _googleBusy = false);
    await _loadGoogleState();
    if (!mounted) return;
    unawaited(AnalyticsSync.restoreFromCloud().then((_) {
      if (mounted) _loadGoogleState();
    }));
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

  @override
  Widget build(BuildContext context) {
    final c = _SettingsColors.of(context);
    // Quemia 7.3: los iconos teal de antes siguen al acento del tema.
    final teal = AppAccent.primary;
    const violet = Color(0xFF8B5CF6);
    const blue = Color(0xFF3B82F6);
    const amber = Color(0xFFF59E0B);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(tr('settingsTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // CUENTA (como Duolingo): la cuenta de Google, el tema,
          // el idioma, los recordatorios, las notificaciones, los
          // favoritos, compartir el progreso y los referidos
          // (mudados de Cuenta, 2026-11-16).
          _SettingsSectionTitle(
            key: const ValueKey('settingsAccountSection'),
            title: tr('settingsAccountSection'),
          ),
          // Vincular con Google (mudado de Cuenta): respaldo con
          // la cuenta de Google (el mismo uid recupera el
          // progreso en otro teléfono). Si está vinculada, la fila
          // muestra el correo y al tocar ofrece desvincular.
          _SettingsRow(
            icon: LucideIcons.link,
            iconColor: blue,
            title: tr('accountLinkGoogle'),
            subtitle: _googleBusy
                ? tr('googleLinking')
                : _googleLinked && _googleEmail != null
                    ? _googleEmail!
                    : tr('accountLinkGoogleSub'),
            onTap: _onGoogleRowTap,
          ),
          // Tema: fila táctil con el subtítulo de la selección
          // actual (p. ej. "Verde · Claro"), que abre su propia
          // pantalla dedicada. El subtítulo se reconstruye solo al
          // cambiar el tema (los dos notifiers).
          ListenableBuilder(
            listenable: Listenable.merge([
              UserPrefs.themeAccentNotifier,
              UserPrefs.themeModeNotifier,
            ]),
            builder: (context, _) => _SettingsRow(
              icon: LucideIcons.sparkles,
              iconColor: violet,
              title: tr('themeTitle'),
              subtitle: themeSelectionSubtitle(),
              onTap: () => widget.onOpenScreen('theme'),
            ),
          ),
          // Idioma: abre el selector de idioma.
          _SettingsRow(
            icon: LucideIcons.globe,
            iconColor: blue,
            title: tr('accountLanguage'),
            subtitle: AppLang.supported
                .firstWhere((e) => e.$1 == AppLang.code,
                    orElse: () => AppLang.supported.first)
                .$2,
            onTap: () => widget.onOpenScreen('language'),
          ),
          // Recordatorios: el recordatorio diario de estudio.
          _SettingsRow(
            icon: LucideIcons.alarmClock,
            iconColor: violet,
            title: tr('accountReminder'),
            subtitle: UserPrefs.reminderOn
                ? tr('menuReminderOn')
                : tr('menuReminderOff'),
            onTap: () => widget.onOpenScreen('reminder'),
          ),
          // Notificaciones: la bandeja de avisos (antes solo se
          // abría desde la campana de arriba).
          _SettingsRow(
            icon: LucideIcons.bell,
            iconColor: teal,
            title: tr('inboxTitle'),
            subtitle: tr('accountNotificationsSub'),
            onTap: () => widget.onOpenScreen('notifications'),
          ),
          // Favoritos: los elementos guardados.
          _SettingsRow(
            icon: LucideIcons.star,
            iconColor: amber,
            title: tr('accountFavorites'),
            subtitle: tr('menuFavoritesSub'),
            onTap: () => widget.onOpenScreen('favorites'),
          ),
          // Compartir progreso: abre Mis estadísticas, donde vive
          // el botón de compartir el progreso como imagen (el
          // compartir es automático con Google vinculada).
          _SettingsRow(
            icon: LucideIcons.image,
            iconColor: teal,
            title: tr('accountShareProgress'),
            subtitle: tr('accountShareProgressSub'),
            onTap: () => widget.onOpenScreen('stats'),
          ),
          // Referidos (mudado de Cuenta, Kristian 2026-11-16,
          // simplificación aprobada): invita con tu código y los
          // dos ganan puntos.
          _SettingsRow(
            icon: LucideIcons.heart,
            iconColor: teal,
            title: tr('accountReferrals'),
            subtitle: tr('accountReferralsSub'),
            onTap: () => widget.onOpenScreen('referrals'),
          ),
          // SOPORTE (como Duolingo): cómo se juega, acerca de,
          // compartir la app y buscar actualización.
          // (Tienda y Premium ya NO viven aquí: Kristian
          // 2026-11-16 los devolvió a Cuenta.)
          _SettingsSectionTitle(
            key: const ValueKey('settingsSupportSection'),
            title: tr('settingsSupportSection'),
          ),
          // Cómo se juega: las reglas, como pantalla completa.
          _SettingsRow(
            icon: LucideIcons.circleHelp,
            iconColor: blue,
            title: tr('howToPlayTitle'),
            subtitle: tr('howToPlaySub'),
            onTap: () => widget.onOpenScreen('howToPlay'),
          ),
          // Acerca de (mudado de Cuenta).
          _SettingsRow(
            icon: LucideIcons.info,
            iconColor: violet,
            title: tr('accountAbout'),
            subtitle: tr('appSubtitle'),
            onTap: () => widget.onOpenScreen('about'),
          ),
          // Compartir la app (mudado de Cuenta): hoja nativa del
          // sistema, sin diálogo con el enlace.
          _SettingsRow(
            icon: LucideIcons.share2,
            iconColor: blue,
            title: tr('accountShareApp'),
            subtitle: tr('menuShare'),
            onTap: () => widget.onOpenScreen('shareApp'),
          ),
          // Buscar actualización: chequeo manual con la versión
          // instalada.
          _SettingsRow(
            icon: LucideIcons.download,
            iconColor: teal,
            title: tr('checkUpdateTitle'),
            subtitle: tr('checkUpdateSub').replaceFirst('%s', kDisplayVersion),
            onTap: _manualUpdateCheck,
          ),
        ],
      ),
    );
  }
}
/// Título de sección de Ajustes ("CUENTA", "SUSCRIPCIÓN",
/// "SOPORTE", como Duolingo): mayúsculas, gris, 15 pt peso 800,
/// con aire arriba.
class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = _SettingsColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: c.inkSoft,
        ),
      ),
    );
  }
}

/// Una fila de Ajustes como TARJETA redondeada: el mismo estilo
/// que las filas de Cuenta (organización 6.3) — tarjeta plana con
/// borde de 1 pt, sin sombra borrosa; icono en un chip tintado,
/// título 17 pt peso 700, subtítulo 15 pt gris, chevron gris a la
/// derecha.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
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
    final c = _SettingsColors.of(context);
    // En modo oscuro, los iconos llevan el color del acento, como
    // en Cuenta.
    final effectiveIconColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.primary
        : iconColor;
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
                    color: effectiveIconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: LucideIcon(icon, color: effectiveIconColor, size: 24),
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
