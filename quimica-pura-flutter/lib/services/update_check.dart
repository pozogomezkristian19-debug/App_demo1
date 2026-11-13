// Aviso de actualización vía GitHub (fix3, punto 20).
//
// Kristian anuncia una actualización editando version.json en la raíz
// del repo (App_demo1): versión + notas + enlace al APK. Al abrirse
// la app, este servicio descarga ese archivo y, si la versión remota
// es mayor que la instalada, muestra el diálogo de actualización.
//
// El flujo NO pasa por el navegador (la app no está en Google Play,
// es sideloaded desde GitHub):
//   diálogo "Hay una nueva actualización"
//     → "Actualizar ahora": la app descarga el APK en SEGUNDO PLANO
//       (notificación bonita con barra de progreso, icono pequeño
//       blanco, acento teal) y al terminar salta el instalador del
//       sistema; la notificación también ofrece "Instalar".
//     → "Más tarde" (solo si force es false): pospone la descarga y
//       programa un RECORDATORIO por notificación para mañana (una vez
//       al día como máximo, hasta actualizar); al tocarlo, la app se
//       abre y vuelve a salir el diálogo. También deja una entrada en
//       la bandeja de Notificaciones (fix4, punto 8). No molesta en
//       cada apertura.
//     → Si el APK de esa versión ya está descargado, el botón es
//       "Instalar" en vez de descargar de nuevo.
//
// Sin internet o si la descarga falla: SILENCIO en la comprobación
// (la app sigue normal, sin diálogo ni error visible). La
// comprobación es en CADA apertura y al volver a primer plano (fix4,
// punto 7): version.json es un JSON diminuto y fallar en silencio no
// cuesta nada. Esto NO hace que el diálogo vuelva a salir en cada
// comprobación: si el usuario tocó "Más tarde", esa versión queda
// registrada como pospuesta y solo avisa su recordatorio por
// notificación (una vez al día como máximo) o una versión aún más
// nueva. Así el aviso sale en cuanto se abre la app tras publicar.
// Además hay un botón manual "Buscar actualización" en Cuenta
// (fix4, punto 7). Si el teléfono no tiene activado "Instalar apps
// desconocidas" para Melli-Qui, al intentar instalar sale un aviso
// claro y lleva a Ajustes para activarlo.
//
// El permiso de instalar y el instalador del sistema solo se pueden
// confirmar en el teléfono real de Kristian, no en pruebas.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/brand_logo.dart';
import '../widgets/lucide_icons.dart';
import 'accent.dart';
import 'localization.dart';
import 'notification_inbox.dart';
import 'notification_service.dart';

/// Versión actual de la app: ÚNICA fuente de verdad en el código.
/// Debe coincidir con `latest` de version.json en la build que se
/// publica, para que no salga un aviso falso nada más instalar.
const String kAppVersion = '7.4';

/// Versión PÚBLICA que se enseña dentro de la app (Quemia 7.3):
/// lo que ve Kristian es 1.0; la 7.3 es solo el número interno de
/// las pruebas (kAppVersion + version.json). El comprobador de
/// actualizaciones compara SIEMPRE kAppVersion (interna), nunca
/// esta: cambiar la pública no afecta a las actualizaciones.
const String kDisplayVersion = '1.0';

/// version.json en la raíz del repo, servido en crudo por GitHub.
const String kUpdateCheckUrl =
    'https://raw.githubusercontent.com/pozogomezkristian19-debug/App_demo1/main/version.json';

/// Claves guardadas en el teléfono (SharedPreferences).
const String kUpdateDismissedKey = 'melli_update_dismissed_version';
const String kUpdatePendingKey = 'melli_update_pending_json';
const String kUpdateReminderVersionKey = 'melli_update_reminder_version';
const String kUpdateReminderAtKey = 'melli_update_reminder_at_ms';
const String kUpdateApkPathKey = 'melli_update_apk_path';
const String kUpdateApkVersionKey = 'melli_update_apk_version';

/// Comparación de versiones por componentes numéricos:
/// "6.0" < "6.1", "6.0" < "6.0.1", "6.10" > "6.9". Devuelve < 0 si
/// [a] es menor que [b], 0 si son iguales y > 0 si [a] es mayor.
/// Los componentes no numéricos se tratan como 0 ("6.0-beta" == "6.0").
int compareVersions(String a, String b) {
  final aParts = a.split('.');
  final bParts = b.split('.');
  final len = aParts.length > bParts.length ? aParts.length : bParts.length;
  for (var i = 0; i < len; i++) {
    final aNum = i < aParts.length ? int.tryParse(aParts[i]) ?? 0 : 0;
    final bNum = i < bParts.length ? int.tryParse(bParts[i]) ?? 0 : 0;
    if (aNum != bNum) return aNum.compareTo(bNum);
  }
  return 0;
}

/// Lo que dice version.json en GitHub.
class UpdateInfo {
  const UpdateInfo({
    required this.latest,
    required this.apkUrl,
    required this.notes,
    required this.force,
  });

  /// Si el archivo trae algo raro (sin versión), no hay nada que
  /// avisar: se devuelve null y la app sigue en silencio.
  static UpdateInfo? fromJson(Map<String, dynamic> json) {
    final latest = json['latest'];
    if (latest is! String || latest.isEmpty) return null;
    final apkUrl = json['apk_url'];
    final notes = json['notes'];
    return UpdateInfo(
      latest: latest,
      apkUrl: apkUrl is String ? apkUrl : '',
      notes: notes is String ? notes : '',
      force: json['force'] == true,
    );
  }

  /// Para guardar la actualización pendiente en el teléfono: al tocar
  /// el recordatorio, el diálogo se muestra con estos datos incluso
  /// sin internet (ver showPendingUpdateDialog).
  Map<String, dynamic> toJson() => {
        'latest': latest,
        'apk_url': apkUrl,
        'notes': notes,
        'force': force,
      };

