// Valores de juego configurables desde el servidor (ronda fix8,
// analítica): el documento 'settings/app' de Firestore puede cambiar
// el umbral de paso, los puntos por dificultad y las vidas máximas.
// Cada valor tiene su valor LOCAL de siempre como fallback: si el
// servidor no responde, no trae el campo o trae algo roto, manda el
// local y la app se comporta exactamente como antes.
//
// Claves remotas (las usa el panel de admin al escribir settings/app):
//   'passRequired': int, aciertos de 5 para pasar un nivel (local: 4).
//   'maxLives': int, vidas máximas (local: 10).
//   'pointsCorrect': mapa por dificultad con claves '1'/'2'/'3' (o
//     'easy'/'medium'/'hard'), puntos al acertar (local: 3/5/8).
//   'pointsWrong': igual, puntos al fallar (negativos; local: -5/-8/-12).
//   'supportWhatsAppNumber': String, número de WhatsApp de soporte
//     que se muestra en Soporte (local: '+5356519431').
//   'showWhatsAppInSupport': bool, mostrar el botón de WhatsApp en
//     Soporte (local: false, apagado).
//   'maintenanceMode': bool, la app muestra la pantalla de
//     mantenimiento (local: false, apagado).
//   'maintenanceMessage': String, mensaje que muestra esa pantalla
//     (local: 'Quemia está en mantenimiento. Vuelve pronto.').
//   'profileAnimationsEnabled': bool, kill-switch de las
//     animaciones de perfil (local: true, encendidas): false las
//     quita de todos los perfiles sin compilar nada.
//
// Solo la analítica toca estos valores (AnalyticsSync.applyRemoteSettings);
// el resto de la app solo los LEE. Sin dependencia de Firebase: así
// points.dart y progress.dart siguen siendo lógica pura.

import 'package:flutter/foundation.dart';

import 'premium.dart';

class RemoteTuning {
  RemoteTuning._();

  /// Puntos al acertar por dificultad 1/2/3. Locales: 3/5/8.
  static List<int> correctPoints = <int>[3, 5, 8];

  /// Puntos al fallar por dificultad 1/2/3 (siempre negativos).
  /// Locales: -5/-8/-12.
  static List<int> wrongPoints = <int>[-5, -8, -12];

  /// Aciertos de 5 necesarios para pasar un nivel. Local: 4.
  static int passRequired = 4;

  /// Vidas máximas. Local: 10 (Kristian 2026-11-16: "Pongámoslo en 10";
  /// Duolingo web usa 5, aquí 10 corazones, −1 por fallo en un nivel).
  static int maxLives = 10;

  /// Número de WhatsApp de soporte (el que usa B para la ventanita
  /// y la fila de Acerca de). Local: +5356519431.
  static String supportWhatsAppNumber = '+5356519431';

  /// Mostrar el botón de WhatsApp en Soporte. Local: apagado.
  static bool showWhatsAppInSupport = false;

  /// Modo mantenimiento (lo activa el panel de Admin en
  /// 'settings/app'): la app muestra la pantalla de mantenimiento
  /// en vez de la app normal. Local: apagado.
  static bool maintenanceMode = false;

  /// Animaciones de perfil (Kristian 2026-11-17, kill-switch
  /// online): el Admin puede apagarlas en 'settings/app'
  /// ('profileAnimationsEnabled': false) y desaparecen de TODOS
  /// los perfiles sin compilar nada. Local: encendidas. Solo se
  /// lee; quien decide es el servidor (ver RemoteTuning.apply).
  static bool profileAnimationsEnabled = true;

  /// Mensaje que muestra la pantalla de mantenimiento. Local:
  /// 'Quemia está en mantenimiento. Vuelve pronto.'.
  static String maintenanceMessage =
      'Quemia está en mantenimiento. Vuelve pronto.';

  /// Premium SOLO WEB (el Admin cambia estos valores en
  /// 'settings/app'; la app los escucha en vivo con snapshots):
  /// precios por plan en CUP. Locales (ejemplos): 250 / 600 / 1800.
  static Map<String, int> planPrices = <String, int>{
    for (final p in premiumPlans) p.id: p.examplePrice,
  };

  /// Datos de Transfermóvil para el pago manual (los cambia el
  /// Admin en 'settings/app'). Locales: los ejemplos de
  /// premium.dart. [transfermovilIsExample] dice si algún valor
  /// sigue siendo el ejemplo (la UI debe decir EJEMPLO).
  static String transfermovilCard = kExampleTransfermovilCard;
  static String transfermovilNumber = kExampleTransfermovilNumber;
  static String paymentDetails = kExamplePaymentDetails;
  static bool transfermovilIsExample = true;

