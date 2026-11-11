// Ronda #6: Resolver sin duplicados.
// Resolver queda SOLO con los solvers: el Formulario rápido y el
// Simulador de laboratorio se quitan de aquí porque ya viven en el
// menú hamburguesa. Los solvers siguen abriéndose como antes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/screens/resolver_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
    await UserPrefs.load();
    await ProgressService.load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers.global/events'),
            (m) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers'), (m) async => null);
  });

  Future<void> pumpResolver(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: ResolverScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Título de un solver DENTRO de su tarjeta: el nombre también
  // aparece en los chips de grupo y en el encabezado del grupo
  // (p. ej. "Valoraciones"), y scrollUntilVisible no sirve aquí
  // porque hay dos Scrollable en la pantalla (la lista y la fila de
  // chips): se desliza a mano hasta que la tarjeta aparece.
  Finder solverCardTitle(String title) => find.descendant(
        of: find.byType(Card),
        matching: find.text(title),
      );

  Future<void> revealSolver(WidgetTester tester, String title) async {
    final cardTitle = solverCardTitle(title);
    for (var i = 0; i < 40 && cardTitle.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pump();
    }
    expect(cardTitle, findsWidgets);
    await tester.ensureVisible(cardTitle.first);
    await tester.pumpAndSettle();
  }

  testWidgets('Resolver muestra los 14 solvers', (tester) async {
    await pumpResolver(tester);
    for (final entry in solverEntries) {
      final title =
          localizedSolver(entry.id)?.title ?? entry.title;
      await revealSolver(tester, title);
    }
  });

  testWidgets(
      'Resolver NO muestra ni el Simulador de laboratorio ni el '
      'Formulario rápido', (tester) async {
    await pumpResolver(tester);
    expect(find.text(tr('labSimTitle')), findsNothing);
    expect(find.text(tr('menuFormulas')), findsNothing);
    expect(find.text(tr('labSimCardSub')), findsNothing);
    expect(find.text(tr('formulaCardSub')), findsNothing);
    // Ni siquiera deslizando hasta el final aparecen.
    await tester.fling(
        find.byType(ListView), const Offset(0, -500), 1000);
    await tester.pumpAndSettle();
    expect(find.text(tr('labSimTitle')), findsNothing);
    expect(find.text(tr('menuFormulas')), findsNothing);
  });

  testWidgets('tocar un solver lo abre como antes', (tester) async {
    await pumpResolver(tester);
    final first = solverEntries.first;
    final title =
        localizedSolver(first.id)?.title ?? first.title;
    await revealSolver(tester, title);
    await tester.tap(solverCardTitle(title).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // El solver de masa molar se abre con su campo de fórmula.
    expect(find.text('Fórmula química'), findsOneWidget);
  });
}
