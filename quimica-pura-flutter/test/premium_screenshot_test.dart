// Premium REAL (solo web): compresión de la captura del pago.
// Máx. 1024 px por el lado largo, JPEG ~75. Bytes inválidos → null.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quimica_pura/services/premium_screenshot.dart';

void main() {
  Uint8List makePng(int width, int height) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(0, 194, 168));
    return Uint8List.fromList(img.encodePng(image));
  }

  test('imagen grande se reduce a 1024 por el lado largo', () {
    final compressed = compressPremiumScreenshot(makePng(2000, 1000));
    expect(compressed, isNotNull);
    // JPEG: empieza por FF D8.
    expect(compressed![0], 0xFF);
    expect(compressed[1], 0xD8);
    final decoded = img.decodeImage(compressed)!;
    expect(decoded.width, 1024);
    expect(decoded.height, 512);
  });

  test('imagen vertical se reduce por el alto', () {
    final compressed = compressPremiumScreenshot(makePng(800, 2000));
    expect(compressed, isNotNull);
    final decoded = img.decodeImage(compressed!)!;
    expect(decoded.height, 1024);
    expect(decoded.width, 410);
  });

  test('imagen pequeña no se agranda', () {
    final compressed = compressPremiumScreenshot(makePng(400, 300));
    expect(compressed, isNotNull);
    final decoded = img.decodeImage(compressed!)!;
    expect(decoded.width, 400);
    expect(decoded.height, 300);
  });

  test('bytes que no son imagen devuelven null', () {
    expect(
      compressPremiumScreenshot(
        Uint8List.fromList('esto no es una imagen'.codeUnits),
      ),
      isNull,
    );
    expect(compressPremiumScreenshot(Uint8List(0)), isNull);
  });

  test('límites de compresión', () {
    expect(kPremiumScreenshotMaxSide, 1024);
    expect(kPremiumScreenshotQuality, 75);
  });
}
