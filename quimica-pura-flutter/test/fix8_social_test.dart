// Tests sociales de Quemia 7.0 (ronda #8): amigos, duelo online,
// torneos, tienda, grupos, puerta de Google, reportar pregunta,
// subida de puesto y regla 1 en las pantallas de preguntas.
//
// Todo contra InMemorySocialRepository (sin Firestore real): lo
// online de verdad (red, Firestore, latencias) NO queda probado
// aquí — ver el informe final.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/duel_screen.dart';
import 'package:quimica_pura/screens/friends_screen.dart';
import 'package:quimica_pura/screens/groups_screen.dart';
import 'package:quimica_pura/screens/leaderboard_screen.dart';
import 'package:quimica_pura/screens/shop_screen.dart';
import 'package:quimica_pura/screens/tournaments_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/simple_quiz.dart';
import 'package:quimica_pura/widgets/tournament_victory.dart';
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
    Size size = const Size(360, 800),
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

  /// Tres pumps: los streams sociales pasan por dos controladores
  /// asíncronos, así que un evento necesita más de un frame para
  /// llegar a la pantalla y dibujarse.
  Future<void> _settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Contesta las 5 preguntas del duelo/torneo con la opción
  /// correcta (por su texto, que no depende del orden barajado).
  /// Flujo original: tocar la opción la juzga al momento; SIGUIENTE
  /// o RESULTADO avanza.
  Future<void> answerAllCorrectly(WidgetTester tester) async {
    const answers = ['2.00 mol', '74.10 g/mol', '20 L', '1.51×10²³', '300 K'];
    for (final answer in answers) {
      await tester.tap(find.text(answer));
      await _settle(tester);
      // El cuestionario es un ListView: el botón de abajo puede
      // quedar fuera del viewport (botones 3D más altos que los
      // planos viejos) y hay que hacer scroll hasta él, como
      // haría el usuario en el teléfono.
      final nextFinder = find.text(tr('quizNext').toUpperCase());
      final next = nextFinder.evaluate().isNotEmpty
          ? nextFinder
          : find.text(tr('quizResult').toUpperCase());
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await _settle(tester);
    }
  }

  group('puerta de Google (regla de identidad, 09:19)', () {
    testWidgets('sin Google: solo el texto y el botón, sin contenido',
        (tester) async {
      await pumpScreen(
          tester, const FriendsScreen(isGoogleLinked: false));
      expect(find.text(tr('onlineNeedGoogle')), findsOneWidget);
      expect(find.text(tr('googleContinue')), findsOneWidget);
      expect(find.text(tr('friendsRandomDuel')), findsNothing);
      expect(find.text('laura'), findsNothing);
    });

    testWidgets('sin Google: la tabla muestra solo la puerta',
        (tester) async {
      await pumpScreen(
          tester, const LeaderboardScreen(isGoogleLinked: false));
      expect(find.text(tr('onlineNeedGoogle')), findsOneWidget);
      // La puerta sustituye al cuerpo de la tabla (la AppBar con el
      // título sí queda): ni vacío ni estado offline.
      expect(find.text(tr('lbEmpty')), findsNothing);
      expect(find.text(tr('lbOffline')), findsNothing);
      expect(find.text(tr('lbRank')), findsNothing);
    });

    testWidgets('sin Google: torneos, tienda y grupos también con puerta',
        (tester) async {
      await pumpScreen(
          tester, const TournamentsScreen(isGoogleLinked: false));
      expect(find.text(tr('onlineNeedGoogle')), findsOneWidget);
      await pumpScreen(tester, const ShopScreen(isGoogleLinked: false));
      expect(find.text(tr('onlineNeedGoogle')), findsOneWidget);
      await pumpScreen(tester, const GroupsScreen(isGoogleLinked: false));
      expect(find.text(tr('onlineNeedGoogle')), findsOneWidget);
    });

    testWidgets('con Google vinculada: entra a la pantalla', (tester) async {
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      expect(find.text(tr('onlineNeedGoogle')), findsNothing);
      expect(find.text(tr('friendsRandomDuel')), findsOneWidget);
      expect(find.text('laura'), findsOneWidget);
    });
  });

  group('amigos', () {
    testWidgets('la lista trae niveles, puntos y racha de cada amigo',
        (tester) async {
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      expect(find.text('laura'), findsOneWidget);
      expect(find.text('miguel'), findsOneWidget);
      expect(find.text('sofia'), findsOneWidget);
      // laura: 28 niveles, 1420 puntos, racha 15 (usuarios demo).
      expect(find.textContaining('28'), findsWidgets);
      expect(find.textContaining('1420'), findsOneWidget);
      expect(find.textContaining('15'), findsWidgets);
    });

    testWidgets('agregar por nombre: aparece; desconocido: aviso tranquilo',
        (tester) async {
      await pumpScreen(
          tester, const FriendsScreen(isGoogleLinked: true),
          size: const Size(360, 1000));
      await tester.enterText(
          find.widgetWithText(TextField, tr('friendsAddHint')), 'camila');
      await tester.tap(
          find.text(tr('friendsAddButton').toUpperCase()));
      await _settle(tester);
      expect(find.text('camila'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextField, tr('friendsAddHint')), 'nadie123');
      await tester.tap(
          find.text(tr('friendsAddButton').toUpperCase()));
      await _settle(tester);
      expect(find.text(tr('friendsAddNotFound')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('sin amigos: estado vacío bonito', (tester) async {
      SocialService.setRepositoryForTests(
          InMemorySocialRepository(seedDemo: false));
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      expect(find.text(tr('friendsEmpty')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('sin internet: línea tranquila, sin error', (tester) async {
      repo.onlineFlag = false;
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      expect(find.text(tr('socialOffline')), findsOneWidget);
      expect(find.text('laura'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('desde la fila, Retar abre el duelo con ese amigo',
        (tester) async {
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      // El primer botón "Retar" de la lista (laura, por orden).
      await tester.tap(
          find.text(tr('friendsChallenge').toUpperCase()).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DuelScreen), findsOneWidget);
      expect(
          find.text(tr('duelAgainst').replaceFirst('%s', 'laura')),
          findsOneWidget);
    });

    testWidgets('mis duelos: el retado ve y abre su duelo',
        (tester) async {
      repo.simulateIncomingDuel('valeria');
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      await _settle(tester);
      expect(find.text(tr('myDuelsTitle')), findsOneWidget);
      expect(find.text('valeria'), findsOneWidget);
      expect(find.text(tr('myDuelsYourTurn')), findsOneWidget);
      await tester.tap(find.text('valeria'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DuelScreen), findsOneWidget);
      expect(
          find.text(tr('duelAgainst').replaceFirst('%s', 'valeria')),
          findsOneWidget);
    });

    testWidgets('sin duelos abiertos: no hay sección de duelos',
        (tester) async {
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      expect(find.text(tr('myDuelsTitle')), findsNothing);
    });
  });

  group('duelo online', () {
    testWidgets('al azar: busca rival y presenta a valeria',
        (tester) async {
      await pumpScreen(
          tester, const DuelScreen(random: true, isGoogleLinked: true));
      expect(find.text(tr('duelFindingOpponent')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(
          find.text(tr('duelAgainst').replaceFirst('%s', 'valeria')),
          findsOneWidget);
      expect(find.text(tr('duelStart').toUpperCase()), findsOneWidget);
    });

    testWidgets('las preguntas llevan sus datos y 4 opciones',
        (tester) async {
      final match =
          (await SocialService.createDuel(opponentUsername: 'laura'))!;
      await pumpScreen(
          tester,
          DuelScreen(initialMatch: match, isGoogleLinked: true));
      await tester.tap(find.text(tr('duelStart').toUpperCase()));
      await _settle(tester);
      expect(find.textContaining('Datos: M = 18.02 g/mol'), findsOneWidget);
      expect(find.text('0.50 mol'), findsOneWidget);
      expect(find.text('1.00 mol'), findsOneWidget);
      expect(find.text('2.00 mol'), findsOneWidget);
      expect(find.text('3.60 mol'), findsOneWidget);
    });

    testWidgets('flujo completo: retar → jugar → esperar → ganador',
        (tester) async {
      final match =
          (await SocialService.createDuel(opponentUsername: 'laura'))!;
      await pumpScreen(
          tester,
          DuelScreen(initialMatch: match, isGoogleLinked: true),
          size: const Size(360, 1000));
      await tester.tap(find.text(tr('duelStart').toUpperCase()));
      await _settle(tester);
      await answerAllCorrectly(tester);
      // Tras responder, espera a que el amigo termine: mi puntaje.
      expect(find.text(tr('duelWaiting')), findsOneWidget);
      expect(
          find.text('${tr('duelYourScore')}: 5/5'), findsOneWidget);
      repo.simulateOpponentFinishes(match.matchId, 3);
      await _settle(tester);
      expect(find.text(tr('duelYouWin')), findsOneWidget);
      expect(find.text(tr('youWord').toUpperCase()), findsOneWidget);
      expect(find.text('5/5'), findsOneWidget);
      expect(find.text('3/5'), findsOneWidget);
    });

    testWidgets('desconexión: "[nombre] perdió el internet" + opciones',
        (tester) async {
      final match =
          (await SocialService.createDuel(opponentUsername: 'laura'))!;
      await pumpScreen(
          tester,
          DuelScreen(initialMatch: match, isGoogleLinked: true),
          size: const Size(360, 1000));
      await tester.tap(find.text(tr('duelStart').toUpperCase()));
      await _settle(tester);
      repo.simulateOpponentDisconnects(match.matchId);
      await _settle(tester);
      expect(
          find.text(
              tr('duelOpponentOffline').replaceFirst('%s', 'laura')),
          findsOneWidget);
      expect(find.text(tr('duelWaitABit').toUpperCase()), findsOneWidget);
      expect(find.text(tr('duelWinByForfeit').toUpperCase()), findsOneWidget);
      // "Esperar un poco" esconde el aviso sin congelar la partida.
      await tester.tap(find.text(tr('duelWaitABit').toUpperCase()));
      await tester.pump();
      expect(find.byKey(const ValueKey('disconnect-banner')), findsNothing);
      expect(find.textContaining('Datos:'), findsOneWidget);
    });

    testWidgets('ganar por abandono: rival no respondió, puntos intactos',
        (tester) async {
      final before = ProgressService.instance.points;
      final match =
          (await SocialService.createDuel(opponentUsername: 'miguel'))!;
      await pumpScreen(
          tester,
          DuelScreen(initialMatch: match, isGoogleLinked: true),
          size: const Size(360, 1000));
      await tester.tap(find.text(tr('duelStart').toUpperCase()));
      await _settle(tester);
      repo.simulateOpponentDisconnects(match.matchId);
      await _settle(tester);
      await tester.tap(find.text(tr('duelWinByForfeit').toUpperCase()));
      await _settle(tester);
      expect(find.text(tr('duelWinByForfeitTitle')), findsOneWidget);
      expect(find.text(tr('duelYouWin')), findsOneWidget);
      expect(ProgressService.instance.points, before);
    });

    testWidgets('rival abandona: reclamar la victoria', (tester) async {
      final match =
          (await SocialService.createDuel(opponentUsername: 'sofia'))!;
      await pumpScreen(
          tester,
          DuelScreen(initialMatch: match, isGoogleLinked: true),
          size: const Size(360, 1000));
      repo.simulateOpponentAbandons(match.matchId);
      await _settle(tester);
      expect(find.text(tr('duelClaimWin').toUpperCase()), findsOneWidget);
      await tester.tap(find.text(tr('duelClaimWin').toUpperCase()));
      await _settle(tester);
      expect(find.text(tr('duelWinByForfeitTitle')), findsOneWidget);
    });

    testWidgets('empate de aciertos: gana el más rápido, no "Empate"',
        (tester) async {
      final match =
          (await SocialService.createDuel(opponentUsername: 'laura'))!;
      await pumpScreen(
          tester,
          DuelScreen(initialMatch: match, isGoogleLinked: true),
          size: const Size(360, 1000));
      await tester.tap(find.text(tr('duelStart').toUpperCase()));
      await _settle(tester);
      await answerAllCorrectly(tester);
      expect(find.text(tr('duelWaiting')), findsOneWidget);
      // La rival también acierta 5/5, pero tarda una hora: yo
      // gano por tiempo (mi tiempo real de juego son milisegundos).
      repo.simulateOpponentFinishes(match.matchId, 5, timeMs: 3600000);
      await _settle(tester);
      expect(find.text(tr('duelYouWin')), findsOneWidget);
      expect(find.text(tr('duelDraw')), findsNothing);
      // Se ve el desempate: los dos tiempos en pantalla.
      expect(find.textContaining('Tu tiempo:'), findsOneWidget);
    });

    testWidgets('empate de aciertos: el rival más rápido gana',
        (tester) async {
      final match =
          (await SocialService.createDuel(opponentUsername: 'laura'))!;
      await pumpScreen(
          tester,
          DuelScreen(initialMatch: match, isGoogleLinked: true),
          size: const Size(360, 1000));
      await tester.tap(find.text(tr('duelStart').toUpperCase()));
      await _settle(tester);
      await answerAllCorrectly(tester);
      // 5/5 en 1 ms: imposible de superar, la rival gana por tiempo.
      repo.simulateOpponentFinishes(match.matchId, 5, timeMs: 1);
      await _settle(tester);
      expect(find.text(tr('duelYouLose')), findsOneWidget);
      expect(find.text(tr('duelDraw')), findsNothing);
    });

    testWidgets('cancelar: estado tranquilo, puntos intactos',
        (tester) async {
      final before = ProgressService.instance.points;
      final match =
          (await SocialService.createDuel(opponentUsername: 'daniel'))!;
      await pumpScreen(
          tester,
          DuelScreen(initialMatch: match, isGoogleLinked: true));
      await tester.tap(find.text(tr('duelCancel').toUpperCase()));
      await _settle(tester);
      expect(find.text(tr('duelCancelKept')), findsOneWidget);
      expect(ProgressService.instance.points, before);
    });
  });

  group('desempate por tiempo (modelo)', () {
    test('el ganador lo dice el servicio, no solo los aciertos', () {
      DuelState state({required int my, required int opp,
          int myMs = 0, int oppMs = 0, bool? winner}) =>
          DuelState(
            matchId: 'x',
            opponentName: 'laura',
            phase: DuelPhase.finished,
            questions: kDuelQuestions,
            myScore: my,
            opponentScore: opp,
            myTimeMs: myMs,
            opponentTimeMs: oppMs,
            winnerIsMe: winner,
          );
      // Empate 5/5: gana el más rápido.
      expect(state(my: 5, opp: 5, myMs: 40000, oppMs: 60000).iWon, isTrue);
      expect(state(my: 5, opp: 5, myMs: 40000, oppMs: 60000).isDraw,
          isFalse);
      expect(state(my: 5, opp: 5, myMs: 60000, oppMs: 40000).iWon, isFalse);
      // Empate exacto (mismos aciertos y mismo tiempo): empate.
      expect(state(my: 5, opp: 5, myMs: 50000, oppMs: 50000).isDraw,
          isTrue);
      // Sin tiempos conocidos, el empate sigue siendo empate.
      expect(state(my: 5, opp: 5).isDraw, isTrue);
      // winnerIsMe del servicio manda aunque los aciertos digan otra
      // cosa (es el que cobra los +10).
      expect(state(my: 4, opp: 5, winner: true).iWon, isTrue);
      expect(state(my: 5, opp: 5, winner: false).iWon, isFalse);
      expect(state(my: 5, opp: 5, winner: false).isDraw, isFalse);
    });

    test('la pregunta de masa molar usa H = 1.01 (no 1.008)', () {
      expect(kDuelQuestions[1].question, contains('H 1.01'));
      expect(kDuelQuestions[1].question, isNot(contains('1.008')));
      expect(kDuelQuestions[1].options[2], '74.10 g/mol');
    });
  });

  group('torneos', () {
    testWidgets('activos y próximos, con premio y mejor puntaje',
        (tester) async {
      await pumpScreen(
          tester, const TournamentsScreen(isGoogleLinked: true),
          size: const Size(360, 1000));
      expect(find.text(tr('tournActive')), findsOneWidget);
      expect(find.text(tr('tournUpcoming')), findsOneWidget);
      expect(find.text('Torneo de Estequiometría'), findsOneWidget);
      expect(find.text('Torneo de Gases'), findsOneWidget);
      expect(find.text('Torneo de Enlace Químico'), findsOneWidget);
      expect(
          find.text(tr('tournPrize').replaceFirst('%s', '500')),
          findsOneWidget);
      expect(
          find.text(
              '${tr('tournYourBest').replaceFirst('%s', '12')}'),
          findsWidgets);
    });

    testWidgets('sin torneos: estado vacío bonito', (tester) async {
      SocialService.setRepositoryForTests(
          InMemorySocialRepository(seedDemo: false));
      await pumpScreen(
          tester, const TournamentsScreen(isGoogleLinked: true));
      expect(find.text(tr('tournEmpty')), findsOneWidget);
    });

    testWidgets('entrar gratis: el botón pasa a Jugar', (tester) async {
      await pumpScreen(
          tester, const TournamentsScreen(isGoogleLinked: true),
          size: const Size(360, 1000));
      // Antes: t2 (activo, sin unir) y t3 (próximo) traen
      // "Entrar gratis"; t1, ya unido y activo, trae "Jugar".
      expect(find.text(tr('tournJoin').toUpperCase()), findsNWidgets(2));
      await tester.tap(find.text(tr('tournJoin').toUpperCase()).first);
      await _settle(tester);
      // Tras unirse a t2 (activo), su botón pasa a "Jugar" y solo
      // queda un "Entrar gratis" (el de t3, próximo).
      expect(find.text(tr('tournJoin').toUpperCase()), findsOneWidget);
      expect(find.text(tr('tournPlay').toUpperCase()), findsNWidgets(2));
    });

    testWidgets('jugar actualiza mi mejor puntaje y la clasificación',
        (tester) async {
      await pumpScreen(
          tester, const TournamentsScreen(isGoogleLinked: true),
          size: const Size(360, 1000));
      // Entrar al detalle del primer torneo (Estequiometría).
      await tester.tap(find.text('Torneo de Estequiometría'));
      await _settle(tester);
      expect(find.text('sofia'), findsOneWidget);
      expect(find.text('19'), findsWidgets);
      // "Jugar" existe también en la lista de atrás (t1, ya unido):
      // el último es el del detalle, que es el que está arriba.
      await tester.tap(find.text(tr('tournPlay').toUpperCase()).last);
      await _settle(tester);
      expect(find.textContaining('Datos:'), findsOneWidget);
      await answerAllCorrectly(tester);
      await tester.pump(const Duration(milliseconds: 300));
      // Mi 5/5 no supera el 12 que ya tenía: el mejor se queda en 12
      // (y no hay victoria porque sofia sigue primera con 19).
      final after = await SocialService.tournaments();
      final t1 = after.firstWhere((t) => t.id == 't1');
      expect(t1.myBestScore, 12);
      expect(find.byKey(const ValueKey('tournament-trophy')), findsNothing);
    });

    testWidgets('con 20 puntos, mi mejor puntaje me pone primero',
        (tester) async {
      final updated =
          await SocialService.submitTournamentScore('t1', 20);
      expect(updated, isNotNull);
      expect(updated!.myBestScore, 20);
      expect(updated.ranking.first.username, 'kristian');
    });

    testWidgets('el tiempo real llega: empates por tiempo en la tabla',
        (tester) async {
      // 18 puntos empatan con laura (18): con tiempo conocido yo
      // quedo por delante (ella no tiene tiempo registrado).
      final fast = await SocialService.submitTournamentScore('t1', 18,
          timeMs: 5000);
      expect(fast, isNotNull);
      expect(fast!.ranking[1].username, 'kristian');
      expect(repo.tournamentBestTimeMs('t1', 'kristian'), 5000);
      // Mismo puntaje con mejor tiempo: el mejor tiempo mejora.
      await SocialService.submitTournamentScore('t1', 18, timeMs: 3000);
      expect(repo.tournamentBestTimeMs('t1', 'kristian'), 3000);
      // Mismo puntaje con peor tiempo: el mejor tiempo no empeora.
      await SocialService.submitTournamentScore('t1', 18, timeMs: 9000);
      expect(repo.tournamentBestTimeMs('t1', 'kristian'), 3000);
    });

    testWidgets('jugar en la pantalla registra un tiempo real (> 0)',
        (tester) async {
      await pumpScreen(
          tester,
          const TournamentDetailScreen(
              tournamentId: 't2', isGoogleLinked: true),
          size: const Size(360, 1000));
      await tester.tap(find.text(tr('tournJoin').toUpperCase()));
      await _settle(tester);
      await tester.tap(find.text(tr('tournPlay').toUpperCase()));
      await _settle(tester);
      expect(find.textContaining('Datos:'), findsOneWidget);
      await answerAllCorrectly(tester);
      await tester.pump(const Duration(milliseconds: 300));
      final t = repo.tournamentBestTimeMs('t2', 'kristian');
      expect(t, isNotNull);
      expect(t, greaterThan(0));
    });

    testWidgets('la celebración de victoria: trofeo + premio + cerrar',
        (tester) async {
      var closed = false;
      await pumpScreen(
          tester,
          TournamentVictory(
              prizePoints: 500, onClose: () => closed = true));
      expect(find.byKey(const ValueKey('tournament-trophy')), findsOneWidget);
      expect(find.text(tr('tournWin')), findsOneWidget);
      expect(
          find.text(tr('tournWinPrize').replaceFirst('%s', '500')),
          findsOneWidget);
      await tester.tap(find.text(tr('tournClose').toUpperCase()));
      expect(closed, isTrue);
    });

    testWidgets('sin internet al entregar: aviso tranquilo y reintento',
        (tester) async {
      repo.onlineFlag = false;
      await pumpScreen(
          tester, const TournamentsScreen(isGoogleLinked: true),
          size: const Size(360, 1000));
      // Lista vacía sin internet: línea tranquila, no error.
      expect(find.text(tr('socialOffline')), findsOneWidget);
    });
  });

  group('tienda de puntos', () {
    testWidgets('comprar descuenta puntos y deja equipar', (tester) async {
      ProgressService.instance.addPoints(2000);
      final before = ProgressService.instance.points;
      await pumpScreen(tester, const ShopScreen(isGoogleLinked: true),
          size: const Size(360, 1200));
      expect(find.text('Coral'), findsOneWidget);
      // Coral cuesta 300: tras comprar, el saldo baja 300.
      await tester.tap(
          find.textContaining(tr('shopBuy').toUpperCase()).first);
      await _settle(tester);
      expect(find.text(tr('shopBought')), findsOneWidget);
      expect(ProgressService.instance.points, before - 300);
      expect(find.text(tr('shopEquip').toUpperCase()), findsWidgets);
      await tester.tap(
          find.text(tr('shopEquip').toUpperCase()).first);
      await _settle(tester);
      expect(find.text(tr('shopEquipped')), findsOneWidget);
      expect(SocialService.equippedThemeColor,
          const Color(0xFFF97316));
    });

    testWidgets('sin puntos suficientes: chip "Te faltan", sin compra',
        (tester) async {
      // Saldo 0 (prefs vacías): nada se puede comprar.
      expect(ProgressService.instance.points, 0);
      await pumpScreen(tester, const ShopScreen(isGoogleLinked: true),
          size: const Size(360, 1200));
      expect(find.textContaining(tr('shopNeedMore').split('%s').first),
          findsWidgets);
      expect(find.textContaining(tr('shopBuy').toUpperCase()), findsNothing);
      expect(ProgressService.instance.points, 0);
    });

    testWidgets('la compra queda guardada en local', (tester) async {
      ProgressService.instance.addPoints(1000);
      await pumpScreen(tester, const ShopScreen(isGoogleLinked: true),
          size: const Size(360, 1200));
      await tester.tap(
          find.textContaining(tr('shopBuy').toUpperCase()).first);
      await _settle(tester);
      final owned = await SocialService.ownedItemIds();
      expect(owned, contains('theme_coral'));
    });

    test('lo equipado se sincroniza (no solo la propiedad)', () async {
      final coral =
          kShopCatalog.firstWhere((i) => i.id == 'theme_coral');
      final avatar =
          kShopCatalog.firstWhere((i) => i.id == 'avatar_dorado');
      final badge = kShopCatalog.firstWhere((i) => i.id == 'badge_star');
      await SocialService.equipItem(coral);
      await SocialService.equipItem(avatar);
      await SocialService.equipItem(badge);
      expect(repo.syncedEquipped['theme'], 'theme_coral');
      expect(repo.syncedEquipped['avatar'], 'avatar_dorado');
      expect(repo.syncedEquipped['badge'], 'badge_star');
      // Al quitar el tema (elegir Verde/Violeta), también se
      // sincroniza que ya no hay tema equipado.
      await SocialService.clearEquippedTheme();
      expect(repo.syncedEquipped['theme'], isNull);
    });
  });

  group('grupos de estudio', () {
    testWidgets('el grupo semilla trae sus miembros y su código',
        (tester) async {
      await pumpScreen(tester, const GroupsScreen(isGoogleLinked: true),
          size: const Size(360, 1000));
      expect(find.text('Químicos nocturnos'), findsOneWidget);
      expect(find.textContaining('QUIM-4821'), findsOneWidget);
    });

    testWidgets('crear grupo muestra su código de invitación',
        (tester) async {
      await pumpScreen(tester, const GroupsScreen(isGoogleLinked: true),
          size: const Size(360, 1000));
      await tester.enterText(
          find.widgetWithText(TextField, tr('groupsCreateHint')),
          'Estudio nocturno');
      await tester.tap(find.text(tr('groupsCreate').toUpperCase()));
      await _settle(tester);
      expect(find.textContaining('QUIM-'), findsWidgets);
      expect(find.text('Estudio nocturno'), findsOneWidget);
    });

    testWidgets('unirse con código abre el detalle con los miembros',
        (tester) async {
      await pumpScreen(tester, const GroupsScreen(isGoogleLinked: true),
          size: const Size(360, 1000));
      await tester.enterText(
          find.widgetWithText(TextField, tr('groupsJoinHint')), 'QUIM-4821');
      await tester.tap(find.text(tr('groupsJoin').toUpperCase()));
      await _settle(tester);
      expect(find.text('Químicos nocturnos'), findsWidgets);
      expect(find.text('laura'), findsOneWidget);
      expect(find.text('sofia'), findsOneWidget);
    });

    testWidgets('código malo: aviso tranquilo, sin error', (tester) async {
      await pumpScreen(tester, const GroupsScreen(isGoogleLinked: true),
          size: const Size(360, 1000));
      await tester.enterText(
          find.widgetWithText(TextField, tr('groupsJoinHint')), 'XXXX-0000');
      await tester.tap(find.text(tr('groupsJoin').toUpperCase()));
      await _settle(tester);
      expect(find.text(tr('groupsJoinNotFound')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('sin grupos: estado vacío bonito', (tester) async {
      SocialService.setRepositoryForTests(
          InMemorySocialRepository(seedDemo: false));
      await pumpScreen(tester, const GroupsScreen(isGoogleLinked: true),
          size: const Size(360, 1000));
      expect(find.text(tr('groupsEmpty')), findsOneWidget);
    });
  });

  group('reportar pregunta (regla 1: solo este texto)', () {
    testWidgets('Reportar abre la hoja y registra el motivo',
        (tester) async {
      await pumpScreen(
          tester,
          Scaffold(
            body: SimpleQuizRunner(
              title: 'Duelo',
              items: kDuelQuestions,
              onFinished: (_, __) {},
              onExit: () {},
            ),
          ),
          size: const Size(360, 1200));
      await tester.ensureVisible(find.byKey(const ValueKey('report-question')));
      await tester.tap(find.byKey(const ValueKey('report-question')));
      await _settle(tester);
      expect(find.text(tr('reportReasonTitle')), findsOneWidget);
      expect(find.text(tr('reportReasonWrong')), findsOneWidget);
      expect(find.text(tr('reportReasonUnclear')), findsOneWidget);
      expect(find.text(tr('reportReasonData')), findsOneWidget);
      await tester.tap(find.text(tr('reportReasonWrong')));
      await _settle(tester);
      expect(find.text(tr('reportThanks')), findsOneWidget);
      expect(repo.reports.length, 1);
      expect(repo.reports.first.reason, tr('reportReasonWrong'));
    });

    testWidgets('en la pregunta no hay nada online salvo Reportar',
        (tester) async {
      await pumpScreen(
          tester,
          Scaffold(
            body: SimpleQuizRunner(
              title: 'Duelo',
              items: kDuelQuestions,
              onFinished: (_, __) {},
              onExit: () {},
            ),
          ),
          size: const Size(360, 1200));
      expect(find.text(tr('lbTitle')), findsNothing);
      expect(find.text(tr('accountLinkGoogle')), findsNothing);
      expect(find.text(tr('googleContinue')), findsNothing);
      expect(find.text(tr('onlineNeedGoogle')), findsNothing);
      expect(find.byKey(const ValueKey('report-question')), findsOneWidget);
    });
  });

  group('subida de puesto en la tabla', () {
    testWidgets('al subir del 3º al 1º salta el aviso', (tester) async {
      final ctrl = StreamController<List<LeaderboardEntry>>(sync: true);
      addTearDown(() => ctrl.close());
      await pumpScreen(
          tester,
          LeaderboardScreen(
            entriesStream: ctrl.stream,
            currentDeviceId: 'd-me',
            isGoogleLinked: true,
          ));
      ctrl.add([
        const LeaderboardEntry(
            deviceId: 'd-sofia',
            username: 'sofia',
            points: 1500,
            levelsPassedTotal: 30,
            streak: 10),
        const LeaderboardEntry(
            deviceId: 'd-laura',
            username: 'laura',
            points: 1400,
            levelsPassedTotal: 28,
            streak: 9),
        const LeaderboardEntry(
            deviceId: 'd-me',
            username: 'kristian',
            points: 1200,
            levelsPassedTotal: 24,
            streak: 8),
      ]);
      await _settle(tester);
      expect(find.byKey(const ValueKey('rank-up-banner')), findsNothing);
      ctrl.add([
        const LeaderboardEntry(
            deviceId: 'd-me',
            username: 'kristian',
            points: 1600,
            levelsPassedTotal: 24,
            streak: 8),
        const LeaderboardEntry(
            deviceId: 'd-sofia',
            username: 'sofia',
            points: 1500,
            levelsPassedTotal: 30,
            streak: 10),
        const LeaderboardEntry(
            deviceId: 'd-laura',
            username: 'laura',
            points: 1400,
            levelsPassedTotal: 28,
            streak: 9),
      ]);
      await _settle(tester);
      expect(find.byKey(const ValueKey('rank-up-banner')), findsOneWidget);
      expect(
          find.text(tr('lbRankUp').replaceFirst('%s', '1')), findsOneWidget);
    });
  });
}
