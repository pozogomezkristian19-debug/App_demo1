import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import 'models.dart';

/// Cabecera del CSV de exportación de usuarios (separador `;`).
const String usersCsvHeader =
    'Nombre;UID;Niveles Bachillerato;Niveles Universidad;Niveles totales;'
    'Puntos;Racha (días);Última actividad;Se unió;Pista;Versión;Baneado;'
    'Motivo del baneo';

/// Formatea una fecha en hora local como `yyyy-MM-dd HH:mm`.
String _formatLocalDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Escapa un campo CSV: lo envuelve en comillas dobles (duplicando las
/// comillas internas) si contiene `;`, `"` o un salto de línea.
String _escapeCsvField(String value) {
  if (value.contains(';') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Construye el CSV de usuarios con separador `;` (Excel en español).
///
/// Empieza con BOM UTF-8 para que Excel lo abra con los acentos correctos.
/// Una lista vacía devuelve solo la cabecera.
String buildUsersCsv(List<AppUser> users) {
  final buffer = StringBuffer('\uFEFF$usersCsvHeader');
  for (final user in users) {
    buffer
      ..write('\n')
      ..write(_escapeCsvField(user.username))
      ..write(';')
      ..write(_escapeCsvField(user.id))
      ..write(';${user.levelsBachPassed}')
      ..write(';${user.levelsUniPassed}')
      ..write(';${user.totalLevelsPassed}')
      ..write(';${user.points}')
      ..write(';${user.streak}')
      ..write(';${_formatLocalDateTime(user.lastActive)}')
      ..write(';${_formatLocalDateTime(user.joinedAt)}')
      ..write(';${user.track == 'uni' ? 'Universidad' : 'Bachillerato'}')
      ..write(';')
      ..write(_escapeCsvField(user.appVersion))
      ..write(';${user.banned ? 'Sí' : 'No'}')
      ..write(';')
      ..write(_escapeCsvField(user.bannedReason));
  }
  return buffer.toString();
}

/// Nombre del archivo CSV con la fecha de hoy: `quemia-usuarios-AAAAMMDD.csv`.
String usersCsvFileName([DateTime? now]) {
  final date = now ?? DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  return 'quemia-usuarios-${date.year}${two(date.month)}${two(date.day)}.csv';
}

/// Comparte el CSV de usuarios con la hoja de compartir del sistema.
Future<void> shareUsersCsv(List<AppUser> users) async {
  final csv = buildUsersCsv(users);
  final bytes = utf8.encode(csv);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[
        XFile.fromData(
          bytes,
          name: usersCsvFileName(),
          mimeType: 'text/csv',
        ),
      ],
    ),
  );
}