  final String latest;
  final String apkUrl;
  final String notes;
  final bool force;
}

/// ¿Toca mostrar el diálogo de actualización?
///
/// - La versión remota debe ser mayor que la instalada.
/// - Con `force` no se puede posponer: el aviso sale en cada apertura
///   (la comprobación es en cada apertura, fix4, punto 7).
/// - Sin `force`, si el usuario ya pulsó "Más tarde" para ESA versión,
///   no se le vuelve a preguntar por ella (el recordatorio por
///   notificación y la entrada de la bandeja son lo que avisa).
bool shouldShowUpdate({
  required String latest,
  required bool force,
  required String? dismissedVersion,
}) {
  if (compareVersions(latest, kAppVersion) <= 0) return false;
  if (!force && dismissedVersion == latest) return false;
  return true;
}

/// ¿Toca programar (o reprogramar) el recordatorio de mañana?
/// No se duplica si ya hay uno para ESTA versión y aún no ha llegado;
/// si salió una versión más nueva, se actualiza a esa.
bool shouldScheduleReminder({
  required String latest,
  required String? scheduledVersion,
  required DateTime? scheduledAt,
  required DateTime now,
}) {
  if (scheduledVersion == latest &&
      scheduledAt != null &&
      scheduledAt.isAfter(now)) {
    return false;
  }
  return true;
}

/// Descarga el contenido de una URL como texto, o null si falla.
/// Inyectable en los tests; en la app usa HttpClient (sin dependencia
/// nueva). Timeout de ~5 s: sin internet no se queda colgada.
typedef UpdateJsonFetcher = Future<String?> Function(Uri url);

