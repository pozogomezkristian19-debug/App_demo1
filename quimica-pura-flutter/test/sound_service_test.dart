// Prueba de los sonidos propios (v6): los 5 WAV están empaquetados
// como assets, son WAV válidos (mono, 22 050 Hz, 16 bits) y el
// servicio no rompe aunque el plugin de audio no esté disponible
// (en los tests no hay plugin: debe caer al fallback sin lanzar).
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/sound_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';

int _u16(ByteData d, int off) => d.getUint16(off, Endian.little);
int _u32(ByteData d, int off) => d.getUint32(off, Endian.little);
String _tag(ByteData d, int off) =>
    String.fromCharCodes(d.buffer.asUint8List(off, 4));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('los 5 sonidos existen y son WAV válidos', () async {
    const files = {
      'correct': (0.2, 0.6),
      'wrong': (0.2, 0.6),
      'levelup': (0.5, 1.2),
      'streak': (0.3, 0.8),
      'click': (0.01, 0.2),
    };
    for (final entry in files.entries) {
      final data = await rootBundle.load('assets/sounds/${entry.key}.wav');
      final bytes = data.buffer.asByteData();
      expect(_tag(bytes, 0), 'RIFF');
      expect(_tag(bytes, 8), 'WAVE');
      expect(_tag(bytes, 12), 'fmt ');
      expect(_u16(bytes, 20), 1, reason: 'PCM');
      expect(_u16(bytes, 22), 1, reason: 'mono');
      expect(_u32(bytes, 24), 22050, reason: 'sample rate');
      expect(_u16(bytes, 34), 16, reason: '16 bits');
      final frames = _u32(bytes, 40) ~/ 2;
      final seconds = frames / 22050;
      expect(seconds, greaterThan(entry.value.$1));
      expect(seconds, lessThan(entry.value.$2));
    }
  });

  test('el servicio no lanza sin plugin de audio', () async {
    UserPrefs.soundOn = true;
    await SoundService.correct();
    await SoundService.wrong();
    await SoundService.levelUp();
    await SoundService.streak();
    await SoundService.tap();
    await SoundService.haptic();
  });

  test('con el sonido apagado no hace nada y no lanza', () async {
    UserPrefs.soundOn = false;
    await SoundService.correct();
    await SoundService.levelUp();
    UserPrefs.soundOn = true;
  });
}
