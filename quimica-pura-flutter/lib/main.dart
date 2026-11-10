import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data/extra_content.dart';
import 'data/periodic_table.dart';
import 'data/search_index.dart';
import 'screens/account_screen.dart';
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
import 'data/i18n/content_i18n.dart';
import 'services/favorites.dart';
import 'services/home_widget_service.dart';
import 'services/localization.dart';
import 'services/notification_service.dart';
import 'services/nav_requests.dart';
import 'services/notes.dart';
import 'services/progress.dart';
import 'services/sound_service.dart';
import 'services/user_prefs.dart';
import 'widgets/avatar.dart';
import 'widgets/brand_logo.dart';
import 'widgets/element_sheet.dart';
import 'widgets/lives_chip.dart';
import 'widgets/support_button.dart';

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
  syncGeneratorLang();
  await NotificationService.init();
  // Primera carga de datos del widget de inicio (pregunta del día,
  // racha, vidas y puntos). Si no hay widget, no pasa nada.
  await HomeWidgetService.update();
  runApp(const MelliQuiApp());
}

/// Transición suave para TODAS las pantallas (v6): fundido + pequeño
/// deslizamiento, en vez del deslizamiento brusco por defecto. Se
/// aplica en el tema, así no hay que tocar cada Navigator.push.
class _FadeSlideTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlideTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOut),
    );
    final slide =
        Tween<Offset>(begin: const Offset(0.04, 0.03), end: Offset.zero)
            .animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

