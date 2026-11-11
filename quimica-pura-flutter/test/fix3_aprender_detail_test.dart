// Pruebas fix3 (2026-11-10, punto 15): en Aprender, tocar un tema
// ya no despliega la lección dentro de la tarjeta (ExpansionTile):
// abre su pantalla propia completa (TopicDetailScreen, la misma que
// usan las Ramas de la química y la búsqueda). La tarjeta queda
// limpia: título y nivel. Nada de contenido se pierde: la pantalla
// del tema tiene resumen, fórmulas, moléculas, ejemplo con pasos,
// errores, consejo y favorito (y el cuestionario de laboratorio
// cuando toca).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/data/topics.dart';
import 'package:quimica_pura/models.dart';
import 'package:quimica_pura/screens/aprender_screen.dart';
import 'package:quimica_pura/screens/topic_detail_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/widgets/molecule_diagrams.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// Primer tema que muestra la lista de Aprender (sin Orgánica ni
/// Laboratorio, que viven en el menú de hamburguesa).
StudyTopic firstLearnTopic() => localizedTopic(topics.firstWhere(
    (t) => t.slug != 'organica' && t.slug != 'laboratorio'));

  void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
  });

  Future<void> pumpScreen(WidgetTester tester, Widget child) async {
    // Ventana muy alta: Aprender y TopicDetailScreen son ListView y
    // solo construyen lo que cabe en la ventana (+caché); con la
    // ventana normal (720x1600) las tarjetas y el contenido de abajo
    // no existen en el árbol y los finders no los encuentran aunque
    // el contenido esté bien. Con 10000 px lógicos cabe todo el
    // tema más largo.
    tester.view.physicalSize = const Size(720, 20000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        // Scaffold: sin Material encima, el texto cae en el estilo
        // de emergencia del framework (monoespaciada 48, roja con
        // doble subrayado amarillo) y cada tema mide ~3x más que en
        // el teléfono: la cola (consejo, botones) no cabía ni en la
        // ventana alta y los finders del final no la encontraban.
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  group('Aprender: tarjetas limpias sin despliegue inline', () {
    testWidgets('no queda ningún ExpansionTile', (tester) async {
      await pumpScreen(tester, const AprenderScreen());
      expect(find.byType(ExpansionTile), findsNothing);
      // La tarjeta sigue mostrando título y nivel.
      final topic = firstLearnTopic();
      expect(find.text(topic.title), findsOneWidget);
      expect(find.text(topic.level), findsAtLeastNWidgets(1));
    });

    testWidgets('tocar un tema abre su pantalla propia',
        (tester) async {
      await pumpScreen(tester, const AprenderScreen());
      final topic = firstLearnTopic();
      final titleFinder = find.text(topic.title).first;
      await tester.ensureVisible(titleFinder);
      await tester.pumpAndSettle();
      await tester.tap(titleFinder);
      await tester.pumpAndSettle();
      expect(find.byType(TopicDetailScreen), findsOneWidget);
      // El contenido de la lección está en la pantalla del tema:
      // resumen, ejemplo y consejo, más la estrellita de favorito.
      expect(find.text(topic.summary.first), findsOneWidget);
      expect(find.text(topic.exampleAnswer), findsOneWidget);
      expect(find.textContaining(topic.tip), findsOneWidget);
      expect(find.byTooltip('Favorito'), findsOneWidget);
    });
  });

  group('TopicDetailScreen: ningún contenido se pierde', () {
    testWidgets('todos los temas muestran resumen, fórmulas, ejemplo,'
        ' errores y consejo', (tester) async {
      for (final raw in topics) {
        final topic = localizedTopic(raw);
        await pumpScreen(tester, TopicDetailView(topic: raw));
        expect(find.text(topic.level), findsOneWidget,
            reason: 'nivel del tema ${topic.slug}');
        for (final p in topic.summary) {
          expect(find.text(p), findsOneWidget,
              reason: 'resumen del tema ${topic.slug}');
        }
        expect(find.text(tr('formulasWord')), findsOneWidget,
            reason: 'fórmulas del tema ${topic.slug}');
        for (final f in topic.formulas) {
          expect(find.text('• ${f.name}: ${f.expr} — ${f.note}'),
              findsOneWidget,
              reason: 'fórmula ${f.name} del tema ${topic.slug}');
        }
        expect(
            find.text('${tr('exampleWord')}: ${topic.exampleTitle}'),
            findsOneWidget,
            reason: 'ejemplo del tema ${topic.slug}');
        for (var i = 0; i < topic.exampleSteps.length; i++) {
          expect(find.text('${i + 1}. ${topic.exampleSteps[i]}'),
              findsOneWidget,
              reason: 'paso del ejemplo del tema ${topic.slug}');
        }
        expect(find.text(topic.exampleAnswer), findsOneWidget,
            reason: 'respuesta del tema ${topic.slug}');
        expect(find.text(tr('errorsWord')), findsOneWidget,
            reason: 'errores del tema ${topic.slug}');
        for (final e in topic.errors) {
          expect(find.text('• $e'), findsOneWidget,
              reason: 'error del tema ${topic.slug}');
        }
        expect(find.textContaining(topic.tip), findsOneWidget,
            reason: 'consejo del tema ${topic.slug}');
      }
    });

    testWidgets('los temas con moléculas muestran sus diagramas',
        (tester) async {
      final withMolecules =
          topics.where((t) => t.molecules.isNotEmpty).toList();
      expect(withMolecules, isNotEmpty);
      for (final raw in withMolecules) {
        await pumpScreen(tester, TopicDetailView(topic: raw));
        expect(find.byType(MoleculeCard),
            findsNWidgets(raw.molecules.length),
            reason: 'moléculas del tema ${raw.slug}');
      }
    });

    testWidgets('el tema de laboratorio ofrece su cuestionario',
        (tester) async {
      await pumpScreen(
          tester, TopicDetailView(topic: findTopic('laboratorio')!));
      expect(find.text(tr('labQuizButton')), findsOneWidget);
    });
  });
}
