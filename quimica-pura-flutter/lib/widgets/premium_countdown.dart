// Contador EN VIVO del Premium: días · hh:mm:ss, tick cada segundo.
//
// Lee el vencimiento de PremiumService.expiresNotifier y repinta
// cada segundo. Al llegar a cero muestra 'Premium vencido' (el
// servicio ya habrá quitado el Premium solo por su propio
// temporizador de 1 s).

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/premium.dart';
import '../services/premium_service.dart';

/// Contador en vivo '12 d · 04:05:06' (o '04:05:06' si queda menos
/// de un día). [prefix] va delante ('Vence en ' / 'Te quedan ').
class PremiumCountdown extends StatefulWidget {
  const PremiumCountdown({
    super.key,
    this.prefix = 'Vence en ',
    this.fontSize = 18,
  });

  final String prefix;
  final double fontSize;

  @override
  State<PremiumCountdown> createState() => _PremiumCountdownState();
}

class _PremiumCountdownState extends State<PremiumCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: PremiumService.expiresNotifier,
      builder: (context, expires, _) {
        final remaining = premiumRemaining(expires);
        final scheme = Theme.of(context).colorScheme;
        if (remaining == Duration.zero) {
          return Text(
            'Premium vencido',
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w800,
              color: scheme.error,
            ),
          );
        }
        return Text(
          '${widget.prefix}${formatPremiumCountdown(remaining)}',
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        );
      },
    );
  }
}
