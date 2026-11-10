// Botón flotante de WhatsApp ("Soporte") de Melli-Qui.
//
// Es un botón a mano (Container + InkWell), SIN FloatingActionButton:
// el FAB dibujaba un borde negro grueso alrededor de la píldora
// verde, y este botón no tiene borde de ningún tipo: solo el verde
// oficial de WhatsApp (#25D366), el logo y una sombra suave.
//
// Lleva directo al chat del creador (wa.me/5356519431); la lógica de
// apertura vive en main.dart y se pasa como [onPressed].

import 'package:flutter/material.dart';

import '../services/localization.dart';

/// Verde oficial de WhatsApp.
const kWhatsAppGreen = Color(0xFF25D366);

class SupportButton extends StatelessWidget {
  const SupportButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr('writeWhatsApp'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: kWhatsAppGreen,
              borderRadius: BorderRadius.all(Radius.circular(999)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Image(
                  image: AssetImage('assets/whatsapp.png'),
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  tr('supportWord'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
