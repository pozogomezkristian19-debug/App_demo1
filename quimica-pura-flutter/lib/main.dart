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
import 'screens/theme_screen.dart';
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
import 'services/update_check.dart';
import 'services/user_prefs.dart';
import 'services/accent.dart';
import 'widgets/brand_logo.dart';
import 'widgets/element_sheet.dart';
import 'widgets/lives_chip.dart';

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
    this.edgeColor = BrandColors.tealDark,
  });

  /// Color del borde inferior (efecto 3D): teal oscuro en el tema
  /// verde, violeta intenso en el tema violeta (fix2, item 12).
  final Color edgeColor;

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final rrect = borderRadius.resolve(textDirection).toRRect(rect);
    canvas.save();
    canvas.clipPath(Path()..addRRect(rrect));
    canvas.drawRect(
      Rect.fromLTRB(rect.left, rect.bottom - 4, rect.right, rect.bottom),
      Paint()..color = edgeColor,
    );
    canvas.restore();
  }

  @override
  ShapeBorder scale(double t) => _DuoPillBorder(
        borderRadius: borderRadius * t,
        edgeColor: edgeColor,
      );
}

class MelliQuiApp extends StatefulWidget {
  const MelliQuiApp({super.key});
  @override
  State<MelliQuiApp> createState() => _MelliQuiAppState();
}

