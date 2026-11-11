// Pruebas fix3 (2026-11-10, punto 17): en Ramas de la química, si
// la rama tiene UN SOLO tema, tocarla abre DIRECTO el detalle de
// ese tema (TopicDetailScreen), sin la pantalla intermedia de la
// rama (BranchDetailScreen), que solo repetía el mismo nombre en
// una tarjeta. Hoy solo Orgánica tiene un tema ('organica'); las
// demás (Inorgánica, Analítica, Química física) siguen abriendo su
// pantalla intermedia con la lista de temas. La regla es general:
// depende de topicSlugs.length == 1, no de la rama.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/branches_screen.dart';
import 'package:quimica_pura/screens/topic_detail_screen.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
  });

  Future<void> pumpScreen(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: child,
      ),
    );
    await tester.pump();
  }

  group('Ramas: un solo tema se abre directo', () {
    testWidgets('tocar Orgánica abre TopicDetailScreen, sin pantalla '
        'intermedia', (tester) async {
      await pumpScreen(tester, const BranchesScreen());
      // La lista sigue mostrando las 4 ramas igual que antes.
      expect(find.text('Química orgánica'), findsOneWidget);
      expect(find.text('Química inorgánica'), findsOneWidget);
      expect(find.text('Química analítica'), findsOneWidget);
      expect(find.text('Química física'), findsOneWidget);

      await tester.tap(find.text('Química orgánica'));
      // Bombeos acotados (no pumpAndSettle): la transición de
      // navegación dura 300 ms y así no se depende de que toda
      // animación ambiental se aquiete.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TopicDetailScreen), findsOneWidget);
      expect(find.byType(BranchDetailScreen), findsNothing);
      // Es el tema de orgánica, con su contenido (resumen).
      final topic = findTopic('organica')!;
      expect(find.text(topic.summary.first), findsOneWidget);
    });

    testWidgets('tocar Inorgánica sigue abriendo su pantalla '
        'intermedia con sus temas', (tester) async {
      await pumpScreen(tester, const BranchesScreen());
      await tester.tap(find.text('Química inorgánica'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BranchDetailScreen), findsOneWidget);
      expect(find.byType(TopicDetailScreen), findsNothing);
      // La pantalla intermedia muestra la descripción y los temas.
      final branch =
          branches.firstWhere((b) => b.slug == 'inorganica');
      expect(find.text(branch.body), findsOneWidget);
      for (final slug in branch.topicSlugs) {
        expect(find.text(findTopic(slug)!.title), findsOneWidget);
      }
    });

    testWidgets('la regla es general: hoy solo Orgánica tiene un '
        'tema', (tester) async {
      final single = branches.where((b) => b.topicSlugs.length == 1);
      expect(single.map((b) => b.slug), ['organica']);
      final multi = branches.where((b) => b.topicSlugs.length > 1);
      expect(multi.map((b) => b.slug).toList(),
          ['inorganica', 'analitica', 'fisicoquimica']);
    });
  });
}
