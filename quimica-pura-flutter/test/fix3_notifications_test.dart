// Pruebas de la ronda de arreglos #3, punto 9 (notificaciones):
// el permiso se pide en el onboarding, el primer aviso llega dentro
// de la primera hora y ninguna plantilla muestra un slug.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/data/questions.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/screens/reminder_screen.dart';
import 'package:quimica_pura/services/nav_requests.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// Fake del plugin de notificaciones para las pruebas: sin plataforma
/// real, `FlutterLocalNotificationsPlatform.instance` ni siquiera está
/// registrado (su `late _instance` lanza LateInitializationError) y
/// las llamadas al canal nativo se quedan colgadas. El fake simula
/// el permiso de notificaciones (concedido o negado, según el test).
class _FakeAndroidNotifications extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
  _FakeAndroidNotifications({required this.permissionGranted});

  bool permissionGranted;

  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async =>
      true;

  @override
  Future<bool?> requestNotificationsPermission() async =>
      permissionGranted;

  @override
  Future<bool?> requestExactAlarmsPermission() async => true;

  /// Permiso real (Zona G, 7.1): la prueba tipada y la
  /// confirmación consultan areNotificationsEnabled() y los
  /// canales antes de enviar. Sin estos overrides, la llamada cae
  /// en el MethodChannel sin mock, su Future no se resuelve nunca
  /// y el tope de 2 s deja un Timer pendiente que rompe el test.
  @override
  Future<bool?> areNotificationsEnabled() async => permissionGranted;

  @override
  Future<List<AndroidNotificationChannel>?> getNotificationChannels() async =>
      const [];

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  // Sin plataforma real, la llamada a la zona horaria se queda
  // colgada: se simula America/Havana. El permiso de notificaciones
  // se simula NEGADO por defecto (cada test de concedido lo cambia).
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Recargar los estáticos de UserPrefs desde las prefs (vacías):
    // sin esto, un test anterior que activó los recordatorios deja
    // `reminderOn` en true para el siguiente test (los estáticos no
    // se reinician solos entre tests del mismo archivo).
    await UserPrefs.load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => 'America/Havana',
    );
    // El icono grande de la notificación copia el PNG del compañero
    // a un archivo temporal (path_provider): sin mock, esa llamada
    // también se queda colgada en pruebas.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getTemporaryDirectory') return '/tmp';
        return null;
      },
    );
    FlutterLocalNotificationsPlatform.instance =
        _FakeAndroidNotifications(permissionGranted: false);
  });

  test('el aviso diario llega a la hora elegida (hoy o mañana)',
      () {
    tzdata.initializeTimeZones();
    final loc = tz.getLocation('America/Havana');
    final morning = tz.TZDateTime(loc, 2026, 11, 17, 10, 0);
    final next = NotificationService.nextDailyReminder(
      hour: 19,
      minute: 0,
      now: morning,
    );
    expect(next.day, 17);
    expect(next.hour, 19);
    final night = tz.TZDateTime(loc, 2026, 11, 17, 20, 30);
    final nextDay = NotificationService.nextDailyReminder(
      hour: 19,
      minute: 0,
      now: night,
    );
    expect(nextDay.day, 18);
    expect(nextDay.hour, 19);
  });

  test('ninguna plantilla de notificación contiene un slug', () {
    const langs = ['es', 'en', 'fr', 'it', 'pt', 'ru'];
    for (final lang in langs) {
      for (final template in NotificationService.messageTemplates(lang)) {
        expect(template.contains('bach-'), isFalse,
            reason: '$lang: $template');
        expect(template.contains('uni-'), isFalse,
            reason: '$lang: $template');
      }
    }
    // El mensaje de tema débil, para TODOS los slugs del banco y del
    // mapa de nombres, nunca muestra el id interno.
    final slugs = <String>{
      for (final q in allQuestions) q.topic,
      ...topicNames.keys,
    };
    expect(slugs, contains('bach-estequiometria'));
    for (final slug in slugs) {
      final name = localizedTopicTitle(slug);
      expect(name.contains('bach-'), isFalse, reason: slug);
      expect(name.contains('uni-'), isFalse, reason: slug);
      for (final lang in langs) {
        final msg = NotificationService.weakTopicMessage(lang, name);
        expect(msg.contains('bach-'), isFalse,
            reason: '$lang $slug: $msg');
        expect(msg.contains('uni-'), isFalse, reason: '$lang $slug: $msg');
        expect(msg.contains(slug), isFalse, reason: '$lang $slug: $msg');
      }
    }
  });

  test("'bach-estequiometria' se muestra como 'Estequiometría y el mol'",
      () {
    expect(localizedTopicTitle('bach-estequiometria'),
        'Estequiometría y el mol');
    expect(
        NotificationService.weakTopicMessage(
            'es', localizedTopicTitle('bach-estequiometria')),
        'Toca repasar Estequiometría y el mol, tu tema más flojo.');
  });

  test('el payload de repaso es estable', () {
    expect(NotificationService.reviewPayload, 'review_mistakes');
  });

  test('NavRequests.requestReview deja el flag y avisa', () {
    NavRequests.startReview = false;
    final before = NavRequests.reviewRequested.value;
    NavRequests.requestReview();
    expect(NavRequests.startReview, isTrue);
    expect(NavRequests.reviewRequested.value, before + 1);
    NavRequests.startReview = false; // limpiar
  });

  /// Lleva el onboarding hasta la pantalla de permiso de
  /// notificaciones (la ÚLTIMA página en la 7.7: Bienvenida
  /// -> Perfil -> Referido -> Notificaciones; sin pantalla de idioma).
  /// [onFinished] se llama cuando el flujo termina.
  Future<void> goToNotificationsPage(
    WidgetTester tester, {
    VoidCallback? onFinished,
  }) async {
    // Superficie de teléfono (393x852, como el Redmi de Kristian):
    // a 800x600 la página del perfil no cabe en vertical y la
    // píldora "Masculino" queda bajo el área visible, fuera del
    // alcance del toque (el toque caería sobre el botón SIGUIENTE).
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
          home: OnboardingScreen(onFinished: onFinished ?? () {})),
    );
    await tester.pumpAndSettle();
    // Bienvenida -> Elección -> la gemela -> cómo supo -> cuánta
    // química sabe -> meta diaria -> Notificaciones (rediseño 7.7:
    // Continuar, Crear mi perfil, Vamos, elegir, Continuar,
    // elegir, Continuar, elegir, Guardar mi meta; sin pantalla de
    // idioma). El perfil y el referido van DESPUÉS de
    // Notificaciones, así que aquí no se rellenan.
    await tester.tap(find.text('CONTINUAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREAR MI PERFIL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VAMOS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Instagram'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conozco lo básico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 min al día'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GUARDAR MI META'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'el onboarding tiene la pantalla de permiso con solo "Activar recordatorios"',
      (tester) async {
    var finished = false;
    await goToNotificationsPage(tester, onFinished: () => finished = true);
    expect(find.text('No pierdas la racha'), findsOneWidget);
    expect(find.text('ACTIVAR RECORDATORIOS'), findsOneWidget);
    // El botón "Ahora no" se quitó (2026-11-10 20:43): queda un
    // solo botón en la pantalla.
    expect(find.text('Ahora no'), findsNothing);
    // La pantalla de permiso tiene sus propios botones: el
    // "Siguiente" de abajo no sale aquí.
    expect(find.text('SIGUIENTE'), findsNothing);
    // Con el permiso negado (en pruebas enable() devuelve false),
    // "Activar recordatorios" muestra el diálogo con "Ir a
    // Ajustes" (fix4, punto 3, en lugar del aviso de antes) y, al
    // cerrarlo, se avanza a la pantalla de la racha (Quemia 7.7:
    // Notificaciones ya NO es la última página: después van la
    // racha, el perfil y el referido).
    await tester.tap(find.text('ACTIVAR RECORDATORIOS'));
    await tester.pumpAndSettle();
    expect(find.text('Ir a Ajustes'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(finished, isFalse);
    expect(find.text('¡Una nueva racha!'), findsOneWidget);
  });

  testWidgets(
      'activar recordatorios en el onboarding avanza también si se concede el permiso',
      (tester) async {
    // Esta vez el permiso SÍ se concede.
    FlutterLocalNotificationsPlatform.instance =
        _FakeAndroidNotifications(permissionGranted: true);
    var finished = false;
    await goToNotificationsPage(tester, onFinished: () => finished = true);
    await tester.tap(find.text('ACTIVAR RECORDATORIOS'));
    // Al conceder, enable() programa la tanda: la copia del icono
    // grande tiene un tope de 3 s (tiempo falso) y en pruebas la E/S
    // real no completa, así que hay que avanzar el reloj para que el
    // tope dispare y el flujo siga sin icono.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    // Sin aviso de permiso y se avanza a la racha (Quemia 7.7:
    // Notificaciones ya NO es la última página).
    expect(find.byType(SnackBar), findsNothing);
    expect(finished, isFalse);
    expect(find.text('¡Una nueva racha!'), findsOneWidget);
    expect(UserPrefs.reminderOn, isTrue);
  });

  testWidgets(
      'activar recordatorios en el onboarding no rompe nada si se niega el permiso',
      (tester) async {
    var finished = false;
    await goToNotificationsPage(tester, onFinished: () => finished = true);
    // En pruebas el permiso está simulado como NEGADO
    // (requestNotificationsPermission devuelve false): sale el
    // diálogo con "Ir a Ajustes" (fix4, punto 3, en lugar del aviso
    // de antes) y, al cerrarlo, se avanza igual a la pantalla del
    // idioma. Los recordatorios quedan apagados y se pueden
    // activar luego desde Cuenta › Recordatorios.
    await tester.tap(find.text('ACTIVAR RECORDATORIOS'));
    await tester.pumpAndSettle();
    expect(find.text('Ir a Ajustes'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    // Tras notificaciones se avanza a la racha (Quemia 7.7: ya NO
    // es la última página). Los recordatorios quedan apagados y se
    // pueden activar luego desde Cuenta › Recordatorios.
    expect(finished, isFalse);
    expect(find.text('¡Una nueva racha!'), findsOneWidget);
    expect(UserPrefs.reminderOn, isFalse);
  });

  group('Próximo aviso (fix3, H3)', () {
  test('nextNotificationTime devuelve el primer aviso futuro', () async {
    final now = DateTime.now();
    final past = now.subtract(const Duration(hours: 1));
    final next = now.add(const Duration(minutes: 30));
    final later = now.add(const Duration(hours: 3));
    SharedPreferences.setMockInitialValues({
      'melli_notif_next':
          '${past.toIso8601String()},${next.toIso8601String()},${later.toIso8601String()}',
    });
    // El primero de la tanda ya pasó: salta al siguiente futuro.
    final got = await NotificationService.nextNotificationTime();
    expect(got, isNotNull);
    expect(got!.difference(next).inSeconds.abs(), lessThanOrEqualTo(1));
  });

  test('nextNotificationTime es null sin avisos; una hora pasada '
      'rueda al día siguiente (la alarma es diaria)', () async {
    SharedPreferences.setMockInitialValues({'melli_notif_next': ''});
    expect(await NotificationService.nextNotificationTime(), isNull);
    final now = DateTime.now();
    final past = now.subtract(const Duration(hours: 1));
    SharedPreferences.setMockInitialValues(
        {'melli_notif_next': past.toIso8601String()});
    // La alarma diaria se repite: la hora pasada no está "pasada
    // para siempre", toca mañana a la misma hora.
    final got = await NotificationService.nextNotificationTime();
    expect(got, isNotNull);
    expect(got!.hour, past.hour);
    expect(got.minute, past.minute);
    expect(got.isAfter(now), isTrue);
    expect(got.difference(now).inHours, lessThan(24));
  });

  testWidgets('la pantalla simplificada no muestra el próximo aviso '
      '(solo interruptor y botón de prueba)', (tester) async {
    // Permiso CONCEDIDO (Zona G): el fake ya no se queda colgado
    // en areNotificationsEnabled (antes el tope de 100 ms de
    // isPermissionGranted asumía "sí" y el interruptor salía ON
    // aunque el permiso estuviera negado por defecto). Con el
    // permiso negado, el interruptor refleja la realidad y queda
    // APAGADO; para comprobar la pantalla con el interruptor ON
    // hay que concederlo de verdad.
    FlutterLocalNotificationsPlatform.instance =
        _FakeAndroidNotifications(permissionGranted: true);
    final next = DateTime.now().add(const Duration(minutes: 30));
    SharedPreferences.setMockInitialValues({
      'melli_reminder_on': true,
      'melli_notif_next': next.toIso8601String(),
    });
    await UserPrefs.load();
    await tester.pumpWidget(
      const MaterialApp(home: ReminderScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Próximo aviso'), findsNothing);
    expect(find.text('Recordatorios activados'), findsOneWidget);
    expect(find.text('PROBAR UN AVISO AHORA'), findsOneWidget);
  });

  testWidgets('sin avisos no se muestra la línea del próximo aviso',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await UserPrefs.load();
    await tester.pumpWidget(
      const MaterialApp(home: ReminderScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Próximo aviso'), findsNothing);
  });
  });
}
