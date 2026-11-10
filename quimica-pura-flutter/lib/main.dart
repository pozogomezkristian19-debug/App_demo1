import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data/periodic_table.dart';
import 'data/search_index.dart';
import 'screens/aprender_screen.dart';
import 'screens/branches_screen.dart';
import 'screens/challenge_screen.dart';
import 'screens/compare_screen.dart';
import 'screens/constants_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/flashcards_screen.dart';
import 'screens/formula_screen.dart';
import 'screens/glossary_screen.dart';
import 'screens/lab_screen.dart';
import 'screens/lab_sim_screen.dart';
import 'screens/language_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/practicar_screen.dart';
import 'screens/reference_tables_screen.dart';
import 'screens/reminder_screen.dart';
import 'screens/resolver_screen.dart';
import 'screens/search_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/tabla_screen.dart';
import 'screens/table_quiz_screen.dart';
import 'screens/timed_exam_screen.dart';
import 'screens/tips_screen.dart';
import 'screens/topic_detail_screen.dart';
import 'screens/version_screen.dart';
import 'services/favorites.dart';
import 'services/localization.dart';
import 'services/nav_requests.dart';
import 'services/notes.dart';
import 'services/progress.dart';
import 'services/user_prefs.dart';
import 'widgets/element_sheet.dart';

