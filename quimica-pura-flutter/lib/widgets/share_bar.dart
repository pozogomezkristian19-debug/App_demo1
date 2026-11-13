// Barra fija de compartir (referidos 7.3): cuatro botones
// circulares con sus logos reales, con la etiqueta debajo de cada
// uno. Es FIJA: el padre la pone FUERA del scroll (debajo del
// contenido desplazable), así no se mueve al deslizar. Los logos
// de WhatsApp y Messenger son los oficiales en blanco sobre su
// color de marca (assets/whatsapp.png y assets/messenger.png);
// Compartir y Mensajes usan iconos Lucide sobre su color.
import 'package:flutter/material.dart';

import '../services/localization.dart';
import 'lucide_icons.dart';

/// Barra fija de compartir: Compartir, Mensajes, WhatsApp y
/// Messenger. Las acciones las pone el padre (Share, sms:, wa.me,
/// fb-messenger://): este widget solo dibuja los botones.
class ShareBar extends StatelessWidget {
  const ShareBar({
    super.key,
    required this.onShare,
    required this.onSms,
    required this.onWhatsApp,
    required this.onMessenger,
  });

  final VoidCallback onShare;
  final VoidCallback onSms;
  final VoidCallback onWhatsApp;
  final VoidCallback onMessenger;

  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color messengerBlue = Color(0xFF0084FF);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      // Separador fino arriba (como la barra de navegación): la
      // barra se distingue del contenido sin sombra borrosa.
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0xFFE5E5E5),
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ShareButton(
            label: tr('referralShare'),
            color: const Color(0xFF00C2A8),
            onTap: onShare,
            child: const LucideIcon(
              LucideIcons.share2,
              size: 26,
              color: Colors.white,
            ),
          ),
          _ShareButton(
            label: tr('referralSms'),
            color: const Color(0xFF2196F3),
            onTap: onSms,
            child: const LucideIcon(
              LucideIcons.messageCircle,
              size: 26,
              color: Colors.white,
            ),
          ),
          _ShareButton(
            label: 'WhatsApp',
            color: whatsappGreen,
            onTap: onWhatsApp,
            child: Image.asset(
              'assets/whatsapp.png',
              width: 30,
              height: 30,
              filterQuality: FilterQuality.medium,
            ),
          ),
          _ShareButton(
            label: 'Messenger',
            color: messengerBlue,
            onTap: onMessenger,
            child: Image.asset(
              'assets/messenger.png',
              width: 30,
              height: 30,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.label,
    required this.color,
    required this.onTap,
    required this.child,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            alignment: Alignment.center,
            child: child,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
