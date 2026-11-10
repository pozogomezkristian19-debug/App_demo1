// Las mascotas de Melli-Qui: las dos gemelas, cada una con su avatar
// ILUSTRADO (imagen generada en estilo Duolingo: muñecas suaves, pelo
// castaño con coletas y lacitos, ojos grandes, colorete), recortado en
// círculo para que se vea limpio como avatar redondo.
// Brenda = lacito/vestido VIOLETA (#8B5CF6), Britany = lacito/
// vestido AZUL (#3B82F6). Asignación fija, siempre igual.
// Sin dibujo por código ni emojis: los avatares son las imágenes
// assets/brenda.png y assets/britany.png (fondo blanco sólido,
// por eso se recortan con ClipOval y llevan un aro del color de
// cada gemela).
//
// - TwinAvatarA / TwinAvatarB: la cara de cada gemela, para usar en
//   preguntas, racha, repaso y celebraciones.
// - MascotBubble: avatar + bocadillo con un mensaje corto.
// - mascotCheerKey / mascotPraiseKey / mascotConsoleKey: eligen por
//   turnos una de las 3 frases de ánimo, celebración o consuelo
//   (claves en localization.dart, x6 idiomas), para que no sea
//   siempre la misma.
//
// En cada pregunta aparece una gemela (alternando por turnos) y en
// los demás momentos (pregunta del día, racha, repaso de errores,
// celebración de nivel) aparece la otra.

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/user_prefs.dart';
import 'brand_logo.dart';

/// Expresión de la mascota: contenta (sonrisa grande) o suave
/// (sonrisa pequeña, de consuelo).
///
/// Se conserva en la API porque otros archivos la pasan; la imagen
/// ilustrada es la misma en los dos estados.
enum TwinMood { happy, soft }

/// Frases de ánimo (antes de responder), por turnos (3 variantes).
String mascotCheerKey(int i) => 'mascotCheer${i % 3}';

/// Frases de celebración (al acertar), por turnos (3 variantes).
String mascotPraiseKey(int i) => 'mascotPraise${i % 3}';

/// Frases de consuelo (al fallar), por turnos (3 variantes).
String mascotConsoleKey(int i) => 'mascotConsole${i % 3}';

/// Nombre de cada gemela: Brenda = lacito violeta, Britany = lacito azul.
/// Asignación fija, siempre igual.
String twinName(bool twinA) => twinA ? 'Brenda' : 'Britany';

/// Gemela del día: va rotando, una cada día (día par = Brenda,
/// día impar = Britany).
bool twinOfTheDay([DateTime? date]) =>
    (date ?? DateTime.now()).day.isEven;

/// Clave del texto "Hoy te acompaña Brenda/Britany".
String twinOfDayKey(bool twinA) =>
    twinA ? 'twinOfDayBrenda' : 'twinOfDayBritany';

/// Avatar redondo de una gemela a partir de su imagen ilustrada.
///
/// La imagen tiene fondo sólido, así que se recorta en círculo con
/// ClipOval y se enmarca con un aro del color de la gemela para que
/// se vea limpio sobre cualquier fondo.
class _TwinAvatarImage extends StatelessWidget {
  const _TwinAvatarImage({
    required this.asset,
    required this.accent,
    required this.size,
  });

  final String asset;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: size * 0.05),
        color: Colors.white,
      ),
      child: ClipOval(
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Gemela del lacito violeta: Brenda.
class TwinAvatarA extends StatelessWidget {
  const TwinAvatarA({super.key, this.size = 52, this.mood = TwinMood.happy});

  final double size;
  final TwinMood mood;

  @override
  Widget build(BuildContext context) {
    return _TwinAvatarImage(
      asset: 'assets/brenda.png',
      accent: BrandColors.violet,
      size: size,
    );
  }
}

/// Gemela del lacito azul: Britany.
class TwinAvatarB extends StatelessWidget {
  const TwinAvatarB({super.key, this.size = 52, this.mood = TwinMood.happy});

  final double size;
  final TwinMood mood;

  @override
  Widget build(BuildContext context) {
    return _TwinAvatarImage(
      asset: 'assets/britany.png',
      accent: BrandColors.blue,
      size: size,
    );
  }
}

/// Avatar de una gemela + bocadillo con un mensaje corto.
///
/// - El nombre aparece en una etiquetita junto al avatar, siempre.
/// - El bocadillo va firmado con su nombre.
/// - La primera vez que aparece cada gemela, se presenta:
///   "¡Hola! Soy Brenda" / "¡Hola! Soy Britany" (se guarda en el
///   teléfono, así que solo pasa una vez por gemela).
class MascotBubble extends StatefulWidget {
  const MascotBubble({
    super.key,
    required this.twinA,
    required this.text,
    this.mood = TwinMood.happy,
    this.size = 52,
  });

  /// true = Brenda (violeta), false = Britany (azul).
  final bool twinA;
  final String text;
  final TwinMood mood;
  final double size;

  @override
  State<MascotBubble> createState() => _MascotBubbleState();
}

class _MascotBubbleState extends State<MascotBubble> {
  /// Presentaciones ya hechas en esta sesión (para que dos burbujas
  /// de la misma gemela en la misma pantalla no se presenten dos veces).
  static final _introducedThisSession = <bool>{};

  var _showIntro = false;

  @override
  void initState() {
    super.initState();
    final met = _introducedThisSession.contains(widget.twinA) ||
        (widget.twinA ? UserPrefs.metBrenda : UserPrefs.metBritany);
    _showIntro = !met;
    if (_showIntro) {
      _introducedThisSession.add(widget.twinA);
      UserPrefs.saveMetTwin(widget.twinA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent =
        widget.twinA ? BrandColors.violet : BrandColors.blue;
    final name = twinName(widget.twinA);
    final text = _showIntro
        ? tr(widget.twinA ? 'mascotIntroBrenda' : 'mascotIntroBritany')
        : widget.text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            widget.twinA
                ? TwinAvatarA(size: widget.size, mood: widget.mood)
                : TwinAvatarB(size: widget.size, mood: widget.mood),
            const SizedBox(height: 2),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '— $name',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
