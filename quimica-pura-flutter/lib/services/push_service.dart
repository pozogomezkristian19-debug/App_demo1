// Push FCM de Quemia (7.1, Task 5): notificaciones push REALES de
// la app principal (firebase_messaging), lado RECEPTOR.
//
// El lado EMISOR ya existe: functions/index.js + payloads.js (9
// triggers, envíos por token). Su contrato, que este archivo cumple
// al pie de la letra:
//
//   - Cada envío lleva notification + data (NUNCA data-only): el
//     título/cuerpo ya vienen en español, sin emojis, y el `data`
//     lleva `type` + el id del documento que lo originó.
//   - `data.type`: 'friend_request', 'friend_request_result',
//     'duel_challenge', 'duel_result', 'support_reply',
//     'announcement'. (Los de admin — 'admin_new_user' y demás —
//     van a la app Admin, no a esta.)
//   - El token vive en users/{uid}: campos 'fcmToken' y
//     'fcmTokenUpdatedAt' (ms). Sin token no hay push.
//
// Cómo llega cada aviso, según el estado de la app:
//
//   - Primer plano: FirebaseMessaging.onMessage lo entrega a Dart;
//     el sistema NO muestra nada solo, así que se muestra una
//     notificación local (canal propio 'quemia_push') Y se crea la
//     entrada en la bandeja (NotificationInbox), para que la
//     campana la marque al abrir la app.
//   - Segundo plano / cerrada: el sistema muestra el aviso solo
//     (lleva notification payload), así que el handler de fondo
//     NO muestra otro (si no, el aviso saldría DOS veces): solo
//     guarda el payload en SharedPreferences (stash) para que la
//     app cree la entrada en la bandeja al volver. Si alguna vez
//     llegara un mensaje data-only (sin notification), el handler
//     de fondo SÍ muestra el aviso local, porque si no nadie lo
//     mostraría.
//   - Toque: onMessageOpenedApp (segundo plano) y getInitialMessage
//     (app cerrada) entregan el mensaje; además, tocar la
//     notificación local (primer plano / data-only) pasa por el
//     handler de toques del plugin. En los tres casos se crea la
//     entrada en la bandeja (red de seguridad, con dedup) y se
//     navega por `data.type` vía NavRequests, el mismo mecanismo
//     que el repaso y la actualización.
//
// El handler de fondo corre en un isolate aparte: NO toca
// NotificationInbox directamente (la lista en memoria del isolate
// principal se comería su escritura al guardar), solo el stash.
//
// Todo va con try/catch + timeout: FCM nunca rompe el arranque,
// el inicio de sesión ni el estudio offline. Sin internet (sin
// token) se salta en silencio y todo sigue como hoy.

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accent.dart';
import 'analytics_sync.dart';
import 'auth_service.dart';
import 'nav_requests.dart';
import 'notification_inbox.dart';
import 'notification_service.dart';
import 'user_prefs.dart';

/// A dónde lleva un aviso push dentro de la app.
enum PushDestination {
  /// Amigos (también los duelos: "Mis duelos abiertos" vive en
  /// FriendsScreen, no hay pantalla de duelos separada).
  friends,

  /// Soporte (hilo con el admin).
  support,

  /// La bandeja de Notificaciones (la campana).
  inbox,
}

/// Destino de cada `data.type` de functions/payloads.js. Un tipo
/// desconocido va a la bandeja: el aviso se ve aunque no se sepa
/// abrir su pantalla.
PushDestination destinationForPushType(String? type) {
  switch (type) {
    case 'friend_request':
    case 'friend_request_result':
    case 'duel_challenge':
    case 'duel_result':
      return PushDestination.friends;
    case 'support_reply':
      return PushDestination.support;
    case 'announcement':
    default:
      return PushDestination.inbox;
  }
}

/// Clave de HomeScreen._openScreenKey para cada destino.
String screenKeyForDestination(PushDestination destination) {
  switch (destination) {
    case PushDestination.friends:
      return 'friends';
    case PushDestination.support:
      return 'support';
    case PushDestination.inbox:
      return 'notifications';
  }
}

