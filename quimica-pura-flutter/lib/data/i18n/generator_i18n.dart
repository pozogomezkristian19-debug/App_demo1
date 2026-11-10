// Plantillas de las preguntas generadas (v6), en los 6 idiomas.
// El generador construye sus preguntas a partir de estas plantillas:
// {name}, {formula}, {v}... se sustituyen por los datos de cada pregunta.
// El español reproduce EXACTAMENTE los textos que el generador usaba
// antes, para que las preguntas guardadas (falladas) se reconstruyan
// idénticas. Dart puro, sin Flutter, para que el generador siga siéndolo.
//
// El idioma activo se fija con `genLang` (main.dart lo sincroniza con
// AppLang.code). Por defecto español.

import 'content_en.dart';
import 'content_fr.dart';
import 'content_it.dart';
import 'content_pt.dart';
import 'content_ru.dart';

String genLang = 'es';

/// Nombre de un elemento por su número atómico (clave = nombre en español).
String genElementName(int z, String esName) {
  switch (genLang) {
    case 'en':
      return elementNamesEn[z] ?? esName;
    case 'fr':
      return elementNamesFr[z] ?? esName;
    case 'it':
      return elementNamesIt[z] ?? esName;
    case 'pt':
      return elementNamesPt[z] ?? esName;
    case 'ru':
      return elementNamesRu[z] ?? esName;
    default:
      return esName;
  }
}

String gt(String key, [Map<String, String> params = const {}]) {
  final table = _genTemplates[genLang] ?? _genTemplates['es']!;
  var s = table[key] ?? _genTemplates['es']![key] ?? key;
  params.forEach((k, v) {
    s = s.replaceAll('{$k}', v);
  });
  return s;
}

/// Nombre de una sustancia del generador (clave = nombre en español).
String genSubstanceName(String esName) {
  if (genLang == 'es') return esName;
  return _genSubstances[genLang]?[esName] ?? esName;
}

/// Geometría molecular (clave = nombre en español, capitalizado).
String genGeometry(String esName) {
  if (genLang == 'es') return esName;
  return _genGeometries[genLang]?[esName] ?? esName;
}

/// Tipo de enlace (clave = nombre en español, capitalizado).
String genBond(String esName) {
  if (genLang == 'es') return esName;
  return _genBonds[genLang]?[esName] ?? esName;
}

