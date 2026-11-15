import 'dart:convert';

/// Parsing y orden de listas gratuitas de servidores (V2Ray / sing-box).
///
/// Dart puro: sin Flutter y sin red, totalmente comprobable con tests.
/// Acepta listas en texto plano (un enlace por línea, líneas `#` ignoradas)
/// y también un único blob base64 que decodifica a esa misma lista.

class ServerLink {
  const ServerLink({
    required this.raw,
    required this.scheme,
    required this.name,
  });

  /// Enlace completo tal como vino en la lista (`vless://…`, `trojan://…`).
  final String raw;

  /// Esquema en minúsculas: `vless`, `vmess`, `trojan`, `ss`, …
  final String scheme;

  /// Nombre del servidor (fragmento tras `#`, decodificado). Puede ser vacío.
  final String name;
}

/// Convierte el cuerpo de una suscripción en enlaces de servidor.
List<ServerLink> parseSubscription(String body) {
  var text = body.trim();
  if (text.isEmpty) return const [];
  if (!text.contains('://')) {
    final decoded = _tryBase64(text);
    if (decoded != null) text = decoded;
  }
  final links = <ServerLink>[];
  final seen = <String>{};
  for (final line in text.split('\n')) {
    final item = line.trim();
    if (item.isEmpty || item.startsWith('#')) continue;
    final candidate = item.contains('://') ? item : (_tryBase64(item) ?? item);
    if (!candidate.contains('://')) continue;
    final scheme = candidate.split('://').first.toLowerCase();
    if (seen.add(candidate)) {
      links.add(ServerLink(
        raw: candidate,
        scheme: scheme,
        name: _fragmentName(candidate),
      ));
    }
  }
  return links;
}

String? _tryBase64(String input) {
  final clean = input.replaceAll(RegExp(r'\s'), '');
  if (clean.length < 8 || !RegExp(r'^[A-Za-z0-9+/=_-]+$').hasMatch(clean)) {
    return null;
  }
  try {
    final normalized = clean.replaceAll('-', '+').replaceAll('_', '/');
    final padded = normalized + '=' * ((4 - normalized.length % 4) % 4);
    final decoded = String.fromCharCodes(base64Decode(padded));
    if (decoded.contains('://')) return decoded;
  } catch (_) {
    // No era base64 válido: se ignora.
  }
  return null;
}

String _fragmentName(String link) {
  final hash = link.indexOf('#');
  if (hash < 0 || hash == link.length - 1) return '';
  try {
    return Uri.decodeComponent(link.substring(hash + 1)).trim();
  } catch (_) {
    return link.substring(hash + 1).trim();
  }
}

/// Orden preferido para Cuba: primero los protocolos que se disfrazan
/// de HTTPS normal (VLESS-Reality, Trojan, Hysteria2), luego el resto.
int _score(ServerLink link) {
  final raw = link.raw;
  switch (link.scheme) {
    case 'vless':
      if (raw.contains('security=reality')) return 100;
      if (raw.contains('security=tls')) return 80;
      return 70;
    case 'trojan':
      return 90;
    case 'hysteria2':
      return 85;
    case 'hysteria':
      return 78;
    case 'vmess':
      return 60;
    case 'ss':
      return 50;
    case 'wireguard':
      return 40;
    default:
      return 10;
  }
}

/// Devuelve la lista ordenada de mejor a peor, sin tocar la original.
List<ServerLink> rankServers(List<ServerLink> links) {
  final sorted = List<ServerLink>.from(links);
  sorted.sort((a, b) => _score(b).compareTo(_score(a)));
  return sorted;
}

