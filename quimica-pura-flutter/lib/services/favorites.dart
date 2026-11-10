// Favoritos: elementos, temas y fórmulas marcados con la estrellita,
// guardados en el teléfono con SharedPreferences. Sin internet.
//
// ids:
// - elemento: 'el:<número atómico>'
// - tema: 'topic:<slug>'
// - fórmula: 'formula:<nombre de la fórmula>'

import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  FavoritesService._();
  static final FavoritesService instance = FavoritesService._();

  static const _kFav = 'melli_favorites_v5';

  SharedPreferences? _prefs;
  final Set<String> _ids = <String>{};

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    instance._prefs = prefs;
    instance._ids
      ..clear()
      ..addAll(prefs.getStringList(_kFav) ?? <String>[]);
  }

  void _save() {
    _prefs?.setStringList(_kFav, _ids.toList());
  }

  bool isFav(String id) => _ids.contains(id);

  void toggle(String id) {
    if (_ids.contains(id)) {
      _ids.remove(id);
    } else {
      _ids.add(id);
    }
    _save();
  }

  List<int> get favoriteElements => _ids
      .where((id) => id.startsWith('el:'))
      .map((id) => int.tryParse(id.substring(3)) ?? 0)
      .where((z) => z > 0)
      .toList();

  List<String> get favoriteTopics => _ids
      .where((id) => id.startsWith('topic:'))
      .map((id) => id.substring(6))
      .toList();

  List<String> get favoriteFormulas => _ids
      .where((id) => id.startsWith('formula:'))
      .map((id) => id.substring(8))
      .toList();

  bool get isEmpty => _ids.isEmpty;
}
