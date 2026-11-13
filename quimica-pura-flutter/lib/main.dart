import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:share_plus/share_plus.dart';
import 'widgets/lucide_icons.dart';
import 'data/periodic_table.dart';
import 'data/search_index.dart';
import 'screens/account_screen.dart';
import 'screens/aprender_screen.dart';
import 'screens/avatar_editor_screen.dart';
import 'screens/branches_screen.dart';
import 'screens/compare_screen.dart';
import 'screens/constants_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/formula_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/glossary_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/how_to_play_screen.dart';
import 'screens/lab_screen.dart';
import 'screens/lab_sim_screen.dart';
import 'screens/language_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/practicar_screen.dart';
import 'screens/reference_tables_screen.dart';
import 'screens/reminder_screen.dart';
import 'screens/resolver_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/support_screen.dart';
import 'screens/tabla_screen.dart';
import 'screens/table_quiz_screen.dart';
import 'screens/theme_screen.dart';
import 'screens/timed_exam_screen.dart';
import 'screens/tips_screen.dart';
import 'screens/topic_detail_screen.dart';
import 'screens/tournaments_screen.dart';
import 'screens/version_screen.dart';
import 'data/i18n/content_i18n.dart';
import 'services/favorites.dart';
import 'services/home_widget_service.dart';
import 'services/localization.dart';
import 'services/notification_inbox.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'services/nav_requests.dart';
import 'services/notes.dart';
import 'services/progress.dart';
import 'services/social_service.dart';
import 'services/sound_service.dart';
import 'services/update_check.dart';
import 'services/user_prefs.dart';
import 'services/accent.dart';
import 'services/analytics_sync.dart';
import 'services/announcements_service.dart';
import 'services/auth_service.dart';
import 'services/duels_service.dart';
import 'services/firestore_social_repository.dart';
import 'services/friends_groups_service.dart';
import 'services/remote_content_service.dart';
import 'services/reports_service.dart';
import 'services/shop_service.dart';
import 'services/support_service.dart';
import 'services/tournaments_service.dart';
import 'widgets/banned_screen.dart';
import 'widgets/brand_logo.dart';
import 'widgets/element_sheet.dart';
import 'widgets/lives_chip.dart';
import 'widgets/main_bottom_nav.dart';

/// URL de la página de descarga de Melli-Qui (landing en GitHub Pages).
const String kLandingUrl =
    'https://pozogomezkristian19-debug.github.io/App_demo1/';

/// Página pública de Quemia (Firebase Hosting, la misma de la bio
/// de Instagram): es lo que se comparte al tocar "Compartir" — la
/// invitación a la app con esta página, sin el APK.
const String kShareUrl = 'https://quemia-8410a.web.app';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase (ronda fix8, analítica): si falla, la app arranca igual
  // 100% offline; la analítica y el bloqueo remoto quedan apagados.
  try {
    await Firebase.initializeApp();
    AnalyticsSync.markFirebaseReady();
  } catch (_) {
    // Sin Firebase: todo sigue local, como antes.
  }
  // Sesión anónima automática (ronda fix8): el uid es la identidad
  // del documento de Firestore. Si falla (sin internet), la app
  // sigue 100% offline y la analítica usa el id temporal.
  await AuthService.ensureAnonymous();
  await AnalyticsSync.init();
  await UserPrefs.load();
  // Compras y cosméticos de la tienda (Quemia 7.0): se cargan
  // antes de arrancar para que el tema equipado tiña la app
  // desde el primer fotograma.
  await SocialService.init();
  // La pista guardada (Bachillerato o Universidad) se carga antes del
  // progreso, porque las claves de guardado dependen de la pista.
  ProgressService.track = UserPrefs.track;
  await ProgressService.load();
  // La bandeja de Notificaciones (fix4, punto 8): se carga antes
  // de init() del servicio de notificaciones, que reconcilia los
  // avisos que ya sonaron.
  await NotificationInbox.load();
  await NotesService.load();
  await FavoritesService.load();
  await AppLang.load();
  syncGeneratorLang();
  await NotificationService.init();
  // Push FCM (7.1, Task 5): token, listeners y drenaje del stash.
  // Sin esperar (unawaited): init() lleva timeouts y try/catch
  // internos, así que FCM nunca bloquea el arranque ni el inicio
  // de sesión; sin internet se salta en silencio.
  unawaited(PushService.init());
  // Primera carga de datos del widget de inicio (pregunta del día,
  // racha, vidas y puntos). Si no hay widget, no pasa nada.
  await HomeWidgetService.update();
  // Puerta de bloqueo (ronda fix8): si el creador baneó esta cuenta,
  // la app arranca en la pantalla de suspensión. La lectura lleva
  // timeout: sin internet no se queda esperando. Los ajustes remotos
  // y la primera subida corren en segundo plano y fallan en silencio.
  final banned = await AnalyticsSync.fetchBanned()
      .timeout(const Duration(seconds: 5), onTimeout: () => false);
  unawaited(AnalyticsSync.applyRemoteSettings());
  unawaited(AnalyticsSync.uploadProgress());
  // Respaldo con Google (backupToCloud es hoy un alias de
  // uploadProgress con force: con Google enlazado sube aunque no
  // haya permiso de compartir, en privado).
  unawaited(AnalyticsSync.backupToCloud());
  // Capa online 7.0: el repositorio Firestore detrás de las
  // pantallas sociales (amigos, duelos, torneos, tienda, grupos,
  // reportes). Sin Google o sin red, cada servicio devuelve vacío
  // y no hace nada (Regla 2). Los reintentos de lo que quedó
  // pendiente sin internet y el cobro de premios de torneos
  // terminados corren en segundo plano y fallan en silencio.
  SocialService.setRepositoryForTests(FirestoreSocialRepository());
  unawaited(RemoteContentService.refreshRemoteContent());
  unawaited(ReportsService.retryPendingReports());
  unawaited(DuelService.retryPendingDuels());
  unawaited(TournamentsService.retryPendingScores());
  unawaited(ShopService.retryPendingPurchases());
  unawaited(FriendsGroupsService.retryPendingFriendRequests());
  unawaited(TournamentsService.claimAllEndedPrizes());
  // Bandeja al abrir (Zona G2, capa sin push): lo que llegó online
  // mientras no había internet aparece en Notificaciones al abrir,
  // sin depender de que llegara el push FCM: solicitudes, duelos
  // (reto y resultado) y avisos del creador. Las respuestas de
  // soporte ya las vigila SupportService.listenForReplies() abajo.
  // Todo con try/catch interno y vacío sin internet: nunca bloquea
  // el arranque.
  unawaited(SocialService.syncFriendRequestInbox());
  unawaited(SocialService.syncDuelInbox());
  unawaited(AnnouncementsService.syncToInbox());
  // Soporte (7.0, Kristian 09:52): enviar lo que quedó encolado sin
  // internet y vigilar si el admin ya respondió a mis mensajes.
  // Con try/catch y sin bloquear el arranque.
  try {
    unawaited(SupportService.instance.retryPendingSupport());
    SupportService.instance.listenForReplies();
  } catch (_) {
    // Sin soporte online: la app sigue.
  }
  runApp(MelliQuiApp(banned: banned));
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
///
/// También sirve para los botones con contorno (OutlinedButton):
/// el `side` (contorno teal de 2 px) se pinta encima del borde
/// inferior, y `copyWith` conserva el tipo para que el marco no lo
/// pierda al fusionar el contorno (sin esto, el botón con contorno
/// volvía a ser una píldora plana).
class DuoPillBorder extends RoundedRectangleBorder {
  const DuoPillBorder({
    super.borderRadius = const BorderRadius.all(Radius.circular(999)),
    super.side = BorderSide.none,
    this.edgeColor = BrandColors.tealDark,
  });

