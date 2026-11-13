// Catálogo REMOTO de la tienda (Quemia 7.3): colección
// 'shop_items' en Firestore. La app ya no depende del catálogo
// fijo: lo lee de Firestore, guarda la última copia buena en
// caché local (SharedPreferences, JSON) y la usa sin internet; si
// no hay caché, usa `kShopCatalog` (respaldo offline).
//
// Como el resto de la app: sin internet NO se muestra diálogo de
// error y este servicio NUNCA lanza — devuelve el respaldo. La
// lectura remota tiene timeout de 5 s (en Cuba, con VPN, una
// lectura colgada no puede dejar la tienda en blanco).
//
// Las fotos remotas de los avatares nuevos (`imageUrl`) se
// descargan con dart:io HttpClient y quedan en caché en disco
// (ShopImageCache, sin dependencias nuevas): sin internet se
// muestra la foto cacheada, y si nunca se descargó, una cara por
// defecto — nunca un cuadro roto ni una tarjeta sin imagen.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shop_item.dart';

/// Cómo se leen los documentos: se inyecta en tests para simular
/// Firestore sin backend (o un Firestore que falla).
typedef ShopCatalogFetcher = Future<List<Map<String, dynamic>>> Function();

class RemoteShopCatalog {
  RemoteShopCatalog._();

  static final RemoteShopCatalog instance = RemoteShopCatalog._();

  /// Timeout de la lectura remota (como el resto de la app: si no
  /// responde en 5 s, se usa la caché sin avisar).
  static const Duration fetchTimeout = Duration(seconds: 5);

  /// Tiempo que vale el catálogo en memoria sin volver a preguntar
  /// a Firestore (abrir la tienda dos veces seguidas no pega dos
  /// veces a la red).
  static const Duration _memoryTtl = Duration(minutes: 5);

  static const String _cacheKey = 'remote_shop_catalog_v1';

  ShopCatalogFetcher? _fetcherOverride;
  List<ShopItem>? _lastLoaded;
  DateTime? _lastFetchAt;

  /// Último catálogo bueno en memoria (síncrono, para los getters
  /// de SocialService como `equippedThemeColor`): vacío si aún no
  /// se cargó nada en esta sesión.
  static List<ShopItem> get lastLoaded =>
      List<ShopItem>.unmodifiable(instance._lastLoaded ?? const <ShopItem>[]);

  /// Inyecta el lector de documentos (solo tests/previews).
  void setFetcherForTests(ShopCatalogFetcher? fetcher) {
    _fetcherOverride = fetcher;
    _lastLoaded = null;
    _lastFetchAt = null;
  }

  void resetForTests() {
    _fetcherOverride = null;
    _lastLoaded = null;
    _lastFetchAt = null;
  }

  /// El catálogo: remoto si hay internet, caché local si no, y
  /// `kShopCatalog` si no hay ni caché. Nunca lanza.
  Future<List<ShopItem>> loadCatalog({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _lastLoaded != null &&
        _lastFetchAt != null &&
        DateTime.now().difference(_lastFetchAt!) < _memoryTtl) {
      return List<ShopItem>.unmodifiable(_lastLoaded!);
    }
    try {
      final raw = await _fetch().timeout(fetchTimeout);
      final items = _parse(raw);
      if (items.isEmpty) throw StateError('catálogo remoto vacío');
      _lastLoaded = items;
      _lastFetchAt = DateTime.now();
      await _saveCache(items);
      return List<ShopItem>.unmodifiable(items);
    } catch (_) {
      // Fallo silencioso: caché local, y si no hay, el respaldo.
      final cached = await _loadCache();
      if (cached.isNotEmpty) {
        _lastLoaded = cached;
        _lastFetchAt = DateTime.now();
        return List<ShopItem>.unmodifiable(cached);
      }
      return List<ShopItem>.unmodifiable(kShopCatalog);
    }
  }

  /// Vuelve a preguntar a Firestore aunque el catálogo en memoria
  /// siga vigente (tirar para actualizar, o tras publicar un
  /// artículo nuevo).
  Future<List<ShopItem>> refreshCatalog() =>
      loadCatalog(forceRefresh: true);

