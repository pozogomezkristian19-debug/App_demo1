// Tienda: sincronización de compras cosméticas (7.0). La compra
// en sí la hace la UI (SocialService.buyItem: descuenta los puntos
// y guarda en local); ESTE servicio sincroniza la lista de compras
// con el documento del usuario ('users/<uid>', campo 'purchases')
// para que la compra sobreviva a un cambio de teléfono (se
// restaura con restoreFromCloud) y el admin la vea.
//
// Lo EQUIPADO también se sincroniza (syncEquipped): tema, avatar
// e insignia se escriben en el mismo documento (campos
// 'equippedTheme', 'equippedAvatar', 'equippedBadge'; cadena vacía
// = quitado) para que sobrevivan a un cambio de teléfono y los
// amigos vean lo que llevas puesto. La lectura de vuelta
// (cloudEquipped) está lista para el respaldo: falta enchufarla al
// restaurar en un teléfono nuevo (restoreFromCloud).
//
// Reglas: sin Google vinculada no hay tienda (puerta de
// identidad); sin internet la compra local NO se pierde: queda
// pendiente y se reintenta sola (retryPendingPurchases). La compra
// local siempre manda: la sincronización nunca borra compras.
import 'analytics_sync.dart';
import 'auth_service.dart';
import 'online_common.dart';

class ShopService {
  ShopService._();

  /// Compras pendientes de sincronizar (solo lectura local).
  static const String _pendingKey = 'melli_online_pending_purchases';

  /// Lo equipado pendiente de sincronizar (un estado, no una
  /// lista: solo importa el último valor de cada tipo).
  static const String _pendingKeyEquipped =
      'melli_online_pending_equipped';

  static AnalyticsRepository get _repo => AnalyticsSync.repository;
  static String get _me => AuthService.currentUid ?? '';

  /// Sincroniza UNA compra con el documento del usuario (se llama
  /// tras comprar en local). Devuelve true si quedó en la nube;
  /// false si quedó pendiente (sin internet) o sin Google.
  /// La lista 'purchases' se fusiona con arrayUnion: no pisa las
  /// compras de otro teléfono con la misma cuenta.
  static Future<bool> syncPurchase(String itemId) async {
    if (itemId.isEmpty) return false;
    if (!OnlineCommon.allowed || _me.isEmpty) return false;
    final ok = await OnlineCommon.write(
        () => _repo.addToArray('users', _me, 'purchases', itemId));
    if (!ok) {
      await OnlineCommon.enqueue(_pendingKey, <String, dynamic>{
        'itemId': itemId,
      });
      return false;
    }
    return true;
  }

  /// Sincroniza TODA la lista local de compras (p. ej. al abrir la
  /// app: por si una compra quedó pendiente en otro teléfono).
  /// [ownedItemIds] viene de SocialService (la UI). Devuelve true
  /// si quedó sincronizada.
  static Future<bool> syncAllPurchases(List<String> ownedItemIds) async {
    if (!OnlineCommon.allowed || _me.isEmpty) return false;
    var ok = true;
    for (final id in ownedItemIds) {
      final one = await OnlineCommon.write(
          () => _repo.addToArray('users', _me, 'purchases', id));
      if (!one) {
        await OnlineCommon.enqueue(_pendingKey, <String, dynamic>{
          'itemId': id,
        });
        ok = false;
      }
    }
    return ok;
  }

  /// Sincroniza LO EQUIPADO (tema, avatar o insignia) con el
  /// documento del usuario. [itemId] null = se quitó (se escribe
  /// cadena vacía; la lectura lo trata como "sin equipar").
  /// Devuelve true si quedó en la nube; false si quedó pendiente
  /// (sin internet) o sin Google. Sin internet lo local NO se
  /// pierde: queda pendiente y se reintenta solo.
  static Future<bool> syncEquipped(String kind, String? itemId) async {
    final field = switch (kind) {
      'theme' => 'equippedTheme',
      'avatar' => 'equippedAvatar',
      'badge' => 'equippedBadge',
      _ => '',
    };
    if (field.isEmpty) return false;
    if (!OnlineCommon.allowed || _me.isEmpty) return false;
    final value = (itemId ?? '').trim();
    final ok = await OnlineCommon.write(
        () => _repo.setDoc('users', _me, <String, dynamic>{field: value}));
    if (!ok) {
      await OnlineCommon.enqueue(_pendingKeyEquipped, <String, dynamic>{
        'kind': kind,
        'itemId': value,
      });
      return false;
    }
    return true;
  }

  /// Lee lo equipado que quedó en la nube (para restaurar en un
  /// teléfono nuevo): kind → itemId; sin valor = no equipado.
  /// Vacío sin Google o sin internet.
  static Future<Map<String, String>> cloudEquipped() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return {};
    final doc =
        await OnlineCommon.call(() => _repo.getDoc('users', _me));
    if (doc == null) return {};
    final out = <String, String>{};
    for (final entry in {
      'theme': 'equippedTheme',
      'avatar': 'equippedAvatar',
      'badge': 'equippedBadge',
    }.entries) {
      final value = doc[entry.value]?.toString().trim() ?? '';
      if (value.isNotEmpty) out[entry.key] = value;
    }
    return out;
  }

  /// Reintenta lo equipado que quedó pendiente sin internet. Lo
  /// equipado es un estado: solo importa el último valor, así que
  /// si se sincroniza se limpian todos los pendientes.
  static Future<int> retryPendingEquipped() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return 0;
    final items = await OnlineCommon.pending(_pendingKeyEquipped);
    if (items.isEmpty) return 0;
    final last = items.last;
    final kind = last['kind']?.toString() ?? '';
    final itemId = last['itemId']?.toString() ?? '';
    final ok = await syncEquipped(kind, itemId.isEmpty ? null : itemId);
    if (!ok) return 0;
    for (var i = items.length - 1; i >= 0; i--) {
      await OnlineCommon.removeAt(_pendingKeyEquipped, i);
    }
    return 1;
  }

  static Future<int> pendingEquippedCount() =>
      OnlineCommon.pendingCount(_pendingKeyEquipped);

  /// Lee las compras sincronizadas del documento del usuario
  /// (para restaurarlas en un teléfono nuevo, junto con
  /// restoreFromCloud). Vacío sin Google o sin internet.
  static Future<List<String>> cloudPurchases() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return [];
    final doc =
        await OnlineCommon.call(() => _repo.getDoc('users', _me));
    final out = <String>[];
    final raw = doc?['purchases'];
    if (raw is List) {
      for (final v in raw) {
        if (v is String && v.isNotEmpty) out.add(v);
      }
    }
    return out;
  }

  /// Reintenta las compras que quedaron pendientes sin internet.
  static Future<int> retryPendingPurchases() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return 0;
    final items = await OnlineCommon.pending(_pendingKey);
    var done = 0;
    for (var i = items.length - 1; i >= 0; i--) {
      final item = items[i];
      final itemId = item['itemId']?.toString() ?? '';
      if (itemId.isEmpty) {
        await OnlineCommon.removeAt(_pendingKey, i);
        continue;
      }
      final ok = await OnlineCommon.write(
          () => _repo.addToArray('users', _me, 'purchases', itemId));
      if (ok) {
        await OnlineCommon.removeAt(_pendingKey, i);
        done++;
      }
    }
    return done;
  }

  static Future<int> pendingCount() =>
      OnlineCommon.pendingCount(_pendingKey);
}
