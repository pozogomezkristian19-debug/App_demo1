// Vistas previas de la simplificación de Recordatorios (ronda #7,
// Quemia 6.4). Se ejecuta con --update-goldens para ESCRIBIR los
// PNG en ~/workspace/melli-qui-v6-previews/ (nombres
// fix7_recordatorios_simple*). Viewport 393x852 (dpr 2), Roboto
// real + MaterialIcons reales. La pantalla de Recordatorios se
// monta suelta, con el tema Material por defecto. Los PNG se leen y
// se verifican a mano antes de informar.
//
// La pantalla simplificada (Kristian, 08:38 CST: "yo no quiero que
// tenga tantas cosas, esa cantidad de detalles es para
// programadores, los usuarios solo tienen que desactivar y
// activar, solamente") tiene SOLO la introducción, el interruptor
// y el botón "Probar un aviso ahora": sin diagnóstico, sin próximo
// ni último aviso, sin tarjeta de batería y sin nota en cursiva.
// - fix7_recordatorios_simple: interruptor ENCENDIDO.
// - fix7_recordatorios_simple_off: interruptor APAGADO.
// Los previews fix7 anteriores (fix7_recordatorios,
// fix7_recordatorios_pendiente, fix7_recordatorios_fallo,
// fix7_recordatorios_enviado, fix7_recordatorios_canal) mostraban
// el diseño rechazado y ya no se generan: no reutilizarlos como
// aprobación.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/screens/reminder_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'test_helpers.dart';

/// Fake del plugin para las vistas previas (mismo patrón que
/// _Fix6PreviewFake): permiso configurable, sin programar nada de
/// verdad, con show() que puede fallar para el estado de error.
class _Fix7PreviewFake extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
  bool permissionGranted = true;

  /// ¿show() lanza (simula un fallo del sistema)?
  bool showThrows = false;

  /// Canales que devuelve getNotificationChannels() (configurable
  /// por test, como en _Fix7FakeNotifications): permite simular un
  /// canal bloqueado (Importance.none). Por defecto ninguno (el
  /// canal de prueba aún no existe) → isTestChannelBlocked()
  /// devuelve false.
  List<AndroidNotificationChannel> channels = const [];

  /// Avisos inmediatos mostrados (ids) por show().
  final shown = <int>[];

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
  Future<bool?> areNotificationsEnabled() async => permissionGranted;

  @override
  Future<bool?> openAppNotificationSettings() async => true;

  /// Canales de notificación: los de [channels] (por defecto
  /// ninguno: el canal de prueba aún no existe) →
  /// isTestChannelBlocked() devuelve false. Sin este override, la
  /// llamada caería en el MethodChannel sin mock, el Future no se
  /// resolvería nunca y el botón de prueba se quedaría esperando
  /// para siempre sin mostrar nada (ronda #7).
  @override
  Future<List<AndroidNotificationChannel>?> getNotificationChannels() async =>
      channels;

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    AndroidNotificationDetails? notificationDetails,
  }) async {
    if (showThrows) {
      throw PlatformException(code: 'SHOW_FAILED');
    }
    shown.add(id);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadMaterialIcons();
  });

  late _Fix7PreviewFake fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPrefs.load();
    NotificationInbox.resetForTests();
    NotificationService.resetForTests();
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
    fake = _Fix7PreviewFake();
    FlutterLocalNotificationsPlatform.instance = fake;
  });

  tearDown(() {
    AppLang.code = 'es';
    NotificationInbox.resetForTests();
    NotificationService.resetForTests();
  });

  Future<void> setPhone(
    WidgetTester tester, {
    double width = 393,
    double height = 852,
  }) async {
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../melli-qui-v6-previews/$name'),
    );
  }

  Future<void> pumpReminders(WidgetTester tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        // Interruptor teal (tema Quemia): sin esto sale violeta,
        // el color por defecto de Material 3.
        theme: ThemeData(
          useMaterial3: true,
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? const Color(0xFF00C2A8)
                    : Colors.white),
            trackColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? const Color(0xFF00C2A8).withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.12)),
          ),
        ),
        home: const ReminderScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// La pantalla simplificada: solo introducción, interruptor y
  /// botón de prueba. Nada de diagnóstico, de próximo/último aviso
  /// ni de batería.
  void expectSimpleScreen() {
    expect(find.text(tr('notifExplain')), findsOneWidget);
    expect(find.text(tr('notifTest').toUpperCase()), findsOneWidget);
    expect(find.text('Diagnóstico'), findsNothing);
    expect(find.text('Próximo aviso'), findsNothing);
    expect(find.text('Sin avisos programados'), findsNothing);
    expect(find.text('Último aviso enviado'), findsNothing);
    expect(find.text('Todavía no se ha enviado ningún aviso'),
        findsNothing);
    expect(find.text('Ahorro de batería'), findsNothing);
    expect(find.text('Canal «Aviso de prueba»: activado'), findsNothing);
    expect(find.text('Canal «Aviso de prueba»: desactivado'),
        findsNothing);
  }

  testWidgets('fix7_recordatorios_simple: Recordatorios simplificado, '
      'interruptor ENCENDIDO', (tester) async {
    SharedPreferences.setMockInitialValues({'melli_reminder_on': true});
    await UserPrefs.load();
    await pumpReminders(tester);
    expect(find.text(tr('notifOn')), findsOneWidget);
    expect(find.text(tr('notifOff')), findsNothing);
    expectSimpleScreen();
    await shot(tester, 'fix7_recordatorios_simple.png');
  });

  testWidgets('fix7_recordatorios_simple_off: Recordatorios '
      'simplificado, interruptor APAGADO', (tester) async {
    await pumpReminders(tester);
    expect(find.text(tr('notifOff')), findsOneWidget);
    expect(find.text(tr('notifOn')), findsNothing);
    expectSimpleScreen();
    await shot(tester, 'fix7_recordatorios_simple_off.png');
  });
}
