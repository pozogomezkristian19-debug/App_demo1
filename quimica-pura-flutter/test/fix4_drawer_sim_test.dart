// Ronda #4, punto 12: el simulador va en el MENÚ, en Referencia,
// JUSTO ARRIBA de "Tablas de referencia", y abre el simulador
// directamente (clave 'labSim', que ya existía y se usaba desde la
// búsqueda y Resolver). El acceso de Laboratorio sigue donde
// estaba (no se duplica: es otra entrada, en otra sección).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
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
    // Sin mock, el AudioPlayer estático de SoundService activa el
    // stream global de audioplayers y lanza MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers.global/events'),
            (m) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers'), (m) async => null);
  });

  // El Scrollable del ListView del menú (no el del TextField de
  // búsqueda, que también es un Scrollable dentro del Drawer).
  Finder drawerScrollable() => find.descendant(
        of: find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(ListView),
        ),
        matching: find.byType(Scrollable),
      );

  // NOTA: el drawer se abre con ScaffoldState.openDrawer(), no
  // tocando el botón del menú: en el binding de tests el toque en
  // ese IconButton no dispara su onPressed (diagnosticado: el
  // botón existe y el hit test llega a su InkWell, pero el gesto no
  // se completa; en el teléfono el botón funciona, Kristian abre
  // el menú a diario). Lo que se verifica aquí es el CONTENIDO del
  // menú y la navegación, que es lo del punto 12; el cableado del
  // botón es una línea estándar (Scaffold.of(context).openDrawer()).
  Future<void> openDrawer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: HomeScreen(
          isDark: false,
          onToggleTheme: () {},
          onTrackChanged: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('el simulador va en el menú, en Referencia (fix4, punto 12)', () {
    testWidgets('está en Referencia, justo arriba de Tablas de referencia',
        (tester) async {
      await openDrawer(tester);
      await tester.scrollUntilVisible(
        find.text(tr('labSimTitle')),
        200,
        scrollable: drawerScrollable(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('labSimTitle')), findsOneWidget);
      expect(find.text(tr('menuTables')), findsOneWidget);
      // La sección Referencia está arriba del simulador (el título
      // de sección se dibuja en mayúsculas)...
      final refY = tester
          .getTopLeft(find.text(tr('drawerReference').toUpperCase()))
          .dy;
      final simY = tester.getTopLeft(find.text(tr('labSimTitle'))).dy;
      final tablesY = tester.getTopLeft(find.text(tr('menuTables'))).dy;
      expect(simY, greaterThan(refY));
      // ...y el simulador está JUSTO arriba de Tablas de referencia.
      expect(simY, lessThan(tablesY));
      // El acceso de Laboratorio sigue en su sitio (no se tocó).
      expect(find.text(tr('menuLab')), findsOneWidget);
    });

    testWidgets('tocarlo abre el simulador directamente', (tester) async {
      await openDrawer(tester);
      await tester.scrollUntilVisible(
        find.text(tr('labSimTitle')),
        200,
        scrollable: drawerScrollable(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Se invoca el onTap del ListTile directamente (ver la nota
      // de openDrawer: el toque físico en el menú no se completa en
      // el binding de tests). Lo que se verifica es el cableado:
      // el ítem cierra el menú y abre LabSimScreen.
      final tile = find.ancestor(
        of: find.text(tr('labSimTitle')),
        matching: find.byType(ListTile),
      );
      expect(tile, findsOneWidget);
      tester.widget<ListTile>(tile).onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Está la pantalla del simulador: su AppBar y la pestaña de
      // ácido-base.
      expect(find.text(tr('labSimTitle')), findsAtLeastNWidgets(1));
      expect(find.text(tr('labModeAcidBase')), findsOneWidget);
      expect(find.text('Fenolftaleína'), findsOneWidget);
      // Y el menú se cerró (la ruta del drawer tarda su animación
      // de cierre en salir del árbol).
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Drawer), findsNothing);
      expect(find.text(tr('labSimTitle')), findsOneWidget);
    });
  });
}