Future<String?> _defaultFetcher(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request =
        await client.getUrl(url).timeout(const Duration(seconds: 5));
    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;
    return await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 5));
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Fuente de un APK para descargar: tamaño total (puede ser -1 si el
/// servidor no lo dice) y el flujo de bytes.
class ApkDownloadSource {
  const ApkDownloadSource({required this.totalBytes, required this.stream});
  final int totalBytes;
  final Stream<List<int>> stream;
}

/// Descarga un APK por streaming: `fetcher` es inyectable (en la app,
/// HttpClient; en los tests, un flujo falso).
typedef ApkStreamFetcher = Future<ApkDownloadSource> Function(Uri url);

Future<ApkDownloadSource> _httpApkSource(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  final request = await client.getUrl(url);
  final response = await request.close();
  if (response.statusCode != 200) {
    client.close();
    throw HttpException('HTTP ${response.statusCode}');
  }
  return ApkDownloadSource(
    totalBytes: response.contentLength,
    // El cliente se cierra cuando el flujo termina (o falla): si se
    // cerrara aquí, el flujo se cortaría.
    stream: response.transform<List<int>>(
      StreamTransformer.fromHandlers(
        handleDone: (sink) {
          client.close();
          sink.close();
        },
        handleError: (error, stackTrace, sink) {
          client.close();
          sink.addError(error, stackTrace);
        },
      ),
    ),
  );
}

/// Máquina de estados de la descarga del APK:
/// idle → downloading → downloaded → installing.
enum UpdateDownloadState { idle, downloading, downloaded, installing }

/// Decisión pura de cuándo actualizar la notificación de progreso de
/// la descarga (zona C, 2026-11-12).
///
/// Antes, `startDownload` solo mostraba la notificación cuando
/// llegaba el primer trozo Y el total era conocido: si la conexión
/// tardaba (GitHub redirige el APK) o el servidor no daba
/// Content-Length (total <= 0), la notificación no aparecía nunca y
/// Kristian veía que "no pasaba nada" aunque la descarga estuviera
/// en marcha. Ahora la regla es:
///
/// - la PRIMERA decisión siempre muestra algo: 0 % determinado si el
///   total ya se conoce, o barra indeterminada si no ([percentFor]
///   devuelve -1 con total <= 0);
/// - con total desconocido se sigue mostrando indeterminada hasta que
///   el total se conoce: ese cambio se muestra DE INMEDIATO, sin
///   esperar al intervalo mínimo;
/// - después solo se muestra si el porcentaje CAMBIÓ (y nunca hacia
///   atrás) y pasaron al menos [minInterval] desde la última vez:
///   en una descarga rápida, 100 `show()` seguidos los funde MIUI y
///   la barra parece atascada; con ~1 aviso cada 500 ms como mucho,
///   cada actualización llega.
///
/// Es una clase con estado (guarda el último porcentaje y la hora),
/// pero la decisión en sí es pura dados (received, total, now): se
/// crea una por descarga en [UpdateCheckService.startDownload].
class UpdateProgressThrottle {
  UpdateProgressThrottle({
    this.minInterval = const Duration(milliseconds: 500),
  });

  /// Intervalo mínimo entre dos actualizaciones de la notificación.
  final Duration minInterval;

  /// Último porcentaje mostrado, o -1 si lo mostrado es la barra
  /// indeterminada, o null si aún no se mostró nada.
  int? _lastPercent;

  /// Hora de la última actualización mostrada.
  DateTime? _lastShownAt;

  /// ¿Lo que se está mostrando ahora es la barra indeterminada?
  bool get showingIndeterminate => _lastPercent == -1;

  /// Último porcentaje mostrado (-1 = indeterminado, null = nada aún).
  int? get lastPercent => _lastPercent;

  /// Porcentaje 0..100 de [received] sobre [total], o -1 si el total
  /// es desconocido (<= 0). No lanza nunca y nunca pasa de 100.
  static int percentFor(int received, int total) {
    if (total <= 0) return -1;
    if (received <= 0) return 0;
    final pct = received * 100 ~/ total;
    return pct.clamp(0, 100);
  }

  /// ¿Hay que actualizar la notificación con este progreso?
  /// Si devuelve true, el llamador muestra [percentFor] (o la barra
  /// indeterminada si es -1) y esta llamada queda registrada como
  /// la última mostrada.
  bool shouldShow({
    required int received,
    required int total,
    required DateTime now,
  }) {
    final pct = percentFor(received, total);
    // Nada mostrado aún: la primera vez siempre se muestra, sea 0 %
    // o indeterminada. Es lo que hace visible la descarga antes del
    // primer byte.
    if (_lastPercent == null) {
      _record(pct, now);
      return true;
    }
    // Total aún desconocido y ya se muestra indeterminada: nada nuevo.
    if (pct < 0) return false;
    // El total se acaba de conocer (antes indeterminada): el cambio
    // de indeterminada a 0 % se muestra de inmediato, sin esperar.
    if (_lastPercent! < 0) {
      _record(pct, now);
      return true;
    }
    // Sin cambio, o hacia atrás: no se muestra.
    if (pct <= _lastPercent!) return false;
    // Mismo segundo que la última: MIUI funde avisos tan seguidos.
    if (now.difference(_lastShownAt!) < minInterval) return false;
    _record(pct, now);
    return true;
  }

  void _record(int pct, DateTime now) {
    _lastPercent = pct;
    _lastShownAt = now;
  }
}

/// Descarga del APK a un archivo, con progreso. No toca notificaciones
/// ni permisos: eso lo orquesta UpdateCheckService.
class UpdateDownloader {
  UpdateDownloader();

  final ValueNotifier<UpdateDownloadState> state =
      ValueNotifier(UpdateDownloadState.idle);
  final ValueNotifier<double> progress = ValueNotifier(0);

  String? downloadedPath;
  String? downloadedVersion;

  /// Nombre del APK de una versión: estable, para saber si ya está
  /// descargado sin volver a bajarlo.
  static String apkFileName(String version) => 'quemia-$version.apk';

  /// Descarga [info] en [dir] y devuelve el archivo, o null si falla.
  /// Si el APK de esa versión ya está descargado y no está vacío, no
  /// vuelve a descargarlo: devuelve el archivo que ya hay.
  Future<File?> download({
    required UpdateInfo info,
    required Directory dir,
    ApkStreamFetcher? fetcher,
    void Function(int received, int total)? onProgress,
  }) async {
    final target = File('${dir.path}/${apkFileName(info.latest)}');
    if (await target.exists() && await target.length() > 0) {
      state.value = UpdateDownloadState.downloaded;
      progress.value = 1;
      downloadedPath = target.path;
      downloadedVersion = info.latest;
      return target;
    }
    state.value = UpdateDownloadState.downloading;
    progress.value = 0;
    final tmp = File('${target.path}.part');
    try {
      final source = await (fetcher ?? _httpApkSource)(Uri.parse(info.apkUrl));
      // Zona C (2026-11-12): avisar del 0 % ANTES del primer trozo.
      // El llamador (startDownload) ya mostró la notificación al
      // arrancar, pero este aviso es el que dice el total real en
      // cuanto se conocen las cabeceras: con total conocido pasa de
      // indeterminada a 0 % determinado; con total desconocido sigue
      // indeterminada. Sin esto, con un servidor lento en el primer
      // trozo no habría ningún progreso hasta que llegara.
      onProgress?.call(0, source.totalBytes);
      var received = 0;
      final sink = tmp.openWrite();
      await for (final chunk in source.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (source.totalBytes > 0) {
          progress.value = received / source.totalBytes;
        }
        onProgress?.call(received, source.totalBytes);
      }
      await sink.flush();
      await sink.close();
      if (source.totalBytes > 0 && received < source.totalBytes) {
        throw const HttpException('descarga incompleta');
      }
      await tmp.rename(target.path);
      state.value = UpdateDownloadState.downloaded;
      progress.value = 1;
      downloadedPath = target.path;
      downloadedVersion = info.latest;
      return target;
    } catch (_) {
      state.value = UpdateDownloadState.idle;
      progress.value = 0;
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {
        // Borrar el parcial es opcional.
      }
      return null;
    }
  }
}

/// Instalador del sistema (Android): abre el instalador con el APK
/// ya descargado. Habla con MainActivity por MethodChannel; el
/// FileProvider y el permiso REQUEST_INSTALL_PACKAGES viven en el
/// AndroidManifest. En los tests el canal se simula (mock).
class UpdateInstaller {
  UpdateInstaller._();

  static const _channel = MethodChannel('com.melliqui/update_installer');

  /// ¿Puede la app pedir instalar APKs? En Android 8+ es el permiso
  /// "Instalar apps desconocidas" para Melli-Qui. Si el canal falla,
  /// se asume que sí y decide el sistema.
  static Future<bool> canInstallUnknownSources() async {
    try {
      final ok = await _channel.invokeMethod<bool>('canInstallUnknownSources');
      return ok ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Abre el instalador del sistema con el APK de [path].
  static Future<bool> installApk(String path) async {
    try {
      final ok =
          await _channel.invokeMethod<bool>('installApk', {'path': path});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre los ajustes del sistema en "Instalar apps desconocidas"
  /// para Melli-Qui, para que el usuario active el permiso.
  static Future<void> openUnknownSourcesSettings() async {
    try {
      await _channel.invokeMethod<void>('openUnknownSourcesSettings');
    } catch (_) {
      // Sin canal (pruebas), no hay ajustes que abrir.
    }
  }
}

/// Textos del flujo de actualización en el idioma del usuario.
/// `{v}` es la versión. Español por defecto.
Map<String, String> updateTexts(String lang) {
  switch (lang) {
    case 'en':
      return {
        'dialogTitle': 'A new update is available',
        'versionAvailable': 'Version {v} is available',
        'updateNow': 'Update now',
        'install': 'Install',
        'later': 'Later',
        'forceNote': 'This update is required to keep using the app.',
        'downloadingTitle': 'Downloading Quemia',
        'downloadingBody': 'Version {v}',
        'downloadReadyTitle': 'Download complete',
        'downloadReadyBody': 'Version {v} is ready. Tap to install it.',
        'downloadFailedTitle': 'Could not download',
        'downloadFailedBody': 'Check your connection and try again later.',
        'reminderBody': 'There is a pending update',
        'unknownSourcesTitle': 'Allow installing apps',
        'unknownSourcesBody':
            'To install the update, turn on "Install unknown apps" for Quemia in your phone settings.',
        'goToSettings': 'Go to Settings',
        'notNow': 'Not now',
      };
    case 'fr':
      return {
        'dialogTitle': 'Une nouvelle mise à jour est disponible',
        'versionAvailable': 'Version {v} disponible',
        'updateNow': 'Mettre à jour',
        'install': 'Installer',
        'later': 'Plus tard',
        'forceNote':
            'Cette mise à jour est obligatoire pour continuer à utiliser l’appli.',
        'downloadingTitle': 'Téléchargement de Quemia',
        'downloadingBody': 'Version {v}',
        'downloadReadyTitle': 'Téléchargement terminé',
        'downloadReadyBody':
            'La version {v} est prête. Touchez pour l’installer.',
        'downloadFailedTitle': 'Téléchargement impossible',
        'downloadFailedBody':
            'Vérifiez votre connexion et réessayez plus tard.',
        'reminderBody': 'Une mise à jour est en attente',
        'unknownSourcesTitle': 'Autoriser l’installation d’applis',
        'unknownSourcesBody':
            'Pour installer la mise à jour, activez « Installer des applis inconnues » pour Quemia dans les réglages du téléphone.',
        'goToSettings': 'Aller aux réglages',
        'notNow': 'Pas maintenant',
      };
    case 'it':
      return {
        'dialogTitle': 'È disponibile un nuovo aggiornamento',
        'versionAvailable': 'Versione {v} disponibile',
        'updateNow': 'Aggiorna ora',
        'install': 'Installa',
        'later': 'Più tardi',
        'forceNote':
            'Questo aggiornamento è obbligatorio per continuare a usare l’app.',
        'downloadingTitle': 'Download di Quemia',
        'downloadingBody': 'Versione {v}',
        'downloadReadyTitle': 'Download completato',
        'downloadReadyBody': 'La versione {v} è pronta. Tocca per installarla.',
        'downloadFailedTitle': 'Download non riuscito',
        'downloadFailedBody': 'Controlla la connessione e riprova più tardi.',
        'reminderBody': 'C’è un aggiornamento in sospeso',
        'unknownSourcesTitle': 'Consenti installazione app',
        'unknownSourcesBody':
            'Per installare l’aggiornamento, attiva «Installa app sconosciute» per Quemia nelle impostazioni del telefono.',
        'goToSettings': 'Vai alle impostazioni',
        'notNow': 'Non ora',
      };
    case 'pt':
      return {
        'dialogTitle': 'Há uma nova atualização disponível',
        'versionAvailable': 'Versão {v} disponível',
        'updateNow': 'Atualizar agora',
        'install': 'Instalar',
        'later': 'Mais tarde',
        'forceNote':
            'Esta atualização é obrigatória para continuar usando o app.',
        'downloadingTitle': 'Baixando Quemia',
        'downloadingBody': 'Versão {v}',
        'downloadReadyTitle': 'Download concluído',
        'downloadReadyBody': 'A versão {v} está pronta. Toque para instalar.',
        'downloadFailedTitle': 'Não foi possível baixar',
        'downloadFailedBody':
            'Verifique sua conexão e tente novamente mais tarde.',
        'reminderBody': 'Há uma atualização pendente',
        'unknownSourcesTitle': 'Permitir instalar apps',
        'unknownSourcesBody':
            'Para instalar a atualização, ative "Instalar apps desconhecidos" para o Quemia nas configurações do telefone.',
        'goToSettings': 'Ir para Ajustes',
        'notNow': 'Agora não',
      };
    case 'ru':
      return {
        'dialogTitle': 'Доступно новое обновление',
        'versionAvailable': 'Версия {v} доступна',
        'updateNow': 'Обновить сейчас',
        'install': 'Установить',
        'later': 'Позже',
        'forceNote':
            'Это обновление обязательно, чтобы продолжать пользоваться приложением.',
        'downloadingTitle': 'Скачивание Quemia',
        'downloadingBody': 'Версия {v}',
        'downloadReadyTitle': 'Скачивание завершено',
        'downloadReadyBody': 'Версия {v} готова. Нажмите, чтобы установить.',
        'downloadFailedTitle': 'Не удалось скачать',
        'downloadFailedBody': 'Проверьте подключение и попробуйте позже.',
        'reminderBody': 'Есть ожидающее обновление',
        'unknownSourcesTitle': 'Разрешить установку приложений',
        'unknownSourcesBody':
            'Чтобы установить обновление, включите «Установка неизвестных приложений» для Quemia в настройках телефона.',
        'goToSettings': 'Перейти в настройки',
        'notNow': 'Не сейчас',
      };
    default:
      return {
        'dialogTitle': 'Hay una nueva actualización',
        'versionAvailable': 'Versión {v} disponible',
        'updateNow': 'Actualizar ahora',
        'install': 'Instalar',
        'later': 'Más tarde',
        'forceNote':
            'Esta actualización es obligatoria para seguir usando la app.',
        'downloadingTitle': 'Descargando Quemia',
        'downloadingBody': 'Versión {v}',
        'downloadReadyTitle': 'Descarga completa',
        'downloadReadyBody':
            'La versión {v} ya está lista. Toca para instalarla.',
        'downloadFailedTitle': 'No se pudo descargar',
        'downloadFailedBody':
            'Revisa tu conexión e inténtalo de nuevo más tarde.',
        'reminderBody': 'Hay una actualización pendiente',
        'unknownSourcesTitle': 'Permite instalar apps',
        'unknownSourcesBody':
            'Para instalar la actualización, activa "Instalar apps desconocidas" para Quemia en los ajustes del teléfono.',
        'goToSettings': 'Ir a Ajustes',
        'notNow': 'Ahora no',
      };
  }
}

/// Resultado de la comprobación MANUAL ("Buscar actualización").
enum ManualUpdateResult {
  /// La versión remota es igual o más vieja que la instalada.
  upToDate,

  /// Hay una versión nueva: el diálogo ya se mostró.
  updateAvailable,

  /// No se pudo descargar version.json (sin internet o archivo roto).
  checkFailed,
}

/// Comprueba si hay actualización y, si toca, muestra el diálogo.
/// La app la llama al abrirse (tras el primer frame); el servicio
/// además se vuelve a comprobar solo al volver a primer plano
/// (AppLifecycleListener, fix3 punto 20b). La comprobación es en
/// CADA apertura y al volver (fix4, punto 7): version.json es un
/// JSON diminuto y fallar en silencio no cuesta nada.
/// En silencio total si no hay internet, si version.json no existe o
/// si trae algo raro: la app sigue en silencio, sin avisar de nada.
/// [fromReminder]: desde el recordatorio de actualización (el usuario
/// tocó la notificación): se salta la versión descartada, porque lo
/// pidió él.
class UpdateCheckService {
  UpdateCheckService._();

  /// Descargador compartido: su `state` es la máquina de estados de
  /// la actualización (idle → downloading → downloaded → installing)
  /// y su `progress` el progreso 0-1. Lo puede escuchar la UI.
  static final UpdateDownloader downloader = UpdateDownloader();

  /// Observador de ciclo de vida (fix3, punto 20b): al volver a
  /// primer plano se vuelve a comprobar (cada 4 h como mucho). Se
  /// arma DENTRO del servicio para no tocar main.dart: HomeScreen ya
  /// llama a [checkForUpdate] al abrirse, y ese contexto vive toda
  /// la sesión de la app (es el de la pantalla principal).
  static AppLifecycleListener? _lifecycleListener;

  /// Contexto guardado para abrir el diálogo al volver a primer
  /// plano (el de HomeScreen, que no se desmonta en la sesión).
  static BuildContext? _resumeContext;

  /// Fetcher guardado para la re-comprobación al volver (en la app
  /// es null y se usa HttpClient; en los tests, el falso inyectado).
  static UpdateJsonFetcher? _resumeFetcher;

  /// Para no solapar dos comprobaciones (p. ej. abrir y volver a
  /// primer plano seguidos): la segunda se salta.
  static bool _checkInFlight = false;

  /// Para no apilar dos diálogos de actualización (p. ej. volver a
  /// primer plano con el diálogo ya abierto): mientras uno está en
  /// pantalla, los demás no se muestran.
  static bool _dialogShowing = false;

  /// Arma el observador de ciclo de vida en la primera llamada a
  /// [checkForUpdate]; las llamadas posteriores solo actualizan el
  /// contexto guardado. Idempotente.
  static void _armResumeCheck(
    BuildContext context, {
    UpdateJsonFetcher? fetcher,
  }) {
    _resumeContext = context;
    _resumeFetcher = fetcher;
    if (_lifecycleListener != null) return;
    try {
      _lifecycleListener = AppLifecycleListener(
        onResume: _onForeground,
      );
    } catch (_) {
      // Sin binding (algún test sin widgets): la comprobación al
      // abrir sigue funcionando; solo no hay re-comprobación al
      // volver a primer plano.
      _lifecycleListener = null;
    }
  }

  /// Al volver a primer plano: comprobar, con la misma cadencia que
  /// al abrir (en cada vuelta, fix4, punto 7; si el usuario pospuso
  /// ESA versión, no hay diálogo: solo el recordatorio).
  static void _onForeground() {
    final context = _resumeContext;
    if (context == null) return;
    unawaited(
      checkForUpdate(context, fetcher: _resumeFetcher),
    );
  }

  /// Solo para tests: desarma el observador de ciclo de vida y
  /// limpia el contexto guardado, para que los tests no se pisen
  /// entre sí (el observador vive en el binding, que es global).
  @visibleForTesting
  static void resetForTests() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _resumeContext = null;
    _resumeFetcher = null;
    _checkInFlight = false;
    _dialogShowing = false;
  }

  static Future<void> checkForUpdate(
    BuildContext context, {
    UpdateJsonFetcher? fetcher,
    DateTime? nowOverride,
    bool fromReminder = false,
  }) async {
    // El observador queda armado desde la primera llamada (la de
    // HomeScreen al abrirse) y vive toda la sesión de la app.
    _armResumeCheck(context, fetcher: fetcher);
    if (_checkInFlight) return;
    _checkInFlight = true;
    try {
      await _performCheck(
        context,
        fetcher: fetcher,
        nowOverride: nowOverride,
        fromReminder: fromReminder,
      );
    } finally {
      _checkInFlight = false;
    }
  }

  /// Descarga version.json y lo parsea. null si no hay internet, si
  /// el archivo no existe o si trae algo raro. La usan la
  /// comprobación al abrir y la manual de Cuenta.
  static Future<UpdateInfo?> _fetchUpdateInfo(
      UpdateJsonFetcher? fetcher) async {
    final raw = await (fetcher ?? _defaultFetcher)(Uri.parse(kUpdateCheckUrl));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return UpdateInfo.fromJson(decoded);
      }
    } catch (_) {
      // JSON roto: silencio, como siempre.
    }
    return null;
  }

  static Future<void> _performCheck(
    BuildContext context, {
    UpdateJsonFetcher? fetcher,
    DateTime? nowOverride,
    bool fromReminder = false,
  }) async {
    final now = nowOverride ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    // Comprobación en CADA apertura (fix4, punto 7): version.json es
    // diminuto y fallar en silencio no cuesta nada, así que ya no
    // hay cadencia de 4 horas ni se anota la última comprobación.
    final info = await _fetchUpdateInfo(fetcher);
    if (info == null) return;

    // Ya estamos al día (o por encima): se acabó el aviso y se
    // limpian el recordatorio y el APK viejo.
    if (compareVersions(info.latest, kAppVersion) <= 0) {
      await _cleanupAfterUpdate();
      return;
    }

    if (fromReminder) {
      if (!context.mounted) return;
      await showUpdateDialog(context, info);
      return;
    }

    final dismissed = prefs.getString(kUpdateDismissedKey);
    if (!info.force && dismissed == info.latest) {
      // Pospuesta con "Más tarde": al abrir no hay diálogo; lo que
      // avisa es el recordatorio por notificación de mañana.
      await scheduleUpdateReminder(info, now);
      return;
    }
    if (!shouldShowUpdate(
      latest: info.latest,
      force: info.force,
      dismissedVersion: dismissed,
    )) {
      return;
    }
    if (!context.mounted) return;
    await showUpdateDialog(context, info);
  }

  /// Comprobación MANUAL, desde el botón "Buscar actualización" de
  /// Cuenta (fix4, punto 7): fuerza el chequeo y dice qué pasó.
  /// A diferencia de la automática, pasa por encima de "Más tarde":
  /// si el usuario lo pide, el diálogo sale aunque esa versión se
  /// hubiera pospuesto. El fetcher es el guardado en la comprobación
  /// al abrir (en los tests, el falso inyectado); en la app es null
  /// y se usa HttpClient.
  static Future<ManualUpdateResult> checkForUpdateManual(
    BuildContext context, {
    UpdateJsonFetcher? fetcher,
  }) async {
    final info =
        await _fetchUpdateInfo(fetcher ?? _resumeFetcher ?? _defaultFetcher);
    if (info == null) return ManualUpdateResult.checkFailed;
    if (compareVersions(info.latest, kAppVersion) <= 0) {
      await _cleanupAfterUpdate();
      return ManualUpdateResult.upToDate;
    }
    if (!context.mounted) return ManualUpdateResult.checkFailed;
    await showUpdateDialog(context, info);
    return ManualUpdateResult.updateAvailable;
  }

  /// Muestra el diálogo de la actualización pendiente (la que guardó
  /// el recordatorio). Al tocar el recordatorio, la app se abre y
  /// sale este diálogo, incluso sin internet. Si ya no hay nada
  /// pendiente guardado, se comprueba de nuevo vía GitHub.
  static Future<void> showPendingUpdateDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kUpdatePendingKey);
    UpdateInfo? info;
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          info = UpdateInfo.fromJson(decoded);
        }
      } catch (_) {
        info = null;
      }
    }
    if (info == null) {
      await checkForUpdate(context, fromReminder: true);
      return;
    }
    if (compareVersions(info.latest, kAppVersion) <= 0) {
      await _cleanupAfterUpdate();
      return;
    }
    if (!context.mounted) return;
    await showUpdateDialog(context, info);
  }

  /// El diálogo de actualización: FONDO BLANCO con el acento teal de
  /// la app (fondo blanco y teal fijos, no del tema, para que se vea
  /// igual en claro y en oscuro). Botón principal "Actualizar ahora"
  /// (o "Instalar" si el APK de esa versión ya está descargado) y
  /// "Más tarde" salvo que la actualización sea obligatoria.
  ///
  /// Los botones solo cierran el diálogo con una elección
  /// ('update' / 'later'; tocar fuera devuelve null): lo que se hace
  /// con esa elección pasa DESPUÉS, fuera del diálogo. Así "Más
  /// tarde" y descartar el diálogo hacen lo mismo (posponer +
  /// recordatorio + entrada en la bandeja), y nunca se ejecuta dos
  /// veces. Si ya hay un diálogo abierto, no se apila otro.
  static Future<void> showUpdateDialog(
      BuildContext context, UpdateInfo info) async {
    if (_dialogShowing) return;
    final t = updateTexts(AppLang.code);
    final already = await _downloadedApkFile(info.latest) != null;
    if (!context.mounted) return;
    _dialogShowing = true;
    String? choice;
    try {
      choice = await showGeneralDialog<String>(
        context: context,
        // Con actualización obligatoria no se puede cerrar tocando
        // fuera ni con el botón atrás: solo queda Actualizar.
        barrierDismissible: !info.force,
        // showGeneralDialog exige barrierLabel != null cuando la
        // barrera cierra el diálogo: la misma etiqueta que usaba
        // showDialog ("Cerrar" localizada).
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        // Barrera transparente (ronda 7.2, Zona C): el velo + blur
        // los pinta el pageBuilder (liquid glass). El showDialog
        // ponía su propio velo gris plano y no dejaba ver el fondo
        // difuminado. La barrera sigue ahí y sigue cerrando el
        // diálogo al tocar fuera (si no es obligatoria): el blur
        // lleva IgnorePointer para no comerse esos toques.
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          // Diálogo según el tema (auditoría 7.2): en oscuro la
          // cara es oscura y el texto claro; en blanco fijo se
          // veía como tarjeta clara en oscuro. El teal se conserva
          // en los dos temas (se lee sobre oscuro).
          final scheme = Theme.of(dialogContext).colorScheme;
          final isDark =
              Theme.of(dialogContext).brightness == Brightness.dark;
          final dialogInk =
              isDark ? scheme.onSurface : BrandColors.ink;
          return PopScope(
          canPop: !info.force,
          child: Stack(
            children: [
              // Blur real (sigma 10) + velo negro 35 % a pantalla
              // completa, detrás del diálogo. Sin toques: la
              // barrera de arriba recibe el toque fuera del
              // diálogo y lo cierra.
              Positioned.fill(
                child: IgnorePointer(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
              // El MISMO diálogo de siempre, centrado, con el
              // MISMO contenido: fondo blanco en claro (oscuro en
              // oscuro, auditoría 7.2), radio 20, icono, título,
              // versión, notas, botones.
              Center(
                child: Dialog(
                  backgroundColor: isDark
                      ? scheme.surfaceContainerHighest
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  insetPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    // Con desplazamiento: unas notas largas nunca desbordan el
                    // diálogo en un teléfono estrecho.
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color:
                                      AppAccent.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: LucideIcon(
                                  LucideIcons.download,
                                  size: 26,
                                  color: AppAccent.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  t['dialogTitle']!,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: dialogInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            // La versión que se enseña es la PÚBLICA
                            // (1.0): la interna (info.latest, 7.3) es
                            // solo para nosotros y el comprobador.
                            t['versionAvailable']!
                                .replaceAll('{v}', kDisplayVersion),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppAccent.primary,
                            ),
                          ),
                          if (info.notes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              info.notes,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.45,
                                color: dialogInk,
                              ),
                            ),
                          ],
                          if (info.force) ...[
                            const SizedBox(height: 8),
                            Text(
                              t['forceNote']!,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: dialogInk,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              // Quemia 7.3: el diálogo sigue al acento elegido en
                              // Cuenta (antes era teal fijo también con el
                              // tema violeta). Con Verde se ve igual que antes.
                              style: FilledButton.styleFrom(
                                backgroundColor: AppAccent.primary,
                                foregroundColor: Colors.white,
                                shadowColor: AppAccent.primaryDark,
                                elevation: 4,
                              ),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop('update'),
                              child: Text(
                                  already ? t['install']! : t['updateNow']!),
                            ),
                          ),
                          if (!info.force) ...[
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppAccent.primary,
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop('later'),
                                child: Text(t['later']!),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    } finally {
      _dialogShowing = false;
    }
    if (choice == 'update') {
      // "Actualizar ahora" (o "Instalar", si el APK ya estaba
      // descargado): el diálogo ya se cerró, se descarga o instala.
      if (!context.mounted) return;
      if (already) {
        await installDownloadedApk(context);
      } else {
        await startDownload(context, info);
      }
      return;
    }
    // "Más tarde" o descartar el diálogo tocando fuera (null):
    // posponer. Con force no se puede llegar aquí (no hay botón
    // "Más tarde" ni se puede cerrar tocando fuera).
    await _onLaterPressed(info);
  }

  /// "Más tarde": pospone la descarga. No vuelve a preguntar por ESA
  /// versión al abrir la app; el aviso pasa al sistema de
  /// notificaciones: un recordatorio para mañana (ver
  /// scheduleUpdateReminder) y una entrada en la bandeja de
  /// Notificaciones (fix4, punto 8), que desaparece al actualizar.
  static Future<void> _onLaterPressed(UpdateInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUpdateDismissedKey, info.latest);
    await scheduleUpdateReminder(info, DateTime.now());
    await NotificationInbox.add(
      id: 'update-${info.latest}',
      kind: InboxKind.update,
      title: tr('inboxUpdateTitle'),
      body: '${tr('inboxUpdateBody').replaceFirst('{v}', info.latest)}'
          '${info.notes.isEmpty ? '' : '\n${info.notes}'}',
      data: info.toJson(),
    );
  }

  /// Programa el recordatorio por notificación para mañana (al día
  /// siguiente, una vez al día como máximo, hasta actualizar). Si
  /// sale una versión aún más nueva, el recordatorio se actualiza a
  /// esa (se cancela el viejo y se programa el nuevo). El recordatorio
  /// usa el MISMO canal, icono y estilo que los recordatorios de
  /// repaso (ver NotificationService.scheduleUpdateReminder).
  static Future<void> scheduleUpdateReminder(
      UpdateInfo info, DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final scheduledVersion = prefs.getString(kUpdateReminderVersionKey);
    final scheduledAtMs = prefs.getInt(kUpdateReminderAtKey);
    final scheduledAt = scheduledAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(scheduledAtMs);
    if (!shouldScheduleReminder(
      latest: info.latest,
      scheduledVersion: scheduledVersion,
      scheduledAt: scheduledAt,
      now: now,
    )) {
      return;
    }
    final at = now.add(const Duration(days: 1));
    // Se guarda la info pendiente: al tocar el recordatorio el
    // diálogo sale con estos datos aunque no haya internet.
    await prefs.setString(kUpdatePendingKey, jsonEncode(info.toJson()));
    await prefs.setString(kUpdateReminderVersionKey, info.latest);
    await prefs.setInt(kUpdateReminderAtKey, at.millisecondsSinceEpoch);
    await NotificationService.cancelUpdateReminder();
    final t = updateTexts(AppLang.code);
    await NotificationService.scheduleUpdateReminder(
      body: t['reminderBody']!,
      at: at,
    );
  }

  /// Limpia el recordatorio y el APK viejo cuando ya estamos al día.
  /// También quita la entrada de actualización de la bandeja de
  /// Notificaciones (fix4, punto 8): ya no hay nada pendiente.
  static Future<void> _cleanupAfterUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kUpdateDismissedKey);
    await NotificationInbox.removeByKind(InboxKind.update);
    await prefs.remove(kUpdatePendingKey);
    await prefs.remove(kUpdateReminderVersionKey);
    await prefs.remove(kUpdateReminderAtKey);
    await NotificationService.cancelUpdateReminder();
    final path = prefs.getString(kUpdateApkPathKey);
    final version = prefs.getString(kUpdateApkVersionKey);
    if (path != null &&
        version != null &&
        compareVersions(version, kAppVersion) < 0) {
      try {
        // Síncrono (ver _downloadedApkFile): borrar un archivo local
        // es inmediato, y la versión asíncrona se cuelga en los
        // testWidgets cuando la limpieza corre tras una comprobación.
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {
        // Borrar el APK viejo es opcional.
      }
      await prefs.remove(kUpdateApkPathKey);
      await prefs.remove(kUpdateApkVersionKey);
    }
  }

  /// APK ya descargado de una versión, si existe y no está vacío.
  /// Comprobación SÍNCRONA (existsSync/lengthSync) a propósito: es
  /// un stat local de microsegundos, y la versión asíncrona se
  /// quedaría colgada en los testWidgets (la zona FakeAsync no
  /// entrega la E/S de dart:io sin runAsync) justo cuando el diálogo
  /// quiere saber si el botón es "Instalar" o "Actualizar ahora".
  static Future<File?> _downloadedApkFile(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(kUpdateApkPathKey);
      final storedVersion = prefs.getString(kUpdateApkVersionKey);
      if (path == null || storedVersion != version) return null;
      final file = File(path);
      if (!file.existsSync()) return null;
      if (file.lengthSync() == 0) return null;
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Descarga el APK en SEGUNDO PLANO: el diálogo ya se cerró y lo
  /// que el usuario ve es la notificación con la barra de progreso.
  /// Al terminar, la notificación ofrece "Instalar" y salta el
  /// instalador del sistema. Si la descarga falla, avisa con una
  /// notificación (la comprobación silenciosa es solo para la
  /// comprobación al abrir: aquí el usuario pidió actualizar).
  /// [fetcher]/[directory] solo existen para los tests; en la app se
  /// usan HttpClient y el almacenamiento externo propio.
  static Future<void> startDownload(
    BuildContext context,
    UpdateInfo info, {
    ApkStreamFetcher? fetcher,
    Directory? directory,
    UpdateDownloader? downloader,
  }) async {
    final t = updateTexts(AppLang.code);
    Directory? dir = directory;
    dir ??= await _downloadDir();
    if (dir == null) return;
    final dl = downloader ?? UpdateCheckService.downloader;
    final throttle = UpdateProgressThrottle();
    final versionBody = t['downloadingBody']!.replaceAll('{v}', info.latest);

    /// Muestra la notificación de progreso si el regulador dice que
    /// toca (ver [UpdateProgressThrottle]): la primera vez siempre,
    /// luego solo si el porcentaje cambió y pasaron 500 ms.
    Future<void> postProgress(int received, int total) async {
      if (!throttle.shouldShow(
        received: received,
        total: total,
        now: DateTime.now(),
      )) {
        return;
      }
      final pct = UpdateProgressThrottle.percentFor(received, total);
      await NotificationService.showUpdateProgress(
        title: t['downloadingTitle']!,
        body: pct < 0 ? versionBody : '$versionBody · $pct%',
        progress: pct < 0 ? 0 : pct,
        indeterminate: pct < 0,
      );
    }

    // Zona C (2026-11-12): la notificación se publica AHORA, antes
    // de conectar siquiera (total aún desconocido → barra
    // indeterminada al 0 %). Antes no se publicaba nada hasta que
    // llegaba el primer trozo con total conocido: con la redirección
    // de GitHub o un Content-Length ausente, el usuario no veía
    // ninguna barra aunque la descarga estuviera en marcha. Se
    // espera a que se publique para que el `download()` de abajo no
    // empiece sin que haya nada visible.
    await postProgress(0, -1);
    final file = await dl.download(
      info: info,
      dir: dir,
      fetcher: fetcher,
      onProgress: (received, total) {
        unawaited(postProgress(received, total));
      },
    );
    if (file == null) {
      await NotificationService.cancelUpdateProgress();
      await NotificationService.showUpdateFailed(
        title: t['downloadFailedTitle']!,
        body: t['downloadFailedBody']!,
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUpdateApkPathKey, file.path);
    await prefs.setString(kUpdateApkVersionKey, info.latest);
    await NotificationService.showUpdateReady(
      title: t['downloadReadyTitle']!,
      body: t['downloadReadyBody']!.replaceAll('{v}', info.latest),
      installLabel: t['install']!,
    );
    // Descarga completa: pide instalar (el instalador del sistema).
    await installDownloadedApk(context);
  }

  /// Carpeta donde vive el APK descargado: el almacenamiento externo
  /// propio de la app (no pide permiso de archivos y el FileProvider
  /// lo puede compartir con el instalador).
  static Future<Directory?> _downloadDir() async {
    try {
      return await getExternalStorageDirectory();
    } catch (_) {
      return null;
    }
  }

  /// Instala el APK ya descargado. Si el teléfono no tiene activado
  /// "Instalar apps desconocidas" para Melli-Qui, muestra el aviso
  /// claro con el botón para ir a Ajustes (si la app no está en
  /// primer plano, el aviso sale al tocar la notificación, que vuelve
  /// a llamar aquí con contexto).
  static Future<void> installDownloadedApk(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(kUpdateApkPathKey);
    if (path == null) return;
    final file = File(path);
    // existsSync (ver _downloadedApkFile): un stat local, y la
    // versión asíncrona se cuelga en los testWidgets.
    if (!file.existsSync()) return;
    final canInstall = await UpdateInstaller.canInstallUnknownSources();
    if (!canInstall) {
      if (!context.mounted) return;
      await _showUnknownSourcesDialog(context);
      return;
    }
    // El instalador del sistema se abre: la app pasa a "installing"
    // (la instalación en sí la hace el sistema, fuera de la app).
    UpdateCheckService.downloader.state.value = UpdateDownloadState.installing;
    final installed = await UpdateInstaller.installApk(path);
    if (!installed) {
      UpdateCheckService.downloader.state.value =
          UpdateDownloadState.downloaded;
    }
  }

  /// Aviso cuando falta el permiso de "Instalar apps desconocidas":
  /// texto claro y botón para ir a Ajustes.
  static Future<void> _showUnknownSourcesDialog(BuildContext context) async {
    final t = updateTexts(AppLang.code);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t['unknownSourcesTitle']!),
        content: Text(t['unknownSourcesBody']!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t['notNow']!),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await UpdateInstaller.openUnknownSourcesSettings();
            },
            child: Text(t['goToSettings']!),
          ),
        ],
      ),
    );
  }
}
