import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpncuba/home_screen.dart';
import 'package:vpncuba/vpn_controller.dart';

// Capturas reales de la pantalla única en sus 3 estados, con fuentes
// reales precargadas (DejaVu como Roboto + MaterialIcons del SDK).
// Generar con: flutter test --update-goldens test/golden_test.dart
// Las PNG quedan en test/goldens/ y se revisan antes de compilar el APK.

Future<void> _loadRealFonts() async {
  // Nunito real de Quemia (la fuente de la familia).
  final nunito = FontLoader('Nunito');
  nunito.addFont(_readFile('assets/fonts/Nunito-Regular.ttf'));
  nunito.addFont(_readFile('assets/fonts/Nunito-SemiBold.ttf'));
  nunito.addFont(_readFile('assets/fonts/Nunito-Bold.ttf'));
  nunito.addFont(_readFile('assets/fonts/Nunito-ExtraBold.ttf'));
  await nunito.load();

  final icons = FontLoader('MaterialIcons');
  icons.addFont(_readFile(_findMaterialIconsFont()));
  await icons.load();
}

// La fuente MaterialIcons vive dentro del SDK de Flutter, pero su ruta
// absoluta cambia según dónde esté instalado (en esta máquina es
// /home/hatch/sdks/flutter-3.47.9/..., en el runner de GitHub Actions
// es otra). La versión anterior tenía la ruta fija y la compilación
// en la nube fallaba con PathNotFoundException. Ahora se busca: la
// ruta de esta máquina, FLUTTER_ROOT si existe, y subiendo desde el
// ejecutable que corre la prueba (flutter_tester o dart) hasta dar
// con la raíz del SDK.
String _findMaterialIconsFont() {
  const relative =
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final candidates = <String>[
    '/home/hatch/sdks/flutter-3.47.9/$relative',
  ];
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    candidates.add('$flutterRoot/$relative');
  }
  var dir = File(Platform.resolvedExecutable).parent;
  while (true) {
    final candidate = '${dir.path}/$relative';
    if (!candidates.contains(candidate)) candidates.add(candidate);
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) return candidate;
  }
  throw StateError(
      'MaterialIcons-Regular.otf no encontrado. Rutas buscadas:\n'
      '${candidates.join('\n')}');
}

Future<ByteData> _readFile(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.view(Uint8List.fromList(bytes).buffer);
}

void main() {
  setUpAll(_loadRealFonts);

  Future<void> pumpScreen(WidgetTester tester, VpnUiState state) async {
    tester.view.physicalSize = const ui.Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'Nunito',
          scaffoldBackgroundColor: const Color(0xFF0A1F1A),
          useMaterial3: true,
        ),
        home: HomeScreen(
          state: state,
          onToggle: () {},
          onShowAbout: () {},
        ),
      ),
    );
    await tester.pump();
    // El logo de anillo es un asset: precargarlo con tiempo real
    // (runAsync), si no la primera foto sale con el hueco vacío y
    // en las demás ya se ve (caché). Sin runAsync el await se cuelga:
    // la decodificación necesita tiempo real, no tiempo falso.
    await tester.runAsync(() => precacheImage(
          const AssetImage('assets/ring_logo.png'),
          tester.element(find.byType(HomeScreen)),
        ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('1) Desconectado: botón grande Conectar', (tester) async {
    await pumpScreen(
      tester,
      const VpnUiState(
        phase: VpnPhase.disconnected,
        statusText: 'Toca Conectar y listo',
        hint: 'La app busca sola el mejor servidor gratuito.',
      ),
    );
    expect(find.text('VPN CUBA'), findsOneWidget);
    expect(find.text('CONECTAR'), findsOneWidget);
    expect(find.text('Toca Conectar y listo'), findsOneWidget);
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/vpn_desconectado.png'),
    );
  });

  testWidgets('2) Buscando el servidor más rápido…', (tester) async {
    await pumpScreen(
      tester,
      const VpnUiState(
        phase: VpnPhase.searching,
        statusText: 'Buscando el mejor servidor…',
        hint: 'Probando servidores gratuitos…',
      ),
    );
    expect(find.text('BUSCANDO'), findsOneWidget);
    expect(find.text('Buscando el mejor servidor…'), findsOneWidget);
    // La rueda gira: avanzar el reloj para fotografiarla ya dibujada,
    // como se ve en el teléfono (en el primer fotograma es solo un punto).
    await tester.pump(const Duration(milliseconds: 800));
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/vpn_buscando.png'),
    );
  });

  testWidgets('3) Conectado: país + tiempo', (tester) async {
    await pumpScreen(
      tester,
      const VpnUiState(
        phase: VpnPhase.connected,
        statusText: '¡Ya estás protegido!',
        hint: 'Tu conexión pasa por otro país. Toca el botón para '
            'desconectar.',
        country: 'EE. UU.',
        ip: '203.0.113.42',
        elapsed: '02:34',
      ),
    );
    expect(find.text('DESCONECTAR'), findsOneWidget);
    expect(find.text('¡Ya estás protegido!'), findsOneWidget);
    expect(find.text('EE. UU.'), findsOneWidget);
    // Quitado por orden de Kristian (2026-11-15): la VPN no enlaza
    // ni abre Quemia, así que el botón ya no debe existir.
    expect(find.text('ABRIR QUEMIA'), findsNothing);
    expect(find.text('02:34'), findsOneWidget);
    expect(find.text('IP 203.0.113.42'), findsOneWidget);
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/vpn_conectado.png'),
    );
  });
}
