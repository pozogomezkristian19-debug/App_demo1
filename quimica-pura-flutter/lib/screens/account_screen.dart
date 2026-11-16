// Pantalla Cuenta — PERFIL ESTILO DUOLINGO (Kristian 2026-11-16):
// Cuenta ya NO es una pestaña del navbar: es una PANTALLA APARTE
// (AccountProfilePage, ruta propia) que se abre al tocar Cuenta en
// la barra de abajo, SIN la barra de abajo y SIN la barra de
// corazones/puntos de arriba. Se vuelve con la X y con el atrás
// del teléfono. Dentro, todo organizado y clarito como el perfil
// de Duolingo: foto/avatar GRANDE con el lapicito para editarla,
// nombre + @usuario · año en que se unió, fila Niveles /
// Siguiendo / Seguidores, botón AGREGA AMIGOS, RESUMEN (racha,
// puntos, trofeos, logros), LOGROS (los 10 logros, gris el que
// falta), fila Premium y las filas de contenido. La tarjeta de
// la contraseña y el banner de prueba siguen aquí (son lo de
// "completar el perfil").
// - Vincular con Google, Acerca de y Compartir la app se mudaron
//   a Ajustes (por categorías: Cuenta / Suscripción / Soporte);
//   la fila Ajustes la sustituye el engranaje de arriba.
// - (2026-11-16, simplificación aprobada): en el perfil quedan
//   SOLO 5 filas (Estadísticas, Amigos, Tabla, Torneo, Canjear);
//   Premium vive solo en Ajustes → SUSCRIPCIÓN, Tienda en
//   Ajustes → TIENDA y Referidos en Ajustes → CUENTA.
// - (2026-11-16, lote de perfil): nombre debajo del avatar (no en
//   la cabecera, según la guía); zona del avatar con su propio
//   fondo; contadores Siguiendo/Seguidores reales y tocables (sus
//   listas); botón QR al lado de AGREGA AMIGOS; tarjeta
//   "¡Completa tu perfil!" y sugerencias de amigos.
// - El avatar del usuario NO cambia: solo su presentación, grande
//   y limpia. Las gemelas Brenda (violeta) y Britany (azul) no
//   cambian: la compañera del día sigue en su línea pequeña.
// - El selector de foto del usuario (subir foto propia) sigue
//   QUITADO (fix2, item 6): la galería de avatares solo usa las
//   fotos predefinidas del proyecto, no subidas.
// - onShowAbout/onShowShareApp se conservan en el constructor
//   por compatibilidad (los tests montan AccountScreen con ellos);
//   las filas que los usaban viven ahora en Ajustes y llegan a
//   ellos por las claves 'about'/'shareApp' de _openScreenKey.
//
// El contenido lleva padding inferior de 32 pt (sin barra abajo
// que tape nada: la pantalla es aparte).
//
// El HUD superior (chips de vidas/repaso/campana) vive en el
// AppBar de main.dart, no en esta pantalla: al ser ruta aparte,
// la barra de arriba no se ve aquí.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/icon_animations.dart';
import '../widgets/avatar_frame_ring.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/motion.dart';

import '../services/achievements.dart';
import '../services/analytics_sync.dart';
import '../services/auth_service.dart';
import '../services/localization.dart';
import '../services/accent.dart';
import '../services/premium.dart';
import '../services/premium_service.dart';
import '../services/referral_service.dart';
import '../services/trial.dart';

import '../services/progress.dart';
import '../services/remote_shop_catalog.dart';
import '../services/social_service.dart';
import '../services/sound_service.dart';
import '../services/user_prefs.dart';
import '../services/notification_service.dart';
import '../services/otp_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/duo_button.dart';
import '../widgets/set_password_form.dart';
import '../widgets/social_avatar.dart';
import '../widgets/trial_banner.dart';
import '../widgets/twin_avatars.dart';
import 'onboarding_screen.dart';
import 'otp_code_page.dart';
import 'profile_qr_screen.dart';
import 'public_profile_screen.dart';

/// Tokens claros (rediseño Duolingo 7.0): texto #4B4B4B,
/// terciario #777777, líneas #E5E5E5; teal #00C2A8 como color
/// principal, teal oscuro #00A18D.
// (Quemia 7.3: el teal fijo de antes se sustituyó por el acento del
// tema — AppAccent.primary — en cada uso; _teal ya no existe.)
const _ink = Color(0xFF4B4B4B);
const _inkSoft = Color(0xFF777777);
const _border = Color(0xFFE5E5E5);
const _violet = Color(0xFF8B5CF6);
const _amber = Color(0xFFF59E0B);

/// Colores de Cuenta según el tema (auditoría fix2): en claro son los
/// de siempre (fondo blanco, tinta #4B4B4B, gris #777777, líneas
/// #E5E5E5); en oscuro son verdes oscuros, para que Cuenta no se
/// quede blanca en modo oscuro (item 8: oscuro verde, sin
/// violeta/azul/ámbar). Las gemelas (Brenda violeta, Britany azul)
/// NO cambian: son las mascotas, no el acento del tema.
class _CuentaColors {
  const _CuentaColors({
    required this.bg,
    required this.ink,
    required this.inkSoft,
    required this.border,
    required this.card,
  });

  factory _CuentaColors.of(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      // Fondo y tarjetas según el acento (fix4, punto 2).
      return _CuentaColors(
        bg: AppAccent.darkBackground,
        ink: Colors.white,
        inkSoft: AppAccent.darkInkSoft,
        border: AppAccent.darkBorder,
        card: AppAccent.darkCard,
      );
    }
    return const _CuentaColors(
      bg: Colors.white,
      ink: _ink,
      inkSoft: _inkSoft,
      border: _border,
      card: Colors.white,
    );
  }

  final Color bg;
  final Color ink;
  final Color inkSoft;
  final Color border;

  /// Fondo de las tarjetas (cabecera y filas): blanco en claro,
  /// superficie oscura en oscuro (6.3).
  final Color card;
}

/// Nombre que se enseña en el perfil estilo Duolingo: el nombre
/// completo del usuario; sin nombre guardado, el nombre público
/// si ya existe, y si no, el título "Cuenta".
String accountDisplayName() {
  if (UserPrefs.userName.isNotEmpty) return UserPrefs.userName;
  if (UserPrefs.publicUsername.isNotEmpty) return UserPrefs.publicUsername;
  return tr('accountTitle');
}

/// Cuenta como PANTALLA APARTE (Kristian 2026-11-16, perfil
/// estilo Duolingo): ruta propia con su Scaffold — X a la
/// izquierda para volver, nombre centrado y ENGRANAJE a la derecha
/// que abre Ajustes. Sin barra de abajo ni barra de corazones:
/// esta pantalla es aparte del todo. El cuerpo es AccountScreen
/// (el contenido del perfil), que así se puede montar solo en
/// tests sin el Scaffold de alrededor.
class AccountProfilePage extends StatelessWidget {
  const AccountProfilePage({
    super.key,
    required this.onOpenScreen,
    required this.onShowAbout,
    required this.onShowShareApp,
    required this.trackTopics,
  });

