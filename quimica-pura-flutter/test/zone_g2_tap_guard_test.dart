// Zona G2 (7.1), guardia del toque: tocar un aviso de repaso NO
// debe soltar un error sin capturar aunque reprogramar la tanda
// falle (p. ej. zona horaria sin inicializar en un arranque raro).
//
// Este archivo NO inicializa la zona horaria a propósito: si la
// cadena del toque no llevara su propio try/catch, el
// LateInitializationError de timezone tumbaría el archivo entero.
// El repaso sí queda pedido (el flag se pone antes de reprogramar).
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/nav_requests.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:quimica_pura/services/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await NotificationInbox.load();
    PushService.resetForTests();
    NavRequests.startReview = false;
  });

  tearDown(() {
    NavRequests.startReview = false;
  });

  test('tocar el aviso de repaso no tumba la app si reprogramar falla',
      () async {
    final reviewBefore = NavRequests.reviewRequested.value;
    PushService.dispatchLocalTapForTests(
      const NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotification,
        payload: NotificationService.reviewPayload,
      ),
    );
    // La cadena async (reconciliar + reprogramar) corre en segundo
    // plano y su fallo queda tragado: si no estuviera tragado, este
    // archivo fallaría con el error sin capturar. Se deja 1 s para
    // que la cadena corra aunque la suite completa esté en paralelo
    // y la CPU vaya justa.
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(NavRequests.startReview, isTrue);
    expect(NavRequests.reviewRequested.value, reviewBefore + 1);
  });
}
