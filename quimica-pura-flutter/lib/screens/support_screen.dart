// Ventanita de Soporte (Quemia 7.0, Kristian 09:52): el botón de
// Soporte de Cuenta ya NO abre WhatsApp directo — abre esta
// pantalla dentro de la app, con el hilo de mis mensajes y las
// respuestas del admin, y un compositor para escribir.
//
// - Sin Google vinculada, la puerta de Google (regla de identidad):
//   no se escribe nada sin cuenta.
// - Enviar sin internet NO da error: el mensaje queda encolado en
//   el servicio y se envía solo al volver internet; la ventanita lo
//   muestra con "Se enviará solo cuando tengas internet".
// - La opción de WhatsApp solo aparece si el interruptor remoto
//   'Mostrar WhatsApp en Soporte' está encendido (por defecto, no):
//   '¿Prefieres WhatsApp? Escríbenos al <número>' (número remoto,
//   por defecto +5356519431).
// - La respuesta automática de Muse NO va en esta versión.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/localization.dart';
import '../services/support_service.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/online_gate.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({
    super.key,
    this.isGoogleLinked,
    this.onLinkGoogle,
    this.service,
  });

  final bool? isGoogleLinked;
  final Future<bool> Function()? onLinkGoogle;

  /// Servicio inyectable para tests (por defecto, el real).
  final SupportService? service;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final SupportService _service;
  final _ctrl = TextEditingController();
  Stream<List<SupportMessage>>? _stream;
  List<SupportMessage> _pending = [];
  SupportSettings? _settings;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SupportService.instance;
    _stream = _service.watchMyMessages();
    _loadSettings();
    _loadPending();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final s = await _service.fetchSupportSettings();
    if (mounted) setState(() => _settings = s);
  }

  Future<void> _loadPending() async {
    final p = await _service.pendingMessages();
    if (mounted) setState(() => _pending = p);
  }

  /// Vuelve a leer el hilo (tras enviar): el stream se recrea y
  /// su primer valor ya trae el mensaje recién enviado.
  Future<void> _refresh() async {
    setState(() => _stream = _service.watchMyMessages());
    await _loadPending();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final ok = await _service.sendMessage(text);
    if (!mounted) return;
    _ctrl.clear();
    setState(() => _sending = false);
    await _refresh();
    if (!mounted) return;
    if (!ok) {
      // Sin internet (o sin Google): sin error, sin rojo — el
      // mensaje quedó encolado y se enviará solo.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('supportQueued'))),
      );
    }
  }

  /// Abre wa.me con el número remoto (y, si falla, el esquema
  /// propio de WhatsApp). Sin diálogo de error: línea tranquila.
  Future<void> _openWhatsApp(String number) async {
    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final waMe = Uri.parse('https://wa.me/$digits');
    final appScheme = Uri.parse('whatsapp://send?phone=$digits');
    var opened = false;
    try {
      if (await canLaunchUrl(waMe)) {
        opened = await launchUrl(waMe, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      try {
        if (await canLaunchUrl(appScheme)) {
          opened =
              await launchUrl(appScheme, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('supportWhatsAppFailed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const teal = Color(0xFF00C2A8);
    return Scaffold(
      appBar: AppBar(title: Text(tr('supportTitle'))),
      body: OnlineGate(
        isGoogleLinked: widget.isGoogleLinked,
        onLinkGoogle: widget.onLinkGoogle,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<SupportMessage>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data ?? [];
                  final pendingIds = _pending.map((m) => m.id).toSet();
                  final all = [...messages, ..._pending]
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  if (all.isEmpty && _settings?.showWhatsApp != true) {
                    return _EmptySupport(scheme: scheme);
                  }
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    color: teal,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      children: [
                        for (final m in all)
                          _ThreadItem(
                            message: m,
                            pending: pendingIds.contains(m.id),
                            scheme: scheme,
                            isDark: isDark,
                          ),
                        if (_settings?.showWhatsApp == true)
                          _WhatsAppOption(
                            number: _settings!.supportNumber,
                            scheme: scheme,
                            isDark: isDark,
                            onTap: () =>
                                _openWhatsApp(_settings!.supportNumber),
                          ),
                        if (all.isEmpty) _EmptySupport(scheme: scheme),
                      ],
                    ),
                  );
                },
              ),
            ),
            _Composer(
              controller: _ctrl,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

/// Un mensaje mío con su respuesta (si la hay): mi burbuja a la
/// derecha en teal suave, la respuesta del admin a la izquierda en
/// tarjeta blanca, y debajo una línea pequeña de estado.
class _ThreadItem extends StatelessWidget {
  const _ThreadItem({
    required this.message,
    required this.pending,
    required this.scheme,
    required this.isDark,
  });

  final SupportMessage message;
  final bool pending;
  final ColorScheme scheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF00C2A8);
    final status = pending
        ? tr('supportQueued')
        : message.isAnswered
            ? tr('supportAnswered')
            : tr('supportOpen');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                // Burbuja propia: tinte teal sólido, sin degradado
                // y sin sombra (diseño Duolingo §3.15).
                color: teal.withValues(alpha: isDark ? 0.25 : 0.14),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                message.message,
                style: TextStyle(fontSize: 15, color: scheme.onSurface),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$status · ${_fmtDate(message.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (message.hasReply) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.82,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? scheme.surfaceContainerHighest : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(18),
                  ),
                  // Borde fino #E5E5E5 en vez de sombra: la sombra
                  // era una de las "líneas" feas (diseño §3.15).
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF37464F)
                          : const Color(0xFFE5E5E5),
                      width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('supportReplyTitle'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: teal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.reply!,
                      style: TextStyle(fontSize: 15, color: scheme.onSurface),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Opción de WhatsApp (solo con el interruptor remoto encendido).
class _WhatsAppOption extends StatelessWidget {
  const _WhatsAppOption({
    required this.number,
    required this.scheme,
    required this.isDark,
    required this.onTap,
  });

  final String number;
  final ColorScheme scheme;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Diseño Duolingo §3.15: fila plana con borde 2 pt #E5E5E5 y
    // radio 16, sin tarjeta con sombra.
    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? const Color(0xFF37464F) : const Color(0xFFE5E5E5),
            width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00C2A8).withValues(alpha: 0.14),
                ),
                alignment: Alignment.center,
                child: const LucideIcon(
                  LucideIcons.messageCircle,
                  size: 22,
                  color: Color(0xFF00C2A8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('supportWhatsApp').replaceFirst('%s', number),
                  style:
                      const TextStyle(fontSize: 15, color: Color(0xFF4B4B4B)),
                ),
              ),
              const LucideIcon(
                LucideIcons.chevronRight,
                size: 20,
                color: Color(0xFFAFAFAF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vacío bonito: círculo teal + texto, nada de error.
class _EmptySupport extends StatelessWidget {
  const _EmptySupport({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF00C2A8);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: teal.withValues(alpha: 0.14),
              ),
              alignment: Alignment.center,
              child: const LucideIcon(
                LucideIcons.messageCircle,
                size: 32,
                color: teal,
                threeD: true,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('supportEmpty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compositor: campo redondeado + botón teal de enviar.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              // Campo con borde 2 pt #E5E5E5 y radio 16 (§1.6):
              // sin sombra, sin flotar sobre el fondo.
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
                ),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: tr('supportHint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Botón de enviar: círculo teal sólido, sin degradado
            // y sin sombra. Se conserva el icono arrowRight que
            // usan los tests para tocarlo.
            SizedBox(
              width: 48,
              height: 48,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: sending ? null : onSend,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF00C2A8),
                    ),
                    alignment: Alignment.center,
                    child: sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const LucideIcon(LucideIcons.arrowRight,
                            size: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fecha corta: 11/11/2026 14:30.
String _fmtDate(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day}/${d.month}/${d.year} $hh:$mm';
}
