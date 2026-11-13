// Push FCM del panel de admin (lado RECEPTOR solamente).
//
// El ENVÍO lo hacen Cloud Functions (otra zona): cuando se crea un usuario
// en 'users', un reporte en 'reports' o un mensaje en 'support_messages',
// la función manda un mensaje FCM de datos a los tokens guardados en
// 'admins'. Esta app solo:
//   1. guarda su token FCM en el documento del admin que inició sesión
//      ('admins/{uid}': fcmToken + fcmTokenUpdatedAt en ms);
//   2. muestra el push como notificación local visible (canal propio);
//   3. al tocarla, abre la pantalla que corresponde (Usuarios, Reportes
//      o Soporte) a través de [PushService.pendingSection], que HomeShell
//      escucha.
//
// Seguridad del token: el token SOLO se guarda desde HomeShell, es decir,
// DESPUÉS de que resolveAdminRecord confirmó que el usuario es admin.
// Guardarlo antes (al iniciar sesión) crearía con set-merge un documento
// parcial en 'admins/{uid}' que AdminRecord.fromDoc leería como admin
// válido (role por defecto 'admin', pending false): un usuario cualquiera
// con Google entraría al panel. Por eso registerAdmin(uid) solo se llama
// desde HomeShell con el uid ya verificado, y unregisterAdmin() lo limpia
// al salir.
//
// Permiso (Android 13+): la app hoy NO pide permiso de notificaciones en
// ningún flujo. Este servicio lo pide UNA sola vez: solo si
// getNotificationSettings() dice notDetermined. No se vuelve a pedir.
//
// Robustez: FCM nunca rompe el arranque ni el login. Cada paso de init(),
// de registerAdmin() y del handler de fondo lleva su propio try/catch y
// timeouts; si Firebase Messaging falla, la app sigue normal, solo sin
// pushes.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'design.dart';
import 'repositories.dart';

/// Tipos de push que mandan las Cloud Functions (campo 'type' del data).
const String pushTypeNewUser = 'admin_new_user';
const String pushTypeNewReport = 'admin_new_report';
const String pushTypeNewSupport = 'admin_new_support';

/// Canal propio de notificaciones locales del panel.
const String kAdminPushChannelId = 'quemia_admin_push';
const String kAdminPushChannelName = 'Avisos de Quemia Admin';
const String kAdminPushChannelDescription =
    'Avisos del panel: usuarios nuevos, reportes de preguntas y mensajes de soporte.';

// ---------------------------------------------------------------------------
// Lógica pura (probada en test/push_service_test.dart sin Firebase real)
// ---------------------------------------------------------------------------

/// Pantalla del panel a la que lleva cada tipo de push. null = tipo
/// desconocido: no se navega a ningún sitio.
AdminSection? sectionForPushType(String? type) => switch (type) {
  pushTypeNewUser => AdminSection.usuarios,
  pushTypeNewReport => AdminSection.reportes,
  pushTypeNewSupport => AdminSection.soporte,
  _ => null,
};

/// Título y cuerpo que se muestran en la notificación local.
class PushContent {
  const PushContent({required this.title, required this.body});

  final String title;
  final String body;
}

/// Construye el contenido visible de un mensaje.
///
/// Prioridad: payload de notificación del mensaje -> campos 'title'/'body'
/// del data (por si la función manda solo datos) -> textos en español por
/// tipo. Así un mensaje de solo datos también se ve bien.
PushContent contentForMessage(
  Map<String, dynamic> data, {
  String? notificationTitle,
  String? notificationBody,
}) {
  final type = data['type'] as String?;
  final fallbackTitle = switch (type) {
    pushTypeNewUser => 'Nuevo usuario',
    pushTypeNewReport => 'Nueva pregunta reportada',
    pushTypeNewSupport => 'Nuevo mensaje de soporte',
    _ => 'Quemia Admin',
  };
  final fallbackBody = switch (type) {
    pushTypeNewUser => 'Un usuario nuevo se unió a Quemia.',
    pushTypeNewReport => 'Un usuario reportó una pregunta.',
    pushTypeNewSupport => 'Un usuario escribió a soporte.',
    _ => 'Tienes un aviso nuevo en Quemia Admin.',
  };
  String? dataText(String key) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  final title = notificationTitle?.trim();
  final body = notificationBody?.trim();
  return PushContent(
    title: (title != null && title.isNotEmpty)
        ? title
        : (dataText('title') ?? fallbackTitle),
    body: (body != null && body.isNotEmpty)
        ? body
        : (dataText('body') ?? fallbackBody),
  );
}

