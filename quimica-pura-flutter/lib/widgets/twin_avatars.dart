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
//   (Brenda, Britany, Kristian) y por momento: presentar una
//   pregunta (ask), ánimo al acertar (praise) y consuelo al fallar
//   (console). 5 variantes por compañero y categoría (claves
//   mascotAskBritany0…4…, en los 6 idiomas). Rota sin repetirse
//   seguida: el índice avanza de uno en uno por (compañero,
//   categoría) y solo avanza cuando cambia el turno, así un mismo
//   turno (misma pregunta, mismo día) reconstruye la pantalla con
//   la MISMA frase y la siguiente vez sale otra distinta.
//   (El momento "greet" y sus claves mascotGreet*0…4 ya NO se usan:
//   la burbuja nunca muestra un saludo — los saludos no tienen que
//   ver con las preguntas. Quedan en localization.dart y en el enum
//   solo por compatibilidad con tests viejos; el coordinador los
//   quita en el cierre.)
//
// En cada pregunta aparece uno de los tres (por turnos) y en los
// demás momentos (racha, repaso de errores, celebración de nivel)
// aparece el compañero del día.

import 'package:flutter/material.dart';

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

/// Momento en el que habla la mascota: presentar una pregunta,
/// ánimo al acertar o consuelo al fallar. Cada momento tiene 5
/// variantes por compañero. (El valor [MascotLine.greet], saludo de
/// presentación, ya NO lo usa la burbuja: se conserva solo porque
/// tests viejos lo referencian; sus claves mascotGreet* se quitan en
/// el cierre.)
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
///
/// Reinicio solo para tests ([resetMascotLineRotationForTesting]):
/// sin él, la frase de la burbuja depende del historial GLOBAL de
/// llamadas y los goldens con burbuja salen distintos según el
/// orden de ejecución (p. ej. fix8_duelo_desconexion mostraba la
/// variante 0 o la 4 según qué tests corrieran antes).
final _mascotLastTurn = <String, int>{};
final _mascotLastIndex = <String, int>{};

/// Pone a cero la rotación de frases de la mascota (SOLO tests).
/// No cambia ningún comportamiento de la app: en producción la
/// rotación sigue avanzando con normalidad.
@visibleForTesting
void resetMascotLineRotationForTesting() {
  _mascotLastTurn.clear();
  _mascotLastIndex.clear();
}

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
/// (Legado: la burbuja ya no muestra el saludo; se conserva porque
/// tests viejos lo usan. Las claves mascotIntro* se quitan de
/// localization.dart en el cierre.)
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
/// ClipOval. El aro del color de cada una es opcional ([ring]);
/// el rediseño Duolingo (§3.2.7/§3.3.2) lo quita en la burbuja de
/// la pregunta y en la muñeca junto al camino: la cara va sin aro.
class _TwinAvatarImage extends StatelessWidget {
  const _TwinAvatarImage({
    required this.asset,
    required this.accent,
    required this.size,
    this.ring = true,
  });

  final String asset;
  final Color accent;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    // (foto72) El fondo era blanco fijo: en oscuro se veía un
    // disco blanco detrás de la cara de la compañera (el PNG es
    // transparente y el blanco se transparentaba). En oscuro el
    // fondo es transparente (se ve el fondo de la pantalla, como
    // en el banner de Niveles); en claro se mantiene blanco.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring ? Border.all(color: accent, width: size * 0.05) : null,
        color: isDark ? Colors.transparent : Colors.white,
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
  const KristianAvatar({super.key, this.size = 52, this.mood = TwinMood.happy});

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
/// de su color (o sin aro si [ring] es false: rediseño Duolingo).
/// Reutiliza el mismo marco que TwinAvatarA/B.
class CompanionAvatar extends StatelessWidget {
  const CompanionAvatar({
    super.key,
    required this.companion,
    this.size = 52,
    this.mood = TwinMood.happy,
    this.ring = true,
  });

  final Companion companion;
  final double size;
  final TwinMood mood;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return _TwinAvatarImage(
      asset: companionAsset(companion),
      accent: companionAccent(companion),
      size: size,
      ring: ring,
    );
  }
}

/// Avatar de un compañero + bocadillo con un mensaje corto.
///
/// (fix5) La foto se queda, pero el nombre ya NO aparece: ni
/// etiquetita debajo de la foto ni firma al pie de la burbuja.
/// Antes se repetía hasta 4 veces en el mismo sitio (nombre bajo
/// la foto, saludo "¡Hola! Soy…", firma "— Nombre" y la línea
/// "Hoy te acompaña…", ya eliminada).
///
/// La burbuja muestra SIEMPRE el mensaje que le pasa el llamador
/// ([text]): NUNCA un saludo. Los saludos no tienen que ver con
/// las preguntas — en las preguntas la burbuja dice la pregunta o
/// un ánimo ("tú puedes" y cosas así). La presentación ("¡Hola!
/// Soy…") se eliminó de la burbuja en esta ronda: al no sustituir
/// nunca el texto, foto y texto siempre salen del MISMO
/// acompañante, el que pasa el llamador (companionForTurn etc.),
/// y el saludo ya no puede repetirse en cada pregunta ni salir
/// con el nombre equivocado.
class MascotBubble extends StatelessWidget {
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

  /// El compañero que habla: [companion] si se pasó, si no el de
  /// [twinA] (Brenda/Britany).
  Companion get _companion =>
      companion ?? (twinA ? Companion.brenda : Companion.britany);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // (fix5) Solo la foto, sin el nombre debajo. Rediseño
        // Duolingo (§3.3.2): sin el anillo de color de la mascota.
        CompanionAvatar(
            companion: _companion, size: size, mood: mood, ring: false),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              // Burbuja blanca con borde #E5E5E5 (§3.3.2): antes era
              // gris tintada con borde del color de la mascota.
              color: isDark ? scheme.surfaceContainerHighest : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              // Sin borde en oscuro: la línea clara se veía fea
              // (Kristian, 2026-11-13); el relleno distingue la
              // burbuja del fondo.
              border:
                  isDark ? null : Border.all(color: const Color(0xFFE5E5E5)),
            ),
            // (fix5) Solo el texto del mensaje, sin la firma
            // "— Nombre" abajo a la derecha. Siempre [text]:
            // nunca se sustituye por ningún saludo.
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }
}
