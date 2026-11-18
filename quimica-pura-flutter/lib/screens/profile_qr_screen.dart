// Código QR del perfil (Kristian 2026-11-16, lote de 11 puntos,
// punto 11): tarjeta blanca redondeada, centrada, sobre el perfil
// oscurecido. Arriba el avatar, el nombre en negrita + @usuario en
// gris y la palabra "quemia" con el color del acento; a la derecha
// el QR con el logo de Quemia (anillo orbital) en el centro.
//
// El QR codifica el perfil ('quemia:user:<nombre-de-usuario>') y
// al ESCANEARLO con la app se abre automáticamente ese perfil
// público con todas sus estadísticas. La tarjeta se puede
// COMPARTIR (hoja nativa, la misma de "Compartir la app") y
// GUARDAR como imagen en la galería. ESCANEAR usa la cámara en el
// móvil; en web, si no hay cámara, dice claro que escanear
// necesita la app del teléfono (no se inventa un escaneo que no
// funciona).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../services/accent.dart';
import '../services/localization.dart';
import '../services/remote_shop_catalog.dart';
import '../services/social_service.dart';
import '../services/sound_service.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/social_avatar.dart';
import 'public_profile_screen.dart';

/// Pantalla del QR de un perfil: [username] es el usuario del QR,
/// [displayName] el nombre que se enseña. [isOwn] = es mi propio
/// código (el título dice "Mi código QR").
class QrScreen extends StatefulWidget {
  const QrScreen({
    super.key,
    required this.username,
    required this.displayName,
    this.avatarAsset,
    this.avatarImageFile,
    this.avatarImageUrl,
    this.isOwn = false,
  });

  final String username;
  final String displayName;
  final String? avatarAsset;
  final File? avatarImageFile;

  /// Foto equipada remota: se baja al llegar, sin frenar la
  /// apertura (auditoría 2026-11-17). Mientras tanto se ve el
  /// avatar por defecto (avatarAsset).
  final String? avatarImageUrl;
  final bool isOwn;

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  final _cardKey = GlobalKey();
  final _scrollController = ScrollController();
  bool _sharing = false;
  bool _saving = false;
  bool _scanning = false;
  bool _handledScan = false;
  String? _scanMessage;

  /// Foto equipada ya resuelta (la del constructor o la bajada al
  /// llegar). Mientras se baja, el avatar por defecto.
  File? _avatarFile;

  @override
  void initState() {
    super.initState();
    _avatarFile = widget.avatarImageFile;
    final url = widget.avatarImageUrl;
    if (_avatarFile == null && url != null && url.isNotEmpty) {
      ShopImageCache.ensureCached(url).then((file) {
        if (!mounted || file == null) return;
        setState(() => _avatarFile = file);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Captura la tarjeta como PNG (mismo patrón que Mis
  /// estadísticas: scroll arriba + 2 intentos de endOfFrame, ratio
  /// de píxeles entre 1 y 2).
  Future<Uint8List?> _captureCard() async {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    RenderRepaintBoundary? boundary;
    for (var attempt = 0; attempt < 2; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 120));
      final object = _cardKey.currentContext?.findRenderObject();
      if (object is RenderRepaintBoundary && object.size != Size.zero) {
        boundary = object;
        break;
      }
    }
    if (boundary == null) return null;
    final pixelRatio =
        MediaQuery.of(context).devicePixelRatio.clamp(1.0, 2.0);
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final bytes = byteData.buffer.asUint8List();
    return bytes.isEmpty ? null : bytes;
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _captureCard();
      if (bytes == null) return;
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(bytes,
              name: 'quemia-qr-${widget.username}.png',
              mimeType: 'image/png')
        ],
        text: '@${widget.username} · Quemia',
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('shareImageFail'))),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await _captureCard();
      if (bytes == null) throw StateError('no image');
      await Gal.putImageBytes(
        bytes,
        album: 'Quemia',
        name: 'quemia-qr-${widget.username}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('profileQrSaved'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('profileQrSaveFailed'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _startScan() {
    SoundService.tap();
    // En web no hay cámara: mensaje claro, sin inventar escaneo.
    if (kIsWeb) {
      setState(() {
        _scanning = false;
        _scanMessage = tr('profileQrScanWeb');
      });
      return;
    }
    setState(() {
      _scanning = true;
      _handledScan = false;
      _scanMessage = null;
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handledScan) return;
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;
    if (!raw.startsWith('quemia:user:')) {
      _handledScan = true;
      if (mounted) {
        setState(() => _scanMessage = tr('profileQrNotQuemia'));
      }
      return;
    }
    final username = raw.substring('quemia:user:'.length);
    final found = await SocialService.findUserByUsername(username);
    if (!mounted) return;
    if (found == null) {
      _handledScan = true;
      setState(() => _scanMessage = tr('profileQrNoUser'));
      return;
    }
    _handledScan = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(uid: found.deviceId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.75),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          widget.isOwn ? tr('profileQrTitle') : widget.displayName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          children: [
            // La tarjeta blanca (2 columnas: identidad a la
            // izquierda, QR a la derecha).
            RepaintBoundary(
              key: _cardKey,
              child: Container(
                width: 340,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: AppAccent.primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: SocialAvatar(
                              username: widget.username,
                              avatarAsset: widget.avatarAsset,
                              avatarImageFile: _avatarFile,
                              badgeId: SocialService.equippedBadgeId,
                              frameItem: SocialService.equippedFrameItem,
                              frameRingWidth: 6,
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${widget.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'quemia',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppAccent.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    QrImageView(
                      data: profileQrData(widget.username),
                      size: 150,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      embeddedImage:
                          const AssetImage('assets/ring_logo.png'),
                      embeddedImageStyle: const QrEmbeddedImageStyle(
                        size: Size(36, 36),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            DuoButton.primary(
              label: tr('profileQrShare').toUpperCase(),
              icon: LucideIcons.share2,
              onPressed: _sharing ? null : _share,
            ),
            const SizedBox(height: 12),
            DuoButton.secondary(
              label: tr('profileQrSave').toUpperCase(),
              icon: LucideIcons.download,
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: 12),
            DuoButton.secondary(
              label: tr('profileQrScan').toUpperCase(),
              icon: LucideIcons.scanLine,
              onPressed: _startScan,
            ),
            if (_scanMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _scanMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ],
            if (_scanning) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: MobileScanner(onDetect: _onDetect),
                ),
              ),
              const SizedBox(height: 12),
              DuoButton.secondary(
                label: tr('closeWord').toUpperCase(),
                onPressed: () => setState(() => _scanning = false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
