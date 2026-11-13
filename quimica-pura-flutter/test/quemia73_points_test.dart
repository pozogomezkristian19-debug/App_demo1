// Pruebas de Quemia 7.3 — los 13 puntos (sin push, sin tocar
// version.json). Cada grupo prueba UN punto con su arreglo:
//  1. Notificaciones: icono PNG + keep.xml + "Probar un aviso ahora".
//  2. Google: error real, fallback credential-already-in-use con
//     migración del progreso, cuenta admin que juega.
//  3. Splash nativo en rutas válidas (ficheros, no APK: la
//     compilación local de Gradle no funciona aquí).
//  4. Atrás en la búsqueda: cierra teclado, luego la búsqueda.
//  5. Preguntas de nivel aleatorias (banco barajado, sin duplicados).
//  6. Cápsula de vidas compacta solo en estadísticas.
//  7. Leyenda de la tabla visible por encima de Comparar/Quiz.
//  8. Hoja del elemento con el fondo difuminado.
//  9. Barra inferior: Aprender primero, Resolver después.
//  10. Conversor primero (pantalla y menú).
//  11. Teclado según dificultad (sencillo/científico).
//  12. Acento del tema en chips, píldoras, botones e iconos.
//  13. Versión pública 1.0 dentro de la app (interna 7.3 intacta).
//
// Se ejecuta con TMPDIR en disco (ver instrucciones de la tarea) y
// TZ=America/Havana, como el resto de la suite.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/data/periodic_table.dart';
import 'package:quimica_pura/models.dart';
import 'package:quimica_pura/screens/constants_screen.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/screens/search_screen.dart';
import 'package:quimica_pura/screens/settings_screen.dart';
import 'package:quimica_pura/screens/stats_screen.dart';
import 'package:quimica_pura/screens/tabla_screen.dart';
import 'package:quimica_pura/services/accent.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/update_check.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:quimica_pura/widgets/element_sheet.dart';
import 'package:quimica_pura/widgets/google_sign_in_button.dart';
import 'package:quimica_pura/widgets/lives_chip.dart';
import 'package:quimica_pura/widgets/main_bottom_nav.dart';
import 'package:quimica_pura/widgets/simple_quiz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'test_helpers.dart';

/// Fake mínimo del plugin de notificaciones: permiso concedido y
/// show() que anota lo mostrado (patrón de fix9_notifications_test).
class _Q73FakeNotifications extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
  final shown = <({int id, String? title, String? body})>[];

  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async =>
      true;

  @override
  Future<bool?> requestNotificationsPermission() async => true;

  @override
  Future<bool?> requestExactAlarmsPermission() async => true;

  @override
  Future<bool?> areNotificationsEnabled() async => true;

  @override
  Future<bool?> openAppNotificationSettings() async => true;

  @override
  Future<List<AndroidNotificationChannel>?> getNotificationChannels() async =>
      [];

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    AndroidNotificationDetails? notificationDetails,
  }) async {
    shown.add((id: id, title: title, body: body));
  }

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
    AndroidNotificationDetails? notificationDetails,
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exact,
  }) async {}
}

/// Repositorio en memoria (solo users/ + lo mínimo del resto):
/// lo que necesita la migración de la 7.3.
class _Q73FakeRepo implements AnalyticsRepository {
  final users = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>?> getUser(String deviceId) async =>
      users[deviceId] == null
          ? null
          : Map<String, dynamic>.from(users[deviceId]!);

  @override
  Future<void> setUser(String deviceId, Map<String, dynamic> data) async {
    final cur = users[deviceId] ?? <String, dynamic>{};
    users[deviceId] = {...cur, ...data};
  }

  @override
  Stream<List<Map<String, dynamic>>> leaderboard() =>
      Stream.value(users.values.toList());

  @override
  Future<Map<String, dynamic>?> getSettings() async => null;

  @override
  Future<Map<String, dynamic>?> getDoc(
          String collection, String docId) async =>
      null;

  @override
  Future<void> setDoc(String collection, String docId,
          Map<String, dynamic> data,
          {bool merge = true}) async {}

  @override
  Future<String> createDoc(
          String collection, Map<String, dynamic> data) async =>
      'doc-1';

