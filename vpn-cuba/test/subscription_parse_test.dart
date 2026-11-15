import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpncuba/subscription.dart';

const _plainList = '''
#profile-title: Lista de ejemplo
#profile-update-interval: 1

vless://uuid@jp.example.com:443?security=reality&sni=example.com#Japan-01
trojan://pass@de.example.com:443#Germany
vmess://eyJ2IjoiMiIsInBzIjoiVm1lc3MiLCJhZGQiOiJ2bS5leGFtcGxlLmNvbSIsInBvcnQiOiI0NDMifQ==
ss://YWVzLTEyOC1nY206cGFzc0AxMjcuMC4wLjE6ODM4OA==#US
ss://YWVzLTI1Ni1nY206cGFzc0AxMjcuMC4wLjI6ODM4OA==#@DeltaKroneckerG
hysteria2://pass@sg.example.com:443#Singapore
''';

void main() {
  test('lista en texto plano: ignora comentarios y vacías', () {
    final links = parseSubscription(_plainList);
    expect(links.length, 6);
    expect(
      links.map((l) => l.scheme),
      ['vless', 'trojan', 'vmess', 'ss', 'ss', 'hysteria2'],
    );
    expect(links.first.name, 'Japan-01');
  });

  test('un blob base64 también se decodifica', () {
    final blob = base64Encode(utf8.encode(_plainList));
    final links = parseSubscription(blob);
    expect(links.length, 6);
    expect(links.first.scheme, 'vless');
  });

  test('orden: Reality y Trojan primero, Shadowsocks al final', () {
    final ranked = rankServers(parseSubscription(_plainList));
    expect(ranked.first.scheme, 'vless'); // Reality
    expect(ranked[1].scheme, 'trojan');
    expect(ranked[2].scheme, 'hysteria2');
    expect(ranked.last.scheme, 'ss');
  });

  test('no se repiten enlaces duplicados', () {
    final links = parseSubscription(
      'vless://a@x.com:443#Japan\nvless://a@x.com:443#Japan\n',
    );
    expect(links.length, 1);
  });

  test('país: nombres y códigos conocidos, en español', () {
    expect(countryFromName('Japan-01'), 'Japón');
    expect(countryFromName('DE'), 'Alemania');
    expect(countryFromName('US'), 'EE. UU.');
    expect(countryFromName('Tokyo'), 'Japón');
    expect(countryFromName('Francia'), 'Francia');
    expect(countryFromName('United States'), 'EE. UU.');
  });

  test('país: nombres raros no se inventan', () {
    expect(countryFromName('@DeltaKroneckerG'), isNull);
    expect(countryFromName(''), isNull);
    expect(countryFromName('Best-In-01'), isNull);
  });

  test('país: banderas emoji y códigos en mayúsculas (listas reales)', () {
    // Así vienen los nombres en top100.txt: "US 🇺🇸 | @Raydikalx | 47E914".
    expect(countryFromName('US 🇺🇸 | @Raydikalx | 47E914'), 'EE. UU.');
    expect(countryFromName('JP 🇯🇵 | algo'), 'Japón');
    expect(countryFromName('DE-01'), 'Alemania');
    expect(countryFromName('NL'), 'Países Bajos');
    // "In" en título no es India: solo vale el código TODO en mayúsculas.
    expect(countryFromName('Best-In-01'), isNull);
  });
}