/// Países y ciudades frecuentes en los nombres de los servidores.
/// Devuelve el país en español, o `null` si el nombre no dice nada claro
/// (nombres raros como `@DeltaKroneckerG` no se inventan como país).
const Map<String, String> _countryNames = {
  'us': 'EE. UU.',
  'usa': 'EE. UU.',
  'united states': 'EE. UU.',
  'america': 'EE. UU.',
  'estados unidos': 'EE. UU.',
  'jp': 'Japón',
  'japan': 'Japón',
  'japón': 'Japón',
  'tokyo': 'Japón',
  'osaka': 'Japón',
  'de': 'Alemania',
  'germany': 'Alemania',
  'alemania': 'Alemania',
  'berlin': 'Alemania',
  'frankfurt': 'Alemania',
  'nl': 'Países Bajos',
  'netherlands': 'Países Bajos',
  'holland': 'Países Bajos',
  'amsterdam': 'Países Bajos',
  'fr': 'Francia',
  'france': 'Francia',
  'francia': 'Francia',
  'paris': 'Francia',
  'gb': 'Reino Unido',
  'uk': 'Reino Unido',
  'united kingdom': 'Reino Unido',
  'england': 'Reino Unido',
  'london': 'Reino Unido',
  'ca': 'Canadá',
  'canada': 'Canadá',
  'canadá': 'Canadá',
  'toronto': 'Canadá',
  'kr': 'Corea del Sur',
  'korea': 'Corea del Sur',
  'south korea': 'Corea del Sur',
  'seoul': 'Corea del Sur',
  'sg': 'Singapur',
  'singapore': 'Singapur',
  'in': 'India',
  'india': 'India',
  'br': 'Brasil',
  'brazil': 'Brasil',
  'es': 'España',
  'spain': 'España',
  'españa': 'España',
  'it': 'Italia',
  'italy': 'Italia',
  'se': 'Suecia',
  'sweden': 'Suecia',
  'ch': 'Suiza',
  'switzerland': 'Suiza',
  'pl': 'Polonia',
  'poland': 'Polonia',
  'tr': 'Turquía',
  'turkey': 'Turquía',
  'turkiye': 'Turquía',
  'ru': 'Rusia',
  'russia': 'Rusia',
  'vn': 'Vietnam',
  'vietnam': 'Vietnam',
  'th': 'Tailandia',
  'thailand': 'Tailandia',
  'fi': 'Finlandia',
  'finland': 'Finlandia',
  'no': 'Noruega',
  'norway': 'Noruega',
  'dk': 'Dinamarca',
  'denmark': 'Dinamarca',
  'au': 'Australia',
  'australia': 'Australia',
  'sydney': 'Australia',
  'mx': 'México',
  'mexico': 'México',
  'méxico': 'México',
  'ar': 'Argentina',
  'argentina': 'Argentina',
  'cl': 'Chile',
  'chile': 'Chile',
  'co': 'Colombia',
  'colombia': 'Colombia',
  'pe': 'Perú',
  'peru': 'Perú',
  'cz': 'Chequia',
  'at': 'Austria',
  'austria': 'Austria',
  'be': 'Bélgica',
  'belgium': 'Bélgica',
  'ie': 'Irlanda',
  'ireland': 'Irlanda',
  'pt': 'Portugal',
  'portugal': 'Portugal',
  'gr': 'Grecia',
  'greece': 'Grecia',
  'hu': 'Hungría',
  'hungary': 'Hungría',
  'ro': 'Rumanía',
  'romania': 'Rumanía',
  'ua': 'Ucrania',
  'ukraine': 'Ucrania',
  'il': 'Israel',
  'israel': 'Israel',
  'ae': 'Emiratos Árabes',
  'sa': 'Arabia Saudí',
  'id': 'Indonesia',
  'indonesia': 'Indonesia',
  'my': 'Malasia',
  'malaysia': 'Malasia',
  'ph': 'Filipinas',
  'philippines': 'Filipinas',
  'tw': 'Taiwán',
  'taiwan': 'Taiwán',
  'hk': 'Hong Kong',
  'hong kong': 'Hong Kong',
  'nz': 'Nueva Zelanda',
  'new zealand': 'Nueva Zelanda',
  'za': 'Sudáfrica',
  'south africa': 'Sudáfrica',
  'eg': 'Egipto',
  'egypt': 'Egipto',
};

/// Bandera emoji (🇺🇸, 🇯🇵…) -> código ISO de 2 letras ("us", "jp").
/// Las banderas son pares de indicadores regionales U+1F1E6..U+1F1FF.
String? _flagToCode(String name) {
  final runes = name.runes.toList();
  for (var i = 0; i + 1 < runes.length; i++) {
    final a = runes[i] - 0x1F1E6;
    final b = runes[i + 1] - 0x1F1E6;
    if (a >= 0 && a < 26 && b >= 0 && b < 26) {
      final code = String.fromCharCode(0x61 + a) + String.fromCharCode(0x61 + b);
      if (_countryNames.containsKey(code)) return code;
    }
  }
  return null;
}

String? countryFromName(String name) {
  if (name.trim().isEmpty) return null;
  // Bandera emoji primero: "US 🇺🇸 | @Raydikalx" es EE. UU.
  final flag = _flagToCode(name);
  if (flag != null) return _countryNames[flag];
  // Código de 2 letras en MAYÚSCULAS ("US | …", "DE-01"): señal fuerte.
  // No vale "In" de "Best-In-01": ahí no está todo en mayúsculas.
  for (final token in name.split(RegExp(r'[^A-Za-z]+'))) {
    if (token.length == 2 && token == token.toUpperCase()) {
      final hit = _countryNames[token.toLowerCase()];
      if (hit != null) return hit;
    }
  }
  final cleaned =
      name.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ');
  final tokens = cleaned.split(' ').where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return null;
  // Frases de varias palabras primero ("united states", "south korea"…).
  for (var n = 3; n >= 2; n--) {
    for (var i = 0; i + n <= tokens.length; i++) {
      final hit = _countryNames[tokens.sublist(i, i + n).join(' ')];
      if (hit != null) return hit;
    }
  }
  // Nombres completos (japan, tokyo, francia…).
  for (final token in tokens) {
    if (token.length > 2) {
      final hit = _countryNames[token];
      if (hit != null) return hit;
    }
  }
  // Códigos de 2 letras solo si son la única palabra del nombre
  // ("DE-01", "US"): en nombres largos un "in" o un "de" sueltos
  // dan falsos positivos ("Best-In-01" no es India).
  final alpha =
      tokens.where((t) => RegExp(r'[a-z]').hasMatch(t)).toList();
  if (alpha.length == 1) {
    return _countryNames[alpha.first];
  }
  return null;
}
