// Página de elección de inicio de sesión para Premium (SOLO WEB).
//
// Flujo (Kristian 2026-11-15, v4): al tocar DESBLOQUEAR CON
// PREMIUM (o el diamante, o el repaso) el invitado NO va directo
// ni al paywall ni al popup de Google: primero llega AQUÍ y elige
// cómo iniciar sesión — con Google o por correo. Después de
// iniciar sesión, la puerta (_openPaywall) abre el paywall; si
// cancela, vuelve atrás sin abrir nada.
//
// POR QUÉ existe esta página (defecto grave de v3, verificado en
// vivo 2026-11-15 20:18-20:22): la puerta anterior llamaba
// directamente a linkWithGoogle(), cuyo popup en web puede
// completarse SOLO con la sesión de Google ya guardada en ese
// navegador (perfil compartido de la nube: el popup se abre y se
// cierra sin que nadie elija nada, y linkWithGoogle devuelve
// true). El invitado llegaba al paywall sin haber elegido nada, y
// el diamante aparecía después para un "invitado" que ya no lo
// era. Con esta página el inicio es EXPLÍCITO: nadie inicia
// sesión sin haber tocado Google o Correo aquí. La puerta además
// re-chequea la sesión en vivo antes de abrir el paywall.
//
// Reutiliza el inicio que ya tiene la app: Google =
// AuthService.linkWithGoogle() (popup en web, el mismo de
// siempre); correo = AuthService.signInWithEmail() (correo +
// contraseña, la cuenta que ya existe — NO se inventa un registro
// nuevo aquí: quien no tiene cuenta de correo entra con Google).
// La migración del progreso al vincular la hace
// AuthService._runGoogleAuth/_runEmailAuth con el hook
// migrateProgressOnUidChange, como siempre.
//
// Diseño: pantalla FIJA, sin deslizar (como el paywall v3).
// Textos en español fijos, como el paywall (no tr()).

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/premium_service.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/quemia_field.dart';

/// Devuelve true si el usuario inició sesión (Google o correo),
/// false/null si canceló. La puerta vuelve a comprobar
/// [PremiumService.isSignedIn] en vivo antes de abrir el paywall.
class PremiumSignInChoiceScreen extends StatefulWidget {
  const PremiumSignInChoiceScreen({super.key});

  @override
  State<PremiumSignInChoiceScreen> createState() =>
      _PremiumSignInChoiceScreenState();
}

class _PremiumSignInChoiceScreenState
    extends State<PremiumSignInChoiceScreen> {
  /// 0 = elegir (Google / correo), 1 = formulario de correo.
  int _step = 0;
  bool _googleBusy = false;
  bool _emailBusy = false;
  String? _error;
  String? _resetDone;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (_googleBusy) return;
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    final ok = await AuthService.linkWithGoogle();
    if (!mounted) return;
    setState(() => _googleBusy = false);
    if (!ok) {
      setState(() => _error =
          'No se pudo iniciar sesión con Google. Inténtalo de nuevo.');
      return;
    }
    if (mounted) Navigator.of(context).pop<bool>(true);
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty || _emailBusy) return;
    setState(() {
      _emailBusy = true;
      _error = null;
      _resetDone = null;
    });
    final ok = await AuthService.signInWithEmail(email, password);
    if (!mounted) return;
    setState(() => _emailBusy = false);
    if (!ok) {
      setState(
          () => _error = 'El correo o la contraseña no son correctos.');
      return;
    }
    if (mounted) Navigator.of(context).pop<bool>(true);
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Escribe tu correo primero.');
      return;
    }
    setState(() {
      _error = null;
      _resetDone = null;
    });
    await AuthService.sendPasswordResetEmail(email);
    if (!mounted) return;
    setState(() =>
        _resetDone = 'Te mandamos un enlace para cambiar tu contraseña.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: _step == 0 ? _choiceBody(scheme) : _emailBody(scheme),
      ),
    );
  }

  Widget _choiceBody(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Inicia sesión para continuar',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Para pasar a Premium primero inicia sesión. '
          'Elige cómo quieres entrar.',
          style: TextStyle(fontSize: 16, color: scheme.onSurface),
        ),
        const Spacer(),
        if (_error != null) ...[
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.error,
            ),
          ),
          const SizedBox(height: 12),
        ],
        DuoButton.primary(
          label: _googleBusy ? 'CONECTANDO…' : 'CONTINUAR CON GOOGLE',
          onPressed: _googleBusy ? null : _signInWithGoogle,
        ),
        const SizedBox(height: 12),
        DuoButton.secondary(
          label: 'CONTINUAR CON CORREO',
          onPressed: _googleBusy
              ? null
              : () => setState(() {
                    _step = 1;
                    _error = null;
                  }),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _googleBusy
              ? null
              : () => Navigator.of(context).pop<bool>(false),
          child: const Text('Volver'),
        ),
      ],
    );
  }

  Widget _emailBody(ColorScheme scheme) {
    const blue = Color(0xFF3B82F6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _emailBusy
                ? null
                : () => setState(() {
                      _step = 0;
                      _error = null;
                      _resetDone = null;
                    }),
            child: const Text('← Elegir otra forma'),
          ),
        ),
        Text(
          'Entra con tu correo',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        QuemiaField(
          controller: _emailController,
          hint: 'Tu correo electrónico',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        QuemiaField(
          controller: _passwordController,
          hint: 'Contraseña',
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _showPassword = !_showPassword),
            icon: LucideIcon(
              _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
              size: 24,
              color: blue,
            ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _signInWithEmail(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.error,
            ),
          ),
        ],
        if (_resetDone != null) ...[
          const SizedBox(height: 8),
          Text(
            _resetDone!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
        const SizedBox(height: 16),
        DuoButton.primary(
          label: _emailBusy ? 'ENTRANDO…' : 'ENTRAR',
          onPressed: _emailController.text.trim().isNotEmpty &&
                  _passwordController.text.isNotEmpty &&
                  !_emailBusy
              ? _signInWithEmail
              : null,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _emailBusy ? null : _forgotPassword,
          child: const Text('¿Olvidaste tu contraseña?'),
        ),
        const Spacer(),
        Text(
          'Si aún no tienes una cuenta de correo, entra con Google.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}
