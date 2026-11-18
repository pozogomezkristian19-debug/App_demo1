// Recordatorio de contraseña (Kristian 2026-11-15): si la cuenta
// es de Google y aún no tiene contraseña, la app programa UN aviso
// único ~1 h después de abrir la app (2026-11-17: antes era cada
// hora en bucle y se acumulaba en la bandeja); al tocarla se abre
// Cuenta. Cuando la contraseña queda puesta (o la cuenta no es de
// Google), el recordatorio se cancela. Aquí se usa el
// FakeAuthProvider del servicio, nunca el plugin real.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/nav_requests.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:quimica_pura/services/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthProvider fakeAuth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Havana'));
    PushService.resetForTests();
    NavRequests.pendingPushScreen = null;
    fakeAuth = FakeAuthProvider();
    AuthService.setProviderForTests(fakeAuth);
  });

  tearDown(() {
    AuthService.resetForTests();
    PushService.resetForTests();
    NavRequests.pendingPushScreen = null;
  });

  /// Cuenta de Google (sin contraseña, salvo [withPassword]).
  void googleAccount({bool withPassword = false}) {
    fakeAuth.uid = 'fake-google-uid';
    fakeAuth.googleLinked = true;
    fakeAuth.emailLinked = withPassword;
    fakeAuth.email = 'kristian@gmail.com';
    fakeAuth.displayName = 'Kristian';
  }

  test('solo toca recordar con Google y sin contraseña', () {
    googleAccount();
    expect(NotificationService.shouldRemindPassword(), isTrue);
    googleAccount(withPassword: true);
    expect(NotificationService.shouldRemindPassword(), isFalse);
    fakeAuth.uid = 'fake-anon-uid';
    fakeAuth.googleLinked = false;
    fakeAuth.emailLinked = false;
    expect(NotificationService.shouldRemindPassword(), isFalse);
  });

  test('el texto del recordatorio explica el porqué (2026-11-17)', () {
    expect(
      tr('passwordReminderBody'),
      'Solo entras con Google: ponle una contraseña para no perder tu progreso',
    );
    expect(NotificationService.passwordPayload, 'set_password');
  });

  test('programar sin plugin no rompe nada', () async {
    googleAccount();
    // En pruebas no hay plugin: el método lo toma como fallo y
    // devuelve false, sin lanzar.
    expect(await NotificationService.schedulePasswordReminder(), isFalse);
    // Cancelar sin plugin tampoco lanza.
    await NotificationService.cancelPasswordReminder();
  });

  test('programar con contraseña ya puesta no programa nada', () async {
    googleAccount(withPassword: true);
    expect(await NotificationService.schedulePasswordReminder(), isFalse);
  });

  test('tocar el recordatorio abre Cuenta', () async {
    final before = NavRequests.pushRequested.value;
    PushService.dispatchLocalTapForTests(
      const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: NotificationService.passwordPayload,
      ),
    );
    expect(NavRequests.pendingPushScreen, 'account');
    expect(NavRequests.pushRequested.value, before + 1);
  });
}
