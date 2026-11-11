// Pruebas de la ronda fix3 2026-11-10 (punto 12: correcciones de
// contenido): renombres (Química física, Periodicidad, Enlace
// químico), nombres de los temas en MAYÚSCULAS en el camino y
// Química orgánica ampliada a 10 niveles.
//
// Nota: el slug interno 'tabla' no cambia (las claves guardadas de
// progreso —'level:tabla:N'— siguen valiendo); lo que cambia es el
// NOMBRE que se muestra. La pestaña inferior sigue siendo 'Tabla'.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/extra_content.dart';
import 'package:quimica_pura/data/i18n/content_en.dart';
import 'package:quimica_pura/data/i18n/content_fr.dart';
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/data/i18n/content_it.dart';
import 'package:quimica_pura/data/i18n/content_pt.dart';
import 'package:quimica_pura/data/i18n/content_ru.dart';
import 'package:quimica_pura/data/questions.dart';
import 'package:quimica_pura/data/search_index.dart';
import 'package:quimica_pura/data/topics.dart';
import 'package:quimica_pura/screens/branches_screen.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRobotoFonts);

  setUp(() async {
    // Reglas ya vistas: PracticarScreen.initState espera 900 ms y
    // abre el popup de reglas si no están vistas; sin el flag el
    // temporizador queda pendiente y el test cae en el teardown
    // aunque las expectativas pasen (patrón de fix3_test.dart).
    SharedPreferences.setMockInitialValues(
        {'melli_rules_seen_v6': true});
    await ProgressService.load();
    await UserPrefs.load();
  });

  group('Renombres: Química física', () {
    test('ningún título visible dice Fisicoquímica', () {
      for (final t in topics) {
        expect(t.title, isNot(contains('Fisicoquímica')), reason: t.slug);
      }
      for (final t in branchTopics) {
        expect(t.title, isNot(contains('Fisicoquímica')), reason: t.slug);
        for (final line in t.summary) {
          expect(line, isNot(contains('fisicoquímica')), reason: t.slug);
        }
      }
      expect(
        branchTopics
            .firstWhere((t) => t.slug == 'fisicoquimica')
            .title,
        'Química física: la física detrás de la química',
      );
      expect(
        branches.firstWhere((b) => b.slug == 'fisicoquimica').title,
        'Química física',
      );
      final entry = appScreens.firstWhere((s) => s.$1 == 'branches');
      expect(entry.$3, contains('Química física'));
      expect(entry.$3, isNot(contains('Fisicoquímica')));
    });

    test('el término es correcto en los 6 idiomas', () {
      expect(topicsEn['fisicoquimica']!.title,
          startsWith('Physical chemistry'));
      expect(topicsFr['fisicoquimica']!.title,
          startsWith('Chimie physique'));
      expect(topicsIt['fisicoquimica']!.title, startsWith('Chimica fisica'));
      expect(topicsPt['fisicoquimica']!.title, startsWith('Química física'));
      expect(topicsRu['fisicoquimica']!.title,
          startsWith('Физическая химия'));
      for (final m in [
        topicsEn['fisicoquimica']!.title,
        topicsFr['fisicoquimica']!.title,
        topicsIt['fisicoquimica']!.title,
        topicsPt['fisicoquimica']!.title,
        topicsRu['fisicoquimica']!.title,
      ]) {
        expect(m, isNot(contains('Fisicoquímica')));
        expect(m, isNot(contains('Physico-chimie')));
        expect(m, isNot(contains('Físico-química')));
      }
    });
  });

  group('Renombres: Periodicidad y Enlace químico', () {
    test('el tema tabla se muestra como Periodicidad, en 6 idiomas', () {
      expect(localizedTopicName('tabla'), 'Periodicidad');
      expect(localizedTopicTitle('tabla'), 'Periodicidad');
      expect(topicNamesEn['tabla'], 'Periodicity');
      expect(topicNamesFr['tabla'], 'Périodicité');
      expect(topicNamesIt['tabla'], 'Periodicità');
      expect(topicNamesPt['tabla'], 'Periodicidade');
      expect(topicNamesRu['tabla'], 'Периодичность');
    });

    test('el tema enlace se muestra como Enlace químico, en 6 idiomas',
        () {
      expect(localizedTopicName('enlace'), 'Enlace químico');
      expect(localizedTopicTitle('enlace'), 'Enlace químico');
      expect(topicNamesEn['enlace'], 'Chemical bonding');
      expect(topicNamesFr['enlace'], 'Liaison chimique');
      expect(topicNamesIt['enlace'], 'Legame chimico');
      expect(topicNamesPt['enlace'], 'Ligação química');
      expect(topicNamesRu['enlace'], 'Химическая связь');
    });
  });

  group('Química orgánica: 10 niveles', () {
    test('el banco de orgánica tiene 50 preguntas', () {
      final count =
          allQuestions.where((q) => q.topic == 'organica').length;
      expect(count, 50);
      expect(allQuestions.length, 210);
    });

    test('orgánica tiene 10 niveles (solo de banco, sin generador)', () {
      expect(ProgressService.levelCountForTopic('organica'), 10);
      // Sin generador: el repaso de una fallada del banco sigue sin
      // variante generada (v6_logic_test lo exige).
      expect(topicNames['organica'], 'Química orgánica');
    });

    test('los demás temas no cambian su número de niveles', () {
      expect(ProgressService.levelCountForTopic('laboratorio'), 4);
      expect(ProgressService.levelCountForTopic('tabla'), 5);
      expect(ProgressService.levelCountForTopic('enlace'), 5);
      expect(ProgressService.levelCountForTopic('estequiometria'), 6);
    });

    test('las preguntas nuevas cubren los 5 bloques pedidos', () {
      final qs = allQuestions
          .where((q) => q.topic == 'organica')
          .map((q) => q.question)
          .toList();
      // Grupos funcionales.
      expect(qs.any((q) => q.contains('−O− entre dos carbonos')), isTrue);
      expect(qs.any((q) => q.contains('−NH₂ corresponde')), isTrue);
      expect(qs.any((q) => q.contains('−C≡N')), isTrue);
      // Nomenclatura.
      expect(qs.any((q) => q.contains('nombre IUPAC del CH₃CH₂OH')),
          isTrue);
      expect(qs.any((q) => q.contains('sufijo −oico')), isTrue);
      // Reacciones.
      expect(qs.any((q) => q.contains('Markovnikov')), isTrue);
      expect(qs.any((q) => q.contains('nitración del benceno')), isTrue);
      // Isomería / estereoquímica.
      expect(qs.any((q) => q.contains('mezcla racémica')), isTrue);
      expect(qs.any((q) => q.contains('2 carbonos quirales distintos')),
          isTrue);
      // Obtención.
      expect(qs.any((q) => q.contains('fermentación de la glucosa')),
          isTrue);
      expect(qs.any((q) => q.contains('saponificación')), isTrue);
      expect(qs.any((q) => q.contains('craqueo del petróleo')), isTrue);
    });

    test('todas las preguntas de orgánica tienen respuesta válida', () {
      for (final q in allQuestions.where((q) => q.topic == 'organica')) {
        expect(q.answer, inInclusiveRange(0, 3), reason: q.question);
        expect(q.options.length, 4, reason: q.question);
        expect(q.options.toSet().length, 4, reason: q.question);
      }
    });
  });

  group('Volumen molar a TPEA (punto 18)', () {
    test('Constantes tiene dos entradas de Vm: 22.4 y 24.8 L/mol', () {
      final vm = chemConstants.where((c) => c.symbol == 'Vm').toList();
      expect(vm.length, 2);
      expect(vm[0].value, '22.4 L·mol⁻¹');
      expect(vm[0].note, 'Volumen molar en condiciones normales');
      expect(vm[1].value, '24.8 L·mol⁻¹');
      expect(vm[1].note, 'Volumen molar a TPEA (25 °C y 1 atm)');
    });

    test('el tema Gases tiene la fórmula de TPEA', () {
      final gases = topics.firstWhere((t) => t.slug == 'gases');
      final f = gases.formulas.firstWhere(
        (f) => f.name == 'Condiciones estándar (TPEA)',
      );
      expect(f.expr, '25 °C y 1 atm → 24.8 L/mol');
      expect(f.note, 'Volumen molar a TPEA (25 °C, 1 atm)');
      expect(localizedTopic(gases).formulas.any(
          (f) => f.name == 'Condiciones estándar (TPEA)'), isTrue);
    });

    test('el glosario de Volumen molar menciona TPEA', () {
      final term = glossary.firstWhere((g) => g.term == 'Volumen molar');
      expect(term.definition, contains('24.8 L a TPEA (25 °C y 1 atm)'));
      expect(localizedGlossaryTerm(term).definition,
          contains('24.8 L a TPEA (25 °C y 1 atm)'));
    });

    test('TPEA está localizado en los 6 idiomas', () {
      expect(
        topicsEn['gases']!.formulas
            .any((f) => f.expr.contains('24.8 L/mol')),
        isTrue,
      );
      expect(
        topicsFr['gases']!.formulas
            .any((f) => f.expr.contains('24.8 L/mol')),
        isTrue,
      );
      expect(
        topicsIt['gases']!.formulas
            .any((f) => f.expr.contains('24.8 L/mol')),
        isTrue,
      );
      expect(
        topicsPt['gases']!.formulas
            .any((f) => f.expr.contains('24.8 L/mol')),
        isTrue,
      );
      expect(
        topicsRu['gases']!.formulas
            .any((f) => f.expr.contains('24.8 L/mol')),
        isTrue,
      );
      expect(constantNotesEn['Volumen molar a TPEA (25 °C y 1 atm)'],
          'Molar volume at SATP (25 °C and 1 atm)');
      expect(
        glossaryEn['Volumen molar']!.definition,
        contains('24.8 L at SATP (25 °C and 1 atm)'),
      );
      expect(
        glossaryFr['Volumen molar']!.definition,
        contains('24.8 L à TPEA (25 °C et 1 atm)'),
      );
      expect(
        glossaryPt['Volumen molar']!.definition,
        contains('24,8 L em TPEA (25 °C e 1 atm)'),
      );
    });
  });

  group('Mayúsculas en el camino', () {
    testWidgets('la cabecera del camino muestra el tema en mayúsculas',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(
            body: PracticarScreen(onOpenScreen: _noop),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ESTEQUIOMETRÍA Y EL MOL'), findsOneWidget);
      expect(find.text('Estequiometría y el mol'), findsNothing);
      // Subtítulo "Nivel N de M" también en mayúsculas.
      expect(find.textContaining('NIVEL 1 DE 6'), findsOneWidget);
      expect(find.textContaining('Nivel 1 de 6'), findsNothing);
    });
  });
}

void _noop(String key) {}
