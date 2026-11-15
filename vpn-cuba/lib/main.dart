import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sing_box/sing_box.dart';

import 'home_screen.dart';
import 'vpn_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SingBox.instance.initialize(const SingBoxOptions(
      android: SingBoxAndroidOptions(
        notificationTitle: 'VPN Cuba',
        notificationContent: 'Conectado',
        notificationIcon: 'ic_vpn',
        showTrafficInNotification: false,
        showStopAction: true,
        stopActionTitle: 'Desconectar',
        sessionName: 'VPN Cuba',
      ),
    ));
  } catch (_) {
    // La app abre igual; si el motor no inició, conectar lo avisará.
  }
  runApp(VpnCubaApp(controller: VpnController()));
}

class VpnCubaApp extends StatelessWidget {
  const VpnCubaApp({super.key, required this.controller});

  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VPN Cuba',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        // Familia Quemia: Nunito + fondo oscuro teal de Quemia.
        fontFamily: 'Nunito',
        scaffoldBackgroundColor: const Color(0xFF0A1F1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00C2A8),
          surface: Color(0xFF122B24),
        ),
        useMaterial3: true,
      ),
      home: _Root(controller: controller),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root({required this.controller});

  final VpnController controller;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  @override
  void initState() {
    super.initState();
    // Precarga en segundo plano: al abrir la app se descarga la lista
    // de servidores, para que al tocar Conectar ya esté lista.
    unawaited(widget.controller.preloadServers());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowWarning());
  }

  Future<void> _maybeShowWarning() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(warnedKey) ?? false) return;
    if (!mounted) return;
    await showVpnWarningDialog(context);
    await prefs.setBool(warnedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => HomeScreen(
        state: widget.controller.uiState,
        onToggle: widget.controller.toggle,
        onShowAbout: () => showVpnWarningDialog(context),
      ),
    );
  }
}
