// Comprar puntos con Transfermóvil (2026-11-17).
//
// El usuario elige el paquete, paga con Transfermóvil y sube la
// captura, como el paywall de Premium. El envío es REAL: la
// solicitud va a Firestore (colección `pointsRequests`, servicio
// PointsPurchaseService) y Kristian la aprueba o niega; al aprobar,
// los puntos se suman al usuario.
//
// Textos en español directo: se localizan en 6 idiomas cuando se
// elija el diseño final.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/accent.dart';
import '../services/analytics_sync.dart';
import '../services/points_purchase_service.dart';
import '../services/premium.dart';
import '../services/premium_screenshot.dart';
import '../services/remote_tuning.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';

class BuyPointsScreen extends StatefulWidget {
  const BuyPointsScreen({super.key});

  @override
  State<BuyPointsScreen> createState() => _BuyPointsScreenState();
}

class _BuyPointsScreenState extends State<BuyPointsScreen> {
  /// 0 = paquetes, 1 = pago, 2 = enviado (en revisión).
  int _step = 0;
  PointsPack _selected = kPointsPacks[1];
  PremiumScreenshot? _screenshot;
  bool _picking = false;
  bool _submitting = false;

  /// Ya se avisó de la acreditación (para subir el progreso una
  /// sola vez cuando Kristian aprueba).
  bool _credited = false;

  @override
  void initState() {
    super.initState();
    PointsPurchaseService.latestRequestNotifier
        .addListener(_onRequestChanged);
    // Si ya había una solicitud (se salió y volvió), se lee su
    // estado; sin temporizadores aquí (el _submit ya escucha en
    // vivo la solicitud que crea).
    unawaited(PointsPurchaseService.instance.refreshLatestRequest());
  }

  @override
  void dispose() {
    PointsPurchaseService.latestRequestNotifier
        .removeListener(_onRequestChanged);
    super.dispose();
  }

