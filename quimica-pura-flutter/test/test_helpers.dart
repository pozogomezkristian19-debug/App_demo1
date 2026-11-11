// Ayudas para los tests de Melli-Qui.
//
// loadRobotoFonts: carga la Roboto REAL del SDK (la misma del
// teléfono) antes de montar pantallas. Sin ella, los tests dibujan
// el texto con la fuente cuadrada de pruebas (cada letra mide lo
// mismo que la fuente: ~2x más ancha que Roboto), y las medidas de
// "¿cabe sin deslizar?" y las capturas salen mucho más apretadas
// que en el teléfono de verdad. Si no se encuentra el SDK, no
// rompe nada: los tests siguen con la fuente de pruebas.
import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadRobotoFonts() async {
  final home = Platform.environment['HOME'] ?? '';
  final dir =
      '$home/sdks/flutter-3.47.9/bin/cache/artifacts/material_fonts';
  const files = [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Italic.ttf',
    'Roboto-BoldItalic.ttf',
  ];
  final loader = FontLoader('Roboto');
  var found = 0;
  for (final file in files) {
    final f = File('$dir/$file');
    if (!await f.exists()) continue;
    final bytes = await f.readAsBytes();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    found++;
  }
  if (found > 0) await loader.load();
}
