// Un artículo de la tienda: solo cosmético, nada de pagar para ganar.
//
// El catálogo VIVE EN FIRESTORE (colección 'shop_items', Quemia
// 7.3): la app lo lee con RemoteShopCatalog y lo guarda en caché
// local; `kShopCatalog` es SOLO el respaldo offline (los 9
// artículos de la 7.0) cuando no hay internet ni caché. Cada
// documento lleva los mismos campos que este modelo (ver
// `toMap()`); `fromMap` es tolerante a campos ausentes o con mal
// tipo, porque un documento editado a mano en la consola no debe
// romper la tienda.

/// Un artículo de la tienda: solo cosmético, nada de pagar para ganar.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.price,
    this.color,
    this.badgeIcon,
    this.asset,
    this.imageUrl,
    this.description = '',
    this.active = true,
    this.sortOrder = 0,
    this.referralOnly = false,
  });

  final String id;
  final String name;

  /// 'theme' | 'avatar' | 'badge' | 'frame'.
  final String kind;
  final int price;

  /// Color ARGB (temas: color del acento; marcos: color del
  /// anillo; insignias: color del disco; avatares: color del
  /// botón Comprar).
  final int? color;

  /// Insignias: 'star' | 'trophy' | 'flame' | 'dna' | 'atom' |
  /// 'rocket'. Marcos: 'rainbow' = anillo arcoíris (sin color
  /// único); cualquier otro valor o null = anillo sólido del
  /// color del artículo.
  final String? badgeIcon;

  /// Avatares: ruta del asset de la foto ('assets/avatar_*.png').
  final String? asset;

  /// Avatares nuevos: URL remota de la foto (Firebase Storage o
  /// similar). Si hay `asset` manda el asset; si no, la foto se
  /// descarga y se guarda en caché en disco (ShopImageCache).
  final String? imageUrl;

  /// Frase graciosa del artículo (se muestra en su tarjeta).
  final String description;

  /// false = oculto en la tienda (no se borra el documento).
  final bool active;

  /// Orden dentro de la tienda (menor primero).
  final int sortOrder;

  /// true = recompensa de referidos: NO se vende en la tienda
  /// (la Tienda lo esconde), solo se consigue invitando amigos
  /// (SocialService.grantItem). El precio no se mira.
  final bool referralOnly;

  static int _asInt(Object? value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static String? _asOptString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// Parsea un documento de 'shop_items'. [docId] es el id del
  /// documento (manda sobre el campo 'id' si viene). Devuelve
  /// null si el documento no sirve (sin id, sin nombre o sin
  /// tipo): un documento roto no debe tumbar el catálogo entero.
  /// Tolerante: precio con texto ('150' → 150, 'abc' → 0),
  /// `active` no booleano → true, campos ausentes → valores por
  /// defecto.
  static ShopItem? fromMap(Map<String, dynamic> raw, [String? docId]) {
    final id = (docId ?? raw['id']?.toString() ?? '').trim();
    if (id.isEmpty) return null;
    final name = (raw['name']?.toString() ?? '').trim();
    if (name.isEmpty) return null;
    final kind = (raw['kind']?.toString() ?? '').trim();
    if (kind.isEmpty) return null;
    final colorRaw = raw['color'];
    final int? color = colorRaw is num
        ? colorRaw.toInt()
        : (colorRaw is String ? int.tryParse(colorRaw.trim()) : null);
    return ShopItem(
      id: id,
      name: name,
      kind: kind,
      price: _asInt(raw['price']),
      color: color,
      badgeIcon: _asOptString(raw['badgeIcon']),
      asset: _asOptString(raw['asset']),
      imageUrl: _asOptString(raw['imageUrl']),
      description: raw['description']?.toString() ?? '',
      active: raw['active'] is bool ? raw['active'] as bool : true,
      sortOrder: _asInt(raw['sortOrder']),
      referralOnly: raw['referralOnly'] == true,
    );
  }

  /// El documento tal como se publica en Firestore (el id del doc
  /// es [id]; el campo 'id' se guarda también dentro, para que el
  /// documento sea legible solo).
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'kind': kind,
        'price': price,
        if (color != null) 'color': color,
        if (badgeIcon != null) 'badgeIcon': badgeIcon,
        if (asset != null) 'asset': asset,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'description': description,
        'active': active,
        'sortOrder': sortOrder,
        if (referralOnly) 'referralOnly': true,
      };

  @override
  bool operator ==(Object other) =>
      other is ShopItem &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.price == price &&
      other.color == color &&
      other.badgeIcon == badgeIcon &&
      other.asset == asset &&
      other.imageUrl == imageUrl &&
      other.description == description &&
      other.active == active &&
      other.sortOrder == sortOrder &&
      other.referralOnly == referralOnly;

  @override
  int get hashCode => Object.hash(id, name, kind, price, color, badgeIcon,
      asset, imageUrl, description, active, sortOrder, referralOnly);
}

