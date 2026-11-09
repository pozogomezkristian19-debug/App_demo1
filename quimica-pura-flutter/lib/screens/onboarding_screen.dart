// Pantallas de bienvenida: solo salen la primera vez que se instala la app.
// No necesitan internet. Al final se guardan el nombre y el género en el
// teléfono, y cada entrada saluda "Bienvenida [nombre]" o "Bienvenido [nombre]".

import 'package:flutter/material.dart';
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

  Future<void> _next() async {
    if (_page < 4) {
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
        const SnackBar(
          content: Text('Escribe tu nombre y elige tu género para terminar.'),
        ),
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
                  _WelcomePage(),
                  const _ExplainPage(
                    icon: Icons.calculate,
                    title: 'Resuelve problemas paso a paso',
                    body:
                        'Siete solucionadores que no solo dan el resultado: muestran el procedimiento completo, como lo escribirías en un examen.',
                    points: [
                      'Masa molar y masa ⇄ moles',
                      'Molaridad y dilución',
                      'pH y pOH, gas ideal y reactivo limitante',
                    ],
                  ),
                  const _ExplainPage(
                    icon: Icons.menu_book,
                    title: 'Estudia y consulta',
                    body:
                        'Seis temas de universidad con resumen, fórmulas clave, un ejemplo resuelto y los errores que más cuestan puntos.',
                    points: [
                      'Formulario rápido siempre a mano',
                      'Tabla periódica con los 118 elementos',
                      'Toca un elemento y mira su ficha completa',
                    ],
                  ),
                  const _ExplainPage(
                    icon: Icons.quiz,
                    title: 'Practica y llega lista al examen',
                    body:
                        'Pon a prueba lo que sabes y corrige al momento, con la explicación de cada respuesta.',
                    points: [
                      '108 preguntas por tema, aleatorias',
                      'Examen mixto de 24 preguntas',
                      'Tips de examen y de cálculo',
                    ],
                  ),
                  _ProfilePage(
                    nameController: _nameController,
                    gender: _gender,
                    onGenderChanged: (g) => setState(() => _gender = g),
                    onFinish: _finish,
                  ),
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
                      5,
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
                  if (_page < 4)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        child: const Text('Siguiente', style: TextStyle(fontSize: 18)),
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
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(32)),
            child: Image(
              image: AssetImage('assets/logo.png'),
              width: 190,
              height: 190,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(height: 32),
          Text(
            'Bienvenidos',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 46, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Químic@',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: Color(0xFF14B8A6),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Tu app de Química Pura para la universidad: resolver, estudiar, practicar y llegar con tips al examen.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, height: 1.5),
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
                  const Text('•  ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(p, style: const TextStyle(fontSize: 17, height: 1.4))),
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
    required this.onFinish,
  });
  final TextEditingController nameController;
  final String? gender;
  final ValueChanged<String> onGenderChanged;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    // Todo centrado, y la caja del nombre es lo más grande y visible
    // de la pantalla: texto grande, borde grueso en teal y centrada.
    const teal = Color(0xFF14B8A6);
    // El relleno de abajo crece con el teclado abierto, así el botón
    // Finalizar se puede subir por encima del teclado desplazando.
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
          const Text(
            'Un último paso',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Dinos cómo te llamas para saludarte cada vez que entres. Todo se guarda en tu teléfono, sin internet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, height: 1.5),
          ),
          const SizedBox(height: 32),
          const Text(
            'Nombre de usuario',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: teal),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Por ejemplo: Ana',
              hintStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.normal,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
          const Text('Género', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              ChoiceChip(
                label: const Text('Femenino'),
                selected: gender == 'Femenino',
                onSelected: (_) => onGenderChanged('Femenino'),
              ),
              ChoiceChip(
                label: const Text('Masculino'),
                selected: gender == 'Masculino',
                onSelected: (_) => onGenderChanged('Masculino'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onFinish,
              child: const Text('Finalizar', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
