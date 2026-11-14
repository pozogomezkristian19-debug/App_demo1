import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../services/localization.dart';
import '../services/platform_check.dart';

/// Pantalla de carga (Quemia 7.7, Kristian 2026-11-14: después de
/// pasar cualquiera de las 3 formas de empezar — crear perfil,
/// entrar con la cuenta o invitado — se muestra esta animación de
/// carga y al terminar se carga la pantalla de Niveles): el
/// círculo teal de LottieFiles (assets/loading.json, 400x400,
/// 24 fps, 72 fotogramas = 3 s por vuelta, vectores puros) con
/// "Cargando…" debajo. La espera la lleva quien la muestra
/// (OnboardingScreen: 3 s, una vuelta completa, y luego
/// onFinished); esta pantalla solo dibuja la animación. En pruebas
/// queda fija a mitad (el fotograma 0 es casi vacío: solo un
/// puntito verde).
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/loading.json',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                controller: _ctrl,
                onLoaded: (composition) {
                  _ctrl.duration = composition.duration;
                  if (isFlutterTest) {
                    // A mitad: el círculo ya dibujado.
                    _ctrl.value = 0.5;
                  } else if (!_ctrl.isAnimating) {
                    _ctrl.repeat();
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                tr('loading'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
