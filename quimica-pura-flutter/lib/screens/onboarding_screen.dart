// Pantallas de bienvenida: solo salen la primera vez que se instala la app.
// No necesitan internet. Al final se guardan el nombre, el género y el
// idioma en el teléfono, y cada entrada saluda "Bienvenida [nombre]" o
// "Bienvenido [nombre]" (en el idioma elegido).

import '../data/i18n/content_i18n.dart';
import 'package:flutter/material.dart';
import '../widgets/duo_button.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/lucide_icons.dart';
import '../services/analytics_sync.dart';
import '../services/auth_service.dart';
import '../services/localization.dart';
import '../widgets/brand_logo.dart';
import '../services/user_prefs.dart';
import 'onboarding_notifications_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  int _page = 0;
  String? _gender;

  bool get _profileOk =>
      _nameController.text.trim().isNotEmpty && _gender != null;

  Future<void> _next() async {
    // En la página del perfil no se avanza sin nombre y género.
    if (_page == 4 && !_profileOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('obNeedName'))),
      );
      return;
    }
    if (_page < 6) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('obNeedName'))),
      );
      return;
    }
    await UserPrefs.saveProfile(name, _gender!);
    widget.onFinished();
  }

  /// "Continuar con Google" (ronda #8, cambio 09:08): enlaza la
  /// sesión anónima con Google (mismo uid, sin cambiarlo) y trae
  /// el respaldo de la nube si esa cuenta ya tenía progreso en
  /// otro teléfono. Prellena el nombre con el de la cuenta de
  /// Google si el campo está vacío. Opcional: se puede seguir
  /// sin Google (el botón Siguiente no depende de esto).
  ///
  /// Error honesto (09:13): mientras se firma, el botón muestra
  /// carga y queda deshabilitado; si linkWithGoogle() devuelve
  /// false, sale UNA línea con el motivo (sin internet, o fallo al
  /// iniciar sesión) y la app sigue: sin excepciones sin atrapar y
  /// sin quedarse en carga. linkWithGoogle() nunca lanza.
  var _googleBusy = false;
  String? _googleError;

  Future<void> _linkGoogle() async {
    if (_googleBusy) return;
    setState(() {
      _googleBusy = true;
      _googleError = null;
    });
    final ok = await AuthService.linkWithGoogle();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _googleBusy = false;
        _googleError = AnalyticsSync.firebaseReady
            ? tr('googleSignInFailed')
            : tr('googleNeedInternet');
      });
      return;
    }
    final String? name = AuthService.googleDisplayName;
    if (name != null &&
        name.isNotEmpty &&
        _nameController.text.trim().isEmpty) {
      _nameController.text = name;
    }
    await AnalyticsSync.restoreFromCloud();
    if (mounted) setState(() => _googleBusy = false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // resizeToAvoidBottomInset: false para que, al abrirse el teclado,
    // el botón Siguiente se quede fijo abajo y no suba a tapar nada.
    // El contenido de cada página ya es desplazable, y la página del
    // perfil reserva abajo el alto del teclado para que nada quede tapado.
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Barra de progreso ARRIBA (diseño Duolingo §3.10): 12 pt,
            // pista #E5E5E5, relleno teal + brillo superior #14D3B8.
            // Los puntos de abajo se borran: el progreso lo lleva
            // esta barra, no los puntos.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
              child: _ProgressBar(progress: (_page + 1) / 7),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _WelcomePage(),
                  _ExplainPage(
                    icon: LucideIcons.calculator,
                    title: tr('obSolveTitle'),
                    body: tr('obSolveBody'),
                    points: [tr('obSolveP1'), tr('obSolveP2'), tr('obSolveP3')],
                  ),
                  _ExplainPage(
                    icon: LucideIcons.bookOpen,
                    title: tr('obStudyTitle'),
                    body: tr('obStudyBody'),
                    points: [tr('obStudyP1'), tr('obStudyP2'), tr('obStudyP3')],
                  ),
                  _ExplainPage(
                    icon: LucideIcons.circleHelp,
                    title: tr('obPracticeTitle'),
                    body: tr('obPracticeBody'),
                    points: [
                      tr('obPracticeP1'),
                      tr('obPracticeP2'),
                      tr('obPracticeP3'),
                    ],
                  ),
                  _ProfilePage(
                    nameController: _nameController,
                    gender: _gender,
                    onGenderChanged: (g) => setState(() => _gender = g),
                    onGoogleSignIn: _linkGoogle,
                    googleBusy: _googleBusy,
                    googleError: _googleError,
                  ),
                  // Fix3, punto 9: permiso de notificaciones, después
                  // del nombre y antes del idioma ("Finalizar"). Tiene
                  // sus propios botones; el "Siguiente" de abajo no
                  // sale en esta página.
                  OnboardingNotificationsPage(onNext: _next),
                  _LanguagePage(onFinish: _finish),
                ],
              ),
            ),
            // Botón "Siguiente" fijado abajo (diseño Duolingo §1.4):
            // sólido teal + labio, texto "SIGUIENTE" 17 pt peso 800.
            // En la página de notificaciones (5) y en la de idioma (6)
            // no sale: cada una tiene sus propios botones.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: _page < 5
                  ? SizedBox(
                      width: double.infinity,
                      child: DuoButton.primary(
                        label: tr('obNext').toUpperCase(),
                        onPressed: _next,
                        fontSize: 17,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de progreso del onboarding (12 pt, pista #E5E5E5, relleno
/// teal con una franja superior #14D3B8 como brillo).
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF00C2A8),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(999),
              bottomLeft: Radius.circular(999),
            ),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 3,
              color: const Color(0xFF14D3B8),
            ),
          ),
        ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Marca nueva (molécula) arriba. La imagen de las gemelas
          // de la primera pantalla se quitó (fix2, item 5): queda el
          // logo, el "Bienvenidos" grande y el botón Siguiente, para
          // que la pantalla se vea ya como la final.
          // Fix3, punto 6: el logo ya es panorámico y recortado a
          // las gemelas (BrandLogo: ancho 104, alto ~42), así las
          // muñecas se ven grandes sin el cuadrado marrón gigante.
          const BrandLogo(size: 104),
          const SizedBox(height: 24),
          Text(
            tr('obWelcome'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 46, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            tr('obChemist'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: Color(0xFF14B8A6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            tr('obWelcomeBody'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ExplainPage extends StatelessWidget {
  const _ExplainPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.points,
  });
  final LucideIconData icon;
  final String title;
  final String body;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: const Color(0xFF14B8A6).withValues(alpha: 0.18),
              child: LucideIcon(icon, size: 46, color: const Color(0xFF14B8A6)),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(fontSize: 17, height: 1.5)),
          const SizedBox(height: 20),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  Expanded(
                      child: Text(p,
                          style: const TextStyle(fontSize: 17, height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Azulejo de género de ancho completo (diseño Duolingo §3.10):
/// dos azulejos APILADOS, no dos píldoras lado a lado. Sin elegir:
/// blanco con borde #E5E5E5. Elegido: fondo con su tinte (Femenino
/// violeta claro, Masculino azul claro) + borde de su color.
/// Texto 17 pt peso 700 #4B4B4B. Radio 12, borde 2 pt.
class _GenderTile extends StatelessWidget {
  const _GenderTile({
    required this.label,
    required this.selected,
    required this.tint,
    required this.borderColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color tint;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? tint : Colors.white,
            border: Border.all(
              color: selected ? borderColor : const Color(0xFFE5E5E5),
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B4B4B),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.nameController,
    required this.gender,
    required this.onGenderChanged,
    this.onGoogleSignIn,
    this.googleBusy = false,
    this.googleError,
  });
  final TextEditingController nameController;
  final String? gender;
  final ValueChanged<String> onGenderChanged;

  /// "Continuar con Google" (opcional): enlaza con Google y
  /// prellena el nombre. Inyectable para probar la página.
  final Future<void> Function()? onGoogleSignIn;

  /// Mientras se firma: el botón muestra carga y queda deshabilitado.
  final bool googleBusy;

  /// Fallo al firmar (una línea, sin diálogo de error): se muestra
  /// debajo del botón, en color neutro, nunca rojo.
  final String? googleError;

  @override
  Widget build(BuildContext context) {
    // Diseño Duolingo (§3.10): Brenda + Britany ilustradas juntas en
    // vez del emblema con degradado; título 24 pt peso 800 #4B4B4B;
    // campo radio 16 con borde #E5E5E5 (al enfocar #5EEAD4), sin
    // sombra teal; género en dos azulejos apilados; botón Google
    // secundario Duolingo con la G real. Nada de bordes negros.
    const ink = Color(0xFF4B4B4B);
    const violet = Color(0xFF8B5CF6);
    const blue = Color(0xFF3B82F6);
    // El relleno de abajo crece con el teclado abierto, así el botón
    // Siguiente se puede subir por encima del teclado desplazando.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        32,
        16,
        32,
        32 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Brenda + Britany ilustradas juntas (~140 dp), en vez del
          // emblema circular con degradado y el icono genérico.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Image.asset('assets/brenda.png', height: 140),
              Image.asset('assets/britany.png', height: 140),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            tr('obProfileTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: ink),
          ),
          const SizedBox(height: 12),
          Text(
            tr('obProfileBody'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, height: 1.5, color: Color(0xFF777777)),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tr('obNameLabel'),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: ink),
            ),
          ),
          const SizedBox(height: 8),
          // Campo de nombre: radio 16 (no píldora), borde 2 pt
          // #E5E5E5, 56 pt de alto, al enfocar borde #5EEAD4;
          // sin sombra teal.
          SizedBox(
            height: 56,
            child: TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: ink),
              decoration: InputDecoration(
                hintText: tr('obNameHint'),
                hintStyle: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.normal,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E5E5), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E5E5), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFF5EEAD4), width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(tr('obGender'),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: ink)),
          ),
          const SizedBox(height: 8),
          // Género: dos azulejos de ancho completo APILADOS (no dos
          // píldoras lado a lado). Femenino violeta claro, Masculino
          // azul claro al seleccionar.
          _GenderTile(
            label: tr('obFemale'),
            selected: gender == 'Femenino',
            tint: const Color(0xFFEDE9FE),
            borderColor: violet,
            onTap: () => onGenderChanged('Femenino'),
          ),
          const SizedBox(height: 12),
          _GenderTile(
            label: tr('obMale'),
            selected: gender == 'Masculino',
            tint: const Color(0xFFDBEAFE),
            borderColor: blue,
            onTap: () => onGenderChanged('Masculino'),
          ),
          // Ronda #8 (cambio 09:08): "Continuar con Google" DEBAJO
          // del nombre y el género. Opcional: enlaza la sesión con
          // Google y prellena el nombre con el de la cuenta.
          const SizedBox(height: 32),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(tr('orWord')),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          // Botón Google secundario Duolingo: blanco + borde 2 pt
          // #E5E5E5 + labio 4 pt #E5E5E5 + texto #4B4B4B 17 pt +
          // logo G real (assets/google_g.png). La G va superpuesta
          // a la izquierda (DuoButton no admite icono de imagen);
          // con IgnorePointer para no tapar el toque.
          SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: DuoButton.secondary(
                    label: tr('googleContinue').toUpperCase(),
                    onPressed: googleBusy || onGoogleSignIn == null
                        ? null
                        : () => onGoogleSignIn!(),
                    textColor: ink,
                    edgeColor: const Color(0xFFE5E5E5),
                    fontSize: 17,
                  ),
                ),
                Positioned(
                  left: 20,
                  child: IgnorePointer(
                    child: googleBusy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const GoogleGIcon(size: 24),
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Última pantalla: elegir el idioma de la app. Se aplica en el acto
/// (los textos de bienvenida cambian al tocar) y se guarda en el teléfono.
class _LanguagePage extends StatefulWidget {
  const _LanguagePage({required this.onFinish});
  final VoidCallback onFinish;

  @override
  State<_LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<_LanguagePage> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Text(
            tr('obLangTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            tr('obLangBody'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, height: 1.5),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (code, name) in AppLang.supported)
                ChoiceChip(
                  // Azulejo Duolingo (§1.5): borde 2 pt #E5E5E5 sin
                  // elegir; elegido, fondo #CCFBF1 + borde #14B8A6.
                  // Sin esto el chip usa el borde `outline` de
                  // Material 3, más oscuro que #E5E5E5 (regla 4).
                  label: Text(name,
                      style: const TextStyle(
                          fontSize: 17, color: Color(0xFF4B4B4B))),
                  selected: AppLang.code == code,
                  selectedColor: const Color(0xFFCCFBF1),
                  backgroundColor: Colors.white,
                  checkmarkColor: const Color(0xFF00A18D),
                  side: BorderSide(
                      color: AppLang.code == code
                          ? const Color(0xFF14B8A6)
                          : const Color(0xFFE5E5E5),
                      width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (_) async {
                    await AppLang.setLang(code);
                    syncGeneratorLang();
                    if (mounted) setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onFinish,
              child: Text(tr('obFinish'), style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
