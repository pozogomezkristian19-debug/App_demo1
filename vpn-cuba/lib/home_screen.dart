import 'package:flutter/material.dart';

import 'vpn_controller.dart';

// Pantalla única, con identidad propia de VPN y lenguaje de familia
// Quemia solo en diseño: Nunito, botones SÓLIDOS estilo Duolingo con
// labio 4 pt más oscuro, SIN gradiente / brillo / sombra borrosa,
// texto extra-bold en mayúsculas. Un solo color de acción: el teal de
// Quemia como acento de familia. Sin personajes ni caras: el único
// detalle gráfico es el anillo orbital de Quemia, en pequeño, en la
// cabecera, y un escudo al conectar. Nada de gemelas aquí.

const _kBackground = Color(0xFF0A1F1A); // Fondo oscuro teal de Quemia.
const _kCard = Color(0xFF122B24); // Tarjeta oscura teal de Quemia.
const _kText = Color(0xFFFFFFFF);
const _kMuted = Color(0xFF8A9A93); // Gris verdoso de Quemia en oscuro.
const _kTeal = Color(0xFF00C2A8); // Teal de Quemia.
const _kTealLip = Color(0xFF00A18D); // Labio del teal.

/// Aviso honesto: solo en el primer inicio y al tocar el icono de info.
/// Nunca en la pantalla principal.
Future<void> showVpnWarningDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: _kCard,
      title: const Text('Antes de empezar'),
      content: const Text(
        'VPN Cuba usa servidores públicos gratuitos: pueden ser lentos, '
        'fallar o cambiar de un día a otro.\n\n'
        'No la uses para banca ni para contraseñas importantes.\n\n'
        'Gratis, sin registro y sin pagos. Solo toca Conectar y la app '
        'hace el resto.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.state,
    required this.onToggle,
    required this.onShowAbout,
  });

  final VpnUiState state;
  final VoidCallback onToggle;
  final VoidCallback onShowAbout;

  @override
  Widget build(BuildContext context) {
    final connected = state.isConnected;
    final buttonLabel = switch (state.phase) {
      VpnPhase.searching => 'BUSCANDO',
      VpnPhase.connecting => 'CONECTANDO',
      VpnPhase.connected => 'DESCONECTAR',
      _ => 'CONECTAR',
    };

    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/ring_logo.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VPN CUBA',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: _kText,
                        ),
                      ),
                      Text(
                        'De la familia Quemia',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 14,
                          color: _kMuted,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onShowAbout,
                    icon: const Icon(Icons.info_outline, color: _kMuted),
                    tooltip: 'Acerca de',
                  ),
                ],
              ),
              const Spacer(),
              // Al conectar: escudo teal, detalle propio de VPN.
              if (connected) ...[
                const Icon(Icons.shield, size: 40, color: _kTeal),
                const SizedBox(height: 10),
              ],
              Text(
                state.statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _kText,
                ),
              ),
              if (connected) ...[
                const SizedBox(height: 10),
                if (state.country != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on,
                          size: 18, color: _kMuted),
                      const SizedBox(width: 4),
                      Text(
                        state.country!,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB8CFC8),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                Text(
                  state.elapsed,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: _kText,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (state.ip != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'IP ${state.ip}',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: _kMuted,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 44),
              _ConnectButton(
                color: _kTeal,
                lipColor: _kTealLip,
                label: buttonLabel,
                busy: state.isBusy,
                onTap: onToggle,
              ),
              const SizedBox(height: 20),
              Text(
                state.hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: _kMuted,
                ),
              ),
              const Spacer(),
              const Text(
                'Gratis · Sin registro · Sin pagos',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: _kMuted,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón grande redondo: teal sólido + labio 4 pt más oscuro.
/// Sin gradiente, sin brillo, sin sombra borrosa.
class _ConnectButton extends StatelessWidget {
  const _ConnectButton({
    required this.color,
    required this.lipColor,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final Color color;
  final Color lipColor;
  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 216,
        height: 221,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Labio inferior 4 pt más oscuro (estilo Duolingo, sólido).
            Container(
              width: 216,
              height: 216,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lipColor,
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 216,
                  height: 216,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (busy)
                        const SizedBox(
                          width: 54,
                          height: 54,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 4,
                          ),
                        )
                      else
                        const Icon(
                          Icons.power_settings_new,
                          size: 64,
                          color: Colors.white,
                        ),
                      const SizedBox(height: 10),
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
