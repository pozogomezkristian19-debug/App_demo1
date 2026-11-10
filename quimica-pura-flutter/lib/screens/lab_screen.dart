// Laboratorio (v5): su propia pantalla en el menú. Muestra el tema de
// laboratorio completo (seguridad, material, técnicas) y los botones del
// cuestionario y del simulador.

import 'package:flutter/material.dart';

import '../services/localization.dart';
import 'lab_quiz_screen.dart';
import 'lab_sim_screen.dart';
import 'topic_detail_screen.dart';

class LabScreen extends StatelessWidget {
  const LabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topic = findTopic('laboratorio');
    return Scaffold(
      appBar: AppBar(title: Text(tr('menuLab'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const LabQuizPage()),
                      );
                    },
                    icon: const Icon(Icons.quiz_outlined),
                    label: Text(tr('labQuizButton')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const LabSimScreen()),
                      );
                    },
                    icon: const Icon(Icons.science_outlined),
                    label: Text(tr('labSimTitle')),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: topic == null
                ? const Center(child: Text('Sin contenido'))
                : TopicDetailView(topic: topic),
          ),
        ],
      ),
    );
  }
}
