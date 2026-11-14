import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Copia [asset] a un archivo temporal [name] (solo si no existe
/// ya) y devuelve su ruta.
Future<String?> copyAssetToTemp(String asset, String name) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  if (!await file.exists()) {
    final bytes = await rootBundle.load(asset);
    await file.writeAsBytes(bytes.buffer.asUint8List());
  }
  return file.path;
}