const Map<String, Map<String, String>> _genTemplates = {
  'es': {
    'molarMassQ':
        '¿Cuál es la masa molar del {name} ({formula})?',
    'molarMassE':
        'M = {steps}. Suma cada elemento multiplicado por su subíndice.',
    'massMolesQ':
        '¿Cuántos moles hay en {g} g de {name} ({formula})?',
    'massMolesE': 'n = m/M = {g} g ÷ {m} g/mol = {v} mol.',
    'massMassQ': '¿Qué masa tienen {n} mol de {name} ({formula})?',
    'massMassE': 'm = n × M = {n} mol × {m} g/mol = {v} g.',
    'molarityQ':
        'Disuelves {n} mol de un soluto y aforas a {v} mL. ¿Cuál es la molaridad?',
    'molarityE':
        'Pasa el volumen a litros: {v} mL = {l} L. M = n/V = {n} mol ÷ {l} L = {c} M.',
    'molesFromMQ':
        '¿Cuántos moles de soluto hay en {v} mL de una disolución {m} M?',
    'molesFromME':
        'Pasa el volumen a litros: {v} mL = {l} L. n = M × V = {m} M × {l} L = {c} mol.',
    'dilutionC2Q':
        'Tienes una disolución {c1} M y tomas {v1} mL. Los diluyes hasta {v2} mL. ¿Cuál es la concentración final?',
    'dilutionC2E':
        'C₁V₁ = C₂V₂, así que C₂ = C₁V₁/V₂ = {c1} × {v1} ÷ {v2} = {c} M.',
    'dilutionV1Q':
        'Quieres preparar {v2} mL de una disolución {c2} M a partir de una concentrada {c1} M. ¿Qué volumen de la concentrada necesitas?',
    'dilutionV1E':
        'C₁V₁ = C₂V₂, así que V₁ = C₂V₂/C₁ = {c2} × {v2} ÷ {c1} = {v} mL.',
    'phQ': 'El pH de una disolución con [H₃O⁺] = {mant}×10{sup} M es:',
    'phE':
        'pH = −log[H⁺] = −log({mant}×10{sup}) = {exp} − log {mant} = {p}.',
    'pohQ': 'El pOH de una disolución con [OH⁻] = {mant}×10{sup} M es:',
    'pohE':
        'pOH = −log[OH⁻] = −log({mant}×10{sup}) = {exp} − log {mant} = {p}.',
    'phFromOhQ':
        'Una disolución tiene [OH⁻] = {mant}×10{sup} M. Su pH a 25 °C es:',
    'phFromOhE':
        'Primero pOH = −log({mant}×10{sup}) = {p}. A 25 °C, pH + pOH = 14, así que pH = 14 − {p} = {c}.',
    'gasVolumeQ':
        '¿Qué volumen ocupan {n} mol de un gas ideal a {t} °C y {p} atm?',
    'gasVolumeE':
        'La temperatura va en kelvin: T = {t} + 273.15 = {tk} K. V = nRT/P = {n} × 0.08206 × {tk} ÷ {p} = {v} L.',
    'gasMolesQ':
        '¿Cuántos moles hay en {v} L de un gas ideal a {t} °C y {p} atm?',
    'gasMolesE':
        'La temperatura va en kelvin: T = {t} + 273.15 = {tk} K. n = PV/RT = {p} × {v} ÷ (0.08206 × {tk}) = {n} mol.',
    'gasPressureQ':
        '¿Qué presión ejerce {n} mol de un gas ideal en {v} L a {t} °C?',
    'gasPressureE':
        'La temperatura va en kelvin: T = {t} + 273.15 = {tk} K. P = nRT/V = {n} × 0.08206 × {tk} ÷ {v} = {p} atm.',
    'stoichProductQ':
        'En la reacción {eq}, si reaccionan {n} mol de {a}, ¿cuántos moles de {b} se forman?',
    'stoichReactantQ':
        'En la reacción {eq}, ¿cuántos moles de {a} se necesitan para formar {n} mol de {b}?',
    'stoichProductE':
        'La proporción {a}:{b} es {ca}:{cb}, así que {n} mol × ({cb}/{ca}) = {v} mol.',
    'stoichReactantE':
        'La proporción {b}:{a} es {cb}:{ca}, así que {n} mol × ({ca}/{cb}) = {v} mol.',
    'equilibQ':
        'Para la reacción {eq}, con [{a}] = {ca} M, [{b}] = {cb} M y [{c}] = {cc} M, calcula el cociente de reacción Qc.',
    'equilibE':
        'Qc = [{c}]^{cc} / ([{a}]^{ca} × [{b}]^{cb}) = {qc1} ÷ ({qa} × {qb}) = {q}. Los exponentes son los coeficientes: olvidarlos es el error clásico.',
    'thermoQ':
        '¿Cuánto calor (en kJ) se necesita para calentar {m} g de {name} {dt} °C? (c = {c} J/g·°C)',
    'thermoE':
        'q = m·c·ΔT = {m} g × {c} J/g·°C × {dt} °C = {qj} J = {qk} kJ. Recuerda pasar de J a kJ dividiendo entre 1000.',
    'periodicZQ': '¿Cuál es el número atómico del {name}?',
    'periodicZE':
        'El número atómico es la cantidad de protones: el {name} tiene Z = {z}.',
    'periodicSymbolQ': '¿Cuál es el símbolo químico del {name}?',
    'periodicSymbolE': 'El símbolo del {name} es {symbol}.',
    'periodicMassQ': '¿Cuál es la masa atómica aproximada del {name}?',
    'periodicMassE':
        'La masa atómica del {name} es {mass} u (aprox. {m} u).',
    'periodicGroupQ':
        '¿En qué grupo de la tabla periódica está el {name}?',
    'periodicGroupE':
        'El {name} está en el grupo {g} y en el periodo {p}.',
    'bondingGeometryQ':
        '¿Qué geometría molecular tiene el {name} ({formula})?',
    'bondingGeometryE':
        'El {name} ({formula}) tiene geometría {geom} según la teoría VSEPR.',
    'bondingBondQ':
        '¿Qué tipo de enlace predomina en el {name} ({formula})?',
    'bondingBondE':
        'En el {name} ({formula}) predomina el enlace {bond}.',
  },
  'en': {
    'molarMassQ': 'What is the molar mass of {name} ({formula})?',
    'molarMassE': 'M = {steps}. Add each element multiplied by its subscript.',
    'massMolesQ': 'How many moles are in {g} g of {name} ({formula})?',
    'massMolesE': 'n = m/M = {g} g ÷ {m} g/mol = {v} mol.',
    'massMassQ': 'What mass do {n} mol of {name} ({formula}) have?',
    'massMassE': 'm = n × M = {n} mol × {m} g/mol = {v} g.',
    'molarityQ':
        'You dissolve {n} mol of a solute and make the volume up to {v} mL. What is the molarity?',
    'molarityE':
        'Convert the volume to liters: {v} mL = {l} L. M = n/V = {n} mol ÷ {l} L = {c} M.',
    'molesFromMQ':
        'How many moles of solute are in {v} mL of a {m} M solution?',
    'molesFromME':
        'Convert the volume to liters: {v} mL = {l} L. n = M × V = {m} M × {l} L = {c} mol.',
    'dilutionC2Q':
        'You have a {c1} M solution and take {v1} mL. You dilute it to {v2} mL. What is the final concentration?',
    'dilutionC2E':
        'C₁V₁ = C₂V₂, so C₂ = C₁V₁/V₂ = {c1} × {v1} ÷ {v2} = {c} M.',
    'dilutionV1Q':
        'You want to prepare {v2} mL of a {c2} M solution from a {c1} M concentrated solution. What volume of the concentrated solution do you need?',
    'dilutionV1E':
        'C₁V₁ = C₂V₂, so V₁ = C₂V₂/C₁ = {c2} × {v2} ÷ {c1} = {v} mL.',
    'phQ': 'The pH of a solution with [H₃O⁺] = {mant}×10{sup} M is:',
    'phE':
        'pH = −log[H⁺] = −log({mant}×10{sup}) = {exp} − log {mant} = {p}.',
    'pohQ': 'The pOH of a solution with [OH⁻] = {mant}×10{sup} M is:',
    'pohE':
        'pOH = −log[OH⁻] = −log({mant}×10{sup}) = {exp} − log {mant} = {p}.',
    'phFromOhQ':
        'A solution has [OH⁻] = {mant}×10{sup} M. Its pH at 25 °C is:',
    'phFromOhE':
        'First pOH = −log({mant}×10{sup}) = {p}. At 25 °C, pH + pOH = 14, so pH = 14 − {p} = {c}.',
    'gasVolumeQ':
        'What volume do {n} mol of an ideal gas occupy at {t} °C and {p} atm?',
    'gasVolumeE':
        'Temperature must be in kelvin: T = {t} + 273.15 = {tk} K. V = nRT/P = {n} × 0.08206 × {tk} ÷ {p} = {v} L.',
    'gasMolesQ':
        'How many moles are in {v} L of an ideal gas at {t} °C and {p} atm?',
    'gasMolesE':
        'Temperature must be in kelvin: T = {t} + 273.15 = {tk} K. n = PV/RT = {p} × {v} ÷ (0.08206 × {tk}) = {n} mol.',
    'gasPressureQ':
        'What pressure do {n} mol of an ideal gas exert in {v} L at {t} °C?',
    'gasPressureE':
        'Temperature must be in kelvin: T = {t} + 273.15 = {tk} K. P = nRT/V = {n} × 0.08206 × {tk} ÷ {v} = {p} atm.',
    'stoichProductQ':
        'In the reaction {eq}, if {n} mol of {a} react, how many moles of {b} are formed?',
    'stoichReactantQ':
        'In the reaction {eq}, how many moles of {a} are needed to form {n} mol of {b}?',
    'stoichProductE':
        'The ratio {a}:{b} is {ca}:{cb}, so {n} mol × ({cb}/{ca}) = {v} mol.',
    'stoichReactantE':
        'The ratio {b}:{a} is {cb}:{ca}, so {n} mol × ({ca}/{cb}) = {v} mol.',
    'equilibQ':
        'For the reaction {eq}, with [{a}] = {ca} M, [{b}] = {cb} M and [{c}] = {cc} M, calculate the reaction quotient Qc.',
    'equilibE':
        'Qc = [{c}]^{cc} / ([{a}]^{ca} × [{b}]^{cb}) = {qc1} ÷ ({qa} × {qb}) = {q}. The exponents are the coefficients: forgetting them is the classic mistake.',
    'thermoQ':
        'How much heat (in kJ) is needed to warm {m} g of {name} by {dt} °C? (c = {c} J/g·°C)',
    'thermoE':
        'q = m·c·ΔT = {m} g × {c} J/g·°C × {dt} °C = {qj} J = {qk} kJ. Remember to convert J to kJ by dividing by 1000.',
    'periodicZQ': 'What is the atomic number of {name}?',
    'periodicZE':
        'The atomic number is the number of protons: {name} has Z = {z}.',
    'periodicSymbolQ': 'What is the chemical symbol of {name}?',
    'periodicSymbolE': 'The symbol of {name} is {symbol}.',
    'periodicMassQ': 'What is the approximate atomic mass of {name}?',
    'periodicMassE':
        'The atomic mass of {name} is {mass} u (approx. {m} u).',
    'periodicGroupQ': 'In which group of the periodic table is {name}?',
    'periodicGroupE': '{name} is in group {g} and period {p}.',
    'bondingGeometryQ':
        'What molecular geometry does {name} ({formula}) have?',
    'bondingGeometryE':
        '{name} ({formula}) has {geom} geometry according to VSEPR theory.',
    'bondingBondQ': 'What type of bond predominates in {name} ({formula})?',
    'bondingBondE': 'In {name} ({formula}) the {bond} bond predominates.',
  },
  'fr': {
    'molarMassQ': 'Quelle est la masse molaire du composé {formula} ? (nom : {name})',
    'molarMassE':
        'M = {steps}. Additionne chaque élément multiplié par son indice.',
    'massMolesQ': 'Combien de moles y a-t-il dans {g} g du composé {formula} ({name}) ?',
    'massMolesE': 'n = m/M = {g} g ÷ {m} g/mol = {v} mol.',
    'massMassQ': 'Quelle masse ont {n} mol du composé {formula} ({name}) ?',
    'massMassE': 'm = n × M = {n} mol × {m} g/mol = {v} g.',
    'molarityQ':
        'Tu dissous {n} mol d\'un soluté et tu complètes à {v} mL. Quelle est la molarité ?',
    'molarityE':
        'Passe le volume en litres : {v} mL = {l} L. M = n/V = {n} mol ÷ {l} L = {c} M.',
    'molesFromMQ':
        'Combien de moles de soluté y a-t-il dans {v} mL d\'une solution {m} M ?',
    'molesFromME':
        'Passe le volume en litres : {v} mL = {l} L. n = M × V = {m} M × {l} L = {c} mol.',
    'dilutionC2Q':
        'Tu as une solution {c1} M et tu prends {v1} mL. Tu dilues jusqu\'à {v2} mL. Quelle est la concentration finale ?',
    'dilutionC2E':
        'C₁V₁ = C₂V₂, donc C₂ = C₁V₁/V₂ = {c1} × {v1} ÷ {v2} = {c} M.',
    'dilutionV1Q':
        'Tu veux préparer {v2} mL d\'une solution {c2} M à partir d\'une solution concentrée {c1} M. Quel volume de la solution concentrée faut-il ?',
    'dilutionV1E':
        'C₁V₁ = C₂V₂, donc V₁ = C₂V₂/C₁ = {c2} × {v2} ÷ {c1} = {v} mL.',
    'phQ': 'Le pH d\'une solution avec [H₃O⁺] = {mant}×10{sup} M est :',
    'phE':
        'pH = −log[H⁺] = −log({mant}×10{sup}) = {exp} − log {mant} = {p}.',
    'pohQ': 'Le pOH d\'une solution avec [OH⁻] = {mant}×10{sup} M est :',
    'pohE':
        'pOH = −log[OH⁻] = −log({mant}×10{sup}) = {exp} − log {mant} = {p}.',
    'phFromOhQ':
        'Une solution a [OH⁻] = {mant}×10{sup} M. Son pH à 25 °C est :',
    'phFromOhE':
        'D\'abord pOH = −log({mant}×10{sup}) = {p}. À 25 °C, pH + pOH = 14, donc pH = 14 − {p} = {c}.',
    'gasVolumeQ':
        'Quel volume occupent {n} mol d\'un gaz parfait à {t} °C et {p} atm ?',
    'gasVolumeE':
        'La température doit être en kelvin : T = {t} + 273,15 = {tk} K. V = nRT/P = {n} × 0,08206 × {tk} ÷ {p} = {v} L.',
    'gasMolesQ':
        'Combien de moles y a-t-il dans {v} L d\'un gaz parfait à {t} °C et {p} atm ?',
    'gasMolesE':
        'La température doit être en kelvin : T = {t} + 273,15 = {tk} K. n = PV/RT = {p} × {v} ÷ (0,08206 × {tk}) = {n} mol.',
    'gasPressureQ':
        'Quelle pression exercent {n} mol d\'un gaz parfait dans {v} L à {t} °C ?',
    'gasPressureE':
        'La température doit être en kelvin : T = {t} + 273,15 = {tk} K. P = nRT/V = {n} × 0,08206 × {tk} ÷ {v} = {p} atm.',
    'stoichProductQ':
        'Dans la réaction {eq}, si {n} mol de {a} réagissent, combien de moles de {b} se forment ?',
    'stoichReactantQ':
        'Dans la réaction {eq}, combien de moles de {a} faut-il pour former {n} mol de {b} ?',
    'stoichProductE':
        'Le rapport {a}:{b} est {ca}:{cb}, donc {n} mol × ({cb}/{ca}) = {v} mol.',
    'stoichReactantE':
        'Le rapport {b}:{a} est {cb}:{ca}, donc {n} mol × ({ca}/{cb}) = {v} mol.',
    'equilibQ':
        'Pour la réaction {eq}, avec [{a}] = {ca} M, [{b}] = {cb} M et [{c}] = {cc} M, calcule le quotient de réaction Qc.',
    'equilibE':
        'Qc = [{c}]^{cc} / ([{a}]^{ca} × [{b}]^{cb}) = {qc1} ÷ ({qa} × {qb}) = {q}. Les exposants sont les coefficients : les oublier est l\'erreur classique.',
    'thermoQ':
        'Combien de chaleur (en kJ) faut-il pour chauffer {m} g ({name}) de {dt} °C ? (c = {c} J/g·°C)',
    'thermoE':
        'q = m·c·ΔT = {m} g × {c} J/g·°C × {dt} °C = {qj} J = {qk} kJ. Pense à passer de J à kJ en divisant par 1000.',
    'periodicZQ': 'Quel est le numéro atomique de {name} ?',
    'periodicZE':
        'Le numéro atomique est le nombre de protons : {name} a Z = {z}.',
    'periodicSymbolQ': 'Quel est le symbole chimique de {name} ?',
    'periodicSymbolE': 'Le symbole de {name} est {symbol}.',
    'periodicMassQ': 'Quelle est la masse atomique approximative de {name} ?',
    'periodicMassE':
        'La masse atomique de {name} est {mass} u (environ {m} u).',
    'periodicGroupQ':
        'Dans quel groupe du tableau périodique se trouve {name} ?',
    'periodicGroupE': '{name} est dans le groupe {g} et la période {p}.',
    'bondingGeometryQ':
        'Quelle géométrie moléculaire a {name} ({formula}) ?',
    'bondingGeometryE':
        '{name} ({formula}) a une géométrie {geom} selon la théorie VSEPR.',
    'bondingBondQ': 'Quel type de liaison prédomine dans {name} ({formula}) ?',
    'bondingBondE': 'Dans {name} ({formula}), c\'est la liaison {bond} qui prédomine.',
  },
  'it': {
    'molarMassQ': 'Qual è la massa molare di {name} ({formula})?',
    'molarMassE': 'M = {steps}. Somma ogni elemento moltiplicato per il suo indice.',
    'massMolesQ': 'Quante moli ci sono in {g} g di {name} ({formula})?',
    'massMolesE': 'n = m/M = {g} g ÷ {m} g/mol = {v} mol.',
    'massMassQ': 'Che massa hanno {n} mol di {name} ({formula})?',
    'massMassE': 'm = n × M = {n} mol × {m} g/mol = {v} g.',
    'molarityQ':
        'Sciogli {n} mol di un soluto e porti a volume {v} mL. Qual è la molarità?',
    'molarityE':
        'Passa il volume in litri: {v} mL = {l} L. M = n/V = {n} mol ÷ {l} L = {c} M.',
    'molesFromMQ':
        'Quante moli di soluto ci sono in {v} mL di una soluzione {m} M?',
    'molesFromME':
        'Passa il volume in litri: {v} mL = {l} L. n = M × V = {m} M × {l} L = {c} mol.',
    'dilutionC2Q':
        'Hai una soluzione {c1} M e ne prendi {v1} mL. La diluisci fino a {v2} mL. Qual è la concentrazione finale?',
    'dilutionC2E':
        'C₁V₁ = C₂V₂, quindi C₂ = C₁V₁/V₂ = {c1} × {v1} ÷ {v2} = {c} M.',
    'dilutionV1Q':
        'Vuoi preparare {v2} mL di una soluzione {c2} M a partire da una concentrata {c1} M. Che volume della concentrata ti serve?',
    'dilutionV1E':
        'C₁V₁ = C₂V₂, quindi V₁ = C₂V₂/C₁ = {c2} × {v2} ÷ {c1} = {v} mL.',
    'phQ': 'Il pH di una soluzione con [H₃O⁺] = {mant}×10{sup} M è:',
    'phE':
        'pH = −log[H⁺] = −log({mant}×10{sup}) = {exp} − log {mant} = {p}.',
    'pohQ': 'Il pOH di una soluzione con [OH⁻] = {mant}×10{sup} M è:',
    'pohE':
        'pOH = −log[OH⁻] = −log({mant}×10{sup}) = {exp} − log {mant} = {p}.',
    'phFromOhQ':
        'Una soluzione ha [OH⁻] = {mant}×10{sup} M. Il suo pH a 25 °C è:',
    'phFromOhE':
        'Prima pOH = −log({mant}×10{sup}) = {p}. A 25 °C, pH + pOH = 14, quindi pH = 14 − {p} = {c}.',
    'gasVolumeQ':
        'Che volume occupano {n} mol di un gas ideale a {t} °C e {p} atm?',
    'gasVolumeE':
        'La temperatura va in kelvin: T = {t} + 273,15 = {tk} K. V = nRT/P = {n} × 0,08206 × {tk} ÷ {p} = {v} L.',
    'gasMolesQ':
        'Quante moli ci sono in {v} L di un gas ideale a {t} °C e {p} atm?',
    'gasMolesE':
        'La temperatura va in kelvin: T = {t} + 273,15 = {tk} K. n = PV/RT = {p} × {v} ÷ (0,08206 × {tk}) = {n} mol.',
    'gasPressureQ':
        'Che pressione esercitano {n} mol di un gas ideale in {v} L a {t} °C?',
    'gasPressureE':
        'La temperatura va in kelvin: T = {t} + 273,15 = {tk} K. P = nRT/V = {n} × 0,08206 × {tk} ÷ {v} = {p} atm.',
    'stoichProductQ':
        'Nella reazione {eq}, se reagiscono {n} mol di {a}, quante moli di {b} si formano?',
    'stoichReactantQ':
        'Nella reazione {eq}, quante moli di {a} servono per formare {n} mol di {b}?',
    'stoichProductE':
        'Il rapporto {a}:{b} è {ca}:{cb}, quindi {n} mol × ({cb}/{ca}) = {v} mol.',
    'stoichReactantE':
        'Il rapporto {b}:{a} è {cb}:{ca}, quindi {n} mol × ({ca}/{cb}) = {v} mol.',
    'equilibQ':
        'Per la reazione {eq}, con [{a}] = {ca} M, [{b}] = {cb} M e [{c}] = {cc} M, calcola il quoziente di reazione Qc.',
    'equilibE':
        'Qc = [{c}]^{cc} / ([{a}]^{ca} × [{b}]^{cb}) = {qc1} ÷ ({qa} × {qb}) = {q}. Gli esponenti sono i coefficienti: dimenticarli è l\'errore classico.',
    'thermoQ':
        'Quanto calore (in kJ) serve per scaldare {m} g di {name} di {dt} °C? (c = {c} J/g·°C)',
    'thermoE':
        'q = m·c·ΔT = {m} g × {c} J/g·°C × {dt} °C = {qj} J = {qk} kJ. Ricorda di passare da J a kJ dividendo per 1000.',
    'periodicZQ': 'Qual è il numero atomico di {name}?',
    'periodicZE':
        'Il numero atomico è il numero di protoni: {name} ha Z = {z}.',
    'periodicSymbolQ': 'Qual è il simbolo chimico di {name}?',
    'periodicSymbolE': 'Il simbolo di {name} è {symbol}.',
    'periodicMassQ': 'Qual è la massa atomica approssimata di {name}?',
    'periodicMassE':
        'La massa atomica di {name} è {mass} u (circa {m} u).',
    'periodicGroupQ':
        'In quale gruppo della tavola periodica si trova {name}?',
    'periodicGroupE': '{name} è nel gruppo {g} e nel periodo {p}.',
    'bondingGeometryQ':
        'Che geometria molecolare ha {name} ({formula})?',
    'bondingGeometryE':
        '{name} ({formula}) ha geometria {geom} secondo la teoria VSEPR.',
    'bondingBondQ': 'Che tipo di legame predomina in {name} ({formula})?',
    'bondingBondE': 'In {name} ({formula}) predomina il legame {bond}.',
  },
  'pt': {
    'molarMassQ': 'Qual é a massa molar de {name} ({formula})?',
    'molarMassE': 'M = {steps}. Some cada elemento multiplicado pelo seu índice.',
    'massMolesQ': 'Quantos mols há em {g} g de {name} ({formula})?',
    'massMolesE': 'n = m/M = {g} g ÷ {m} g/mol = {v} mol.',
    'massMassQ': 'Que massa têm {n} mol de {name} ({formula})?',
    'massMassE': 'm = n × M = {n} mol × {m} g/mol = {v} g.',
    'molarityQ':
        'Você dissolve {n} mol de um soluto e completa até {v} mL. Qual é a molaridade?',
    'molarityE':
        'Passe o volume para litros: {v} mL = {l} L. M = n/V = {n} mol ÷ {l} L = {c} M.',
    'molesFromMQ':
        'Quantos mols de soluto há em {v} mL de uma solução {m} M?',
    'molesFromME':
        'Passe o volume para litros: {v} mL = {l} L. n = M × V = {m} M × {l} L = {c} mol.',
    'dilutionC2Q':
        'Você tem uma solução {c1} M e toma {v1} mL. Você dilui até {v2} mL. Qual é a concentração final?',
    'dilutionC2E':
        'C₁V₁ = C₂V₂, então C₂ = C₁V₁/V₂ = {c1} × {v1} ÷ {v2} = {c} M.',
    'dilutionV1Q':
        'Você quer preparar {v2} mL de uma solução {c2} M a partir de uma concentrada {c1} M. Que volume da concentrada você precisa?',
    'dilutionV1E':
        'C₁V₁ = C₂V₂, então V₁ = C₂V₂/C₁ = {c2} × {v2} ÷ {c1} = {v} mL.',
    'phQ': 'O pH de uma solução com [H₃O⁺] = {mant}×10{sup} M é:',
    'phE':
        'pH = −log[H⁺] = −log({mant}×10{sup}) = {exp} − log {mant} = {p}.',
    'pohQ': 'O pOH de uma solução com [OH⁻] = {mant}×10{sup} M é:',
    'pohE':
        'pOH = −log[OH⁻] = −log({mant}×10{sup}) = {exp} − log {mant} = {p}.',
    'phFromOhQ':
        'Uma solução tem [OH⁻] = {mant}×10{sup} M. Seu pH a 25 °C é:',
    'phFromOhE':
        'Primeiro pOH = −log({mant}×10{sup}) = {p}. A 25 °C, pH + pOH = 14, então pH = 14 − {p} = {c}.',
    'gasVolumeQ':
        'Que volume ocupam {n} mol de um gás ideal a {t} °C e {p} atm?',
    'gasVolumeE':
        'A temperatura vai em kelvin: T = {t} + 273,15 = {tk} K. V = nRT/P = {n} × 0,08206 × {tk} ÷ {p} = {v} L.',
    'gasMolesQ':
        'Quantos mols há em {v} L de um gás ideal a {t} °C e {p} atm?',
    'gasMolesE':
        'A temperatura vai em kelvin: T = {t} + 273,15 = {tk} K. n = PV/RT = {p} × {v} ÷ (0,08206 × {tk}) = {n} mol.',
    'gasPressureQ':
        'Que pressão exercem {n} mol de um gás ideal em {v} L a {t} °C?',
    'gasPressureE':
        'A temperatura vai em kelvin: T = {t} + 273,15 = {tk} K. P = nRT/V = {n} × 0,08206 × {tk} ÷ {v} = {p} atm.',
    'stoichProductQ':
        'Na reação {eq}, se reagem {n} mol de {a}, quantos mols de {b} se formam?',
    'stoichReactantQ':
        'Na reação {eq}, quantos mols de {a} são necessários para formar {n} mol de {b}?',
    'stoichProductE':
        'A proporção {a}:{b} é {ca}:{cb}, então {n} mol × ({cb}/{ca}) = {v} mol.',
    'stoichReactantE':
        'A proporção {b}:{a} é {cb}:{ca}, então {n} mol × ({ca}/{cb}) = {v} mol.',
    'equilibQ':
        'Para a reação {eq}, com [{a}] = {ca} M, [{b}] = {cb} M e [{c}] = {cc} M, calcule o quociente de reação Qc.',
    'equilibE':
        'Qc = [{c}]^{cc} / ([{a}]^{ca} × [{b}]^{cb}) = {qc1} ÷ ({qa} × {qb}) = {q}. Os expoentes são os coeficientes: esquecê-los é o erro clássico.',
    'thermoQ':
        'Quanto calor (em kJ) é preciso para aquecer {m} g de {name} em {dt} °C? (c = {c} J/g·°C)',
    'thermoE':
        'q = m·c·ΔT = {m} g × {c} J/g·°C × {dt} °C = {qj} J = {qk} kJ. Lembre-se de passar de J para kJ dividindo por 1000.',
    'periodicZQ': 'Qual é o número atômico de {name}?',
    'periodicZE':
        'O número atômico é a quantidade de prótons: {name} tem Z = {z}.',
    'periodicSymbolQ': 'Qual é o símbolo químico de {name}?',
    'periodicSymbolE': 'O símbolo de {name} é {symbol}.',
    'periodicMassQ': 'Qual é a massa atômica aproximada de {name}?',
    'periodicMassE':
        'A massa atômica de {name} é {mass} u (aprox. {m} u).',
    'periodicGroupQ':
        'Em que grupo da tabela periódica está {name}?',
    'periodicGroupE': '{name} está no grupo {g} e no período {p}.',
    'bondingGeometryQ':
        'Que geometria molecular tem {name} ({formula})?',
    'bondingGeometryE':
        '{name} ({formula}) tem geometria {geom} segundo a teoria VSEPR.',
    'bondingBondQ': 'Que tipo de ligação predomina em {name} ({formula})?',
    'bondingBondE': 'Em {name} ({formula}) predomina a ligação {bond}.',
  },
  'ru': {
    'molarMassQ': 'Чему равна молярная масса соединения {formula} ({name})?',
    'molarMassE': 'M = {steps}. Сложите каждый элемент, умноженный на его индекс.',
    'massMolesQ': 'Сколько моль содержится в {g} г соединения {formula} ({name})?',
    'massMolesE': 'n = m/M = {g} г ÷ {m} г/моль = {v} моль.',
    'massMassQ': 'Какую массу имеют {n} моль соединения {formula} ({name})?',
    'massMassE': 'm = n × M = {n} моль × {m} г/моль = {v} г.',
    'molarityQ':
        'Вы растворяете {n} моль растворённого вещества и доводите объём до {v} мл. Чему равна молярность?',
    'molarityE':
        'Переведите объём в литры: {v} мл = {l} л. M = n/V = {n} моль ÷ {l} л = {c} M.',
    'molesFromMQ':
        'Сколько моль растворённого вещества содержится в {v} мл раствора {m} M?',
    'molesFromME':
        'Переведите объём в литры: {v} мл = {l} л. n = M × V = {m} M × {l} л = {c} моль.',
    'dilutionC2Q':
        'У вас есть раствор {c1} M, вы берёте {v1} мл. Вы разбавляете его до {v2} мл. Чему равна конечная концентрация?',
    'dilutionC2E':
        'C₁V₁ = C₂V₂, значит C₂ = C₁V₁/V₂ = {c1} × {v1} ÷ {v2} = {c} M.',
    'dilutionV1Q':
        'Вы хотите приготовить {v2} мл раствора {c2} M из концентрированного раствора {c1} M. Какой объём концентрированного раствора нужен?',
    'dilutionV1E':
        'C₁V₁ = C₂V₂, значит V₁ = C₂V₂/C₁ = {c2} × {v2} ÷ {c1} = {v} мл.',
    'phQ': 'Чему равен pH раствора с [H₃O⁺] = {mant}×10{sup} M?',
    'phE':
        'pH = −log[H⁺] = −log({mant}×10{sup}) = {exp} − log {mant} = {p}.',
    'pohQ': 'Чему равен pOH раствора с [OH⁻] = {mant}×10{sup} M?',
    'pohE':
        'pOH = −log[OH⁻] = −log({mant}×10{sup}) = {exp} − log {mant} = {p}.',
    'phFromOhQ':
        'В растворе [OH⁻] = {mant}×10{sup} M. Чему равен его pH при 25 °C?',
    'phFromOhE':
        'Сначала pOH = −log({mant}×10{sup}) = {p}. При 25 °C pH + pOH = 14, значит pH = 14 − {p} = {c}.',
    'gasVolumeQ':
        'Какой объём занимают {n} моль идеального газа при {t} °C и {p} атм?',
    'gasVolumeE':
        'Температура должна быть в кельвинах: T = {t} + 273,15 = {tk} K. V = nRT/P = {n} × 0,08206 × {tk} ÷ {p} = {v} л.',
    'gasMolesQ':
        'Сколько моль содержится в {v} л идеального газа при {t} °C и {p} атм?',
    'gasMolesE':
        'Температура должна быть в кельвинах: T = {t} + 273,15 = {tk} K. n = PV/RT = {p} × {v} ÷ (0,08206 × {tk}) = {n} моль.',
    'gasPressureQ':
        'Какое давление создают {n} моль идеального газа в объёме {v} л при {t} °C?',
    'gasPressureE':
        'Температура должна быть в кельвинах: T = {t} + 273,15 = {tk} K. P = nRT/V = {n} × 0,08206 × {tk} ÷ {v} = {p} атм.',
    'stoichProductQ':
        'В реакции {eq}, если прореагировало {n} моль {a}, сколько моль {b} образуется?',
    'stoichReactantQ':
        'В реакции {eq}, сколько моль {a} нужно, чтобы получить {n} моль {b}?',
    'stoichProductE':
        'Соотношение {a}:{b} равно {ca}:{cb}, значит {n} моль × ({cb}/{ca}) = {v} моль.',
    'stoichReactantE':
        'Соотношение {b}:{a} равно {cb}:{ca}, значит {n} моль × ({ca}/{cb}) = {v} моль.',
    'equilibQ':
        'Для реакции {eq}, при [{a}] = {ca} M, [{b}] = {cb} M и [{c}] = {cc} M, вычислите коэффициент реакции Qc.',
    'equilibE':
        'Qc = [{c}]^{cc} / ([{a}]^{ca} × [{b}]^{cb}) = {qc1} ÷ ({qa} × {qb}) = {q}. Показатели степени — это коэффициенты: забыть их — классическая ошибка.',
    'thermoQ':
        'Сколько теплоты (в кДж) нужно, чтобы нагреть {m} г ({name}) на {dt} °C? (c = {c} Дж/г·°C)',
    'thermoE':
        'q = m·c·ΔT = {m} г × {c} Дж/г·°C × {dt} °C = {qj} Дж = {qk} кДж. Не забудьте перевести Дж в кДж, разделив на 1000.',
    'periodicZQ': 'Чему равен атомный номер {name}?',
    'periodicZE':
        'Атомный номер — это число протонов: у {name} Z = {z}.',
    'periodicSymbolQ': 'Какой химический символ у {name}?',
    'periodicSymbolE': 'Символ {name} — {symbol}.',
    'periodicMassQ': 'Чему примерно равна атомная масса {name}?',
    'periodicMassE':
        'Атомная масса {name} равна {mass} а.е.м. (примерно {m} а.е.м.).',
    'periodicGroupQ': 'В какой группе таблицы Менделеева находится {name}?',
    'periodicGroupE': '{name} находится в группе {g} и периоде {p}.',
    'bondingGeometryQ':
        'Какую молекулярную геометрию имеет {name} ({formula})?',
    'bondingGeometryE':
        '{name} ({formula}) имеет {geom} геометрию согласно теории VSEPR.',
    'bondingBondQ': 'Какой тип связи преобладает в {name} ({formula})?',
    'bondingBondE': 'В {name} ({formula}) преобладает {bond} связь.',
  },
};

