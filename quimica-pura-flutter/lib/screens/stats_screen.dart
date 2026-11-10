// Mis estadísticas (v5, rediseño claro 2026-11-10): racha, niveles,
// mejores puntuaciones, temas más débiles, totales y logros. También
// exporta el progreso y el interruptor de sonido y vibración.
//
// La exportación no usa ningún plugin: genera un texto con todo el
// progreso y lo pone en el portapapeles (y, si se quiere, lo comparte
// por WhatsApp). Así no se pierde al cambiar de teléfono.

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../widgets/lives_chip.dart';
import '../widgets/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/i18n/content_i18n.dart';
import '../services/achievements.dart';
import '../services/localization.dart';
import '../services/progress.dart';
import '../services/user_prefs.dart';

/// Tokens claros (paleta propia de Melli-Qui, sin verde Duolingo):
/// teal #00C2A8 como color principal, teal oscuro #00A18D.
const _teal = Color(0xFF00C2A8);
const _tealDark = Color(0xFF00A18D);
const _ink = Color(0xFF3C3C3C);
const _inkSoft = Color(0xFF6E6E6E);
const _card = Color(0xFFF7F7F7);
const _border = Color(0xFFE8E8E8);
const _edgeGray = Color(0xFFDDDDDD);

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.trackTopics});
  final List<String> trackTopics;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, int>? _otherBest;

  /// La tarjeta de resumen que se convierte en imagen al compartir.
  final _shareKey = GlobalKey();

  /// Renderiza la tarjeta de progreso a PNG y la comparte con la hoja
  /// del sistema (WhatsApp, galería, correo...). La imagen se genera
  /// en memoria y no se guarda ningún archivo.
  Future<void> _shareImage() async {
    try {
      final boundary = _shareKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(bytes,
              name: 'melli-qui-progreso.png', mimeType: 'image/png')
        ],
        text: tr('shareProgress'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('shareImageFail'))),
      );
    }
  }

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
        if ((best['level:$topic:$level'] ?? 0) >= 81) passed++;
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(tr('statsTitle')),
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _ink,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tarjeta de resumen: es la que se comparte como imagen (v6).
          RepaintBoundary(
            key: _shareKey,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Melli-Qui · ${tr('statsTitle')}',
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: _teal)),
                  const SizedBox(height: 8),
                  Text('${tr('streakWord')}: ${p.streakNow}',
                      style: const TextStyle(color: _ink, height: 1.5)),
                  Text('${tr('levelsTitle')}: $passed / $total',
                      style: const TextStyle(color: _ink, height: 1.5)),
                  Text('${tr('pointsTitle')}: ${p.points}',
                      style: const TextStyle(color: _ink, height: 1.5)),
                  Row(
                    children: [
                      Text('${tr('livesTitle')}: ',
                          style:
                              const TextStyle(color: _ink, height: 1.5)),
                      LivesChip(
                          lives: p.livesLeft, showMax: true, pulse: false),
                    ],
                  ),
                  Text(
                      'Respuestas correctas: ${p.totalCorrect} de ${p.totalAnswered}',
                      style: const TextStyle(color: _ink, height: 1.5)),
                  Text('Errores por repasar: ${p.failedCount}',
                      style: const TextStyle(color: _ink, height: 1.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Racha.
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const LucideIcon(LucideIcons.flame,
                      size: 32, color: Colors.deepOrange, filled: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tr('streakWord')}: ${p.streakNow} ${p.streakNow == 1 ? 'día' : 'días'}',
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: _ink),
                      ),
                      Text('Mejor racha: ${p.streakBest} días',
                          style: const TextStyle(color: _inkSoft)),
                      Text(
                        'Meta del día: ${p.dailyGoalDone ? 'hecha' : 'pasa 1 nivel hoy'}',
                        style: const TextStyle(color: _inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Niveles por versión y totales.
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _statRow(
                    'Niveles pasados (${ProgressService.track == ProgressService.trackUni ? tr('trackUni') : tr('trackBach')})',
                    '$passed / $total'),
                _statRow(
                    'Niveles pasados (${otherTrack == ProgressService.trackUni ? tr('trackUni') : tr('trackBach')})',
                    otherPassed == null ? '…' : '$otherPassed / $otherTotal'),
                _statRow('Examen mixto (mejor)', '${p.bestScore('mixto')}%'),
                _statRow('Respuestas correctas', '${p.totalCorrect}'),
                _statRow('Respuestas totales', '${p.totalAnswered}'),
                _statRow('Errores por repasar', '${p.failedCount}'),
                _statRow(tr('pointsTitle'), '${p.points}'),
                _statWidgetRow(
                    '${tr('livesTitle')} (hoy)',
                    LivesChip(
                        lives: p.livesLeft, showMax: true, pulse: false)),
                _statRow('Temas dominados', '${p.masteredTopics.length}'),
                _statRow('Días practicando', '${p.practiceDays.length}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Temas más débiles',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _ink)),
          const SizedBox(height: 8),
          if (weakest.isEmpty)
            const Text(
                'Aún no hay datos: contesta algunas preguntas.',
                style: TextStyle(color: _inkSoft))
          else
            for (final t in weakest)
              Card(
                color: _card,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text(localizedTopicName(t),
                      style: const TextStyle(color: _ink)),
                  trailing: Text(
                    p.accuracy(t) == null
                        ? 'sin intentos'
                        : '${((p.accuracy(t) ?? 0) * 100).round()}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: _tealDark),
                  ),
                ),
              ),
          const SizedBox(height: 16),
          // Logros.
          Text(tr('achievementsWord'),
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _ink)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              // Alto fijo con margen de sobra (nunca se corta por abajo):
              // el contenido más largo (icono 24 + título a 2 líneas +
              // cuerpo a 3 líneas + paddings) mide ~135 incluso en un
              // teléfono estrecho de 320 px; 168 deja ~30 px de aire.
              mainAxisExtent: 168,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: allAchievements.length,
            itemBuilder: (context, i) {
              final a = allAchievements[i];
              final unlocked = achievementUnlocked(a.id, p, topics);
              return Card(
                color: unlocked
                    ? Colors.amber.withValues(alpha: 0.15)
                    : _card,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LucideIcon(a.icon,
                          color: unlocked
                              ? Colors.amber.shade800
                              : Colors.grey),
                      const SizedBox(height: 6),
                      Text(a.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: unlocked ? _ink : _inkSoft,
                          )),
                      const SizedBox(height: 2),
                      Text(a.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _inkSoft,
                          )),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Ajustes rápidos.
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
              title: const Text('Sonido y vibración al contestar',
                  style: TextStyle(color: _ink)),
              value: UserPrefs.soundOn,
              activeThumbColor: _teal,
              onChanged: (v) async {
                await UserPrefs.saveSoundOn(v);
                setState(() {});
              },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _PillButton(
            icon: LucideIcons.image,
            label: tr('shareProgress'),
            background: _teal,
            edge: _tealDark,
            foreground: Colors.white,
            onPressed: _shareImage,
          ),
          const SizedBox(height: 12),
          _PillButton(
            icon: LucideIcons.copy,
            label: 'Exportar mi progreso (copiar)',
            background: _card,
            edge: _edgeGray,
            foreground: _ink,
            onPressed: () => _export(),
          ),
          const SizedBox(height: 12),
          _PillButton(
            icon: LucideIcons.share2,
            label: 'Compartir progreso por WhatsApp',
            background: Colors.white,
            edge: _edgeGray,
            foreground: _tealDark,
            border: _teal,
            onPressed: () => _export(viaWhatsApp: true),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: _ink))),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: _ink)),
        ],
      ),
    );
  }

  /// Como _statRow, pero con un valor que es un widget (el chip de
  /// vidas: corazón + número, nunca la fila de 5 corazones).
  Widget _statWidgetRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: _ink))),
          value,
        ],
      ),
    );
  }
}

/// Botón píldora estilo Duolingo con borde inferior más oscuro
/// (efecto 3D): el color [edge] se ve como una franja de 4 px bajo
/// el botón. Sin verde Duolingo: el primario es el teal de Melli-Qui.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.edge,
    required this.foreground,
    required this.onPressed,
    this.border,
  });

  final LucideIconData icon;
  final String label;
  final Color background;
  final Color edge;
  final Color foreground;
  final Color? border;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
        border:
            border == null ? null : Border.all(color: border!, width: 2),
        boxShadow: [
          BoxShadow(
            color: edge,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onPressed,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LucideIcon(icon, size: 20, color: foreground),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: foreground,
                    ),
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
