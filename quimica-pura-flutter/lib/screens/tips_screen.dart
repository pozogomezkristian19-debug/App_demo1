import 'package:flutter/material.dart';
import '../data/topics.dart';
import '../services/localization.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr('tipsTitle'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Lo que distingue una respuesta correcta de una «casi»: método, unidades y comprobaciones rápidas.',
        ),
        const SizedBox(height: 12),
        for (final tip in generalTips)
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
    );
  }
}
