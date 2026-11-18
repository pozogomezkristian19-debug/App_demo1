// Puerta de identidad (Quemia 7.0, regla 09:19; revisada
// 2026-11-17): para JUGAR online hay que tener sesión — con
// Google O con correo. Antes la puerta solo dejaba pasar con
// Google, pero las casillas de Online ya se enseñan con
// cualquiera de los dos: un usuario con correo veía Amigos y al
// tocarlo le pedía Google. Todas las pantallas online (tabla,
// amigos, duelos, torneos, grupos, tienda) envuelven su contenido
// en `OnlineGate`: sin sesión, la pantalla muestra SOLO esta
// tarjeta limpia (texto + botón de Google + entrar con correo).
// El estudio nunca pasa por aquí: funciona sin internet y sin
// Google.
//
// `isGoogleLinked` y `onLinkGoogle` son inyectables para tests y
// previews; sin ellos se usa AuthService. El error, si el enlace
// falla, es UNA línea tranquila (googleSignInFailed o
// googleNeedInternet), nunca un diálogo ni rojo.

import 'package:flutter/material.dart';

import '../screens/onboarding_screen.dart';
import '../services/accent.dart';
import '../services/analytics_sync.dart';
import '../services/auth_service.dart';
import '../services/localization.dart';
import 'google_sign_in_button.dart';
import 'lucide_icons.dart';

class OnlineGate extends StatefulWidget {
  const OnlineGate({
    super.key,
    required this.child,
    this.isGoogleLinked,
    this.onLinkGoogle,
  });

  final Widget child;

  /// null = preguntar a AuthService.
  final bool? isGoogleLinked;

  /// null = AuthService.linkWithGoogle().
  final Future<bool> Function()? onLinkGoogle;

  @override
  State<OnlineGate> createState() => _OnlineGateState();
}

class _OnlineGateState extends State<OnlineGate> {
  bool? _linkedAfterTap;
  var _busy = false;
  String? _errorKey;
  String? _errorCode;

  bool get _isLinked =>
      (widget.isGoogleLinked ??
          _linkedAfterTap ??
          AuthService.isGoogleLinked) ||
      AuthService.isEmailLinked;

  /// Entra con correo (revisión 2026-11-17): la tarjeta solo
  /// ofrecía Google, y un usuario con cuenta de correo que estaba
  /// sin sesión no tenía cómo entrar desde aquí. Al volver se
  /// repinta la puerta para que ya enseñe el contenido.
  Future<void> _openEmailSignIn() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingScreen(
          fromAccount: true,
          onFinished: () => Navigator.of(context).pop(),
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _link() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorKey = null;
      _errorCode = null;
    });
    final ok =
        await (widget.onLinkGoogle?.call() ?? AuthService.linkWithGoogle());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _linkedAfterTap = true;
      } else {
        _errorKey = AnalyticsSync.firebaseReady
            ? 'googleSignInFailed'
            : 'googleNeedInternet';
        // Quemia 7.3: el código real del fallo, para diagnosticar.
        _errorCode = AuthService.lastGoogleError;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLinked) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Card(
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.10),
            color: isDark ? scheme.surfaceContainerHighest : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppAccent.primary.withValues(alpha: 0.14),
                    ),
                    alignment: Alignment.center,
                    child: LucideIcon(
                      LucideIcons.logIn,
                      size: 30,
                      color: AppAccent.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr('onlineNeedGoogle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // El botón de Google compartido (blanco, píldora,
                  // G en colores, sin borde negro), a todo lo ancho
                  // de la tarjeta.
                  SizedBox(
                    width: double.infinity,
                    child: GoogleSignInButton(
                      onPressed: _busy ? null : _link,
                      busy: _busy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _openEmailSignIn,
                    child: Text(
                      tr('onlineEnterWithEmail'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppAccent.primary,
                      ),
                    ),
                  ),
                  if (_errorKey != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorCode == null
                          ? tr(_errorKey!)
                          : '${tr(_errorKey!)} [$_errorCode]',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
