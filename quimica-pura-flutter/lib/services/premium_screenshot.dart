// Subida de la captura del pago de Transfermóvil (Premium, solo web).
//
// RUTA ÚNICA (veredicto de Storage confirmado 2026-11-15: el bucket
// quemia-8410a.firebasestorage.app NO existe — dos sondas
// devolvieron 404 'bucket does not exist'; NO se añade
// firebase_storage): la imagen se elige con image_picker (en web
// abre el selector de archivos), se comprime (máx. 1024 px por el
// lado largo, JPEG ~75) y se guarda como base64 data URL en
// paymentRequests.screenshotData. screenshotUrl y screenshotPath
// quedan en '' (campos del contrato, vacíos).
//
// Todo el código de subida vive aquí y solo aquí: el paywall llama
// a [pickAndEncodeScreenshot] y nada más toca image_picker ni los
// bytes de la imagen.

import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Lado largo máximo de la captura comprimida (px).
const int kPremiumScreenshotMaxSide = 1024;

/// Calidad JPEG de la captura comprimida (0-100).
const int kPremiumScreenshotQuality = 75;

/// Resultado de elegir + comprimir una captura.
class PremiumScreenshot {
  const PremiumScreenshot({
    required this.dataUrl,
    required this.bytes,
  });

  /// 'data:image/jpeg;base64,...' listo para paymentRequests
  /// .screenshotData.
  final String dataUrl;

  /// Los mismos bytes JPEG comprimidos (para la futura subida a
  /// Storage: [uploadScreenshotToStorage] los sube tal cual).
  final Uint8List bytes;
}

/// Abre el selector de archivos y devuelve la captura comprimida
/// como data URL, o null si el usuario cancela. Nunca lanza: un
/// fallo al leer o comprimir devuelve null.
Future<PremiumScreenshot?> pickAndEncodeScreenshot({
  ImagePicker? pickerOverride,
}) async {
  try {
    final picker = pickerOverride ?? ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    final original = await picked.readAsBytes();
    final compressed = compressPremiumScreenshot(original);
    if (compressed == null) return null;
    return PremiumScreenshot(
      dataUrl:
          'data:image/jpeg;base64,${base64Encode(compressed)}',
      bytes: compressed,
    );
  } catch (_) {
    return null;
  }
}

/// Comprime bytes de imagen (cualquier formato que entienda el
/// paquete `image`) a JPEG: lado largo máx. 1024 px, calidad ~75.
/// null si los bytes no son una imagen válida. Función pura para
/// tests: entra bytes, salen bytes.
Uint8List? compressPremiumScreenshot(Uint8List original) {
  try {
    final decoded = img.decodeImage(original);
    if (decoded == null) return null;
    final img.Image resized;
    if (decoded.width > kPremiumScreenshotMaxSide ||
        decoded.height > kPremiumScreenshotMaxSide) {
      // Redimensiona por el lado largo, sin deformar.
      if (decoded.width >= decoded.height) {
        resized = img.copyResize(decoded, width: kPremiumScreenshotMaxSide);
      } else {
        resized = img.copyResize(decoded, height: kPremiumScreenshotMaxSide);
      }
    } else {
      resized = decoded;
    }
    return Uint8List.fromList(
      img.encodeJpg(resized, quality: kPremiumScreenshotQuality),
    );
  } catch (_) {
    return null;
  }
}

/// Subida a Firebase Storage: NO EXISTE como opción. Veredicto
/// confirmado 2026-11-15: el bucket quemia-8410a.firebasestorage.app
/// no existe (404 en dos sondas). Esta función queda solo como
/// marcador explícito para que nadie la implemente por accidente:
/// la captura va SIEMPRE en screenshotData (base64) y
/// screenshotUrl/screenshotPath quedan en ''.
Future<({String url, String path})> uploadScreenshotToStorage({
  required String uid,
  required String requestId,
  required PremiumScreenshot screenshot,
}) async {
  throw UnimplementedError(
    'Sin Storage: el bucket no existe (404 verificado). '
    'La captura va en screenshotData (base64).',
  );
}