// ---------------------------------------------------------------------------
// Abstracciones (para probar sin Firebase real)
// ---------------------------------------------------------------------------

/// Cliente de mensajería mínimo que usa PushService.
abstract class MessagingClient {
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Stream<RemoteMessage> get onMessage;
  Stream<RemoteMessage> get onMessageOpenedApp;
  Future<RemoteMessage?> getInitialMessage();
  Future<NotificationSettings> getNotificationSettings();
  Future<NotificationSettings> requestPermission();
}

class FirebaseMessagingClient implements MessagingClient {
  FirebaseMessagingClient([FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  // getToken/onTokenRefresh están deprecados en firebase_messaging 17 a
  // favor de register()/onRegistered, PERO esos devuelven el Firebase
  // Installation ID, no el token de registro FCM. Las Cloud Functions
  // mandan los pushes a 'admins.fcmToken', así que aquí hace falta el
  // token: se mantiene la API deprecada a propósito.
  @override
  // ignore: deprecated_member_use
  Future<String?> getToken() => _messaging.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  @override
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  @override
  Future<NotificationSettings> getNotificationSettings() =>
      _messaging.getNotificationSettings();

  @override
  Future<NotificationSettings> requestPermission() =>
      _messaging.requestPermission();
}

/// Muestra las notificaciones locales visibles.
abstract class PushNotifier {
  Future<void> initialize();
  Future<void> show({
    required String title,
    required String body,
    required String type,
  });

  /// Tipo del push que lanzó la app estando terminada (null si no fue un
  /// push). Solo se puede leer una vez tras initialize().
  Future<String?> launchPayload();
}

class LocalPushNotifier implements PushNotifier {
  LocalPushNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  var _nextId = 1000;

  @override
  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: darwin);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: PushService.onLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse:
          PushService.onLocalNotificationTap,
    );
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        kAdminPushChannelId,
        kAdminPushChannelName,
        description: kAdminPushChannelDescription,
        importance: Importance.max,
      ),
    );
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    required String type,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        kAdminPushChannelId,
        kAdminPushChannelName,
        channelDescription: kAdminPushChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      id: _nextId++,
      title: title,
      body: body,
      notificationDetails: details,
      payload: type,
    );
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.notificationResponse?.payload;
  }
}

// ---------------------------------------------------------------------------
// Handler de fondo (nivel superior: lo exige Firebase Messaging)
// ---------------------------------------------------------------------------

/// Se ejecuta en un isolate aparte cuando llega un push con la app en
/// segundo plano o cerrada. Muestra la misma notificación local que en
/// primer plano. Pequeño y a prueba de fallos: si algo falla, el push
/// simplemente no se muestra; nunca rompe nada.
@pragma('vm:entry-point')
Future<void> adminPushBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    final notifier = LocalPushNotifier();
    await notifier.initialize();
    final content = contentForMessage(
      message.data,
      notificationTitle: message.notification?.title,
      notificationBody: message.notification?.body,
    );
    await notifier.show(
      title: content.title,
      body: content.body,
      type: (message.data['type'] as String?) ?? '',
    );
  } catch (_) {
    // Silencio: el handler de fondo nunca debe lanzar.
  }
}

// ---------------------------------------------------------------------------
// Servicio
// ---------------------------------------------------------------------------

class PushService {
  PushService({
    AdminsRepository? admins,
    MessagingClient? messaging,
    PushNotifier? notifier,
  }) : _admins = admins ?? FirestoreAdminsRepository(),
       _messaging = messaging ?? FirebaseMessagingClient(),
       _notifier = notifier ?? LocalPushNotifier();

  /// Instancia que usan main.dart y HomeShell.
  static final PushService shared = PushService();