class _MelliQuiAppState extends State<MelliQuiApp>
    with WidgetsBindingObserver {
  bool _isDark = UserPrefs.isDark;
  bool _onboardingDone = UserPrefs.onboardingDone;

  @override
  void initState() {
    super.initState();
    // El modo de tema vive SOLO en Cuenta (fix3, punto 13): cuando
    // cambia, este aviso reconstruye el tema en el acto, igual que
    // hacía el icono de sol/luna de la AppBar. Sin este listener, el
    // cambio en Cuenta no se vería hasta reiniciar la app.
    WidgetsBinding.instance.addObserver(this);
    UserPrefs.themeModeNotifier.addListener(_onThemeModeChanged);
  }

  @override
  void dispose() {
    UserPrefs.themeModeNotifier.removeListener(_onThemeModeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Cambió el modo de tema en Cuenta: el tema efectivo cambia y la
  /// app entera se reconstruye con el modo nuevo.
  void _onThemeModeChanged() {
    setState(() => _isDark = UserPrefs.effectiveDark);
  }

  /// Con el modo 'sistema', el teléfono cambió de claro a oscuro (o
  /// al revés) sin tocar a Cuenta: el tema efectivo cambia igual.
  @override
  void didChangePlatformBrightness() {
    if (UserPrefs.themeMode == 'sistema') {
      setState(() => _isDark = UserPrefs.effectiveDark);
    }
  }

  /// ThemeMode real: 'sistema' sigue al teléfono; 'oscuro' y 'claro'
  /// son fijos.
  ThemeMode get _themeMode => switch (UserPrefs.themeMode) {
        'oscuro' => ThemeMode.dark,
        'sistema' => ThemeMode.system,
        _ => ThemeMode.light,
      };

  /// Cada vez que cambia la versión (Bachillerato/Universidad), este
  /// contador cambia y toda la pantalla principal se reconstruye desde
  /// cero con la versión nueva, como si cambiara la app entera.
  int _reloadToken = 0;

  // Nueva identidad visual (rediseño claro estilo Duolingo, con el
  // color propio de Melli-Qui: teal #00C2A8, nunca verde Duolingo).
  // Los colores de marca viven en BrandColors.
  // Modo oscuro VERDE, como al principio (fix2, item 8): fondo
  // verde muy oscuro y acentos SOLO de la familia verde (teal/
  // menta). Nada de violeta ni azul en el tema oscuro.
  static const _deepGreen = Color(0xFF0A1F1A);
  static const _surfaceGreen = Color(0xFF122B24);

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
      scaffoldBackgroundColor: _deepGreen,
      colorScheme: const ColorScheme.dark(
        primary: BrandColors.mintLight,
        onPrimary: _deepGreen,
        secondary: BrandColors.mint,
        surface: _surfaceGreen,
        onSurface: Color(0xFFE6F4EE),
        surfaceContainerHighest: Color(0xFF1B3A31),
        error: Color(0xFFEF4444),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _deepGreen,
        foregroundColor: Color(0xFFE6F4EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFFE6F4EE),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _deepGreen,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.30),
        indicatorColor: BrandColors.teal.withValues(alpha: 0.25),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? BrandColors.mintLight
                : const Color(0xFF8A9A93),
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
                ? BrandColors.mintLight
                : const Color(0xFF8A9A93),
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: _surfaceGreen,
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 6),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: _surfaceGreen,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFFE6F4EE),
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          height: 1.45,
          color: Color(0xFFE6F4EE),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.teal,
          foregroundColor: Colors.white,
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
          foregroundColor: BrandColors.mintLight,
          backgroundColor: _surfaceGreen,
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
          foregroundColor: BrandColors.mintLight,
          textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F241E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFFE6F4EE),
        contentTextStyle: TextStyle(
            fontFamily: 'Roboto', color: _deepGreen, fontSize: 15),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BrandColors.mintLight,
        linearTrackColor: Color(0xFF1B3A31),
      ),
      textTheme: const TextTheme(
        bodyMedium:
            TextStyle(fontSize: 16, height: 1.45, color: Color(0xFFE6F4EE)),
        bodyLarge:
            TextStyle(fontSize: 17, height: 1.45, color: Color(0xFFE6F4EE)),
        titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE6F4EE)),
        titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE6F4EE)),
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
      // Acento elegido en Ajustes (fix2, item 12): Verde (teal) o
      // Violeta. El color principal del tema claro, los botones y el
      // indicador de la barra inferior siguen al acento.
      colorScheme: ColorScheme.light(
        primary: AppAccent.primary,
        onPrimary: Colors.white,
        secondary:
            AppAccent.isViolet ? BrandColors.teal : BrandColors.violet,
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
        indicatorColor: AppAccent.primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppAccent.primary
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
                ? AppAccent.primary
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
          backgroundColor: AppAccent.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppAccent.primary.withValues(alpha: 0.40),
          elevation: 2,
          shadowColor: AppAccent.primaryDark,
          surfaceTintColor: Colors.transparent,
          shape: _DuoPillBorder(edgeColor: AppAccent.primaryDark),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppAccent.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppAccent.primary.withValues(alpha: 0.40),
          elevation: 2,
          shadowColor: AppAccent.primaryDark,
          surfaceTintColor: Colors.transparent,
          shape: _DuoPillBorder(edgeColor: AppAccent.primaryDark),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppAccent.primary,
          backgroundColor: Colors.white,
          side: BorderSide(color: AppAccent.primary, width: 2),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppAccent.primary,
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
            color: AppAccent.primary.withValues(alpha: 0.40),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppAccent.primary.withValues(alpha: 0.40),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: AppAccent.primary, width: 2),
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
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppAccent.primary,
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
    // la app con los textos nuevos, sin reiniciar. Igual con el acento
    // (Verde/Violeta, fix2 item 12): themeAccentNotifier avisa y el
    // tema claro cambia de color principal en el acto.
    return ValueListenableBuilder<String>(
      valueListenable: UserPrefs.themeAccentNotifier,
      builder: (context, accent, _) => ValueListenableBuilder<String>(
      valueListenable: AppLang.notifier,
      builder: (context, lang, _) => MaterialApp(
        title: 'Quemia',
        debugShowCheckedModeBanner: false,
        theme: _lightTheme(),
        darkTheme: _darkTheme(),
        themeMode: _themeMode,
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
    ),
    );
  }
}

