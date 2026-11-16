// Pantallas de bienvenida: solo salen la primera vez que se instala la app.
// No necesitan internet. Al final se guardan el nombre, el género y el
// idioma en el teléfono, y cada entrada saluda "Bienvenido/a
// [primer nombre]" (Kristian).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../widgets/duo_button.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/icon_animations.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/password_rules.dart';
import '../widgets/play_once_lottie.dart';
import '../widgets/quemia_field.dart';
import '../services/accent.dart';
import '../services/analytics_sync.dart';
import '../services/auth_service.dart';
import '../services/email_index.dart';
import '../services/localization.dart';
import '../services/otp_service.dart';
import '../services/platform_check.dart';
import 'loading_screen.dart';
import '../services/referral_service.dart';
import '../services/user_prefs.dart';
import 'onboarding_notifications_page.dart';
import 'otp_code_page.dart';
import 'set_password_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinished,
    this.fromAccount = false,
    this.onCancel,
  });
  final VoidCallback onFinished;

  /// Flujo reutilizable desde Cuenta (Quemia 7.7, Kristian
  /// 2026-11-13): un usuario que entró "sin conexión" y luego
  /// quiere iniciar sesión ve LAS MISMAS pantallas que al
  /// instalar. Con fromAccount=true el flujo empieza en la
  /// elección (sin la Bienvenida) y sin el botón "Sin conexión"
  /// (ya está sin conexión: en su lugar va "Volver").
  final bool fromAccount;

  /// Cancelar el flujo abierto desde Cuenta (vuelve a Cuenta).
  /// Solo se usa con fromAccount=true.
  final VoidCallback? onCancel;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  // Nombre de usuario del perfil (Quemia 7.7, Kristian 2026-11-13):
  // se SUGIERE del correo de Google (primer nombre de la cuenta) o
  // del correo que se escribe en la pantalla de registro (prefijo
  // del correo), pero se ELIGE DESPUÉS, en el perfil ("¡Completa tu
  // perfil!"), no en el registro (Kristian 2026-11-16: la pantalla
  // de elegir usuario salió del registro). Sin género: ya no se
  // pregunta (el saludo usa "Bienvenido/a" si no hay género
  // guardado).
  String? _profileName;
  // Código de referido (Quemia 7.6, Kristian): va en la pantalla
  // de género, con y sin Google, y se guarda en local aunque no
  // haya internet (se canjea solo cuando hay conexión).
  final _referralController = TextEditingController();
  late int _page;

  /// Carga tras el inicio (Quemia 7.7, Kristian 2026-11-14): después
  /// de pasar cualquiera de las 3 formas de empezar se muestra la
  /// animación de carga y al terminar se carga la pantalla de
  /// Niveles. La animación dura 3 s (una vuelta completa del
  /// círculo) y la espera es de 3 s para que se vea ENTERA: con
  /// 2 s la pantalla cambiaba a mitad de la animación.
  var _loading = false;
  Timer? _loadingTimer;

  Future<void> _finishWithLoading() async {
    if (_loading) return;
    if (isFlutterTest) {
      widget.onFinished();
      return;
    }
    setState(() => _loading = true);
    _loadingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) widget.onFinished();
    });
  }

  // Crear cuenta (Quemia 7.7, Kristian 2026-11-13, flujo estilo
  // Duolingo): cómo supo de Quemia ('google' | 'instagram' |
  // 'facebook' | 'tiktok' | 'friends' | 'other'), cuánta química
  // sabe (0..4) y su meta diaria (3 | 10 | 15 | 30 min). Se guardan
  // en UserPrefs al confirmar cada pantalla (no al final), así no
  // se pierden si el usuario enlaza con Google a mitad de camino.
  String? _source;
  int? _level;
  var _goalMinutes = 10;

  @override
  void initState() {
    super.initState();
    // Desde Cuenta (fromAccount) el flujo empieza en la elección
    // (página 1), no en la Bienvenida: el usuario ya está en la
    // app y viene a iniciar sesión.
    _pageController = PageController(initialPage: widget.fromAccount ? 1 : 0);
    _page = widget.fromAccount ? 1 : 0;
  }

  /// En la página de registro (9) no se avanza sin nombre de
  /// usuario: el nombre lo pone Google o el correo, nunca se
  /// escribe a mano (Kristian 2026-11-13). La pantalla de registro
  /// solo llama a [_next] cuando ya tiene el nombre.
  bool get _profileOk => (_profileName ?? '').trim().isNotEmpty;

  Future<void> _next() async {
    if (_page == 9 && !_profileOk) return;
    // 11 páginas (Quemia 7.7, Kristian 2026-11-13): 0 bienvenida,
    // 1 elección (empezar / tengo cuenta / sin conexión), 2 la
    // gemela que se presenta, 3 cómo supo de Quemia, 4 cuánta
    // química sabe, 5 meta diaria, 6 notificaciones, 7 la racha
    // nueva, 8 aviso "¡No pierdas tu progreso!" (Duolingo, antes
    // del registro), 9 registro (Google / correo, como Duolingo —
    // sin nombre ni género), 10 código de referido. El idioma ya
    // NO se pide aquí: la app coge el del sistema al instalar y
    // solo se cambia en Ajustes.
    if (_page < 10) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Google enlazado desde la pantalla de entrar (no desde el
  /// registro): el flujo corto de Google salta el referido y las
  /// notificaciones — tras entrar va directo a la principal, sin
  /// preguntas (Kristian 2026-11-15). Las preguntas (fuente,
  /// nivel, meta, notificaciones, racha, aviso) quedan solo en
  /// crear cuenta.
  var _googleFromSignIn = false;

  /// "Sin conexión" (Quemia 7.7, Kristian 2026-11-13): ya NO entra
  /// directo sin más — pide solo el nombre y la meta diaria
  /// (minutos) y va directo a la principal. Sin cuenta, sin
  /// Google, sin correo, sin referido, sin notificaciones. El
  /// nombre se guarda para el saludo ("Bienvenido/a [nombre]") y
  /// el usuario podrá vincular Google o crear su perfil después
  /// desde Cuenta.
  var _offlineFlow = false;

  /// Correo ya tomado (Kristian 2026-11-15): PANTALLA ENTERA, no
  /// un cuadradito. El correo y si la cuenta ya tiene contraseña
  /// (del índice de correos): con contraseña no se ofrece ponerle
  /// una (sería pedirlo de nuevo).
  var _emailTakenFlow = false;
  String _emailTakenEmail = '';

  /// ¿Tiene contraseña la cuenta del correo tomado? null = no se
  /// sabe (el índice no lo tenía).
  bool? _emailTakenHasPassword;

  /// Ponerle una contraseña al correo tomado (Kristian 2026-11-16):
  /// OTP → entrar con Google (para ser dueño de la cuenta) →
  /// CREA TU CONTRASEÑA dentro de la app. SIN el correo de
  /// restablecer de Firebase. Solo uno de estos tres está activo
  /// a la vez; `_emailTakenFlow` queda en false mientras tanto.
  String? _setPasswordOtpEmail;
  var _setPasswordGoogleStep = false;
  String? _setPasswordEmail;

  /// Aviso en la pantalla de correo tomado (p. ej. la cuenta de
  /// Google elegida no es la del correo tomado).
  String? _takenEmailNotice;

  /// true mientras el Google del paso de crear contraseña está en
  /// marcha: al enlazar bien, en vez de abrir el flujo corto de
  /// Google se abre la pantalla de crear la contraseña.
  var _googleForSetPassword = false;

  /// Correo con el que entrar (pantalla de correo tomado → inicio
  /// de sesión con el correo ya puesto).
  String _signInEmail = '';

  /// Crear cuenta (Quemia 7.7): confirmar "¿Cómo supiste de
  /// Quemia?" — guarda la respuesta y avanza. Sin elegir no se
  /// avanza (el botón sale deshabilitado).
  Future<void> _confirmSource() async {
    final source = _source;
    if (source == null) return;
    await UserPrefs.saveHeardFrom(source);
    await _next();
  }

  /// Crear cuenta (Quemia 7.7): confirmar "¿Cuánta química
  /// sabes?" — guarda el nivel (0..4) y avanza.
  Future<void> _confirmLevel() async {
    final level = _level;
    if (level == null) return;
    await UserPrefs.saveChemLevel(level);
    await _next();
  }

  /// Crear cuenta (Quemia 7.7): confirmar la meta diaria — guarda
  /// los minutos (3 | 10 | 15 | 30) y avanza.
  Future<void> _confirmGoal() async {
    await UserPrefs.saveDailyGoal(_goalMinutes);
    await _next();
  }

  Future<void> _finish() async {
    final name = (_profileName ?? '').trim();
    if (name.isEmpty) return;
    // Código de referido (Quemia 7.6): se guarda en local y se
    // canjea solo en segundo plano cuando hay conexión.
    await ReferralService.saveOnboardingCode(_referralController.text);
    unawaited(ReferralService.redeemOnboardingCode());
    // El nombre de usuario YA NO se reclama aquí (Kristian
    // 2026-11-16: la pantalla de elegir usuario salió del
    // registro): quien no tenga nombre lo pone después en su
    // perfil, con la tarjeta "¡Completa tu perfil!". Nada
    // reclama un nombre en silencio.
    // El nombre que se escribió se guarda como perfil (el saludo
    // usa su primer nombre).
    await UserPrefs.saveProfile(name);
    await _finishWithLoading();
  }

  /// Registro con correo (Quemia 7.7, Kristian 2026-11-13: como
  /// Duolingo, "Continuar con correo electrónico"): el flujo del
  /// correo es correo → contraseña → nombre → código OTP. Al
  /// verificar el código se ENLAZA la cuenta (linkWithEmail) y se
  /// avanza al código de referido (Kristian 2026-11-16: SIN la
  /// pantalla de elegir usuario, que salió del registro; el nombre
  /// se pone después en el perfil). El nombre que se escribe en la
  /// pantalla "¿Cómo te llamas?" es el que saluda la app
  /// ("Bienvenido/a [primer nombre]"). [_emailFlow] cambia TODA la
  /// pantalla por el flujo del correo (igual que [_googleFlow]
  /// con Google).
  var _emailFlow = false;

  /// "Ya tengo una cuenta" (Quemia 7.7, Kristian 2026-11-13: la
  /// pantalla de Duolingo "Ingresa tus datos"): correo +
  /// contraseña, "¿Has olvidado tu contraseña?" (recuperar por
  /// OTP) y Google. [_signInFlow] cambia TODA la pantalla por el
  /// inicio de sesión (igual que [_googleFlow]).
  var _signInFlow = false;

  /// Registro con correo verificado: enlaza la cuenta, guarda el
  /// nombre que se escribió (ese es el que saluda la app) y avanza
  /// al código de referido. (El correo ya no se guarda aparte:
  /// el nombre de usuario sale del correo solo si el usuario lo
  /// pone después en su perfil.)
  Future<void> _registerWithEmail(
      String email, String password, String fullName) async {
    final ok = await AuthService.linkWithEmail(email, password);
    if (!mounted) return;
    if (!ok) {
      // El correo ya tiene cuenta: el enlace no pudo entrar en
      // ella (la contraseña escrita no es la de esa cuenta). Si el
      // motivo real es que el correo ya está tomado, se abre la
      // PANTALLA de correo tomado (Kristian 2026-11-15: pantalla
      // entera, no un cuadradito), que antes verifica en el índice
      // si la cuenta ya tiene contraseña. Sin internet o con otro
      // fallo, solo queda la línea en el registro (la pantalla
      // mentiría).
      // La comprobación del índice se hace ANTES de cerrar el
      // flujo del correo: mientras tanto la pantalla del OTP sigue
      // con su carga y no se salta a otra pantalla sin explicación.
      if (AuthService.lastEmailError == 'firebase_auth:email-already-in-use') {
        final entry = await EmailIndex.lookup(email);
        if (!mounted) return;
        setState(() {
          _emailFlow = false;
          _emailTakenEmail = email;
          _emailTakenHasPassword = entry?.hasPassword;
          _takenEmailNotice = null;
          _emailTakenFlow = true;
        });
        return;
      }
      setState(() {
        _emailFlow = false;
        _googleError = tr('obEmailInUse');
      });
      // Volver a la página del registro (igual que al terminar
      // bien): sin esto, el PageView se remonta en la Bienvenida
      // y la línea del error no se ve nunca.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_page);
      }
      return;
    }
    setState(() {
      _profileName = fullName.trim().isNotEmpty ? fullName.trim() : email;
      _emailFlow = false;
    });
    // Sin pantalla de elegir usuario (Kristian 2026-11-16): tras
    // enlazar el correo se sigue de largo al código de referido.
    // El nombre de usuario se pone después, en el perfil.
    // El flujo del correo sustituye TODA la pantalla (no hay
    // PageView montada): al volver, el PageController crea su
    // posición desde initialPage (0, Bienvenida) y se perdería la
    // página. Hay que esperar al frame, saltar a la página del
    // registro y recién ahí avanzar al referido.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_page);
    }
    await _next();
  }

  /// "Continuar con Google" (ronda #8, cambio 09:08): enlaza la
  /// sesión anónima con Google (mismo uid, sin cambiarlo) y trae
  /// el respaldo de la nube si esa cuenta ya tenía progreso en
  /// otro teléfono. El nombre ya viene de la cuenta de Google, no
  /// se escribe a mano; el nombre de usuario se pone DESPUÉS, en
  /// el perfil ("¡Completa tu perfil!", Kristian 2026-11-16: la
  /// pantalla de elegir usuario salió del registro).
  ///
  /// Tras enlazar NO se entra directo (Quemia 7.5, Kristian): se
  /// abre el flujo corto de Google — 1) "Ya has iniciado sesión",
  /// 2) código de referido, 3) notificaciones — y de ahí a la
  /// pantalla principal. Así no hay que escribir el nombre ni
  /// darle a Siguiente, y el permiso de notificaciones no se salta.
  ///
  /// Error honesto (09:13): mientras se firma, el botón muestra
  /// carga y queda deshabilitado; si linkWithGoogle() devuelve
  /// false, sale UNA línea con el motivo (sin internet, o fallo al
  /// iniciar sesión) y la app sigue: sin excepciones sin atrapar y
  /// sin quedarse en carga. linkWithGoogle() nunca lanza.
  var _googleBusy = false;
  String? _googleError;

  /// Flujo corto de Google (Quemia 7.5): true tras enlazar con
  /// Google; la pantalla pasa a ser [_GoogleOnboardingFlow].
  var _googleFlow = false;
  String _googleName = '';
  String? _googleEmail;

  Future<void> _linkGoogle() async {
    if (_googleBusy) return;
    // Si se enlaza desde la pantalla de entrar (no desde el
    // registro), el flujo corto de Google salta al final a las
    // preguntas (Kristian 2026-11-13: entrar pide lo mismo que
    // registrarse).
    _googleFromSignIn = _signInFlow;
    setState(() {
      _googleBusy = true;
      _googleError = null;
    });
    final ok = await AuthService.linkWithGoogle();
    if (!mounted) return;
    if (!ok) {
      // Quemia 7.3: el CÓDIGO real del fallo, para diagnosticar por
      // qué ni siquiera salió el selector (p. ej.
      // google_sign_in:unknownError = error 10 DEVELOPER_ERROR).
      final code = AuthService.lastGoogleError;
      setState(() {
        _googleBusy = false;
        _googleError = AnalyticsSync.firebaseReady
            ? (code == null
                ? tr('googleSignInFailed')
                : '${tr('googleSignInFailed')} [$code]')
            : tr('googleNeedInternet');
      });
      return;
    }
    // Enlazado: se abre el flujo corto de Google (Quemia 7.5,
    // Kristian): "Ya has iniciado sesión" → código de referido →
    // notificaciones → principal. El nombre es el de Google (o el
    // prefijo del correo si Google no dio nombre). El respaldo de
    // la nube se trae en segundo plano.
    final googleName = AuthService.googleDisplayName ?? '';
    final googleEmail = AuthService.googleEmail;
    final name = googleName.trim().isNotEmpty
        ? googleName.trim()
        : ReferralService.usernameBaseFromGoogle(null, googleEmail);
    // Crear contraseña (Kristian 2026-11-16): el OTP ya comprobó
    // que el correo es suyo; ahora Google confirma que la cuenta
    // es suya, porque Firebase solo deja ponerle contraseña a
    // quien tenga la sesión abierta como dueño. Si la cuenta de
    // Google elegida NO es la del correo tomado, se vuelve a la
    // pantalla de correo tomado con el aviso — nunca se le pone
    // la contraseña a otra cuenta.
    if (_googleForSetPassword) {
      _googleForSetPassword = false;
      final signedEmail = AuthService.accountEmail;
      if (signedEmail == null ||
          signedEmail.toLowerCase() != _emailTakenEmail.toLowerCase()) {
        if (mounted) {
          setState(() {
            _googleBusy = false;
            _setPasswordGoogleStep = false;
            _emailTakenFlow = true;
            _takenEmailNotice = tr('obSetPasswordGoogleMismatch')
                .replaceFirst('%s', _emailTakenEmail);
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _googleBusy = false;
          _setPasswordGoogleStep = false;
          _setPasswordEmail = signedEmail;
          _googleName = name;
          _googleEmail = googleEmail;
        });
      }
      unawaited(AnalyticsSync.restoreFromCloud().then((_) {}));
      return;
    }
    if (mounted) {
      setState(() {
        _googleBusy = false;
        _googleFlow = true;
        _googleName = name;
        _googleEmail = googleEmail;
      });
    }
    unawaited(AnalyticsSync.restoreFromCloud().then((_) {}));
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _pageController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingScreen();
    // Idioma (Quemia 7.7, Kristian 2026-11-13): ya NO se pide al
    // instalar; la app coge el idioma del sistema del teléfono
    // (ver AppLang.load) y solo se cambia después en Ajustes →
    // Idioma. El onboarding empieza directo en la Bienvenida.
    // Flujo corto de Google (Quemia 7.5): tras enlazar, la
    // pantalla pasa a ser el flujo "Ya has iniciado sesión" →
    // código de referido → notificaciones → principal.
    if (_googleFlow) {
      return _GoogleOnboardingFlow(
        name: _googleName,
        email: _googleEmail,
        fromSignIn: _googleFromSignIn,
        onFinish: (name) async {
          await UserPrefs.saveProfile(name);
          // Entrar con Google (Kristian 2026-11-15): tras
          // "Ya has iniciado sesión" va directo a la principal,
          // sin preguntas. Las preguntas quedan solo en crear
          // cuenta.
          await _finishWithLoading();
        },
      );
    }
    // Inicio de sesión (Quemia 7.7, Kristian 2026-11-13: la
    // pantalla de Duolingo "Ingresa tus datos"): correo +
    // contraseña, "¿Has olvidado tu contraseña?" y Google.
    if (_signInFlow) {
      return _SignInPage(
        onGoogleSignIn: _linkGoogle,
        googleBusy: _googleBusy,
        googleError: _googleError,
        initialEmail: _signInEmail,
        onBack: () async {
          setState(() => _signInFlow = false);
          // Al volver, el PageView se remonta desde initialPage:
          // saltar de vuelta a la elección para no perder la página.
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_page);
          }
        },
        onSignedIn: () async {
          // Tras entrar, el perfil local: el nombre de Google si
          // lo hay; si no, el nombre de usuario del correo (así
          // se creó en el registro). El progreso de la nube se
          // trae en segundo plano.
          final display = AuthService.googleDisplayName;
          final email = AuthService.accountEmail;
          final name = (display != null && display.trim().isNotEmpty)
              ? display.trim()
              : (email != null
                  ? ReferralService.usernameBaseFromGoogle(null, email)
                  : '');
          if (name.isNotEmpty) await UserPrefs.saveProfile(name);
          unawaited(AnalyticsSync.restoreFromCloud().then((_) {}));
          // Entrar con la cuenta (Kristian 2026-11-15): va
          // directo a la principal, sin preguntas. Las preguntas
          // quedan solo en crear cuenta.
          await _finishWithLoading();
        },
      );
    }
    // Registro con correo (Quemia 7.7, Kristian 2026-11-13: las
    // pantallas de Duolingo por correo): correo → contraseña →
    // nombre → código OTP.
    if (_emailFlow) {
      return _EmailOnboardingFlow(
        onBack: () async {
          setState(() => _emailFlow = false);
          // Al volver, el PageView se remonta desde initialPage:
          // saltar de vuelta al registro para no perder la página.
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_page);
          }
        },
        onVerified: _registerWithEmail,
        onEmailTaken: (email, hasPassword) {
          setState(() {
            _emailFlow = false;
            _emailTakenEmail = email;
            _emailTakenHasPassword = hasPassword;
            _takenEmailNotice = null;
            _emailTakenFlow = true;
          });
        },
      );
    }
    // Ponerle una contraseña al correo tomado (Kristian
    // 2026-11-16): OTP → entrar con Google → CREA TU
    // CONTRASEÑA dentro de la app. Sin correo de restablecer.
    if (_setPasswordOtpEmail != null) {
      final email = _setPasswordOtpEmail!;
      return OtpCodePage(
        email: email,
        purpose: OtpPurpose.setPassword,
        title: tr('obSetPasswordOtpTitle'),
        body: tr('obSetPasswordOtpBody'),
        onBack: () {
          setState(() {
            _setPasswordOtpEmail = null;
            _emailTakenFlow = true;
          });
        },
        onVerified: () async {
          setState(() {
            _setPasswordOtpEmail = null;
            _setPasswordGoogleStep = true;
          });
        },
      );
    }
    if (_setPasswordGoogleStep) {
      return _SetPasswordGoogleStep(
        email: _emailTakenEmail,
        busy: _googleBusy,
        error: _googleError,
        onBack: () {
          _googleForSetPassword = false;
          setState(() {
            _setPasswordGoogleStep = false;
            _emailTakenFlow = true;
          });
        },
        onGoogle: () async {
          _googleForSetPassword = true;
          await _linkGoogle();
        },
      );
    }
    if (_setPasswordEmail != null) {
      final email = _setPasswordEmail!;
      return SetPasswordPage(
        email: email,
        onBack: () {
          setState(() {
            _setPasswordEmail = null;
            _emailTakenFlow = true;
          });
        },
        onSaved: () async {
          // Contraseña puesta: seguir como si se hubiera entrado
          // con Google (flujo corto: "Ya has iniciado sesión" →
          // usuario → referido → notificaciones).
          setState(() {
            _setPasswordEmail = null;
            _googleFlow = true;
          });
        },
      );
    }
    // Correo ya tomado (Kristian 2026-11-15): pantalla entera, no
    // un cuadradito. Con contraseña ofrece entrar con el correo;
    // sin ella, entrar con Google o ponerle una contraseña.
    if (_emailTakenFlow) {
      return EmailTakenPage(
        email: _emailTakenEmail,
        hasPassword: _emailTakenHasPassword,
        notice: _takenEmailNotice,
        onBack: () async {
          setState(() {
            _emailTakenFlow = false;
            _takenEmailNotice = null;
          });
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_page);
          }
        },
        onSignIn: () {
          setState(() {
            _emailTakenFlow = false;
            _signInEmail = _emailTakenEmail;
            _signInFlow = true;
          });
        },
        onGoogle: () async {
          _googleForSetPassword = false;
          setState(() => _emailTakenFlow = false);
          await _linkGoogle();
        },
        onSetPassword: () {
          setState(() {
            _emailTakenFlow = false;
            _takenEmailNotice = null;
            _setPasswordOtpEmail = _emailTakenEmail;
          });
        },
      );
    }
    // Sin conexión (Quemia 7.7, Kristian 2026-11-13): solo el
    // nombre y la meta diaria, y directo a la principal.
    if (_offlineFlow) {
      return _OfflineFlow(
        onBack: () async {
          setState(() => _offlineFlow = false);
          // Al volver, el PageView se remonta desde initialPage:
          // saltar de vuelta a la elección para no perder la página.
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_page);
          }
        },
        onFinished: _finishWithLoading,
      );
    }
    // resizeToAvoidBottomInset: false para que, al abrirse el teclado,
    // el botón Siguiente se quede fijo abajo y no suba a tapar nada.
    // El contenido de cada página ya es desplazable, y la página del
    // perfil reserva abajo el alto del teclado para que nada quede tapado.
    // SIN barra de progreso arriba (Quemia 7.7, Kristian 2026-11-13):
    // el inicio es tarjeta de bienvenida → elección → flujo, sin
    // barra. La clase _ProgressBar se borró con su último uso.
    // Sin deslizar (Kristian 2026-11-15: el inicio solo cambia
    // con los botones, nunca deslizando): el PageView no admite
    // gestos; el atrás del teléfono vuelve un paso con PopScope.
    return PopScope(
      // Solo se sale de la app con el atrás en la Bienvenida de
      // la primera instalación: en el resto, el atrás vuelve un
      // paso dentro del inicio.
      canPop: !widget.fromAccount && _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Desde Cuenta, la elección es la primera pantalla: el
        // atrás vuelve a Cuenta, no a la Bienvenida.
        if (widget.fromAccount && _page <= 1) {
          widget.onCancel?.call();
          return;
        }
        if (_page > 0 && _pageController.hasClients) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    // Bienvenida (Quemia 7.7, Kristian): SIN botón de
                    // Google — lo de Google va en la pantalla de
                    // elección ("Entrar con mi cuenta"), no aquí.
                    // Las 3 explicaciones (Resolver, Estudiar,
                    // Practicar) las QUITÓ Kristian: ya no salen.
                    _WelcomePage(),
                    // Elección (Quemia 7.7, Kristian 2026-11-13,
                    // estilo Duolingo pero con Quemia): crear perfil,
                    // entrar con la cuenta o sin conexión. "Entrar
                    // con mi cuenta" abre el inicio de sesión
                    // ("Ingresa tus datos": correo+contraseña,
                    // olvidar contraseña por OTP y Google), no
                    // enlaza con Google directo.
                    _ChoicePage(
                      onStart: _next,
                      onSignIn: () => setState(() => _signInFlow = true),
                      onOffline: () => setState(() => _offlineFlow = true),
                      showOffline: !widget.fromAccount,
                      onBack: widget.onCancel,
                    ),
                    // La gemela que se presenta (Quemia 7.7, Kristian
                    // 2026-11-13, vídeo de Duolingo): Brenda se
                    // presenta en su bocadillo; atrás vuelve a la
                    // elección y "Vamos" sigue a las preguntas.
                    _MascotIntroPage(
                      onBack: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      onVamos: _next,
                    ),
                    // Crear cuenta (Quemia 7.7, Kristian 2026-11-13,
                    // flujo de Duolingo con contenido de Quemia): 3)
                    // "¿Cómo supiste de Quemia?" — sin la pantalla
                    // de elegir idioma de Duolingo, que no va.
                    _SourcePage(
                      selected: _source,
                      onSelected: (v) => setState(() => _source = v),
                      onConfirm: _confirmSource,
                    ),
                    // 4) "¿Cuánta química sabes?" (en vez de "¿Cuánto
                    // inglés sabes?"): 5 niveles con barritas.
                    _LevelPage(
                      selected: _level,
                      onSelected: (v) => setState(() => _level = v),
                      onConfirm: _confirmLevel,
                    ),
                    // 5) Meta diaria (3/10/15/30 min): Quemia tiene
                    // racha y días de práctica, así que encaja.
                    _GoalPage(
                      selected: _goalMinutes,
                      onSelected: (v) => setState(() => _goalMinutes = v),
                      onConfirm: _confirmGoal,
                    ),
                    // 6) Permiso de notificaciones: la MISMA página
                    // del onboarding (no otra inventada). Aquí NO
                    // termina el flujo: al continuar va a la racha.
                    OnboardingNotificationsPage(onNext: _next),
                    // 7) "¡Una nueva racha!": 1 día, la semana con
                    // hoy marcado. Sin edad (Duolingo pide la edad;
                    // Quemia no la pide).
                    _StreakPage(onNext: _next),
                    // 8) Aviso antes del registro (Quemia 7.7,
                    // Kristian 2026-11-13, la pantalla de Duolingo
                    // "¡No pierdas tu progreso! Vamos a crear tu
                    // perfil."): Brenda con su bocadillo y
                    // CONTINUAR. Con flecha atrás (Kristian
                    // 2026-11-15: sin deslizar, también vuelve con
                    // botón): vuelve a la racha.
                    _ProfileNudgePage(
                      onBack: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      onNext: _next,
                    ),
                    // 9) Registro (Quemia 7.7, Kristian 2026-11-13,
                    // como la pantalla de Duolingo: "Elige una opción
                    // para registrarte y continuar" — Google y correo,
                    // sin pedir nombre ni género. El nombre de usuario
                    // se coge del correo).
                    _RegisterPage(
                      onGoogleSignIn: _linkGoogle,
                      googleBusy: _googleBusy,
                      googleError: _googleError,
                      onEmail: () => setState(() => _emailFlow = true),
                      onBack: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                    ),
                    // Código de referido (Quemia 7.6, Kristian):
                    // PÁGINA APARTE, después del registro. Como la de
                    // canjear de la app de Muse (regalo + 6
                    // casillas). Opcional: se puede seguir con las
                    // casillas vacías. Es la ÚLTIMA página (Quemia
                    // 7.7): su botón termina el onboarding (guarda
                    // el perfil) y se entra a la principal ya con
                    // la cuenta puesta.
                    _ReferralPage(
                      referralController: _referralController,
                      onNext: _finish,
                    ),
                  ],
                ),
              ),
              // Botón fijado abajo (diseño Duolingo §1.4): sólido teal
              // + labio. Solo en la Bienvenida ("Continuar"): la
              // Elección, la gemela, el registro y las demás tienen
              // sus propios botones. Entra deslizándose desde abajo
              // con opacidad (animación simple, como el botón del
              // vídeo de Duolingo).
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: _page == 0
                    ? FadeSlideIn(
                        key: const ValueKey('onb-bottom-0'),
                        child: SizedBox(
                          width: double.infinity,
                          child: DuoButton.primary(
                            label: tr('obContinue').toUpperCase(),
                            onPressed: _next,
                            fontSize: 17,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Flujo corto tras enlazar con Google (Quemia 7.5, Kristian):
/// 1) "Ya has iniciado sesión" (la cuenta de Google),
/// 2) código de referido (página aparte, Quemia 7.6),
/// 3) notificaciones,
/// y de ahí a la pantalla principal. El nombre de usuario se coge
/// del correo (primer nombre, sin apellido — Kristian 2026-11-13)
/// y se reclama solo; NO se pregunta el nombre ni el género.
/// Al terminar, [onFinish] guarda el perfil y entra a la app.
class _GoogleOnboardingFlow extends StatefulWidget {
  const _GoogleOnboardingFlow({
    required this.name,
    required this.email,
    required this.onFinish,
    this.fromSignIn = false,
  });

  final String name;
  final String? email;
  final Future<void> Function(String name) onFinish;

  /// Entra con Google desde la pantalla de entrar (no desde el
  /// registro): tras "Ya has iniciado sesión" NO pide referido ni
  /// notificaciones — eso lo hacen las preguntas 3–6 del inicio
  /// (Kristian 2026-11-13: entrar pide lo mismo que registrarse).
  final bool fromSignIn;

  @override
  State<_GoogleOnboardingFlow> createState() => _GoogleOnboardingFlowState();
}

class _GoogleOnboardingFlowState extends State<_GoogleOnboardingFlow> {
  /// 0 = "Ya has iniciado sesión", 1 = código de referido,
  /// 2 = notificaciones. (Kristian 2026-11-16: el paso de elegir
  /// nombre de usuario salió del registro; el nombre se pone
  /// después en el perfil.)
  var _step = 0;

  /// Código de referido (Quemia 7.6, Kristian): tiene su propia
  /// pantalla aparte, igual que en el onboarding normal.
  final _referralController = TextEditingController();

  /// Tras "Ya has iniciado sesión": desde entrar se va directo a
  /// la principal; desde registro, al referido (paso 1).
  void _afterSignedIn() {
    if (widget.fromSignIn) {
      unawaited(widget.onFinish(widget.name));
    } else {
      setState(() => _step = 1);
    }
  }

  @override
  void initState() {
    super.initState();
    // "Ya has iniciado sesión" avanza SOLO (Quemia 7.6, Kristian:
    // al iniciar sesión con Google, salta automáticamente): a los
    // ~1,5 s pasa al referido sin tocar nada. Si el
    // usuario ya avanzó (no debería), no se toca. Desde la
    // pantalla de entrar no hay referido: termina y el padre
    // lleva a las preguntas.
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted || _step != 0) return;
      _afterSignedIn();
    });
  }

  @override
  void dispose() {
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    // Sin reclamar nombre de usuario (Kristian 2026-11-16: la
    // pantalla de elegir usuario salió del registro; el nombre se
    // pone después en el perfil, con la tarjeta "¡Completa tu
    // perfil!").
    // Código de referido (Quemia 7.6): se guarda en local y se
    // canjea solo en segundo plano cuando hay conexión.
    await ReferralService.saveOnboardingCode(_referralController.text);
    unawaited(ReferralService.redeemOnboardingCode());
    await widget.onFinish(widget.name);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final sub =
        isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF6B7280);
    // El atrás del teléfono hace lo mismo que la flecha de
    // la pantalla (Kristian 2026-11-15: el atrás no sale
    // de la app en el inicio).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step > 0) setState(() => _step--);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              // SIN barra de progreso (Quemia 7.7, Kristian
              // 2026-11-13): el inicio no lleva barra arriba.
              Expanded(
                child: switch (_step) {
                  // 1) "Ya has iniciado sesión": la cuenta de Google.
                  0 => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: const BoxDecoration(
                                color: Color(0xFF14B8A6),
                                shape: BoxShape.circle,
                              ),
                              child: const LucideIcon(
                                LucideIcons.check,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            tr('obGoogleSignedIn'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          if (widget.email != null &&
                              widget.email!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.email!,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, color: sub),
                            ),
                          ],
                          const SizedBox(height: 32),
                          DuoButton.primary(
                            label: tr('obNext').toUpperCase(),
                            onPressed: _afterSignedIn,
                            fontSize: 17,
                          ),
                        ],
                      ),
                    ),
                  // 1) Código de referido: página aparte (regalo + 6
                  // casillas), como la de canjear de la app de Muse.
                  // Opcional: se puede saltar. Al continuar, a
                  // notificaciones.
                  1 => _ReferralPage(
                      referralController: _referralController,
                      onNext: () => setState(() => _step = 2),
                    ),
                  // 2) Notificaciones: la misma página del onboarding
                  // normal; al continuar se guarda el perfil y se
                  // entra a la app.
                  _ => OnboardingNotificationsPage(onNext: _finish),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla de elegir nombre de usuario (Kristian 2026-11-15:
/// vuelve tras haberse quitado el 2026-11-13; 2026-11-16 SALIÓ
/// del registro y ahora vive en el PERFIL, tras la tarjeta
/// "¡Completa tu perfil!"). Muestra el nombre sugerido (primer
/// nombre de la cuenta de Google o prefijo del correo, sin
/// apellido) con dos caminos claros: dejarlo como está
/// ("NO CAMBIAR") o escribir otro. Al escribir otro se comprueba
/// en vivo si está cogido ([isTaken]); si lo está, salen
/// sugerencias parecidas disponibles ([suggest]) para tocar una.
/// Solo al confirmar se reclama el nombre (lo hace [onConfirm],
/// con [ReferralService.claimUsername]); sin internet se guarda en
/// local y se reclama después, como siempre. El inicio de sesión
/// ("Ya tengo una cuenta") NO pasa por aquí: esos usuarios ya
/// tienen nombre.
///
/// Modo perfil ([prefillField] = true, "Personaliza tu nombre de
/// usuario"): el campo ya trae el sugerido escrito, no se enseña
/// el bloque del sugerido ni el botón NO CAMBIAR (el campo ES la
/// elección), y con [onSkip] sale el enlace "QUIZÁ MÁS TARDE" y
/// con [onBack] la flecha para volver.
class UsernameChoicePage extends StatefulWidget {
  const UsernameChoicePage({
    super.key,
    required this.base,
    required this.onConfirm,
    this.isTaken,
    this.suggest,
    this.titleText,
    this.bodyText,
    this.prefillField = false,
    this.onSkip,
    this.onBack,
  });

  /// Nombre sugerido (ya limpio, sin apellido).
  final String base;

  /// Se llama SOLO al confirmar, con el nombre elegido.
  final Future<void> Function(String chosen) onConfirm;

  /// Comprueba si un nombre está cogido (por defecto
  /// [ReferralService.isUsernameTaken]). Inyectable en tests.
  final Future<bool> Function(String candidate)? isTaken;

  /// Sugerencias parecidas disponibles (por defecto
  /// [ReferralService.suggestUsernames]). Inyectable en tests.
  final Future<List<String>> Function(String base)? suggest;

  /// Título propio (por defecto el del registro). En el perfil:
  /// "Personaliza tu nombre de usuario".
  final String? titleText;

  /// Texto propio bajo el título (por defecto el del registro).
  final String? bodyText;

  /// true en el perfil: el campo trae el sugerido ya escrito y
  /// no se enseña el bloque del sugerido ni NO CAMBIAR.
  final bool prefillField;

  /// Si se pasa, sale el enlace "QUIZÁ MÁS TARDE" al final.
  final VoidCallback? onSkip;

  /// Si se pasa, sale la flecha de atrás y el atrás del teléfono
  /// vuelve (si no, la pantalla no se puede cerrar sin elegir).
  final VoidCallback? onBack;

  @override
  State<UsernameChoicePage> createState() => _UsernameChoicePageState();
}

class _UsernameChoicePageState extends State<UsernameChoicePage> {
  final _customController = TextEditingController();
  Timer? _debounce;

  /// ¿Está cogido el nombre sugerido? null = aún comprobando.
  bool? _baseTaken;

  /// Estado del nombre escrito: null = vacío/sin comprobar,
  /// true = libre, false = cogido.
  bool? _customFree;

  /// ¿Se está comprobando el nombre escrito ahora mismo?
  var _checkingCustom = false;

  /// Sugerencias para el nombre que está cogido (base o escrito).
  var _suggestions = <String>[];

  /// Confirmando (reclamando el nombre).
  var _busy = false;

  static String _clean(String value) {
    final clean = value.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9]'), '');
    return clean.length > 20 ? clean.substring(0, 20) : clean;
  }

  @override
  void initState() {
    super.initState();
    // En el perfil el campo ya trae el sugerido escrito (el
    // usuario lo edita si quiere); la comprobación del sugerido
    // dirá si ese nombre está libre o cogido.
    if (widget.prefillField) {
      _customController.text = widget.base;
    }
    // El sugerido también se comprueba: si está cogido, "NO
    // CAMBIAR" no se puede usar y salen las sugerencias.
    unawaited(_checkBase());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _customController.dispose();
    super.dispose();
  }

  Future<bool> _isTaken(String candidate) async {
    final check = widget.isTaken ?? ReferralService.isUsernameTaken;
    try {
      return await check(candidate);
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> _suggest(String base) async {
    final suggest = widget.suggest ?? ReferralService.suggestUsernames;
    try {
      return await suggest(base);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _checkBase() async {
    final taken = await _isTaken(widget.base);
    if (!mounted) return;
    List<String> suggestions = const [];
    if (taken) suggestions = await _suggest(widget.base);
    if (!mounted) return;
    setState(() {
      _baseTaken = taken;
      if (taken) _suggestions = suggestions;
      // En el perfil el campo trae el sugerido: su estado libre /
      // cogido es el del campo (el botón de guardar se activa con
      // él). Si el usuario ya escribió otra cosa, no se toca.
      if (widget.prefillField &&
          _clean(_customController.text) == _clean(widget.base)) {
        _customFree = !taken;
        _checkingCustom = false;
      }
    });
  }

  void _onCustomChanged(String value) {
    final clean = _clean(value);
    _debounce?.cancel();
    if (clean.isEmpty) {
      _customFree = null;
      _checkingCustom = false;
      _suggestions = const [];
      return;
    }
    // En pruebas no hay temporizador: pumpAndSettle no termina
    // nunca con un Timer vivo (igual que el reenvío del OTP).
    if (isFlutterTest) {
      unawaited(_checkCustom(clean));
      return;
    }
    _checkingCustom = true;
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_checkCustom(clean));
    });
  }

  Future<void> _checkCustom(String clean) async {
    final taken = await _isTaken(clean);
    if (!mounted) return;
    // Si mientras tanto se borró el campo o se escribió otro
    // nombre, este resultado ya no vale.
    if (_clean(_customController.text) != clean) return;
    List<String> suggestions = const [];
    if (taken) suggestions = await _suggest(clean);
    if (!mounted) return;
    if (_clean(_customController.text) != clean) return;
    setState(() {
      _checkingCustom = false;
      _customFree = !taken;
      _suggestions = suggestions;
    });
  }

  Future<void> _confirm(String chosen) async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onConfirm(chosen);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final sub =
        isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF6B7280);
    final okColor = isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F9D58);
    final errorColor = const Color(0xFFFF4B4B);
    final customClean = _clean(_customController.text);
    final baseFree = _baseTaken == false;
    return PopScope(
      // En el perfil se puede volver con el atrás del teléfono
      // (onBack); en el registro no se salía sin elegir.
      canPop: widget.onBack != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              32,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.onBack != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const LucideIcon(LucideIcons.arrowLeft),
                      tooltip: tr('closeWord'),
                      onPressed: widget.onBack,
                    ),
                  ),
                Text(
                  widget.titleText ?? tr('obUsernameTitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.bodyText ?? tr('obUsernameBody'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.4, color: sub),
                ),
                // En el perfil el campo ya trae el sugerido: no se
                // enseña el bloque del sugerido ni NO CAMBIAR.
                if (!widget.prefillField) ...[
                  const SizedBox(height: 24),
                  Text(
                    tr('obUsernameSuggested'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: sub),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.base,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_baseTaken == true) ...[
                    Text(
                      tr('obUsernameTaken'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: errorColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SuggestionChips(
                      suggestions: _suggestions,
                      onPick: _confirm,
                      busy: _busy,
                    ),
                  ] else if (baseFree) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LucideIcon(
                          LucideIcons.check,
                          size: 20,
                          color: okColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tr('obUsernameFree'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: okColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  DuoButton.primary(
                    label: tr('obUsernameKeep').toUpperCase(),
                    onPressed:
                        baseFree && !_busy ? () => _confirm(widget.base) : null,
                    fontSize: 17,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr('obUsernameOrWrite'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  const SizedBox(height: 24),
                ],
                QuemiaField(
                  controller: _customController,
                  hint: tr('obUsernameHint'),
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.done,
                  onChanged: (v) => setState(() => _onCustomChanged(v)),
                ),
                const SizedBox(height: 12),
                if (_checkingCustom)
                  Text(
                    tr('obUsernameChecking'),
                    style: TextStyle(fontSize: 15, color: sub),
                  )
                else if (_customFree == true)
                  Row(
                    children: [
                      LucideIcon(
                        LucideIcons.check,
                        size: 20,
                        color: okColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tr('obUsernameFree'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: okColor,
                        ),
                      ),
                    ],
                  )
                else if (_customFree == false) ...[
                  Text(
                    tr('obUsernameTaken'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: errorColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SuggestionChips(
                    suggestions: _suggestions,
                    onPick: _confirm,
                    busy: _busy,
                  ),
                ],
                const SizedBox(height: 16),
                DuoButton.secondary(
                  label: tr('obUsernameUseThis').toUpperCase(),
                  onPressed: _customFree == true && !_busy
                      ? () => _confirm(customClean)
                      : null,
                  fontSize: 17,
                ),
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ],
                // En el perfil se puede saltar ("QUIZÁ MÁS TARDE"):
                // la tarjeta de completar perfil seguirá ahí hasta
                // que ponga su nombre.
                if (widget.onSkip != null) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: widget.onSkip,
                      child: Text(
                        tr('usernameSkip').toUpperCase(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: sub,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla de correo ya tomado (Quemia 7.7, Kristian 2026-11-15):
/// PANTALLA ENTERA, no un cuadradito. Antes de mostrarse, el padre
/// ya comprobó en el índice de correos si la cuenta tiene
/// contraseña:
///   - con contraseña (o sin saberlo): entrar con el correo o con
///     Google; NUNCA se ofrece ponerle una contraseña, porque sería
///     pedirlo de nuevo;
///   - sin contraseña: entrar con Google o ponerle una contraseña
///     (enlace de Firebase, como antes).
/// Sale tanto desde la comprobación temprana (antes de la
/// contraseña) como desde el fallo tardío del enlace (red de
/// seguridad). "Ponerle una contraseña" manda el enlace y se queda
/// en la pantalla con la confirmación.
class EmailTakenPage extends StatefulWidget {
  const EmailTakenPage({
    super.key,
    required this.email,
    required this.hasPassword,
    this.notice,
    required this.onBack,
    required this.onSignIn,
    required this.onGoogle,
    required this.onSetPassword,
  });

  /// El correo que ya tiene cuenta.
  final String email;

  /// ¿Tiene contraseña la cuenta? null = no se sabe.
  final bool? hasPassword;

  /// Aviso bajo el texto (p. ej. la cuenta de Google elegida no
  /// era la de este correo). null = sin aviso.
  final String? notice;

  /// Volver al registro.
  final VoidCallback onBack;

  /// Entrar con el correo (abre el inicio de sesión con el correo
  /// ya puesto).
  final VoidCallback onSignIn;

  /// Entrar con Google.
  final Future<void> Function() onGoogle;

  /// Ponerle una contraseña: OTP → Google → CREA TU CONTRASEÑA
  /// dentro de la app (Kristian 2026-11-16). SIN el correo de
  /// restablecer de Firebase: ese enlace ya no se manda en este
  /// flujo. Solo se ofrece cuando la cuenta NO tiene contraseña.
  final VoidCallback onSetPassword;

  @override
  State<EmailTakenPage> createState() => _EmailTakenPageState();
}

class _EmailTakenPageState extends State<EmailTakenPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final sub =
        isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF6B7280);
    final body = switch (widget.hasPassword) {
      true => tr('obTakenHasPasswordBody'),
      false => tr('obTakenNoPasswordBody'),
      null => tr('obTakenUnknownBody'),
    };
    // Con contraseña (o sin saberlo): entrar, nunca ponerle una.
    final withPassword = widget.hasPassword != false;
    return PopScope(
      canPop: false,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: widget.onBack,
                    icon: const LucideIcon(LucideIcons.arrowLeft, size: 28),
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('obTakenTitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.4, color: sub),
                ),
                if (widget.notice != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.notice!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF4B4B),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (withPassword) ...[
                  DuoButton.primary(
                    label: tr('obTakenSignIn').toUpperCase(),
                    onPressed: widget.onSignIn,
                    fontSize: 17,
                  ),
                  const SizedBox(height: 16),
                  DuoButton.secondary(
                    label: tr('obEmailTakenGoogle').toUpperCase(),
                    onPressed: () => widget.onGoogle(),
                    fontSize: 17,
                  ),
                ] else ...[
                  DuoButton.primary(
                    label: tr('obEmailTakenGoogle').toUpperCase(),
                    onPressed: () => widget.onGoogle(),
                    fontSize: 17,
                  ),
                  const SizedBox(height: 16),
                  DuoButton.secondary(
                    label: tr('obTakenSetPassword').toUpperCase(),
                    onPressed: widget.onSetPassword,
                    fontSize: 17,
                  ),
                ],
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: widget.onBack,
                    child: Text(
                      tr('obBack'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paso "entra con Google" del flujo de crear contraseña
/// (Kristian 2026-11-16): el OTP ya comprobó que el correo es
/// suyo; ahora Google confirma que la cuenta es suya, porque
/// Firebase solo deja ponerle contraseña a quien tenga la sesión
/// abierta como dueño. El botón es el mismo ENTRAR CON GOOGLE
/// de la pantalla de correo tomado.
class _SetPasswordGoogleStep extends StatelessWidget {
  const _SetPasswordGoogleStep({
    required this.email,
    required this.busy,
    required this.error,
    required this.onBack,
    required this.onGoogle,
  });

  /// Correo tomado al que se le va a poner la contraseña.
  final String email;

  /// true mientras el enlace con Google está en marcha.
  final bool busy;

  /// Error del enlace con Google (null = sin error).
  final String? error;

  /// Volver a la pantalla de correo tomado.
  final VoidCallback onBack;

  /// Entrar con Google con esa misma cuenta.
  final Future<void> Function() onGoogle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final sub =
        isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF6B7280);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onBack();
      },
      child: Scaffold(
        key: const ValueKey('setPasswordGoogleStep'),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const LucideIcon(LucideIcons.arrowLeft, size: 28),
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('obSetPasswordGoogleTitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr('obSetPasswordGoogleBody').replaceFirst('%s', email),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.4, color: sub),
                ),
                const SizedBox(height: 24),
                DuoButton.primary(
                  label: tr('obEmailTakenGoogle').toUpperCase(),
                  onPressed: busy ? null : onGoogle,
                  fontSize: 17,
                ),
                if (busy) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sugerencias de nombre de usuario parecidas al que está cogido:
/// una por línea, como botones secundarios. Tocar una la confirma
/// directamente (ya se comprobó que está libre).
class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({
    required this.suggestions,
    required this.onPick,
    required this.busy,
  });

  final List<String> suggestions;
  final Future<void> Function(String chosen) onPick;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final suggestion in suggestions) ...[
          DuoButton.secondary(
            label: suggestion,
            onPressed: busy ? null : () => onPick(suggestion),
            fontSize: 17,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Pantalla del código de referido (Quemia 7.6, Kristian): PÁGINA
/// APARTE en el onboarding, después del registro y antes de
/// notificaciones — como la de canjear de la app de Muse (regalo +
/// 6 casillas + botón). El código es OPCIONAL: se puede seguir con
/// las casillas vacías ("Saltar"). Se escribe en
/// [referralController] y se guarda en local al terminar el
/// onboarding ([_OnboardingScreenState._finish] /
/// [_GoogleOnboardingFlowState._finish]); se canjea solo cuando hay
/// conexión. Se usa en el onboarding normal (página 9) y en el
/// flujo de Google (paso 1).

class _ReferralPage extends StatefulWidget {
  const _ReferralPage({
    required this.referralController,
    required this.onNext,
  });

  final TextEditingController referralController;
  final VoidCallback onNext;

  @override
  State<_ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<_ReferralPage> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    // Si vuelve atrás, las casillas ya traen el código escrito.
    final code = widget.referralController.text;
    for (var i = 0; i < 6; i++) {
      if (i < code.length) _controllers[i].text = code[i];
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onBoxChanged(int index, String value) {
    final clean = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean != value) {
      _controllers[index].value = TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
    }
    // El código vive en el controlador compartido: al terminar el
    // onboarding se guarda en local y se canjea solo.
    widget.referralController.text = _code;
    if (clean.length == 1 && index < 5) {
      _nodes[index + 1].requestFocus();
    } else if (clean.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
  }

  void _skip() {
    widget.referralController.clear();
    for (final c in _controllers) {
      c.clear();
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final sub =
        isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF6B7280);
    final boxBorder =
        isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE5E5E5);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Regalo en círculo teal claro (como la de canjear).
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppAccent.primary.withValues(alpha: 0.14),
              ),
              alignment: Alignment.center,
              child: LucideIcon(
                LucideIcons.gift,
                size: 56,
                color: AppAccent.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr('obReferralTitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('obReferralBody'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.4, color: sub),
          ),
          const SizedBox(height: 24),
          // Las 6 casillas (como la de canjear de la app de Muse).
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 6; i++)
                SizedBox(
                  width: 48,
                  height: 56,
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _nodes[i],
                    textAlign: TextAlign.center,
                    cursorHeight: 28,
                    textAlignVertical: TextAlignVertical.center,
                    textCapitalization: TextCapitalization.characters,
                    keyboardType: TextInputType.text,
                    maxLength: 1,
                    buildCounter: (context,
                            {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        null,
                    onChanged: (v) => _onBoxChanged(i, v),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppAccent.primary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: isDark ? AppAccent.darkCard : Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: boxBorder, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: AppAccent.primary, width: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          DuoButton.primary(
            label: tr('obNext').toUpperCase(),
            onPressed: widget.onNext,
            fontSize: 17,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _skip,
            child: Text(
              tr('obReferralSkip'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: sub,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      // Entrada suave al abrir la app (animación simple, como el
      // vídeo de Duolingo): el logo y los textos aparecen con un
      // fundido + subida, sin retrasar nada.
      child: FadeSlideIn(
        duration: const Duration(milliseconds: 450),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Orden (Kristian 2026-11-14: "que diga Bienvenidos,
            // abajo Químic@, y después viene la animación y luego
            // lo de tu app de química"): título, Químic@,
            // animación y por último el texto.
            Text(
              tr('obWelcome'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 46, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              tr('obChemist'),
              textAlign: TextAlign.center,
              // Quemia 7.3 (P12): el título seguía en menta fijo con el
              // tema violeta; ahora sigue al acento elegido. En claro
              // va el tono oscuro del acento (contraste 3,2 en verde);
              // en oscuro el acento (el tono oscuro sería ilegible
              // sobre oscuro en violeta: violetDeep da 2,4:1).
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppAccent.primary
                    : AppAccent.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            // Matraces de ciencia (Lottie, Kristian 2026-11-14:
            // la animación "science" de LottieFiles). SIN tarjeta
            // blanca detrás: Kristian 2026-11-14: en el fondo
            // oscuro no quiere la animación con el fondo blanco.
            // La animación solo usa azules y teal (sin rellenos
            // blancos), así que se lee bien directo sobre el fondo
            // en los dos temas.
            Lottie.asset(
              'assets/science.json',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
              repeat: true,
              animate: !isFlutterTest,
            ),
            const SizedBox(height: 20),
            Text(
              tr('obWelcomeBody'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla de elección (Quemia 7.7, Kristian 2026-11-13): tras la
/// Bienvenida, la app pregunta cómo entrar — estilo Duolingo (las
/// gemelas arriba, título y botones grandes), pero con la identidad
/// de Quemia y textos propios (NO es una copia de la pantalla de
/// Duolingo: ni el búho, ni "EMPIEZA AHORA", ni "YA TENGO UNA
/// CUENTA"). Tres caminos: crear perfil (sin Google), entrar con
/// la cuenta (Google) o sin conexión (directo a la principal).
class _ChoicePage extends StatelessWidget {
  const _ChoicePage({
    required this.onStart,
    required this.onSignIn,
    required this.onOffline,
    this.showOffline = true,
    this.onBack,
  });

  final VoidCallback onStart;

  /// "Entrar con mi cuenta": abre el inicio de sesión (la pantalla
  /// "Ingresa tus datos": correo+contraseña, olvidar contraseña
  /// por OTP y Google). Inyectable para probar la página.
  final VoidCallback onSignIn;

  final VoidCallback onOffline;

  /// "Sin conexión" solo en la primera instalación. Desde Cuenta
  /// (fromAccount) no tiene sentido (ya está sin conexión): en su
  /// lugar sale "Volver" ([onBack]).
  final bool showOffline;

  /// Volver (solo desde Cuenta): cierra el flujo y vuelve a Cuenta.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final subtitleColor = isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : const Color(0xFF777777);
    // Azul de Britany (sistema de color Duolingo, colores de
    // Quemia): el botón secundario ("Entrar con mi cuenta") va en
    // azul, el primario ("Crear mi perfil") en teal. En oscuro el
    // azul se aclara para leerse sobre el botón oscuro.
    const blue = Color(0xFF3B82F6);
    const blueLight = Color(0xFF60A5FA);
    // Los botones van ABAJO (Quemia 7.7, Kristian 2026-11-13,
    // como Duolingo): el título arriba, la animación en el
    // centro ocupando el espacio libre (Expanded) y los 3 botones
    // pegados al fondo, como en la Racha y en la Presentación de
    // Brenda. Antes las gemelas iban arriba en 90 dp y quedaba un
    // hueco vacío enorme en el medio (Kristian 2026-11-13: "yo le
    // veo un hueco muy vacío al principio. Guíate más por
    // Duolingo").
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FadeSlideIn(
            child: Text(
              tr('obChoiceTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, color: ink),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: Text(
              tr('obChoiceBody'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4, color: subtitleColor),
            ),
          ),
          Expanded(
            child: Center(
              // Animación Lottie de contraseña segura (Kristian
              // 2026-11-14: "para la parte de cómo quieres
              // empezar pon esto en vez de las dos mellizas"):
              // candado amarillo + escudo verde + la barra azul
              // donde van apareciendo los asteriscos de la
              // contraseña, en bucle. En pruebas queda quieta en
              // el primer cuadro para que pumpAndSettle no se
              // quede esperando al bucle infinito.
              child: Lottie.asset(
                'assets/pin_code.json',
                width: 280,
                height: 280,
                fit: BoxFit.contain,
                repeat: true,
                animate: !isFlutterTest,
              ),
            ),
          ),
          // 1) Empezar ahora: crear perfil (sin Google). Botón
          // primario teal (acción principal).
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: SizedBox(
              width: double.infinity,
              child: DuoButton.primary(
                label: tr('obCreateProfile').toUpperCase(),
                onPressed: onStart,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 2) Ya tengo cuenta: entrar (inicio de sesión). Botón
          // secundario AZUL (Britany): el secundario va en azul,
          // como en Duolingo, pero con el azul de Quemia. Mismo
          // patrón que el del Perfil (etiqueta vacía + fila [G +
          // texto] superpuesta, para que la G quede pegada al
          // texto en cualquier ancho). Abre "Ingresa tus datos"
          // (correo+contraseña, olvidar contraseña y Google):
          // el enlace con Google se hace DENTRO de esa pantalla.
          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: SizedBox(
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: DuoButton.secondary(
                      label: '',
                      onPressed: onSignIn,
                      textColor: blue,
                      edgeColor: const Color(0xFFBFDBFE),
                      fontSize: 17,
                    ),
                  ),
                  IgnorePointer(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const GoogleGIcon(size: 24),
                        const SizedBox(width: 8),
                        // El texto varía por idioma ("Me connecter à mon
                        // compte" en francés es más largo): sin
                        // Flexible + FittedBox desbordaba 72 px a la
                        // derecha en 360. Así se achica en vez de salirse.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              tr('obEnterAccount'),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: isDark ? blueLight : blue,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 3) Invitado TAMBIÉN en botón (Quemia 7.7, Kristian
          // 2026-11-13, como Duolingo: las 3 opciones son botones
          // abajo, no un enlace de texto). Botón neutro (secundario
          // gris): el primario es teal y el de Google azul; este no
          // lleva color de acción. Desde Cuenta es "Volver" (ya está
          // dentro y puede cambiar de idea).
          FadeSlideIn(
            delay: const Duration(milliseconds: 280),
            child: SizedBox(
              width: double.infinity,
              child: DuoButton.secondary(
                label: (showOffline ? tr('obOffline') : tr('obBack'))
                    .toUpperCase(),
                onPressed: showOffline ? onOffline : onBack,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La gemela que se presenta (Quemia 7.7, Kristian 2026-11-13,
/// vídeo de Duolingo): como la pantalla del búho — flecha atrás
/// arriba, la mascota en el centro con su bocadillo y un botón
/// grande abajo — pero con Brenda (no el búho) y textos propios.
/// "Vamos" sigue al perfil; la flecha vuelve a la elección.
class _MascotIntroPage extends StatelessWidget {
  const _MascotIntroPage({required this.onBack, required this.onVamos});

  final VoidCallback onBack;
  final VoidCallback onVamos;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final bubbleBg = isDark ? AppAccent.darkCard : Colors.white;
    final bubbleBorder =
        isDark ? AppAccent.darkBorder : const Color(0xFFE5E5E5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Flecha atrás arriba a la izquierda: vuelve a la elección.
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: LucideIcon(LucideIcons.arrowLeft, color: ink),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Chica saludando en bucle (Lottie, Kristian
                // 2026-11-14: "para el hola soy Brenda pon esto"):
                // la animación "girl-hi-or-wave" de LottieFiles en
                // vez de la foto de Brenda. En pruebas queda quieta
                // en el primer cuadro para que pumpAndSettle no se
                // quede esperando al bucle infinito.
                Lottie.asset(
                  'assets/girl_wave.json',
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: !isFlutterTest,
                ),
                const SizedBox(height: 20),
                // Bocadillo con la cola hacia Brenda: un cuadrado
                // girado 45° en el borde superior — la mitad de
                // dentro se funde con el bocadillo y la de fuera
                // se ve como un triangulito apuntando a ella.
                // Aparece con un pop suave (escala + opacidad)
                // justo después de que Brenda aterriza.
                _PopIn(
                  delay: const Duration(milliseconds: 250),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: bubbleBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: bubbleBorder, width: 2),
                        ),
                        child: Text(
                          tr('obBrendaHello'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                            color: ink,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -7,
                        child: Transform.rotate(
                          angle: 0.785398,
                          child: Container(
                            width: 14,
                            height: 14,
                            color: bubbleBg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 400),
            child: SizedBox(
              width: double.infinity,
              child: DuoButton.primary(
                label: tr('obVamos').toUpperCase(),
                onPressed: onVamos,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icono de cuenta, el hombre de la Lottie "man-account-icon"
/// (Quemia 7.7, Kristian 2026-11-14): se usa en la pantalla de
/// registrarse y en el aviso de crear perfil. La animación arranca
/// con un circulito casi vacío y el hombre aparece a mitad del bucle,
/// así que en pruebas (y con movimiento reducido) se deja FIJO en el
/// 45% — el hombre ya armado — para que las fotos no salgan con el
/// círculo vacío del primer cuadro. En la app se repite en bucle.
class _AccountLottie extends StatefulWidget {
  const _AccountLottie({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_AccountLottie> createState() => _AccountLottieState();
}

class _AccountLottieState extends State<_AccountLottie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Lottie.asset(
      'assets/account.json',
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
      controller: _ctrl,
      onLoaded: (composition) {
        _ctrl.duration = composition.duration;
        if (isFlutterTest || reduceMotion) {
          // Hombre ya armado, quieto.
          _ctrl.value = 0.45;
        } else if (!_ctrl.isAnimating) {
          _ctrl.repeat();
        }
      },
    );
  }
}

/// Pantalla de registro (Quemia 7.7, Kristian 2026-11-13: como la
/// pantalla de Duolingo que me puso — "Elige una opción para
/// registrarte y continuar": Google y correo, SIN pedir el nombre
/// ni el género. El nombre de usuario se coge del correo: con
/// Google, el primer nombre de la cuenta; con correo, el prefijo
/// del correo. Una sola gemela (Brenda, la guía), como Duo solo
/// en la imagen de Duolingo.
class _RegisterPage extends StatelessWidget {
  const _RegisterPage({
    required this.onGoogleSignIn,
    this.googleBusy = false,
    this.googleError,
    required this.onEmail,
    required this.onBack,
  });

  /// "Continuar con Google": enlaza con Google.
  final Future<void> Function()? onGoogleSignIn;

  /// Mientras se firma: el botón muestra carga y queda deshabilitado.
  final bool googleBusy;

  /// Fallo al firmar (una línea, sin diálogo de error): se muestra
  /// debajo del botón, en color neutro, nunca rojo.
  final String? googleError;

  /// "Continuar con correo electrónico": abre el flujo del correo
  /// (correo → contraseña → nombre → código OTP).
  final VoidCallback onEmail;

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final sub = isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : const Color(0xFF777777);
    const blue = Color(0xFF3B82F6);
    final blueText = isDark ? const Color(0xFF60A5FA) : blue;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const LucideIcon(LucideIcons.arrowLeft, size: 28),
              color: ink,
            ),
          ),
          // Icono de cuenta (Lottie, Kristian 2026-11-14: la
          // animación "man-account-icon" de LottieFiles en la
          // pantalla de registrarse, en vez de Brenda).
          const Center(
            child: _AccountLottie(width: 160, height: 160),
          ),
          const SizedBox(height: 16),
          Text(
            tr('obRegisterTitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 24),
          // Google (Duolingo: "CONTINUAR CON GOOGLE", G real +
          // texto azul, botón secundario con labio).
          SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: DuoButton.secondary(
                    label: '',
                    onPressed: googleBusy || onGoogleSignIn == null
                        ? null
                        : () => onGoogleSignIn!(),
                    textColor: blue,
                    edgeColor: const Color(0xFFBFDBFE),
                    fontSize: 17,
                  ),
                ),
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        googleBusy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const GoogleGIcon(size: 24),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              tr('obRegisterGoogle').toUpperCase(),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: googleBusy
                                    ? const Color(0xFFAFAFAF)
                                    : blueText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (googleError != null) ...[
            const SizedBox(height: 12),
            Text(
              googleError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Correo (Duolingo: "CONTINUAR CON CORREO ELECTRÓNICO",
          // sobre morado + texto azul, mismo botón secundario):
          // abre el flujo del correo (correo → contraseña →
          // nombre → código OTP), no un campo aquí.
          SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: DuoButton.secondary(
                    label: '',
                    onPressed: onEmail,
                    textColor: blue,
                    edgeColor: const Color(0xFFBFDBFE),
                    fontSize: 17,
                  ),
                ),
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LucideIcon(
                          LucideIcons.mail,
                          size: 22,
                          color: blueText,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              tr('obRegisterEmail').toUpperCase(),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: blueText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Términos (Duolingo: "Al registrarte..., aceptas
          // nuestros Términos y Política de privacidad.").
          Text(
            tr('obRegisterTerms'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.4, color: sub),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Aviso antes del registro (Quemia 7.7, Kristian 2026-11-13: la
/// pantalla de Duolingo "¡No pierdas tu progreso! Vamos a crear tu
/// perfil."): el avatar arriba, el bocadillo debajo y CONTINUAR
/// abajo (Kristian 2026-11-14: "la caja de texto debe de ir bajo
/// el avatar"). Sin flecha atrás (como Duolingo): se vuelve
/// deslizando.
class _ProfileNudgePage extends StatelessWidget {
  const _ProfileNudgePage({required this.onBack, required this.onNext});

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final bubbleBg = isDark ? scheme.surfaceContainerHighest : Colors.white;
    final bubbleBorder =
        isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE5E5E5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Flecha atrás arriba a la izquierda (Kristian
          // 2026-11-15: sin deslizar, el aviso también vuelve
          // con botón): vuelve a la racha.
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: LucideIcon(LucideIcons.arrowLeft, color: ink),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icono de cuenta arriba (Lottie, Kristian 2026-11-14:
                // la animación "man-account-icon" de LottieFiles en
                // el aviso de crear perfil, en vez de Brenda).
                const _AccountLottie(width: 200, height: 200),
                const SizedBox(height: 20),
                // Bocadillo DEBAJO del avatar (Kristian 2026-11-14:
                // "la caja de texto debe de ir bajo el avatar"): la
                // cola queda arriba, apuntando al avatar.
                _PopIn(
                  delay: const Duration(milliseconds: 250),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: bubbleBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: bubbleBorder, width: 2),
                        ),
                        child: Text(
                          tr('obNudgeTitle'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                            color: ink,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -7,
                        child: Transform.rotate(
                          angle: 0.785398,
                          child: Container(
                            width: 14,
                            height: 14,
                            color: bubbleBg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 400),
            child: SizedBox(
              width: double.infinity,
              child: DuoButton.primary(
                label: tr('obContinue').toUpperCase(),
                onPressed: onNext,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Invitado (Quemia 7.7, Kristian 2026-11-13: "cuando pongan
/// no tengo conexión sería nada más ponerle eso, el nombre, elegir
/// eh ya... ir directo para la aplicación" — el botón ya no se
/// llama "Sin conexión", se llama "Invitado"): solo dos pasos —
/// 0) "¿Cómo te llamas?" (un solo campo, el nombre) → 1) "¿Cuál
/// es tu meta diaria?" (3/10/15/30 min, botón EMPEZAR) → directo
/// a la principal. Sin cuenta, sin Google, sin correo, sin
/// referido, sin notificaciones, sin racha. El nombre se guarda
/// para el saludo y la meta para los recordatorios; el usuario
/// podrá vincular Google o crear su perfil después desde Cuenta.
class _OfflineFlow extends StatefulWidget {
  const _OfflineFlow({
    required this.onBack,
    required this.onFinished,
  });

  final VoidCallback onBack;
  final VoidCallback onFinished;

  @override
  State<_OfflineFlow> createState() => _OfflineFlowState();
}

class _OfflineFlowState extends State<_OfflineFlow> {
  /// 0 = nombre, 1 = meta diaria.
  var _step = 0;
  final _nameController = TextEditingController();

  /// Minutos de la meta diaria (por defecto 10, como en el flujo
  /// normal).
  var _goalMinutes = 10;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await UserPrefs.saveProfile(name);
    await UserPrefs.saveDailyGoal(_goalMinutes);
    await UserPrefs.markOnboardingDone();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    // El atrás del teléfono hace lo mismo que la flecha de
    // la pantalla (Kristian 2026-11-15: el atrás no sale
    // de la app en el inicio).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step == 0) {
          widget.onBack();
        } else {
          setState(() => _step = 0);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const LucideIcon(LucideIcons.arrowLeft, size: 28),
                  onPressed: _step == 0
                      ? widget.onBack
                      : () => setState(() => _step = 0),
                ),
              ),
              Expanded(
                child: _step == 0
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              tr('obNameTitle'),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 24),
                            QuemiaField(
                              controller: _nameController,
                              hint: tr('obFirstNameHint'),
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            DuoButton.primary(
                              label: tr('obContinue').toUpperCase(),
                              onPressed: _nameController.text.trim().isNotEmpty
                                  ? () => setState(() => _step = 1)
                                  : null,
                              fontSize: 17,
                            ),
                          ],
                        ),
                      )
                    : _GoalPage(
                        selected: _goalMinutes,
                        onSelected: (m) => setState(() => _goalMinutes = m),
                        onConfirm: _finish,
                        confirmLabel: 'obOfflineStart',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Registro con correo, paso a paso (Quemia 7.7, Kristian
/// 2026-11-13: las pantallas de Duolingo por correo, en orden):
/// 0) "¿Cuál es tu dirección de correo electrónico?" — solo el
/// correo; 1) "Crea una contraseña" — con ojo para verla; 2)
/// "¿Cómo te llamas?" — Nombre + Apellido; 3) código OTP de 6
/// dígitos que llega al correo. Sin barra de progreso (Quemia no
/// la usa) y sin edad (Quemia no la pide). Al verificar el código
/// se llama a [onVerified] (el padre enlaza la cuenta y avanza
/// al código de referido). El nombre de usuario se coge del
/// correo (orden de Kristian); el nombre que se escribe es el
/// que saluda la app.
class _EmailOnboardingFlow extends StatefulWidget {
  const _EmailOnboardingFlow({
    required this.onBack,
    required this.onVerified,
    required this.onEmailTaken,
  });

  /// Volver al registro (Google / correo).
  final VoidCallback onBack;

  /// (correo, contraseña, nombre completo) tras verificar el OTP.
  final Future<void> Function(String email, String password, String fullName)
      onVerified;

  /// El correo ya está cogido (comprobación temprana, antes de la
  /// contraseña): el padre abre la pantalla de correo tomado con
  /// (correo, ¿tiene contraseña?).
  final void Function(String email, bool? hasPassword) onEmailTaken;

  @override
  State<_EmailOnboardingFlow> createState() => _EmailOnboardingFlowState();
}

class _EmailOnboardingFlowState extends State<_EmailOnboardingFlow> {
  var _step = 0;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpNodes = List.generate(6, (_) => FocusNode());
  var _showPassword = false;
  var _busy = false;
  String? _error;
  var _resendIn = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  String get _email => _emailController.text.trim();
  String get _password => _passwordController.text;
  String get _otpCode => _otpControllers.map((c) => c.text).join();

  String get _fullName {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    return last.isEmpty ? first : '$first $last';
  }

  bool _validEmail(String value) {
    final v = value.trim();
    final at = v.indexOf('@');
    return at > 0 && v.indexOf('.', at) > at + 1 && !v.contains(' ');
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    // En pruebas no hay temporizador periódico: pumpAndSettle no
    // termina nunca con un Timer.periodic vivo (igual que las
    // animaciones, que se paran con FLUTTER_TEST). El botón de
    // reenviar queda disponible de inmediato en los tests.
    if (isFlutterTest) {
      setState(() => _resendIn = 0);
      return;
    }
    setState(() => _resendIn = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendIn <= 1) {
        timer.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn--);
      }
    });
  }

  /// Comprobación temprana del correo (Kristian 2026-11-15):
  /// ANTES de pedir la contraseña, se mira en el índice de correos
  /// si ya está cogido y se dice ahí mismo. Si está cogido, se abre
  /// la pantalla de correo tomado (el padre); si está libre o no se
  /// pudo comprobar (sin internet, permiso, timeout), se sigue a la
  /// contraseña como antes — el enlace al final lo dirá, como red
  /// de seguridad.
  Future<void> _checkEmailAndContinue() async {
    if (!_validEmail(_email) || _busy) return;
    setState(() => _busy = true);
    final entry = await EmailIndex.lookup(_email);
    if (!mounted) return;
    setState(() => _busy = false);
    if (entry != null) {
      widget.onEmailTaken(_email, entry.hasPassword);
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _sendOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await OtpService.requestCode(_email, OtpPurpose.register);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _error = tr('obOtpNotSent'));
      return;
    }
    setState(() {
      _step = 3;
    });
    _startResendCooldown();
  }

  void _onOtpBoxChanged(int index, String value) {
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean != value) {
      _otpControllers[index].value = TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
    }
    if (clean.length == 1 && index < 5) {
      _otpNodes[index + 1].requestFocus();
    } else if (clean.isEmpty && index > 0) {
      _otpNodes[index - 1].requestFocus();
    }
    // El error de un código viejo se limpia en cuanto se escribe
    // uno nuevo: si no, el "incorrecto" se queda pegado aunque el
    // código nuevo sea bueno.
    setState(() => _error = null);
  }

  Future<void> _verifyOtp() async {
    if (_otpCode.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result =
        await OtpService.verifyCode(_email, _otpCode, OtpPurpose.register);
    if (!mounted) return;
    if (result != OtpVerifyResult.valid) {
      setState(
        () {
          _busy = false;
          _error = tr(switch (result) {
            OtpVerifyResult.expired => 'obOtpExpired',
            OtpVerifyResult.exhausted => 'obOtpAttemptsOut',
            _ => 'obOtpInvalid',
          });
        },
      );
      return;
    }
    // CAUSA RAÍZ del bug "error y luego avanza" (Kristian
    // 2026-11-15): antes _busy se soltaba AQUÍ, antes de enlazar
    // la cuenta, así que mientras el enlace iba por la red el botón
    // CONTINUAR volvía a estar activo; un segundo toque volvía a
    // comprobar el código — que ya se había consumido — y salía
    // "incorrecto", y de momento la primera comprobación terminaba
    // y la pantalla avanzaba. Ahora _busy se mantiene hasta que el
    // padre avanza de pantalla (o el enlace falla): un código
    // correcto nunca muestra error y un segundo toque no hace nada.
    await widget.onVerified(_email, _password, _fullName);
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _resendOtp() async {
    if (_resendIn > 0 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await OtpService.requestCode(_email, OtpPurpose.register);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _error = tr('obOtpNotSent'));
      return;
    }
    _startResendCooldown();
  }

  void _back() {
    if (_step == 0) {
      widget.onBack();
    } else {
      setState(() {
        _step--;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final sub = isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : const Color(0xFF777777);
    // El atrás del teléfono hace lo mismo que la flecha de
    // la pantalla (Kristian 2026-11-15: el atrás no sale
    // de la app en el inicio).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              8 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _back,
                    icon: const LucideIcon(LucideIcons.arrowLeft, size: 28),
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                if (_step == 0) ...[
                  Text(
                    tr('obEmailTitle'),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 24),
                  QuemiaField(
                    controller: _emailController,
                    hint: tr('obEmailFieldHint'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _checkEmailAndContinue(),
                  ),
                  const SizedBox(height: 16),
                  DuoButton.primary(
                    label: tr('obContinue').toUpperCase(),
                    onPressed: _validEmail(_email) && !_busy
                        ? _checkEmailAndContinue
                        : null,
                    fontSize: 17,
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ],
                ] else if (_step == 1) ...[
                  Text(
                    tr('obPasswordTitle'),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 24),
                  QuemiaField(
                    controller: _passwordController,
                    hint: tr('obPasswordHint'),
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: LucideIcon(
                        _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                        size: 24,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (isStrongPassword(_password)) {
                        setState(() => _step = 2);
                      }
                    },
                  ),
                  // Contraseña segura (Kristian 2026-11-13: nada de
                  // fáciles): la lista dice qué falta; CONTINUAR
                  // solo se activa con las 5 reglas cumplidas.
                  const SizedBox(height: 12),
                  PasswordRules(password: _password),
                  const SizedBox(height: 16),
                  DuoButton.primary(
                    label: tr('obContinue').toUpperCase(),
                    onPressed: isStrongPassword(_password)
                        ? () => setState(() => _step = 2)
                        : null,
                    fontSize: 17,
                  ),
                ] else if (_step == 2) ...[
                  Text(
                    tr('obNameTitle'),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Nombre y Apellido en DOS cajas separadas (Kristian
                  // 2026-11-13: "están demasiado unidas y feas" — la
                  // caja única de Duolingo con divisor no le gustó):
                  // cada campo con su propio borde y 12 px entre ellos.
                  QuemiaField(
                    controller: _firstNameController,
                    hint: tr('obFirstNameHint'),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  QuemiaField(
                    controller: _lastNameController,
                    hint: tr('obLastNameHint'),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  DuoButton.primary(
                    label: tr('obCreateProfile').toUpperCase(),
                    // Apellido OBLIGATORIO (Kristian 2026-11-15): sin
                    // apellido no se puede crear el perfil; antes
                    // bastaba solo el nombre.
                    onPressed: _firstNameController.text.trim().isNotEmpty &&
                            _lastNameController.text.trim().isNotEmpty &&
                            !_busy
                        ? _sendOtp
                        : null,
                    fontSize: 17,
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ],
                ] else ...[
                  Text(
                    tr('obOtpTitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('obOtpBody'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.4, color: sub),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 6; i++)
                        SizedBox(
                          width: 48,
                          height: 56,
                          child: TextField(
                            controller: _otpControllers[i],
                            focusNode: _otpNodes[i],
                            textAlign: TextAlign.center,
                            cursorHeight: 28,
                            textAlignVertical: TextAlignVertical.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            buildCounter: (context,
                                    {required currentLength,
                                    required isFocused,
                                    maxLength}) =>
                                null,
                            onChanged: (v) => _onOtpBoxChanged(i, v),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppAccent.primary,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor:
                                  isDark ? AppAccent.darkCard : Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : const Color(0xFFC7CBD1),
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                    color: AppAccent.primary, width: 2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  DuoButton.primary(
                    label: tr('obContinue').toUpperCase(),
                    onPressed:
                        _otpCode.length == 6 && !_busy ? _verifyOtp : null,
                    fontSize: 17,
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _resendIn > 0 || _busy ? null : _resendOtp,
                      child: Text(
                        _resendIn > 0
                            ? '${tr('obOtpResend')} ($_resendIn)'
                            : tr('obOtpResend'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  tr('obRegisterTerms'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.4, color: sub),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inicio de sesión (Quemia 7.7, Kristian 2026-11-13: la pantalla
/// de Duolingo "Ingresa tus datos"): correo + contraseña en UNA
/// pantalla, INGRESAR, "¿Has olvidado tu contraseña?" (recuperar
/// por OTP) y "Ingresa con Google". Sin Facebook (Quemia: solo
/// Google + correo). Al entrar se trae el progreso de la nube y se
/// va a la principal.
class _SignInPage extends StatefulWidget {
  const _SignInPage({
    required this.onGoogleSignIn,
    this.googleBusy = false,
    this.googleError,
    required this.onBack,
    required this.onSignedIn,
    this.initialEmail = '',
  });

  /// "Ingresa con Google": enlaza con Google (flujo corto).
  final Future<void> Function()? onGoogleSignIn;

  /// Mientras se firma con Google: el botón muestra carga.
  final bool googleBusy;

  /// Fallo de Google (una línea, sin diálogo).
  final String? googleError;

  /// Volver a la elección.
  final VoidCallback onBack;

  /// Al entrar (correo o Google): el padre guarda el perfil, trae
  /// el progreso y entra a la principal.
  final Future<void> Function() onSignedIn;

  /// Correo ya puesto (pantalla de correo tomado → entrar con el
  /// correo que ya se escribió).
  final String initialEmail;

  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _showPassword = false;
  var _busy = false;
  String? _error;
  var _forgot = false;
  String? _resetDone;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await AuthService.signInWithEmail(email, password);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _error = tr('obSignInFailed'));
      return;
    }
    await widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final sub = isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : const Color(0xFF777777);
    const blue = Color(0xFF3B82F6);
    final blueText = isDark ? const Color(0xFF60A5FA) : blue;
    if (_forgot) {
      return _ForgotPasswordFlow(
        onBack: () => setState(() => _forgot = false),
        onDone: () => setState(() {
          _forgot = false;
          _resetDone = tr('obResetLinkSent');
        }),
      );
    }
    // El atrás del teléfono hace lo mismo que la flecha: vuelve
    // a la elección (Kristian 2026-11-15: el atrás no sale de la
    // app en el inicio). El flujo de olvidar contraseña lleva su
    // propio PopScope dentro, así que aquí solo está el formulario.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        widget.onBack();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              8 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: widget.onBack,
                    icon: const LucideIcon(LucideIcons.arrowLeft, size: 28),
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('obSignInTitle'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 24),
                QuemiaField(
                  controller: _emailController,
                  hint: tr('obEmailHint'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                QuemiaField(
                  controller: _passwordController,
                  hint: tr('obPasswordHint'),
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.done,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: LucideIcon(
                      _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 24,
                      color: blue,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _signIn(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_resetDone != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _resetDone!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppAccent.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DuoButton.primary(
                  label: tr('obSignInButton').toUpperCase(),
                  onPressed: _emailController.text.trim().isNotEmpty &&
                          _passwordController.text.isNotEmpty &&
                          !_busy
                      ? _signIn
                      : null,
                  fontSize: 17,
                ),
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _forgot = true),
                    child: Text(
                      tr('obForgotPassword').toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: blueText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Google (Duolingo: "INGRESA CON GOOGLE", G real +
                // texto azul, botón secundario con labio).
                SizedBox(
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: DuoButton.secondary(
                          label: '',
                          onPressed:
                              widget.googleBusy || widget.onGoogleSignIn == null
                                  ? null
                                  : () => widget.onGoogleSignIn!(),
                          textColor: blue,
                          edgeColor: const Color(0xFFBFDBFE),
                          fontSize: 17,
                        ),
                      ),
                      IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              widget.googleBusy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5),
                                    )
                                  : const GoogleGIcon(size: 24),
                              const SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    tr('obSignInWithGoogle').toUpperCase(),
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: widget.googleBusy
                                          ? const Color(0xFFAFAFAF)
                                          : blueText,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.googleError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.googleError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  tr('obRegisterTerms'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.4, color: sub),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Recuperar la contraseña por OTP (Quemia 7.7, Kristian
/// 2026-11-13): 0) el correo, 1) el código de 6 dígitos, 2) la
/// contraseña nueva. Al cambiarla se vuelve al inicio de sesión
/// con el mensaje de que ya puede entrar.
class _ForgotPasswordFlow extends StatefulWidget {
  const _ForgotPasswordFlow({
    required this.onBack,
    required this.onDone,
  });

  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  State<_ForgotPasswordFlow> createState() => _ForgotPasswordFlowState();
}

class _ForgotPasswordFlowState extends State<_ForgotPasswordFlow> {
  var _step = 0;
  final _emailController = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();

  bool _validEmail(String value) {
    final v = value.trim();
    final at = v.indexOf('@');
    return at > 0 && v.indexOf('.', at) > at + 1 && !v.contains(' ');
  }

  /// Manda el enlace de Firebase para cambiar la contraseña (gratis,
  /// sin código OTP). Si sale bien, pasa a la pantalla de
  /// confirmación; si no, enseña el error y se queda en el correo.
  Future<void> _sendLink() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await AuthService.sendPasswordResetEmail(_email);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _error = tr('obResetLinkFailed'));
      return;
    }
    setState(() => _step = 1);
  }

  void _back() {
    if (_step == 0) {
      widget.onBack();
    } else {
      setState(() {
        _step--;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final sub = isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : const Color(0xFF777777);
    // El atrás del teléfono hace lo mismo que la flecha de
    // la pantalla (Kristian 2026-11-15: el atrás no sale
    // de la app en el inicio).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              8 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _back,
                    icon: const LucideIcon(LucideIcons.arrowLeft, size: 28),
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                if (_step == 0) ...[
                  Text(
                    tr('obResetTitle'),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('obResetBody'),
                    style: TextStyle(fontSize: 16, height: 1.4, color: sub),
                  ),
                  const SizedBox(height: 24),
                  QuemiaField(
                    controller: _emailController,
                    hint: tr('obEmailFieldHint'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_validEmail(_email)) _sendLink();
                    },
                  ),
                  const SizedBox(height: 16),
                  DuoButton.primary(
                    label: tr('obContinue').toUpperCase(),
                    onPressed: _validEmail(_email) && !_busy ? _sendLink : null,
                    fontSize: 17,
                  ),
                ] else ...[
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppAccent.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: LucideIcon(
                        LucideIcons.mail,
                        size: 36,
                        color: AppAccent.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr('obResetLinkSent'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ink,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DuoButton.primary(
                    label: tr('obContinue').toUpperCase(),
                    onPressed: widget.onDone,
                    fontSize: 17,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pop suave (escala + opacidad) con retardo: para el bocadillo de
/// Brenda y la llama de la racha. Sin paquetes, solo Flutter. Con
/// movimiento reducido se ve directo, sin animar.
class _PopIn extends StatefulWidget {
  const _PopIn({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  // Arranca en didChangeDependencies (no en initState: MediaQuery
  // es un inherited widget y no se puede leer en initState). Solo
  // una vez.
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Movimiento reducido: sin animación, se ve directo.
    if (MediaQuery.of(context).disableAnimations) {
      _ctrl.value = 1;
    } else if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: widget.child,
    );
  }
}

/// Tarjeta de opción limpia (Quemia 7.7, diseños limpios como
/// Duolingo): borde redondeado 16, un solo foco por fila (icono +
/// texto) y un círculo de selección a la derecha. Al elegir, el
/// borde se pone teal y el check entra con un pop; al tocar, la
/// tarjeta rebota un poco (PressScale 0.97). Texto siempre
/// legible (tinta del tema, nunca gris tenue sobre color).
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.selected,
    required this.onTap,
    required this.child,
    this.selectedColor,
    this.selectedGradient,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  /// Color de la selección (borde, fondo, check). Por defecto el
  /// teal del acento; la Fuente pasa el color de cada app
  /// (Quemia 7.7, Kristian 2026-11-13: "según la app que se
  /// escoja cogerá color cada opción según la app").
  final Color? selectedColor;

  /// Degradado REAL de la marca (solo Instagram, Kristian
  /// 2026-11-13: "Instagram tiene varios de colores"). Cuando está
  /// y la opción está elegida, el borde y el check usan el
  /// degradado; el fondo sigue siendo el color sólido al 8%.
  final Gradient? selectedGradient;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = selectedColor ?? AppAccent.primary;
    final useGradient = selected && selectedGradient != null;
    final border = useGradient
        ? Colors.transparent
        : selected
            ? accent
            : (isDark
                ? Colors.white.withValues(alpha: 0.2)
                : const Color(0xFFE5E5E5));
    final fill = selected
        ? accent.withValues(alpha: 0.08)
        : (isDark ? AppAccent.darkCard : Colors.white);
    final checkBorder = useGradient
        ? Colors.transparent
        : selected
            ? accent
            : (isDark
                ? Colors.white.withValues(alpha: 0.5)
                : const Color(0xFF9CA3AF));
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(useGradient ? 14 : 16),
        border: Border.all(color: border, width: 2),
      ),
      child: Row(
        children: [
          Expanded(child: child),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  useGradient ? null : (selected ? accent : Colors.transparent),
              gradient: useGradient ? selectedGradient : null,
              border: Border.all(color: checkBorder, width: 2),
            ),
            child: AnimatedScale(
              scale: selected ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: const LucideIcon(
                LucideIcons.check,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    return PressScale(
      onTap: onTap,
      child: useGradient
          ? Container(
              decoration: BoxDecoration(
                gradient: selectedGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(2),
              child: card,
            )
          : card,
    );
  }
}

/// Una opción de "¿Cómo supiste de Quemia?": valor que se guarda,
/// etiqueta que se ve, icono y COLOR de la app (Quemia 7.7, Kristian
/// 2026-11-13: "según la app que se escoja cogerá color cada opción
/// según la app" — regla de color: cada cosa con el color de su
/// tema). Los LOGOS son las imágenes REALES de cada app, buscadas
/// (Kristian 2026-11-13: "busca las imágenes y cualquier tipo de
/// logo, no inventes los logos"), no dibujadas: Google la G de
/// colores, Instagram su logo con TODOS sus colores (degradado
/// oficial amarillo-naranja-rosa-violeta-azul, no un rosa plano),
/// Facebook la f azul, TikTok la nota negra con sombras cian y
/// magenta (en oscuro, la nota blanca oficial). Amigos/familia
/// sigue con el corazón violeta de Brenda y Otra con el icono gris:
/// no son apps, no tienen logo.
class _SourceOption {
  const _SourceOption(this.value, this.labelKey, this.icon, this.color,
      {this.asset, this.assetDark, this.gradient});
  final String value;
  final String labelKey;
  final LucideIconData icon;
  final Color color;

  /// Logo REAL de la app. null = icono Lucide (Amigos/Otra).
  final String? asset;

  /// Logo para el tema oscuro (TikTok: la nota negra no se ve
  /// sobre oscuro; se usa la blanca). null = el mismo en ambos.
  final String? assetDark;

  /// Degradado real de la marca (Instagram: sus varios colores).
  final Gradient? gradient;
}

/// Crear cuenta, paso 3 (Quemia 7.7, Kristian 2026-11-13, flujo de
/// Duolingo con contenido de Quemia): "¿Cómo supiste de Quemia?"
/// — sin la pantalla de elegir idioma de Duolingo, que no va.
/// Diseño limpio: título, una línea de cuerpo, las 6 opciones bien
/// separadas (aparecen una a una) y UN solo botón grande abajo.
class _SourcePage extends StatelessWidget {
  const _SourcePage({
    required this.selected,
    required this.onSelected,
    required this.onConfirm,
  });

  final String? selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onConfirm;

  static const _options = [
    _SourceOption(
        'google', 'obSourceGoogle', LucideIcons.search, Color(0xFF4285F4),
        asset: 'assets/google_g.png'),
    _SourceOption(
        'instagram', 'obSourceInstagram', LucideIcons.image, Color(0xFFD62976),
        asset: 'assets/instagram_logo.png',
        gradient: LinearGradient(
          colors: [
            Color(0xFFFEDA75),
            Color(0xFFFA7E1E),
            Color(0xFFD62976),
            Color(0xFF962FBF),
            Color(0xFF4F5BD5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )),
    _SourceOption(
        'facebook', 'obSourceFacebook', LucideIcons.globe, Color(0xFF1877F2),
        asset: 'assets/facebook_logo.png'),
    _SourceOption(
        'tiktok', 'obSourceTiktok', LucideIcons.play, Color(0xFFFE2C55),
        asset: 'assets/tiktok_logo.png',
        assetDark: 'assets/tiktok_logo_white.png'),
    _SourceOption(
        'friends', 'obSourceFriends', LucideIcons.heart, Color(0xFF8B5CF6)),
    _SourceOption(
        'other', 'obSourceOther', LucideIcons.sparkles, Color(0xFF9CA3AF)),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final sub = isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : const Color(0xFF777777);
    final iconIdle =
        isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF9CA3AF);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(
            child: Text(
              tr('obSourceTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, color: ink),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: Text(
              tr('obSourceBody'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4, color: sub),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final option = _options[i];
                final isSelected = selected == option.value;
                // Logo real de la app (siempre a todo color, como la
                // app de verdad); en oscuro TikTok usa su nota
                // blanca. Amigos/Otra no son apps: icono Lucide.
                final logoAsset = isDark && option.assetDark != null
                    ? option.assetDark!
                    : option.asset;
                return FadeSlideIn(
                  delay: Duration(milliseconds: 100 + i * 60),
                  child: _OptionCard(
                    selected: isSelected,
                    selectedColor: option.color,
                    selectedGradient: option.gradient,
                    onTap: () => onSelected(option.value),
                    child: Row(
                      children: [
                        if (logoAsset != null)
                          Image.asset(
                            logoAsset,
                            width: 28,
                            height: 28,
                          )
                        else
                          LucideIcon(
                            option.icon,
                            size: 22,
                            color: isSelected ? option.color : iconIdle,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr(option.labelKey),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: Duration(milliseconds: 100 + _options.length * 60),
            child: SizedBox(
              width: double.infinity,
              child: DuoButton.primary(
                label: tr('obContinue').toUpperCase(),
                onPressed: selected == null ? null : onConfirm,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Crear cuenta, paso 4 (Quemia 7.7): "¿Cuánta química sabes?"
/// (en vez de "¿Cuánto inglés sabes?" de Duolingo). 5 niveles con
/// barritas, como en Duolingo, pero con contenido de química.
/// Diseño limpio: título, una línea, las 5 opciones y un botón.
class _LevelPage extends StatelessWidget {
  const _LevelPage({
    required this.selected,
    required this.onSelected,
    required this.onConfirm,
  });

  final int? selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onConfirm;

  // Nivel, clave de la etiqueta, clave de la descripción.
  static const _levels = [
    (0, 'obLevel0', 'obLevel0Sub'),
    (1, 'obLevel1', 'obLevel1Sub'),
    (2, 'obLevel2', 'obLevel2Sub'),
    (3, 'obLevel3', 'obLevel3Sub'),
    (4, 'obLevel4', 'obLevel4Sub'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final sub = isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : const Color(0xFF777777);
    final barEmpty =
        isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE5E7EB);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(
            child: Text(
              tr('obLevelTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, color: ink),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: Text(
              tr('obLevelBody'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4, color: sub),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _levels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final (level, labelKey, subKey) = _levels[i];
                final isSelected = selected == level;
                return FadeSlideIn(
                  delay: Duration(milliseconds: 100 + i * 60),
                  child: _OptionCard(
                    selected: isSelected,
                    onTap: () => onSelected(level),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(labelKey),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(subKey),
                          style: TextStyle(fontSize: 14, color: sub),
                        ),
                        const SizedBox(height: 8),
                        // Barritas del nivel (1..5): llenas en teal,
                        // vacías en gris. Como en Duolingo.
                        Row(
                          children: [
                            for (var b = 0; b < 5; b++) ...[
                              if (b > 0) const SizedBox(width: 4),
                              Container(
                                width: 22,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color:
                                      b <= level ? AppAccent.primary : barEmpty,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: Duration(milliseconds: 100 + _levels.length * 60),
            child: SizedBox(
              width: double.infinity,
              child: DuoButton.primary(
                label: tr('obContinue').toUpperCase(),
                onPressed: selected == null ? null : onConfirm,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Crear cuenta, paso 5 (Quemia 7.7): "¿Cuál es tu meta diaria?"
/// 3/10/15/30 min (Relajado/Normal/Serio/Intenso). Quemia tiene
/// racha y días de práctica, así que encaja. Por defecto 10 min
/// (Normal). Diseño limpio: título, una línea, 4 opciones y un
/// botón.
class _GoalPage extends StatelessWidget {
  const _GoalPage({
    required this.selected,
    required this.onSelected,
    required this.onConfirm,
    this.confirmLabel = 'obGoalSave',
  });

  /// Minutos elegidos (3 | 10 | 15 | 30). Por defecto 10.
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onConfirm;

  /// Clave del botón de confirmar (por defecto "GUARDAR MI META";
  /// el flujo sin conexión usa "EMPEZAR").
  final String confirmLabel;

  // Minutos, clave de "X min al día", clave de la etiqueta.
  static const _goals = [
    (3, 'obGoal3', 'obGoalRelaxed'),
    (10, 'obGoal10', 'obGoalNormal'),
    (15, 'obGoal15', 'obGoalSerious'),
    (30, 'obGoal30', 'obGoalIntense'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final sub = isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : const Color(0xFF777777);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(
            child: Text(
              tr('obGoalTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, color: ink),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: Text(
              tr('obGoalBody'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4, color: sub),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final (minutes, minutesKey, labelKey) = _goals[i];
                final isSelected = selected == minutes;
                return FadeSlideIn(
                  delay: Duration(milliseconds: 100 + i * 60),
                  child: _OptionCard(
                    selected: isSelected,
                    onTap: () => onSelected(minutes),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(minutesKey),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? AppAccent.primary : ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(labelKey),
                          style: TextStyle(fontSize: 14, color: sub),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: Duration(milliseconds: 100 + _goals.length * 60),
            child: SizedBox(
              width: double.infinity,
              child: DuoButton.primary(
                label: tr(confirmLabel).toUpperCase(),
                onPressed: onConfirm,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confeti al empezar la racha (Quemia 7.7, Kristian 2026-11-13:
/// animaciones como Duolingo — la pantalla de racha de Duolingo es
/// llama grande + "You started a streak!" + confeti).
/// Kristian 2026-11-14 mandó la animación "confetti" de LottieFiles
/// (https://lottiefiles.com/free-animation/confetti-3ofTs67sBx)
/// para el confeti y lo demás que lleve confeti: una sola pasada
/// al aparecer la página (~5 s) y al terminar se desmonta, como el
/// overlay de celebración (fix5: nada congelado tapando botones).
/// En pruebas queda congelado a mitad de la caída para que la foto
/// enseñe el confeti; con movimiento reducido no sale nada.
class _ConfettiLottie extends StatefulWidget {
  const _ConfettiLottie();

  @override
  State<_ConfettiLottie> createState() => _ConfettiLottieState();
}

class _ConfettiLottieState extends State<_ConfettiLottie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  var _started = false;

  /// La animación terminó: ya no hay nada que pintar.
  var _done = false;

  @override
  void initState() {
    super.initState();
    // Una pasada a la velocidad natural del Lottie: 126 fotogramas
    // a 25 fps = 5,04 s.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5040),
    )..addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Movimiento reducido o pruebas: cuadro congelado a mitad de
    // la caída (en pruebas, para que la foto enseñe el confeti sin
    // bloquear los pumpAndSettle).
    if (MediaQuery.of(context).disableAnimations || isFlutterTest) {
      _ctrl.value = 0.4;
      return;
    }
    _ctrl.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _done = true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();
    return Lottie.asset(
      'assets/confetti.json',
      controller: _ctrl,
      fit: BoxFit.cover,
      repeat: false,
    );
  }
}

class _StreakPage extends StatelessWidget {
  const _StreakPage({required this.onNext});

  final VoidCallback onNext;

  static const _dayKeys = [
    'obDayMon',
    'obDayTue',
    'obDayWed',
    'obDayThu',
    'obDayFri',
    'obDaySat',
    'obDaySun',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final sub = isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : const Color(0xFF777777);
    // Naranja de la racha (Duolingo: la racha es naranja; Quemia
    // usa su propio naranja vivo, plano, con texto legible).
    const orange = Color(0xFFF97316);
    // Hoy: 1 = lunes .. 7 = domingo.
    final today = DateTime.now().weekday;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En pantallas cortas (p. ej. 600 pt de alto en
              // pruebas) el contenido no cabe y desbordaba 45 pt:
              // con scroll no se corta nada; en el teléfono (852+)
              // todo cabe y no se nota el cambio.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Llama de Lottie (Kristian 2026-11-13: "usa
                      // esto de Lottie, quita a la chica y ese fuego,
                      // y pon este en movimiento"; 2026-11-14 mandó
                      // la llama nueva "fireeeeee" y pidió que suene
                      // una sola vez al abrir la página y luego quede
                      // quieta): la animación "streak-fire" de
                      // LottieFiles, sin Brenda y sin la llama
                      // vectorial dibujada.
                      _PopIn(
                        child: const PlayOnceLottie(
                          asset: 'assets/streak_fire.json',
                          width: 260,
                          height: 220,
                        ),
                      ),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 100),
                      child: Text(
                        tr('obStreakTitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: ink),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // El número GIGANTE en naranja, como en Duolingo:
                    // el "1" entra con pop y debajo va "día de racha".
                    _PopIn(
                      delay: const Duration(milliseconds: 220),
                      child: const Text(
                        '1',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 96,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          color: orange,
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 300),
                      child: Text(
                        tr('obStreakDayLabel'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // La semana (lunes..domingo), como en Duolingo: la
                    // letra arriba y el círculo abajo; hoy es naranja
                    // con un ✓ blanco, los demás grises. Cada día
                    // aparece escalonado.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: FadeSlideIn(
                              delay: Duration(milliseconds: 360 + i * 60),
                              child: Column(
                                children: [
                                  Text(
                                    tr(_dayKeys[i]),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: (i + 1) == today ? orange : sub,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (i + 1) == today
                                          ? orange
                                          : (isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.12)
                                              : const Color(0xFFE5E5E5)),
                                    ),
                                    child: (i + 1) == today
                                        ? const LucideIcon(
                                            LucideIcons.check,
                                            size: 20,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  ),
                ),
              ),
              FadeSlideIn(
                delay: const Duration(milliseconds: 480),
                child: SizedBox(
                  width: double.infinity,
                  child: DuoButton.primary(
                    label: tr('obStreakStart').toUpperCase(),
                    onPressed: onNext,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          // Confeti al aparecer (como Duolingo): no tapa los toques.
          const Positioned.fill(
            child: IgnorePointer(child: _ConfettiLottie()),
          ),
        ],
      ),
    );
  }
}
