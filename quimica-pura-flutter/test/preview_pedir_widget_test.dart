// Foto de la pantalla que pide el widget en el registro, para que
// Kristian la apruebe antes de construir nada (2026-11-18).
// La pantalla es un SIMULACRO local de este test (no existe en
// lib/ todavía): mismo patrón que las fotos de preview_* —
// vista 393x852, Nunito real, DuoButton de verdad. Solo genera la
// foto en ../../melli-qui-v6-previews/; no es un golden de
// regresión (no se compara en verde salvo que exista).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/widgets/duo_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// Simulacro de la pantalla «Pon Quemia en tu pantalla principal»:
/// miniatura del widget (la de verdad se verá así), título, cuerpo,
/// AGREGAR WIDGET + MÁS TARDE. Los valores son de ejemplo (racha 3,
/// meta cumplida); la pantalla real leerá los datos del usuario.
class _PedirWidgetPreview extends StatelessWidget {
  const _PedirWidgetPreview();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final bodyColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFF777777);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        // Miniatura del widget: así se verá en la
                        // pantalla principal (fondo noche, borde
                        // violeta, cara de Brenda, racha, tip, meta
                        // con barra, vidas y puntos).
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1628),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF8B5CF6),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 20,
                                    backgroundImage:
                                        AssetImage('assets/brenda.png'),
                                    backgroundColor: Colors.transparent,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Quemia',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Text(
                                    'Racha: 3',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFF9600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tip: Convierte todo a las unidades del SI antes de sustituir.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFFDE68A),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Row(
                                children: [
                                  Text(
                                    'Meta del día',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Spacer(),
                                  Text(
                                    '¡Meta cumplida!',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2DD4BF),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const ClipRRect(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(3)),
                                child: LinearProgressIndicator(
                                  value: 1,
                                  minHeight: 6,
                                  backgroundColor: Color(0xFF243447),
                                  valueColor: AlwaysStoppedAnimation(
                                    Color(0xFF14B8A6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Row(
                                children: [
                                  Text(
                                    'Vidas: 10/10',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                  Spacer(),
                                  Text(
                                    'Puntos: 120',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Pon Quemia en tu pantalla principal',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Agrega el widget y ve tu racha, tu meta del día y un tip sin abrir la app. Puedes hacerlo ahora o más tarde.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: bodyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: DuoButton.primary(
                  label: 'AGREGAR WIDGET',
                  onPressed: () {},
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: DuoButton.secondary(
                  label: 'MÁS TARDE',
                  onPressed: () {},
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadNunitoFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('pedir_widget: la pantalla con AGREGAR WIDGET y MÁS TARDE',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Nunito'),
        home: const _PedirWidgetPreview(),
      ),
    );
    // La cara de Brenda es un asset: precargarla antes de la foto
    // o la miniatura sale con el círculo vacío.
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(MaterialApp));
      await precacheImage(const AssetImage('assets/brenda.png'), ctx);
    });
    await tester.pumpAndSettle();
    expect(find.text('AGREGAR WIDGET'), findsOneWidget);
    expect(find.text('MÁS TARDE'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../melli-qui-v6-previews/pedir_widget.png'),
    );
  });
}
