// Mis estadísticas (v5, rediseño claro 2026-11-10): racha, niveles,
// mejores puntuaciones, temas más débiles, totales y logros. También
// exporta el progreso y el interruptor de sonido y vibración.
//
// La exportación no usa ningún plugin: genera un texto con todo el
// progreso y lo pone en el portapapeles (y, si se quiere, lo comparte
// por WhatsApp). Así no se pierde al cambiar de teléfono.

import '../widgets/shadows.dart';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../widgets/brand_logo.dart';
import '../widgets/lives_chip.dart';
import '../widgets/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/i18n/content_i18n.dart';
import '../services/achievements.dart';
import '../services/accent.dart';

import '../services/localization.dart';
import '../services/progress.dart';
import '../services/user_prefs.dart';

/// Tokens claros (paleta propia de Melli-Qui, sin verde Duolingo):
/// teal #00C2A8 como color principal, teal oscuro #00A18D.
const _ink = Color(0xFF3C3C3C);
const _inkSoft = Color(0xFF6E6E6E);
const _card = Color(0xFFF7F7F7);
const _border = Color(0xFFE8E8E8);
const _edgeGray = Color(0xFFDDDDDD);

/// Colores de esta pantalla según el tema (igual patrón que
/// _CuentaColors en account_screen.dart).
///
/// BUG 12: toda la pantalla usaba colores claros fijos (fondo blanco,
/// tarjetas #F7F7F7, texto #3C3C3C). En modo oscuro quedaban
/// rectángulos blancos/claros sobre el fondo verde oscuro, y las
/// tarjetas de logros bloqueadas eran gris sobre gris. En claro los
/// valores son los mismos de antes; en oscuro solo verdes/menta
/// (fondo #0A1F1A, superficie #122B24, sin violeta/azul/ámbar).
class _StatsColors {
  const _StatsColors({
    required this.bg,
    required this.card,
    required this.surface,
    required this.ink,
    required this.inkSoft,
    required this.border,
    required this.edgeGray,
    required this.accent,
    required this.accentDark,
    required this.unlockedBg,
    required this.unlockedIcon,
    required this.flameBg,
    required this.flameIcon,
  });

