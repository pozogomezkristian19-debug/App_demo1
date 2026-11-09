import 'package:flutter/material.dart';
import 'screens/resolver_screen.dart';
import 'screens/aprender_screen.dart';
import 'screens/tabla_screen.dart';
import 'screens/practicar_screen.dart';
import 'screens/tips_screen.dart';

void main() {
  runApp(const MelliQuiApp());
}

class MelliQuiApp extends StatelessWidget {
  const MelliQuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF14B8A6);
    const deep = Color(0xFF0C1A17);
    return MaterialApp(
      title: 'Melli-Qui',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: deep,
        colorScheme: const ColorScheme.dark(
          primary: teal,
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
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
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
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundImage: AssetImage('assets/logo-circular.png'),
            backgroundColor: Colors.transparent,
          ),
        ),
        title: Text(_titles[_index]),
        backgroundColor: const Color(0xFF0C1A17),
        centerTitle: false,
      ),
      body: SafeArea(child: _pages[_index]),
      // Solo barra inferior, sin menú hamburguesa ni barra superior con menú.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: const Color(0xFF0F211D),
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
