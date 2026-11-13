// Atrás de Android en el panel: desde cualquier sección del drawer
// (Usuarios, Avisos, Editor, Reportes, Soporte, Administradores, Ajustes)
// el botón atrás vuelve al Panel de inicio; solo estando YA en el Panel
// sale de la app. Antes, las secciones se cambiaban con setState sin
// apilar ninguna ruta, así que el botón atrás cerraba la app desde
// cualquier sección (reportado por Kristian 2026-11-12 en la Admin 7.1;
// el mismo defecto que reportó el 2026-11-10 en la app principal).
//
// Firebase se inicializa con un mock del host API de firebase_core: sin
// él, ni GoogleAuthService() ni PushService.shared se pueden construir en
// tests ([core/no-app]). Los repositorios son los fakes de siempre.
//
// Semántica de handlePopRoute()/maybePop() (verificada en el SDK):
// devuelve true cuando el atrás quedó CONSUMIDO (el PopScope lo vetó y
// el shell volvió al Panel) y false cuando NO lo consume nadie, caso en
// el que Android cierra la app vía SystemNavigator.pop(). Por eso los
// tests afirman sobre ese valor MÁS el estado visible.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/auth_service.dart';
import 'package:quemia_admin/repositories.dart';
import 'package:quemia_admin/screens.dart';

import 'test_data.dart';

/// Host API falso de firebase_core: sin él, ni GoogleAuthService() ni
/// PushService.shared se pueden construir en tests ([core/no-app]).
class _FakeCoreHostApi implements TestFirebaseCoreHostApi {
  CoreFirebaseOptions get _options => CoreFirebaseOptions(
    apiKey: 'fake-api-key',
    appId: '1:1234567890:android:fakeappid',
    messagingSenderId: '1234567890',
    projectId: 'fake-project',
  );

  CoreInitializeResponse _response(String name) => CoreInitializeResponse(
    name: name,
    options: _options,
    pluginConstants: <String, Object?>{},
  );

  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions request,
  ) async => _response(appName);

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
    _response('[DEFAULT]'),
  ];

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async => _options;
}

