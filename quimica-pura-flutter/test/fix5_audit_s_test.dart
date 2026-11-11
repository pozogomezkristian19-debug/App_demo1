// Tests de la auditoría propia (ronda #5, Quemia 6.2, grupo
// Solucionadores): un grupo por hallazgo, con los ejemplos del
// informe en ~/workspace/goals/pure-chemistry-app-in-flutter/
// hidden_files/auditoria-propia-2026-11-11.md. NO importa
// practicar_screen.dart ni main.dart (el árbol está roto por otro
// agente): solo los servicios y las pantallas de Resolver que toca
// este grupo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/resolver_extra.dart';
import 'package:quimica_pura/screens/resolver_screen.dart';
import 'package:quimica_pura/services/advanced_solvers.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadMaterialIcons();
  });

  Future<void> pumpSolver(WidgetTester tester, Widget solver) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [solver, const SizedBox(height: 16)],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapCalculate(WidgetTester tester, [String label = 'Calcular']) async {
    await tester.ensureVisible(find.text(label));
    await tester.pump();
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> selectDropdown(
    WidgetTester tester,
    String current,
    String option,
  ) async {
    await tester.ensureVisible(find.text(current));
    await tester.pump();
    await tester.tap(find.text(current));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  Future<void> enterField(
    WidgetTester tester,
    int index,
    String value,
  ) async {
    await tester.enterText(find.byType(TextField).at(index), value);
    await tester.pump();
  }

  // ---------- A1: potenciométrica con pH bajando ----------
  group('A1 potentiometric', () {
    test('pH bajando: el salto mayor esta entre 20 y 25 mL (Veq 22.5)', () {
      final r = potentiometric(
        volumesMl: const [0, 10, 20, 25, 30, 40],
        ph: const [12.0, 11.5, 10.0, 5.0, 4.0, 3.0],
      );
      expect(r.error, isNull);
      expect(r.summary, contains('22.5'));
    });

    test('pH subiendo: tambien elige el salto mayor', () {
      final r = potentiometric(
        volumesMl: const [0, 10, 20, 25, 30, 40],
        ph: const [2.0, 2.5, 4.0, 9.0, 10.0, 10.5],
      );
      expect(r.error, isNull);
      expect(r.summary, contains('22.5'));
    });
  });

  // ---------- A10: coma decimal en la potenciométrica ----------
  group('A10 potentiometric coma decimal', () {
    testWidgets('"24,9" es 24.9, no 24 y 9', (tester) async {
      await pumpSolver(tester, const PotentiometricSolver());
      await enterField(tester, 0, '0, 10, 20, 24,9, 25');
      await enterField(tester, 1, '12.0, 11.5, 10.0, 5.0, 4.0');
      await tapCalculate(tester);
      // 5 volúmenes y 5 pH: si "24,9" se partiera en dos, las
      // listas tendrían distinta longitud y saldría el error.
      expect(find.textContaining('24.95'), findsOneWidget);
      expect(find.textContaining('Escribe al menos 3 pares'), findsNothing);
    });
  });

  // ---------- A11: retroceso ----------
  group('A11 backTitration', () {
    test('ejemplo nuevo (NaOH 31 mL) da 95.1 %, un valor posible', () {
      final r = backTitration(
        sampleMassG: 0.5,
        molarMass: 100.09,
        cHcl: 0.5,
        vHclMl: 50,
        cNaoh: 0.5,
        vNaohMl: 31,
        hclPerAnalyte: 2,
      );
      expect(r.error, isNull);
      expect(r.summary, contains('95.1 %'));
      expect(r.summary, isNot(contains('Revisa los datos')));
    });

    test('el ejemplo viejo (NaOH 30 mL) da >100 % y avisa', () {
      final r = backTitration(
        sampleMassG: 0.5,
        molarMass: 100.09,
        cHcl: 0.5,
        vHclMl: 50,
        cNaoh: 0.5,
        vNaohMl: 30,
        hclPerAnalyte: 2,
      );
      expect(r.error, isNull);
      expect(r.summary, contains('100.1 %'));
      expect(r.summary, contains('Revisa los datos'));
      expect(r.lines.any((l) => l.contains('Revisa los datos')), isTrue);
    });

    testWidgets('el ejemplo por defecto de la pantalla da 95.1 %',
        (tester) async {
      await pumpSolver(tester, const TitrationSolver());
      await selectDropdown(
        tester,
        'Ácido-base fuerte-fuerte',
        'Por retroceso (exceso + retitulación)',
      );
      await tapCalculate(tester);
      expect(
          find.text('La muestra contiene 95.1 % de analito (0.4754 g)'),
          findsOneWidget);
    });
  });

  // ---------- A12: mezcla de dos ácidos débiles ----------
  group('A12 mixturePh', () {
    test('dos ácidos débiles 0.1 M con Ka 1e-5: pH 2.85, no 2.70', () {
      final r = mixturePh(
        const MixtureComponent(
            kind: MixtureKind.weakAcid, c: 0.1, k: 1e-5),
        const MixtureComponent(
            kind: MixtureKind.weakAcid, c: 0.1, k: 1e-5),
      );
      expect(r.error, isNull);
      expect(r.summary, contains('2.85'));
    });

    test('dos bases débiles 0.1 M con Kb 1e-5: pH 11.15', () {
      final r = mixturePh(
        const MixtureComponent(
            kind: MixtureKind.weakBase, c: 0.1, k: 1e-5),
        const MixtureComponent(
            kind: MixtureKind.weakBase, c: 0.1, k: 1e-5),
      );
      expect(r.error, isNull);
      expect(r.summary, contains('11.15'));
    });

    test('mezcla de fuertes sin cambios (0.1 + 0.05 M: pH 0.82)', () {
      final r = mixturePh(
        const MixtureComponent(kind: MixtureKind.strongAcid, c: 0.1),
        const MixtureComponent(kind: MixtureKind.strongAcid, c: 0.05),
      );
      expect(r.error, isNull);
      expect(r.summary, contains('0.82'));
    });
  });

  // ---------- A16: la conversión mL -> L se ve en los pasos ----------
  group('A16 conversion mL a L en los pasos', () {
    test('titrationStrongStrong muestra "mol/L x mL ÷ 1000"', () {
      final r = titrationStrongStrong(ca: 0.1, vaMl: 25, cb: 0.1, vbMl: 25);
      expect(r.lines.first, contains('÷ 1000'));
      expect(r.lines.first, isNot(contains('0.1 × 25 mL =')));
    });

    test('titrationRedox muestra "mol/L x mL ÷ 1000"', () {
      final r = titrationRedox(
          cFe: 0.1, vFeMl: 25, cMnO4: 0.02, vAddedMl: 25);
      expect(r.lines[1], contains('÷ 1000'));
    });

    test('backTitration muestra "mol/L x mL ÷ 1000" en las dos líneas', () {
      final r = backTitration(
        sampleMassG: 0.5,
        molarMass: 100.09,
        cHcl: 0.5,
        vHclMl: 50,
        cNaoh: 0.5,
        vNaohMl: 31,
        hclPerAnalyte: 2,
      );
      expect(r.lines[0], contains('÷ 1000'));
      expect(r.lines[1], contains('÷ 1000'));
    });
  });

  // ---------- A18: los básicos rechazan negativos ----------
  group('A18 basicos rechazan negativos', () {
    testWidgets('Gas ideal: P = -1 protesta', (tester) async {
      await pumpSolver(tester, const GasSolver());
      await enterField(tester, 0, '-1');
      await enterField(tester, 2, '2');
      await enterField(tester, 3, '300');
      await tapCalculate(tester);
      expect(find.textContaining('Revisa los datos'), findsOneWidget);
    });

    testWidgets('Molaridad: n = -2 protesta', (tester) async {
      await pumpSolver(tester, const MolaritySolver());
      await enterField(tester, 0, '-2');
      await enterField(tester, 1, '1');
      await tapCalculate(tester);
      expect(find.textContaining('Revisa los datos'), findsOneWidget);
    });

    testWidgets('Dilución: C1 = -1 protesta', (tester) async {
      await pumpSolver(tester, const DilutionSolver());
      await enterField(tester, 0, '-1');
      await enterField(tester, 1, '10');
      await enterField(tester, 2, '0.1');
      await tapCalculate(tester, 'Calcular el dato que falta');
      expect(find.textContaining('Revisa los datos'), findsOneWidget);
    });

    testWidgets('Masa-moles: m = -5 protesta', (tester) async {
      await pumpSolver(tester, const MassMolesSolver());
      await enterField(tester, 0, '-5');
      await enterField(tester, 1, '18');
      await tapCalculate(tester);
      expect(find.textContaining('Revisa los datos'), findsOneWidget);
    });

    testWidgets('Limitante: moles de A = -3 protestan', (tester) async {
      await pumpSolver(tester, const LimitingSolver());
      await enterField(tester, 0, '1');
      await enterField(tester, 1, '-3');
      await enterField(tester, 2, '1');
      await enterField(tester, 3, '2');
      await tapCalculate(tester, 'Encontrar el limitante');
      expect(find.textContaining('Revisa los datos'), findsOneWidget);
    });

    testWidgets('pH = 0 es válido en modo pH', (tester) async {
      await pumpSolver(tester, const PhSolver());
      await selectDropdown(tester, 'Concentración [H⁺] (mol/L)', 'pH');
      await enterField(tester, 0, '0');
      await tapCalculate(tester, 'Calcular pH y pOH');
      expect(find.textContaining('[H⁺] = 1 mol/L'), findsOneWidget);
      expect(find.textContaining('Revisa los datos'), findsNothing);
    });

    testWidgets('pero [H+] = 0 sigue rechazándose', (tester) async {
      await pumpSolver(tester, const PhSolver());
      await enterField(tester, 0, '0');
      await tapCalculate(tester, 'Calcular pH y pOH');
      expect(find.textContaining('Revisa los datos'), findsOneWidget);
    });
  });

  // ---------- A20: anión anfiprótico ----------
  group('A20 saltPh anfiprotico', () {
    test('NaHCO3 (Ka1 4.5e-7, Ka2 4.7e-11): pH 8.34', () {
      final r = saltPh(
        kind: SaltKind.amphiproticAnion,
        c: 0.1,
        ka: 4.5e-7,
        ka2: 4.7e-11,
      );
      expect(r.error, isNull);
      expect(r.summary, contains('8.34'));
    });

    test('con las Ka de libro 4.3e-7 / 5.6e-11: pH 8.31', () {
      final r = saltPh(
        kind: SaltKind.amphiproticAnion,
        c: 0.1,
        ka: 4.3e-7,
        ka2: 5.6e-11,
      );
      expect(r.error, isNull);
      expect(r.summary, contains('8.31'));
    });

    test('sin Ka2 avisa de que faltan datos', () {
      final r = saltPh(
        kind: SaltKind.amphiproticAnion,
        c: 0.1,
        ka: 4.5e-7,
      );
      expect(r.error, isNotNull);
      expect(r.error, contains('Ka'));
    });

    testWidgets('el modo existe en la pantalla y da 8.34 por defecto',
        (tester) async {
      await pumpSolver(tester, const SaltPhSolver());
      await selectDropdown(
        tester,
        'Ácido débil + base fuerte (básica)',
        'Anión anfiprótico (HCO₃⁻, H₂PO₄⁻)',
      );
      await tapCalculate(tester);
      expect(find.text('pH ≈ 8.34  (anión anfiprótico)'), findsOneWidget);
    });
  });
}