/// Entrada de la bandeja que corresponde a un push (función pura:
/// se prueba sin Firebase).
class PushInboxEntry {
  const PushInboxEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.data,
  });

  final String id;
  final InboxKind kind;
  final String title;
  final String body;

  /// El `data` de FCM tal cual, más 'pushType' con el tipo.
  final Map<String, dynamic> data;
}

/// Entrada de la bandeja para un push: el título/cuerpo del
/// notification payload si lo hay (ya viene en español desde
/// functions/payloads.js); si es un mensaje data-only (sin
/// notification), un texto genérico en el mismo tono.
///
/// El id es ESTABLE por documento de origen, y coincide a
/// propósito con los ids que ya usa la sincronización local:
/// 'friend-request-<id>' (SocialService.syncFriendRequestInbox) y
/// 'support-reply-<id>' (SupportService.checkRepliesNow). Así la
/// misma solicitud o respuesta no deja dos entradas aunque llegue
/// por push y luego se sincronice al abrir Amigos o Soporte: el
/// dedup va por id (NotificationInbox.addIfAbsent).
PushInboxEntry inboxEntryForPush({
  required Map<String, String> data,
  String? title,
  String? body,
  String? messageId,
}) {
  final type = data['type'];
  final refId = switch (type) {
    'friend_request' => data['requestId'],
    'friend_request_result' => data['requestId'],
    'duel_challenge' => data['duelId'],
    'duel_result' => data['duelId'],
    'support_reply' => data['messageId'],
    'announcement' => data['announcementId'],
    _ => null,
  };
  var stable = (refId ?? '').trim();
  stable = stable.isEmpty ? (messageId ?? '').trim() : stable;
  final suffix = stable.isEmpty ? 'sin-id' : stable;
  final (String id, InboxKind kind, String fallbackTitle,
      String fallbackBody) = switch (type) {
    'friend_request' => (
        'friend-request-$suffix',
        InboxKind.friendRequest,
        'Solicitud de amistad',
        'Toca para verla y aceptar o rechazar.',
      ),
    'friend_request_result' => (
        'friend-request-result-$suffix',
        InboxKind.friendRequest,
        'Respuesta a tu solicitud',
        'Toca para verla en Amigos.',
      ),
    'duel_challenge' => (
        'duel-challenge-$suffix',
        InboxKind.duel,
        '¡Te retaron a un duelo!',
        'Toca para ver el reto.',
      ),
    'duel_result' => (
        'duel-result-$suffix',
        InboxKind.duel,
        'Duelo terminado',
        'Toca para ver el resultado.',
      ),
    'support_reply' => (
        'support-reply-$suffix',
        InboxKind.support,
        'Soporte te respondió',
        'Toca para leer la respuesta.',
      ),
    'announcement' => (
        'announcement-$suffix',
        InboxKind.announcement,
        'Nuevo aviso de Quemia',
        'Abre la app para leerlo.',
      ),
    _ => (
        'push-${type ?? 'sin-tipo'}-$suffix',
        InboxKind.announcement,
        'Quemia',
        'Tienes un aviso nuevo.',
      ),
  };
  final cleanTitle = (title ?? '').trim();
  final cleanBody = (body ?? '').trim();
  return PushInboxEntry(
    id: id,
    kind: kind,
    title: cleanTitle.isEmpty ? fallbackTitle : cleanTitle,
    body: cleanBody.isEmpty ? fallbackBody : cleanBody,
    data: <String, dynamic>{'pushType': type ?? '', ...data},
  );
}

/// Handler de fondo de FCM: OBLIGATORIAMENTE una función de nivel
/// superior (lo exige el plugin: en release, el tree-shaking la
/// borraría si fuera un método). Corre en un isolate aparte, sin
/// acceso al estado de la app.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await PushService.handleBackgroundMessage(message);
}

class PushService {
  PushService._();

  /// Canal propio de los avisos push: alta importancia para que no
  /// se pierdan entre los recordatorios. distinto del canal de
  /// recordatorios ('melli_study_reminders') y del de prueba: si el
  /// usuario silencia uno, los otros siguen llegando.
  static const _channelId = 'quemia_push';
  static const _channelName = 'Avisos de Quemia';

