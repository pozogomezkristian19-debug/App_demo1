// Mis estadísticas (v5): racha, niveles, mejores puntuaciones, temas
// más débiles, totales y logros. También exporta el progreso y el
// interruptor de sonido y vibración.
//
// La exportación no usa ningún plugin: genera un texto con todo el
// progreso y lo pone en el portapapeles (y, si se quiere, lo comparte
// por WhatsApp). Así no se pierde al cambiar de teléfono.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/questions.dart';
import '../services/achievements.dart';
import '../services/localization.dart';
import '../services/progress.dart';
import '../services/user_prefs.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.trackTopics});
  final List<String> trackTopics;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, int>? _otherBest;

  @override
  void initState() {
    super.initState();
    _loadOtherTrack();
  }

  Future<void> _loadOtherTrack() async {
    final other = ProgressService.track == ProgressService.trackUni
        ? ProgressService.trackBach
        : ProgressService.trackUni;
    final snap = await ProgressService.trackSnapshot(other);
    if (!mounted) return;
    setState(() {
      _otherBest = snap.best;
    });
  }

  int _passedLevels(Map<String, int> best, List<String> topics) {
    var passed = 0;
    for (final topic in topics) {
      final count = ProgressService.levelCountForTopic(topic);
      for (var level = 1; level <= count; level++) {
        if ((best['level:$topic:$level'] ?? 0) >= 80) passed++;
      }
    }
    return passed;
  }

  int _totalLevels(List<String> topics) {
    var total = 0;
    for (final topic in topics) {
      total += ProgressService.levelCountForTopic(topic);
    }
    return total;
  }

  List<String> _topicsOf(String track) {
    if (track == ProgressService.trackBach) {
      return const [
        'bach-estequiometria',
        'bach-disoluciones',
        'bach-gases',
        'bach-acido-base',
      ];
    }
    return const [
      'estequiometria',
      'gases',
      'disoluciones',
      'acido-base',
      'equilibrio',
      'termo-cinetica',
      'tabla',
      'enlace',
      'organica',
      'laboratorio',
    ];
  }

  String _exportText() {
    final p = ProgressService.instance;
    final data = <String, dynamic>{
      'app': 'Melli-Qui',
      'version': ProgressService.track,
      'racha_actual': p.streakNow,
      'racha_mejor': p.streakBest,
      'niveles_pasados_uni': _passedLevels(
          ProgressService.track == ProgressService.trackUni
              ? p.bestScores
              : (_otherBest ?? {}),
          _topicsOf(ProgressService.trackUni)),
      'niveles_pasados_bach': _passedLevels(
          ProgressService.track == ProgressService.trackBach
              ? p.bestScores
              : (_otherBest ?? {}),
          _topicsOf(ProgressService.trackBach)),
      'mejores_puntuaciones': p.bestScores,
      'respuestas_correctas': p.totalCorrect,
      'respuestas_totales': p.totalAnswered,
      'errores_pendientes': p.failedCount,
      'temas_dominados': p.masteredTopics.toList(),
      'dias_practica': p.practiceDays.toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> _export({bool viaWhatsApp = false}) async {
    final text = _exportText();
    if (viaWhatsApp) {
      final uri = Uri.parse(
          'https://wa.me/?text=${Uri.encodeComponent('Mi progreso en Melli-Qui:\n$text')}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progreso copiado al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final topics = widget.trackTopics;
    final passed = _passedLevels(p.bestScores, topics);
    final total = _totalLevels(topics);
    final weakest = p.weakestTopics(topics).take(3).toList();
    final otherTrack = ProgressService.track == ProgressService.trackUni
        ? ProgressService.trackBach
        : ProgressService.trackUni;
    final otherTopics = _topicsOf(otherTrack);
    final otherPassed = _otherBest == null
        ? null
        : _passedLevels(_otherBest!, otherTopics);
    final otherTotal = _totalLevels(otherTopics);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('statsTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Racha.
          Card(
            color: scheme.primary.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department,
                      size: 40, color: Colors.deepOrange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tr('streakWord')}: ${p.streakNow} ${p.streakNow == 1 ? 'día' : 'días'}',
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                        Text('Mejor racha: ${p.streakBest} días'),
                        Text(
                          'Meta del día: ${p.dailyGoalDone ? 'hecha' : 'pasa 1 nivel hoy'}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Niveles por versión.
          _statRow('Niveles pasados (${ProgressService.track == ProgressService.trackUni ? tr('trackUni') : tr('trackBach')})',
              '$passed / $total'),
          _statRow(
              'Niveles pasados (${otherTrack == ProgressService.trackUni ? tr('trackUni') : tr('trackBach')})',
              otherPassed == null ? '…' : '$otherPassed / $otherTotal'),
          _statRow('Examen mixto (mejor)', '${p.bestScore('mixto')}%'),
          _statRow('Respuestas correctas', '${p.totalCorrect}'),
          _statRow('Respuestas totales', '${p.totalAnswered}'),
          _statRow('Errores por repasar', '${p.failedCount}'),
          _statRow('Temas dominados', '${p.masteredTopics.length}'),
          _statRow('Días practicando', '${p.practiceDays.length}'),
          const SizedBox(height: 12),
          const Text('Temas más débiles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (weakest.isEmpty)
            const Text('Aún no hay datos: contesta algunas preguntas.')
          else
            for (final t in weakest)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(topicNames[t] ?? t),
                  trailing: Text(
                    p.accuracy(t) == null
                        ? 'sin intentos'
                        : '${((p.accuracy(t) ?? 0) * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          const SizedBox(height: 16),
          // Logros.
          Text(tr('achievementsWord'),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: allAchievements.length,
            itemBuilder: (context, i) {
              final a = allAchievements[i];
              final unlocked = achievementUnlocked(a.id, p, topics);
              return Card(
                color: unlocked
                    ? Colors.amber.withValues(alpha: 0.2)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(a.icon,
                          color: unlocked
                              ? Colors.amber.shade800
                              : scheme.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(height: 4),
                      Text(a.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: unlocked
                                ? null
                                : scheme.onSurface.withValues(alpha: 0.5),
                          )),
                      Text(a.body,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          )),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Ajustes rápidos.
          SwitchListTile(
            title: const Text('Sonido y vibración al contestar'),
            value: UserPrefs.soundOn,
            onChanged: (v) async {
              await UserPrefs.saveSoundOn(v);
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _export(),
            icon: const Icon(Icons.copy),
            label: const Text('Exportar mi progreso (copiar)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _export(viaWhatsApp: true),
            icon: const Icon(Icons.share),
            label: const Text('Compartir progreso por WhatsApp'),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
