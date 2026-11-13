// Pantalla Ajustes (Quemia 7.1, Zona H): la última fila de Cuenta
// abre esta pantalla con todo lo que no es contenido principal:
// Tema, Recordatorios, Notificaciones, Cómo se juega, Buscar
// actualización, Idioma, Cambiar versión, Favoritos y Compartir
// progreso. Nada de esto vive ya en la lista principal de Cuenta.
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

import 'package:flutter/material.dart';

import '../services/accent.dart';
import '../services/localization.dart';
import '../services/progress.dart';
import '../services/sound_service.dart';
import '../services/update_check.dart';
import '../services/user_prefs.dart';
import '../widgets/lucide_icons.dart';
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
          // Notificaciones: la bandeja (antes solo se abría desde
          // la campana de la barra superior).
          _SettingsRow(
            icon: LucideIcons.bell,
            iconColor: amber,
            title: tr('inboxTitle'),
            subtitle: tr('settingsNotificationsSub'),
            onTap: () => widget.onOpenScreen('notifications'),
          ),
          // Cómo se juega: las reglas, como pantalla completa.
          _SettingsRow(
            icon: LucideIcons.circleHelp,
            iconColor: blue,
            title: tr('howToPlayTitle'),
            subtitle: tr('howToPlaySub'),
            onTap: () => widget.onOpenScreen('howToPlay'),
          ),
          // Buscar actualización: chequeo manual con la versión
          // instalada.
          _SettingsRow(
            icon: LucideIcons.download,
            iconColor: teal,
            title: tr('checkUpdateTitle'),
            subtitle:
                tr('checkUpdateSub').replaceFirst('%s', kDisplayVersion),
            onTap: _manualUpdateCheck,
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
          // Cambiar versión: Bachillerato o Universidad.
          _SettingsRow(
            icon: LucideIcons.refreshCw,
            iconColor: amber,
            title: tr('accountVersion'),
            subtitle: ProgressService.track == ProgressService.trackBach
                ? tr('trackBach')
                : tr('trackUni'),
            onTap: () => widget.onOpenScreen('version'),
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
        ],
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
    final effectiveIconColor =
        Theme.of(context).brightness == Brightness.dark
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child:
                      LucideIcon(icon, color: effectiveIconColor, size: 24),
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
