/// Pantalla entera CREA TU CONTRASEÑA (Kristian 2026-11-16):
/// después de comprobar con un OTP que el correo es suyo, la
/// contraseña se crea DENTRO de la app, sin ningún correo de
/// restablecer de Firebase.
///
/// La usa el flujo de correo tomado (onboarding): al guardar, el
/// padre sigue como si se hubiera entrado con Google (pantalla
/// de usuario → referido → notificaciones).
library;

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/set_password_form.dart';

class SetPasswordPage extends StatelessWidget {
  const SetPasswordPage({
    super.key,
    required this.email,
    required this.onBack,
    required this.onSaved,
  });

  /// Correo de la cuenta (la contraseña se enlaza a él).
  final String email;

  /// Volver atrás (flecha o botón del teléfono).
  final VoidCallback onBack;

  /// Al guardar bien: el padre avanza el flujo.
  final Future<void> Function() onSaved;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final sub =
        isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF777777);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onBack();
      },
      child: Scaffold(
        key: const ValueKey('setPasswordPage'),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              8 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const LucideIcon(LucideIcons.arrowLeft, size: 28),
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('obPasswordTitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr('accountSetPasswordSheetBody'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.4, color: sub),
                ),
                const SizedBox(height: 24),
                SetPasswordForm(email: email, onSaved: onSaved),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