/// Chip de repaso en la AppBar (fix2, item 2): icono de repaso +
/// cantidad de errores por repasar, con el color del tema.
/// Icono ARRIBA del texto no: en la barra va en línea, como el chip
/// de vidas, para que quepa junto a la campana.
class _ReviewChip extends StatelessWidget {
  const _ReviewChip({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LucideIcon(LucideIcons.rotateCcw,
                  size: 17, color: scheme.primary),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
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

  /// ¿Hay una sesión de juego en curso (quiz de nivel, repaso o
  /// examen mixto en línea)? Mientras la hay, la barra de arriba,
  /// el menú y la barra inferior se OCULTAN: la única salida es el
  /// botón Salir del quiz (fix2, ronda 2). Lo avisa PracticarScreen.
  bool _inSession = false;

  @override
  void initState() {
    super.initState();
    // Tocar una notificación (o su acción "Repasar ahora") pide el
    // repaso de errores aunque la app ya estuviera abierta (fix3,
    // punto 9): sin este aviso, Niveles ya montada no volvería a
    // mirar el flag.
    NavRequests.reviewRequested.addListener(_onNotificationReviewRequest);
    // Recordatorio de actualización e instalación del APK (fix3,
    // punto 20): tocar esas notificaciones con la app ya abierta
    // pide el diálogo o la instalación, igual que el repaso.
    NavRequests.updateRequested.addListener(_onNotificationUpdateRequest);
    NavRequests.installRequested
        .addListener(_onNotificationInstallRequest);
    // Tras el primer frame: primero el elemento del día (si toca),
    // luego el diálogo de actualización si la app se abrió desde su
    // recordatorio, y si no, la comprobación normal vía GitHub
    // (fix3, punto 20). En ese orden para que los diálogos no se
    // pisen: el de actualización espera a que se cierre el del
    // elemento.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeShowElementOfDay();
      if (!mounted) return;
      if (NavRequests.showUpdateDialog) {
        NavRequests.showUpdateDialog = false;
        await UpdateCheckService.showPendingUpdateDialog(context);
        return;
      }
      await UpdateCheckService.checkForUpdate(context);
    });
  }

  @override
  void dispose() {
    NavRequests.reviewRequested
        .removeListener(_onNotificationReviewRequest);
    NavRequests.updateRequested
        .removeListener(_onNotificationUpdateRequest);
    NavRequests.installRequested
        .removeListener(_onNotificationInstallRequest);
    super.dispose();
  }

  /// Repaso pedido por una notificación: ir a Niveles y arrancar el
  /// repaso de errores. Si hay una sesión en curso, la petición queda
  /// guardada (NavRequests.startReview) y Niveles la consume al
  /// terminar la sesión.
  void _onNotificationReviewRequest() {
    if (_inSession) return;
    if (!mounted) return;
    _goToTab(0, startReview: true);
  }

  /// Recordatorio de actualización tocado (fix3, punto 20): la app
  /// se abre y sale el diálogo de actualización (con los datos
  /// guardados al programar el recordatorio, incluso sin internet).
  void _onNotificationUpdateRequest() {
    if (!mounted) return;
    NavRequests.showUpdateDialog = false;
    UpdateCheckService.showPendingUpdateDialog(context);
  }