  /// Color del borde inferior (efecto 3D): teal oscuro en el tema
  /// verde, violeta intenso en el tema violeta (fix2, item 12).
  final Color edgeColor;

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    // Primero el contorno (si lo hay), luego el borde inferior 3D.
    super.paint(canvas, rect, textDirection: textDirection);
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
  RoundedRectangleBorder copyWith(
          {BorderSide? side, BorderRadiusGeometry? borderRadius}) =>
      DuoPillBorder(
        borderRadius: borderRadius ?? this.borderRadius,
        side: side ?? this.side,
        edgeColor: edgeColor,
      );

  @override
  ShapeBorder scale(double t) => DuoPillBorder(
        borderRadius: borderRadius * t,
        side: side,
        edgeColor: edgeColor,
      );
}

class MelliQuiApp extends StatefulWidget {
  const MelliQuiApp({super.key, this.banned = false});

  /// La cuenta está baneada: arrancar en la pantalla de suspensión
  /// en vez de en la app normal (ronda fix8).
  final bool banned;

  @override
  State<MelliQuiApp> createState() => _MelliQuiAppState();
}

class _MelliQuiAppState extends State<MelliQuiApp> with WidgetsBindingObserver {
  bool _isDark = UserPrefs.isDark;
  bool _onboardingDone = UserPrefs.onboardingDone;

  /// Logo al abrir (Zona E2, Quemia 7.1): true solo en el arranque en
  /// frío. Mientras tanto la home es el SplashScreen (~1 s) y al
  /// agotarse pasa a la principal o al onboarding. Al volver de
  /// segundo plano no se vuelve a poner: es estado de arranque, no
  /// de cada resume (Android enseña la última pantalla entonces).
  bool _showSplash = true;

  /// ¿La cuenta está baneada ahora? Se re-chequea al volver a primer
  /// plano (ronda fix8): un baneo aplicado mientras la app estaba
  /// abierta se ve al volver, sin reiniciar.
  late bool _banned;

