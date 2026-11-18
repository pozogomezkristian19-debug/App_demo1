// Marcos 3D (7.9): AvatarFrameRing dibuja relieve y luz según el
// tipo de marco — metal con brillo y sombra, fuego con llamas,
// arcoíris — y sin marco enseña solo el hijo, sin anillo.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/shop_item.dart';
import 'package:quimica_pura/widgets/avatar_frame_ring.dart';

void main() {
  Future<void> pumpRing(WidgetTester tester, ShopItem? frame) async {
    await tester.pumpWidget(
      MaterialApp(
        // Sin el banner DEBUG: su CustomPaint contaminaría la
        // búsqueda del pintor del anillo.
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: AvatarFrameRing(
              frame: frame,
              ringWidth: 8,
              photoSize: 80,
              child: const SizedBox(
                width: 80,
                height: 80,
                child: ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  String? painterName(WidgetTester tester) {
    final found = find.byType(CustomPaint);
    if (found.evaluate().isEmpty) return null;
    final painter = tester.widget<CustomPaint>(found.first).painter;
    return painter?.runtimeType.toString();
  }

  testWidgets('sin marco: solo el hijo, sin anillo', (tester) async {
    await pumpRing(tester, null);
    expect(find.byType(CustomPaint), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('marco dorado: imagen recortada de la foto (no pintor)',
      (tester) async {
    await pumpRing(
      tester,
      const ShopItem(
        id: 'frame_dorado_3d',
        name: 'Marco Dorado 3D',
        kind: 'frame',
        price: 500,
        color: 0xFFFFD700,
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CustomPaint), findsNothing);
  });

  testWidgets('marco plata: pintor de metal con su color', (tester) async {
    await pumpRing(
      tester,
      const ShopItem(
        id: 'frame_plata',
        name: 'Marco Plata 3D',
        kind: 'frame',
        price: 400,
        color: 0xFFD6D6D6,
      ),
    );
    expect(painterName(tester), contains('Metal'));
  });

  testWidgets('marco fuego: imagen recortada de la foto (no pintor)',
      (tester) async {
    await pumpRing(
      tester,
      const ShopItem(
        id: 'frame_fuego',
        name: 'Marco Fuego 3D',
        kind: 'frame',
        price: 400,
        color: 0xFFFF6B00,
        badgeIcon: 'fire',
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CustomPaint), findsNothing);
  });

  testWidgets('marco arcoíris: pintor arcoíris (badgeIcon rainbow)',
      (tester) async {
    await pumpRing(
      tester,
      const ShopItem(
        id: 'frame_arcoiris',
        name: 'Marco Arcoíris',
        kind: 'frame',
        price: 600,
        badgeIcon: 'rainbow',
      ),
    );
    expect(painterName(tester), contains('Rainbow'));
  });

  test('paddingFor: el marco-imagen es una fracción de la foto', () {
    const fire = ShopItem(
      id: 'frame_fuego',
      name: 'Marco Fuego 3D',
      kind: 'frame',
      price: 400,
      badgeIcon: 'fire',
    );
    const gold = ShopItem(
      id: 'frame_dorado_3d',
      name: 'Marco Dorado 3D',
      kind: 'frame',
      price: 500,
      color: 0xFFFFD700,
    );
    // Con foto de 80: fuego 80 × 100/790, dorado 80 × 100/680.
    expect(AvatarFrameRing.paddingFor(fire, 8, photoSize: 80),
        closeTo(10.13, 0.01));
    expect(AvatarFrameRing.paddingFor(gold, 8, photoSize: 80),
        closeTo(11.76, 0.01));
    // Sin foto, el respaldo viejo: fuego 8 × 1.75 = 14, metal 8.
    expect(AvatarFrameRing.paddingFor(fire, 8), 14);
    expect(AvatarFrameRing.paddingFor(gold, 8), 8);
    expect(AvatarFrameRing.paddingFor(null, 8), 8);
  });

  testWidgets('marco fuego: el cuadro crece con el halo de la foto',
      (tester) async {
    await pumpRing(
      tester,
      const ShopItem(
        id: 'frame_fuego',
        name: 'Marco Fuego 3D',
        kind: 'frame',
        price: 400,
        badgeIcon: 'fire',
      ),
    );
    // Foto 80 + halo 10.13 a cada lado = 100.25.
    final ring = tester.getSize(find.byType(AvatarFrameRing));
    expect(ring.width, closeTo(100.25, 0.1));
    expect(ring.height, closeTo(100.25, 0.1));
  });

  testWidgets('marco dorado: el cuadro crece con el aire de la foto',
      (tester) async {
    await pumpRing(
      tester,
      const ShopItem(
        id: 'frame_dorado_3d',
        name: 'Marco Dorado 3D',
        kind: 'frame',
        price: 500,
        color: 0xFFFFD700,
      ),
    );
    // Foto 80 + anillo 11.76 a cada lado = 103.53.
    final ring = tester.getSize(find.byType(AvatarFrameRing));
    expect(ring.width, closeTo(103.53, 0.1));
    expect(ring.height, closeTo(103.53, 0.1));
  });
}
