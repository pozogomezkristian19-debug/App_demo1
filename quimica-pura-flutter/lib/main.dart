import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/resolver_screen.dart';
import 'screens/aprender_screen.dart';
import 'screens/tabla_screen.dart';
import 'screens/practicar_screen.dart';
import 'screens/tips_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/progress.dart';
import 'services/user_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserPrefs.load();
  await ProgressService.load();
  runApp(const MelliQuiApp());
}

class MelliQuiApp extends StatefulWidget {
  const MelliQuiApp({super.key});
  @override
  State<MelliQuiApp> createState() => _MelliQuiAppState();
}

class _MelliQuiAppState extends State<MelliQuiApp> {
  bool _isDark = UserPrefs.isDark;
  bool _onboardingDone = UserPrefs.onboardingDone;

  static const _teal = Color(0xFF14B8A6);
  static const _deep = Color(0xFF0C1A17);

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _deep,
      colorScheme: const ColorScheme.dark(
        primary: _teal,
        secondary: Color(0xFF2DD4BF),
        surface: Color(0xFF122622),
        onSurface: Color(0xFFE8F5F1),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF122622),
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F211D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 16, height: 1.45),
        bodyLarge: TextStyle(fontSize: 17, height: 1.45),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F1E7),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0F766E),
        secondary: _teal,
        surface: Colors.white,
        onSurface: Color(0xFF1C2B28),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 16, height: 1.45),
        bodyLarge: TextStyle(fontSize: 17, height: 1.45),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _toggleTheme() async {
    final next = !_isDark;
    setState(() => _isDark = next);
    await UserPrefs.saveDarkMode(next);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Melli-Qui',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: _onboardingDone
          ? HomeScreen(isDark: _isDark, onToggleTheme: _toggleTheme)
          : OnboardingScreen(
              onFinished: () => setState(() => _onboardingDone = true),
            ),
    );
  }
}

/// Botoncito de tema: lunita con nubes en modo oscuro, sol en modo claro.
class _ThemeToggleIcon extends StatelessWidget {
  const _ThemeToggleIcon({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (!isDark) {
      // Modo claro: el sol.
      return const Icon(Icons.wb_sunny_rounded, size: 24);
    }
    // Modo oscuro: lunita con nubes.
    return const Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.nightlight_round, size: 24),
        Positioned(
          right: -3,
          bottom: -2,
          child: Icon(Icons.cloud, size: 14),
        ),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.isDark, required this.onToggleTheme});
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // La primera pantalla es el camino de niveles (Niveles), como en
  // Duolingo; Resolver queda como una opción más.
  static const List<Widget> _pages = [
    PracticarScreen(),
    ResolverScreen(),
    AprenderScreen(),
    TablaScreen(),
    TipsScreen(),
  ];

  static const List<String> _titles = [
    'Niveles',
    'Resolver',
    'Aprender',
    'Tabla periódica',
    'Tips',
  ];

  /// Abre el chat de WhatsApp del creador.
  ///
  /// Secuencia robusta para un teléfono Android real:
  /// 1) El enlace wa.me con el manejo por defecto de la plataforma: en
  ///    Android, WhatsApp registra wa.me como enlace de la app, así que
  ///    el sistema lo abre directo en WhatsApp si está instalada.
  /// 2) Si eso falla, el esquema propio de WhatsApp
  ///    (whatsapp://send?phone=...).
  /// El aviso de error solo sale si fallan las dos.
  Future<void> _openWhatsApp(BuildContext context) async {
    final waMe = Uri.parse('https://wa.me/5356519431');
    final appScheme = Uri.parse('whatsapp://send?phone=5356519431');
    var opened = false;
    try {
      if (await canLaunchUrl(waMe)) {
        opened = await launchUrl(waMe, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      try {
        if (await canLaunchUrl(appScheme)) {
          opened = await launchUrl(appScheme,
              mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }

  /// Hoja "Acerca de Melli-Qui" con los datos de soporte.
  void _showAbout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  child: Image(
                    image: AssetImage('assets/logo.png'),
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Melli-Qui',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('Química Pura — Universidad'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Tu app de Química Pura para la universidad: resolver problemas paso a paso, estudiar, practicar por niveles y llegar con tips al examen.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text('Creador: CraigKamer',
                style: TextStyle(fontSize: 16)),
            const Text('Teléfono (Cuba): +53 56519431',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                      const ClipboardData(text: '+5356519431'));
                  if (!context.mounted) return;
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Teléfono copiado al portapapeles')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar teléfono'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final greeting = UserPrefs.greeting;
    return Scaffold(
      // Botón flotante de WhatsApp, visible en las 5 secciones:
      // lleva directo al chat del creador.
      floatingActionButton: FloatingActionButton(
        tooltip: 'Escribir por WhatsApp',
        backgroundColor: const Color(0xFF25D366),
        onPressed: () => _openWhatsApp(context),
        child: const Image(
          image: AssetImage('assets/whatsapp.png'),
          width: 32,
          height: 32,
        ),
      ),
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            child: Image(
              image: AssetImage('assets/logo.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titles[_index]),
            if (UserPrefs.userName.isNotEmpty)
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Acerca de Melli-Qui',
            onPressed: () => _showAbout(context),
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            tooltip: widget.isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
            onPressed: widget.onToggleTheme,
            icon: _ThemeToggleIcon(isDark: widget.isDark),
          ),
        ],
        centerTitle: false,
      ),
      body: SafeArea(child: _pages[_index]),
      // Solo barra inferior, sin menú hamburguesa ni barra superior con menú.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: const Color(0xFF14B8A6).withValues(alpha: 0.25),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Niveles',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Resolver',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Aprender',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Tabla',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outlined),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Tips',
          ),
        ],
      ),
    );
  }
}
