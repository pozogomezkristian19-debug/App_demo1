// Pantalla de bloqueo (ronda fix8, analítica): si el creador baneó
// la cuenta (campo 'banned' en su documento de Firestore), la app
// arranca mostrando esto en vez de la app normal. Solo un botón:
// escribir a Soporte por WhatsApp. Los textos salen de tr() (las
// claves bannedTitle/bannedBody/bannedSupport las añade otro agente
// a localization.dart; si aún no existen, tr() devuelve la clave).
//
// Diseño Quemia (tema claro siempre, aunque la app esté en oscuro):
// fondo blanco, tarjeta grande redondeada con sombra suave, teal
// #00C2A8, tipografía limpia. Nada rústico ni amontonado.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/localization.dart';
import 'brand_logo.dart';

class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key});

  static const _kSupportUrl = 'https://wa.me/5356519431';

  Future<void> _openSupport() async {
    final uri = Uri.parse(_kSupportUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colores fijos del sistema claro (no del tema): la pantalla se
    // ve igual en claro y en oscuro.
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: BrandColors.teal.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: BrandColors.teal.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.block,
                        size: 44,
                        color: BrandColors.teal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr('bannedTitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: BrandColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('bannedBody'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: BrandColors.ink,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: BrandColors.teal,
                      foregroundColor: Colors.white,
                      shadowColor: BrandColors.tealDark,
                      // Sombra más marcada: el botón flota (antes
                      // plano sobre la tarjeta). El teal fijo se
                      // conserva: la pantalla es siempre clara.
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: _openSupport,
                    icon: const Icon(Icons.chat, size: 20),
                    label: Text(tr('bannedSupport')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
