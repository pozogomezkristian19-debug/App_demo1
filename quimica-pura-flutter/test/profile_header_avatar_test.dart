// Cabecera de perfil dinámica (7.9): sin animación equipada, el
// avatar va CENTRADO; con animación, avatar a la IZQUIERDA y
// animación a la DERECHA del mismo alto. Al quitar la animación,
// el avatar vuelve a centrarse enseguida.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/shop_item.dart';
import 'package:quimica_pura/widgets/profile_animation.dart';

const _dragon = ShopItem(
  id: 'anim_dragon',
  name: 'Dragón dorado',
  kind: 'animation',
  price: 800,
  color: 0xFFFFC800,
);

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    required ShopItem? Function() resolveAnimation,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ProfileHeaderAvatar(
              size: 120,
              resolveAnimation: resolveAnimation,
              avatar: (s) => SizedBox(
                key: const ValueKey('avatar'),
                width: s,
                height: s,
                child: const ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('sin animación: avatar centrado, sin Lottie', (tester) async {
    await pumpHeader(tester, resolveAnimation: () => null);
    expect(find.byKey(const ValueKey('avatar')), findsOneWidget);
    expect(find.byType(ProfileAnimation), findsNothing);
    // La cabecera es un Center, no una fila.
    expect(find.byType(Row), findsNothing);
  });

  testWidgets('con animación: fila con avatar y animación del mismo alto',
      (tester) async {
    await pumpHeader(tester, resolveAnimation: () => _dragon);
    expect(find.byKey(const ValueKey('avatar')), findsOneWidget);
    expect(find.byType(ProfileAnimation), findsOneWidget);
    expect(find.byType(Row), findsOneWidget);
    // La animación mide lo mismo que la foto (120 dp).
    final animation = tester.widget<ProfileAnimation>(
        find.byType(ProfileAnimation));
    expect(animation.size, 120);
  });

  testWidgets('al quitar la animación, el avatar vuelve a centrarse',
      (tester) async {
    var equipped = true;
    await pumpHeader(
        tester, resolveAnimation: () => equipped ? _dragon : null);
    expect(find.byType(ProfileAnimation), findsOneWidget);

    // Quitar (como al pulsar «Quitar» en la Tienda): la cabecera
    // se reconstruye con la animación en null.
    equipped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ProfileHeaderAvatar(
              size: 120,
              resolveAnimation: () => equipped ? _dragon : null,
              avatar: (s) => SizedBox(
                key: const ValueKey('avatar'),
                width: s,
                height: s,
                child: const ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ProfileAnimation), findsNothing);
    expect(find.byType(Row), findsNothing);
    expect(find.byKey(const ValueKey('avatar')), findsOneWidget);
  });

  testWidgets(
      'con marco Dorado y animación en un teléfono de 393 dp: no se sale',
      (tester) async {
    // El Dorado es el marco más grueso: el avatar con marco mide
    // 1.294 × la foto. Con el cálculo viejo (/ 2) la fila sumaba
    // 207 + 16 + 160 = 383 > 361 y el dragón quedaba fuera de la
    // pantalla (overflow de 22 px, 2026-11-18).
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ProfileHeaderAvatar(
              size: 160,
              resolveAnimation: () => _dragon,
              avatar: (s) => SizedBox(
                key: const ValueKey('avatar'),
                width: s * 1.294,
                height: s * 1.294,
                child: const ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    final animation = tester.widget<ProfileAnimation>(
        find.byType(ProfileAnimation));
    expect(animation.size, closeTo(150, 0.01));
  });
}
