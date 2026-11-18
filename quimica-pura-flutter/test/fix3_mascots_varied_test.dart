// Pruebas fix3 — mascotas (ronda #3; rediseño Duolingo 7.0):
// - Cabecera de Cuenta (alcance 9, 7.1): tarjeta redondeada con
//   el CÍRCULO GRANDE del avatar del usuario (96 dp, editable)
//   y la línea "Hoy te acompaña…" con su miniatura de compañera
//   (22 dp). El círculo grande ya NO es la compañera del día.
//   Sin selector de avatar propio viejo y sin repetir el nombre
//   bajo la foto.
// - Mensajes de los muñecos variados: 5 variantes por compañero
//   (Brenda, Britany, Kristian) y categoría (pregunta, ánimo,
//   consuelo) en los 6 idiomas, rotando sin repetirse seguidas;
//   MascotBubble muestra una variante. Los saludos se quitaron en
//   la ronda fix5: la burbuja NUNCA sustituye el texto por un
//   saludo y las claves mascotGreet*/mascotIntro* ya no existen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/avatar.dart';
import 'package:quimica_pura/widgets/social_avatar.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppLang.code = 'es';
    await ProgressService.load();
    await UserPrefs.load();
  });

  tearDown(() {
    AppLang.code = 'es';
  });

  group('Frases variadas: repertorio completo', () {
    test('5 variantes distintas por compañero y categoría', () {
      // Solo las categorías vivas (pregunta, ánimo, consuelo): el
      // saludo se quitó en la ronda fix5 y sus claves ya no existen.
      final kinds =
          MascotLine.values.where((k) => k != MascotLine.greet);
      for (final c in Companion.values) {
        for (final kind in kinds) {
          final keys = [
            for (var i = 0; i < mascotLineVariants; i++)
              mascotLineKeyAt(c, kind, i),
          ];
          expect(keys.toSet().length, mascotLineVariants);
          final texts = keys.map((k) => tr(k)).toList();
          expect(texts.toSet().length, mascotLineVariants,
              reason: '$c $kind');
          expect(texts.every((t) => t.isNotEmpty), isTrue);
        }
      }
    });

    test('las 45 claves existen en los 6 idiomas', () {
      final maps = AppLang.allStrings;
      final kinds =
          MascotLine.values.where((k) => k != MascotLine.greet);
      for (final c in Companion.values) {
        for (final kind in kinds) {
          for (var i = 0; i < mascotLineVariants; i++) {
            final key = mascotLineKeyAt(c, kind, i);
            for (final lang in ['es', 'en', 'fr', 'it', 'pt', 'ru']) {
              expect(maps[lang]!.containsKey(key), isTrue,
                  reason: '$lang $key');
              expect(maps[lang]![key]!.isNotEmpty, isTrue);
            }
          }
        }
      }
    });

    test('preguntar/ánimo/consuelo: 5 variantes distintas en los 6 idiomas',
        () {
      // El saludo se quitó en la ronda fix5; estas 3 categorías son
      // las que la burbuja muestra de verdad.
      final kinds =
          MascotLine.values.where((k) => k != MascotLine.greet);
      for (final lang in ['es', 'en', 'fr', 'it', 'pt', 'ru']) {
        AppLang.code = lang;
        for (final c in Companion.values) {
          for (final kind in kinds) {
            final texts = [
              for (var i = 0; i < mascotLineVariants; i++)
                tr(mascotLineKeyAt(c, kind, i)),
            ];
            expect(texts.toSet().length, mascotLineVariants,
                reason: '$lang $c $kind');
            expect(texts.every((t) => t.isNotEmpty), isTrue);
          }
        }
      }
      AppLang.code = 'es';
    });
  });

  group('Rotación sin repeticiones seguidas', () {
    test('10 turnos seguidos: nunca la misma dos veces seguidas y cubre las 5',
        () {
      const c = Companion.kristian;
      const kind = MascotLine.console;
      final seq = [
        for (var t = 0; t < 10; t++) mascotLineKey(c, kind, t),
      ];
      for (var i = 1; i < seq.length; i++) {
        expect(seq[i], isNot(seq[i - 1]), reason: 'turno $i');
      }
      expect(seq.sublist(0, 5).toSet().length, 5);
      expect(seq.sublist(5).toSet().length, 5);
    });

    test('mismo turno, misma frase (estable al reconstruir la pantalla)',
        () {
      const c = Companion.britany;
      const kind = MascotLine.ask;
      final first = mascotLineKey(c, kind, 42);
      expect(mascotLineKey(c, kind, 42), first);
      expect(mascotLineKey(c, kind, 43), isNot(first));
    });
  });

  group('Cabecera de Cuenta', () {
    Future<void> pumpAccount(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          // 2026-11-16: la pantalla COMPLETA (AccountProfilePage),
          // no solo el cuerpo: el título "Cuenta" vive en la
          // AppBar (el nombre bajo la foto se quitó: aparece UNA
          // vez, en el título).
          home: AccountProfilePage(
            onOpenScreen: (_) {},
            onShowAbout: () {},
            onShowShareApp: () {},
            trackTopics: const ['estequiometria'],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets(
        'círculo grande del avatar del usuario (160 dp), sin la '
        'línea de la compañera ni selector viejo',
        (tester) async {
      await pumpAccount(tester);
      // Alcance 9 (7.1): el círculo grande de la cabecera ES el
      // avatar del usuario (SocialAvatar de 160 dp, con su lápiz;
      // 96 dp hasta el perfil estilo Duolingo de 2026-11-16),
      // ya NO la compañera del día. La línea "Hoy te acompaña…"
      // con su miniatura (22 dp) ya NO está en Cuenta (arreglo
      // 2026-11-16 23:2x, punto 9 del reporte de errores de la
      // 7.8): ni CompanionAvatar ni su texto salen aquí.
      expect(find.byType(SocialAvatar), findsOneWidget);
      expect(tester.getSize(find.byType(SocialAvatar)),
          const Size(160, 160));
      expect(find.byType(CompanionAvatar), findsNothing);
      expect(find.textContaining('Hoy te acompaña'), findsNothing);
      // Sin avatar dibujado con código ni selector viejo.
      expect(find.byType(MelliAvatar), findsNothing);
      expect(find.text(tr('accountAvatarTitle')), findsNothing);
      expect(find.text(tr('accountAvatarHint')), findsNothing);
      // El título sigue como texto (sin nombre guardado, el título
      // de la AppBar muestra "Cuenta": el nombre aparece UNA vez,
      // en el título, desde el lote de 11 puntos).
      expect(find.text(tr('accountTitle')), findsOneWidget);
    });

    testWidgets('día de Kristian: foto teal + "Hoy te acompaña Kristian"',
        (tester) async {
      // AccountScreen lee el reloj real, así que el día de Kristian
      // se comprueba con su misma construcción (misma API y mismo
      // tamaño): compañero del 2026-11-05, foto 48 y línea.
      final companion = companionOfTheDay(DateTime(2026, 11, 5));
      expect(companion, Companion.kristian);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                CompanionAvatar(companion: companion, size: 48),
                Text(tr(companionOfDayKey(companion))),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CompanionAvatar), findsOneWidget);
      expect(tester.getSize(find.byType(CompanionAvatar)),
          const Size(48, 48));
      expect(find.text('Hoy te acompaña Kristian'), findsOneWidget);
      expect(companionAccent(companion), const Color(0xFF00C2A8));
    });
  });

  group('MascotBubble con frases variadas', () {
    testWidgets('la burbuja de pregunta muestra una variante que rota',
        (tester) async {
      // Ya presentado (sin saludo): la burbuja muestra el texto que
      // se le pasa, que ahora es una variante rotativa.
      await UserPrefs.saveMetTwin(true);
      final text = tr(mascotLineKey(
          Companion.brenda, MascotLine.ask, 7));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MascotBubble(
              companion: Companion.brenda,
              text: text,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(text), findsOneWidget);
      // Sin firma "— Brenda" (se quitó en la ronda fix5).
      expect(find.text('— Brenda'), findsNothing);
    });

    testWidgets('la burbuja muestra SIEMPRE el texto que se le pasa',
        (tester) async {
      // Rondas fix5: la burbuja NUNCA sustituye el texto por un
      // saludo — foto y texto siempre del mismo acompañante.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MascotBubble(
              companion: Companion.brenda,
              text: 'Texto fijo que debe salir',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Texto fijo que debe salir'), findsOneWidget);
      expect(find.text('¡Hola! Soy Brenda'), findsNothing);
      expect(find.text('— Brenda'), findsNothing);
      expect(find.text('Brenda'), findsNothing);
    });
  });
}
