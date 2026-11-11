// Pruebas fix5 — punto de la mascota en preguntas (ronda #5):
// - MascotBubble: solo foto + burbuja con el mensaje. Sin el nombre
//   debajo de la foto y sin la firma "— Nombre" al pie de la
//   burbuja (antes el nombre se repetía 4 veces en el mismo sitio).
// - La burbuja muestra SIEMPRE el mensaje que le pasa el llamador
//   (widget.text): NUNCA un saludo, ni en la primera aparición del
//   acompañante ni al cambiar de acompañante entre preguntas. Los
//   saludos no tienen que ver con las preguntas — en las preguntas
//   la burbuja dice la pregunta o un ánimo ("tú puedes" y cosas
//   así). La lógica de presentación (_showIntro/_introKey y los
//   flags metBrenda/metBritany/metKristian) se eliminó de la
//   burbuja en esta ronda: al no sustituir nunca el texto, el bug
//   del nombre equivocado (foto de uno y "¡Hola! Soy…" de otro)
//   desaparece, y el saludo ya no se repite en cada pregunta.
// - Al cambiar de acompañante en la misma burbuja (Brenda →
//   Britany → Kristian, como al pasar de pregunta en un quiz),
//   foto y texto son del MISMO acompañante.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpBubble(
    WidgetTester tester, {
    Companion? companion,
    bool? twinA,
    String text = '¿Cuál es la masa molar del agua?',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MascotBubble(
              companion: companion,
              twinA: twinA ?? true,
              text: text,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Companion shownCompanion(WidgetTester tester) =>
      tester.widget<CompanionAvatar>(find.byType(CompanionAvatar)).companion;

  /// Ningún saludo "¡Hola! Soy…" en el árbol (de ningún
  /// acompañante): la burbuja nunca saluda.
  void expectNoGreeting(WidgetTester tester) {
    for (final c in Companion.values) {
      expect(find.text('¡Hola! Soy ${companionName(c)}'), findsNothing,
          reason: 'la burbuja nunca muestra el saludo de ${companionName(c)}');
    }
  }

  testWidgets(
      'la burbuja muestra siempre widget.text, nunca un saludo, '
      'ni en la primera aparición de cada acompañante', (tester) async {
    for (final c in Companion.values) {
      final message = 'Pregunta para ${companionName(c)}: ¿qué es un mol?';
      // Primera aparición de cada acompañante: sale el mensaje,
      // no el saludo.
      await pumpBubble(tester, companion: c, text: message);
      expect(find.text(message), findsOneWidget,
          reason: '${companionName(c)}: siempre widget.text');
      expectNoGreeting(tester);
      expect(shownCompanion(tester), c);
    }
  });

  testWidgets(
      'al cambiar de acompañante en la misma burbuja, foto y texto '
      'son del mismo acompañante y nunca sale un saludo', (tester) async {
    // Brenda pregunta.
    await pumpBubble(tester,
        companion: Companion.brenda, text: 'Brenda: ¿qué es un mol?');
    expect(find.text('Brenda: ¿qué es un mol?'), findsOneWidget);
    expectNoGreeting(tester);
    expect(shownCompanion(tester), Companion.brenda);
    // La MISMA burbuja pasa a Britany al pasar de pregunta: foto
    // de Britany y SU mensaje, no el saludo de nadie.
    await pumpBubble(tester,
        companion: Companion.britany, text: 'Britany: ¡tú puedes!');
    expect(find.text('Britany: ¡tú puedes!'), findsOneWidget);
    expect(find.text('Brenda: ¿qué es un mol?'), findsNothing);
    expectNoGreeting(tester);
    expect(shownCompanion(tester), Companion.britany);
    // La MISMA burbuja pasa a Kristian.
    await pumpBubble(tester,
        companion: Companion.kristian,
        text: 'Kristian: lee bien y dime qué piensas');
    expect(find.text('Kristian: lee bien y dime qué piensas'),
        findsOneWidget);
    expect(find.text('Britany: ¡tú puedes!'), findsNothing);
    expectNoGreeting(tester);
    expect(shownCompanion(tester), Companion.kristian);
    // Vuelta a Brenda: mensaje normal de Brenda, sin saludo.
    await pumpBubble(tester,
        companion: Companion.brenda, text: 'Brenda: ¡vamos, otra vez!');
    expect(find.text('Brenda: ¡vamos, otra vez!'), findsOneWidget);
    expectNoGreeting(tester);
    expect(shownCompanion(tester), Companion.brenda);
  });

  testWidgets('la burbuja muestra foto + mensaje, sin nombre debajo '
      'de la foto ni firma', (tester) async {
    const message = '¿Cuál es la masa molar del agua?';
    for (final c in Companion.values) {
      await pumpBubble(tester, companion: c, text: message);
      // La foto sigue.
      expect(find.byType(CompanionAvatar), findsOneWidget);
      expect(shownCompanion(tester), c);
      // El mensaje sigue.
      expect(find.text(message), findsOneWidget);
      // Ni el nombre debajo de la foto…
      expect(find.text(companionName(c)), findsNothing,
          reason: 'sin etiquetita con el nombre bajo la foto');
      // …ni la firma al pie de la burbuja.
      expect(find.text('— ${companionName(c)}'), findsNothing,
          reason: 'sin firma "— ${companionName(c)}" en la burbuja');
      // Ningún texto del árbol dice el nombre del acompañante.
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        expect(t.data?.contains(companionName(c)) ?? false, isFalse,
            reason: 'ningún texto debe decir ${companionName(c)}');
      }
    }
  });

  testWidgets('tampoco con el parámetro antiguo twinA (Britany)',
      (tester) async {
    const message = '¿Qué es un mol?';
    await pumpBubble(tester, twinA: false, text: message);
    expect(find.byType(CompanionAvatar), findsOneWidget);
    expect(shownCompanion(tester), Companion.britany);
    expect(find.text(message), findsOneWidget);
    expect(find.text('Britany'), findsNothing);
    expect(find.text('— Britany'), findsNothing);
  });
}
