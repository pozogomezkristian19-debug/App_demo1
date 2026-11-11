// Las mascotas de Melli-Qui: las dos gemelas y Kristian, cada uno
// con su avatar ILUSTRADO (imagen generada en estilo Duolingo:
// muñecos suaves, ojos grandes, colorete), recortado en círculo
// para que se vea limpio como avatar redondo.
// Brenda = lacito/vestido VIOLETA (#8B5CF6), Britany = lacito/
// vestido AZUL (#3B82F6), Kristian = SUDADERA NEGRA con detalles
// teal (el color principal de la app), pelo rubio. Asignación fija,
// siempre igual. Sin dibujo por código ni emojis: los avatares son
// las imágenes assets/brenda.png, assets/britany.png y
// assets/kristian.png (fondo blanco sólido, por eso se recortan
// con ClipOval y llevan un aro del color de cada uno).
//
// - TwinAvatarA / TwinAvatarB / KristianAvatar (o CompanionAvatar):
//   la cara de cada uno, para usar en preguntas, racha, repaso y
//   celebraciones.
// - MascotBubble: avatar + bocadillo con un mensaje corto.
// - mascotCheerKey / mascotPraiseKey / mascotConsoleKey: las 3 frases
//   genéricas antiguas (compatibilidad; siguen en localization.dart).
// - MascotLine + mascotLineKey: el repertorio NUEVO, por compañero
//   (Brenda, Britany, Kristian) y por momento: saludo de presentación
//   (greet), presentar una pregunta (ask), ánimo al acertar (praise)
//   y consuelo al fallar (console). 5 variantes por compañero y
//   categoría (claves mascotGreetBrenda0…4, mascotAskBritany0…4…,
//   en los 6 idiomas). Rota sin repetirse seguida: el índice avanza
//   de uno en uno por (compañero, categoría) y solo avanza cuando
//   cambia el turno, así un mismo turno (misma pregunta, mismo día)
//   reconstruye la pantalla con la MISMA frase y la siguiente vez
//   sale otra distinta.
//
// En cada pregunta aparece uno de los tres (por turnos) y en los
// demás momentos (pregunta del día, racha, repaso de errores,
// celebración de nivel) aparece el compañero del día.

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
/// (Compatibilidad: el código nuevo usa [mascotLineKey] con
/// [MascotLine.console], 5 variantes por compañero.)
String mascotConsoleKey(int i) => 'mascotConsole${i % 3}';

/// Momento en el que habla la mascota: saludo de presentación,
/// presentar una pregunta, ánimo al acertar o consuelo al fallar.
/// Cada momento tiene 5 variantes por compañero.
enum MascotLine { greet, ask, praise, console }

/// Variantes por compañero y categoría.
const int mascotLineVariants = 5;

/// Clave de una variante concreta ('mascotAskBritany2',
/// 'mascotGreetKristian0'…). Pura (sin estado): para pruebas y
/// para comprobar que la clave existe en los 6 idiomas.
String mascotLineKeyAt(Companion c, MascotLine kind, int i) {
  final n = i % mascotLineVariants;
  final kindWord = switch (kind) {
    MascotLine.greet => 'Greet',
    MascotLine.ask => 'Ask',
    MascotLine.praise => 'Praise',
    MascotLine.console => 'Console',
  };
  final who = switch (c) {
    Companion.brenda => 'Brenda',
    Companion.britany => 'Britany',
    Companion.kristian => 'Kristian',
  };
  return 'mascot$kindWord$who$n';
}

/// Último turno visto y último índice usado, por (compañero,
/// categoría). El índice solo avanza cuando cambia el turno: una
/// misma pregunta o un mismo día reconstruye la pantalla con la
/// MISMA frase, y la siguiente vez sale otra distinta — nunca la
/// misma dos veces seguidas.
final _mascotLastTurn = <String, int>{};
final _mascotLastIndex = <String, int>{};

