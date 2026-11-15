// Descarga las dos listas reales y comprueba parseo + orden.
// Uso: dart run tool/parse_subscriptions.dart
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:vpncuba/subscription.dart';

const _urls = [
  'https://raw.githubusercontent.com/0xRadikal/Free-v2ray-Configs/main/top100.txt',
  'https://raw.githubusercontent.com/morpheusadam/v2ray-config/main/subs/bundles/best.txt',
];

Future<void> main() async {
  for (final url in _urls) {
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      stdout.writeln('$url -> HTTP ${res.statusCode}, ${res.body.length} B');
      final links = parseSubscription(res.body);
      final counts = <String, int>{};
      for (final l in links) {
        counts[l.scheme] = (counts[l.scheme] ?? 0) + 1;
      }
      final reality =
          links.where((l) => l.raw.contains('security=reality')).length;
      final ranked = rankServers(links);
      final countries = ranked
          .take(6)
          .map((l) => countryFromName(l.name))
          .whereType<String>()
          .toList();
      stdout.writeln('  configs: ${links.length} $counts');
      stdout.writeln('  VLESS-Reality: $reality');
      stdout.writeln(
          '  top 6: ${ranked.take(6).map((l) => l.scheme).join(', ')}');
      stdout.writeln('  países en top 6: $countries');
    } catch (e) {
      stdout.writeln('$url -> ERROR: $e');
      exitCode = 1;
    }
  }
}