/// Catálogo fijo de la tienda (7.0): RESPALDO OFFLINE. Los 9
/// artículos de siempre; el catálogo real vive en Firestore
/// ('shop_items') y este solo se usa sin internet y sin caché.
/// Los `sortOrder` siguen el orden de la pantalla (temas,
/// avatares, insignias).
const List<ShopItem> kShopCatalog = [
  ShopItem(
      id: 'theme_coral',
      name: 'Coral',
      kind: 'theme',
      price: 300,
      color: 0xFFF97316,
      description: 'El color del atardecer en la playa. Te queda bien.',
      sortOrder: 1),
  ShopItem(
      id: 'theme_rosa',
      name: 'Rosa',
      kind: 'theme',
      price: 300,
      color: 0xFFEC4899,
      description: 'Rosa como las flores de primavera.',
      sortOrder: 2),
  ShopItem(
      id: 'theme_azul',
      name: 'Azul',
      kind: 'theme',
      price: 300,
      color: 0xFF3B82F6,
      description: 'Azul como el mar en calma.',
      sortOrder: 3),
  ShopItem(
      id: 'avatar_dorado',
      name: 'Avatar dorado',
      kind: 'avatar',
      price: 200,
      color: 0xFFFFD700,
      asset: 'assets/avatar_dorado.png',
      description:
          'El rey de la química. Solo para los que llegan a 200 puntos.',
      sortOrder: 4),
  ShopItem(
      id: 'avatar_violeta',
      name: 'Avatar violeta',
      kind: 'avatar',
      price: 150,
      color: 0xFF8B5CF6,
      asset: 'assets/avatar_violeta.png',
      description:
          'Violeta como Brenda. Para que te vean desde la última fila.',
      sortOrder: 5),
  ShopItem(
      id: 'avatar_teal',
      name: 'Avatar teal',
      kind: 'avatar',
      price: 100,
      color: 0xFF00C2A8,
      asset: 'assets/avatar_teal.png',
      description: 'Teal como la app. Discreto por fuera, crack por dentro.',
      sortOrder: 6),
  ShopItem(
      id: 'badge_star',
      name: 'Estrella',
      kind: 'badge',
      price: 150,
      color: 0xFFFFC800,
      badgeIcon: 'star',
      description: 'Brilla como tú cuando aciertas.',
      sortOrder: 7),
  ShopItem(
      id: 'badge_trophy',
      name: 'Trofeo',
      kind: 'badge',
      price: 250,
      color: 0xFFFFC800,
      badgeIcon: 'trophy',
      description: 'Para los que llegan a lo más alto.',
      sortOrder: 8),
  ShopItem(
      id: 'badge_flame',
      name: 'Llama de racha',
      kind: 'badge',
      price: 200,
      color: 0xFFFFC800,
      badgeIcon: 'flame',
      description: 'Tu racha, en llamas.',
      sortOrder: 9),
];