/// Borde de botón estilo Duolingo: píldora con un borde inferior de
/// 4 px en teal oscuro, que hace el efecto 3D (el botón parece
/// levantado). Material pinta el ShapeBorder del botón, así que el
/// borde inferior se dibuja de verdad, no es solo una sombra.
class _DuoPillBorder extends RoundedRectangleBorder {
  const _DuoPillBorder({
    super.borderRadius =
        const BorderRadius.all(Radius.circular(999)),
  });

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final rrect = borderRadius.resolve(textDirection).toRRect(rect);
    canvas.save();
    canvas.clipPath(Path()..addRRect(rrect));
    canvas.drawRect(
      Rect.fromLTRB(rect.left, rect.bottom - 4, rect.right, rect.bottom),
      Paint()..color = BrandColors.tealDark,
    );
    canvas.restore();
  }

  @override
  ShapeBorder scale(double t) => _DuoPillBorder(
        borderRadius: borderRadius * t,
      );
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

  // Nueva identidad visual (rediseño claro estilo Duolingo, con el
  // color propio de Melli-Qui: teal #00C2A8, nunca verde Duolingo).
  // Los colores de marca viven en BrandColors.
  static const _deep = Color(0xFF171226);

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeSlideTransitionsBuilder(),
          TargetPlatform.iOS: _FadeSlideTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: _deep,
      colorScheme: const ColorScheme.dark(
        primary: BrandColors.violetLight,
        secondary: BrandColors.mintLight,
        surface: Color(0xFF241B3A),
        onSurface: Color(0xFFF1EAFB),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF241B3A),
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1B1530),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 16, height: 1.45),
        bodyLarge: TextStyle(fontSize: 17, height: 1.45),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ).apply(fontFamily: 'Roboto'),
    );
  }

  /// Tema claro estilo Duolingo con el color propio de Melli-Qui
  /// (teal #00C2A8, NUNCA verde Duolingo): fondo blanco, texto
  /// oscuro, tarjetas blancas muy redondeadas con sombra suave,
  /// tipografía gruesa y amistosa, y botones píldora teal con borde
  /// inferior oscuro (efecto 3D, ver _DuoPillBorder).
  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeSlideTransitionsBuilder(),
          TargetPlatform.iOS: _FadeSlideTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: BrandColors.teal,
        onPrimary: Colors.white,
        secondary: BrandColors.violet,
        surface: Colors.white,
        onSurface: BrandColors.ink,
        surfaceContainerHighest: BrandColors.cardGray,
        error: Color(0xFFEF4444),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: BrandColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: BrandColors.ink,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        indicatorColor: BrandColors.teal.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? BrandColors.teal
                : const Color(0xFF9CA3AF),
            size: 26,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? BrandColors.teal
                : const Color(0xFF9CA3AF),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.10),
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: BrandColors.ink,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          height: 1.45,
          color: BrandColors.ink,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              BrandColors.teal.withValues(alpha: 0.40),
          elevation: 2,
          shadowColor: BrandColors.tealDark,
          surfaceTintColor: Colors.transparent,
          shape: const _DuoPillBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              BrandColors.teal.withValues(alpha: 0.40),
          elevation: 2,
          shadowColor: BrandColors.tealDark,
          surfaceTintColor: Colors.transparent,
          shape: const _DuoPillBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.teal,
          backgroundColor: Colors.white,
          side: const BorderSide(color: BrandColors.teal, width: 2),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BrandColors.teal,
          textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: BrandColors.teal.withValues(alpha: 0.40),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: BrandColors.teal.withValues(alpha: 0.40),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: BrandColors.teal, width: 2),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: BrandColors.ink,
        contentTextStyle: TextStyle(
            fontFamily: 'Roboto', color: Colors.white, fontSize: 15),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BrandColors.teal,
        linearTrackColor: BrandColors.cardGray,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
            fontSize: 16, height: 1.45, color: BrandColors.ink),
        bodyLarge: TextStyle(
            fontSize: 17, height: 1.45, color: BrandColors.ink),
        titleMedium: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: BrandColors.ink),
        titleLarge: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: BrandColors.ink),
        headlineSmall: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800, color: BrandColors.ink),
      ).apply(fontFamily: 'Roboto'),
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
      return const LucideIcon(LucideIcons.sun, size: 24);
    }
    // Modo oscuro: lunita con nubes.
    return const Stack(
      clipBehavior: Clip.none,
      children: [
        LucideIcon(LucideIcons.moon, size: 24),
        Positioned(
          right: -3,
          bottom: -2,
          child: LucideIcon(LucideIcons.cloud, size: 14),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowElementOfDay());
  }

  /// Elemento del día como POPUP al abrir la app (v6, item 2): nombre,
  /// símbolo y curiosidad. Al cerrarlo no vuelve a salir hoy.
  Future<void> _maybeShowElementOfDay() async {
    final p = ProgressService.instance;
    if (p.elementDayShownToday) return;
    final element = elementOfTheDay(DateTime.now());
    p.markElementDayShown();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('elementDayTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary,
                  child: Text(
                    element.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    localizedElementName(element),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(localizedElementFact(element)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('closeWord')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              showElementSheet(context, element);
            },
            child: Text(tr('elementDaySeeMore')),
          ),
        ],
      ),
    );
  }

  // La primera pantalla es el camino de niveles (Niveles), como en
  // Duolingo; Resolver queda como una opción más. Niveles lleva la
  // pista como clave: al cambiar de versión se crea de nuevo.
  // La quinta pestaña es Cuenta (v6): Tips se mudó a Aprender.
  List<Widget> get _pages => [
        PracticarScreen(
            key: ValueKey(ProgressService.track),
            onOpenScreen: _openScreenKey),
        const ResolverScreen(),
        const AprenderScreen(),
        const TablaScreen(),
        AccountScreen(
          onOpenScreen: _openScreenKey,
          onShowAbout: () => _showAbout(context),
          onShowShareApp: () => _showShareApp(context),
          trackTopics: _trackTopics,
        ),
      ];

  /// Títulos de las 5 secciones, en el idioma actual.
  List<String> get _titles => [
        tr('tabLevels'),
        tr('tabResolver'),
        tr('tabLearn'),
        tr('tableTitle'),
        tr('accountTitle'),
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
      case 'tips':
        page = const TipsScreen();
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
                const BrandLogo(size: 48),
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
                icon: const LucideIcon(LucideIcons.copy),
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
    required LucideIconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: LucideIcon(icon, size: 24),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const LucideIcon(LucideIcons.chevronRight, size: 18),
      onTap: () {
        SoundService.tap();
        Navigator.of(context).pop();
        onTap();
      },
    );
  }

  /// Título pequeño de una sección del menú (Practicar, Referencia...).
  Widget _drawerSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
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
        // lleva directo al chat del creador. Es un botón a mano
        // (widgets/support_button.dart), SIN FloatingActionButton: el
        // FAB dibujaba un borde negro grueso alrededor de la píldora
        // verde, y este botón no tiene borde de ningún tipo.
        floatingActionButton:
            SupportButton(onPressed: () => _openWhatsApp(context)),
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
                    const BrandLogo(size: 56),
                    const SizedBox(height: 10),
                    const Text('Melli-Qui',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(tr('appSubtitle')),
                  ],
                ),
              ),
              _drawerItem(
                icon: LucideIcons.network,
                title: tr('menuBranches'),
                subtitle: 'Orgánica, Inorgánica, Analítica, Fisicoquímica',
                onTap: () => _openScreenKey('branches'),
              ),
              _drawerItem(
                icon: LucideIcons.dna,
                title: tr('menuLab'),
                subtitle: 'Seguridad, cuestionario y simulador',
                onTap: () => _openScreenKey('lab'),
              ),
              _drawerSection(tr('drawerPractice')),
              _drawerItem(
                icon: LucideIcons.layers,
                title: tr('flashcardsTitle'),
                subtitle: tr('flashcardsSub'),
                onTap: () => _openScreenKey('flashcards'),
              ),
              _drawerItem(
                icon: LucideIcons.timer,
                title: tr('timedTitle'),
                subtitle: tr('timedSub'),
                onTap: () => _openScreenKey('timed'),
              ),
              _drawerItem(
                icon: LucideIcons.gamepad2,
                title: tr('challengeTitle'),
                subtitle: tr('challengeSub'),
                onTap: () => _openScreenKey('challenge'),
              ),
              _drawerItem(
                icon: LucideIcons.circleHelp,
                title: tr('tableQuizTitle'),
                subtitle: 'Adivina el elemento',
                onTap: () => _openScreenKey('tableQuiz'),
              ),
              _drawerSection(tr('drawerReference')),
              _drawerItem(
                icon: LucideIcons.table,
                title: tr('menuTables'),
                subtitle: 'Actividad de metales y solubilidad',
                onTap: () => _openScreenKey('tables'),
              ),
              _drawerItem(
                icon: LucideIcons.sigma,
                title: tr('menuFormulas'),
                subtitle: 'Todas las fórmulas juntas',
                onTap: () => _openScreenKey('formulas'),
              ),
              _drawerItem(
                icon: LucideIcons.arrowLeftRight,
                title: tr('menuConstants'),
                subtitle: 'Constantes y conversor de unidades',
                onTap: () => _openScreenKey('constants'),
              ),
              _drawerItem(
                icon: LucideIcons.bookOpen,
                title: tr('glossaryTitle'),
                subtitle: 'Términos de química explicados',
                onTap: () => _openScreenKey('glossary'),
              ),
              _drawerItem(
                icon: LucideIcons.arrowLeftRight,
                title: tr('compareTitle'),
                subtitle: 'Dos elementos, cara a cara',
                onTap: () => _openScreenKey('compare'),
              ),
              _drawerItem(
                icon: LucideIcons.notebookPen,
                title: tr('notesTitle'),
                subtitle: 'Tus notas por tema',
                onTap: () => _openScreenKey('notes'),
              ),
              _drawerItem(
                icon: LucideIcons.flaskConical,
                title: tr('labSimTitle'),
                subtitle: 'Mezcla ácidos, bases e indicadores',
                onTap: () => _openScreenKey('labSim'),
              ),
              _drawerSection(tr('searchWord')),
              _drawerItem(
                icon: LucideIcons.search,
                title: tr('searchWord'),
                subtitle: 'Temas, elementos, fórmulas y pantallas',
                onTap: _openSearch,
              ),
            ],
          ),
        ),
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const LucideIcon(LucideIcons.menu),
              tooltip: tr('menuWord'),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Row(
            children: [
              const BrandLogo(size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_titles[_index]),
                    if (UserPrefs.userName.isNotEmpty)
                      Text(
                        greeting,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
            // Chip de vidas junto al saludo (corazón + número, fix 1):
            // siempre visible en las 5 pestañas. Se actualiza solo
            // cuando cambian las vidas, sin reconstruir la pantalla.
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: ValueListenableBuilder<int>(
                  valueListenable: ProgressService.livesNotifier,
                  builder: (context, _, __) => LivesChip(
                    lives: ProgressService.instance.livesLeft,
                  ),
                ),
              ),
            ),
            // Tu avatar junto al saludo: toca para abrir tu Cuenta.
            if (UserPrefs.userName.isNotEmpty)
              IconButton(
                tooltip: tr('accountTitle'),
                onPressed: () => _goToTab(4),
                icon: MelliAvatar(
                  avatarId: UserPrefs.avatar.isNotEmpty &&
                          MelliAvatar.isValidId(UserPrefs.avatar)
                      ? UserPrefs.avatar
                      : MelliAvatar.defaultForGender(UserPrefs.userGender),
                  size: 30,
                ),
              ),
            IconButton(
              tooltip: tr('searchWord'),
              onPressed: _openSearch,
              icon: const LucideIcon(LucideIcons.search),
            ),
            IconButton(
              tooltip: widget.isDark ? tr('lightWord') : tr('darkWord'),
              onPressed: widget.onToggleTheme,
              icon: _ThemeToggleIcon(isDark: widget.isDark),
            ),
          ],
          centerTitle: false,
        ),
        body: SafeArea(
          // Cambio de pestaña con fundido + deslizamiento suave.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey('tab-$_index'),
              child: _pages[_index],
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            SoundService.tap();
            setState(() => _index = i);
          },
          // Barra blanca; cada pestaña tiene su color al estar
          // seleccionada (Niveles teal, Resolver violeta, Aprender
          // ámbar, Tabla azul, Cuenta coral) y gris si no lo está.
          indicatorColor: BrandColors.teal.withValues(alpha: 0.15),
          destinations: [
            NavigationDestination(
              icon: const LucideIcon(LucideIcons.route,
                  color: Color(0xFF9CA3AF)),
              selectedIcon:
                  const LucideIcon(LucideIcons.route, color: BrandColors.teal),
              label: tr('tabLevels'),
            ),
            NavigationDestination(
              icon: const LucideIcon(LucideIcons.calculator,
                  color: Color(0xFF9CA3AF)),
              selectedIcon:
                  const LucideIcon(LucideIcons.calculator, color: BrandColors.violet),
              label: tr('tabResolver'),
            ),
            NavigationDestination(
              icon: const LucideIcon(LucideIcons.bookOpen,
                  color: Color(0xFF9CA3AF)),
              selectedIcon:
                  const LucideIcon(LucideIcons.bookOpen, color: BrandColors.amber),
              label: tr('tabLearn'),
            ),
            NavigationDestination(
              icon: const LucideIcon(LucideIcons.layoutGrid,
                  color: Color(0xFF9CA3AF)),
              selectedIcon:
                  const LucideIcon(LucideIcons.layoutGrid, color: BrandColors.blue),
              label: tr('tabTable'),
            ),
            NavigationDestination(
              icon: const LucideIcon(LucideIcons.userRound,
                  color: Color(0xFF9CA3AF)),
              selectedIcon:
                  const LucideIcon(LucideIcons.userRound, color: BrandColors.coral),
              label: tr('accountTitle'),
            ),
          ],
        ),
      ),
    );
  }
}
