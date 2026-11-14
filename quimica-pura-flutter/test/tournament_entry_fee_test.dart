// Tests de entrada con puntos a los torneos (Quemia 7.7, Kristian):
// varios torneos cuestan puntos, salir NO devuelve la entrada.
// Todo contra InMemorySocialRepository (sin Firestore real).
//
// Semillas del repo (seedDemo: true): t1 gratis y ya unido,
// t2 "Torneo de Gases" entrada 25 (no unido), t3 entrada 50
// (próximo, no unido).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/tournaments_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late InMemorySocialRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    UserPrefs.userName = 'kristian';
    repo = InMemorySocialRepository(seedDemo: true);
    SocialService.setRepositoryForTests(repo);
    AnalyticsSync.resetForTests();
  });

  tearDown(() {
    SocialService.resetForTests();
    AnalyticsSync.resetForTests();
    UserPrefs.userName = '';
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(360, 1000),
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: screen,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> _settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<TournamentInfo> _tournament(String id) async =>
      (await SocialService.tournaments()).firstWhere((t) => t.id == id);

  group('entrada con puntos', () {
    testWidgets('entrar a un torneo gratis no descuenta puntos',
        (tester) async {
      // t1 está unido en la semilla: se siembra uno gratis sin unir.
      repo.setTournamentsForTests([
        const TournamentInfo(
          id: 't-gratis',
          title: 'Torneo de Bienvenida',
          topic: 'Estequiometría',
          dateRange: '13–20 nov',
          questionCount: 10,
          prizePoints: 50,
          entryFee: 0,
          status: 'active',
        ),
      ]);
      ProgressService.instance.addPoints(100);
      final result =
          await SocialService.joinTournament('t-gratis', entryFee: 0);
      expect(result, TournamentJoinResult.joined);
      expect((await _tournament('t-gratis')).joined, isTrue);
      expect(ProgressService.instance.points, 100);
    });

    testWidgets('entrar a uno con entrada descuenta los puntos exactos',
        (tester) async {
      // t2 "Torneo de Gases": entrada 25.
      ProgressService.instance.addPoints(100);
      final result =
          await SocialService.joinTournament('t2', entryFee: 25);
      expect(result, TournamentJoinResult.joined);
      expect((await _tournament('t2')).joined, isTrue);
      expect(ProgressService.instance.points, 75);
    });

    testWidgets('sin puntos suficientes NO entra ni descuenta',
        (tester) async {
      ProgressService.instance.addPoints(10);
      final result =
          await SocialService.joinTournament('t2', entryFee: 25);
      expect(result, TournamentJoinResult.notEnoughPoints);
      expect((await _tournament('t2')).joined, isFalse);
      expect(ProgressService.instance.points, 10);
    });

    testWidgets('entrar dos veces no cobra dos veces', (tester) async {
      ProgressService.instance.addPoints(100);
      expect(
          await SocialService.joinTournament('t2', entryFee: 25),
          TournamentJoinResult.joined);
      expect(ProgressService.instance.points, 75);
      expect(
          await SocialService.joinTournament('t2', entryFee: 25),
          TournamentJoinResult.alreadyJoined);
      expect(ProgressService.instance.points, 75);
    });

    testWidgets('salir quita el torneo y NO devuelve los puntos',
        (tester) async {
      ProgressService.instance.addPoints(100);
      await SocialService.joinTournament('t2', entryFee: 25);
      expect(ProgressService.instance.points, 75);
      final left = await SocialService.leaveTournament('t2');
      expect(left, isTrue);
      expect((await _tournament('t2')).joined, isFalse);
      // Sin reembolso: el saldo se queda en 75, no vuelve a 100.
      expect(ProgressService.instance.points, 75);
    });

    testWidgets('el modelo lee entryFee (0 si el doc no lo tiene)',
        (tester) async {
      // fromMap se prueba a través de la semilla: t1 no tenía
      // entrada en Firestore y el modelo la deja en 0.
      final t1 = await _tournament('t1');
      expect(t1.entryFee, 0);
      final t2 = await _tournament('t2');
      expect(t2.entryFee, 25);
    });
  });

  group('pantalla de torneos', () {
    testWidgets('la lista muestra la entrada y el botón con el precio',
        (tester) async {
      // Un gratis sin unir + uno de pago, para ver los dos botones.
      repo.setTournamentsForTests([
        const TournamentInfo(
          id: 't-gratis',
          title: 'Torneo de Bienvenida',
          topic: 'Estequiometría',
          dateRange: '13–20 nov',
          questionCount: 10,
          prizePoints: 50,
          entryFee: 0,
          status: 'active',
        ),
        const TournamentInfo(
          id: 't-pago',
          title: 'Torneo de Gases',
          topic: 'Gases',
          dateRange: '13–20 nov',
          questionCount: 10,
          prizePoints: 250,
          entryFee: 25,
          status: 'active',
        ),
      ]);
      await pumpScreen(
          tester, const TournamentsScreen(isGoogleLinked: true));
      await tester.ensureVisible(find.text('Torneo de Gases'));
      await _settle(tester);
      expect(find.text(tr('tournEntry').replaceFirst('%s', '25')),
          findsWidgets);
      expect(
          find.text(
              tr('tournJoinPaid').replaceFirst('%s', '25').toUpperCase()),
          findsOneWidget);
      // El gratis sigue diciendo "Entrar gratis".
      expect(find.text(tr('tournJoin').toUpperCase()), findsOneWidget);
    });

    testWidgets('salir desde el detalle pide confirmar y no reembolsa',
        (tester) async {
      ProgressService.instance.addPoints(100);
      await SocialService.joinTournament('t2', entryFee: 25);
      expect(ProgressService.instance.points, 75);

      await pumpScreen(
          tester, const TournamentsScreen(isGoogleLinked: true));
      await tester.ensureVisible(find.text('Torneo de Gases'));
      await tester.tap(find.text('Torneo de Gases'));
      await _settle(tester);

      // Estoy dentro y aún no jugué: aparece "Salir del torneo".
      expect(find.text(tr('tournLeave')), findsOneWidget);
      await tester.tap(find.text(tr('tournLeave')));
      await _settle(tester);

      // El diálogo avisa de que se pierden los 25 puntos.
      expect(find.text(tr('tournLeaveTitle')), findsOneWidget);
      expect(
          find.text(
              tr('tournLeaveLoseFee').replaceFirst('%s', '25')),
          findsOneWidget);
      // Confirmar (el último "Salir del torneo" es el del diálogo).
      await tester.tap(find.text(tr('tournLeave')).last);
      await _settle(tester);

      expect((await _tournament('t2')).joined, isFalse);
      expect(ProgressService.instance.points, 75);
      expect(find.text(tr('tournLeftOk')), findsOneWidget);
    });
  });
}
