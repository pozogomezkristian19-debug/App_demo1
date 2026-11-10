// Mi cuaderno: notas propias del usuario, una por tema (y una general),
// guardadas en el teléfono con SharedPreferences. Sin internet.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NotesService {
  NotesService._();
  static final NotesService instance = NotesService._();

  static const _kNotes = 'melli_notes_v5';

  SharedPreferences? _prefs;
  final Map<String, String> _notes = <String, String>{};

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    instance._prefs = prefs;
    instance._notes
      ..clear()
      ..addAll(_read(prefs.getString(_kNotes)));
  }

  static Map<String, String> _read(String? raw) {
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String, String>{};
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }

  void _save() {
    _prefs?.setString(_kNotes, jsonEncode(_notes));
  }

  String noteFor(String topicSlug) => _notes[topicSlug] ?? '';

  bool hasNote(String topicSlug) =>
      (_notes[topicSlug] ?? '').trim().isNotEmpty;

  void saveNote(String topicSlug, String text) {
    final t = text.trim();
    if (t.isEmpty) {
      _notes.remove(topicSlug);
    } else {
      _notes[topicSlug] = t;
    }
    _save();
  }

  /// Temas con nota guardada.
  List<String> get topicsWithNotes => _notes.keys.toList();
}
