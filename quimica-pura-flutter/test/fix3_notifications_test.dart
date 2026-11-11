// Pruebas de la ronda de arreglos #3, punto 9 (notificaciones):
// el permiso se pide en el onboarding, el primer aviso llega dentro
// de la primera hora y ninguna plantilla muestra un slug.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  test('el primer aviso llega dentro de la primera hora (20-50 min)',
      () {
    for (var seed = 0; seed < 100; seed++) {
      final gap = NotificationService.nextFirstGapMinutes(Random(seed));
      expect(gap, greaterThanOrEqualTo(20));
      expect(gap, lessThanOrEqualTo(50));
      expect(NotificationService.firstGapIsValid(gap), isTrue);
    }
  });

  test('firstGapIsValid: 19 no vale, 20 y 50 sí, 51 no', () {
    expect(NotificationService.firstGapIsValid(19), isFalse);
    expect(NotificationService.firstGapIsValid(20), isTrue);
    expect(NotificationService.firstGapIsValid(50), isTrue);
    expect(NotificationService.firstGapIsValid(51), isFalse);
  });

  test('el primer aviso siempre llega antes que un hueco normal', () {
    for (var seed = 0; seed < 100; seed++) {
      final first = NotificationService.nextFirstGapMinutes(Random(seed));
      final next = NotificationService.nextGapMinutes(Random(seed));
      expect(first, lessThan(next));
    }
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
  /// notificaciones (después del nombre, antes del idioma).
  Future<void> goToNotificationsPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onFinished: () {})),
    );
    await tester.pumpAndSettle();
    // 4 pantallas: bienvenida, resolver, estudiar, practicar.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }
    // Pantalla del perfil: nombre + género para poder avanzar.
    await tester.enterText(find.byType(TextField), 'Kristian');
    await tester.tap(find.text('Masculino'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'el onboarding tiene la pantalla de permiso con solo "Activar recordatorios"',
      (tester) async {
    await goToNotificationsPage(tester);
    expect(find.text('No pierdas la racha'), findsOneWidget);
    expect(find.text('Activar recordatorios'), findsOneWidget);
    // El botón "Ahora no" se quitó (2026-11-10 20:43): queda un
    // solo botón en la pantalla.
    expect(find.text('Ahora no'), findsNothing);
    // La pantalla de permiso tiene sus propios botones: el
    // "Siguiente" de abajo no sale aquí.
    expect(find.text('Siguiente'), findsNothing);
    // Con el permiso negado (en pruebas enable() devuelve false),
    // "Activar recordatorios" avanza igual al idioma, donde está
    // "Finalizar".
    await tester.tap(find.text('Activar recordatorios'));
    await tester.pumpAndSettle();
    expect(find.text('Finalizar'), findsOneWidget);
  });

  testWidgets(
      'activar recordatorios en el onboarding avanza también si se concede el permiso',
      (tester) async {
    // Esta vez el permiso SÍ se concede.
    FlutterLocalNotificationsPlatform.instance =
        _FakeAndroidNotifications(permissionGranted: true);
    await goToNotificationsPage(tester);
    await tester.tap(find.text('Activar recordatorios'));
    // Al conceder, enable() programa la tanda: la copia del icono
    // grande tiene un tope de 3 s (tiempo falso) y en pruebas la E/S
    // real no completa, así que hay que avanzar el reloj para que el
    // tope dispare y el flujo siga sin icono.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    // Sin aviso de permiso y se avanza igual al idioma.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Finalizar'), findsOneWidget);
    expect(UserPrefs.reminderOn, isTrue);
  });

  testWidgets(
      'activar recordatorios en el onboarding no rompe nada si se niega el permiso',
      (tester) async {
    await goToNotificationsPage(tester);
    // En pruebas el permiso está simulado como NEGADO
    // (requestNotificationsPermission devuelve false): sale el aviso
    // de que hace falta el permiso y se avanza igual a la pantalla
    // del idioma. Los recordatorios quedan apagados y se pueden
    // activar luego desde Cuenta › Recordatorios.
    await tester.tap(find.text('Activar recordatorios'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Finalizar'), findsOneWidget);
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

  test('nextNotificationTime es null sin avisos o con todos pasados',
      () async {
    SharedPreferences.setMockInitialValues({'melli_notif_next': ''});
    expect(await NotificationService.nextNotificationTime(), isNull);
    final past = DateTime.now().subtract(const Duration(hours: 1));
    SharedPreferences.setMockInitialValues(
        {'melli_notif_next': past.toIso8601String()});
    expect(await NotificationService.nextNotificationTime(), isNull);
  });

  testWidgets('la pantalla muestra la fecha del próximo aviso',
      (tester) async {
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
    expect(find.text('Próximo aviso'), findsOneWidget);
    final timeStr =
        '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
    expect(find.textContaining(timeStr), findsOneWidget);
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