  /// Sección pendiente a la que debe ir el panel cuando se toca un push.
  /// HomeShell la escucha y la consume (la pone en null) al navegar.
  static final ValueNotifier<AdminSection?> pendingSection =
      ValueNotifier<AdminSection?>(null);

  /// Enruta un tipo de push a su sección (sin efecto si es desconocido).
  static void routePushType(String? type) {
    final section = sectionForPushType(type);
    if (section != null) pendingSection.value = section;
  }

  /// Toque en una notificación local (primer plano, fondo o app terminada).
  /// El payload es el tipo de push.
  @pragma('vm:entry-point')
  static void onLocalNotificationTap(NotificationResponse response) {
    routePushType(response.payload);
  }

  final AdminsRepository _admins;
  final MessagingClient _messaging;
  final PushNotifier _notifier;

  bool _initialized = false;
  String? _adminUid;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  /// Arranque del receptor de pushes. Se llama una vez en main(), después
  /// de Firebase.initializeApp() y antes de runApp(). Nunca lanza.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // El handler de fondo se registra antes que nada: debe existir antes
    // de que el sistema entregue pushes con la app cerrada.
    try {
      FirebaseMessaging.onBackgroundMessage(adminPushBackgroundHandler);
    } catch (_) {}
    await _requestPermissionOnce();
    await _setupNotifier();
    _listenToMessages();
    await _checkInitialMessage();
  }

  /// Pide el permiso de notificaciones solo si aún no se ha decidido.
  /// (Android 13+: la app no lo pide en ningún otro flujo; este es el
  /// único prompt.)
  Future<void> _requestPermissionOnce() async {
    try {
      final settings = await _messaging
          .getNotificationSettings()
          .timeout(const Duration(seconds: 10));
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        await _messaging.requestPermission().timeout(
          const Duration(seconds: 10),
        );
      }
    } catch (_) {}
  }

  Future<void> _setupNotifier() async {
    try {
      await _notifier.initialize().timeout(const Duration(seconds: 10));
      final launchType = await _notifier
          .launchPayload()
          .timeout(const Duration(seconds: 5));
      routePushType(launchType);
    } catch (_) {}
  }

  void _listenToMessages() {
    try {
      _messageSubscription ??= _messaging.onMessage.listen(
        (message) async {
          try {
            final content = contentForMessage(
              message.data,
              notificationTitle: message.notification?.title,
              notificationBody: message.notification?.body,
            );
            await _notifier.show(
              title: content.title,
              body: content.body,
              type: (message.data['type'] as String?) ?? '',
            );
          } catch (_) {}
        },
        onError: (_) {},
      );
    } catch (_) {}
    try {
      _openedSubscription ??= _messaging.onMessageOpenedApp.listen(
        (message) {
          routePushType(message.data['type'] as String?);
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  Future<void> _checkInitialMessage() async {
    try {
      final initial = await _messaging
          .getInitialMessage()
          .timeout(const Duration(seconds: 5));
      if (initial != null) {
        routePushType(initial.data['type'] as String?);
      }
    } catch (_) {}
  }

  /// Registra al admin verificado: guarda su token FCM actual en su
  /// documento de 'admins' y vuelve a guardarlo cada vez que FCM lo
  /// renueva. Solo se llama desde HomeShell (admin ya verificado).
  Future<void> registerAdmin(String uid) async {
    _adminUid = uid;
    await _saveCurrentToken();
    try {
      _tokenSubscription ??= _messaging.onTokenRefresh.listen(
        (token) async {
          final current = _adminUid;
          if (current != null) await _saveToken(current, token);
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  /// Limpia el admin registrado (al salir del panel). El token guardado en
  /// Firestore se queda: se sobrescribe en el próximo inicio de sesión.
  void unregisterAdmin() {
    _adminUid = null;
    unawaited(_tokenSubscription?.cancel());
    _tokenSubscription = null;
  }

  Future<void> _saveCurrentToken() async {
    final uid = _adminUid;
    if (uid == null) return;
    try {
      final token = await _messaging
          .getToken()
          .timeout(const Duration(seconds: 10));
      if (token != null && token.isNotEmpty) {
        await _saveToken(uid, token);
      }
    } catch (_) {}
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _admins.saveFcmToken(uid, token);
    } catch (_) {}
  }
}
