import 'package:flutter/material.dart';
import '../data/i18n/content_i18n.dart';
import '../services/localization.dart';

/// Pantalla "Tips de examen", como el resto de pantallas de detalle
/// (Constantes, tema, Ramas): Scaffold con AppBar (título y flecha
/// para volver) y cuerpo con la introducción y las tarjetas.
///
/// Antes era un ListView pelado, sin Scaffold ni Material, y eso es
/// justo lo que rompía el texto: sin Material, un Text hereda el
/// DefaultTextStyle de MaterialApp, que es a propósito un estilo feo
/// de aviso — rojo, monoespaciada, 48 px, subrayado doble amarillo —
/// y así se pintaban el título y la introducción en el teléfono,
/// con el título además pegado a la barra de estado y sin forma de
/// volver. El Scaffold pone el Material (fondo y estilo del tema) y
/// la AppBar; y la introducción lleva además el estilo explícito
/// bodyMedium del tema, así que es siempre cuerpo normal de la app,
/// en claro y en oscuro.
class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('tipsTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Lo que distingue una respuesta correcta de una «casi»: método, unidades y comprobaciones rápidas.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          for (final tip in localizedGeneralTips())
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tip.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(tip.body),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Errores que cuestan puntos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('• Usar °C en PV = nRT en lugar de kelvin.\n'
                      '• Comparar moles a secas para el reactivo limitante, sin dividir entre el coeficiente.\n'
                      '• Confundir volumen de disolución con volumen de disolvente en molaridad.\n'
                      '• Incluir sólidos puros en Kc.\n'
                      '• Redondear en pasos intermedios.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