  /// Id del canal propio del push (Zona G2, capa online): distinto
  /// de los canales locales (recordatorios y prueba), para que las
  /// dos capas no se pisen en Ajustes.
  static String get channelId => _channelId;

  /// Icono pequeño: la misma campana blanca (PNG) que
  /// NotificationService: Android pinta solo su silueta, y el logo
  /// a color saldría como un cuadrado negro.
  static const _smallIcon = 'ic_notif_bell';

  /// Clave del stash de payloads que llegaron en segundo plano:
  /// lista JSON en SharedPreferences, que se drena a la bandeja al
  /// volver a primer plano.
  static const stashKey = 'melli_pending_push_payloads';

  /// Máximo de payloads guardados en el stash (los más nuevos).
  static const int maxStashed = 20;

  /// Campos del token en users/{uid}. Los nombres EXACTOS los lee
  /// functions/index.js (FCM_TOKEN_FIELD = 'fcmToken'): si cambia
  /// uno, el envío por token deja de encontrarlo.
  static const tokenField = 'fcmToken';
  static const tokenUpdatedAtField = 'fcmTokenUpdatedAt';

  /// Acción "Repasar ahora" de NotificationService (su constante es
  /// privada): el handler de toques de este servicio la despacha
  /// igual que el suyo (ver _onLocalTap).
  static const _reviewActionId = 'review_now';

  /// Plugin propio para mostrar los avisos push (primer plano y
  /// data-only en segundo plano). Es OTRA instancia distinta de la
  /// de NotificationService (Zone C): ese archivo no se toca.
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Instancia aparte para el isolate de fondo: la del isolate
  /// principal no existe ahí.
  static final FlutterLocalNotificationsPlugin _bgPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _pluginReady = false;
  static String? _lastSavedToken;
  static String? _lastSavedUid;
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<User?>? _authSub;

  /// Solo para tests: vuelve al estado frío.
  @visibleForTesting
  static void resetForTests() {
    _initialized = false;
    _pluginReady = false;
    _lastSavedToken = null;
    _lastSavedUid = null;
    unawaited(_tokenRefreshSub?.cancel());
    unawaited(_authSub?.cancel());
    _tokenRefreshSub = null;
    _authSub = null;
  }