const Map<String, Map<String, String>> _genSubstances = {
  'en': {
    'agua': 'water',
    'cloruro de sodio': 'sodium chloride',
    'dióxido de carbono': 'carbon dioxide',
    'amoníaco': 'ammonia',
    'metano': 'methane',
    'ácido clorhídrico': 'hydrochloric acid',
    'hidróxido de sodio': 'sodium hydroxide',
    'cloruro de potasio': 'potassium chloride',
    'carbonato de calcio': 'calcium carbonate',
    'ácido sulfúrico': 'sulfuric acid',
    'hidróxido de calcio': 'calcium hydroxide',
    'sulfato de aluminio': 'aluminum sulfate',
    'glucosa': 'glucose',
    'sulfato de magnesio': 'magnesium sulfate',
    'óxido de hierro(III)': 'iron(III) oxide',
    'sulfato de cobre(II)': 'copper(II) sulfate',
    'aluminio': 'aluminum',
    'hierro': 'iron',
    'oxígeno': 'oxygen',
    'trifluoruro de boro': 'boron trifluoride',
    'cloruro de hidrógeno': 'hydrogen chloride',
  },
  'fr': {
    'agua': 'eau',
    'cloruro de sodio': 'chlorure de sodium',
    'dióxido de carbono': 'dioxyde de carbone',
    'amoníaco': 'ammoniac',
    'metano': 'méthane',
    'ácido clorhídrico': 'acide chlorhydrique',
    'hidróxido de sodio': 'hydroxyde de sodium',
    'cloruro de potasio': 'chlorure de potassium',
    'carbonato de calcio': 'carbonate de calcium',
    'ácido sulfúrico': 'acide sulfurique',
    'hidróxido de calcio': 'hydroxyde de calcium',
    'sulfato de aluminio': 'sulfate d\'aluminium',
    'glucosa': 'glucose',
    'sulfato de magnesio': 'sulfate de magnésium',
    'óxido de hierro(III)': 'oxyde de fer(III)',
    'sulfato de cobre(II)': 'sulfate de cuivre(II)',
    'aluminio': 'aluminium',
    'hierro': 'fer',
    'oxígeno': 'oxygène',
    'trifluoruro de boro': 'trifluorure de bore',
    'cloruro de hidrógeno': 'chlorure d\'hydrogène',
  },
  'it': {
    'agua': 'acqua',
    'cloruro de sodio': 'cloruro di sodio',
    'dióxido de carbono': 'diossido di carbonio',
    'amoníaco': 'ammoniaca',
    'metano': 'metano',
    'ácido clorhídrico': 'acido cloridrico',
    'hidróxido de sodio': 'idrossido di sodio',
    'cloruro de potasio': 'cloruro di potassio',
    'carbonato de calcio': 'carbonato di calcio',
    'ácido sulfúrico': 'acido solforico',
    'hidróxido de calcio': 'idrossido di calcio',
    'sulfato de aluminio': 'solfato di alluminio',
    'glucosa': 'glucosio',
    'sulfato de magnesio': 'solfato di magnesio',
    'óxido de hierro(III)': 'ossido di ferro(III)',
    'sulfato de cobre(II)': 'solfato di rame(II)',
    'aluminio': 'alluminio',
    'hierro': 'ferro',
    'oxígeno': 'ossigeno',
    'trifluoruro de boro': 'trifluoruro di boro',
    'cloruro de hidrógeno': 'cloruro di idrogeno',
  },
  'pt': {
    'agua': 'água',
    'cloruro de sodio': 'cloreto de sódio',
    'dióxido de carbono': 'dióxido de carbono',
    'amoníaco': 'amônia',
    'metano': 'metano',
    'ácido clorhídrico': 'ácido clorídrico',
    'hidróxido de sodio': 'hidróxido de sódio',
    'cloruro de potasio': 'cloreto de potássio',
    'carbonato de calcio': 'carbonato de cálcio',
    'ácido sulfúrico': 'ácido sulfúrico',
    'hidróxido de calcio': 'hidróxido de cálcio',
    'sulfato de aluminio': 'sulfato de alumínio',
    'glucosa': 'glicose',
    'sulfato de magnesio': 'sulfato de magnésio',
    'óxido de hierro(III)': 'óxido de ferro(III)',
    'sulfato de cobre(II)': 'sulfato de cobre(II)',
    'aluminio': 'alumínio',
    'hierro': 'ferro',
    'oxígeno': 'oxigênio',
    'trifluoruro de boro': 'trifluoreto de boro',
    'cloruro de hidrógeno': 'cloreto de hidrogênio',
  },
  'ru': {
    'agua': 'вода',
    'cloruro de sodio': 'хлорид натрия',
    'dióxido de carbono': 'углекислый газ',
    'amoníaco': 'аммиак',
    'metano': 'метан',
    'ácido clorhídrico': 'соляная кислота',
    'hidróxido de sodio': 'гидроксид натрия',
    'cloruro de potasio': 'хлорид калия',
    'carbonato de calcio': 'карбонат кальция',
    'ácido sulfúrico': 'серная кислота',
    'hidróxido de calcio': 'гидроксид кальция',
    'sulfato de aluminio': 'сульфат алюминия',
    'glucosa': 'глюкоза',
    'sulfato de magnesio': 'сульфат магния',
    'óxido de hierro(III)': 'оксид железа(III)',
    'sulfato de cobre(II)': 'сульфат меди(II)',
    'aluminio': 'алюминий',
    'hierro': 'железо',
    'oxígeno': 'кислород',
    'trifluoruro de boro': 'трифторид бора',
    'cloruro de hidrógeno': 'хлорид водорода',
  },
};