  /// Parsea y ordena; descarta documentos rotos e inactivos
  /// (`active == false` = oculto sin borrar el documento).
  List<ShopItem> _parse(List<Map<String, dynamic>> raw) {
    final out = <ShopItem>[];
    for (final doc in raw) {
      final item = ShopItem.fromMap(doc, doc['id']?.toString());
      if (item == null || !item.active) continue;
      out.add(item);
    }
    out.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return out;
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final fetcher = _fetcherOverride ?? _firestoreFetch;
    return fetcher();
  }

  /// Lectura real: solo ordena por `sortOrder` (sin `where` +
  /// `orderBy` combinados, que exigirían un índice compuesto en
  /// Firestore); los inactivos se filtran en `_parse`.
  static Future<List<Map<String, dynamic>>> _firestoreFetch() async {
    final snap = await FirebaseFirestore.instance
        .collection('shop_items')
        .orderBy('sortOrder')
        .get();
    return snap.docs
        .map((d) => <String, dynamic>{...d.data(), 'id': d.id})
        .toList();
  }

  Future<void> _saveCache(List<ShopItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cacheKey, jsonEncode(items.map((i) => i.toMap()).toList()));
    } catch (_) {}
  }

  Future<List<ShopItem>> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return <ShopItem>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ShopItem>[];
      final out = <ShopItem>[];
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final item = ShopItem.fromMap(entry, entry['id']?.toString());
          if (item != null && item.active) out.add(item);
        } else if (entry is Map) {
          final map = Map<String, dynamic>.from(entry);
          final item = ShopItem.fromMap(map, map['id']?.toString());
          if (item != null && item.active) out.add(item);
        }
      }
      out.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return out;
    } catch (_) {
      return <ShopItem>[];
    }
  }
}

/// Caché en disco de las fotos remotas de la tienda (`imageUrl`).
/// Sin dependencias nuevas: dart:io HttpClient + path_provider.
/// El nombre del archivo es un hash estable (FNV-1a) de la URL:
/// la misma URL siempre cae en el mismo archivo, y dos URLs
/// distintas no se pisan. Nunca lanza: null = sin internet, error
/// de red o disco no disponible.
class ShopImageCache {
  ShopImageCache._();

  static String fileNameFor(String url) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(url)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'shop_${hash.toRadixString(16)}${_extension(url)}';
  }

  static String _extension(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    if (dot < 0) return '.jpg';
    final ext = path.substring(dot).toLowerCase();
    return const ['.jpg', '.jpeg', '.png', '.webp'].contains(ext)
        ? ext
        : '.jpg';
  }

  static Future<Directory?> _dir() async {
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}/shop_images');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {
      return null;
    }
  }

  /// La foto ya descargada, o null si nunca se bajó.
  static Future<File?> cachedFile(String url) async {
    try {
      final dir = await _dir();
      if (dir == null) return null;
      final file = File('${dir.path}/${fileNameFor(url)}');
      return await file.exists() ? file : null;
    } catch (_) {
      return null;
    }
  }

  /// La foto cacheada si la hay; si no, la descarga (timeout 5 s
  /// de conexión, 10 s de descarga) y la guarda. Null si no se
  /// pudo (sin internet o error): quien llama muestra el
  /// placeholder con cara.
  static Future<File?> ensureCached(String url) async {
    final existing = await cachedFile(url);
    if (existing != null) return existing;
    try {
      final dir = await _dir();
      if (dir == null) return null;
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response =
            await request.close().timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) return null;
        final file = File('${dir.path}/${fileNameFor(url)}');
        final sink = file.openWrite();
        await sink.addStream(response);
        await sink.close();
        return file;
      } finally {
        client.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// Gancho para tests/previews: siembra bytes en la caché como si
  /// ya se hubieran descargado.
  static Future<File?> seedForTests(String url, List<int> bytes) async {
    try {
      final dir = await _dir();
      if (dir == null) return null;
      final file = File('${dir.path}/${fileNameFor(url)}');
      await file.writeAsBytes(bytes);
      return file;
    } catch (_) {
      return null;
    }
  }
}