/// Clave de la variante que toca para este compañero, momento y
/// turno (índice de pregunta, día del mes, nº de errores…).
String mascotLineKey(Companion c, MascotLine kind, int turn) {
  final mapKey = '${c.name}-${kind.name}';
  if (_mascotLastTurn[mapKey] != turn) {
    _mascotLastTurn[mapKey] = turn;
    _mascotLastIndex[mapKey] =
        ((_mascotLastIndex[mapKey] ?? -1) + 1) % mascotLineVariants;
  }
  return mascotLineKeyAt(c, kind, _mascotLastIndex[mapKey] ?? 0);
}

/// Turno nuevo para cada presentación (saludo): cada vez que un
/// compañero se presenta por primera vez, el saludo rota. La
/// primera presentación de cada compañero es la variante 0, la
/// presentación clásica ("¡Hola! Soy Brenda/Britany/Kristian").
int _mascotIntroTurn = 0;
int mascotNextIntroTurn() => _mascotIntroTurn++;

/// Los tres compañeros de Melli-Qui, en el orden de la rotación:
/// Brenda (violeta), Britany (azul) y Kristian (teal).
enum Companion { brenda, britany, kristian }

/// Compañero del día: va rotando, uno cada día (el día del mes
/// decide: día % 3 = 0 → Brenda, 1 → Britany, 2 → Kristian).
Companion companionOfTheDay([DateTime? date]) =>
    Companion.values[(date ?? DateTime.now()).day % 3];

/// Compañero de cada pregunta, por turnos: las preguntas van
/// rotando entre los tres, así Kristian también aparece en las
/// burbujas de las preguntas.
Companion companionForTurn(int i) => Companion.values[i % 3];

/// Gemela del día (compatibilidad): la API antigua devolvía un
/// bool (true = Brenda, false = Britany). Se conserva para que
/// los llamadores que aún la usan (p. ej. el servicio de
/// notificaciones) sigan compilando: true solo el día de Brenda.
/// El código nuevo debe usar [companionOfTheDay].
bool twinOfTheDay([DateTime? date]) =>
    companionOfTheDay(date) == Companion.brenda;

/// Nombre de cada compañero.
String companionName(Companion c) => switch (c) {
      Companion.brenda => 'Brenda',
      Companion.britany => 'Britany',
      Companion.kristian => 'Kristian',
    };

/// Color de acento de cada compañero: Brenda violeta, Britany azul,
/// Kristian teal (el color principal de la app).
Color companionAccent(Companion c) => switch (c) {
      Companion.brenda => BrandColors.violet,
      Companion.britany => BrandColors.blue,
      Companion.kristian => BrandColors.teal,
    };

/// Archivo de imagen de cada compañero.
String companionAsset(Companion c) => switch (c) {
      Companion.brenda => 'assets/brenda.png',
      Companion.britany => 'assets/britany.png',
      Companion.kristian => 'assets/kristian.png',
    };

/// Clave del texto "Hoy te acompaña Brenda/Britany/Kristian".
String companionOfDayKey(Companion c) => switch (c) {
      Companion.brenda => 'twinOfDayBrenda',
      Companion.britany => 'twinOfDayBritany',
      Companion.kristian => 'twinOfDayKristian',
    };

/// Clave del texto de presentación "¡Hola! Soy Brenda/Britany/Kristian".
String companionIntroKey(Companion c) => switch (c) {
      Companion.brenda => 'mascotIntroBrenda',
      Companion.britany => 'mascotIntroBritany',
      Companion.kristian => 'mascotIntroKristian',
    };

/// Nombre de cada gemela: Brenda = lacito violeta, Britany = lacito azul.
/// Asignación fija, siempre igual. (Compatibilidad: el código nuevo
/// usa [companionName]).
String twinName(bool twinA) => twinA ? 'Brenda' : 'Britany';

/// Clave del texto "Hoy te acompaña Brenda/Britany".
/// (Compatibilidad: el código nuevo usa [companionOfDayKey]).
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
          // La foto (1600x1600) llena el marco y se reduce mucho
          // (a ~36-52 px): calidad media para que no se vea blanda
          // ni pixelada al achicarla. Cuadrada sobre cuadrado con
          // cover: sin estirar ni aplastar.
          filterQuality: FilterQuality.medium,
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

/// Kristian, el tercer compañero: pelo rubio, sudadera negra con
/// detalles teal (su color de identidad sigue siendo el teal: aro
/// de la foto y etiquetas).
class KristianAvatar extends StatelessWidget {
  const KristianAvatar(
      {super.key, this.size = 52, this.mood = TwinMood.happy});

