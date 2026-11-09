import 'package:flutter/material.dart';
import 'screens/resolver_screen.dart';
import 'screens/aprender_screen.dart';
import 'screens/tabla_screen.dart';
import 'screens/practicar_screen.dart';
import 'screens/tips_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/user_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserPrefs.load();
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

  static const List<Widget> _pages = [
    ResolverScreen(),
    AprenderScreen(),
    TablaScreen(),
    PracticarScreen(),
    TipsScreen(),
  ];

  static const List<String> _titles = [
    'Resolver',
    'Aprender',
    'Tabla periódica',
    'Practicar',
    'Tips',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final greeting = UserPrefs.greeting;
    return Scaffold(
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
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: 'Practicar',
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
