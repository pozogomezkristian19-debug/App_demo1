/// Formulario para crearle una contraseña a una cuenta de Google
/// (Kristian 2026-11-15): campo de contraseña con ojo, lista de
/// las 5 reglas fuertes (las mismas del registro por correo) y
/// GUARDAR CONTRASEÑA, que solo se activa con las 5 reglas
/// cumplidas. Al guardar se enlaza la credencial a la cuenta
/// actual (el uid NO cambia); si falla, el error sale en una
/// línea dentro del formulario.
///
/// Lo usan la hoja de Cuenta (`_SetPasswordSheet`) y la página
/// entera del flujo de correo tomado (`SetPasswordPage`): el
/// formulario NO cierra nada — el padre decide qué hacer al
/// guardar bien (la hoja se cierra; la página avanza el flujo).
library;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/localization.dart';
import 'duo_button.dart';
import 'lucide_icons.dart';
import 'password_rules.dart';
import 'quemia_field.dart';

class SetPasswordForm extends StatefulWidget {
  const SetPasswordForm({
    super.key,
    required this.email,
    required this.onSaved,
  });

  /// Correo de la cuenta (la contraseña se enlaza a él).
  final String email;

  /// Al guardar bien: el padre cierra o avanza.
  final Future<void> Function() onSaved;

  @override
  State<SetPasswordForm> createState() => _SetPasswordFormState();
}

class _SetPasswordFormState extends State<SetPasswordForm> {
  final _passwordController = TextEditingController();
  var _showPassword = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  String get _password => _passwordController.text;

  Future<void> _save() async {
    if (!isStrongPassword(_password) || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await AuthService.linkPassword(widget.email, _password);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      final code = AuthService.lastEmailError ?? '';
      setState(() {
        _error = code.contains('email-already-in-use')
            ? tr('obEmailInUse')
            : tr('accountSetPasswordFailed');
      });
      return;
    }
    await widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('setPasswordForm'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuemiaField(
          controller: _passwordController,
          hint: tr('obPasswordHint'),
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _showPassword = !_showPassword),
            icon: LucideIcon(
              _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
              size: 24,
              color: const Color(0xFF3B82F6),
            ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 12),
        PasswordRules(password: _password),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        DuoButton.primary(
          label: tr('accountSetPasswordSave').toUpperCase(),
          onPressed: isStrongPassword(_password) && !_busy ? _save : null,
          fontSize: 17,
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ],
      ],
    );
  }
}