  final double size;
  final TwinMood mood;

  @override
  Widget build(BuildContext context) {
    return _TwinAvatarImage(
      asset: 'assets/kristian.png',
      accent: BrandColors.teal,
      size: size,
    );
  }
}

/// Avatar redondo de cualquiera de los tres compañeros, con el aro
/// de su color. Reutiliza el mismo marco que TwinAvatarA/B.
class CompanionAvatar extends StatelessWidget {
  const CompanionAvatar({
    super.key,
    required this.companion,
    this.size = 52,
    this.mood = TwinMood.happy,
  });

  final Companion companion;
  final double size;
  final TwinMood mood;

  @override
  Widget build(BuildContext context) {
    return _TwinAvatarImage(
      asset: companionAsset(companion),
      accent: companionAccent(companion),
      size: size,
    );
  }
}

/// Avatar de un compañero + bocadillo con un mensaje corto.
///
/// - El nombre aparece en una etiquetita junto al avatar, siempre.
/// - El bocadillo va firmado con su nombre.
/// - La primera vez que aparece cada compañero, se presenta:
///   "¡Hola! Soy Brenda" / "¡Hola! Soy Britany" / "¡Hola! Soy
///   Kristian" (se guarda en el teléfono, así que solo pasa una
///   vez por compañero). El saludo rota entre 5 variantes
///   ([MascotLine.greet]); la primera vez es la clásica.
class MascotBubble extends StatefulWidget {
  const MascotBubble({
    super.key,
    this.twinA = true,
    this.companion,
    required this.text,
    this.mood = TwinMood.happy,
    this.size = 52,
  });

  /// Compatibilidad: true = Brenda (violeta), false = Britany
  /// (azul). Si se pasa [companion], es ese el que manda.
  final bool twinA;

  /// El compañero que habla. Si no se pasa, se deriva de [twinA].
  final Companion? companion;
  final String text;
  final TwinMood mood;
  final double size;

  @override
  State<MascotBubble> createState() => _MascotBubbleState();
}

class _MascotBubbleState extends State<MascotBubble> {
  /// Presentaciones ya hechas en esta sesión (para que dos burbujas
  /// del mismo compañero en la misma pantalla no se presenten dos veces).
  static final _introducedThisSession = <Companion>{};

  var _showIntro = false;

  /// Saludo de presentación que toca (variante que rota): solo se
  /// elige una vez, al crearse la burbuja, para que no cambie si la
  /// pantalla se reconstruye.
  String? _introKey;

  /// El compañero que habla: [MascotBubble.companion] si se pasó,
  /// si no el de [MascotBubble.twinA] (Brenda/Britany).
  Companion get _companion =>
      widget.companion ??
      (widget.twinA ? Companion.brenda : Companion.britany);

  /// ¿Este compañero ya se presentó alguna vez (en el teléfono)?
  bool _alreadyMet(Companion c) => switch (c) {
        Companion.brenda => UserPrefs.metBrenda,
        Companion.britany => UserPrefs.metBritany,
        Companion.kristian => UserPrefs.metKristian,
      };

  @override
  void initState() {
    super.initState();
    final met =
        _introducedThisSession.contains(_companion) || _alreadyMet(_companion);
    _showIntro = !met;
    if (_showIntro) {
      // El saludo de presentación también rota (variante 0 la
      // primera vez: la presentación clásica "¡Hola! Soy…").
      _introKey =
          mascotLineKey(_companion, MascotLine.greet, mascotNextIntroTurn());
      _introducedThisSession.add(_companion);
      switch (_companion) {
        case Companion.brenda:
        case Companion.britany:
          UserPrefs.saveMetTwin(_companion == Companion.brenda);
        case Companion.kristian:
          UserPrefs.saveMetKristian();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = companionAccent(_companion);
    final name = companionName(_companion);
    final text =
        _showIntro ? tr(_introKey ?? companionIntroKey(_companion)) : widget.text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CompanionAvatar(
                companion: _companion, size: widget.size, mood: widget.mood),
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
