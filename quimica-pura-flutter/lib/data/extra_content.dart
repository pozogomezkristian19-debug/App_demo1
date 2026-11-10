// Contenido extra de Melli-Qui v5: glosario, constantes, datos del día
// (pregunta del día y elemento del día) y curiosidades de elementos.
// Todo en español y sin internet.

import 'dart:math';

import '../data/periodic_table.dart';
import '../models.dart';
import 'element_details.dart';
import 'questions.dart';

// ---- Utilidades de fecha (deterministas por día) ----

/// Semilla estable para un día: el mismo día siempre da el mismo número.
int daySeed(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Pregunta del día: la misma para todos durante todo el día, distinta
/// cada día. Se elige del banco con la semilla del día.
QuizQuestion questionOfTheDay(DateTime date) {
  final rng = Random(daySeed(date));
  return allQuestions[rng.nextInt(allQuestions.length)];
}

/// Elemento del día: uno distinto cada día, en orden por la semilla.
ChemicalElement elementOfTheDay(DateTime date) {
  final rng = Random(daySeed(date));
  return allElements[rng.nextInt(allElements.length)];
}

// ---- Curiosidades de elementos (elemento del día) ----

/// Datos curiosos escritos a mano para los elementos más conocidos.
/// Para el resto, la curiosidad se genera con sus datos reales
/// (estado, categoría, electronegatividad).
const Map<int, String> elementFacts = {
  1: 'Es el elemento más ligero y el más abundante del universo: forma las estrellas.',
  2: 'Es un gas noble que no reacciona con casi nada; se usa en globos y en resonancias magnéticas.',
  3: 'Es el metal más ligero; sus sales se usan en baterías recargables y en el tratamiento del trastorno bipolar.',
  6: 'Es la base de toda la química orgánica: forma más compuestos que ningún otro elemento.',
  7: 'Forma el 78 % del aire que respiras, pero casi ningún ser vivo puede usarlo directamente del aire.',
  8: 'Sin oxígeno no hay respiración ni combustión: es el elemento más abundante en la corteza terrestre.',
  9: 'Es el elemento más electronegativo de todos: arranca electrones a casi cualquier átomo.',
  11: 'Es tan reactivo que se guarda bajo aceite: con agua explota. Su llama es amarilla intensa.',
  12: 'Arde con una luz blanca cegadora; es el centro de la molécula de clorofila.',
  13: 'Es el metal más abundante de la corteza terrestre y no se oxida con facilidad: por eso hay aviones de aluminio.',
  16: 'Huele a huevos podridos en su forma de sulfuro de hidrógeno, pero es esencial para las proteínas.',
  17: 'Era un arma química en la Primera Guerra Mundial; hoy desinfecta el agua de las piscinas.',
  19: 'Es tan blando que se corta con un cuchillo y tan reactivo que arde en contacto con el agua.',
  20: 'Forma tus huesos y tus dientes, y la cal de las construcciones.',
  26: 'Es el metal más usado del mundo: el acero es, en su mayor parte, hierro con un poco de carbono.',
  27: 'Da el color azul a los vidrios y a muchos pigmentos; su isótopo Co-60 se usa en radioterapia.',
  29: 'La humanidad lo usa desde hace más de 10 000 años: fue uno de los primeros metales trabajados.',
  30: 'Protege al acero del óxido (galvanizado) y es esencial para tu sistema inmune.',
  35: 'Es uno de los dos únicos elementos líquidos a temperatura ambiente, junto con el mercurio.',
  47: 'Es el mejor conductor eléctrico de todos los metales; también es un potente antibacteriano.',
  53: 'Su vapor es violeta; se usa como desinfectante y en el tratamiento de la tiroides.',
  54: 'Es un gas noble que se ilumina en los letreros de neón: su nombre significa «lo nuevo».',
  56: 'Sus sales dan el color verde a los fuegos artificiales.',
  79: 'No se oxida ni se corroe: por eso los tesoros de oro de hace miles de años siguen brillando.',
  80: 'Es el único metal líquido a temperatura ambiente y es muy tóxico: por eso ya no se usa en termómetros.',
  82: 'Es tan denso que una pelota de plomo del tamaño de una naranja pesa más de 2 kg.',
  92: 'Es el elemento más pesado que existe de forma natural en la Tierra.',
};

/// Curiosidad de un elemento: la escrita a mano si existe, o una
/// generada con sus datos reales.
String elementFact(ChemicalElement e) {
  final manual = elementFacts[e.atomicNumber];
  if (manual != null) return manual;
  final en = electronegativity[e.atomicNumber];
  final state = elementState(e.atomicNumber);
  final enText = en == null ? 'sin electronegatividad medida' : 'electronegatividad $en';
  return 'Es un ${categoryNames[e.category].toLowerCase()} que a 25 °C está en estado $state, con $enText y número atómico ${e.atomicNumber}.';
}

// ---- Glosario ----

class GlossaryTerm {
  const GlossaryTerm({required this.term, required this.definition});
  final String term;
  final String definition;
}

const List<GlossaryTerm> glossary = [
  GlossaryTerm(term: 'Ácido', definition: 'Sustancia que cede protones (H⁺) o acepta pares de electrones. En disolución acuosa genera iones hidronio y su pH es menor que 7.'),
  GlossaryTerm(term: 'Átomo', definition: 'La unidad más pequeña de un elemento que conserva sus propiedades químicas. Está formado por protones, neutrones y electrones.'),
  GlossaryTerm(term: 'Base', definition: 'Sustancia que acepta protones (H⁺) o cede pares de electrones. En disolución acuosa genera iones hidróxido y su pH es mayor que 7.'),
  GlossaryTerm(term: 'Catión', definition: 'Ion con carga positiva, formado cuando un átomo pierde electrones (por ejemplo, Na⁺, Ca²⁺).'),
  GlossaryTerm(term: 'Anión', definition: 'Ion con carga negativa, formado cuando un átomo gana electrones (por ejemplo, Cl⁻, SO₄²⁻).'),
  GlossaryTerm(term: 'Mol', definition: 'Cantidad de sustancia que contiene 6.022×10²³ entidades (átomos, moléculas o iones): el número de Avogadro.'),
  GlossaryTerm(term: 'Molaridad', definition: 'Concentración de una disolución: moles de soluto por litro de disolución (mol/L).'),
  GlossaryTerm(term: 'pH', definition: 'Medida de la acidez: pH = −log[H₃O⁺]. Menor que 7 es ácido, 7 es neutro y mayor que 7 es básico.'),
  GlossaryTerm(term: 'Equilibrio químico', definition: 'Estado en el que la velocidad de la reacción directa iguala a la de la inversa y las concentraciones dejan de cambiar.'),
  GlossaryTerm(term: 'Constante de equilibrio (K)', definition: 'Cociente entre las concentraciones de productos y reactivos en el equilibrio, cada una elevada a su coeficiente.'),
  GlossaryTerm(term: 'Kps (producto de solubilidad)', definition: 'Constante de equilibrio de la disolución de una sal poco soluble: a mayor Kps, más soluble es la sal.'),
  GlossaryTerm(term: 'Hidrólisis', definition: 'Reacción de un ion con el agua que cambia el pH: las sales de ácido débil y base fuerte dan disoluciones básicas, y al revés.'),
  GlossaryTerm(term: 'Redox', definition: 'Reacción en la que hay transferencia de electrones: una especie se oxida (los pierde) y otra se reduce (los gana).'),
  GlossaryTerm(term: 'Número de oxidación', definition: 'Carga hipotética que tendría un átomo si todos sus enlaces fueran iónicos. Sirve para seguir los electrones en las reacciones redox.'),
  GlossaryTerm(term: 'Electrón', definition: 'Partícula subatómica con carga negativa que se mueve alrededor del núcleo y participa en los enlaces químicos.'),
  GlossaryTerm(term: 'Electronegatividad', definition: 'Capacidad de un átomo para atraer hacia sí los electrones de un enlace. El flúor es el más electronegativo.'),
  GlossaryTerm(term: 'Configuración electrónica', definition: 'Distribución de los electrones de un átomo en sus niveles y subniveles (por ejemplo, [Ar] 3d⁷ 4s² para el cobalto).'),
  GlossaryTerm(term: 'Isótopo', definition: 'Átomos del mismo elemento con distinto número de neutrones (por ejemplo, ¹²C y ¹⁴C). Tienen el mismo Z y distinta masa.'),
  GlossaryTerm(term: 'Enlace covalente', definition: 'Unión entre átomos que comparten pares de electrones (por ejemplo, H₂, H₂O, CH₄).'),
  GlossaryTerm(term: 'Enlace iónico', definition: 'Unión entre iones de carga opuesta por atracción electrostática (por ejemplo, NaCl).'),
  GlossaryTerm(term: 'Enlace metálico', definition: 'Unión entre átomos de un metal, con electrones deslocalizados que forman un «mar de electrones».'),
  GlossaryTerm(term: 'Hidrógeno (enlace de)', definition: 'Atracción entre un hidrógeno unido a O, N o F y un par libre de otro átomo. Explica que el agua sea líquida a temperatura ambiente.'),
  GlossaryTerm(term: 'Fuerzas de Van der Waals', definition: 'Atracciones débiles entre moléculas (dipolo-dipolo y dispersión de London). Deciden puntos de fusión y ebullición.'),
  GlossaryTerm(term: 'Grupo funcional', definition: 'Átomo o grupo de átomos que da a una molécula orgánica sus propiedades características (–OH, –COOH, –NH₂…).'),
  GlossaryTerm(term: 'Isómero', definition: 'Compuestos con la misma fórmula molecular pero distinta estructura o disposición espacial.'),
  GlossaryTerm(term: 'Quiralidad', definition: 'Propiedad de una molécula que no se puede superponer con su imagen especular, como las manos izquierda y derecha.'),
  GlossaryTerm(term: 'Enantiómero', definition: 'Cada uno de los dos estereoisómeros quirales que son imagen especular el uno del otro.'),
  GlossaryTerm(term: 'Catálisis', definition: 'Aumento de la velocidad de una reacción por un catalizador, que no se consume en la reacción.'),
  GlossaryTerm(term: 'Energía de activación', definition: 'Energía mínima que deben tener las moléculas para que una colisión produzca reacción.'),
  GlossaryTerm(term: 'Entalpía (ΔH)', definition: 'Calor intercambiado a presión constante. ΔH < 0 es exotérmico (suelta calor); ΔH > 0 es endotérmico (absorbe calor).'),
  GlossaryTerm(term: 'Entropía (ΔS)', definition: 'Medida del desorden de un sistema. Los procesos espontáneos tienden a aumentar la entropía del universo.'),
  GlossaryTerm(term: 'Energía libre de Gibbs (ΔG)', definition: 'ΔG = ΔH − TΔS. Si ΔG < 0, el proceso es espontáneo; si ΔG > 0, no lo es.'),
  GlossaryTerm(term: 'Valoración', definition: 'Técnica para determinar la concentración de una disolución añadiendo poco a poco otra de concentración conocida hasta el punto de equivalencia.'),
  GlossaryTerm(term: 'Punto de equivalencia', definition: 'Momento de una valoración en el que la cantidad añadida es justo la necesaria para reaccionar por completo con la muestra.'),
  GlossaryTerm(term: 'Indicador', definition: 'Sustancia que cambia de color en un intervalo de pH y permite ver el punto final de una valoración (por ejemplo, la fenolftaleína).'),
  GlossaryTerm(term: 'Soluto', definition: 'Sustancia que se disuelve en un disolvente para formar una disolución.'),
  GlossaryTerm(term: 'Disolvente', definition: 'Sustancia que disuelve al soluto; en las disoluciones acuosas es el agua.'),
  GlossaryTerm(term: 'Disolución saturada', definition: 'Disolución que contiene la máxima cantidad de soluto que se puede disolver a esa temperatura.'),
  GlossaryTerm(term: 'Precipitado', definition: 'Sólido insoluble que se forma en una disolución durante una reacción química.'),
  GlossaryTerm(term: 'Ácido poliprótico', definition: 'Ácido que puede ceder más de un protón por molécula (por ejemplo, H₂SO₄, H₃PO₄), en etapas sucesivas.'),
  GlossaryTerm(term: 'Anfótero', definition: 'Sustancia que puede actuar como ácido o como base según con qué reaccione (por ejemplo, el agua, el Al(OH)₃).'),
  GlossaryTerm(term: 'Metal de transición', definition: 'Elemento del bloque d de la tabla periódica, con varios estados de oxidación y compuestos a menudo coloreados.'),
  GlossaryTerm(term: 'Serie de actividad', definition: 'Orden de los metales según su facilidad para perder electrones y reaccionar. Un metal desplaza a los que están por debajo de él.'),
  GlossaryTerm(term: 'Orbital', definition: 'Región del espacio donde hay una alta probabilidad de encontrar un electrón. Los orbitales s, p, d y f tienen formas distintas.'),
  GlossaryTerm(term: 'Regla del octeto', definition: 'Tendencia de los átomos a tener 8 electrones en su capa de valencia al formar enlaces, como los gases nobles.'),
  GlossaryTerm(term: 'Polaridad', definition: 'Distribución desigual de la carga en una molécula, por diferencias de electronegatividad entre sus átomos.'),
  GlossaryTerm(term: 'Tensión superficial', definition: 'Fuerza que mantiene unida la superficie de un líquido; por eso algunos insectos caminan sobre el agua.'),
  GlossaryTerm(term: 'Presión parcial', definition: 'Presión que ejercería un gas de una mezcla si ocupara él solo todo el volumen (ley de Dalton).'),
  GlossaryTerm(term: 'Volumen molar', definition: 'Volumen que ocupa un mol de gas: 22.4 L en condiciones normales (0 °C y 1 atm).'),
  GlossaryTerm(term: 'Reactivo limitante', definition: 'Reactivo que se agota primero en una reacción y determina la cantidad máxima de producto que se puede formar.'),
  GlossaryTerm(term: 'Rendimiento', definition: 'Porcentaje del producto teórico que se obtiene realmente en una reacción. Nunca supera el 100 %.'),
];

// ---- Constantes (Constantes y conversiones) ----

class ChemConstant {
  const ChemConstant({required this.symbol, required this.value, required this.note});
  final String symbol;
  final String value;
  final String note;
}

const List<ChemConstant> chemConstants = [
  ChemConstant(symbol: 'NA', value: '6.022 × 10²³ mol⁻¹', note: 'Número de Avogadro'),
  ChemConstant(symbol: 'R', value: '0.08206 L·atm·mol⁻¹·K⁻¹', note: 'Constante de los gases ideales'),
  ChemConstant(symbol: 'R', value: '8.314 J·mol⁻¹·K⁻¹', note: 'Constante de los gases ideales (SI)'),
  ChemConstant(symbol: 'F', value: '96485 C·mol⁻¹', note: 'Constante de Faraday'),
  ChemConstant(symbol: 'Kw', value: '1.0 × 10⁻¹⁴ (25 °C)', note: 'Producto iónico del agua'),
  ChemConstant(symbol: 'e', value: '1.602 × 10⁻¹⁹ C', note: 'Carga elemental'),
  ChemConstant(symbol: 'h', value: '6.626 × 10⁻³⁴ J·s', note: 'Constante de Planck'),
  ChemConstant(symbol: 'c', value: '3.00 × 10⁸ m·s⁻¹', note: 'Velocidad de la luz en el vacío'),
  ChemConstant(symbol: 'Vm', value: '22.4 L·mol⁻¹', note: 'Volumen molar en condiciones normales'),
  ChemConstant(symbol: '0 °C', value: '273.15 K', note: 'Cero de la escala Celsius en kelvin'),
  ChemConstant(symbol: '1 atm', value: '101325 Pa = 760 mmHg', note: 'Presión atmosférica estándar'),
  ChemConstant(symbol: 'me', value: '9.109 × 10⁻³¹ kg', note: 'Masa del electrón'),
  ChemConstant(symbol: 'mp', value: '1.673 × 10⁻²⁷ kg', note: 'Masa del protón'),
];

// ---- Búsqueda: quitar tildes para comparar ----

/// Quita tildes y pasa a minúsculas, para que «ácido» coincida con
/// «acido» al buscar.
String fold(String s) {
  const from = 'áéíóúüñÁÉÍÓÚÜÑ';
  const to = 'aeiouunAEIOUUN';
  var out = s;
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out.toLowerCase();
}
