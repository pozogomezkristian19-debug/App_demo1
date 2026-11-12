// Puerta de identidad (Quemia 7.0, regla 09:19): para JUGAR online
// hay que tener la cuenta de Google vinculada. Todas las pantallas
// online (tabla, amigos, duelos, torneos, grupos, tienda) envuelven
// su contenido en `OnlineGate`: sin Google, la pantalla muestra
// SOLO esta tarjeta limpia (texto + botón de Google). El estudio
// nunca pasa por aquí: funciona sin internet y sin Google.
//
// `isGoogleLinked` y `onLinkGoogle` son inyectables para tests y
// previews; sin ellos se usa AuthService. El error, si el enlace
// falla, es UNA línea tranquila (googleSignInFailed o
// googleNeedInternet), nunca un diálogo ni rojo.

import 'package:flutter/material.dart';

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

  bool get _isLinked =>
      widget.isGoogleLinked ??
      _linkedAfterTap ??
      AuthService.isGoogleLinked;

  Future<void> _link() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorKey = null;
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
                      color: const Color(0xFF00C2A8).withValues(alpha: 0.14),
                    ),
                    alignment: Alignment.center,
                    child: const LucideIcon(
                      LucideIcons.logIn,
                      size: 30,
                      color: Color(0xFF00C2A8),
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
                  if (_errorKey != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      tr(_errorKey!),
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