/// URL de la página de descarga de Melli-Qui (landing en GitHub Pages).
const String kLandingUrl =
    'https://pozogomezkristian19-debug.github.io/App_demo1/';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserPrefs.load();
  // La pista guardada (Bachillerato o Universidad) se carga antes del
  // progreso, porque las claves de guardado dependen de la pista.
  ProgressService.track = UserPrefs.track;
  await ProgressService.load();
  await NotesService.load();
  await FavoritesService.load();
  await AppLang.load();
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

  /// Cada vez que cambia la versión (Bachillerato/Universidad), este
  /// contador cambia y toda la pantalla principal se reconstruye desde
  /// cero con la versión nueva, como si cambiara la app entera.
  int _reloadToken = 0;

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
      scaffoldBackgroundColor: const Color(0xFFF7F4EE),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0F766E),
        secondary: _teal,
        surface: Colors.white,
        onSurface: Color(0xFF1C2B28),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF7F4EE),
        foregroundColor: Color(0xFF1C2B28),
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFF14B8A6),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFF0F766E).withValues(alpha: 0.35),
          ),
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

  void _reloadApp() {
    setState(() => _reloadToken++);
  }

  @override
  Widget build(BuildContext context) {
    // Al cambiar el idioma, AppLang.notifier avisa y se reconstruye toda
    // la app con los textos nuevos, sin reiniciar.
    return ValueListenableBuilder<String>(
      valueListenable: AppLang.notifier,
      builder: (context, lang, _) => MaterialApp(
        title: 'Melli-Qui',
        debugShowCheckedModeBanner: false,
        theme: _lightTheme(),
        darkTheme: _darkTheme(),
        themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
        home: _onboardingDone
            ? KeyedSubtree(
                key: ValueKey('home-$_reloadToken'),
                child: HomeScreen(
                  isDark: _isDark,
                  onToggleTheme: _toggleTheme,
                  onTrackChanged: _reloadApp,
                ),
              )
            : OnboardingScreen(
                onFinished: () => setState(() => _onboardingDone = true),
              ),
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
  const HomeScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onTrackChanged,
  });
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onTrackChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // La primera pantalla es el camino de niveles (Niveles), como en
  // Duolingo; Resolver queda como una opción más. Niveles lleva la
  // pista como clave: al cambiar de versión se crea de nuevo.
  List<Widget> get _pages => [
        PracticarScreen(key: ValueKey(ProgressService.track)),
        const ResolverScreen(),
        const AprenderScreen(),
        const TablaScreen(),
        const TipsScreen(),
      ];

  /// Títulos de las 5 secciones, en el idioma actual.
  List<String> get _titles => [
        tr('tabLevels'),
        tr('tabResolver'),
        tr('tabLearn'),
        tr('tableTitle'),
        tr('tipsTitle'),
      ];

  /// Temas de la pista actual, en orden (para Mis estadísticas).
  List<String> get _trackTopics => ProgressService.track == ProgressService.trackBach
      ? bachTopics
      : uniTopics;

  /// Ir a una pestaña, con una petición opcional para la pantalla
  /// destino (abrir un solucionador, empezar el repaso, filtrar Tabla).
  void _goToTab(
    int i, {
    String? openSolver,
    bool startReview = false,
    String? tableQuery,
    int? tableTab,
  }) {
    if (openSolver != null) NavRequests.openSolverTitle = openSolver;
    if (startReview) NavRequests.startReview = true;
    if (tableQuery != null) NavRequests.tableQuery = tableQuery;
    if (tableTab != null) NavRequests.tableTab = tableTab;
    setState(() => _index = i);
  }

  /// Abre una pantalla del menú o de la búsqueda por su clave.
  void _openScreenKey(String key) {
    Widget? page;
    switch (key) {
      case 'branches':
        page = const BranchesScreen();
      case 'lab':
        page = const LabScreen();
      case 'stats':
        page = StatsScreen(trackTopics: _trackTopics);
      case 'flashcards':
        page = const FlashcardsScreen();
      case 'timed':
        page = const TimedExamScreen();
      case 'challenge':
        page = const ChallengeScreen();
      case 'glossary':
        page = const GlossaryScreen();
      case 'compare':
        page = const CompareScreen();
      case 'notes':
        page = const NotesScreen();
      case 'tables':
        page = const ReferenceTablesScreen();
      case 'formulas':
        page = const FormulaScreen();
      case 'constants':
        page = const ConstantsScreen();
      case 'favorites':
        page = const FavoritesScreen();
      case 'reminder':
        page = const ReminderScreen();
      case 'language':
        page = const LanguageScreen();
      case 'tableQuiz':
        page = const TableQuizScreen();
      case 'labSim':
        page = const LabSimScreen();
      case 'version':
        page = VersionScreen(onVersionChanged: widget.onTrackChanged);
      case 'review':
        _goToTab(0, startReview: true);
        return;
    }
    if (page != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => page!),
      );
    }
  }

  /// Lo que pasa al tocar un resultado de la búsqueda.
  void _onEntryTap(SearchEntry entry) {
    switch (entry.kind) {
      case 'topic':
        final topic = findTopic(entry.target);
        if (topic != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => TopicDetailScreen(topic: topic)),
          );
        }
      case 'levels':
        Navigator.of(context).pop();
        _goToTab(0);
      case 'solver':
        Navigator.of(context).pop();
        _goToTab(1, openSolver: entry.target);
      case 'element':
        final z = int.tryParse(entry.target) ?? 0;
        final element = allElements
            .where((e) => e.atomicNumber == z)
            .firstOrNull;
        if (element != null) showElementSheet(context, element);
      case 'formula':
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FormulaScreen()),
        );
      case 'glossary':
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => GlossaryScreen(initialQuery: entry.target)),
        );
      case 'screen':
        Navigator.of(context).pop();
        _openScreenKey(entry.target);
    }
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(onEntryTap: _onEntryTap),
      ),
    );
  }

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
        SnackBar(content: Text(tr('whatsappFail'))),
      );
    }
  }

  /// Diálogo para compartir la app: el enlace de descarga, para copiar
  /// o para mandar por WhatsApp.
  void _showShareApp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('menuShare')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Pásale Melli-Qui a otros estudiantes de química:'),
            const SizedBox(height: 12),
            SelectableText(kLandingUrl),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                  const ClipboardData(text: kLandingUrl));
              if (!context.mounted) return;
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enlace copiado')),
              );
            },
            child: const Text('Copiar enlace'),
          ),
          TextButton(
            onPressed: () async {
              final uri = Uri.parse(
                  'https://wa.me/?text=${Uri.encodeComponent('Descarga Melli-Qui, la app de química pura: $kLandingUrl')}');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('WhatsApp'),
          ),
        ],
      ),
    );
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Melli-Qui',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(tr('appSubtitle')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              tr('aboutBody'),
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text('${tr('creatorWord')}: CraigKamer',
                style: const TextStyle(fontSize: 16)),
            Text('${tr('phoneWord')}: +53 56519431',
                style: const TextStyle(fontSize: 16)),
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
                    SnackBar(content: Text(tr('phoneCopied'))),
                  );
                },
                icon: const Icon(Icons.copy),
                label: Text(tr('copyPhone')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Una fila del menú de hamburguesa: solo abre su pantalla. Nada de
  /// listas sueltas dentro del menú: cada cosa tiene su pantalla propia.
  Widget _drawerItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final greeting = AppLang.greeting();
    return PopScope(
      // Botón atrás: primero cierra lo abierto por dentro (quiz,
      // solucionador); si no hay nada, vuelve a Niveles; solo en
      // Niveles y sin nada abierto se sale de la app.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (BackNav.handle()) return;
        if (_index != 0) {
          setState(() => _index = 0);
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        // Botón flotante de WhatsApp, visible en las 5 secciones:
        // lleva directo al chat del creador.
        floatingActionButton: FloatingActionButton(
          tooltip: tr('writeWhatsApp'),
          backgroundColor: const Color(0xFF25D366),
          onPressed: () => _openWhatsApp(context),
          child: const Image(
            image: AssetImage('assets/whatsapp.png'),
            width: 32,
            height: 32,
          ),
        ),
        // Menú hamburguesa: el organizador de la app. Cada fila abre su
        // propia pantalla; nada suelto ni repetido dentro del menú.
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      child: Image(
                        image: AssetImage('assets/logo.png'),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Melli-Qui',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(tr('appSubtitle')),
                  ],
                ),
              ),
              _drawerItem(
                icon: Icons.hub,
                title: tr('menuBranches'),
                subtitle: 'Orgánica, Inorgánica, Analítica, Fisicoquímica',
                onTap: () => _openScreenKey('branches'),
              ),
              _drawerItem(
                icon: Icons.biotech,
                title: tr('menuLab'),
                subtitle: 'Seguridad, cuestionario y simulador',
                onTap: () => _openScreenKey('lab'),
              ),
              _drawerItem(
                icon: Icons.swap_horizontal_circle,
                title: tr('menuVersion'),
                subtitle: ProgressService.track == ProgressService.trackBach
                    ? tr('trackBach')
                    : tr('trackUni'),
                onTap: () => _openScreenKey('version'),
              ),
              _drawerItem(
                icon: Icons.language,
                title: tr('languageWord'),
                subtitle: AppLang.supported
                    .firstWhere((e) => e.$1 == AppLang.code,
                        orElse: () => AppLang.supported.first)
                    .$2,
                onTap: () => _openScreenKey('language'),
              ),
              const Divider(),
              _drawerItem(
                icon: Icons.bar_chart,
                title: tr('menuStats'),
                subtitle: 'Racha, logros y progreso',
                onTap: () => _openScreenKey('stats'),
              ),
              _drawerItem(
                icon: Icons.replay_circle_filled,
                title: tr('reviewTitle'),
                subtitle: '${ProgressService.instance.failedCount} por repasar',
                onTap: () => _openScreenKey('review'),
              ),
              _drawerItem(
                icon: Icons.table_chart,
                title: tr('menuTables'),
                subtitle: 'Actividad de metales y solubilidad',
                onTap: () => _openScreenKey('tables'),
              ),
              _drawerItem(
                icon: Icons.functions,
                title: tr('menuFormulas'),
                subtitle: 'Todas las fórmulas juntas',
                onTap: () => _openScreenKey('formulas'),
              ),
              _drawerItem(
                icon: Icons.swap_horiz,
                title: tr('menuConstants'),
                subtitle: 'Constantes y conversor de unidades',
                onTap: () => _openScreenKey('constants'),
              ),
              _drawerItem(
                icon: Icons.star,
                title: tr('menuFavorites'),
                subtitle: 'Elementos, temas y fórmulas',
                onTap: () => _openScreenKey('favorites'),
              ),
              _drawerItem(
                icon: Icons.alarm,
                title: tr('menuReminder'),
                subtitle: UserPrefs.reminderOn ? 'Activado' : 'Desactivado',
                onTap: () => _openScreenKey('reminder'),
              ),
              _drawerItem(
                icon: Icons.share,
                title: tr('menuShare'),
                onTap: () => _showShareApp(context),
              ),
              const Divider(),
              _drawerItem(
                icon: Icons.info_outline,
                title: tr('aboutWord'),
                onTap: () => _showAbout(context),
              ),
            ],
          ),
        ),
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: tr('menuWord'),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Row(
            children: [
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                child: Image(
                  image: AssetImage('assets/logo.png'),
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
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
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: tr('searchWord'),
              onPressed: _openSearch,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: tr('aboutTitle'),
              onPressed: () => _showAbout(context),
              icon: const Icon(Icons.info_outline),
            ),
            IconButton(
              tooltip: widget.isDark ? tr('lightWord') : tr('darkWord'),
              onPressed: widget.onToggleTheme,
              icon: _ThemeToggleIcon(isDark: widget.isDark),
            ),
          ],
          centerTitle: false,
        ),
        body: SafeArea(child: _pages[_index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          indicatorColor: const Color(0xFF14B8A6).withValues(alpha: 0.25),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.route_outlined),
              selectedIcon: const Icon(Icons.route),
              label: tr('tabLevels'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.calculate_outlined),
              selectedIcon: const Icon(Icons.calculate),
              label: tr('tabResolver'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book),
              label: tr('tabLearn'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.grid_view_outlined),
              selectedIcon: const Icon(Icons.grid_view),
              label: tr('tabTable'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.lightbulb_outlined),
              selectedIcon: const Icon(Icons.lightbulb),
              label: tr('tabTips'),
            ),
          ],
        ),
      ),
    );
  }
}
