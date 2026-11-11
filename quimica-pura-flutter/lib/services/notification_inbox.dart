// Bandeja de Notificaciones (fix4, punto 8): centro de notificaciones
// dentro de la app (como Facebook). Las entradas se guardan en el
// teléfono (SharedPreferences, máximo 30, las más nuevas primero)
// con leído/no leído; la campana de la barra superior lleva el
// numerito de no leídos.
//
// Qué genera entradas:
//   (a) actualización disponible: al tocar "Más tarde" (o descartar
//       el diálogo) en UpdateCheckService._onLaterPressed, con la
//       versión y las notas; al actualizar, la entrada desaparece
//       (removeByKind en _cleanupAfterUpdate).
//   (b) cada recordatorio de estudio que se dispara: lo registra
//       NotificationService.reconcileFiredReminders (las horas
//       pasadas de la lista de programadas).
//   (c) logro desbloqueado y aviso de racha en peligro: los genera
//       syncDaily, una vez al abrir la app (la primera vez solo
//       anota los logros que ya había, sin avisar de los viejos).
//
// Un solo ValueNotifier con la lista: la campana y la pantalla
// escuchan lo mismo; el numerito de no leídos se calcula de la lista.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'achievements.dart';
import 'localization.dart';
import 'progress.dart';

enum InboxKind { update, reminder, achievement, streak }

class InboxEntry {
  const InboxEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.data = const {},
  });

  final String id;
  final InboxKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  /// Datos extra para abrir lo que toca al tocar la entrada: en una
  /// de actualización, el UpdateInfo serializado.
  final Map<String, dynamic> data;

  InboxEntry copyWith({bool? read}) => InboxEntry(
        id: id,
        kind: kind,
        title: title,
        body: body,
        createdAt: createdAt,
        read: read ?? this.read,
        data: data,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'body': body,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'read': read,
        'data': data,
      };

  static InboxEntry? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final kindName = json['kind'];
    final title = json['title'];
    final body = json['body'];
    final createdAtMs = json['createdAt'];
    if (id is! String ||
        kindName is! String ||
        title is! String ||
        body is! String ||
        createdAtMs is! int) {
      return null;
    }
    InboxKind? kind;
    for (final k in InboxKind.values) {
      if (k.name == kindName) kind = k;
    }
    if (kind == null) return null;
    final data = json['data'];
    return InboxEntry(
      id: id,
      kind: kind,
      title: title,
      body: body,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      read: json['read'] == true,
      data: data is Map<String, dynamic> ? data : const {},
    );
  }
}

class NotificationInbox {
  NotificationInbox._();

  static const _entriesKey = 'melli_inbox_v1';
  static const _seenAchievementsKey = 'melli_inbox_seen_achievements';

  /// Máximo de entradas guardadas: las 30 últimas.
  static const int maxEntries = 30;

  /// La lista actual (la más nueva primero). La campana y la
  /// pantalla de Notificaciones escuchan este notifier.
  static final ValueNotifier<List<InboxEntry>> entriesNotifier =
      ValueNotifier<List<InboxEntry>>([]);

  /// ¿Ya se cargó la lista guardada? Las mutaciones cargan primero
  /// si hace falta: así da igual en qué orden arranquen los
  /// servicios al abrir la app (p. ej. NotificationService.init
  /// reconcilia antes de que main() llame a load()).
  static bool _loaded = false;

  @visibleForTesting
  static void resetForTests() {
    entriesNotifier.value = const [];
    _loaded = false;
  }

  static Future<void> _ensureLoaded() async {
    if (!_loaded) await load();
  }

  static List<InboxEntry> get entries => entriesNotifier.value;

  static int get unreadCount =>
      entriesNotifier.value.where((e) => !e.read).length;