const Map<String, Map<String, String>> _genGeometries = {
  'en': {
    'Tetraédrica': 'Tetrahedral',
    'Piramidal trigonal': 'Trigonal pyramidal',
    'Angular': 'Bent',
    'Lineal': 'Linear',
    'Plana trigonal': 'Trigonal planar',
  },
  'fr': {
    'Tetraédrica': 'Tétraédrique',
    'Piramidal trigonal': 'Pyramidale trigonale',
    'Angular': 'Coudée',
    'Lineal': 'Linéaire',
    'Plana trigonal': 'Plane trigonale',
  },
  'it': {
    'Tetraédrica': 'Tetraedrica',
    'Piramidal trigonal': 'Piramidale trigonale',
    'Angular': 'Angolare',
    'Lineal': 'Lineare',
    'Plana trigonal': 'Planare trigonale',
  },
  'pt': {
    'Tetraédrica': 'Tetraédrica',
    'Piramidal trigonal': 'Piramidal trigonal',
    'Angular': 'Angular',
    'Lineal': 'Linear',
    'Plana trigonal': 'Planar trigonal',
  },
  'ru': {
    'Tetraédrica': 'Тетраэдрическая',
    'Piramidal trigonal': 'Тригонально-пирамидальная',
    'Angular': 'Угловая',
    'Lineal': 'Линейная',
    'Plana trigonal': 'Тригонально-плоская',
  },
};

