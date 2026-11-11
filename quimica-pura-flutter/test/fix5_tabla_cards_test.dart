// Ronda #5, punto extra (Quemia 6.2): las dos tarjetas de acción
// de arriba ("Quiz de la tabla periódica" y "Comparar elementos")
// SOLO se muestran cuando el filtro es "Todos" (sin categoría
// seleccionada). En cuanto se activa cualquier filtro de categoría,
// las dos tarjetas DESAPARECEN y la tabla filtrada gana ese sitio;
// al volver a "Todos", reaparecen. Es el mismo patrón que ya tiene
// la leyenda (que solo sale con "Todos"). La búsqueda y los chips
// se quedan siempre. Vale para los tres modos (búsqueda, tabla
// normal y tabla angosta) porque _actionCards está en la cabecera
// común y devuelve SizedBox.shrink() con filtro activo.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/tabla_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (call) async => null,
    );
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
    UserPrefs.isDark = false;
    UserPrefs.onboardingDone = true;
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
  });

  Finder quizCard(WidgetTester tester) =>
      find.text(tr('tableQuizTitle'));
  Finder compareCard(WidgetTester tester) =>
      find.text(tr('compareTitle'));

  /// Las dos tarjetas de acción están visibles.
  void expectCardsVisible(WidgetTester tester) {
    expect(quizCard(tester), findsOneWidget);
    expect(compareCard(tester), findsOneWidget);
  }

  /// Las dos tarjetas de acción NO están en el árbol.
  void expectCardsHidden(WidgetTester tester) {
    expect(quizCard(tester), findsNothing);
    expect(compareCard(tester), findsNothing);
  }

  /// Toca el chip de una categoría (por su nombre en español).
  Future<void> tapCategoryChip(
      WidgetTester tester, String name) async {
    await tester.tap(
      find.widgetWithText(ChoiceChip, name),
    );
    await tester.pump();
  }

  /// Toca el chip "Todos".
  Future<void> tapAllChip(WidgetTester tester) async {
    await tester.tap(
      find.widgetWithText(ChoiceChip, tr('allWord')),
    );
    await tester.pump();
  }

  group('Tarjetas de acción solo con filtro "Todos" '
      '(fix5, punto extra)', () {
    testWidgets('con filtro Todos las dos tarjetas están visibles',
        (tester) async {
      await pumpTabla(tester, logicalWidth: 393, logicalHeight: 852);
      expectCardsVisible(tester);
      // La tabla completa está debajo: la rejilla y la leyenda.
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text(tr('legendWord')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('al activar "Metal alcalino" las tarjetas desaparecen '
        'y la tabla filtrada ocupa su sitio', (tester) async {
      await pumpTabla(tester, logicalWidth: 393, logicalHeight: 852);
      expectCardsVisible(tester);
      await tapCategoryChip(tester, 'Metal alcalino');
      expectCardsHidden(tester);
      // La lista filtrada: 6 alcalinos (Li, Na, K, Rb, Cs, Fr).
      expect(find.text('6 ${tr('elementsWord')}'), findsOneWidget);
      expect(find.text('Litio'), findsOneWidget);
      expect(find.text('Sodio'), findsOneWidget);
      // Nada que no sea alcalino: el hidrógeno no está en la lista.
      expect(find.text('Hidrógeno'), findsNothing);
      // La lista filtrada ocupa el sitio de las tarjetas: el
      // recuento empieza pegado a la fila de chips (menos de 40 px
      // por debajo de su borde inferior), sin el hueco de ~150 px
      // que dejaban las dos tarjetas.
      final chipsBottom =
          tester.getBottomRight(find.byType(ChoiceChip).first).dy;
      final countTop = tester.getTopLeft(
          find.text('6 ${tr('elementsWord')}')).dy;
      expect(countTop - chipsBottom, lessThan(40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('al volver a "Todos" las tarjetas reaparecen y vuelve '
        'la tabla completa', (tester) async {
      await pumpTabla(tester, logicalWidth: 393, logicalHeight: 852);
      await tapCategoryChip(tester, 'Metal alcalino');
      expectCardsHidden(tester);
      await tapAllChip(tester);
      expectCardsVisible(tester);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text(tr('legendWord')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con filtro activo la búsqueda y los chips siguen '
        'siempre visibles', (tester) async {
      await pumpTabla(tester, logicalWidth: 393, logicalHeight: 852);
      await tapCategoryChip(tester, 'Metal alcalino');
      expectCardsHidden(tester);
      // Campo de búsqueda y fila de chips, siempre.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, tr('allWord')),
          findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Metal alcalino'),
          findsOneWidget);
      // Buscar dentro del filtro sigue funcionando y las tarjetas
      // siguen ocultas mientras el filtro está activo.
      await tester.enterText(find.byType(TextField), 'litio');
      await tester.pump();
      expectCardsHidden(tester);
      expect(find.text('Litio'), findsOneWidget);
      expect(find.text('Sodio'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('solo buscar (sin filtro de categoría) NO oculta las '
        'tarjetas', (tester) async {
      await pumpTabla(tester, logicalWidth: 393, logicalHeight: 852);
      await tester.enterText(find.byType(TextField), 'oxígeno');
      await tester.pump();
      // Sin categoría seleccionada el filtro sigue siendo "Todos".
      expectCardsVisible(tester);
      expect(find.text('Oxígeno'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('otro filtro ("Gas noble") también oculta las tarjetas',
        (tester) async {
      await pumpTabla(tester, logicalWidth: 393, logicalHeight: 852);
      // El chip "Gas noble" queda fuera de la vista a la derecha:
      // hay que deslizar la fila de chips hasta él antes de tocarlo.
      final gasNobleChip = find.widgetWithText(ChoiceChip, 'Gas noble');
      await tester.ensureVisible(gasNobleChip);
      await tester.pumpAndSettle();
      await tester.tap(gasNobleChip);
      await tester.pump();
      expect(find.text('7 ${tr('elementsWord')}'), findsOneWidget);
      expect(find.text('Helio'), findsOneWidget);
      await tapAllChip(tester);
      expectCardsVisible(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('Modo angosto (fix5, punto extra)', () {
    testWidgets('a 320 px: con Todos las tarjetas están; con filtro '
        'desaparecen y vuelve la lista filtrada', (tester) async {
      await pumpTabla(tester, logicalWidth: 320, logicalHeight: 2000);
      expectCardsVisible(tester);
      await tapCategoryChip(tester, 'Metal alcalino');
      expectCardsHidden(tester);
      expect(find.text('6 ${tr('elementsWord')}'), findsOneWidget);
      expect(find.text('Litio'), findsOneWidget);
      // Búsqueda y chips siguen visibles también en angosto.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, tr('allWord')),
          findsOneWidget);
      await tapAllChip(tester);
      expectCardsVisible(tester);
      expect(find.byType(GridView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> pumpTabla(
  WidgetTester tester, {
  required double logicalWidth,
  required double logicalHeight,
}) async {
  tester.view.physicalSize = Size(logicalWidth * 2, logicalHeight * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(body: TablaScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}