Future<void> _pumpShell(WidgetTester tester) async {
  // Vista de teléfono real: sin ella, el drawer se mide con la fuente
  // de pruebas (mucho más ancha que Nunito) y sus filas desbordan.
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: quemiaAdminTheme(),
      home: HomeShell(
        me: ownerRecord(),
        authService: GoogleAuthService(),
        users: FakeUsersRepository(seedUsers()),
        admins: FakeAdminsRepository([ownerRecord()]),
        settings: FakeSettingsRepository(),
        levels: FakeLevelsRepository(),
        announcements: FakeAnnouncementsRepository(),
        reports: FakeReportsRepository(),
        support: FakeSupportRepository(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  // HomeShell registra el token FCM con un timeout de 10 s que en tests
  // nunca se resuelve: dejarlo pendiente hace fallar el test al final
  // ("A Timer is still pending"). Se agota aquí, en tiempo falso.
  await tester.pump(const Duration(seconds: 11));
}

/// Título visible en la AppBar del shell (no el del drawer ni el cuerpo).
void _expectAppBarTitle(String title) {
  expect(
    find.descendant(of: find.byType(AppBar), matching: find.text(title)),
    findsOneWidget,
  );
}

/// El shell sigue vivo (la app NO se cerró).
void _expectShellAlive() => expect(find.byType(HomeShell), findsOneWidget);

/// Abre el drawer y toca el destino con esa etiqueta. Algunos destinos
/// (Ajustes) quedan bajo el pliegue en pantallas cortas: se hace scroll
/// dentro del drawer hasta dejarlo visible, como haría un usuario.
/// La etiqueta se busca SOLO dentro del Drawer: el Panel tiene tarjetas
/// de acción con los mismos títulos (Usuarios, Ajustes...).
Future<void> _goToSection(WidgetTester tester, String label) async {
  final drawerItem = find.descendant(
    of: find.byType(Drawer),
    matching: find.text(label),
  );
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
  // El drawer es perezoso: los destinos de abajo (Ajustes) no existen
  // en el árbol hasta hacer scroll. Primero scrollUntilVisible para que
  // aparezca y luego ensureVisible lo deja totalmente visible
  // (scrollUntilVisible solo se conforma con que asome 1 px, pero el
  // centro seguiría tapado por el pie y el tap fallaría).
  await tester.scrollUntilVisible(
    drawerItem,
    200,
    scrollable: find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(drawerItem);
  await tester.pumpAndSettle();
  await tester.tap(drawerItem);
  // El drawer tarda ~250 ms en cerrarse: con pumps acotados el velo
  // aún cubre la pantalla y el siguiente tap no llega a la fila.
  await tester.pumpAndSettle();
}

/// Simula el botón atrás de Android. true = consumido por la app (no
/// sale); false = nadie lo consumió, Android cerraría la app.
/// pumpAndSettle: la salida de una ruta apilada tarda ~300 ms y con
/// pumps acotados la pantalla seguiría en el árbol al afirmar.
Future<bool> _pressSystemBack(WidgetTester tester) async {
  final consumed = await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  return consumed;
}

void main() {
  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FakeCoreHostApi());
    await Firebase.initializeApp();
    // flutter_test no carga las fuentes del pubspec: sin Nunito, el texto
    // se mide con la fuente de pruebas y el drawer desborda (artefacto
    // del test, en el teléfono cabe). Igual que en preview_test.dart.
    final loader = FontLoader('Nunito');
    for (final asset in [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-SemiBold.ttf',
      'assets/fonts/Nunito-Bold.ttf',
      'assets/fonts/Nunito-ExtraBold.ttf',
    ]) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  });

  group('atrás de Android (PopScope del shell)', () {
    testWidgets('desde Usuarios, atrás vuelve al Panel', (tester) async {
      await _pumpShell(tester);
      _expectAppBarTitle('Panel');

      await _goToSection(tester, 'Usuarios');
      _expectAppBarTitle('Usuarios');
      expect(find.text('Buscar por nombre…'), findsOneWidget);

      final consumed = await _pressSystemBack(tester);
      expect(consumed, isTrue, reason: 'atrás desde Usuarios no cierra la app');
      _expectShellAlive();
      _expectAppBarTitle('Panel');
    });

    testWidgets('desde Ajustes, atrás vuelve al Panel', (tester) async {
      await _pumpShell(tester);
      await _goToSection(tester, 'Ajustes');
      // Antes SettingsScreen traía su propio Scaffold con AppBar 'Ajustes
      // remotos' anidado (doble barra); desde el arreglo 2026-11-13 solo
      // queda la barra del shell, así que el título aparece una vez.
      _expectAppBarTitle('Ajustes remotos');

      final consumed = await _pressSystemBack(tester);
      expect(consumed, isTrue, reason: 'atrás desde Ajustes no cierra la app');
      _expectShellAlive();
      _expectAppBarTitle('Panel');
    });

    testWidgets('en el Panel, atrás sí sale de la app', (tester) async {
      await _pumpShell(tester);
      _expectAppBarTitle('Panel');

      final consumed = await _pressSystemBack(tester);
      expect(
        consumed,
        isFalse,
        reason: 'atrás en el Panel no lo consume nadie: Android sale',
      );
    });

    testWidgets('una sola barra: Ajustes, Avisos, Editor, Reportes y Soporte', (
      tester,
    ) async {
      // Regresión del arreglo 2026-11-13 (doble barra): esas secciones
      // traían su propio Scaffold con AppBar anidado dentro del AppBar
      // del shell. Ahora solo queda la barra del shell.
      await _pumpShell(tester);
      for (final (label, title) in [
        ('Ajustes', 'Ajustes remotos'),
        ('Avisos', 'Avisos'),
        ('Editor de contenido', 'Editor de contenido'),
        ('Reportes', 'Reportes'),
        ('Soporte', 'Soporte'),
      ]) {
        await _goToSection(tester, label);
        expect(
          find.byType(AppBar),
          findsOneWidget,
          reason: 'doble barra en $label',
        );
        _expectAppBarTitle(title);
      }
    });

    testWidgets(
      'detalle apilado: atrás cierra el detalle y luego vuelve al Panel',
      (tester) async {
        await _pumpShell(tester);
        await _goToSection(tester, 'Usuarios');
        _expectAppBarTitle('Usuarios');

        // Abrir el detalle de un usuario (ruta apilada con Navigator.push).
        // Se toca la primera fila ('rosa', la más reciente): la lista es
        // ListView.builder y las filas de abajo aún no están construidas,
        // así que buscar 'laura' obligaría a adivinar qué Scrollable es
        // el de la lista (hay dos ListView y el TextField trae otro).
        await tester.tap(find.text('rosa').first);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(UserDetailScreen), findsOneWidget);

        // Primer atrás: cierra el detalle, sigue en Usuarios.
        var consumed = await _pressSystemBack(tester);
        expect(consumed, isTrue, reason: 'atrás cierra el detalle apilado');
        expect(find.byType(UserDetailScreen), findsNothing);
        _expectShellAlive();
        _expectAppBarTitle('Usuarios');

        // Segundo atrás: de Usuarios vuelve al Panel, no sale de la app.
        consumed = await _pressSystemBack(tester);
        expect(consumed, isTrue);
        _expectShellAlive();
        _expectAppBarTitle('Panel');
      },
    );
  });
}