  /// Inicializa el push. Lo llama main() antes de runApp(), sin
  /// esperar (unawaited): cada paso lleva tope y try/catch, así que
  /// FCM nunca bloquea el arranque ni el inicio de sesión.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // Registro SÍNCRONO de los listeners (antes del primer await):
    // main() llama a init() antes de runApp(), así ningún mensaje
    // que llegue durante el arranque se pierde.
    try {
      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);
    } catch (_) {
      // Sin FCM (tests): no hay fondo que registrar.
    }
    try {
      // En firebase_messaging 15.x, onMessage y
      // onMessageOpenedApp son estáticos (no de la instancia).
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    } catch (_) {
      // Sin FCM: no hay mensajes que escuchar.
    }
    try {
      _tokenRefreshSub =
          FirebaseMessaging.instance.onTokenRefresh.listen((_) {
        unawaited(_saveCurrentToken());
      });
    } catch (_) {
      // Sin FCM: el token no se refresca solo.
    }
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        // El uid cambió (entrar con Google en otro teléfono): el
        // token vive en el documento del uid NUEVO, así que se
        // vuelve a guardar. Enlazar Google NO cambia el uid, así
        // que ese caso no necesita re-guardar.
        if (user != null) unawaited(_saveCurrentToken());
      });
    } catch (_) {
      // Sin Auth: no hay cambios de uid que seguir.
    }
    try {
      WidgetsBinding.instance.addObserver(_PushLifecycleObserver());
    } catch (_) {
      // Sin binding: no hay reintentos al volver a primer plano.
    }
    // Pasos asíncronos, cada uno con tope y try/catch: sin
    // internet (sin token) se salta en silencio y todo sigue
    // como hoy (offline-first intacto).
    try {
      await _ensurePermission().timeout(const Duration(seconds: 15));
    } catch (_) {
      // Sin permiso no hay push: la app sigue.
    }
    try {
      await _saveCurrentToken();
    } catch (_) {
      // Sin token no hay push: se reintenta al volver.
    }
    try {
      await _handleInitialMessage();
    } catch (_) {
      // Sin mensaje inicial: arranque normal.
    }
    try {
      await drainStashedPayloads();
    } catch (_) {
      // Sin stash: nada que drenar.
    }
  }

  /// Permiso de notificaciones (POST_NOTIFICATIONS, Android 13+):
  /// se consulta, y SOLO se pide si aún no se ha preguntado nunca
  /// (notDetermined). El onboarding y la pantalla de Recordatorios
  /// YA lo piden a través de NotificationService, y es el MISMO
  /// permiso del sistema: si ya está concedido o denegado, aquí NO
  /// se vuelve a pedir nada (nada de doble diálogo).
  static Future<void> _ensurePermission() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings()
          .timeout(const Duration(seconds: 3));
      if (settings.authorizationStatus ==
          AuthorizationStatus.notDetermined) {
        // Zona G2: en una instalación nueva el onboarding aún no
        // terminó: NO pedir aquí el permiso del sistema. Lo pide el
        // onboarding (NotificationService.enable(), el MISMO permiso
        // POST_NOTIFICATIONS) con su pantalla que lo explica; pedirlo
        // aquí haría salir el diálogo en el splash, antes de esa
        // pantalla, y sería una segunda petición del mismo permiso.
        // Con el onboarding ya hecho, pedirlo aquí es el único aviso
        // que queda (el onboarding ya no vuelve a preguntar). Si el
        // usuario lo concede en el onboarding, FCM lo ve concedido
        // sin pedir nada más: el token ya se guarda igual en
        // _saveCurrentToken, que no necesita el permiso. main()
        // carga UserPrefs antes de llamar a PushService.init(), así
        // que onboardingDone ya está al día aquí.
        if (!UserPrefs.onboardingDone) return;
        await FirebaseMessaging.instance
            .requestPermission()
            .timeout(const Duration(seconds: 10));
      }
    } catch (_) {
      // Sin permiso no hay push: la app sigue.
    }
  }

  /// Datos del token para users/{uid} (merge). [nowMs] es solo
  /// para los tests (una fecha fija).
  static Map<String, Object?> tokenSaveData(String token,
          {int? nowMs}) =>
      <String, Object?>{
        tokenField: token,
        tokenUpdatedAtField:
            nowMs ?? DateTime.now().millisecondsSinceEpoch,
      };

  /// Guarda el token FCM en el documento del uid actual
  /// (users/{uid}, merge). Sin uid o sin token (sin internet) se
  /// salta en silencio; si el token y el uid no cambiaron, no se
  /// escribe dos veces. Con tope de 5 s (Regla 2): sin internet la
  /// escritura queda encolada en el SDK, pero este intento se da
  /// por fallido y se reintenta al volver a primer plano.
  static Future<void> _saveCurrentToken() async {
    try {
      final uid = AuthService.currentUid;
      if (uid == null || uid.isEmpty) return;
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 5));
      if (token == null || token.isEmpty) return;
      if (token == _lastSavedToken && uid == _lastSavedUid) return;
      await AnalyticsSync.repository
          .setDoc('users', uid, tokenSaveData(token), merge: true)
          .timeout(const Duration(seconds: 5));
      _lastSavedToken = token;
      _lastSavedUid = uid;
    } catch (_) {
      // Sin token guardado no hay push: se reintenta al volver.
    }
  }

  /// Vuelve a guardar el token del uid actual (p. ej. tras enlazar
  /// o entrar con Google). El cambio de uid ya lo cubre el
  /// authStateChanges de init(); esto es por si alguien lo llama a
  /// mano después de un cambio de cuenta.
  static Future<void> refreshToken() async {
    try {
      await _saveCurrentToken();
    } catch (_) {
      // Silencio: se reintenta al volver.
    }
  }

  /// Mensaje con la app en primer plano: el sistema NO muestra
  /// nada solo, así que se crea la entrada en la bandeja Y se
  /// muestra el aviso local. Si el mensaje es data-only (sin
  /// notification), el título/cuerpo salen del fallback de
  /// inboxEntryForPush.
  static Future<void> _handleForegroundMessage(
      RemoteMessage message) async {
    try {
      final data = _stringData(message.data);
      final entry = inboxEntryForPush(
        data: data,
        title: message.notification?.title,
        body: message.notification?.body,
        messageId: message.messageId,
      );
      await NotificationInbox.addIfAbsent(
        id: entry.id,
        kind: entry.kind,
        title: entry.title,
        body: entry.body,
        data: entry.data,
      );
      await _showLocalNotification(entry, data);
    } catch (_) {
      // Un push en primer plano nunca rompe la app.
    }
  }

  /// Mensaje tocado con la app en segundo plano: el sistema ya
  /// mostró el aviso; aquí solo queda crear la entrada (red de
  /// seguridad, con dedup) y navegar a la pantalla que toca.
  static Future<void> _handleOpenedMessage(RemoteMessage message) async {
    await handlePushTapData(
      _stringData(message.data),
      title: message.notification?.title,
      body: message.notification?.body,
      messageId: message.messageId,
    );
  }

  /// La app se abrió tocando un aviso con la app CERRADA: el
  /// mensaje que la abrió sigue esperando en getInitialMessage.
  /// Se resuelve en init(), antes de que HomeScreen se monte, y la
  /// pantalla pendiente la consume su post-frame (NavRequests).
  static Future<void> _handleInitialMessage() async {
    try {
      final message = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 5));
      if (message == null) return;
      await handlePushTapData(
        _stringData(message.data),
        title: message.notification?.title,
        body: message.notification?.body,
        messageId: message.messageId,
      );
    } catch (_) {
      // Sin mensaje inicial: arranque normal.
    }
  }

  /// Toque de un push (sistema o aviso local): crea la entrada en
  /// la bandeja (red de seguridad, con dedup: el primer plano y el
  /// drenaje ya pudieron crearla) y pide la pantalla por
  /// `data.type`. La entrada se crea ANTES de navegar: si la
  /// navegación falla, el aviso queda en la bandeja.
  static Future<void> handlePushTapData(
    Map<String, String> data, {
    String? title,
    String? body,
    String? messageId,
  }) async {
    try {
      final entry = inboxEntryForPush(
        data: data,
        title: title,
        body: body,
        messageId: messageId,
      );
      await NotificationInbox.addIfAbsent(
        id: entry.id,
        kind: entry.kind,
        title: entry.title,
        body: entry.body,
        data: entry.data,
      );
    } catch (_) {
      // Sin bandeja, la navegación sigue igual.
    }
    NavRequests.requestPushScreen(
        screenKeyForDestination(destinationForPushType(data['type'])));
  }

  /// Mensaje en segundo plano o con la app cerrada (isolate
  /// aparte). Los envíos de functions/index.js llevan SIEMPRE
  /// notification + data: el sistema MUESTRA el aviso solo, así
  /// que aquí NO se muestra otro (si no, el aviso saldría DOS
  /// veces): solo se guarda el payload en el stash para que la
  /// app cree la entrada en la bandeja al volver. Solo un mensaje
  /// data-only (sin notification) necesita que mostremos el aviso
  /// nosotros, porque si no nadie lo mostraría.
  static Future<void> handleBackgroundMessage(
      RemoteMessage message) async {
    try {
      await stashMessage(message);
      if (message.notification == null) {
        await _showBackgroundLocalNotification(message);
      }
    } catch (_) {
      // El push en segundo plano nunca rompe nada.
    }
  }

  /// Guarda el payload en el stash (SharedPreferences, lista JSON).
  /// Dedup por messageId de FCM: el mismo mensaje no se guarda dos
  /// veces. Los más viejos se caen cuando hay más de [maxStashed].
  static Future<void> stashMessage(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(stashKey) ?? <String>[];
      final mid = message.messageId;
      final list = <String>[
        for (final item in raw)
          if (mid == null ||
              mid.isEmpty ||
              decodeStashEntry(item)?['messageId'] != mid)
            item,
        encodeStashEntry(
          data: _stringData(message.data),
          title: message.notification?.title,
          body: message.notification?.body,
          messageId: mid,
        ),
      ];
      final capped =
          list.length > maxStashed ? list.sublist(list.length - maxStashed) : list;
      await prefs.setStringList(stashKey, capped);
    } catch (_) {
      // Sin stash, la entrada se crea igual al tocar el aviso.
    }
  }

  /// Una entrada del stash, codificada como JSON: messageId,
  /// título, cuerpo y el `data` de FCM.
  static String encodeStashEntry({
    required Map<String, String> data,
    String? title,
    String? body,
    String? messageId,
  }) {
    return jsonEncode(<String, dynamic>{
      'messageId': messageId,
      'title': title,
      'body': body,
      'data': data,
    });
  }

  /// Decodifica una entrada del stash, o null si está rota. El
  /// `data` queda como Map (las claves/valores son strings).
  static Map<String, dynamic>? decodeStashEntry(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['data'] is! Map) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// Drena el stash a la bandeja: cada payload guardado en segundo
  /// plano crea su entrada (addIfAbsent: el dedup va por el id de
  /// la entrada, así que ni repetir el drenaje ni tocar el aviso
  /// duplican nada). Devuelve cuántas entradas se crearon.
  /// Primero se procesa y luego se borran SOLO las entradas
  /// procesadas: si un push nuevo cae en mitad del drenaje, no se
  /// pierde.
  static Future<int> drainStashedPayloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(stashKey);
      if (raw == null || raw.isEmpty) return 0;
      var added = 0;
      final seen = <String>{};
      final processed = <String>[];
      for (final item in raw) {
        processed.add(item);
        final decoded = decodeStashEntry(item);
        if (decoded == null) continue;
        final dataRaw = decoded['data'] as Map;
        final data = dataRaw.map(
            (k, v) => MapEntry(k.toString(), v.toString()));
        final entry = inboxEntryForPush(
          data: data,
          title: decoded['title'] as String?,
          body: decoded['body'] as String?,
          messageId: decoded['messageId'] as String?,
        );
        if (!seen.add(entry.id)) continue;
        await NotificationInbox.addIfAbsent(
          id: entry.id,
          kind: entry.kind,
          title: entry.title,
          body: entry.body,
          data: entry.data,
        );
        added++;
      }
      final remaining = prefs.getStringList(stashKey) ?? <String>[];
      remaining.removeWhere(processed.contains);
      await prefs.setStringList(stashKey, remaining);
      return added;
    } catch (_) {
      return 0;
    }
  }

  /// Id de la notificación local para una entrada de la bandeja:
  /// estable por id (el mismo aviso reemplaza al anterior en vez
  /// de apilarse), no negativo y distinto por entrada. Hash propio
  /// (djb2) en vez de String.hashCode, que no es estable entre
  /// arranques.
  static int localNotificationIdForEntry(String entryId) {
    var hash = 5381;
    for (final unit in entryId.codeUnits) {
      hash = ((hash << 5) + hash + unit) & 0x7fffffff;
    }
    return hash;
  }

  /// Muestra el aviso push en primer plano, en el canal propio
  /// 'quemia_push' (Importance.high). El payload es el `data` de
  /// FCM en JSON: al tocarlo, _onLocalTap navega por `data.type`.
  static Future<void> _showLocalNotification(
      PushInboxEntry entry, Map<String, String> data) async {
    try {
      await _ensurePluginInitialized();
      await _plugin
          .show(
            id: localNotificationIdForEntry(entry.id),
            title: entry.title,
            body: entry.body,
            payload: jsonEncode(data),
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                _channelName,
                importance: Importance.high,
                priority: Priority.high,
                icon: _smallIcon,
                color: AppAccent.primary,
              ),
            ),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Sin aviso local, la entrada de la bandeja ya está creada.
    }
  }

  /// Muestra el aviso de un mensaje data-only en el isolate de
  /// fondo, con su propia instancia del plugin (la del isolate
  /// principal no existe aquí) y sin handler de toques: al tocarlo
  /// se abre la app y el toque lo recibe el plugin principal al
  /// inicializarse.
  static Future<void> _showBackgroundLocalNotification(
      RemoteMessage message) async {
    try {
      final data = _stringData(message.data);
      final entry = inboxEntryForPush(
        data: data,
        title: message.notification?.title,
        body: message.notification?.body,
        messageId: message.messageId,
      );
      await _bgPlugin
          .initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings(_smallIcon),
            ),
          )
          .timeout(const Duration(seconds: 3));
      await _bgPlugin
          .show(
            id: localNotificationIdForEntry(entry.id),
            title: entry.title,
            body: entry.body,
            payload: jsonEncode(data),
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                _channelName,
                importance: Importance.high,
                priority: Priority.high,
                icon: _smallIcon,
                color: AppAccent.primary,
              ),
            ),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Sin aviso local en fondo, el stash ya guardó el payload.
    }
  }

  /// Inicializa el plugin propio (una sola vez). OJO: esta es una
  /// SEGUNDA instancia de FlutterLocalNotificationsPlugin, y su
  /// initialize() sustituye el handler de toques de la primera
  /// (NotificationService, mismo MethodChannel). Por eso _onLocalTap
  /// despacha TAMBIÉN los payloads viejos de repaso, actualización
  /// e instalación, exactamente como lo hace NotificationService:
  /// sin ese despacho, tocar esos avisos dejaría de abrir nada.
  static Future<void> _ensurePluginInitialized() async {
    if (_pluginReady) return;
    try {
      await _plugin
          .initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings(_smallIcon),
            ),
            onDidReceiveNotificationResponse: _onLocalTap,
          )
          .timeout(const Duration(seconds: 3));
      _pluginReady = true;
    } catch (_) {
      // Sin plugin no hay aviso local, pero el push sí queda en
      // la bandeja (eso ya se hizo antes de llamar aquí).
    }
  }

  /// Toque de una notificación local: si el payload es el JSON de
  /// un push, navega por `data.type` (con la entrada de la bandeja
  /// como red de seguridad); si es un payload viejo de
  /// NotificationService (repaso, actualización, instalación), lo
  /// despacha igual que lo hace su propio handler.
  ///
  /// Solo para tests (Zona G2): el handler real lo pone el plugin
  /// al inicializarse; aquí se prueba que UN solo handler cubre
  /// las dos capas (push + avisos locales viejos).
  @visibleForTesting
  static void dispatchLocalTapForTests(NotificationResponse response) =>
      _onLocalTap(response);

  static void _onLocalTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.startsWith('{')) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          unawaited(handlePushTapData(_stringData(decoded)));
          return;
        }
      } catch (_) {
        // No era JSON: seguir con los payloads viejos.
      }
    }
    if (response.payload == NotificationService.reviewPayload ||
        response.actionId == _reviewActionId) {
      NavRequests.requestReview();
      // Zona G2: la cadena lleva su propio try/catch — si
      // reprogramar falla, el toque NO debe soltar un error sin
      // capturar: el repaso ya quedó pedido arriba.
      unawaited(
        () async {
          try {
            await NotificationService.reconcileFiredReminders();
            await NotificationService.scheduleNext();
          } catch (_) {
            // El repaso ya está pedido; reprogramar es opcional.
          }
        }(),
      );
    } else if (response.payload == NotificationService.updatePayload) {
      NavRequests.requestUpdateDialog();
    } else if (response.payload == NotificationService.installActionId ||
        response.actionId == NotificationService.installActionId) {
      NavRequests.requestInstallApk();
    }
  }

  /// FCM solo admite strings en el `data`: todo a string.
  static Map<String, String> _stringData(Map<String, dynamic> data) =>
      data.map((k, v) => MapEntry(k.toString(), v.toString()));
}

/// Al volver a primer plano: drenar lo que llegó en segundo plano
/// y re-guardar el token si cambió (sin internet se salta en
/// silencio; no escribe dos veces lo mismo).
class _PushLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(PushService.drainStashedPayloads());
      unawaited(PushService.refreshToken());
    }
  }
}
