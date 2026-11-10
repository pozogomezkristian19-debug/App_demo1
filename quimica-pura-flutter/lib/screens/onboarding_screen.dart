// Pantallas de bienvenida: solo salen la primera vez que se instala la app.
// No necesitan internet. Al final se guardan el nombre, el género y el
// idioma en el teléfono, y cada entrada saluda "Bienvenida [nombre]" o
// "Bienvenido [nombre]" (en el idioma elegido).

import 'package:flutter/material.dart';
import '../services/localization.dart';
import '../services/user_prefs.dart';

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

  static const _teal = Color(0xFF14B8A6);

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
    if (_page < 5) {
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

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // resizeToAvoidBottomInset: false para que, al abrirse el teclado, la
    // fila de puntos se quede fija abajo y no suba a tapar los botones.
    // El contenido de cada página ya es desplazable, y la página del
    // perfil reserva abajo el alto del teclado para que nada quede tapado.
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _WelcomePage(),
                  _ExplainPage(
                    icon: Icons.calculate,
                    title: tr('obSolveTitle'),
                    body: tr('obSolveBody'),
                    points: [tr('obSolveP1'), tr('obSolveP2'), tr('obSolveP3')],
                  ),
                  _ExplainPage(
                    icon: Icons.menu_book,
                    title: tr('obStudyTitle'),
                    body: tr('obStudyBody'),
                    points: [tr('obStudyP1'), tr('obStudyP2'), tr('obStudyP3')],
                  ),
                  _ExplainPage(
                    icon: Icons.quiz,
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
                  ),
                  _LanguagePage(onFinish: _finish),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      6,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _page == i ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _page == i
                              ? _teal
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_page < 5)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        child: Text(tr('obNext'),
                            style: const TextStyle(fontSize: 18)),
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
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(32)),
            child: Image(
              image: AssetImage('assets/logo.png'),
              width: 190,
              height: 190,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 32),
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
  final IconData icon;
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
              child: Icon(icon, size: 46, color: const Color(0xFF14B8A6)),
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
                          style:
                              const TextStyle(fontSize: 17, height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.nameController,
    required this.gender,
    required this.onGenderChanged,
  });
  final TextEditingController nameController;
  final String? gender;
  final ValueChanged<String> onGenderChanged;

  @override
  Widget build(BuildContext context) {
    // Todo centrado, y la caja del nombre es lo más grande y visible
    // de la pantalla: texto grande, borde grueso en teal y centrada.
    const teal = Color(0xFF14B8A6);
    // El relleno de abajo crece con el teclado abierto, así el botón
    // Siguiente se puede subir por encima del teclado desplazando.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        32,
        32,
        32,
        32 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Text(
            tr('obProfileTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            tr('obProfileBody'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, height: 1.5),
          ),
          const SizedBox(height: 32),
          Text(
            tr('obNameLabel'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: teal),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: tr('obNameHint'),
              hintStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.normal,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.45),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: teal, width: 2.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: teal, width: 2.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: teal, width: 3),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(tr('obGender'),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              ChoiceChip(
                label: Text(tr('obFemale')),
                selected: gender == 'Femenino',
                onSelected: (_) => onGenderChanged('Femenino'),
              ),
              ChoiceChip(
                label: Text(tr('obMale')),
                selected: gender == 'Masculino',
                onSelected: (_) => onGenderChanged('Masculino'),
              ),
            ],
          ),
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
                  label: Text(name, style: const TextStyle(fontSize: 17)),
                  selected: AppLang.code == code,
                  onSelected: (_) async {
                    await AppLang.setLang(code);
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
              child: Text(tr('obFinish'),
                  style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
