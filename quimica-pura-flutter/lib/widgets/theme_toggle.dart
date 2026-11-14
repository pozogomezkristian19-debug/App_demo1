// Interruptor rápido claro/oscuro con la Lottie "toogle" de
// LottieFiles (Kristian, 2026-11-14): cambia entre claro y oscuro
// SIN tocar el sistema de temas de Ajustes (allí siguen "sistema",
// "claro" y "oscuro"). Antes vivía en la tarjeta de Cuenta; desde
// 2026-11-14 vive en el menú lateral, a petición de Kristian
// ("me gusta, pero no ahí").
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../services/localization.dart';
import '../services/platform_check.dart';
import '../services/user_prefs.dart';

class ThemeToggle extends StatefulWidget {
  const ThemeToggle({super.key});

  @override
  State<ThemeToggle> createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<ThemeToggle>
    with SingleTickerProviderStateMixin {
  static const _dayRest = 0.05; // fotograma 10 de 200
  static const _nightRest = 0.5; // fotograma 100 de 200

  late final AnimationController _ctrl;
  var _animating = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    UserPrefs.themeModeNotifier.addListener(_syncToTheme);
  }

  @override
  void dispose() {
    UserPrefs.themeModeNotifier.removeListener(_syncToTheme);
    _ctrl.dispose();
    super.dispose();
  }

  /// El tema cambió en otro sitio: poner el interruptor en el
  /// estado que toca (salvo que esté animando por un toque aquí).
  void _syncToTheme() {
    if (!_animating && mounted) {
      _ctrl.value = UserPrefs.effectiveDark ? _nightRest : _dayRest;
    }
  }

  Future<void> _toggle() async {
    if (_animating) return;
    final toDark = !UserPrefs.effectiveDark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    _animating = true;
    try {
      await UserPrefs.saveThemeMode(toDark ? 'oscuro' : 'claro');
      if (!mounted) return;
      if (isFlutterTest || reduceMotion) {
        _ctrl.value = toDark ? _nightRest : _dayRest;
      } else if (toDark) {
        await _ctrl.animateTo(
          _nightRest,
          duration: const Duration(milliseconds: 900),
        );
      } else {
        await _ctrl.animateTo(1, duration: const Duration(milliseconds: 1200));
        if (mounted) _ctrl.value = _dayRest;
      }
    } catch (_) {
      // Si la pantalla se cierra a mitad de la animación, no pasa nada.
    } finally {
      _animating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Toda la fila es táctil (etiqueta + paisaje): el área de
    // toque es ancha y no exige acertar en el dibujo.
    return Semantics(
      button: true,
      label: tr('themeTitle'),
      child: GestureDetector(
        onTap: _toggle,
        child: Row(
          children: [
            Text(
              tr('themeTitle'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Lottie.asset(
              'assets/theme_toggle.json',
              width: 80,
              height: 44,
              fit: BoxFit.contain,
              controller: _ctrl,
              onLoaded: (composition) {
                _ctrl.duration = composition.duration;
                if (!_ctrl.isAnimating) {
                  _ctrl.value =
                      UserPrefs.effectiveDark ? _nightRest : _dayRest;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