  @override
  void initState() {
    super.initState();
    _banned = widget.banned;
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

  /// Al volver a primer plano: re-chequear si la cuenta fue baneada
  /// (ronda fix8) y reintentar la subida que quedó pendiente sin
  /// internet (Regla 2). Con timeout, para no quedarse esperando sin
  /// internet; si falla, el estado queda como estaba.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_recheckBanned());
      unawaited(AnalyticsSync.retryPending());
      // Reintentos online 7.0 (Regla 2): lo que quedó encolado sin
      // internet se sincroniza al volver, en segundo plano.
      unawaited(RemoteContentService.refreshRemoteContent());
      unawaited(ReportsService.retryPendingReports());
      unawaited(DuelService.retryPendingDuels());
      unawaited(TournamentsService.retryPendingScores());
      unawaited(ShopService.retryPendingPurchases());
      unawaited(FriendsGroupsService.retryPendingFriendRequests());
      unawaited(TournamentsService.claimAllEndedPrizes());
      // Bandeja al volver (Zona G2, capa sin push): igual que al
      // abrir — lo online que llegó sin internet se sincroniza a
      // Notificaciones sin esperar al push.
      unawaited(SocialService.syncFriendRequestInbox());
      unawaited(SocialService.syncDuelInbox());
      unawaited(AnnouncementsService.syncToInbox());
      // Soporte (7.0): reenviar lo encolado y mirar si el admin
      // respondió mientras la app estaba en segundo plano.
      try {
        unawaited(SupportService.instance.retryPendingSupport());
        SupportService.instance.listenForReplies();
      } catch (_) {
        // Sin soporte online: la app sigue.
      }
    }
  }

  Future<void> _recheckBanned() async {
    final banned = await AnalyticsSync.fetchBanned()
        .timeout(const Duration(seconds: 5), onTimeout: () => _banned);
    if (mounted && banned != _banned) {
      setState(() => _banned = banned);
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
  // Modo oscuro (fix4, punto 2): sigue al acento elegido en Cuenta
  // — verde oscuro como al principio con Verde, violeta oscuro con
  // Violeta (fondo con tinte violeta y primario violeta claro).
  // Antes era verde fijo y el violeta no se veía nunca en oscuro.
  // Verde oscuro de siempre: fondo y superficie del modo oscuro
  // con el acento Verde.
  // Modo oscuro Duolingo (§2): lienzo #131F24, superficie #1F2C34.
  // La variante violeta (#17112A/#241B3D) se queda como está.
  static const _deepGreen = Color(0xFF131F24);
  static const _surfaceGreen = Color(0xFF1F2C34);
  ThemeData _darkTheme() {
    // Paleta oscura según el acento (fix4, punto 2): Verde usa el
    // verde oscuro de siempre; Violeta usa fondo con tinte violeta,
    // superficie violeta oscura y primario violeta claro (legible
    // sobre oscuro, como el menta lo es sobre el verde oscuro).
    final violet = AppAccent.isViolet;
    final bg = violet ? const Color(0xFF17112A) : _deepGreen;
    final surface = violet ? const Color(0xFF241B3D) : _surfaceGreen;
    final onSurface =
        violet ? const Color(0xFFEDE9F7) : const Color(0xFFE6F4EE);
    final primary = violet ? BrandColors.violetLight : BrandColors.mintLight;
    final secondary = violet ? BrandColors.violet : BrandColors.mint;
    final containerHighest =
        violet ? const Color(0xFF2E2350) : const Color(0xFF1B3A31);
    final buttonBg = violet ? BrandColors.violet : BrandColors.teal;
    final buttonShadow = violet ? BrandColors.violetDeep : BrandColors.tealDark;
    final inputFill =
        violet ? const Color(0xFF1C1533) : const Color(0xFF0F241E);
    final unselected =
        violet ? const Color(0xFF9B8FC4) : const Color(0xFF8A9A93);
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Nunito',
      brightness: Brightness.dark,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeSlideTransitionsBuilder(),
          TargetPlatform.iOS: _FadeSlideTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: bg,
        secondary: secondary,
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: containerHighest,
        // Rojo Cardinal de Duolingo (§2): #FF4B4B, no #EF4444.
        error: Color(0xFFFF4B4B),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        elevation: 0,
        // SIN resaltado detrás del tab activo (corrección de
        // Kristian 2026-11-12; antes el primario al 20 %).
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : unselected,
            size: 28,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected) ? primary : unselected,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF37464F), width: 2),
        ),
      ),
      // Las líneas divisorias NO son negras: divisor oscuro #37464F.
      dividerTheme: const DividerThemeData(
        color: Color(0xFF37464F),
        thickness: 1,
      ),
      // Barra de desplazamiento BONITA y siempre visible (Zona F):
      // thumb del color del acento en oscuro (menta con Verde,
      // violeta claro con Violeta), redondeado y fino.
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(primary),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(8),
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(false),
        crossAxisMargin: 2,
        minThumbLength: 48,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: onSurface,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 16,
          height: 1.45,
          color: onSurface,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBg,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: buttonShadow,
          surfaceTintColor: Colors.transparent,
          shape: const DuoPillBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonBg,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: buttonShadow,
          surfaceTintColor: Colors.transparent,
          shape: const DuoPillBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          backgroundColor: surface,
          side: BorderSide(color: buttonBg, width: 2),
          shape: DuoPillBorder(edgeColor: primary.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
              fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
              fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      // Interruptor teal (sistema Quemia): sin esto sale violeta,
      // el color por defecto de Material 3.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primary : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? primary.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        // Campo §1.6 también en oscuro: radio 16, borde 2 pt
        // #37464F (divisor oscuro); al enfocar, #84D8FF. Sin borde
        // negro por defecto y con altura mínima 56 pt.
        constraints: const BoxConstraints(minHeight: 56),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF37464F), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF37464F), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF84D8FF), width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurface,
        contentTextStyle:
            TextStyle(fontFamily: 'Nunito', color: bg, fontSize: 15),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: containerHighest,
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(fontSize: 16, height: 1.45, color: onSurface),
        bodyLarge: TextStyle(fontSize: 17, height: 1.45, color: onSurface),
        titleMedium: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: onSurface),
        titleLarge: TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, color: onSurface),
      ).apply(fontFamily: 'Nunito'),
    );
  }

  /// Tema claro estilo Duolingo con el color propio de Melli-Qui
  /// (teal #00C2A8, NUNCA verde Duolingo): fondo blanco, texto
  /// oscuro, tarjetas blancas muy redondeadas con sombra suave,
  /// tipografía gruesa y amistosa, y botones píldora teal con borde
  /// inferior oscuro (efecto 3D, ver DuoPillBorder).
  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Nunito',
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
        secondary: AppAccent.isViolet ? BrandColors.teal : BrandColors.violet,
        surface: Colors.white,
        onSurface: BrandColors.ink,
        surfaceContainerHighest: BrandColors.cardGray,
        // Rojo Cardinal de Duolingo (§2): #FF4B4B, no #EF4444.
        error: Color(0xFFFF4B4B),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: BrandColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: BrandColors.ink,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        // SIN resaltado detrás del tab activo: el tab activo se
        // distingue SOLO por el color del icono y de la etiqueta
        // (corrección de Kristian 2026-11-12; antes #CCFBF1).
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppAccent.primary
                : const Color(0xFFAFAFAF),
            size: 28,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? AppAccent.primary
                : const Color(0xFFAFAFAF),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
        ),
      ),
      // Las líneas divisorias NO son negras: gris muy claro.
      // (El Divider por defecto usa colorScheme.outline, que en los
      // previews salía negro puro: esa era una de las "líneas negras".)
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E5E5),
        thickness: 1,
      ),
      // Barra de desplazamiento BONITA y siempre visible (Zona F,
      // corrección 2026-11-12): thumb del color del acento,
      // redondeado y fino, en todas las pantallas con scroll.
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppAccent.primary),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(8),
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(false),
        crossAxisMargin: 2,
        minThumbLength: 48,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: BrandColors.ink,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 16,
          height: 1.45,
          color: BrandColors.ink,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppAccent.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppAccent.primary.withValues(alpha: 0.40),
          elevation: 2,
          shadowColor: AppAccent.primaryDark,
          surfaceTintColor: Colors.transparent,
          shape: DuoPillBorder(edgeColor: AppAccent.primaryDark),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppAccent.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppAccent.primary.withValues(alpha: 0.40),
          elevation: 2,
          shadowColor: AppAccent.primaryDark,
          surfaceTintColor: Colors.transparent,
          shape: DuoPillBorder(edgeColor: AppAccent.primaryDark),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppAccent.primary,
          backgroundColor: Colors.white,
          side: BorderSide(color: AppAccent.primary, width: 2),
          shape: DuoPillBorder(
              edgeColor: AppAccent.primary.withValues(alpha: 0.30)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
              fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppAccent.primary,
          textStyle: const TextStyle(
              fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      // Interruptor teal (sistema Quemia): sin esto sale violeta,
      // el color por defecto de Material 3.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppAccent.primary
                : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppAccent.primary.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        // Campo §1.6 (rediseño Duolingo 7.0, Zona A): borde 2 pt
        // #E5E5E5 por defecto (no teal); al enfocar, #84D8FF;
        // altura mínima 56 pt. Sin sombra.
        constraints: const BoxConstraints(minHeight: 56),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE5E5E5),
            width: 2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE5E5E5),
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          borderSide: const BorderSide(color: Color(0xFF84D8FF), width: 2),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: BrandColors.ink,
        contentTextStyle:
            TextStyle(fontFamily: 'Nunito', color: Colors.white, fontSize: 15),
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
        bodyMedium:
            TextStyle(fontSize: 16, height: 1.45, color: BrandColors.ink),
        bodyLarge:
            TextStyle(fontSize: 17, height: 1.45, color: BrandColors.ink),
        titleMedium: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: BrandColors.ink),
        titleLarge: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: BrandColors.ink),
        headlineSmall: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800, color: BrandColors.ink),
      ).apply(fontFamily: 'Nunito'),
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
          // Sin barra de desplazamiento global (corrección
          // 2026-11-12, Kristian): la barra bonita SOLO va en
          // las pantallas de estudio (detalle de tema, glosario,
          // cuaderno, vía QuemiaScrollBehavior). En las pantallas
          // principales no hay barra.
          home: _showSplash
              ? SplashScreen(
                  onDone: () => setState(() => _showSplash = false),
                )
              : _banned
                  ? const BannedScreen()
                  : _onboardingDone
                      ? KeyedSubtree(
                          key: ValueKey('home-$_reloadToken'),
                          child: HomeScreen(
                            isDark: _isDark,
                            onToggleTheme: _toggleTheme,
                            onTrackChanged: _reloadApp,
                          ),
                        )
                      : OnboardingScreen(
                          onFinished: () =>
                              setState(() => _onboardingDone = true),
                        ),
        ),
      ),
    );
  }
}