  void _onRequestChanged() {
    final req = PointsPurchaseService.latestRequestNotifier.value;
    if (req == null || !mounted) return;
    if (req.isApproved && _step == 2 && !_credited) {
      _credited = true;
      // La nube ya tiene los puntos acreditados: al subir el
      // progreso, el teléfono los toma (la nube manda cuando tiene
      // más puntos que el teléfono).
      unawaited(AnalyticsSync.uploadProgress());
    }
    if (mounted && _step == 2) setState(() {});
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado')),
    );
  }

  Future<void> _pickScreenshot() async {
    if (_picking) return;
    setState(() => _picking = true);
    final shot = await pickAndEncodeScreenshot();
    if (!mounted) return;
    setState(() {
      _picking = false;
      if (shot != null) _screenshot = shot;
    });
  }

  Future<void> _submit() async {
    if (_screenshot == null || _submitting) return;
    setState(() => _submitting = true);
    final ok = await PointsPurchaseService.instance.submitPointsRequest(
      pack: _selected,
      screenshotData: _screenshot!.dataUrl,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_submitErrorText())),
      );
      return;
    }
    setState(() => _step = 2);
  }

  /// Qué pasó al enviar, en palabras del usuario (igual que el
  /// paywall: no solo «revisa tu conexión»).
  String _submitErrorText() {
    switch (PointsPurchaseService.instance.lastSubmitError) {
      case 'no-session':
        return 'Inicia sesión para comprar puntos.';
      case 'bad-pack':
        return 'Ese paquete no es válido.';
      case 'timeout':
        return 'No se pudo enviar: conexión lenta. Inténtalo de nuevo.';
      case 'denied':
        return 'No tienes permiso para enviar la solicitud.';
      default:
        return 'No se pudo enviar la solicitud. Revisa tu conexión.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // En el paso de pago, el atrás del teléfono vuelve a los
    // paquetes en vez de salir de la pantalla (auditoría
    // 2026-11-17: el botón interno sí volvía, el del sistema no).
    return PopScope(
      canPop: _step != 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 1) {
          setState(() {
            _step = 0;
            _screenshot = null;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Comprar puntos')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_step == 0) ..._packsBody(scheme, isDark),
              if (_step == 1) ..._payBody(scheme, isDark),
              if (_step == 2)
                ValueListenableBuilder<PointsRequest?>(
                  valueListenable:
                      PointsPurchaseService.latestRequestNotifier,
                  builder: (_, req, __) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _pendingBody(scheme, req),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Paso 0: paquetes ----

  List<Widget> _packsBody(ColorScheme scheme, bool isDark) {
    return [
      const Text(
        'Compra puntos',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        'Los puntos se gastan en la Tienda: temas, avatares, insignias y marcos. Paga con Transfermóvil.',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
      const SizedBox(height: 12),
      for (final pack in kPointsPacks) ...[
        _PackCard(
          pack: pack,
          isDark: isDark,
          onBuy: () => setState(() {
            _selected = pack;
            _step = 1;
          }),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  // ---- Paso 1: pago + captura (como el paywall de Premium) ----

  List<Widget> _payBody(ColorScheme scheme, bool isDark) {
    final isExample = RemoteTuning.transfermovilIsExample;
    final cardColor = isDark ? AppAccent.darkCard : Colors.white;
    final borderColor =
        isDark ? AppAccent.darkBorder : const Color(0xFFE5E5E5);
    return [
      const Text(
        'Paga con Transfermóvil',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        'Paquete de ${formatCupPrice(_selected.points)} puntos · ${formatCupPrice(_selected.cup)} CUP',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1 · Haz la transferencia',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _PayRow(
                label: 'Monto',
                value: '${formatCupPrice(_selected.cup)} CUP',
                onCopy: () => _copy('${_selected.cup}', 'El monto'),
              ),
              _PayRow(
                label: isExample
                    ? 'Tarjeta destino (EJEMPLO)'
                    : 'Tarjeta destino',
                value: RemoteTuning.transfermovilCard,
                onCopy: () => _copy(
                    RemoteTuning.transfermovilCard, 'La tarjeta'),
              ),
              _PayRow(
                label: 'Número de Transfermóvil',
                value: RemoteTuning.transfermovilNumber,
                onCopy: () => _copy(
                    RemoteTuning.transfermovilNumber, 'El número'),
              ),
              Text(
                'Titular: Quemia · Concepto: Puntos Quemia',
                style: TextStyle(fontSize: 13, color: scheme.onSurface),
              ),
              if (isExample) ...[
                const SizedBox(height: 6),
                Text(
                  'Los datos de arriba son un EJEMPLO. El número real lo configura el equipo de Quemia.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '2 · Sube la captura del pago',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      if (_screenshot != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            _screenshot!.bytes,
            height: 80,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      if (_screenshot != null) const SizedBox(height: 8),
      DuoButton.secondary(
        label: _picking
            ? 'ELIGIENDO…'
            : (_screenshot == null
                ? 'ELEGIR CAPTURA'
                : 'CAMBIAR CAPTURA'),
        onPressed: _picking ? null : _pickScreenshot,
      ),
      const SizedBox(height: 8),
      DuoButton.primary(
        label: _submitting ? 'ENVIANDO…' : 'ENVIAR SOLICITUD',
        onPressed: (_screenshot == null || _submitting) ? null : _submit,
      ),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          onPressed: () => setState(() {
            _step = 0;
            _screenshot = null;
          }),
          child: const Text('Volver a los paquetes'),
        ),
      ),
    ];
  }

  // ---- Paso 2: enviado (en revisión / aprobado / negado) ----

  List<Widget> _pendingBody(ColorScheme scheme, PointsRequest? req) {
    if (req != null && req.isApproved) {
      return [
        const SizedBox(height: 32),
        Center(
          child: LucideIcon(
            LucideIcons.check,
            size: 64,
            color: AppAccent.primary,
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            '¡Listo!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Se sumaron ${formatCupPrice(req.points)} puntos a tu saldo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: scheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ),
        const SizedBox(height: 24),
        DuoButton.secondary(
          label: 'VOLVER A LA TIENDA',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ];
    }
    if (req != null && req.isDenied) {
      return [
        const SizedBox(height: 32),
        const Center(
          child: LucideIcon(
            LucideIcons.x,
            size: 64,
            color: Color(0xFFFF4B4B),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'No se aprobó',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        if (req.reason.isNotEmpty)
          Center(
            child: Text(
              req.reason,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
        const SizedBox(height: 24),
        DuoButton.primary(
          label: 'VOLVER A LOS PAQUETES',
          onPressed: () => setState(() {
            _step = 0;
            _screenshot = null;
            _credited = false;
          }),
        ),
      ];
    }
    return [
      const SizedBox(height: 32),
      Center(
        child: LucideIcon(
          LucideIcons.clock,
          size: 64,
          color: AppAccent.primary,
        ),
      ),
      const SizedBox(height: 16),
      const Center(
        child: Text(
          'Solicitud enviada',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: Text(
          'En revisión: te avisamos cuando se acrediten tus ${formatCupPrice(_selected.points)} puntos.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: scheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ),
      const SizedBox(height: 24),
      DuoButton.secondary(
        label: 'VOLVER A LA TIENDA',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ];
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.isDark,
    required this.onBuy,
  });

  final PointsPack pack;
  final bool isDark;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = isDark ? AppAccent.darkCard : Colors.white;
    final borderColor = pack.popular
        ? AppAccent.primary
        : (isDark ? AppAccent.darkBorder : const Color(0xFFE5E5E5));
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pack.popular)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppAccent.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'EL MÁS POPULAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            if (pack.popular) const SizedBox(height: 8),
            Row(
              children: [
                const LucideIcon(
                  LucideIcons.star,
                  size: 28,
                  color: Color(0xFFFFC800),
                  filled: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatCupPrice(pack.points)} PUNTOS',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${formatCupPrice(pack.cup)} CUP',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DuoButton.primary(label: 'COMPRAR', onPressed: onBuy),
          ],
        ),
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const LucideIcon(LucideIcons.copy, size: 20),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
