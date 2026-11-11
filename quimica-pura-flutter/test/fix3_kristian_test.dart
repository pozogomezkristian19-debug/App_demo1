// Pruebas de la ronda fix3 2026-11-10 (punto 11: Kristian, el
// tercer compañero, junto a Brenda y Britany): la rotación del
// compañero del día es de tres, el banner dice "Hoy te
// acompaña Kristian" el día que le toca y su burbuja muestra el
// texto que se le pasa, sin saludo, sin firma y sin nombre (ronda
// fix5). Las gemelas no cambian nada: Brenda sigue violeta y
// Britany azul.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRobotoFonts);

  group('Rotación de 3 compañeros', () {
    test('companionOfTheDay cubre a los tres en 3 días seguidos', () {
      final days = {
        companionOfTheDay(DateTime(2026, 11, 3)),
        companionOfTheDay(DateTime(2026, 11, 4)),
        companionOfTheDay(DateTime(2026, 11, 5)),
      };
      expect(
        days,
        {Companion.brenda, Companion.britany, Companion.kristian},
      );
    });

    test('companionForTurn rota por turnos: Brenda, Britany, Kristian',
        () {
      expect(companionForTurn(0), Companion.brenda);
      expect(companionForTurn(1), Companion.britany);
      expect(companionForTurn(2), Companion.kristian);
      expect(companionForTurn(3), Companion.brenda);
      expect(companionForTurn(5), Companion.kristian);
    });

    test('Kristian: nombre, acento teal y su imagen', () {
      expect(companionName(Companion.kristian), 'Kristian');
      expect(companionAccent(Companion.kristian), BrandColors.teal);
      expect(companionAsset(Companion.kristian), 'assets/kristian.png');
    });

    test('las gemelas no cambian: Brenda violeta, Britany azul', () {
      expect(companionName(Companion.brenda), 'Brenda');
      expect(companionAccent(Companion.brenda), BrandColors.violet);
      expect(companionAsset(Companion.brenda), 'assets/brenda.png');
      expect(companionName(Companion.britany), 'Britany');
      expect(companionAccent(Companion.britany), BrandColors.blue);
      expect(companionAsset(Companion.britany), 'assets/britany.png');
    });

    test('claves de Kristian: banner y presentación', () {
      expect(companionOfDayKey(Companion.kristian), 'twinOfDayKristian');
      expect(
        tr(companionOfDayKey(Companion.kristian)),
        'Hoy te acompaña Kristian',
      );
      expect(companionIntroKey(Companion.kristian), 'mascotIntroKristian');
      // La clave de presentación ya no existe en los idiomas (el
      // saludo se quitó en la ronda fix5): tr devuelve la clave.
      expect(tr(companionIntroKey(Companion.kristian)),
          'mascotIntroKristian');
    });

    test('la API antigua sigue funcionando (compatibilidad)', () {
      // Día de Brenda → true; días de Britany y Kristian → false.
      expect(twinOfTheDay(DateTime(2026, 11, 3)), isTrue);
      expect(twinOfTheDay(DateTime(2026, 11, 4)), isFalse);
      expect(twinOfTheDay(DateTime(2026, 11, 5)), isFalse);
      expect(twinOfDayKey(true), 'twinOfDayBrenda');
      expect(twinOfDayKey(false), 'twinOfDayBritany');
      expect(twinName(true), 'Brenda');
      expect(twinName(false), 'Britany');
    });
  });

  group('Kristian en la UI', () {
    // La burbuja NUNCA muestra un saludo (ronda fix5): siempre el
    // texto que se le pasa, sin nombre ni firma.
    testWidgets('la burbuja de Kristian muestra el texto, sin saludo',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await UserPrefs.load();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MascotBubble(
              companion: Companion.kristian,
              text: 'Vamos a practicar',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Vamos a practicar'), findsOneWidget);
      expect(find.text('¡Hola! Soy Kristian'), findsNothing);
      // Sin etiqueta de nombre junto al avatar.
      expect(find.text('Kristian'), findsNothing);
    });

    testWidgets('la burbuja de Kristian no lleva firma "— Kristian"',
        (tester) async {
      SharedPreferences.setMockInitialValues({'melli_met_kristian': true});
      await UserPrefs.load();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MascotBubble(
              companion: Companion.kristian,
              text: 'Vamos a practicar',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Vamos a practicar'), findsOneWidget);
      expect(find.text('— Kristian'), findsNothing);
      expect(find.text('Kristian'), findsNothing);
    });

    testWidgets('banner "Hoy te acompaña Kristian" con su avatar',
        (tester) async {
      final companion = companionOfTheDay(DateTime(2026, 11, 5));
      expect(companion, Companion.kristian);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                CompanionAvatar(companion: companion, size: 36),
                Text(tr(companionOfDayKey(companion))),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Hoy te acompaña Kristian'), findsOneWidget);
      expect(find.byType(CompanionAvatar), findsOneWidget);
      expect(
        tester.getSize(find.byType(CompanionAvatar)),
        const Size(36, 36),
      );
    });

    testWidgets('KristianAvatar: cuadrado, sin deformar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KristianAvatar(size: 40),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(KristianAvatar)),
        const Size(40, 40),
      );
    });

    test('la presentación de Kristian se guarda en el teléfono', () async {
      SharedPreferences.setMockInitialValues({});
      await UserPrefs.load();
      expect(UserPrefs.metKristian, isFalse);
      await UserPrefs.saveMetKristian();
      expect(UserPrefs.metKristian, isTrue);
      await UserPrefs.load();
      expect(UserPrefs.metKristian, isTrue);
    });
  });
}
