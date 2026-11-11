// Pruebas de la ronda visual 2026-11-10 (fixes 1-7): geometría y
// presencia de widgets, sin capturar píxeles (toImage no corre en
// este entorno de pruebas).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/lives_chip.dart';
import 'package:quimica_pura/widgets/stats_card.dart';
import 'package:quimica_pura/widgets/support_button.dart';

void main() {
  testWidgets('fix 2: el botón Soporte no tiene ningún borde',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton:
              SupportButton(onPressed: () => tapped = true),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    // La decoración del botón es verde WhatsApp, píldora y sin borde.
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(SupportButton),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFF25D366));
    expect(decoration.border, isNull);
    expect(decoration.borderRadius,
        const BorderRadius.all(Radius.circular(999)));
    expect(find.text('Soporte'), findsOneWidget);
    await tester.tap(find.byType(SupportButton));
    expect(tapped, isTrue);
    // Y ya NO existe ningún FloatingActionButton en la app.
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('fix 1: el chip de vidas es corazón + número',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LivesChip(lives: 4, pulse: false)),
      ),
    );
    await tester.pump();
    expect(find.text('4'), findsOneWidget);
    expect(find.byType(LivesHeart), findsOneWidget);
    expect(find.text('4/5'), findsNothing);
  });

  testWidgets(
      'fix 3+4+6: Niveles sin tarjeta de estadísticas, sin banner, '
      'sin pregunta del día ni "Practicar de otra forma"',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // Sin la ventanita de reglas de la primera vez: si no, su
    // temporizador de 900 ms queda pendiente al final del test.
    UserPrefs.rulesSeenV6 = true;
    addTearDown(() => UserPrefs.rulesSeenV6 = false);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: PracticarScreen(onOpenScreen: (_) {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Sin tarjeta de estadísticas: ni Vidas ni Puntos ni Meta del día.
    expect(find.text('Vidas'), findsNothing);
    expect(find.text('Puntos'), findsNothing);
    expect(find.text('Meta del día'), findsNothing);
    // Sin banner "Hoy te acompaña…" en Niveles (fix4, punto 13
    // REVISADO: lo quitó Kristian); la pregunta del día se eliminó
    // por completo de la app en la ronda #6 y "Practicar de otra
    // forma" ya no está en Niveles: queda solo el camino.
    expect(find.textContaining('Hoy te acompaña'), findsNothing);
    expect(find.text('Pregunta del día'), findsNothing);
    expect(find.text('Practicar de otra forma'), findsNothing);

  });

  testWidgets('fix 3: Cuenta tiene UNA tarjeta de estadísticas, sin duplicar',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: AccountScreen(
            onOpenScreen: (_) {},
            onShowAbout: () {},
            onShowShareApp: () {},
            trackTopics: const ['estequiometria'],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(StatsCard), findsOneWidget);
    expect(find.text('Vidas'), findsOneWidget);
    expect(find.text('Puntos'), findsOneWidget);
    expect(find.text('Racha'), findsOneWidget);
    expect(find.text('Meta del día'), findsOneWidget);
    expect(find.text('Logros'), findsOneWidget);
    expect(find.byType(LivesHeart), findsWidgets);
  });
}