  static Future<void> load() async {
    var list = <InboxEntry>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_entriesKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          list = decoded
              .whereType<Map<String, dynamic>>()
              .map(InboxEntry.fromJson)
              .whereType<InboxEntry>()
              .toList();
        }
      }
    } catch (_) {
      list = <InboxEntry>[];
    }
    // De más nueva a más vieja, como mucho 30.
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (list.length > maxEntries) list = list.sublist(0, maxEntries);
    entriesNotifier.value = list;
    _loaded = true;
  }

  static Future<void> _save(List<InboxEntry> list) async {
    final trimmed =
        list.length > maxEntries ? list.sublist(0, maxEntries) : list;
    entriesNotifier.value = List<InboxEntry>.unmodifiable(trimmed);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _entriesKey, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
    } catch (_) {
      // Guardar la bandeja es opcional: la lista en memoria sigue.
    }
  }

  /// Añade una entrada arriba del todo (sin leer). Si ya existía
  /// una con el mismo id, se sustituye y vuelve a marcarse sin
  /// leer (p. ej. una actualización que vuelve a posponerse, o la
  /// racha de hoy que se vuelve a generar al abrir).
  static Future<void> add({
    required String id,
    required InboxKind kind,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
    // Solo para tests/previews: una fecha fija hace la captura
    // determinista (si no, la hora "hoy, HH:MM" cambia cada minuto
    // y el golden falla en la suite completa).
    DateTime? createdAt,
  }) async {
    await _ensureLoaded();
    final list = List<InboxEntry>.of(entriesNotifier.value)
      ..removeWhere((e) => e.id == id);
    list.insert(
      0,
      InboxEntry(
        id: id,
        kind: kind,
        title: title,
        body: body,
        createdAt: createdAt ?? DateTime.now(),
        data: data,
      ),
    );
    await _save(list);
  }

  static Future<void> markRead(String id) async {
    await _ensureLoaded();
    final list = entriesNotifier.value
        .map((e) => e.id == id ? e.copyWith(read: true) : e)
        .toList();
    await _save(list);
  }

  static Future<void> markAllRead() async {
    await _ensureLoaded();
    final list =
        entriesNotifier.value.map((e) => e.copyWith(read: true)).toList();
    await _save(list);
  }

  static Future<void> removeByKind(InboxKind kind) async {
    await _ensureLoaded();
    final list =
        entriesNotifier.value.where((e) => e.kind != kind).toList();
    await _save(list);
  }

  /// Logros desbloqueados y aviso de racha (fix4, punto 8): se
  /// llama una vez al abrir la app. [trackTopics] son los temas de
  /// la pista actual (los necesita el logro de tema completado).
  ///
  /// - Logros: se compara el conjunto desbloqueado ahora con el que
  ///   se vio la última vez. La PRIMERA vez solo se anota el
  ///   conjunto (sin avisar de los logros viejos). Cada logro nuevo
  ///   genera una entrada con su título y su cuerpo.
  /// - Racha: si hay racha (streakNow > 0) y hoy aún no se ha
  ///   practicado, una entrada al día ("Tu racha se pierde si no
  ///   practicas hoy"): el id lleva la fecha, así que no se duplica.
  static Future<void> syncDaily(List<String> trackTopics) async {
    try {
      await _ensureLoaded();
      final prefs = await SharedPreferences.getInstance();
      final p = ProgressService.instance;

      // Logros.
      final unlocked = <String>{
        for (final a in allAchievements)
          if (achievementUnlocked(a.id, p, trackTopics)) a.id,
      };
      final seenRaw = prefs.getStringList(_seenAchievementsKey);
      if (seenRaw == null) {
        // Primera vez: se anota lo que ya hay, sin avisar.
        await prefs.setStringList(_seenAchievementsKey, unlocked.toList());
      } else {
        final seen = seenRaw.toSet();
        final fresh = unlocked.difference(seen);
        if (fresh.isNotEmpty) {
          await prefs.setStringList(
              _seenAchievementsKey, unlocked.toList());
          for (final id in fresh) {
            final a =
                allAchievements.firstWhere((x) => x.id == id);
            await add(
              id: 'achievement-$id',
              kind: InboxKind.achievement,
              title: a.title,
              body: a.body,
            );
          }
        }
      }

      // Racha en peligro.
      final today = ProgressService.dateKey(DateTime.now());
      if (p.streakNow > 0 && !p.practiceDays.contains(today)) {
        await add(
          id: 'streak-$today',
          kind: InboxKind.streak,
          title: tr('inboxStreakTitle'),
          body: tr('inboxStreakBody').replaceFirst('{n}', '${p.streakNow}'),
        );
      }
    } catch (_) {
      // La bandeja es opcional: si algo falla, la app sigue.
    }
  }
}