  final void Function(String key) onOpenScreen;
  final VoidCallback onShowAbout;
  final VoidCallback onShowShareApp;
  final List<String> trackTopics;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // X para volver, como el perfil de Duolingo (el atrás del
        // teléfono también cierra la ruta, como siempre).
        leading: IconButton(
          key: const ValueKey('accountCloseButton'),
          icon: const LucideIcon(LucideIcons.x),
          tooltip: tr('closeWord'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // El NOMBRE en la cabecera, centrado, como en Duolingo
        // (Kristian 2026-11-16: la captura de su perfil de
        // Duolingo lo lleva ahí, no debajo del avatar).
        centerTitle: true,
        title: Text(
          accountDisplayName(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        // El engranaje llevaba el padding por defecto y quedaba
        // muy pegado al borde derecho (Kristian 2026-11-16): 12 pt
        // de aire a la derecha, como el resto de la pantalla.
        actionsPadding: const EdgeInsets.only(right: 12),
        // Engranaje arriba, como Duolingo: abre Ajustes (la fila
        // Ajustes de la Cuenta vieja ya no existe; el engranaje
        // ES la entrada a Ajustes).
        actions: [
          IconButton(
            key: const ValueKey('accountSettingsButton'),
            icon: const LucideIcon(LucideIcons.settings),
            tooltip: tr('settingsTitle'),
            onPressed: () => onOpenScreen('settings'),
          ),
        ],
      ),
      body: AccountScreen(
        onOpenScreen: onOpenScreen,
        onShowAbout: onShowAbout,
        onShowShareApp: onShowShareApp,
        trackTopics: trackTopics,
      ),
    );
  }
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.onOpenScreen,
    required this.onShowAbout,
    required this.onShowShareApp,
    required this.trackTopics,
  });

  /// Abre una pantalla por su clave ('language', 'stats', 'version',
  /// 'review', 'favorites', 'reminder', 'theme').
  final void Function(String key) onOpenScreen;
  final VoidCallback onShowAbout;
  final VoidCallback onShowShareApp;
  final List<String> trackTopics;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  void initState() {
    super.initState();
    _loadGoogleState();
    _loadPasswordState();
    _loadJoinedYear();
    // Lo social (sugerencias, AGREGA AMIGOS, seguidores) solo
    // existe con sesión (Kristian 2026-11-16): sin sesión ni se
    // carga ni se enseña nada de eso.
    if (_signedIn) {
      _socialLoaded = true;
      _loadFollowCounts();
      _loadSuggestions();
    }
  }

  /// ¿Ya se cargó lo social? Se marca al cargarlo (en initState o
  /// al aparecer la sesión estando la pantalla abierta: un invitado
  /// que vincula Google desde Ajustes vuelve a Cuenta con sesión
  /// y lo social tiene que aparecer sin reabrir la pantalla).
  bool _socialLoaded = false;

  /// ¿Hay sesión (Google o correo vinculada)? Lo social solo sale
  /// con sesión: sugerencias, AGREGA AMIGOS, QR y los contadores
  /// de Siguiendo/Seguidores (Kristian 2026-11-16).
  bool get _signedIn =>
      AuthService.isGoogleLinked || AuthService.isEmailLinked;

  /// Subtítulo de la fila Premium (igual que en Ajustes): prueba
  /// con días, Premium pagado con fecha de vencimiento o gratis.
  String _premiumSubtitle() {
    if (TrialService.isTrialActiveNow) {
      final days = TrialService.daysLeftNow;
      if (days <= 1) return tr('accountPremiumTrialDay');
      return tr('accountPremiumTrialDays')
          .replaceFirst('%s', '$days');
    }
    if (PremiumService.hasPaidPremium) {
      final expires =
          PremiumService.expiresNotifier.value ?? PremiumFlags.expiresAt;
      if (expires != null) {
        return tr('accountPremiumActive')
            .replaceFirst('%s', formatPremiumDate(expires));
      }
      return tr('accountPremium');
    }
    return tr('accountPremiumFree');
  }

  /// ¿Se enseña la tarjeta de completar perfil? Solo con sesión
  /// (Google o correo) y sin nombre de usuario reclamado.
  bool get _showCompleteProfile => _signedIn && _myUsername.isEmpty;

  /// Seguidores y seguidos REALES (lote 2026-11-16): de la colección
  /// 'follows'. null = aún cargando (se enseña '…', nunca un 0
  /// inventado).
  int? _followingCount;
  int? _followersCount;

  Future<void> _loadFollowCounts() async {
    final me = AuthService.currentUid ?? '';
    if (me.isEmpty) {
      if (mounted) {
        setState(() {
          _followingCount = 0;
          _followersCount = 0;
        });
      }
      return;
    }
    final following = await SocialService.followingCount(me);
    final followers = await SocialService.followersCount(me);
    if (!mounted) return;
    setState(() {
      _followingCount = following;
      _followersCount = followers;
    });
  }

  /// Sugerencias de amigos (lote 2026-11-16): 2 personas que rotan
  /// cada día. null = aún cargando; [] = no hay ninguna.
  List<FriendEntry>? _suggestions;

  /// ¿A cuáles de las sugerencias ya sigo? (para que el botón diga
  /// SIGUIENDO desde el principio).
  final _suggestionFollowing = <String, bool>{};

  /// ¿Cuáles de las sugerencias ME siguen a mí? (si sigo a una que
  /// me sigue, somos mutuos: el botón lleva corazón, no check).
  final _suggestionFollowedBy = <String, bool>{};

  /// Sugerencias en salida (al seguir, la tarjeta se desliza y se
  /// desvanece en 300 ms antes de que la sustituya la siguiente).
  final _exitingSuggestions = <String>{};

  /// Seguir en curso por uid (el botón no acepta otro toque
  /// mientras tanto).
  final _followBusy = <String>{};

  Future<void> _loadSuggestions() async {
    final list = await SocialService.friendSuggestions();
    if (!mounted) return;
    final following = <String, bool>{};
    final followedBy = <String, bool>{};
    for (final s in list) {
      following[s.deviceId] = await SocialService.isFollowing(s.deviceId);
      followedBy[s.deviceId] =
          await SocialService.isFollowedBy(s.deviceId);
    }
    if (!mounted) return;
    setState(() {
      _suggestions = list;
      _suggestionFollowing
        ..clear()
        ..addAll(following);
      _suggestionFollowedBy
        ..clear()
        ..addAll(followedBy);
    });
  }

  /// Seguir / dejar de seguir desde una sugerencia: el botón pasa
  /// a SIGUIENDO (o vuelve a SEGUIR) y los contadores se recargan.
  /// Al SEGUIR, la tarjeta se desliza/desvanece en 300 ms y la
  /// sustituye la siguiente sugerencia (pulido Duolingo 2026-11-16).
  /// Las sugerencias solo se enseñan con sesión (Kristian
  /// 2026-11-16), así que aquí siempre hay sesión: sin puerta de
  /// invitado.
  Future<void> _toggleSuggestionFollow(FriendEntry user) async {
    final uid = user.deviceId;
    if (_followBusy.contains(uid)) return;
    setState(() => _followBusy.add(uid));
    final following = _suggestionFollowing[uid] ?? false;
    final ok = following
        ? await SocialService.unfollowUser(uid)
        : await SocialService.followUser(uid);
    if (!mounted) return;
    setState(() {
      _followBusy.remove(uid);
      if (ok) _suggestionFollowing[uid] = !following;
    });
    if (!ok) return;
    await _loadFollowCounts();
    if (following) return;
    setState(() => _exitingSuggestions.add(uid));
    await Future.delayed(AppMotion.cardExit);
    if (!mounted) return;
    setState(() => _exitingSuggestions.remove(uid));
    await _loadSuggestions();
  }

  /// La X de una sugerencia: la descarta solo por hoy.
  Future<void> _dismissSuggestion(FriendEntry user) async {
    await SocialService.dismissSuggestion(user.deviceId);
    if (!mounted) return;
    setState(() => _suggestions = _suggestions
        ?.where((s) => s.deviceId != user.deviceId)
        .toList());
  }

  /// Completar el perfil (Kristian 2026-11-16): la tarjeta
  /// "¡Completa tu perfil!" abre "Personaliza tu nombre de
  /// usuario" (campo con el sugerido, comprobación en vivo,
  /// "QUIZÁ MÁS TARDE" para saltarlo); al guardar sale
  /// "¡Se ve genial!" y al volver la tarjeta ya no está.
  Future<void> _openCompleteProfile() async {
    final name = UserPrefs.userName;
    final email = AuthService.accountEmail;
    final base = ReferralService.usernameBaseFromGoogle(
      name.isEmpty ? null : name,
      email,
    );
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _CompleteProfileFlow(base: base),
      ),
    );
    if (saved == true && mounted) _loadGoogleState();
  }

  /// Perfil público de otra persona (Kristian 2026-11-16): al
  /// tocar una sugerencia (o a alguien de las listas de
  /// seguidos/seguidores) se abre aunque no seamos amigos.
  void _openPublicProfile(String uid) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(uid: uid),
      ),
    );
  }

  /// Listas de seguidos / seguidores (Kristian 2026-11-16): al
  /// tocar Siguiendo o Seguidores se abre la lista real.
  void _openFollowList(String kind) {
    final me = AuthService.currentUid ?? '';
    if (me.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FollowListScreen(uid: me, kind: kind),
      ),
    );
  }

  /// Mi código QR (Kristian 2026-11-16): la tarjeta blanca con
  /// mi avatar, mi nombre y mi QR (quemia:user:<usuario>).
  Future<void> _openMyQr() async {
    if (_myUsername.isEmpty) return;
    final url = SocialService.equippedAvatarImageUrl;
    File? file;
    if (url != null && url.isNotEmpty) {
      file = await ShopImageCache.ensureCached(url);
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QrScreen(
          username: _myUsername,
          displayName: accountDisplayName(),
          avatarAsset: SocialService.displayAvatarAssetForGender(
              UserPrefs.userGender),
          avatarImageFile: file,
          isOwn: true,
        ),
      ),
    );
  }

  /// ¿Se enseña la tarjeta de "ponle una contraseña"?
  bool _showPasswordCard = false;

  /// Año en que se unió ("SE UNIÓ EN 2026", perfil estilo
  /// Duolingo): del progreso guardado en local. null = aún no
  /// hay año (entonces la línea no lo enseña, en vez de
  /// inventarlo).
  int? _joinedYear;

  Future<void> _loadJoinedYear() async {
    final ms = await AnalyticsSync.joinedAtMs();
    if (!mounted || ms == null) return;
    setState(() =>
        _joinedYear = DateTime.fromMillisecondsSinceEpoch(ms).year);
  }

  /// ¿Toca enseñar el aviso de contraseña? Solo si la cuenta se
  /// creó con Google y todavía no tiene contraseña. El RECORDATORIO
  /// es una notificación cada hora ("Asegura tu cuenta con una
  /// contraseña"); la tarjeta de Cuenta es donde se pone la
  /// contraseña, así que se enseña siempre que haga falta, sin
  /// límite de días. Cuando la contraseña queda puesta, isEmailLinked
  /// ya es true y el aviso no vuelve a salir nunca.
  Future<void> _loadPasswordState() async {
    final needsPassword =
        AuthService.isGoogleLinked && !AuthService.isEmailLinked;
    if (!mounted) return;
    setState(() => _showPasswordCard = needsPassword);
  }

  /// CREAR CONTRASEÑA (Kristian 2026-11-16): primero un OTP al
  /// correo para comprobar que la cuenta es suya, y después la
  /// hoja para crear la contraseña DENTRO de la app. SIN el correo
  /// de restablecer de Firebase: ese enlace ya no se manda en
  /// este flujo. Al guardar, la credencial se enlaza a la cuenta
  /// actual (el uid NO cambia) y la tarjeta desaparece.
  Future<void> _onCreatePasswordTap() async {
    final email = AuthService.accountEmail;
    if (email == null || email.isEmpty || !mounted) return;
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OtpCodePage(
          email: email,
          purpose: OtpPurpose.setPassword,
          title: tr('obSetPasswordOtpTitle'),
          body: tr('obSetPasswordOtpBody'),
          onBack: () => Navigator.of(context).pop(false),
          onVerified: () async => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (verified != true || !mounted) return;
    await _showSetPasswordSheet();
  }

  /// Hoja para crear la contraseña de la cuenta de Google: las
  /// mismas reglas fuertes del registro por correo. Al guardar, la
  /// credencial se enlaza a la cuenta actual (el uid NO cambia) y
  /// la tarjeta desaparece. Si falla, el error sale en una línea
  /// dentro de la hoja, sin cerrarla.
  Future<void> _showSetPasswordSheet() async {
    final email = AuthService.accountEmail;
    if (email == null || email.isEmpty || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _CuentaColors.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SetPasswordSheet(
        email: email,
        onSaved: () async {
          // Ya tiene contraseña: el recordatorio de cada hora para.
          await NotificationService.cancelPasswordReminder();
          await _loadPasswordState();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('accountSetPasswordSaved'))),
          );
        },
      ),
    );
  }

  /// Mi nombre de usuario público (Quemia 7.3, Kristian): el que
  /// le doy a un amigo para que me agregue. '' = aún sin poner
  /// (Kristian 2026-11-16: ya NADA lo reclama solo; se pone en el
  /// perfil con la tarjeta "¡Completa tu perfil!"). Solo se
  /// muestra si no está vacío.
  /// (La fila "Vincular con Google" y el diálogo de desvincular
  /// viven ahora en Ajustes, sección Cuenta — perfil estilo
  /// Duolingo, Kristian 2026-11-16.)
  String _myUsername = '';

  /// Solo LEE el nombre guardado (nunca lo reclama): si no hay
  /// nombre, la tarjeta de completar perfil es la que lo pide.
  /// Se vuelve a llamar al volver de poner el nombre, para que
  /// la tarjeta desaparezca y salga el @usuario.
  void _loadGoogleState() {
    final username = UserPrefs.publicUsername;
    if (_myUsername == username) return;
    _myUsername = username;
    if (mounted) setState(() {});
  }

  Future<void> _copyUsername() async {
    if (_myUsername.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _myUsername));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('myUsernameCopied'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    // La sesión apareció estando la pantalla abierta (el invitado
    // vinculó Google desde Ajustes): lo social se carga ahora, una
    // sola vez, sin reabrir la pantalla.
    if (_signedIn && !_socialLoaded) {
      _socialLoaded = true;
      _loadFollowCounts();
      _loadSuggestions();
    }
    final p = ProgressService.instance;
    // Colores según el tema (auditoría fix2): en oscuro, Cuenta es
    // verde oscura, no blanca.
    final c = _CuentaColors.of(context);
    // La compañera del día: su MINIATURA (22 dp) va junto a la
    // línea "Hoy te acompaña…" debajo del nombre.
    final companion = companionOfTheDay();
    final accent = companionAccent(companion);
    // Logros desbloqueados de los 10 que hay.
    final unlockedCount = allAchievements
        .where((a) => achievementUnlocked(a.id, p, widget.trackTopics))
        .length;
    // Trofeos ganados de la pista actual.
    final trophyWon = p.trophyCount(widget.trackTopics);
    // Niveles pasados en total: un tema con el nivel N abierto
    // tiene N-1 niveles pasados.
    final levelsPassed = p.unlockedLevels.values
        .fold<int>(0, (sum, u) => sum + (u > 1 ? u - 1 : 0));
    // Línea "@usuario · SE UNIÓ EN 2026" (como Duolingo): solo las
    // partes que existen; sin usuario ni año no se enseña nada.
    final joinedParts = <String>[
      if (_myUsername.isNotEmpty) '@$_myUsername',
      if (_joinedYear != null)
        tr('accountJoinedYear').replaceFirst('%s', '$_joinedYear'),
    ];
    final joinedLine = joinedParts.join(' · ').toUpperCase();

    return Container(
      color: c.bg,
      child: ListView(
        // Pantalla aparte (sin barra abajo que tape nada):
        // padding inferior de 32 pt.
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ZONA DEL AVATAR (Kristian 2026-11-16): como en Duolingo,
          // SIN división — el avatar va directo sobre el fondo de
          // la pantalla, sin cuadrado ni fondo distinto, y el
          // NOMBRE vive en la cabecera, no debajo del avatar.
          // Debajo del avatar: @usuario · año y la compañera del
          // día, a la izquierda como en Duolingo.
          Center(
            child: _UserAvatarSection(
              size: 160,
              onTap: () => widget.onOpenScreen('avatar'),
            ),
          ),
          if (joinedLine.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  child: Text(
                    joinedLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.inkSoft,
                    ),
                  ),
                ),
                // Botoncito de copiar el nombre de usuario
                // (GestureDetector: el icono es pequeño y no
                // necesita la onda de tinta).
                if (_myUsername.isNotEmpty)
                  GestureDetector(
                    onTap: _copyUsername,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: LucideIcon(
                        LucideIcons.copy,
                        size: 16,
                        color: c.inkSoft,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          // La compañera del día, en pequeño, con su miniatura
          // (22 dp) y su color.
          const SizedBox(height: 8),
          Row(
            children: [
              CompanionAvatar(
                companion: companion,
                size: 22,
                ring: false,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  tr(companionOfDayKey(companion)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Fila de usuarios, como Duolingo (número arriba en
          // negrita, letrero gris debajo): Niveles pasados siempre;
          // Siguiendo y Seguidores SOLO con sesión (Kristian
          // 2026-11-16: lo de los seguidores y demás solo sale una
          // vez iniciado sesión), con números REALES de la
          // colección 'follows' (punto 8). Siguiendo y Seguidores
          // se tocan y abren sus listas (refinamiento 2026-11-16).
          Row(
            children: [
              _ProfileStat(
                value: '$levelsPassed',
                label: tr('accountLevels'),
              ),
              if (_signedIn) ...[
                _ProfileStat(
                  value:
                      _followingCount == null ? '…' : '$_followingCount',
                  label: tr('accountFollowing'),
                  onTap: () => _openFollowList('following'),
                ),
                _ProfileStat(
                  value:
                      _followersCount == null ? '…' : '$_followersCount',
                  label: tr('accountFollowers'),
                  onTap: () => _openFollowList('followers'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // AGREGA AMIGOS, como Duolingo: botón grande con el
          // icono de amigo, que abre Amigos. Al lado, el botón
          // cuadrado con el QR de mi perfil (punto 11): sin
          // nombre de usuario no hay QR, así que no sale.
          // SOLO con sesión (Kristian 2026-11-16).
          if (_signedIn) ...[
            Row(
              children: [
                Expanded(
                  child: DuoButton.secondary(
                    key: const ValueKey('accountAddFriendsButton'),
                    label: tr('accountAddFriends').toUpperCase(),
                    icon: LucideIcons.userRound,
                    textColor: AppAccent.primary,
                    onPressed: () => widget.onOpenScreen('friends'),
                  ),
                ),
                if (_myUsername.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _QrSquareButton(
                    key: const ValueKey('accountQrButton'),
                    onTap: _openMyQr,
                  ),
                ],
              ],
            ),
            // Separación clara entre AGREGA AMIGOS y el banner de
            // la prueba (punto 2): antes iban pegados, sin hueco.
            const SizedBox(height: 16),
          ],
          // Aviso de la versión de prueba (Kristian 2026-11-15):
          // banner con los días que quedan, debajo de la cabecera.
          // Sin prueba no ocupa nada.
          // Sin const a propósito: como en Niveles, el banner lee
          // el acento y el brillo dentro de sus
          // ValueListenableBuilder; con const no se reconstruía al
          // cambiar de tema o de acento y se quedaba con los
          // colores viejos.
          TrialBanner(),
          // Tarjeta de completar perfil (punto 4): solo con sesión
          // y sin nombre de usuario. Al completarlo desaparece.
          if (_showCompleteProfile) ...[
            const SizedBox(height: 4),
            _CompleteProfileCard(onContinue: _openCompleteProfile),
          ],
          // SUGERENCIAS DE AMIGOS (punto 6): 2 personas que rotan
          // cada día, tras la tarjeta de completar perfil (donde
          // Duolingo las pone). SOLO con sesión (Kristian
          // 2026-11-16): sin sesión no se enseña nada de lo
          // social. Sin sugerencias no ocupa nada.
          if (_signedIn &&
              _suggestions != null &&
              _suggestions!.isNotEmpty) ...[
            _SectionTitle(title: tr('accountSuggestionsTitle')),
            ..._suggestions!.map((s) {
              // Al seguir, la tarjeta se desliza/desvanece en
              // 300 ms (solo opacidad con movimiento reducido).
              final exiting = _exitingSuggestions.contains(s.deviceId);
              return AnimatedOpacity(
                opacity: exiting ? 0 : 1,
                duration: AppMotion.cardExit,
                child: AnimatedSlide(
                  offset: exiting && !reducedMotion(context)
                      ? const Offset(0.3, 0)
                      : Offset.zero,
                  duration: AppMotion.cardExit,
                  child: _SuggestionRow(
                    entry: s,
                    following:
                        _suggestionFollowing[s.deviceId] ?? false,
                    followedBy:
                        _suggestionFollowedBy[s.deviceId] ?? false,
                    busy: _followBusy.contains(s.deviceId),
                    onFollow: () => _toggleSuggestionFollow(s),
                    onDismiss: () => _dismissSuggestion(s),
                    onOpen: () => _openPublicProfile(s.deviceId),
                  ),
                ),
              );
            }),
          ],
          // Aviso de contraseña (Kristian 2026-11-15): la cuenta se
          // creó con Google y no tiene contraseña. Sale una vez al
          // día como mucho, hasta que se ponga la contraseña.
          // Separación clara de la tarjeta de Cuenta (antes iba
          // pegada a ella, sin hueco).
          if (_showPasswordCard) ...[
            const SizedBox(height: 12),
            _PasswordPromptCard(
              onCreate: _onCreatePasswordTap,
            ),
          ],
          // RESUMEN (perfil estilo Duolingo, Kristian 2026-11-16):
          // racha, puntos, trofeos y logros, en 2x2, sin tarjeta.
          // (La StatsCard de antes — Vidas, Puntos, Racha, Meta y
          // Logros — queda sustituida por este resumen: las vidas
          // ya se ven en la barra de arriba de las demás pantallas
          // y la meta del día en Niveles. Duelos ganados no va:
          // la app no guarda ese contador en ningún sitio.)
          _SectionTitle(title: tr('accountSummary')),
          _SummaryGrid(
            streak: p.streakNow,
            points: p.points,
            trophies: '$trophyWon/${widget.trackTopics.length}',
            achievements: '$unlockedCount/${allAchievements.length}',
          ),
          // LOGROS (perfil estilo Duolingo): los 10 logros como
          // iconos; el que falta va en gris, como en Duolingo. Al
          // tocar uno se enseña qué es y cómo se consigue.
          _SectionTitle(title: tr('accountAchievements')),
          _AchievementsGrid(trackTopics: widget.trackTopics),
          // Filas de contenido que quedan en el perfil (Kristian
          // 2026-11-16, simplificación aprobada: SOLO 5): Estadísticas,
          // Amigos, Tabla de posiciones, Torneo y Canjear código, en
          // este orden. Premium vive SOLO en Ajustes → SUSCRIPCIÓN;
          // Tienda se mudó a Ajustes → TIENDA (sección nueva) y
          // Referidos a Ajustes → CUENTA. Nada se borra, solo se
          // mueve de sitio. Vincular con Google, Acerca de y
          // Compartir la app viven ahora en Ajustes; la fila
          // Ajustes la sustituye el engranaje de arriba.
          // Entrada escalonada (pulido 7.7).
          FadeSlideIn(
            delay: Duration(milliseconds: 0),
            child: _Row(
              icon: LucideIcons.chartColumn,
              iconColor: _violet,
              title: tr('accountStats'),
              subtitle: tr('accountStatsSub'),
              onTap: () => widget.onOpenScreen('stats'),
            ),
          ),
          // Amigos (SOLO con sesión, Kristian 2026-11-16: las
          // cosas de amigos — sugerencias, agregar, seguidores —
          // salen solo una vez iniciado sesión; la fila es la
          // entrada a esa pantalla, así que también se esconde).
          // Entrada escalonada (pulido 7.7).
          if (_signedIn)
            FadeSlideIn(
              delay: Duration(milliseconds: 20),
              child: _Row(
                icon: LucideIcons.userRound,
                iconColor: AppAccent.primary,
                title: tr('accountFriends'),
                subtitle: tr('accountFriendsSub'),
                onTap: () => widget.onOpenScreen('friends'),
              ),
            ),
          // Ronda #8 (Quemia 6.5): tabla de posiciones. SOLO con
          // sesión (Kristian 2026-11-16: lo de buscar otra gente
          // no le sale a un invitado, así no puede seguir a nadie).
          // Entrada escalonada (pulido 7.7).
          if (_signedIn)
            FadeSlideIn(
              delay: Duration(milliseconds: 40),
              child: _Row(
                icon: LucideIcons.trophy,
                iconColor: _amber,
                title: tr('accountLeaderboard'),
                subtitle: tr('accountLeaderboardSub'),
                onTap: () => widget.onOpenScreen('leaderboard'),
              ),
            ),
          // Torneos: SOLO con sesión, igual que la tabla (misma
          // orden: un invitado no ve lo de buscar otra gente).
          // Entrada escalonada (pulido 7.7).
          if (_signedIn)
            FadeSlideIn(
              delay: Duration(milliseconds: 60),
              child: _Row(
                icon: LucideIcons.award,
                iconColor: _amber,
                title: tr('accountTournaments'),
                subtitle: tr('accountTournamentsSub'),
                onTap: () => widget.onOpenScreen('tournaments'),
              ),
            ),
          // Tienda y Premium VUELVEN a Cuenta (Kristian 2026-11-16:
          // "saca tienda y premium de configuraciones, déjalo en
          // cuenta"): estaban en Ajustes desde la simplificación
          // del 2026-11-16 02:19; ahora salen de Ajustes y vuelven
          // aquí, para todos (no son sociales: también de
          // invitado). La Tienda abre la pantalla de cosméticos;
          // Premium abre el paywall (que pide sesión solo ahí).
          // Entrada escalonada (pulido 7.7).
          FadeSlideIn(
            delay: Duration(milliseconds: 80),
            child: _Row(
              icon: LucideIcons.gift,
              iconColor: _violet,
              title: tr('accountShop'),
              subtitle: tr('accountShopSub'),
              onTap: () => widget.onOpenScreen('shop'),
            ),
          ),
          // Premium: el subtítulo vive (prueba con días, Premium
          // pagado con fecha de vencimiento o gratis), igual que
          // estaba en Ajustes.
          AnimatedBuilder(
            animation: Listenable.merge([
              PremiumService.premiumNotifier,
              PremiumService.expiresNotifier,
              TrialService.trialNotifier,
              TrialService.trialDaysLeftNotifier,
            ]),
            builder: (context, _) => FadeSlideIn(
              delay: Duration(milliseconds: 100),
              child: _Row(
                icon: LucideIcons.crown,
                iconColor: _amber,
                title: tr('accountPremium'),
                subtitle: _premiumSubtitle(),
                onTap: PremiumService.requestPaywall,
              ),
            ),
          ),
          // Canjear código (7.6, Kristian): apartado SEPARADO en
          // Cuenta, como en la app de Muse (fila "Canjea el código
          // de recomendación"). Abre directo las 6 casillas.
          // Entrada escalonada (pulido 7.7).
          FadeSlideIn(
            delay: Duration(milliseconds: 120),
            child: _Row(
              icon: LucideIcons.gift,
              iconColor: AppAccent.primary,
              title: tr('accountRedeem'),
              subtitle: tr('accountRedeemSub'),
              onTap: () => widget.onOpenScreen('redeem'),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 28),
                const SizedBox(width: 8),
                Text(
                  'Quemia',
                  style: TextStyle(fontWeight: FontWeight.bold, color: c.ink),
                ),
                Text(
                  ' · ${tr('creatorWord')}: CraigKamer',
                  style: TextStyle(color: c.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Título de sección del perfil estilo Duolingo ("RESUMEN",
/// "LOGROS"): mayúsculas, gris, 15 pt peso 800, con aire arriba.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = _CuentaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: c.inkSoft,
        ),
      ),
    );
  }
}

/// Una celda de la fila de usuarios del perfil (Niveles /
/// Siguiendo / Seguidores, como Duolingo): número arriba en
/// negrita, letrero gris debajo. Siguiendo y Seguidores se tocan
/// (lote 2026-11-16) y abren sus listas; Niveles no hace nada.
class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = _CuentaColors.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: c.inkSoft),
        ),
      ],
    );
    if (onTap == null) return Expanded(child: content);
    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            SoundService.tap();
            onTap!();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// RESUMEN del perfil estilo Duolingo: racha, puntos, trofeos y
/// logros, en 2x2, sin tarjeta. Cada celda es icono + número en
/// una sola línea (como la StatsCard de antes) y el letrero
/// debajo, centrado.
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.streak,
    required this.points,
    required this.trophies,
    required this.achievements,
  });

  final int streak;
  final int points;
  final String trophies;
  final String achievements;

  @override
  Widget build(BuildContext context) {
    final c = _CuentaColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    // Iconos del RESUMEN (Kristian 2026-11-16, punto 5): Racha =
    // llama (como está), Puntos = RAYO, Trofeos = trofeo, Logros =
    // MEDALLA. Estilo Duolingo, colores de Quemia.
    final boltColor = isDark ? scheme.primary : const Color(0xFFF59E0B);
    final trophyColor = isDark ? scheme.primary : const Color(0xFF8B5CF6);
    final medalColor = isDark ? scheme.primary : AppAccent.primary;
    const valueStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
    Widget cell(Widget icon, Widget value, String label) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 5),
              value,
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: c.inkSoft),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: cell(
                Image.asset(
                  'assets/streak_fire_orange.png',
                  width: 28,
                  height: 28,
                ),
                // Pulido (2026-11-16): la racha y los puntos
                // cuentan hacia arriba con pulso elástico al
                // cambiar.
                CountUp(value: streak, style: valueStyle),
                tr('accountStreak'),
              ),
            ),
            Expanded(
              child: cell(
                LucideIcon(
                  LucideIcons.zap,
                  size: 22,
                  color: boltColor,
                  filled: true,
                  threeD: true,
                ),
                CountUp(value: points, style: valueStyle),
                tr('accountPoints'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: cell(
                LucideIcon(
                  LucideIcons.trophy,
                  size: 22,
                  color: trophyColor,
                  threeD: true,
                ),
                Text(trophies, style: valueStyle),
                tr('trophiesWord'),
              ),
            ),
            Expanded(
              child: cell(
                LucideIcon(
                  LucideIcons.medal,
                  size: 22,
                  color: medalColor,
                  threeD: true,
                ),
                Text(achievements, style: valueStyle),
                tr('accountAchievements'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// LOGROS del perfil estilo Duolingo: los 10 logros como iconos
/// en 5 columnas; el que falta va en gris, como en Duolingo. Al
/// tocar uno se enseña qué es y cómo se consigue.
class _AchievementsGrid extends StatelessWidget {
  const _AchievementsGrid({required this.trackTopics});

  final List<String> trackTopics;

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final c = _CuentaColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        // Alto FIJO de celda (120): con childAspectRatio la altura
        // salía del ancho, y en pantallas anchas (web, 1919 px) cada
        // celda medía ~600 px de alto y la rejilla ~1200 px, dejando
        // un hueco vacío enorme entre LOGROS y las filas del menú
        // (verificación en vivo 2026-11-16). 120 cabe en el teléfono
        // (círculo 50 + título en 2 líneas ~28 pt + aire) y no crece
        // en escritorio.
        mainAxisExtent: 120,
      ),
      itemCount: allAchievements.length,
      itemBuilder: (context, i) {
        final a = allAchievements[i];
        final unlocked = achievementUnlocked(a.id, p, trackTopics);
        final bg = unlocked
            ? AppAccent.primary.withValues(alpha: 0.12)
            : (isDark ? c.border : const Color(0xFFE5E5E5));
        final fg = unlocked
            ? (isDark ? scheme.primary : AppAccent.primary)
            : (isDark ? AppAccent.darkInkSoft : const Color(0xFF9CA3AF));
        return GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${a.title} — ${a.body}')),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: LucideIcon(a.icon, size: 28, color: fg),
              ),
              const SizedBox(height: 4),
              Text(
                a.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: unlocked ? c.ink : c.inkSoft,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Círculo grande del avatar del USUARIO (alcance 9, 7.1): la
/// foto equipada (o la de por defecto según el género) en 96 dp,
/// con un distintivo de lápiz que dice que se puede cambiar.
/// Al tocarlo se abre la galería de avatares. Usa SocialAvatar,
/// el mismo widget que en Amigos, tabla y torneos: sin inicial,
/// siempre una cara.
/// La foto del usuario en la cabecera (7.3): resuelve la foto
/// remota del avatar equipado (si es un avatar nuevo de la
/// tienda, su `imageUrl` ya descargada en disco) y el marco
/// equipado (el anillo alrededor de la foto). Escucha los dos
/// notifiers de SocialService, así el círculo repinta al instante
/// al equipar otro avatar o marco sin volver a entrar.
class _UserAvatarSection extends StatefulWidget {
  const _UserAvatarSection({required this.onTap, this.size = 96});

  final VoidCallback onTap;

  /// Diámetro del círculo: 96 dp en la cabecera vieja, 160 dp en
  /// el perfil estilo Duolingo (foto grande).
  final double size;

  @override
  State<_UserAvatarSection> createState() => _UserAvatarSectionState();
}

class _UserAvatarSectionState extends State<_UserAvatarSection> {
  File? _remoteFile;

  @override
  void initState() {
    super.initState();
    SocialService.equippedAvatarIdNotifier.addListener(_resolve);
    SocialService.equippedFrameIdNotifier.addListener(_onFrameChanged);
    _resolve();
  }

  void _onFrameChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _resolve() async {
    final url = SocialService.equippedAvatarImageUrl;
    File? file;
    if (url != null && url.isNotEmpty) {
      file = await ShopImageCache.ensureCached(url);
    }
    if (!mounted) return;
    setState(() => _remoteFile = file);
  }

  @override
  void dispose() {
    SocialService.equippedAvatarIdNotifier.removeListener(_resolve);
    SocialService.equippedFrameIdNotifier.removeListener(_onFrameChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _UserAvatarCircle(
      asset: SocialService.displayAvatarAssetForGender(UserPrefs.userGender),
      avatarImageFile: _remoteFile,
      frame: SocialService.equippedFrameItem,
      size: widget.size,
      onTap: widget.onTap,
    );
  }
}

class _UserAvatarCircle extends StatelessWidget {
  const _UserAvatarCircle({
    required this.asset,
    required this.onTap,
    this.avatarImageFile,
    this.frame,
    this.size = 96,
  });

  final String asset;
  final VoidCallback onTap;

  /// Foto remota del avatar equipado (caché en disco), o null si
  /// el avatar es de asset.
  final File? avatarImageFile;

  /// Marco equipado de la tienda (7.3), o null sin marco.
  final ShopItem? frame;

  /// Diámetro del círculo (96 dp antes, 160 dp en el perfil
  /// estilo Duolingo); el lapicito crece con él.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr('avatarTitle'),
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            SoundService.tap();
            onTap();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AvatarFrameRing(
                frame: frame,
                ringWidth: 4,
                child: SocialAvatar(
                  username: UserPrefs.userName,
                  size: size,
                  avatarAsset: asset,
                  avatarImageFile: avatarImageFile,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: size >= 140 ? 36 : 28,
                  height: size >= 140 ? 36 : 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppAccent.primary,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: LucideIcon(
                    LucideIcons.pencil,
                    size: size >= 140 ? 18 : 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cambio rápido claro/oscuro (Quemia 7.7, Kristian 2026-11-14:
/// la Lottie "toogle" de LottieFiles en la tarjeta de Cuenta):
/// al tocar, cambia entre claro y oscuro SIN tocar el sistema
/// de temas de Ajustes (allí siguen "sistema", "claro" y
/// "oscuro"). La animación es un paisaje día/noche (590x320,
/// 60 fps, 200 fotogramas) con marcadores: "Day Idle" 0-20,
/// "Day to Night" 20-80, "Night Idle" 81-119, "Night to Day"
/// 120-200. El paquete lottie no entiende la máquina de estados
/// del .lottie, así que la transición se hace a mano con un
/// controlador: día en reposo = fotograma 10 (0.05), noche en
/// reposo = fotograma 100 (0.5). Claro→oscuro anima de 0.05 a
/// 0.5 (pasa por "Day to Night"); oscuro→claro anima de 0.5 a
/// 1.0 (pasa por "Night to Day") y al terminar salta a 0.05,
/// que es el mismo día en reposo. Si el tema cambia en otro
/// sitio (Ajustes), el notifier pone el interruptor en el
/// estado que toca. En pruebas queda fijo en el estado actual,
/// sin animar.

/// Una fila de Cuenta como TARJETA redondeada (organización
/// 6.3): cada fila en su propia tarjeta con separación, icono
/// en un chip tintado, título 17 pt peso 700, subtítulo 15 pt
/// gris, chevron gris a la derecha. Sin sombra borrosa (estilo
/// Duolingo aprobado): la tarjeta es plana, con borde de 1 pt.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final LucideIconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = _CuentaColors.of(context);
    // En modo oscuro, los iconos llevan el color del acento
    // (menta con Verde, violeta claro con Violeta): el "nada de
    // violeta en oscuro" era de la ronda #2, cuando el oscuro era
    // verde fijo; con el oscuro violeta (fix4, punto 2) el icono
    // sigue al acento.
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.primary
        : this.iconColor;
    // Tarjeta (organización 6.3): radio 16, borde de 1 pt, sin
    // sombra borrosa. La separación entre tarjetas la da el
    // margen inferior de 12 pt.
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            SoundService.tap();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: LucideIcon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 15,
                          color: c.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                LucideIcon(
                  LucideIcons.chevronRight,
                  size: 20,
                  color: c.inkSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón cuadrado con el icono QR (punto 11): al lado de AGREGA
/// AMIGOS (perfil propio) y de SEGUIR (perfil ajeno, con el código
/// de esa persona).
class _QrSquareButton extends StatelessWidget {
  const _QrSquareButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          SoundService.tap();
          onTap();
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppAccent.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppAccent.primary.withValues(alpha: 0.35),
            ),
          ),
          alignment: Alignment.center,
          child: LucideIcon(
            LucideIcons.qrCode,
            size: 28,
            color: AppAccent.primary,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta "¡Completa tu perfil! QUEDA 1 PASO" (punto 4): con una
/// melliza (la compañera del día, nunca el búho de Duolingo) y el
/// botón CONTINUAR. Solo se enseña si hay sesión y aún no hay
/// nombre de usuario.
class _CompleteProfileCard extends StatelessWidget {
  const _CompleteProfileCard({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = _CuentaColors.of(context);
    final companion = companionOfTheDay();
    // Pulido (2026-11-16): pop elástico al aparecer la primera
    // vez. La melliza queda ESTÁTICA (Kristian 2026-11-16:
    // "quítale la mascota" — la respiración en bucle se quitó
    // con el resto de animaciones de la mascota).
    return PopOnMount(
      child: Container(
        key: const ValueKey('completeProfileCard'),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CompanionAvatar(
                companion: companion,
                size: 56,
                ring: false,
              ),
              const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('accountCompleteProfileTitle'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr('accountCompleteProfileStep').toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppAccent.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr('accountCompleteProfileBody'),
                    style: TextStyle(fontSize: 13, color: c.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            DuoButton.primary(
              label: tr('accountCompleteProfileButton').toUpperCase(),
              onPressed: onContinue,
              fontSize: 15,
            ),
          ],
        ),
      ),
    ),
  );
  }
}

/// Una sugerencia de amigo (punto 6): avatar con cara, nombre,
/// "Es posible que se conozcan", botón SEGUIR (o SIGUIENDO si ya
/// lo sigo) y X para descartarla. Al tocar la tarjeta (no el
/// botón) se abre su perfil público.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.entry,
    required this.following,
    required this.followedBy,
    required this.busy,
    required this.onFollow,
    required this.onDismiss,
    required this.onOpen,
  });

  final FriendEntry entry;
  final bool following;

  /// ¿Me sigue de vuelta? (mutuo: corazón en vez de check).
  final bool followedBy;
  final bool busy;
  final VoidCallback onFollow;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = _CuentaColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            SoundService.tap();
            onOpen();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SocialAvatar(
                  username: entry.username,
                  avatarAsset: entry.avatarAsset,
                  badgeId: entry.badgeId,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr('accountSuggestionsSub'),
                        style: TextStyle(fontSize: 13, color: c.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Pulido (2026-11-16): al pasar a SIGUIENDO el
                // botón hace pop; el check hace pop con él, y si
                // es mutuo (me sigue de vuelta) lleva corazón.
                FollowPulse(
                  following: following,
                  child: DuoButton.secondary(
                    label: (following
                            ? tr('accountFollowingBtn')
                            : tr('accountFollow'))
                        .toUpperCase(),
                    icon: following
                        ? (followedBy
                            ? LucideIcons.heart
                            : LucideIcons.check)
                        : null,
                    onPressed: busy ? null : onFollow,
                    fontSize: 14,
                  ),
                ),
                IconButton(
                  icon: const LucideIcon(LucideIcons.x, size: 20),
                  color: c.inkSoft,
                  tooltip: tr('closeWord'),
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de aviso en Cuenta (Kristian 2026-11-15): la cuenta se
/// creó con Google y no tiene contraseña. Estilo de tarjeta de
/// Cuenta (radio 20, borde 1 pt, sin sombra): icono de candado en
/// chip ámbar, título, texto y el botón para crearla.
/// COMPACTA (2026-11-15, Kristian: era demasiado grande y pegada
/// a la tarjeta de Cuenta): menos relleno, icono y textos más
/// chicos, botón más chico; la separación con la tarjeta de
/// Cuenta la pone el hueco de arriba (SizedBox 12), no la tarjeta.
class _PasswordPromptCard extends StatelessWidget {
  const _PasswordPromptCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final c = _CuentaColors.of(context);
    return Container(
      key: const ValueKey('passwordPromptCard'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const LucideIcon(
                    LucideIcons.lock,
                    color: _amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('accountSetPasswordTitle'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr('accountSetPasswordBody'),
                        style: TextStyle(fontSize: 13, color: c.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DuoButton.primary(
              label: tr('accountSetPasswordButton').toUpperCase(),
              onPressed: onCreate,
              fontSize: 15,
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja para crear la contraseña de una cuenta de Google (Kristian
/// 2026-11-15): el correo de la cuenta arriba y el formulario
/// compartido (campo con ojo, 5 reglas fuertes, GUARDAR
/// CONTRASEÑA). El formulario es el mismo que la página entera
/// del flujo de correo tomado (`SetPasswordForm`); la hoja solo
/// pone el título, el correo y el texto, y al guardar se cierra
/// y llama a `onSaved`.
class _SetPasswordSheet extends StatelessWidget {
  const _SetPasswordSheet({required this.email, required this.onSaved});

  /// Correo de la cuenta de Google (la contraseña se enlaza a él).
  final String email;

  /// Al guardar bien: recarga el aviso (la tarjeta desaparece) y
  /// enseña la confirmación.
  final Future<void> Function() onSaved;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final sub =
        isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF777777);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tirador de la hoja.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sub.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('obPasswordTitle'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: sub,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('accountSetPasswordSheetBody'),
              style: TextStyle(fontSize: 15, height: 1.4, color: sub),
            ),
            const SizedBox(height: 24),
            SetPasswordForm(
              email: email,
              onSaved: () async {
                Navigator.of(context).pop();
                await onSaved();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Flujo de completar el perfil (punto 4, Kristian 2026-11-16):
/// una sola ruta que primero enseña "Personaliza tu nombre de
/// usuario" (campo con el sugerido, comprobación en vivo,
/// "QUIZÁ MÁS TARDE" para saltarlo) y al guardar cambia a
/// "¡Se ve genial!". El OK cierra la ruta con true (se guardó);
/// volver o saltar la cierra con false (la tarjeta seguirá en
/// Cuenta hasta que ponga su nombre).
class _CompleteProfileFlow extends StatefulWidget {
  const _CompleteProfileFlow({required this.base});

  /// Nombre sugerido (primer nombre o prefijo del correo).
  final String base;

  @override
  State<_CompleteProfileFlow> createState() => _CompleteProfileFlowState();
}

class _CompleteProfileFlowState extends State<_CompleteProfileFlow> {
  var _saved = false;
  var _savedName = '';

  Future<void> _onConfirm(String chosen) async {
    final claimed = await ReferralService.claimUsername(chosen);
    if (!mounted) return;
    setState(() {
      _saved = true;
      _savedName = claimed;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_saved) {
      return _UsernameSavedScreen(
        username: _savedName,
        onOk: () => Navigator.of(context).pop(true),
      );
    }
    return UsernameChoicePage(
      base: widget.base,
      prefillField: true,
      titleText: tr('usernamePersonalizeTitle'),
      bodyText: tr('usernamePersonalizeBody'),
      onConfirm: _onConfirm,
      onBack: () => Navigator.of(context).pop(false),
      onSkip: () => Navigator.of(context).pop(false),
    );
  }
}

/// "¡Se ve genial!" (punto 10): tras guardar el nombre de usuario.
/// La melliza del día (nunca el búho), el nombre con @ y el botón
/// OK que vuelve a Cuenta.
class _UsernameSavedScreen extends StatelessWidget {
  const _UsernameSavedScreen({
    required this.username,
    required this.onOk,
  });

  final String username;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final sub =
        isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF777777);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Celebración por fases (pulido 2026-11-16): melliza
              // → título → texto → @nombre → botón, 100 ms entre
              // fases, nunca todo a la vez. La melliza queda
              // ESTÁTICA (Kristian 2026-11-16: sin animación de
              // la mascota — el salto con estrellitas se quitó).
              StaggeredEntrance(
                index: 0,
                child: Center(
                  child: CompanionAvatar(
                    companion: companionOfTheDay(),
                    size: 120,
                    ring: false,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              StaggeredEntrance(
                index: 1,
                child: Text(
                  tr('usernameSavedTitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StaggeredEntrance(
                index: 2,
                child: Text(
                  tr('usernameSavedBody'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.4, color: sub),
                ),
              ),
              if (username.isNotEmpty) ...[
                const SizedBox(height: 12),
                StaggeredEntrance(
                  index: 3,
                  child: Text(
                    '@$username',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppAccent.primary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              StaggeredEntrance(
                index: 4,
                child: DuoButton.primary(
                  label: tr('okWord'),
                  onPressed: onOk,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