const Map<String, Map<String, String>> _genBonds = {
  'en': {
    'Iónico': 'Ionic',
    'Covalente': 'Covalent',
    'Covalente polar': 'Polar covalent',
    'Metálico': 'Metallic',
    'De hidrógeno': 'Hydrogen bond',
  },
  'fr': {
    'Iónico': 'Ionique',
    'Covalente': 'Covalente',
    'Covalente polar': 'Covalente polaire',
    'Metálico': 'Métallique',
    'De hidrógeno': 'Liaison hydrogène',
  },
  'it': {
    'Iónico': 'Ionico',
    'Covalente': 'Covalente',
    'Covalente polar': 'Covalente polare',
    'Metálico': 'Metallico',
    'De hidrógeno': 'Legame a idrogeno',
  },
  'pt': {
    'Iónico': 'Iônico',
    'Covalente': 'Covalente',
    'Covalente polar': 'Covalente polar',
    'Metálico': 'Metálico',
    'De hidrógeno': 'Ligação de hidrogênio',
  },
  'ru': {
    'Iónico': 'Ионная',
    'Covalente': 'Ковалентная',
    'Covalente polar': 'Полярная ковалентная',
    'Metálico': 'Металлическая',
    'De hidrógeno': 'Водородная связь',
  },
};