  factory _StatsColors.of(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      // Superficies y tintes según el acento (fix4, punto 2): con
      // Violeta el oscuro es violeta, no verde (los valores son los
      // mismos que _darkTheme en main.dart).
      final violet = AppAccent.isViolet;
      return _StatsColors(
        bg: AppAccent.darkBackground,
        card: AppAccent.darkCard,
        surface: AppAccent.darkCard,
        ink: violet ? const Color(0xFFEDE9F7) : const Color(0xFFE6F4EE),
        inkSoft: AppAccent.darkInkSoft,
        border: AppAccent.darkBorder,
        edgeGray: AppAccent.darkBorder,
        accent: violet ? BrandColors.violetLight : BrandColors.mintLight,
        accentDark: violet ? BrandColors.violet : BrandColors.mint,
        // Logro desbloqueado: tinte del acento, nunca ámbar en oscuro.
        unlockedBg: violet ? const Color(0x268B5CF6) : const Color(0x2614B8A6),
        unlockedIcon: violet ? BrandColors.violetLight : BrandColors.mintLight,
        flameBg: violet ? const Color(0x268B5CF6) : const Color(0x2614B8A6),
        flameIcon: violet ? BrandColors.violetLight : BrandColors.mintLight,
      );
    }
    return _StatsColors(
      bg: Colors.white,
      card: _card,
      surface: Colors.white,
      ink: _ink,
      inkSoft: _inkSoft,
      border: _border,
      edgeGray: _edgeGray,
      accent: AppAccent.primary,
      accentDark: AppAccent.primaryDark,
      // Igual que antes: Colors.amber con alpha 0.15 y amber.shade800.
      unlockedBg: Color(0x26FFC107),
      unlockedIcon: Color(0xFFFF8F00),
      flameBg: Color(0x26FFC107),
      flameIcon: Colors.deepOrange,
    );
  }

  final Color bg;
  final Color card;
  final Color surface;
  final Color ink;
  final Color inkSoft;
  final Color border;
  final Color edgeGray;
  final Color accent;
  final Color accentDark;
  final Color unlockedBg;
  final Color unlockedIcon;
  final Color flameBg;
  final Color flameIcon;
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.trackTopics});
  final List<String> trackTopics;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /// Niveles desbloqueados de la otra pista (para su contador de
  /// pasados): el contador usa el desbloqueo, no la nota (A2).
  Map<String, int>? _otherLevels;

  /// La tarjeta de resumen que se convierte en imagen al compartir.
  final _shareKey = GlobalKey();

  /// Scroll de la lista: hace falta para el arreglo del BUG 7.
  final _scrollController = ScrollController();

  /// Evita dos capturas a la vez si se toca el botón dos veces.
  bool _isSharing = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Renderiza la tarjeta de progreso a PNG y la comparte con la hoja
  /// del sistema (WhatsApp, galería, correo...). La imagen se genera
  /// en memoria y no se guarda ningún archivo.
  ///
  /// BUG 7 — causa raíz: la tarjeta a capturar está arriba del todo
  /// de la lista y el botón "Compartir progreso" está abajo. Al bajar
  /// hasta el botón, ListView ya ha desmontado la tarjeta (queda fuera
  /// del cacheExtent de 250 px), así que `_shareKey.currentContext`
  /// es null y el `!` del código anterior lanzaba siempre en el
  /// teléfono real: de ahí el toast "No se pudo crear la imagen".
  /// El arreglo es volver arriba y esperar a que la tarjeta esté
  /// montada y pintada ANTES de capturar, y comprobarlo todo (contexto
  /// no nulo, boundary no nulo, tamaño no vacío, bytes no nulos) en
  /// vez de usar `!`. El pixelRatio se limita a 2.0 (imagen sobrada
  /// para compartir y menos memoria que 3.0).
  Future<void> _shareImage() async {
    if (_isSharing) return;
    _isSharing = true;
    try {
      // 1. Llevar la tarjeta a pantalla: si estaba desmontada, el
      // scroll la vuelve a montar; si ya estaba arriba, no se mueve.
      if (_scrollController.hasClients && _scrollController.offset > 0) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      // 2. Esperar a que el frame con la tarjeta montada se pinte.
      // Dos intentos: si tras el primer frame sigue sin estar lista,
      // se espera un poco más en vez de fallar de inmediato.
      RenderRepaintBoundary? boundary;
      for (var attempt = 0; attempt < 2; attempt++) {
        await WidgetsBinding.instance.endOfFrame;
        await Future.delayed(const Duration(milliseconds: 120));
        final context = _shareKey.currentContext;
        final object = context?.findRenderObject();
        if (object is RenderRepaintBoundary && object.size != Size.zero) {
          boundary = object;
          break;
        }
      }
      if (boundary == null) {
        throw StateError('summary card not mounted');
      }
      final pixelRatio =
          MediaQuery.of(context).devicePixelRatio.clamp(1.0, 2.0);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('could not encode image');
      }
      final bytes = byteData.buffer.asUint8List();
      if (bytes.isEmpty) {
        throw StateError('empty image');
      }
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(bytes,
              name: 'quemia-progreso.png', mimeType: 'image/png')
        ],
        text: tr('shareProgress'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('shareImageFail'))),
      );
    } finally {
      _isSharing = false;
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
      _otherLevels = snap.levels;
    });
  }

  /// Niveles pasados de una pista (auditoría A2, fix5 ronda #5):
  /// "pasado" es LO MISMO que en el camino de Niveles — el nivel
  /// siguiente está desbloqueado (`unlockedLevel > level`). La
  /// mejor nota guardada es la nota PONDERADA y ya no es la puerta:
  /// un 4/5 fallando la difícil guarda 76 % y antes no se contaba,
  /// aunque el camino lo marcaba pasado (y el contador "Superado:
  /// X / 55" de Niveles no coincidía con este). `unlocked` es tema
  /// → nivel más alto desbloqueado (1 si el tema nunca se tocó).
  int _passedLevels(Map<String, int> unlocked, List<String> topics) {
    var passed = 0;
    for (final topic in topics) {
      final count = ProgressService.levelCountForTopic(topic);
      final unlockedLevel = unlocked[topic] ?? 1;
      for (var level = 1; level <= count; level++) {
        if (unlockedLevel > level) passed++;
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

  /// Etiqueta legible de una clave de puntuación guardada, solo para
  /// la exportación (fix3): las claves internas ('level:bach-…:2',
  /// 'mixto', 'timed') nunca se muestran al usuario tal cual. Las
  /// claves guardadas no cambian; solo se traduce lo que se exporta.
  String _prettyScoreKey(String key) {
    final parts = key.split(':');
    if (parts.length == 3 && parts[0] == 'level') {
      final level = int.tryParse(parts[2]) ?? 0;
      return '${localizedTopicTitle(parts[1])} · ${tr('levelWord')} $level';
    }
    if (key == 'mixto') return tr('mixedTitle');
    if (key == 'timed') return tr('timedTitle');
    return humanizeTopicId(key);
  }

  String _exportText() {
    final p = ProgressService.instance;
    final data = <String, dynamic>{
      'app': 'Quemia',
      'version': ProgressService.track == ProgressService.trackBach
          ? tr('trackBach')
          : tr('trackUni'),
      'racha_actual': p.streakNow,
      'racha_mejor': p.streakBest,
      'niveles_pasados_uni': _passedLevels(
          ProgressService.track == ProgressService.trackUni
              ? p.unlockedLevels
              : (_otherLevels ?? {}),
          _topicsOf(ProgressService.trackUni)),
      'niveles_pasados_bach': _passedLevels(
          ProgressService.track == ProgressService.trackBach
              ? p.unlockedLevels
              : (_otherLevels ?? {}),
          _topicsOf(ProgressService.trackBach)),
      'mejores_puntuaciones': {
        for (final e in p.bestScores.entries) _prettyScoreKey(e.key): e.value,
      },
      'respuestas_correctas': p.totalCorrect,
      'respuestas_totales': p.totalAnswered,
      'errores_pendientes': p.failedCount,
      'dias_practica': p.practiceDays.toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> _export({bool viaWhatsApp = false}) async {
    final text = _exportText();
    if (viaWhatsApp) {
      final uri = Uri.parse(
          'https://wa.me/?text=${Uri.encodeComponent('Mi progreso en Quemia:\n$text')}');
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
    final c = _StatsColors.of(context);
    final p = ProgressService.instance;
    final topics = widget.trackTopics;
    final passed = _passedLevels(p.unlockedLevels, topics);
    final total = _totalLevels(topics);
    final weakest = p.weakestTopics(topics).take(3).toList();
    final otherTrack = ProgressService.track == ProgressService.trackUni
        ? ProgressService.trackBach
        : ProgressService.trackUni;
    final otherTopics = _topicsOf(otherTrack);
    final otherPassed = _otherLevels == null
        ? null
        : _passedLevels(_otherLevels!, otherTopics);
    final otherTotal = _totalLevels(otherTopics);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(tr('statsTitle')),
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: c.ink,
        ),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          // Tarjeta de resumen: es la que se comparte como imagen (v6).
          RepaintBoundary(
            key: _shareKey,
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.border),
                boxShadow: [
                  standardShadow(const Color(0xFF6B7280)),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quemia · ${tr('statsTitle')}',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: c.accent)),
                  const SizedBox(height: 8),
                  Text('${tr('streakWord')}: ${p.streakNow}',
                      style: TextStyle(color: c.ink, height: 1.5)),
                  Text('${tr('levelsTitle')}: $passed / $total',
                      style: TextStyle(color: c.ink, height: 1.5)),
                  Text('${tr('pointsTitle')}: ${p.points}',
                      style: TextStyle(color: c.ink, height: 1.5)),
                  Row(
                    children: [
                      Text('${tr('livesTitle')}: ',
                          style: TextStyle(color: c.ink, height: 1.5)),
                      LivesChip(
                          lives: p.livesLeft,
                          showMax: true,
                          pulse: false,
                          compact: true),
                    ],
                  ),
                  Text(
                      'Respuestas correctas: ${p.totalCorrect} de ${p.totalAnswered}',
                      style: TextStyle(color: c.ink, height: 1.5)),
                  Text('Errores por repasar: ${p.failedCount}',
                      style: TextStyle(color: c.ink, height: 1.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Racha.
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border),
              boxShadow: [
                standardShadow(const Color(0xFF6B7280)),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: c.flameBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: LucideIcon(LucideIcons.flame,
                      size: 32, color: c.flameIcon, filled: true, threeD: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fix3, punto 2 (segunda pasada): esta tarjeta
                      // ya NO repite la racha actual — ya está en la
                      // tarjeta de resumen de arriba ("Racha: N").
                      // Solo muestra lo que el resumen no tiene: la
                      // mejor racha y la meta del día.
                      Text(
                        tr('streakWord'),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: c.accent),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mejor racha: ${p.streakBest} días',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: c.ink),
                      ),
                      Text(
                        'Meta del día: ${p.dailyGoalDone ? 'hecha' : 'pasa 1 nivel hoy'}',
                        style: TextStyle(color: c.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Detalle: SOLO lo que el resumen de arriba no tiene.
          // Fix3, punto 2 (segunda pasada): antes esta lista repetía
          // Respuestas correctas, Respuestas totales, Errores por
          // repasar, Puntos y Vidas — cifras que ya están en la
          // tarjeta de resumen. Quedan niveles por versión, el mejor
          // del examen mixto y días practicando.
          Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
              boxShadow: [
                standardShadow(const Color(0xFF6B7280)),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _statRow(
                    'Niveles pasados (${ProgressService.track == ProgressService.trackUni ? tr('trackUni') : tr('trackBach')})',
                    '$passed / $total',
                    c.ink),
                _statRow(
                    'Niveles pasados (${otherTrack == ProgressService.trackUni ? tr('trackUni') : tr('trackBach')})',
                    otherPassed == null ? '…' : '$otherPassed / $otherTotal',
                    c.ink),
                _statRow(
                    'Examen mixto (mejor)', '${p.bestScore('mixto')}%', c.ink),
                _statRow('Días practicando', '${p.practiceDays.length}', c.ink),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Temas más débiles',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: c.ink)),
          const SizedBox(height: 8),
          if (weakest.isEmpty)
            Text('Aún no hay datos: contesta algunas preguntas.',
                style: TextStyle(color: c.inkSoft))
          else
            for (final t in weakest)
              Card(
                color: c.card,
                elevation: 2,
                shadowColor: c.accent.withValues(alpha: 0.22),
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text(localizedTopicName(t),
                      style: TextStyle(color: c.ink)),
                  trailing: Text(
                    p.accuracy(t) == null
                        ? 'sin intentos'
                        : '${((p.accuracy(t) ?? 0) * 100).round()}%',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: c.accentDark),
                  ),
                ),
              ),
          const SizedBox(height: 16),
          // Logros.
          Text(tr('achievementsWord'),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: c.ink)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              // BUG 12: el alto era 168 pero el contenido mide ~135-140
              // incluso en un teléfono estrecho de 320 px, así que cada
              // tarjeta tenía ~30 px de gris vacío abajo. Al hacer scroll
              // solo se veía esa franja vacía de la fila de arriba: los
              // dos rectángulos grises vacíos de la captura. Con 152 y
              // el contenido centrado verticalmente ya no queda banda
              // vacía abajo (el peor caso — título a 2 líneas + cuerpo
              // a 3 líneas + paddings — mide ~146).
              mainAxisExtent: 152,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: allAchievements.length,
            itemBuilder: (context, i) {
              final a = allAchievements[i];
              final unlocked = achievementUnlocked(a.id, p, topics);
              return Card(
                color: unlocked ? c.unlockedBg : c.card,
                elevation: 2,
                shadowColor: c.accent.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LucideIcon(a.icon,
                          color: unlocked ? c.unlockedIcon : c.inkSoft),
                      const SizedBox(height: 6),
                      Text(a.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: unlocked ? c.ink : c.inkSoft,
                          )),
                      const SizedBox(height: 2),
                      Text(a.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.inkSoft,
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
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
              boxShadow: [
                standardShadow(const Color(0xFF6B7280)),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                title: Text('Sonido y vibración al contestar',
                    style: TextStyle(color: c.ink)),
                value: UserPrefs.soundOn,
                activeThumbColor: AppAccent.primary,
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
            background: AppAccent.primary,
            edge: AppAccent.primaryDark,
            foreground: Colors.white,
            onPressed: _shareImage,
          ),
          const SizedBox(height: 12),
          _PillButton(
            icon: LucideIcons.copy,
            label: 'Exportar mi progreso (copiar)',
            background: c.card,
            edge: c.edgeGray,
            foreground: c.ink,
            onPressed: () => _export(),
          ),
          const SizedBox(height: 12),
          _PillButton(
            icon: LucideIcons.share2,
            label: 'Compartir progreso por WhatsApp',
            background: c.surface,
            edge: c.edgeGray,
            foreground: c.accentDark,
            border: c.accent,
            onPressed: () => _export(viaWhatsApp: true),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color ink) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: ink))),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: ink)),
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
        border: border == null ? null : Border.all(color: border!, width: 2),
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
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
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
