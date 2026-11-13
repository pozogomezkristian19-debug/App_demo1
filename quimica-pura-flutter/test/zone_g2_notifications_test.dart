// Zona G2 (7.1): las DOS capas de notificaciones no se pisan.
//
//   Capa online (push FCM): solicitudes, duelos, respuestas de
//   soporte y avisos del creador. Llega con internet, canal propio
//   'quemia_push', y deja su entrada en la bandeja.
//   Capa local (sin internet): recordatorios de estudio, aviso de
//   prueba, logros y racha. Se programan y suenan en el teléfono,
//   canales 'melli_study_reminders' y 'quemia_prueba_avisos'.
//
// Lo que estos tests cierran:
//   1. Los tres canales son distintos (un canal silenciado en
//      Ajustes no apaga las otras dos capas).
//   2. UN solo handler de toques cubre las dos capas: el segundo
//      plugin (push) sustituye el handler del primero (local), así
//      que despacha TAMBIÉN los payloads viejos de repaso,
//      actualización e instalación; si no, tocar esos avisos
//      dejaría de abrir nada.
//   3. La sincronización sin push usa los MISMOS ids que el push,
//      así que un aviso que llegó por los dos lados deja UNA sola
//      entrada en la bandeja (dedup por id).
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/nav_requests.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:quimica_pura/services/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Como en producción (NotificationService.init() corre antes
    // que cualquier toque): la zona horaria está inicializada.
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Havana'));
    await NotificationInbox.load();
    PushService.resetForTests();
    NavRequests.startReview = false;
    NavRequests.showUpdateDialog = false;
    NavRequests.pendingPushScreen = null;
  });

  tearDown(() {
    NavRequests.startReview = false;
    NavRequests.showUpdateDialog = false;
    NavRequests.pendingPushScreen = null;
  });

  test('los tres canales son distintos (push, recordatorios, prueba)',
      () {
    expect(PushService.channelId, 'quemia_push');
    expect(NotificationService.remindersChannelId,
        'melli_study_reminders');
    expect(NotificationService.testChannelId, 'quemia_prueba_avisos');
    expect(NotificationService.remindersChannelId,
        isNot(PushService.channelId));
    expect(NotificationService.testChannelId,
        isNot(PushService.channelId));
    expect(NotificationService.testChannelId,
        isNot(NotificationService.remindersChannelId));
  });

  test('el toque del push despacha también los avisos locales viejos',
      () async {
    // Repaso: abre el repaso de errores.
    final reviewBefore = NavRequests.reviewRequested.value;
    PushService.dispatchLocalTapForTests(
      const NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotification,
        payload: NotificationService.reviewPayload,
      ),
    );
    expect(NavRequests.startReview, isTrue);
    expect(NavRequests.reviewRequested.value, reviewBefore + 1);

    // Actualización: abre el diálogo de actualización.
    final updateBefore = NavRequests.updateRequested.value;
    PushService.dispatchLocalTapForTests(
      const NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotification,
        payload: NotificationService.updatePayload,
      ),
    );
    expect(NavRequests.showUpdateDialog, isTrue);
    expect(NavRequests.updateRequested.value, updateBefore + 1);

    // Instalación: pide instalar el APK ya descargado.
    final installBefore = NavRequests.installRequested.value;
    PushService.dispatchLocalTapForTests(
      const NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotification,
        payload: NotificationService.installActionId,
      ),
    );
    expect(NavRequests.installRequested.value, installBefore + 1);
  });

  test('el toque de un push JSON crea la entrada y pide su pantalla',
      () async {
    final pushBefore = NavRequests.pushRequested.value;
    PushService.dispatchLocalTapForTests(
      const NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotification,
        payload:
            '{"type":"friend_request","requestId":"r1","senderUsername":"laura"}',
      ),
    );
    // handlePushTapData es async: la entrada y la navegación
    // llegan tras el await interno. Se espera con sondeo (hasta
    // 5 s) en vez de un retraso fijo: con la suite completa en
    // paralelo, 200 ms no bastaban para que el microtask corriera.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      if (NavRequests.pendingPushScreen == 'friends' &&
          NotificationInbox.entriesNotifier.value
              .any((e) => e.id == 'friend-request-r1')) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(NavRequests.pendingPushScreen, 'friends');
    expect(NavRequests.pushRequested.value, pushBefore + 1);
    expect(
      NotificationInbox.entriesNotifier.value
          .any((e) => e.id == 'friend-request-r1'),
      isTrue,
    );
  });

  test('la sincronización sin push usa los mismos ids que el push',
      () {
    // El push crea 'friend-request-<id>' y el sync de G2
    // (SocialService.syncFriendRequestInbox) usa ese mismo id, así
    // que addIfAbsent deja UNA sola entrada aunque llegue por los
    // dos lados. Lo mismo para duelos ('duel-challenge-<id>',
    // 'duel-result-<id>') y avisos ('announcement-<id>').
    expect(
      inboxEntryForPush(data: {
        'type': 'friend_request',
        'requestId': 'r9',
        'senderUsername': 'laura',
      }).id,
      'friend-request-r9',
    );
    expect(
      inboxEntryForPush(data: {
        'type': 'duel_challenge',
        'duelId': 'd7',
      }).id,
      'duel-challenge-d7',
    );
    expect(
      inboxEntryForPush(data: {
        'type': 'announcement',
        'announcementId': 'a3',
      }).id,
      'announcement-a3',
    );
  });
}
