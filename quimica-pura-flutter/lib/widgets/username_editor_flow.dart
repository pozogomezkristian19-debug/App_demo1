// Editor de nombre de usuario compartido (Kristian 2026-11-17):
// la MISMA pantalla de elegir nombre ("Personaliza tu nombre de
// usuario" + "¡Se ve genial!") se abre desde Cuenta y desde el
// editor de avatares ("Cambiar nombre de usuario" antes de los
// avatares). Antes vivía privada en account_screen.dart
// (_CompleteProfileFlow); se sacó aquí para reutilizarla sin
// duplicar la pantalla.
import 'package:flutter/material.dart';

import '../screens/onboarding_screen.dart';
import '../services/accent.dart';
import '../services/localization.dart';
import '../services/referral_service.dart';
import '../services/user_prefs.dart';
import 'duo_button.dart';
import 'motion.dart';
import 'twin_avatars.dart';

/// Flujo de elegir/cambiar el nombre de usuario: UsernameChoicePage
/// con el nombre actual ya escrito; al guardar muestra
/// "¡Se ve genial!" y devuelve true al volver.
class UsernameEditorFlow extends StatefulWidget {
  const UsernameEditorFlow({super.key, required this.base});

  /// Nombre sugerido (primer nombre o prefijo del correo).
  final String base;

  @override
  State<UsernameEditorFlow> createState() => _UsernameEditorFlowState();
}

class _UsernameEditorFlowState extends State<UsernameEditorFlow> {
  var _saved = false;
  var _savedName = '';

  Future<void> _onConfirm(String chosen) async {
    final claimed = await ReferralService.claimUsername(chosen);
    if (!mounted) return;
    setState(() {
      _saved = true;
      _savedName = claimed;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_saved) {
      return _UsernameSavedScreen(
        username: _savedName,
        onOk: () => Navigator.of(context).pop(true),
      );
    }
    // Límite de cambio cada 10 días (Kristian 2026-11-17): si el
    // último cambio fue hace menos de 10 días, no se abre el
    // editor: sale la pantalla de espera con la fecha en que se
    // podrá cambiar de nuevo. El primer reclamo nunca se bloquea
    // (sin cambio anterior no hay fecha). Cubre Cuenta y avatares
    // con este solo cambio, porque los dos abren este flujo.
    final availableOn = UserPrefs.usernameChangeAvailableOn();
    if (availableOn != null) {
      return _UsernameChangeWaitScreen(
        availableOn: availableOn,
        onOk: () => Navigator.of(context).pop(false),
      );
    }
    return UsernameChoicePage(
      base: widget.base,
      prefillField: true,
      titleText: tr('usernamePersonalizeTitle'),
      bodyText: tr('usernamePersonalizeBody'),
      onConfirm: _onConfirm,
      onBack: () => Navigator.of(context).pop(false),
      onSkip: () => Navigator.of(context).pop(false),
    );
  }
}

/// Fecha en que se podrá cambiar el nombre de nuevo: "27 de
/// noviembre" (es) / "November 27" (en) / "27/11" (resto).
String _formatAvailableDate(DateTime date) {
  const monthsEs = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  const monthsEn = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  if (AppLang.code == 'es') {
    return '${date.day} de ${monthsEs[date.month - 1]}';
  }
  if (AppLang.code == 'en') {
    return '${monthsEn[date.month - 1]} ${date.day}';
  }
  return '${date.day}/${date.month}';
}

/// Pantalla de espera del límite de 10 días: dice cuándo se podrá
/// cambiar el nombre de nuevo y vuelve sin abrir el editor. Mismo
/// estilo que la pantalla de "¡Se ve genial!".
class _UsernameChangeWaitScreen extends StatelessWidget {
  const _UsernameChangeWaitScreen({
    required this.availableOn,
    required this.onOk,
  });

  final DateTime availableOn;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final sub =
        isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF777777);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StaggeredEntrance(
                index: 0,
                child: Center(
                  child: CompanionAvatar(
                    companion: companionOfTheDay(),
                    size: 120,
                    ring: false,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              StaggeredEntrance(
                index: 1,
                child: Text(
                  tr('usernameCooldownTitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StaggeredEntrance(
                index: 2,
                child: Text(
                  tr('usernameCooldownBody').replaceFirst(
                    '%s',
                    _formatAvailableDate(availableOn),
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.4, color: sub),
                ),
              ),
              const Spacer(),
              StaggeredEntrance(
                index: 3,
                child: DuoButton.primary(
                  label: tr('okWord'),
                  onPressed: onOk,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "¡Se ve genial!" (punto 10): tras guardar el nombre de usuario.
/// La melliza del día (nunca el búho), el nombre con @ y el botón
/// OK que vuelve a Cuenta.
class _UsernameSavedScreen extends StatelessWidget {
  const _UsernameSavedScreen({
    required this.username,
    required this.onOk,
  });

  final String username;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final sub =
        isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF777777);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Celebración por fases (pulido 2026-11-16): melliza
              // → título → texto → @nombre → botón, 100 ms entre
              // fases, nunca todo a la vez. La melliza queda
              // ESTÁTICA (Kristian 2026-11-16: sin animación de
              // la mascota — el salto con estrellitas se quitó).
              StaggeredEntrance(
                index: 0,
                child: Center(
                  child: CompanionAvatar(
                    companion: companionOfTheDay(),
                    size: 120,
                    ring: false,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              StaggeredEntrance(
                index: 1,
                child: Text(
                  tr('usernameSavedTitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StaggeredEntrance(
                index: 2,
                child: Text(
                  tr('usernameSavedBody'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.4, color: sub),
                ),
              ),
              if (username.isNotEmpty) ...[
                const SizedBox(height: 12),
                StaggeredEntrance(
                  index: 3,
                  child: Text(
                    '@$username',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppAccent.primary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              StaggeredEntrance(
                index: 4,
                child: DuoButton.primary(
                  label: tr('okWord'),
                  onPressed: onOk,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