  /// "Descarga completa" o su acción "Instalar" (fix3, punto 20):
  /// instala el APK ya descargado (o avisa si falta el permiso de
  /// "Instalar apps desconocidas").
  void _onNotificationInstallRequest() {
    if (!mounted) return;
    UpdateCheckService.installDownloadedApk(context);
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
            // Fix3, punto 9: los botones iban en `actions` y el
            // OverflowBar del diálogo los apilaba al no caber lado a
            // lado — "Cerrar" quedaba como enlace de texto encima
            // de la pastilla grande "Ver ficha completa". Ahora van
            // en una fila limpia dentro del contenido: secundario
            // con borde a la izquierda y primario teal relleno a la
            // derecha, mismo ancho y mismo alto (stretch), sin que
            // uno quede encima del otro.
            const SizedBox(height: 20),
            // IntrinsicHeight: la fila usa stretch para igualar el
            // alto de los dos botones, y sin altura acotada el
            // stretch pide altura infinita y rompe el diálogo
            // (mismo patrón que el menú de Laboratorio).
            IntrinsicHeight(
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    child: Text(
                      tr('closeWord'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      showElementSheet(context, element);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    child: Text(
                      tr('elementDaySeeMore'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              ),
            ),
          ],
        ),
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
            onOpenScreen: _openScreenKey,
            onSessionChanged: (inSession) {
              if (_inSession != inSession) {
                setState(() => _inSession = inSession);
              }
            }),
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

  /// Repaso desde la barra de arriba (fix2, item 2): si hay errores,
  /// va a Niveles y arranca el repaso; si no hay, avisa.
  void _startReviewFromAppBar() {
    if (ProgressService.instance.failedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('quizNoErrors'))),
      );
      return;
    }
    _goToTab(0, startReview: true);
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
      case 'theme':
        page = const ThemeScreen();
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
                'Pásale Quemia a otros estudiantes de química:'),
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
                  'https://wa.me/?text=${Uri.encodeComponent('Descarga Quemia, la app de química pura: $kLandingUrl')}');
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
                      const Text('Quemia',
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
      // Icono 3D (fix3, punto 6) con el acento de la app: relleno
      // con degradado + brillito, como el corazón de las vidas.
      // La flecha de la derecha sigue plana (es solo una pista).
      leading: LucideIcon(icon,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
          threeD: true),
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
    // Color de la pestaña seleccionada (fix2, items 8 y 12): en modo
    // oscuro, verde para las 5; en claro, el color propio de cada
    // pestaña con el acento verde, o violeta para todas con el
    // acento violeta.
    final tabColors = List<Color>.generate(
      5,
      (i) => widget.isDark ? BrandColors.mintLight : AppAccent.tabColor(i),
    );
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
        // Sin botón flotante de Soporte (fix2, ronda 2): el pill
        // verde tapaba contenido en Niveles y en Tabla. Soporte
        // vive ahora al pie del menú hamburguesa.
        // Menú hamburguesa: el organizador de la app. Cada fila abre su
        // propia pantalla; nada suelto ni repetido dentro del menú.
        // La barra de búsqueda va PRIMERA y FIJA (fix2, item 11): no
        // se desplaza con el resto del menú. Tocar abre la búsqueda.
        drawer: _inSession ? null : Drawer(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    readOnly: true,
                    showCursor: false,
                    onTap: () {
                      Navigator.of(context).pop();
                      _openSearch();
                    },
                    decoration: InputDecoration(
                      hintText: tr('searchWord'),
                      prefixIcon:
                          const LucideIcon(LucideIcons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
              // Cabecera del menú: altura LIBRE (fix2, auditoría).
              // El DrawerHeader de Flutter tiene altura fija (160) y
              // el subtítulo, si se parte en 2 líneas, lo desbordaba
              // 11 px: con fuente grande o en otro idioma se cortaba
              // el texto. Este Container crece con su contenido.
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  border: Border(
                    bottom: Divider.createBorderSide(context),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fix3, punto 6: logo panorámico recortado a las
                    // gemelas (ancho 60, alto ~24), no el cuadrado
                    // marrón de 56 que dominaba la cabecera.
                    const BrandLogo(size: 60),
                    const SizedBox(height: 10),
                    const Text('Quemia',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(tr('appSubtitle')),
                  ],
                ),
              ),
              _drawerItem(
                icon: LucideIcons.network,
                title: tr('menuBranches'),
                subtitle: 'Orgánica, Inorgánica, Analítica, Química física',
                onTap: () => _openScreenKey('branches'),
              ),
              _drawerItem(
                icon: LucideIcons.dna,
                title: tr('menuLab'),
                subtitle: 'Seguridad, cuestionario y simulador',
                onTap: () => _openScreenKey('lab'),
              ),
              // Fix3 (segunda pasada): el simulador NO va como
              // entrada aparte en el menú — ya estaba duplicado:
              // "Laboratorio" dice "Seguridad, cuestionario y
              // simulador" y el simulador es la PRIMERA tarjeta de
              // la pantalla Laboratorio. La vía de acceso sigue
              // siendo esa tarjeta (y la búsqueda y Resolver, que
              // usan la ruta 'labSim', que se conserva).
              _drawerSection(tr('drawerPractice')),
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
                    ],
                  ),
                ),
                // Soporte al PIE del menú (fix2, ronda 2): el botón
                // flotante verde tapaba contenido en Niveles y en
                // Tabla, así que vive aquí, fijo abajo, con el logo
                // de WhatsApp. Abre lo mismo de siempre (wa.me con
                // lanzamiento en dos pasos).
                const Divider(height: 1),
                ListTile(
                  // El logo de WhatsApp es el glifo BLANCO (estaba
                  // pensado para el pill verde): sobre el fondo
                  // blanco del drawer era invisible. Va dentro de su
                  // círculo verde #25D366, visible en claro y oscuro.
                  leading: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                    child: const Image(
                      image: AssetImage('assets/whatsapp.png'),
                      width: 20,
                      height: 20,
                    ),
                  ),
                  title: Text(tr('supportWord'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(tr('writeWhatsApp')),
                  trailing:
                      const LucideIcon(LucideIcons.chevronRight, size: 18),
                  onTap: () {
                    SoundService.tap();
                    Navigator.of(context).pop();
                    _openWhatsApp(context);
                  },
                ),
              ],
            ),
          ),
        ),
        appBar: _inSession ? null : AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const LucideIcon(LucideIcons.menu),
              tooltip: tr('menuWord'),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          // Sin título de texto en la barra (fix3, punto 6,
          // ampliación): el nombre de la pantalla ("Niveles",
          // "Tabla"...) se recortaba ("Ni...") y ya está como
          // título grande dentro del contenido de cada pestaña.
          // La barra queda solo con sus controles: menú, vidas,
          // repaso y campana.
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
            // Repasar mis errores (fix2, item 2): entrada visible en
            // la barra de arriba, estilo Duolingo, junto a la campana
            // de notificaciones. El numerito es la cantidad de errores
            // por repasar; sin errores, avisa y no abre nada.
            // El avatar del usuario ya NO está aquí (fix2, item 6).
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: ValueListenableBuilder<int>(
                  valueListenable: ProgressService.failedNotifier,
                  builder: (context, _, __) => _ReviewChip(
                    count: ProgressService.instance.failedCount,
                    onTap: _startReviewFromAppBar,
                  ),
                ),
              ),
            ),
            // Campana de notificaciones (fix2, item 2): abre los
            // recordatorios (avisos del sistema).
            IconButton(
              tooltip: tr('notifTitle'),
              onPressed: () => _openScreenKey('reminder'),
              icon: const LucideIcon(LucideIcons.bell),
            ),
          ],
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
        bottomNavigationBar: _inSession ? null : NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            SoundService.tap();
            setState(() => _index = i);
          },
          // Barra blanca; la pestaña seleccionada lleva su color
          // (fix2, items 8 y 12): verde en modo oscuro, el color
          // propio de cada pestaña con el acento verde, o violeta
          // para todas con el acento violeta; gris si no está.
          indicatorColor: (widget.isDark
                  ? BrandColors.mintLight
                  : AppAccent.primary)
              .withValues(alpha: 0.15),
          destinations: [
            NavigationDestination(
              icon: const LucideIcon(LucideIcons.route,
                  color: Color(0xFF9CA3AF)),
              selectedIcon: LucideIcon(LucideIcons.route,
                  color: tabColors[0], threeD: true),
              label: tr('tabLevels'),
            ),
            NavigationDestination(
              icon: const LucideIcon(LucideIcons.calculator,
                  color: Color(0xFF9CA3AF)),
              selectedIcon: LucideIcon(LucideIcons.calculator,
                  color: tabColors[1], threeD: true),
              label: tr('tabResolver'),
            ),
            NavigationDestination(
              icon: const LucideIcon(LucideIcons.bookOpen,
                  color: Color(0xFF9CA3AF)),
              selectedIcon: LucideIcon(LucideIcons.bookOpen,
                  color: tabColors[2], threeD: true),
              label: tr('tabLearn'),
            ),
            NavigationDestination(
              icon: const LucideIcon(LucideIcons.layoutGrid,
                  color: Color(0xFF9CA3AF)),
              selectedIcon: LucideIcon(LucideIcons.layoutGrid,
                  color: tabColors[3], threeD: true),
              label: tr('tabTable'),
            ),
            NavigationDestination(
              icon: const LucideIcon(LucideIcons.userRound,
                  color: Color(0xFF9CA3AF)),
              selectedIcon: LucideIcon(LucideIcons.userRound,
                  color: tabColors[4], threeD: true),
              label: tr('accountTitle'),
            ),
          ],
        ),
      ),
    );
  }
}