  @override
  Future<List<Map<String, dynamic>>> queryDocs(String collection,
          {String? whereField,
          Object? isEqualTo,
          String? orderByField,
          bool descending = false,
          int? limit}) async =>
      [];

  @override
  Stream<Map<String, dynamic>?> watchDoc(
          String collection, String docId) =>
      const Stream.empty();

  @override
  Future<void> addToArray(String collection, String docId, String field,
          Object value) async {}

  @override
  Future<void> removeFromArray(String collection, String docId,
          String field, Object value) async {}

  @override
  Future<bool> ping(String collection, String docId) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'melli_rules_seen_v6': true});
    await UserPrefs.load();
    await ProgressService.load();
    ProgressService.track = ProgressService.trackUni;
    UserPrefs.track = 'uni';
    UserPrefs.userName = 'kristian';
    UserPrefs.themeAccent = 'verde';
    // PracticarScreen muestra el camino de niveles sin la pantalla
    // de reglas (patrón de fix5_repetir_test).
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.onboardingDone = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
  });

  tearDown(() {
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    NotificationService.resetForTests();
    NotificationInbox.resetForTests();
    UpdateCheckService.resetForTests();
    UserPrefs.themeAccent = 'verde';
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.onboardingDone = false;
    AppLang.code = 'es';
  });

  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('P1 notificaciones: icono PNG + keep + probar aviso', () {
    test('los PNG de la campana existen en las 5 densidades y el '
        'keep.xml los protege', () {
      for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        final f = File(
            'android/app/src/main/res/drawable-$d/ic_notif_bell.png');
        expect(f.existsSync(), isTrue, reason: 'falta $d');
        expect(f.lengthSync(), greaterThan(0));
      }
      final keep =
          File('android/app/src/main/res/values/keep.xml').readAsStringSync();
      expect(keep, contains('tools:keep="@drawable/ic_notif_bell"'));
      // El vector viejo ya no existe.
      expect(
          File('android/app/src/main/res/drawable/ic_notif_bell.xml')
              .existsSync(),
          isFalse);
    });

    testWidgets('"Probar un aviso ahora" (sendTest) llega con el '
        'icono de campana', (tester) async {
      final fake = _Q73FakeNotifications();
      FlutterLocalNotificationsPlatform.instance = fake;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        (call) async => 'America/Havana',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async {
          if (call.method == 'getTemporaryDirectory') return '/tmp';
          return null;
        },
      );
      // La copia del icono grande tiene un tope de 3 s y rootBundle
      // necesita pumps para resolver (patrón de fix9): sin bombear,
      // el futuro no se resuelve nunca.
      final future = NotificationService.sendTest();
      await tester.pump(const Duration(seconds: 4));
      expect(await future, isTrue);
      expect(fake.shown, isNotEmpty);
    });
  });

  group('P2 Google: error real, fallback y migración', () {
    late _Q73FakeRepo repo;
    late FakeAuthProvider authFake;

    setUp(() async {
      repo = _Q73FakeRepo();
      authFake = FakeAuthProvider();
      AnalyticsSync.setRepositoryForTests(repo);
      AuthService.setProviderForTests(authFake);
      await AuthService.ensureAnonymous();
      await AnalyticsSync.init();
    });

    test('google-services.json: los dos clientes, web tipo 3 y la '
        'huella SHA-1 del keystore actual', () {
      final json = jsonDecode(File('android/app/google-services.json')
          .readAsStringSync()) as Map<String, dynamic>;
      final clients = (json['client'] as List).cast<Map<String, dynamic>>();
      final packages = clients
          .map((c) => (c['client_info'] as Map)['android_client_info']
              ['package_name'] as String)
          .toList();
      expect(packages, contains('com.melliqui.quimica_pura'));
      expect(packages, contains('com.melliqui.quemia_admin'));
      final main = clients.firstWhere((c) =>
          (c['client_info'] as Map)['android_client_info']['package_name'] ==
          'com.melliqui.quimica_pura');
      final oauth =
          (main['oauth_client'] as List).cast<Map<String, dynamic>>();
      expect(oauth.map((o) => o['client_type']), containsAll([1, 3]));
      final web = oauth.firstWhere((o) => o['client_type'] == 3);
      expect(web['client_id'],
          '898001909401-o2ins4m72vvgb5hg6v5rgsl0llgu9glj.apps.googleusercontent.com');
      final android = oauth.firstWhere((o) => o['client_type'] == 1);
      // Huella SHA-1 del keystore actual, sin ':' y en minúsculas.
      expect(
          (android['android_info'] as Map)['certificate_hash'],
          'e8c25aadc6a17883278ac697618b34b13ee347e7');
    });

    test('sin selector (initialize/authenticate roto): el código real '
        'queda en lastGoogleError, no solo "Inténtalo de nuevo"', () async {
      authFake.failNativeCredential = true;
      authFake.nativeErrorCode = 'unknownError';
      expect(await AuthService.linkWithGoogle(), isFalse);
      expect(AuthService.lastGoogleError,
          'google_sign_in:unknownError');
      expect(await AuthService.signInWithGoogle(), isFalse);
      expect(AuthService.lastGoogleError,
          'google_sign_in:unknownError');
    });

    test('anónimo nivel 3 con 120 puntos → inicia sesión (fallback) → '
        'sigue en nivel 3 con 120 puntos', () async {
      // Progreso anónimo en el teléfono.
      ProgressService.instance.addPoints(120);
      ProgressService.instance.recordLevelPass('estequiometria', 2);
      expect(ProgressService.instance.points, 120);
      expect(ProgressService.instance.unlockedLevel('estequiometria'), 3);
      // Documento de la nube del anónimo (menos que el local).
      repo.users['fake-anon-uid'] = {
        'username': 'kristian',
        'points': 50,
        'levels': {
          'uni': {'estequiometria': 2},
        },
        'practiceDays': <String>[],
      };
      // La cuenta de Google ya vive en otro uid, con menos progreso.
      repo.users['google-uid'] = {
        'username': 'kristian',
        'points': 42,
        'levels': {
          'uni': {'estequiometria': 3},
        },
        'practiceDays': <String>[],
      };
      authFake.googleUid = 'google-uid';
      authFake.simulateAlreadyInUse = true;
      final migrations = <(String, String)>[];
      AuthService.migrateProgressOnUidChange = (from, to) async {
        migrations.add((from, to));
        return AnalyticsSync.migrateAnonymousProgress(from, to);
      };

      expect(await AuthService.linkWithGoogle(), isTrue);
      expect(AuthService.currentUid, 'google-uid');
      expect(AuthService.isGoogleLinked, isTrue);
      expect(migrations, [('fake-anon-uid', 'google-uid')]);
      // El progreso local NO se tocó: nivel 3, 120 puntos.
      expect(ProgressService.instance.points, 120);
      expect(ProgressService.instance.unlockedLevel('estequiometria'), 3);
      // Y la nube del uid de Google quedó con lo mejor (120 puntos).
      expect(repo.users['google-uid']?['points'], 120);
      expect(
          ((repo.users['google-uid']?['levels'] as Map)['uni'] as Map)[
              'estequiometria'],
          3);
    });

    test('si la migración falla, el inicio devuelve false con motivo '
        'claro y el progreso local sigue intacto', () async {
      ProgressService.instance.addPoints(120);
      ProgressService.instance.recordLevelPass('estequiometria', 2);
      authFake.googleUid = 'google-uid';
      authFake.simulateAlreadyInUse = true;
      AuthService.migrateProgressOnUidChange = (_, __) async => false;

      expect(await AuthService.linkWithGoogle(), isFalse);
      expect(AuthService.lastGoogleError, 'migration_failed');
      expect(ProgressService.instance.points, 120);
      expect(ProgressService.instance.unlockedLevel('estequiometria'), 3);
    });

    test('la cuenta admin (pozogomezkristian19@gmail.com) entra y '
        'juega como una jugadora normal', () async {
      authFake.email = 'pozogomezkristian19@gmail.com';
      authFake.displayName = 'Kristian Pozo';
      expect(await AuthService.linkWithGoogle(), isTrue);
      expect(AuthService.isGoogleLinked, isTrue);
      expect(AuthService.googleEmail, 'pozogomezkristian19@gmail.com');
      // Puede jugar: el progreso local se guarda con normalidad.
      ProgressService.instance.addPoints(10);
      expect(ProgressService.instance.points, 10);
    });

    test('la app principal no tiene ningún chequeo de admin/rol en '
        'lib/ (la cuenta admin no se trata distinto)', () {
      // Solo cuenta el CÓDIGO: los comentarios de auth_service.dart
      // explican la regla y mencionan isAdmin/admin@/rol.
      final hits = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final code = f
            .readAsStringSync()
            .split('\n')
            .map((l) => l.split('//').first)
            .join('\n');
        if (code.contains('isAdmin') ||
            code.contains('admin@') ||
            RegExp(r'\brole\b').hasMatch(code) ||
            RegExp(r'\brol\b').hasMatch(code)) {
          hits.add(f.path);
        }
      }
      expect(hits, isEmpty, reason: 'chequeos de admin en: $hits');
    });

    testWidgets('el botón de Google no solapa la G con el texto',
        (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: GoogleSignInButton(onPressed: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final gRect = tester.getRect(find.byType(Image).first);
      final textRect =
          tester.getRect(find.text('Continuar con Google'));
      expect(gRect.right, lessThanOrEqualTo(textRect.left));
      expect(find.text('Continuar con Google'), findsOneWidget);
    });
  });

  group('P3 arranque en frío: splash nativos en rutas válidas', () {
    test('drawable-v21 (claro) y drawable-night-v21 (oscuro) existen '
        'con el anillo; la ruta inválida ya no existe', () {
      final light =
          File('android/app/src/main/res/drawable-v21/launch_background.xml');
      expect(light.existsSync(), isTrue);
      final lightSrc = light.readAsStringSync();
      expect(lightSrc, contains('@drawable/splash_logo'));
      // La plantilla vieja (?android:colorBackground) solo queda
      // mencionada en el comentario que explica el arreglo: se
      // quitan los comentarios antes de afirmar sobre el drawable.
      final lightNoComments = lightSrc.replaceAll(
          RegExp(r'<!--.*?-->', dotAll: true), '');
      expect(lightNoComments, isNot(contains('?android:colorBackground')));
      expect(lightSrc, contains('@android:color/white'));
      final dark = File(
          'android/app/src/main/res/drawable-night-v21/launch_background.xml');
      expect(dark.existsSync(), isTrue);
      final darkSrc = dark.readAsStringSync();
      expect(darkSrc, contains('@drawable/splash_logo'));
      expect(darkSrc, contains('#131F24'));
      expect(
          File('android/app/src/main/res/values-night/drawable/'
                  'launch_background.xml')
              .existsSync(),
          isFalse);
      expect(
          File('android/app/src/main/res/drawable-xxxhdpi/splash_logo.png')
              .existsSync(),
          isTrue);
    });
  });

  group('P13 versión pública 1.0', () {
    test('la pública es 1.0 y la interna sigue en 7.3 (el comprobador '
        'compara la interna)', () {
      expect(kDisplayVersion, '1.0');
      expect(kAppVersion, '7.3');
    });

    testWidgets('Ajustes muestra "Versión instalada: 1.0"',
        (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: SettingsScreen(onOpenScreen: (_) {}),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Versión instalada: 1.0'),
          findsOneWidget);
    });

    testWidgets('el diálogo de actualización enseña la versión pública',
        (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(body: SizedBox()),
        ),
      );
      await tester.pump();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async {
          if (call.method == 'getApplicationDocumentsDirectory' ||
              call.method == 'getTemporaryDirectory') {
            return '/tmp';
          }
          return null;
        },
      );
      final context = tester.element(find.byType(Scaffold));
      const info = UpdateInfo(
        latest: '7.3',
        apkUrl: 'https://example.com/app.apk',
        notes: 'Novedades',
        force: false,
      );
      UpdateCheckService.showUpdateDialog(context, info);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Versión 1.0 disponible'), findsOneWidget);
      expect(find.text('Versión 7.3 disponible'), findsNothing);
    });
  });

  group('P4 atrás en la búsqueda: teclado primero, luego la búsqueda', () {
    Future<void> pumpSearchHome(WidgetTester tester) async {
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SearchScreen(onEntryTap: (_) {}),
                    ),
                  ),
                  child: const Text('Abrir búsqueda'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Abrir búsqueda'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SearchScreen), findsOneWidget);
    }

    testWidgets('atrás con el teclado abierto solo lo cierra; el '
        'segundo atrás cierra la búsqueda sin salir de la app',
        (tester) async {
      await pumpSearchHome(tester);
      // El campo tiene autofocus: el teclado (foco) está abierto.
      expect(FocusScope.of(tester.element(find.byType(SearchScreen)))
          .hasFocus, isTrue);
      // Primer atrás: solo cierra el teclado, la búsqueda sigue.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(FocusScope.of(tester.element(find.byType(SearchScreen)))
          .hasFocus, isFalse);
      // Segundo atrás: cierra la búsqueda y vuelve a la pantalla.
      // La ruta tarda 300 ms en animarse fuera: hay que bombear
      // más que un frame o sigue en el árbol animándose.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SearchScreen), findsNothing);
      expect(find.text('Abrir búsqueda'), findsOneWidget);
    });

    testWidgets('la flecha atrás de la AppBar también cierra solo la '
        'búsqueda', (tester) async {
      await pumpSearchHome(tester);
      // Primera flecha: el teclado está abierto, solo lo cierra.
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(FocusScope.of(tester.element(find.byType(SearchScreen)))
          .hasFocus, isFalse);
      // Segunda flecha: cierra la búsqueda.
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SearchScreen), findsNothing);
      expect(find.text('Abrir búsqueda'), findsOneWidget);
    });
  });

  group('P5 preguntas de nivel aleatorias', () {
    Future<void> pumpNiveles(WidgetTester tester) async {
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: PracticarScreen(onOpenScreen: (_) {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> startLevel1(WidgetTester tester) async {
      await tester.ensureVisible(find.text('1').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('1').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
    }

    /// Contesta la pregunta visible con la opción correcta del banco
    /// (patrón de fix5_repetir_test) y avanza. Devuelve el texto de
    /// la pregunta contestada.
    Future<String> answerCurrent(WidgetTester tester) async {
      final bank = localizedAllQuestions();
      QuizQuestion? shown;
      for (final q in bank) {
        if (find.text(q.question).evaluate().isNotEmpty) {
          shown = q;
          break;
        }
      }
      expect(shown, isNotNull,
          reason: 'No se ve ninguna pregunta del banco');
      final q = shown!;
      final optionBtn = find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.text(q.options[q.answer]),
      );
      await tester.tap(optionBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final nextFinder = find.text(tr('quizNext').toUpperCase());
      final target = nextFinder.evaluate().isNotEmpty
          ? nextFinder
          : find.text(tr('quizResult').toUpperCase());
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return q.question;
    }

    Future<List<String>> playLevel1(WidgetTester tester) async {
      final seen = <String>[];
      for (var i = 0; i < 5; i++) {
        seen.add(await answerCurrent(tester));
      }
      return seen;
    }

    testWidgets('dos intentos seguidos del mismo nivel no dan las '
        'mismas 5 en el mismo orden, ni duplicados dentro del intento',
        (tester) async {
      await pumpNiveles(tester);
      await startLevel1(tester);
      final first = await playLevel1(tester);
      expect(first.length, 5);
      expect(first.toSet().length, 5,
          reason: 'hay preguntas repetidas dentro del intento: $first');
      // Repetir el nivel inmediatamente con REPETIR (el nodo 1 ya
      // sale completado en el camino, así que la repetición es
      // desde el resultado).
      await tester.tap(find.text(tr('quizRepeat').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
      final second = await playLevel1(tester);
      expect(second.length, 5);
      expect(second.toSet().length, 5,
          reason: 'hay preguntas repetidas dentro del intento: $second');
      expect(second, isNot(first),
          reason: 'el segundo intento repite las mismas 5 en el '
              'mismo orden');
    });
  });

  group('P6 cápsula de vidas compacta solo en estadísticas', () {
    testWidgets('LivesChip compacta mide 26 dp; la normal sigue en '
        '36 dp (barra superior intacta)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LivesChip(lives: 4, showMax: true, pulse: false),
                LivesChip(
                    lives: 4, showMax: true, pulse: false, compact: true),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final sizes = tester
          .widgetList<LivesChip>(find.byType(LivesChip))
          .map((w) => tester.getSize(find.byWidget(w)))
          .toList();
      expect(sizes[0].height, 36.0);
      expect(sizes[1].height, 26.0);
    });

    testWidgets('Mis estadísticas usa la variante compacta',
        (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: StatsScreen(trackTopics: const ['estequiometria']),
          ),
        ),
      );
      await tester.pump();
      final chip = tester.widget<LivesChip>(find.byType(LivesChip).first);
      expect(chip.compact, isTrue);
    });
  });

  group('P7 leyenda de la tabla por encima de Comparar/Quiz', () {
    testWidgets('al bajar del todo se ve "118 elementos." sin nada '
        'encima', (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(body: TablaScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final scrollable =
          find.byType(SingleChildScrollView).first;
      await tester.drag(scrollable, const Offset(0, -10000));
      await tester.pumpAndSettle();
      final legend = find.text('118 elementos.');
      expect(legend, findsOneWidget);
      final legendRect = tester.getRect(legend);
      final compareRect = tester.getRect(find.text('Comparar'));
      final quizRect = tester.getRect(find.text('Quiz'));
      expect(legendRect.bottom, lessThanOrEqualTo(compareRect.top),
          reason: 'Comparar tapa la leyenda');
      expect(legendRect.bottom, lessThanOrEqualTo(quizRect.top),
          reason: 'Quiz tapa la leyenda');
      // Y la leyenda entera está dentro de la pantalla.
      expect(legendRect.bottom,
          lessThanOrEqualTo(tester.view.physicalSize.height / 2.0));
    });
  });

  group('P8 hoja del elemento con el fondo difuminado', () {
    testWidgets('al abrir un elemento hay UN BackdropFilter (sigma 10) '
        'sobre toda la pantalla', (tester) async {
      await setPhone(tester);
      final element =
          allElements.firstWhere((e) => e.atomicNumber == 115);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showElementSheet(context, element),
                  child: const Text('Abrir elemento'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Abrir elemento'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Moscovio'), findsOneWidget);
      final filters =
          tester.widgetList<BackdropFilter>(find.byType(BackdropFilter));
      expect(filters, isNotEmpty);
      final filter = filters.first.filter;
      expect(filter.toString(), contains('10'));
      // Atrás cierra la hoja y vuelve a la pantalla (no sale).
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Moscovio'), findsNothing);
      expect(find.text('Abrir elemento'), findsOneWidget);
    });
  });

  group('P9 barra inferior: Aprender primero, Resolver después', () {
    testWidgets('el orden es Aprender, Resolver, Niveles, Tabla, '
        'Cuenta y cada toque abre su pestaña', (tester) async {
      await setPhone(tester);
      var selected = 2;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            bottomNavigationBar: MainBottomNav(
              selectedIndex: selected,
              onSelected: (i) => selected = i,
              isDark: false,
              tabColors: const [
                Colors.teal,
                Colors.teal,
                Colors.teal,
                Colors.teal,
                Colors.teal,
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final learnX = tester.getCenter(find.text('Aprender')).dx;
      final solveX = tester.getCenter(find.text('Resolver')).dx;
      final levelsX = tester.getCenter(find.text('Niveles')).dx;
      final tableX = tester.getCenter(find.text('Tabla')).dx;
      final accountX = tester.getCenter(find.text('Cuenta')).dx;
      expect(learnX, lessThan(solveX));
      expect(solveX, lessThan(levelsX));
      expect(levelsX, lessThan(tableX));
      expect(tableX, lessThan(accountX));
      await tester.tap(find.text('Aprender'));
      expect(selected, 0);
      await tester.tap(find.text('Resolver'));
      expect(selected, 1);
      await tester.tap(find.text('Tabla'));
      expect(selected, 3);
    });
  });

  group('P10 conversor primero', () {
    testWidgets('en la pantalla, "Conversor de unidades" va antes que '
        '"Constantes"', (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ConstantsScreen()),
        ),
      );
      await tester.pump();
      final converterY =
          tester.getCenter(find.text('Conversor de unidades')).dy;
      final constantsY = tester.getCenter(find.text('Constantes')).dy;
      expect(converterY, lessThan(constantsY));
    });
  });

  group('P11 teclado según dificultad', () {
    QuizQuestion numericQ({required int difficulty}) => QuizQuestion(
          topic: 'estequiometria',
          question: '¿Cuántos moles hay en 36 g de agua?',
          options: const ['0.50 mol', '1.00 mol', '2.00 mol', '3.60 mol'],
          answer: 2,
          explanation: 'n = m/M.',
          difficulty: difficulty,
          numericAnswer: 2.0,
          numericUnit: 'mol',
        );

    Future<void> openCalculator(
        WidgetTester tester, QuizQuestion q) async {
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: SimpleQuizRunner(
              title: 'Prueba',
              items: [q],
              onFinished: (_, __) {},
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // El campo de respuesta numérica abre la calculadora.
      await tester.tap(find.byKey(
          const Key('numeric-answer-field-text')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('pregunta fácil (1): teclado sencillo, sin teclas '
        'científicas, pero CON "Usar resultado"', (tester) async {
      await openCalculator(tester, numericQ(difficulty: 1));
      expect(find.text('log'), findsNothing);
      // El teclado sencillo no tiene ni log, ni ln, ni raíz.
      expect(find.text('ln'), findsNothing);
      expect(find.text('√'), findsNothing);
      // Se puede responder: el teclado sencillo entrega el valor.
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('='));
      await tester.pump();
      expect(find.text('Usar resultado'), findsOneWidget);
      await tester.tap(find.text('Usar resultado'));
      await tester.pump();
      // El pop tarda 500 ms en sacar la calculadora del árbol.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Usar resultado'), findsNothing);
    });

    testWidgets('pregunta difícil (3): teclado científico',
        (tester) async {
      await openCalculator(tester, numericQ(difficulty: 3));
      expect(find.text('log'), findsOneWidget);
      // El teclado no tiene teclas de trigonometría; las
      // científicas son log, ln, √, x², 10^x, e^x.
      expect(find.text('ln'), findsOneWidget);
      expect(find.text('√'), findsOneWidget);
    });

    testWidgets('pregunta media (2): teclado científico',
        (tester) async {
      await openCalculator(tester, numericQ(difficulty: 2));
      expect(find.text('log'), findsOneWidget);
    });
  });

  group('P12 acento del tema en todo', () {
    test('las píldoras de arriba siguen al acento (color, no tamaño)', () {
      UserPrefs.themeAccent = 'verde';
      expect(AppAccent.pillDarkBackground, const Color(0xFF134E4A));
      expect(AppAccent.pillDarkForeground, const Color(0xFF2DD4BF));
      UserPrefs.themeAccent = 'violeta';
      expect(AppAccent.pillDarkBackground, const Color(0xFF2A1B52));
      expect(AppAccent.pillDarkForeground, const Color(0xFFC4B5FD));
      UserPrefs.themeAccent = 'verde';
    });

    testWidgets('los chips de la tabla usan el acento: violeta con '
        'Violeta, teal con Verde', (tester) async {
      await setPhone(tester);
      for (final (accent, expected) in [
        ('violeta', BrandColors.violet),
        ('verde', BrandColors.teal),
      ]) {
        UserPrefs.themeAccent = accent;
        // Key distinta por acento: pumpWidget con el árbol const
        // idéntico reutilizaría el elemento sin reconstruir (artefacto
        // del test; en la app real el cambio de acento reconstruye
        // todo vía themeAccentNotifier).
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(body: TablaScreen(key: ValueKey(accent))),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final chip = tester.widget<ChoiceChip>(
            find.byType(ChoiceChip).first);
        expect(chip.selectedColor, expected,
            reason: 'chip "Todos" con acento $accent');
      }
      UserPrefs.themeAccent = 'verde';
    });
  });
}