/// Barra de desplazamiento bonita: vive en
/// lib/widgets/quemia_scrollbar.dart y SOLO la usan las
/// pantallas de estudio (detalle de tema, glosario,
/// cuaderno). En las pantallas principales no hay barra
/// (corrección 2026-11-12, Kristian).

/// Chip de repaso en la AppBar (fix2, item 2): icono de repaso +
/// cantidad de errores por repasar, con el color del tema.
/// Icono ARRIBA del texto no: en la barra va en línea, como el chip
/// de vidas, para que quepa junto a la campana.
/// PÍLDORA teal oscura (Zona F, corrección 2026-11-12, imagen de
/// Kristian): fondo #134E4A, icono + número en menta #2DD4BF,
/// redondeada, en claro y en oscuro (color semántico, no de
/// acento). Antes era fondo transparente con el color del tema.
class _ReviewChip extends StatelessWidget {
  const _ReviewChip({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          // Píldora teal oscura con el número dentro (imagen de
          // Kristian): fondo #134E4A, icono + número en menta.
          // Altura fija kTopBarPillHeight: igual que vidas y campana.
          decoration: BoxDecoration(
            color: const Color(0xFF134E4A),
            borderRadius: BorderRadius.circular(999),
          ),
          height: kTopBarPillHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LucideIcon(LucideIcons.rotateCcw,
                  size: 20, color: Color(0xFF2DD4BF)),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2DD4BF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Separación IGUAL entre los tres controles de la AppBar (fix4,
/// punto 9): vidas, repaso y campana. Cada control lleva este
/// padding a ambos lados, así que el hueco entre dos controles es
/// siempre 2 × _kTopBarGap (12 px) y no depende del icono que lleve
/// cada uno: antes los dos chips llevaban Padding(right: 2) y la
/// campana era un IconButton con su propio inset de 12 px, así que
/// los huecos se veían distintos.
const double _kTopBarGap = 6.0;

/// Campana de notificaciones en la AppBar (fix4, puntos 8 y 9):
/// PÍLDORA teal oscura (Zona F, corrección 2026-11-12, imagen de
/// Kristian): fondo #134E4A, campana en menta #2DD4BF, icono de
/// 20 px. Lleva el numerito rojo de no leídos de la bandeja (como
/// Facebook) solapado arriba a la derecha de la píldora; sin no
/// leídos, no hay numerito. Abre la bandeja de Notificaciones (ya
/// no Recordatorios).
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<InboxEntry>>(
      valueListenable: NotificationInbox.entriesNotifier,
      builder: (context, entries, _) {
        final unread = entries.where((e) => !e.read).length;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Tooltip(
                  message: tr('inboxTitle'),
                  child: Container(
                    // Píldora teal oscura con la campana dentro
                    // (imagen de Kristian): fondo #134E4A, campana
                    // en menta. Altura fija kTopBarPillHeight (36):
                    // la campana, sin número, quedaba 6 dp más baja
                    // que vidas y repaso (30 dp) y se veía más
                    // pequeña; el padding horizontal 18 iguala el
                    // ancho, la altura fija iguala el alto
                    // (corrección 2026-11-12, el alto, no el ancho).
                    decoration: BoxDecoration(
                      color: const Color(0xFF134E4A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    height: kTopBarPillHeight,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                    child: const LucideIcon(LucideIcons.bell,
                        size: 20, color: Color(0xFF2DD4BF), threeD: true),
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      key: const Key('inboxBadge'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        // Rojo Cardinal de Duolingo (§2): #FF4B4B.
                        color: const Color(0xFFFF4B4B),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: scheme.surface,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
  // Ronda #8 (Quemia 6.5): Niveles es el centro de la barra (índice
  // 2 en el orden nuevo: Resolver, Aprender, Niveles, Tabla,
  // Cuenta), así que la app arranca en Niveles, como siempre.
  int _index = 2;

  /// ¿Hay una sesión de juego en curso (quiz de nivel, repaso o
  /// examen mixto en línea)? Mientras la hay, la barra de arriba,
  /// el menú y la barra inferior se OCULTAN: la única salida es el
  /// botón Salir del quiz (fix2, ronda 2). Lo avisa PracticarScreen.
  bool _inSession = false;

  /// ¿Está abierto el menú hamburguesa? Lo sigue `onDrawerChanged`
  /// del Scaffold (ronda 7.2, Zona C): con el menú abierto, el
  /// contenido se ve con blur real + velo oscuro estilo
  /// "liquid glass"; el drawer en sí queda nítido por encima.
  /// Seguimiento 7.2: el blur cubre TODA la pantalla (AppBar +
  /// body + barra inferior), no solo el body.
  bool _drawerOpen = false;

  /// Overlay de blur "liquid glass" del menú abierto (ronda 7.2,
  /// Zona C; corrección 2026-11-13: UNA sola capa a pantalla
  /// completa por encima de la barra, el cuerpo y la barra
  /// inferior): blur real (sigma 10) + velo negro 35 % con
  /// entrada/salida animada (~250 ms). NO es el cuadrado gris plano
  /// que Kristian rechazó: el fondo se sigue viendo, difuminado. El
  /// drawer se pinta POR ENCIMA de este overlay (es del Scaffold),
  /// así que el menú queda nítido y opaco. IgnorePointer: los toques
  /// pasan al Scaffold, que cierra el menú al tocar fuera como
  /// siempre.
  Widget _drawerBlurOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: _drawerOpen ? 1 : 0),
          duration: const Duration(milliseconds: 250),
          builder: (context, t, child) {
            if (t == 0) return const SizedBox.shrink();
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10 * t, sigmaY: 10 * t),
              child: Container(
                color: Colors.black.withValues(alpha: 0.35 * t),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Tocar una notificación (o su acción "Repasar ahora") pide el
    // repaso de errores aunque la app ya estuviera abierta (fix3,
    // punto 9): sin este aviso, Niveles ya montada no volvería a
    // mirar el flag.
    NavRequests.reviewRequested.addListener(_onNotificationReviewRequest);
    // Push FCM (7.1): tocar un aviso con la app ya abierta pide la
    // pantalla que toca (Amigos, Soporte o la bandeja).
    NavRequests.pushRequested.addListener(_onPushRequest);
    // Recordatorio de actualización e instalación del APK (fix3,
    // punto 20): tocar esas notificaciones con la app ya abierta
    // pide el diálogo o la instalación, igual que el repaso.
    NavRequests.updateRequested.addListener(_onNotificationUpdateRequest);
    NavRequests.installRequested.addListener(_onNotificationInstallRequest);
    // Tras el primer frame: el diálogo de actualización si la app
    // se abrió desde su recordatorio, y si no, la comprobación
    // normal vía GitHub (fix3, punto 20). La pantalla pedida por
    // un push (app cerrada) va primero: el usuario tocó ese aviso.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final pushKey = NavRequests.takePendingPushScreen();
      if (pushKey != null) {
        _openScreenKey(pushKey);
      }
      if (NavRequests.showUpdateDialog) {
        NavRequests.showUpdateDialog = false;
        await UpdateCheckService.showPendingUpdateDialog(context);
        return;
      }
      await UpdateCheckService.checkForUpdate(context);
      if (!mounted) return;
      // Logros nuevos y aviso de racha en la bandeja (fix4, punto 8).
      await NotificationInbox.syncDaily(_trackTopics);
    });
  }

  @override
  void dispose() {
    NavRequests.reviewRequested.removeListener(_onNotificationReviewRequest);
    NavRequests.pushRequested.removeListener(_onPushRequest);
    NavRequests.updateRequested.removeListener(_onNotificationUpdateRequest);
    NavRequests.installRequested.removeListener(_onNotificationInstallRequest);
    super.dispose();
  }

  /// Repaso pedido por una notificación: ir a Niveles y arrancar el
  /// repaso de errores. Si hay una sesión en curso, la petición queda
  /// guardada (NavRequests.startReview) y Niveles la consume al
  /// terminar la sesión.
  void _onNotificationReviewRequest() {
    if (_inSession) return;
    if (!mounted) return;
    _goToTab(2, startReview: true);
  }

  /// Push FCM tocado con la app ya abierta: ir a la pantalla que
  /// toca (Amigos, Soporte o la bandeja). Igual que el repaso: un
  /// toque explícito del usuario, así que navega aunque haya una
  /// sesión de juego en curso (queda debajo, en la pila).
  void _onPushRequest() {
    final key = NavRequests.takePendingPushScreen();
    if (key == null || !mounted) return;
    _openScreenKey(key);
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

  // La primera pantalla es el camino de niveles (Niveles), como en
  // Duolingo; Resolver queda como una opción más. Niveles lleva la
  // pista como clave: al cambiar de versión se crea de nuevo.
  // La quinta pestaña es Cuenta (v6): Tips se mudó a Aprender.
  // Ronda #8 (Quemia 6.5): orden nuevo de la barra inferior,
  // con Niveles en el centro (índice 2): Resolver, Aprender,
  // Niveles, Tabla, Cuenta.
  List<Widget> get _pages => [
        const ResolverScreen(),
        const AprenderScreen(),
        PracticarScreen(
            key: ValueKey(ProgressService.track),
            onOpenScreen: _openScreenKey,
            onSessionChanged: (inSession) {
              if (_inSession != inSession) {
                setState(() => _inSession = inSession);
              }
            }),
        const TablaScreen(),
        AccountScreen(
          onOpenScreen: _openScreenKey,
          onShowAbout: () => _showAbout(context),
          onShowShareApp: () => _showShareApp(context),
          trackTopics: _trackTopics,
        ),
      ];

  /// Temas de la pista actual, en orden (para Mis estadísticas).
  List<String> get _trackTopics =>
      ProgressService.track == ProgressService.trackBach
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
    _goToTab(2, startReview: true);
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
      case 'leaderboard':
        page = const LeaderboardScreen();
      // Quemia 7.0: social (amigos, torneos, tienda, grupos).
      case 'friends':
        page = const FriendsScreen();
      case 'tournaments':
        page = const TournamentsScreen();
      case 'shop':
        page = const ShopScreen();
      case 'groups':
        page = const GroupsScreen();
      // Soporte en la app (7.0, Kristian 09:52): ventanita con hilo
      // y compositor (ya no abre WhatsApp directo).
      case 'support':
        page = const SupportScreen();
      // Ajustes (7.1, Zona H): última fila de Cuenta; abre su
      // propia pantalla con Tema, Recordatorios, Notificaciones,
      // Cómo se juega, Buscar actualización, Idioma, Cambiar
      // versión, Favoritos y Compartir progreso.
      case 'settings':
        page = SettingsScreen(onOpenScreen: _openScreenKey);
      // Avatar editable (7.1, alcance 9): el círculo grande de
      // la cabecera de Cuenta abre la galería.
      case 'avatar':
        page = AvatarEditorScreen(onOpenScreen: _openScreenKey);
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
      case 'notifications':
        page = NotificationsScreen(onOpenScreen: _openScreenKey);
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
      case 'howToPlay':
        // "¿Cómo se juega?" como pantalla completa (fix5, punto 1):
        // se abre desde la fila de Cuenta.
        page = const HowToPlayScreen();
      case 'tips':
        page = const TipsScreen();
      case 'review':
        _goToTab(2, startReview: true);
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
            MaterialPageRoute(builder: (_) => TopicDetailScreen(topic: topic)),
          );
        }
      case 'levels':
        Navigator.of(context).pop();
        _goToTab(2);
      case 'solver':
        Navigator.of(context).pop();
        _goToTab(0, openSolver: entry.target);
      case 'element':
        final z = int.tryParse(entry.target) ?? 0;
        final element =
            allElements.where((e) => e.atomicNumber == z).firstOrNull;
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

  /// Compartir la app (Quemia 7.1, Zona H): abre DIRECTO la hoja
  /// nativa del sistema (la de la captura: contactos y apps),
  /// sin diálogo ni pantalla intermedia con el enlace. El texto
  /// es la invitación a la app con la página
  /// https://quemia-8410a.web.app (la misma de la bio de
  /// Instagram; no tiene botón de descarga, así que compartirla
  /// no filtra el APK). share_plus ya era dependencia (la usa
  /// también el compartir del progreso como imagen).
  Future<void> _showShareApp(BuildContext context) async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Descarga Quemia, la app de química pura: $kShareUrl',
      ),
    );
  }

  /// Teléfono para mostrar: +5356519431 (o '+53 5 9999999' con
  /// espacios) → +53 56519431, como antes; otros formatos, tal cual.
  String _formatSupportPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[\s-]'), '');
    final m = RegExp(r'^\+53(\d{8})$').firstMatch(digits);
    return m == null ? raw.trim() : '+53 ${m.group(1)}';
  }

  /// Hoja "Acerca de Melli-Qui" con los datos de soporte. El
  /// teléfono es el número REMOTO de Soporte (7.0, 09:52; por
  /// defecto +5356519431), no un número fijo en el código.
  Future<void> _showAbout(BuildContext context) async {
    final settings = await SupportService.instance.fetchSupportSettings();
    if (!context.mounted) return;
    final number = settings.supportNumber;
    final display = _formatSupportPhone(number);
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
            Text('${tr('phoneWord')}: $display',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: number));
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
  /// Rediseño Duolingo (§3.15, Zona A): fila PLANA, sin tarjeta —
  /// el icono va en un círculo tintado (sin 3D ni degradado), el
  /// título es 17 pt peso 700 #4B4B4B, el subtítulo 15 pt #777777
  /// (se envuelve en tantas líneas como necesite, sin ellipsis) y
  /// el chevron es gris #AFAFAF. En oscuro los textos siguen el
  /// tema (onSurface / onSurfaceVariant).
  /// Sigue siendo un ListTile, para que el cableado de navegación y los
  /// tests que invocan su onTap no cambien.
  Widget _drawerItem({
    required LucideIconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = widget.isDark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      // Tres líneas de alto cuando hay subtítulo: así un subtítulo de
      // dos líneas (p. ej. el del simulador) cabe sin recortarse.
      isThreeLine: subtitle != null,
      // Icono en círculo tintado, PLANO (sin threeD, sin degradado).
      // La flecha de la derecha sigue plana (es solo una pista).
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primary.withValues(alpha: 0.12),
        ),
        alignment: Alignment.center,
        child: LucideIcon(icon, size: 22, color: scheme.primary),
      ),
      title: Text(title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? scheme.onSurface : const Color(0xFF4B4B4B),
          )),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              // Sin ellipsis ni límite de líneas: el texto completo
              // se ve, aunque ocupe dos líneas (el ListTile crece).
              softWrap: true,
              maxLines: null,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color:
                    isDark ? scheme.onSurfaceVariant : const Color(0xFF777777),
              ),
            ),
      trailing: const LucideIcon(LucideIcons.chevronRight,
          size: 18, color: Color(0xFFAFAFAF)),
      onTap: () {
        SoundService.tap();
        Navigator.of(context).pop();
        onTap();
      },
    );
  }

  /// Título de una sección del menú (Practicar, Referencia...).
  /// Rediseño Duolingo (§3.15, Zona A): título 20 pt peso 800
  /// #4B4B4B (en oscuro, onSurface), sin barrita, con divisor
  /// #E5E5E5 (oscuro #37464F). El título SIGUE en mayúsculas
  /// (toUpperCase): los tests del menú lo exigen y es solo aspecto.
  Widget _drawerSection(String title) {
    final scheme = Theme.of(context).colorScheme;
    final dividerColor =
        widget.isDark ? const Color(0xFF37464F) : const Color(0xFFE5E5E5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: widget.isDark ? scheme.onSurface : const Color(0xFF4B4B4B),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              height: 1,
              color: dividerColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Filas del menú SIN tarjeta (rediseño Duolingo §3.15, Zona A):
  /// la tarjeta de sección (Material gris + radio 20 + borde) se
  /// borra — las filas van directamente sobre el fondo del drawer,
  /// separadas por un Divider de 1 pt #E5E5E5 (oscuro #37464F).
  /// El ListTile sigue pintando su splash sobre el Material del
  /// propio Drawer, así que no hace falta envolverlo.
  /// (La tarjeta se quitó también en los tests de aspecto del menú;
  /// la navegación y el orden no cambian.)
  Widget _drawerCard(List<Widget> items) {
    final dividerColor =
        widget.isDark ? const Color(0xFF37464F) : const Color(0xFFE5E5E5);
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(Divider(
          height: 1,
          indent: 68,
          endIndent: 16,
          color: dividerColor,
        ));
      }
      children.add(items[i]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  /// Barra superior (menú, vidas, repaso, campana). Vive en el
  /// cuerpo (no en el slot appBar del Scaffold) para que el
  /// difuminado del menú sea UNA sola capa de blur a pantalla
  /// completa por encima de la barra, el cuerpo y la barra
  /// inferior (corrección 2026-11-13, Kristian: un solo
  /// difuminado uniforme, sin costuras). El drawer sigue siendo
  /// del Scaffold y se pinta por encima, así que queda nítido.
  Widget _topBar() {
    return AppBar(
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
        // Separación igual entre los tres controles (fix4,
        // punto 9): cada uno lleva _kTopBarGap a ambos lados.
        Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: _kTopBarGap),
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
            padding:
                const EdgeInsets.symmetric(horizontal: _kTopBarGap),
            child: ValueListenableBuilder<int>(
              valueListenable: ProgressService.failedNotifier,
              builder: (context, _, __) => _ReviewChip(
                count: ProgressService.instance.failedCount,
                onTap: _startReviewFromAppBar,
              ),
            ),
          ),
        ),
        // Campana de notificaciones (fix4, punto 8): abre la
        // bandeja de Notificaciones (ya no Recordatorios).
        // Fondo transparente como los otros dos chips
        // (§3.9.5, Zona A), no píldora.
        Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: _kTopBarGap),
            child: _NotificationBell(
              onTap: () => _openScreenKey('notifications'),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Color de la pestaña seleccionada (fix2, items 8 y 12; fix4,
    // punto 2): en modo oscuro sigue al acento — menta con Verde,
    // violeta claro con Violeta. En claro, el color propio de cada
    // pestaña con el acento verde, o violeta para todas con el
    // acento violeta.
    // Ronda #8 (Quemia 6.5): la lista va en el orden NUEVO de la
    // barra (Resolver, Aprender, Niveles, Tabla, Cuenta), así que
    // cada pestaña conserva SU color de antes: Resolver era la 1,
    // Aprender la 2, Niveles la 0, Tabla la 3 y Cuenta la 4.
    const _navOldIndex = [1, 2, 0, 3, 4];
    final tabColors = List<Color>.generate(
      5,
      (i) => widget.isDark
          ? (AppAccent.isViolet
              ? BrandColors.violetLight
              : BrandColors.mintLight)
          : AppAccent.tabColor(_navOldIndex[i]),
    );
    return PopScope(
      // Botón atrás: primero cierra lo abierto por dentro (quiz,
      // solucionador); si no hay nada, vuelve a Niveles; solo en
      // Niveles y sin nada abierto se sale de la app.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (BackNav.handle()) return;
        if (_index != 2) {
          setState(() => _index = 2);
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        // Sin velo gris sobre la pantalla al abrir el menú
        // (corrección 2026-11-12, Kristian): el scrim oscuro
        // dejaba un cuadrado gris detrás del icono de Cuenta en
        // la franja que el menú no cubre. Sin scrim, la pantalla
        // de detrás se ve normal y el menú se distingue por su
        // propia sombra; tocar fuera sigue cerrándolo.
        // El difuminado al abrir el menú (ronda 7.2, Zona C) NO
        // es ese gris plano: es blur real + velo, pintado por el
        // overlay único a pantalla completa del body (ver
        // _drawerBlurOverlay). Por eso el scrim sigue en
        // transparente.
        drawerScrimColor: Colors.transparent,
        // Sigue si el menú está abierto o cerrado para el blur
        // del body: abrir/cerrar (gesto, tocar fuera, atrás)
        // lo maneja el Scaffold como siempre; esto solo avisa.
        onDrawerChanged: (open) {
          if (_drawerOpen != open) setState(() => _drawerOpen = open);
        },
        // Sin botón flotante de Soporte (fix2, ronda 2): el pill
        // verde tapaba contenido en Niveles y en Tabla. Soporte
        // vive ahora al pie del menú hamburguesa.
        // Menú hamburguesa: el organizador de la app. Cada fila abre su
        // propia pantalla; nada suelto ni repetido dentro del menú.
        // La barra de búsqueda va PRIMERA y FIJA (fix2, item 11): no
        // se desplaza con el resto del menú. Tocar abre la búsqueda.
        drawer: _inSession
            ? null
            : Drawer(
                // Fondo plano del drawer (rediseño Duolingo §3.15):
                // blanco en claro, superficie oscura en oscuro — las
                // filas van directamente sobre este fondo, sin tarjeta.
                backgroundColor: widget.isDark ? scheme.surface : Colors.white,
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
                                horizontal: 16, vertical: 16),
                            // Campo §1.6: radio 16, borde 2 pt #E5E5E5
                            // en claro (#37464F en oscuro, auditoría
                            // 7.2); al enfocar, #84D8FF. Sin sombra. El
                            // padding vertical 16 (como el campo de
                            // Amigos) hace que la caja PINTADA mida
                            // ≥ 56 pt de alto (mínimo §1.6): el
                            // minHeight del tema solo agranda el
                            // hueco, no la caja visible.
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: widget.isDark
                                      ? const Color(0xFF37464F)
                                      : const Color(0xFFE5E5E5),
                                  width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: widget.isDark
                                      ? const Color(0xFF37464F)
                                      : const Color(0xFFE5E5E5),
                                  width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: Color(0xFF84D8FF), width: 2),
                            ),
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
                            // Rediseño Duolingo (§3.15, Zona A): PLANO, sin
                            // degradado ni radios inferiores — fondo blanco
                            // (superficie oscura en oscuro). Se quedan el
                            // logo del anillo (56), "Quemia" 28 pt w800 y
                            // el subtítulo (alcance 10: sin gemelas aquí).
                            Container(
                              width: double.infinity,
                              color: scheme.surface,
                              padding:
                                  const EdgeInsets.fromLTRB(20, 20, 20, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Alcance 10 (7.1): el logo del
                                  // ANILLO (el icono actual de la
                                  // app, teal sobre blanco), no la
                                  // pastilla marrón de las gemelas.
                                  // Cuadrado 56x56 con radio 14.
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.asset(
                                      'assets/app_icon.png',
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text('Quemia',
                                      style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5)),
                                  const SizedBox(height: 4),
                                  Text(
                                    tr('appSubtitle'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.3,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            _drawerCard([
                              _drawerItem(
                                icon: LucideIcons.network,
                                title: tr('menuBranches'),
                                subtitle:
                                    'Orgánica, Inorgánica, Analítica, Química física',
                                onTap: () => _openScreenKey('branches'),
                              ),
                              _drawerItem(
                                icon: LucideIcons.dna,
                                title: tr('menuLab'),
                                subtitle: 'Seguridad, cuestionario y simulador',
                                onTap: () => _openScreenKey('lab'),
                              ),
                            ]),
                            // Fix4, punto 12: el simulador SÍ va como
                            // entrada aparte en el menú, en Referencia
                            // (Kristian lo pidió así: acceso directo al
                            // simulador, además de la tarjeta de
                            // Laboratorio). La decisión fix3 de no
                            // duplicarlo queda sustituida por esta.
                            _drawerSection(tr('drawerPractice')),
                            _drawerCard([
                              _drawerItem(
                                icon: LucideIcons.timer,
                                title: tr('timedTitle'),
                                subtitle: tr('timedSub'),
                                onTap: () => _openScreenKey('timed'),
                              ),
                              _drawerItem(
                                icon: LucideIcons.trophy,
                                title: tr('accountLeaderboard'),
                                subtitle: tr('accountLeaderboardSub'),
                                onTap: () => _openScreenKey('leaderboard'),
                              ),
                              // Quemia 7.0: social junto a la tabla.
                              _drawerItem(
                                icon: LucideIcons.userRound,
                                title: tr('accountFriends'),
                                subtitle: tr('accountFriendsSub'),
                                onTap: () => _openScreenKey('friends'),
                              ),
                              _drawerItem(
                                icon: LucideIcons.award,
                                title: tr('accountTournaments'),
                                subtitle: tr('accountTournamentsSub'),
                                onTap: () => _openScreenKey('tournaments'),
                              ),
                              _drawerItem(
                                icon: LucideIcons.network,
                                title: tr('accountGroups'),
                                subtitle: tr('accountGroupsSub'),
                                onTap: () => _openScreenKey('groups'),
                              ),
                              _drawerItem(
                                icon: LucideIcons.circleHelp,
                                title: tr('tableQuizTitle'),
                                subtitle: 'Adivina el elemento',
                                onTap: () => _openScreenKey('tableQuiz'),
                              ),
                            ]),
                            _drawerSection(tr('drawerReference')),
                            _drawerCard([
                              _drawerItem(
                                icon: LucideIcons.flaskConical,
                                title: tr('labSimTitle'),
                                subtitle: 'Mezcla, mira el pH y el color',
                                onTap: () => _openScreenKey('labSim'),
                              ),
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
                            ]),
                            // Ronda #6, ítem 5: "Mi cuaderno" sale del menú
                            // (clave 'notes'); la pantalla de notas sigue
                            // existiendo en _openScreenKey y en la búsqueda.
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        body: SafeArea(
          top: true,
          bottom: false,
          // UN SOLO difuminado uniforme sobre TODA la pantalla
          // trasera al abrir el menú (corrección 2026-11-13,
          // Kristian): la barra de arriba, el cuerpo y la barra
          // inferior viven en esta misma columna, con UNA sola
          // capa de blur + velo a pantalla completa por encima
          // de los tres (un solo sigma, un solo velo, sin
          // costuras). El drawer se pinta POR ENCIMA (es del
          // Scaffold), así que el menú queda nítido.
          child: Stack(
            children: [
              Column(
                children: [
                  // Las tres posiciones son FIJAS (con SizedBox
                  // vacío en sesión): si la barra o la navegación
                  // desaparecieran de la lista, el Expanded
                  // cambiaría de índice y Flutter destruiría el
                  // AnimatedSwitcher con el quiz en curso (el
                  // _inSession se quedaba en true y se veía Niveles
                  // sin barras ni quiz). Con hueco fijo, el quiz
                  // sobrevive al cambio de _inSession.
                  _inSession
                      ? const SizedBox.shrink()
                      : MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: _topBar(),
                        ),
                  // Cambio de pestaña con fundido +
                  // deslizamiento suave.
                  // El Expanded lleva CLAVE: al entrar/salir de una
                  // sesión la barra y la navegación cambian de tipo
                  // (a SizedBox), y el diff de Flutter desactiva
                  // todo el medio de la lista si el Expanded no
                  // tiene clave — con ella, el AnimatedSwitcher y
                  // el quiz en curso sobreviven al cambio de
                  // _inSession (sin la clave, el quiz se destruía
                  // y quedaba Niveles sin barras ni quiz).
                  Expanded(
                    key: const ValueKey('homeBody'),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(
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
                  _inSession
                      ? const SizedBox.shrink()
                      : MainBottomNav(
                          selectedIndex: _index,
                          onSelected: (i) {
                            SoundService.tap();
                            setState(() => _index = i);
                          },
                          isDark: widget.isDark,
                          tabColors: tabColors,
                        ),
                ],
              ),
              _drawerBlurOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}