  static int correctFor(int difficulty) {
    switch (difficulty) {
      case 1:
        return correctPoints[0];
      case 3:
        return correctPoints[2];
      default:
        return correctPoints[1];
    }
  }

  static int wrongFor(int difficulty) {
    switch (difficulty) {
      case 1:
        return wrongPoints[0];
      case 3:
        return wrongPoints[2];
      default:
        return wrongPoints[1];
    }
  }

  /// Aplica un mapa remoto (settings/app): solo acepta valores sanos;
  /// lo que falte o venga roto mantiene el valor local. Nunca lanza.
  static void apply(Map<String, dynamic> settings) {
    try {
      final pass = settings['passRequired'];
      if (pass is num) {
        final v = pass.toInt();
        if (v >= 1 && v <= 5) passRequired = v;
      }
      final lives = settings['maxLives'];
      if (lives is num) {
        final v = lives.toInt();
        if (v >= 1 && v <= 10) maxLives = v;
      }
      final correct = _pointsMap(settings['pointsCorrect']);
      if (correct != null) correctPoints = correct;
      final wrong = _pointsMap(settings['pointsWrong']);
      if (wrong != null) {
        // Al fallar se RESTA: un valor positivo llegado por error se
        // convierte en negativo, para no premiar un fallo.
        wrongPoints = wrong.map((v) => v <= 0 ? v : -v).toList();
      }
      final supportNumber = settings['supportWhatsAppNumber'];
      if (supportNumber is String) {
        final v = supportNumber.trim();
        if (v.isNotEmpty) supportWhatsAppNumber = v;
      }
      final showWhatsApp = settings['showWhatsAppInSupport'];
      if (showWhatsApp is bool) showWhatsAppInSupport = showWhatsApp;
      final maintenance = settings['maintenanceMode'];
      if (maintenance is bool) maintenanceMode = maintenance;
      // Kill-switch de las animaciones de perfil (2026-11-17):
      // false = se apagan en todos los perfiles sin compilar.
      // Si el campo no viene o viene roto, quedan encendidas.
      final animations = settings['profileAnimationsEnabled'];
      if (animations is bool) profileAnimationsEnabled = animations;
      final maintenanceMessageRaw = settings['maintenanceMessage'];
      if (maintenanceMessageRaw is String) {
        final v = maintenanceMessageRaw.trim();
        if (v.isNotEmpty) maintenanceMessage = v;
      }
      // Premium (solo web; lo lee el paywall y las instrucciones
      // de Transfermóvil): precios y datos de pago, con los
      // ejemplos locales como fallback si falta algo o viene roto.
      planPrices = parsePlanPrices(settings['planPrices']);
      final tm = parseTransfermovilDetails(settings);
      transfermovilCard = tm.card;
      transfermovilNumber = tm.number;
      paymentDetails = tm.details;
      transfermovilIsExample = tm.isExample;
    } catch (_) {
      // Mapa roto: mandan los locales, como si no hubiera llegado nada.
    }
  }

  /// Lee un mapa de puntos por dificultad. Acepta claves '1'/'2'/'3'
  /// o 'easy'/'medium'/'hard'. null si no trae los 3 valores sanos.
  static List<int>? _pointsMap(Object? raw) {
    if (raw is! Map) return null;
    int? read(Object? key) {
      final v = raw[key];
      if (v is! num) return null;
      return v.toInt();
    }

    final easy = read('1') ?? read('easy');
    final medium = read('2') ?? read('medium');
    final hard = read('3') ?? read('hard');
    if (easy == null || medium == null || hard == null) return null;
    return <int>[easy, medium, hard];
  }

  /// Solo para tests: vuelve a los valores locales de siempre.
  @visibleForTesting
  static void resetForTests() {
    correctPoints = <int>[3, 5, 8];
    wrongPoints = <int>[-5, -8, -12];
    passRequired = 4;
    maxLives = 10;
    supportWhatsAppNumber = '+5356519431';
    showWhatsAppInSupport = false;
    maintenanceMode = false;
    maintenanceMessage = 'Quemia está en mantenimiento. Vuelve pronto.';
    profileAnimationsEnabled = true;
    planPrices = <String, int>{
      for (final p in premiumPlans) p.id: p.examplePrice,
    };
    transfermovilCard = kExampleTransfermovilCard;
    transfermovilNumber = kExampleTransfermovilNumber;
    paymentDetails = kExamplePaymentDetails;
    transfermovilIsExample = true;
  }
}
