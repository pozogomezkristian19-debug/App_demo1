// Temas de estudio: mismo contenido que la app web original.
import '../models.dart';

const List<StudyTopic> topics = [
  StudyTopic(
    slug: 'estequiometria',
    title: 'Estequiometría y el mol',
    level: 'Química general I',
    summary: [
      'El mol es la unidad de cantidad de sustancia: 1 mol contiene 6.022×10²³ entidades (número de Avogadro). La masa molar (g/mol) conecta el mundo microscópico con lo que pesas en el laboratorio.',
      'Toda reacción ajustada es una receta en moles: los coeficientes estequiométricos dan la proporción exacta en la que reaccionan y se forman las sustancias. La ruta universal es: masa → moles (÷ masa molar) → moles del objetivo (× proporción) → masa o volumen (× masa molar).',
      'El reactivo limitante es el que se agota primero y fija la cantidad máxima de producto. El rendimiento porcentual compara lo obtenido en la práctica con el rendimiento teórico calculado.',
    ],
    formulas: [
      Formula(name: 'Moles desde masa', expr: 'n = m / M', note: 'm en gramos, M = masa molar en g/mol'),
      Formula(name: 'Partículas', expr: 'N = n · Nₐ', note: 'Nₐ = 6.022×10²³ mol⁻¹'),
      Formula(name: 'Rendimiento', expr: '% rend. = (real / teórico) × 100', note: 'El real se mide; el teórico se calcula'),
      Formula(name: 'Pureza', expr: 'm pura = m muestra × (% pureza / 100)', note: 'Corrige antes de pasar a moles'),
    ],
    exampleTitle: '¿Cuántos gramos de CO₂ se forman al quemar 8.0 g de CH₄?',
    exampleSteps: [
      'Ajusta la reacción: CH₄ + 2 O₂ → CO₂ + 2 H₂O. La proporción CH₄ : CO₂ es 1 : 1.',
      'Masa molar del CH₄: 12.011 + 4(1.008) = 16.04 g/mol.',
      'Pasa a moles: n(CH₄) = 8.0 g ÷ 16.04 g/mol = 0.499 mol.',
      'Por la proporción 1:1, n(CO₂) = 0.499 mol.',
      'Masa molar del CO₂: 12.011 + 2(15.999) = 44.01 g/mol.',
      'Vuelve a gramos: m = 0.499 mol × 44.01 g/mol = 21.9 g.',
    ],
    exampleAnswer: 'Se forman ≈ 21.9 g de CO₂.',
    errors: [
      'Usar la masa molar de un elemento diatómico (O₂ = 32.00) como si fuera atómica (O = 16.00).',
      'Olvidar ajustar la ecuación antes de usar los coeficientes.',
      'Confundir el reactivo en exceso con el limitante: el limitante es el que da MENOS producto.',
      'Redondear en pasos intermedios y arrastrar el error hasta el resultado.',
    ],
    tip: 'Escribe siempre la ruta masa → moles → moles → masa antes de tocar la calculadora. Si un problema de estequiometría no pasa por moles, casi seguro está mal planteado.',
  ),
  StudyTopic(
    slug: 'gases',
    title: 'Gases ideales',
    level: 'Química general I',
    summary: [
      'Un gas ideal cumple PV = nRT: las partículas no interactúan y su volumen propio es despreciable. Es una excelente aproximación a presiones bajas y temperaturas altas, lejos de la condensación.',
      'La constante R vale 0.08206 L·atm·mol⁻¹·K⁻¹ o 8.314 J·mol⁻¹·K⁻¹: elige la que case con tus unidades. La temperatura SIEMPRE va en kelvin.',
      'De la ecuación se derivan las leyes de Boyle (P∝1/V), Charles (V∝T) y Avogadro (V∝n), y la ley de Dalton para mezclas: la presión total es la suma de las presiones parciales.',
    ],
    formulas: [
      Formula(name: 'Gas ideal', expr: 'P·V = n·R·T', note: 'T siempre en kelvin: K = °C + 273.15'),
      Formula(name: 'Densidad de un gas', expr: 'd = P·M / (R·T)', note: 'Útil para identificar gases desconocidos'),
      Formula(name: 'Dalton', expr: 'P total = P₁ + P₂ + …', note: 'Pᵢ = xᵢ · P total (fracción molar)'),
      Formula(name: 'Condiciones normales', expr: '0 °C y 1 atm → 22.41 L/mol', note: 'Volumen molar a TPN (0 °C, 1 atm)'),
    ],
    exampleTitle: '¿Qué volumen ocupan 0.50 mol de N₂ a 27 °C y 1.2 atm?',
    exampleSteps: [
      'Convierte la temperatura: T = 27 + 273.15 = 300.15 K ≈ 300 K.',
      'Despeja V de la ecuación del gas ideal: V = nRT / P.',
      'Sustituye con R = 0.08206 L·atm·mol⁻¹·K⁻¹: V = (0.50 × 0.08206 × 300) / 1.2.',
      'Calcula: numerador = 12.31; V = 12.31 / 1.2 = 10.3 L.',
    ],
    exampleAnswer: 'El gas ocupa ≈ 10.3 L.',
    errors: [
      'Usar °C en lugar de K: es el error número uno en exámenes de gases.',
      'Mezclar unidades de R: si P está en kPa, R = 8.314 exige V en m³.',
      'Aplicar la ley ideal a un gas cerca de su punto de licuefacción sin cuestionarlo.',
    ],
    tip: 'Antes de calcular, pregúntate si el resultado tiene sentido: a TPN, 1 mol ≈ 22.4 L. Si tu respuesta da 0.02 L para medio mol, revisa las unidades.',
  ),
  StudyTopic(
    slug: 'disoluciones',
    title: 'Disoluciones y concentración',
    level: 'Química general I–II',
    summary: [
      'La molaridad (mol de soluto por litro de DISOLUCIÓN) es la unidad reina en el laboratorio porque se mide con matraces aforados. Ojo: litro de disolución final, no de disolvente añadido.',
      'La molalidad (mol/kg de disolvente) no depende de la temperatura; la fracción molar y el % en masa tampoco. En diluciones se conserva la cantidad de soluto: M₁V₁ = M₂V₂.',
      'Al diluir, el volumen aumenta y la concentración baja en la misma proporción; los moles de soluto antes y después son idénticos.',
    ],
    formulas: [
      Formula(name: 'Molaridad', expr: 'M = n soluto / V disolución (L)', note: 'V es el volumen final aforado'),
      Formula(name: 'Dilución', expr: 'M₁·V₁ = M₂·V₂', note: 'Se conservan los moles de soluto'),
      Formula(name: 'Molalidad', expr: 'm = n soluto / kg disolvente', note: 'Independiente de la temperatura'),
      Formula(name: '% en masa', expr: '% = (m soluto / m disolución) × 100', note: 'Base para ppm y ppb'),
    ],
    exampleTitle: 'Preparas 250 mL de NaCl 0.200 M. ¿Cuánta sal necesitas?',
    exampleSteps: [
      'Pasa el volumen a litros: 250 mL = 0.250 L.',
      'Moles necesarios: n = M × V = 0.200 mol/L × 0.250 L = 0.0500 mol.',
      'Masa molar del NaCl: 22.99 + 35.45 = 58.44 g/mol.',
      'Masa: m = 0.0500 mol × 58.44 g/mol = 2.92 g.',
      'Procedimiento: pesa 2.92 g, disuelve en poca agua, transfiere al matraz de 250 mL y afora hasta la marca.',
    ],
    exampleAnswer: 'Necesitas 2.92 g de NaCl, aforando a 250 mL.',
    errors: [
      'Añadir 250 mL de agua al soluto en vez de aforar HASTA 250 mL de disolución.',
      'Usar M₁V₁ = M₂V₂ en una reacción (eso es dilución, no neutralización).',
      'Confundir molaridad con molalidad cuando el problema da kg de disolvente.',
    ],
    tip: 'En cada problema subraya qué volumen te dan: ¿de disolución o de disolvente? Esa sola decisión separa la molaridad de la molalidad.',
  ),
  StudyTopic(
    slug: 'acido-base',
    title: 'Ácido-base y pH',
    level: 'Química general II',
    summary: [
      'El pH = −log[H₃O⁺] mide la acidez en escala logarítmica: cada unidad de pH es un factor 10 en concentración. A 25 °C, pH + pOH = 14.00 y el agua pura tiene pH 7.',
      'Un ácido fuerte (HCl, HNO₃, H₂SO₄ en su primer protón) se disocia por completo: [H₃O⁺] = concentración inicial. Un ácido débil solo se disocia parcialmente y exige usar Ka con la tabla ICE.',
      'Las disoluciones reguladoras (ácido débil + su base conjugada) resisten cambios de pH y se calculan con Henderson-Hasselbalch: pH = pKa + log([base]/[ácido]).',
    ],
    formulas: [
      Formula(name: 'pH', expr: 'pH = −log[H₃O⁺]', note: 'Y [H₃O⁺] = 10^(−pH)'),
      Formula(name: 'Relación a 25 °C', expr: 'pH + pOH = 14.00', note: 'Viene de Kw = 1.0×10⁻¹⁴'),
      Formula(name: 'Ácido débil', expr: 'Ka = x² / (C − x)', note: 'Si x/C < 5%, aproxima C − x ≈ C'),
      Formula(name: 'Henderson-Hasselbalch', expr: 'pH = pKa + log([A⁻]/[HA])', note: 'Para reguladoras ácido débil/base conjugada'),
    ],
    exampleTitle: 'Calcula el pH de una disolución de HCl 0.025 M.',
    exampleSteps: [
      'El HCl es un ácido fuerte: se disocia al 100%, así que [H₃O⁺] = 0.025 M.',
      'Aplica la definición: pH = −log(0.025).',
      'log(0.025) = log(2.5×10⁻²) = −1.60.',
      'pH = −(−1.60) = 1.60.',
    ],
    exampleAnswer: 'El pH es 1.60 (disolución claramente ácida).',
    errors: [
      'Calcular el pH de un ácido débil como si fuera fuerte, sin usar Ka.',
      'Dar el pH con más decimales que cifras significativas tienen los datos.',
      'Olvidar que al mezclar ácido y base primero reaccionan entre sí: calcula los moles que sobran antes del pH.',
      'Suponer que pH 7 es neutro a cualquier temperatura (solo a 25 °C).',
    ],
    tip: 'Clasifica antes de calcular: ¿fuerte o débil? ¿solo o mezcla? ¿reguladora? El 80% de los ejercicios de pH se resuelve eligiendo bien la casilla, no la fórmula.',
  ),
  StudyTopic(
    slug: 'equilibrio',
    title: 'Equilibrio químico',
    level: 'Química general II',
    summary: [
      'En el equilibrio las velocidades directa e inversa se igualan y las concentraciones se mantienen constantes, no iguales. La constante Kc relaciona las concentraciones en equilibrio elevadas a sus coeficientes estequiométricos.',
      'La tabla ICE (Inicial, Cambio, Equilibrio) organiza cualquier cálculo: el cambio siempre respeta la proporción estequiométrica. El cociente Q comparado con K predice el sentido del desplazamiento: Q < K → avanza hacia productos; Q > K → hacia reactivos.',
      'El principio de Le Chatelier predice la respuesta a perturbaciones: añadir reactivo, cambiar el volumen o la temperatura desplaza el equilibrio en el sentido que contrarresta el cambio. Los sólidos y líquidos puros NO aparecen en Kc.',
    ],
    formulas: [
      Formula(name: 'Constante Kc', expr: 'Kc = [C]ᶜ[D]ᵈ / [A]ᵃ[B]ᵇ', note: 'Solo especies en disolución o gas'),
      Formula(name: 'Kp y Kc', expr: 'Kp = Kc (RT)^Δn', note: 'Δn = moles gas productos − reactivos'),
      Formula(name: 'Cociente Q', expr: 'Q < K → productos · Q > K → reactivos', note: 'Q tiene la misma forma que K, fuera del equilibrio'),
    ],
    exampleTitle: 'Para N₂O₄ ⇌ 2 NO₂, Kc = 5.9×10⁻³ a 25 °C. Si [N₂O₄] inicial es 0.20 M, halla [NO₂] en el equilibrio.',
    exampleSteps: [
      'Tabla ICE: inicial [N₂O₄] = 0.20, [NO₂] = 0. Cambio: −x y +2x. Equilibrio: 0.20 − x y 2x.',
      'Plantea Kc: (2x)² / (0.20 − x) = 5.9×10⁻³.',
      'Como Kc es pequeña, aproxima 0.20 − x ≈ 0.20: 4x² / 0.20 = 5.9×10⁻³ → x² = 2.95×10⁻⁴.',
      'x = 0.017 M. Comprueba la aproximación: 0.017/0.20 = 8.6%… supera el 5%, así que conviene resolver la cuadrática.',
      'Cuadrática: 4x² + 5.9×10⁻³x − 1.18×10⁻³ = 0 → x = 0.0164 M.',
      '[NO₂] = 2x = 0.033 M y [N₂O₄] = 0.184 M.',
    ],
    exampleAnswer: '[NO₂] ≈ 0.033 M en el equilibrio (con la aproximación daría 0.034 M, muy cercano).',
    errors: [
      'Incluir sólidos o líquidos puros en la expresión de Kc.',
      'Olvidar elevar las concentraciones a los coeficientes estequiométricos.',
      'Usar concentraciones iniciales en Kc en lugar de las de equilibrio.',
      'Aceptar una raíz negativa o mayor que la concentración inicial al resolver la cuadrática.',
    ],
    tip: 'Si K es muy pequeña (< 10⁻³ aprox.), el cambio x suele ser despreciable frente a la concentración inicial: aproxima, calcula y VERIFICA que x < 5% del valor inicial.',
  ),
  StudyTopic(
    slug: 'termo-cinetica',
    title: 'Termoquímica y cinética',
    level: 'Química general II',
    summary: [
      'La entalpía de reacción (ΔH) se puede calcular con la ley de Hess (suma de pasos), con entalpías de formación: ΔH° = Σ n·ΔHf°(productos) − Σ n·ΔHf°(reactivos), o rompiendo y formando enlaces. Signo negativo = exotérmica.',
      'La entropía (ΔS) crece con el desorden: más moles de gas, mayor volumen, disolución de sólidos. La espontaneidad la decide ΔG = ΔH − TΔS: ΔG < 0, espontánea.',
      'En cinética, la ley de velocidad v = k[A]ᵐ[B]ⁿ se determina experimentalmente; los órdenes no salen de la ecuación ajustada. La energía de activación (Arrhenius) explica por qué la temperatura acelera tanto las reacciones.',
    ],
    formulas: [
      Formula(name: 'Hess / formación', expr: 'ΔH° = Σ prod. − Σ react.', note: 'Siempre multiplicando por los coeficientes'),
      Formula(name: 'Gibbs', expr: 'ΔG = ΔH − T·ΔS', note: 'ΔG < 0 → espontánea; T en kelvin'),
      Formula(name: 'Ley de velocidad', expr: 'v = k [A]ᵐ [B]ⁿ', note: 'm y n se determinan experimentalmente'),
      Formula(name: 'Arrhenius', expr: 'k = A · e^(−Ea/RT)', note: 'Al subir T, k crece exponencialmente'),
      Formula(name: 'Primer orden', expr: 'ln[A] = ln[A]₀ − k·t', note: 'Y t½ = ln 2 / k, independiente de [A]₀'),
    ],
    exampleTitle: 'ΔH° de combustión del CH₄ con ΔHf°: CO₂ = −393.5, H₂O(l) = −285.8, CH₄ = −74.8 kJ/mol.',
    exampleSteps: [
      'Reacción: CH₄ + 2 O₂ → CO₂ + 2 H₂O. ΔHf°(O₂) = 0 (elemento en su forma estándar).',
      'Productos: (−393.5) + 2(−285.8) = −965.1 kJ.',
      'Reactivos: (−74.8) + 2(0) = −74.8 kJ.',
      'ΔH° = −965.1 − (−74.8) = −890.3 kJ por mol de CH₄.',
    ],
    exampleAnswer: 'ΔH° ≈ −890 kJ/mol: combustión fuertemente exotérmica.',
    errors: [
      'Olvidar multiplicar ΔHf° por los coeficientes estequiométricos.',
      'Asignar ΔHf° ≠ 0 a un elemento en estado estándar (O₂, N₂, C grafito valen 0).',
      'Deducir los órdenes de reacción de los coeficientes de la ecuación global.',
      'Usar °C en ΔG = ΔH − TΔS.',
    ],
    tip: 'En termoquímica, el signo ES la mitad de la respuesta: antes de entregar, di en voz alta «exotérmica/endotérmica, espontánea/no» y comprueba que coincide con tu signo.',
  ),
];

const List<ExamTip> generalTips = [
  ExamTip(
    title: 'Método para cualquier problema',
    body: 'Datos → incógnita → fórmula → sustitución → resultado con unidades. Escribe siempre ese orden; si te atascas, el paso que falta salta a la vista.',
  ),
  ExamTip(
    title: 'Convierte antes de sustituir',
    body: 'Convierte todo a las unidades del SI o a las de la fórmula antes de sustituir: mL → L, °C → K, g → mol. Al final, pregúntate si el resultado tiene sentido: un pH de 25 o una masa molar de 3 g/mol para el H₂SO₄ son imposibles.',
  ),
  ExamTip(
    title: 'Estequiometría sin tropezar',
    body: 'La ecuación ajustada manda: los coeficientes son la proporción en moles, nunca en gramos. Para el reactivo limitante no compares moles a secas: divide los moles de cada reactivo entre su coeficiente. El cociente menor es el limitante. El rendimiento nunca puede superar el 100 %. Si te sale 130 %, has invertido real y teórico.',
  ),
  ExamTip(
    title: 'Gases y disoluciones',
    body: 'En PV = nRT la temperatura va siempre en kelvin. Es el error más frecuente de todo el temario. En diluciones, C₁V₁ = C₂V₂ solo necesita que ambos volúmenes estén en la misma unidad; no hace falta pasarlos a litros. Molaridad: el volumen es el de la disolución final, no el del disolvente añadido.',
  ),
  ExamTip(
    title: 'Ácido–base de cabeza',
    body: 'Si [H⁺] = 10⁻ⁿ, el pH es directamente n. Si es a×10⁻ⁿ, el pH está entre n−1 y n. pH + pOH = 14 solo a 25 °C. Fuera de esa temperatura, Kw cambia. Diluir un ácido 10 veces sube el pH en 1 unidad, pero un ácido nunca se vuelve básico por dilución: el pH se acerca a 7 sin cruzarlo.',
  ),
  ExamTip(
    title: 'Estrategia el día del examen',
    body: 'Primera vuelta: responde solo lo que sepas hacer sin pensar. Marca lo dudoso y sigue; el tiempo vale más que una pregunta. En preguntas de cálculo, aunque no llegues al final, deja escrito el planteamiento: en la universidad el procedimiento suele dar puntos parciales. Reserva los últimos 5 minutos para revisar unidades, signos (ΔH, cargas) y órdenes de magnitud. Dibuja una tabla ICE cuando un problema de equilibrio o de gases se resista.',
  ),
  ExamTip(
    title: 'Análisis dimensional siempre',
    body: 'Escribe cada cantidad con su unidad y cancela unidades como si fueran factores algebraicos. Si al final no obtienes la unidad que buscabas, el planteamiento está mal: la unidad es tu detector de errores gratuito.',
  ),
  ExamTip(
    title: 'Nunca redondees a mitad de camino',
    body: 'Guarda todos los decimales en la calculadora y redondea solo el resultado final según las cifras significativas de los datos (normalmente 3). Redondear en cada paso es la causa silenciosa de la mayoría de los «casi» en los exámenes.',
  ),
  ExamTip(
    title: 'La estimación antes que el cálculo',
    body: 'Antes de operar, estima el orden de magnitud: ¿el pH debe ser < 7? ¿El volumen, más o menos que 22 L? Si el resultado contradice la estimación, busca el error antes de seguir.',
  ),
  ExamTip(
    title: 'Lee el enunciado dos veces',
    body: 'La primera para saber qué pasa; la segunda subrayando datos y la pregunta exacta. «¿Masa de producto o moles?» y «¿disolución o disolvente?» se deciden en esa segunda lectura.',
  ),
];

const List<Map<String, String>> formulary = [
  {'group': 'Cantidad de sustancia', 'name': 'Moles', 'expr': 'n = m / M'},
  {'group': 'Cantidad de sustancia', 'name': 'Partículas', 'expr': 'N = n · 6.022×10²³'},
  {'group': 'Cantidad de sustancia', 'name': 'Rendimiento', 'expr': '% = (real / teórico) × 100'},
  {'group': 'Gases', 'name': 'Gas ideal', 'expr': 'PV = nRT'},
  {'group': 'Gases', 'name': 'R', 'expr': '0.08206 L·atm·mol⁻¹·K⁻¹ = 8.314 J·mol⁻¹·K⁻¹'},
  {'group': 'Gases', 'name': 'Dalton', 'expr': 'P total = Σ Pᵢ · Pᵢ = xᵢ·P total'},
  {'group': 'Gases', 'name': 'Densidad', 'expr': 'd = PM / RT'},
  {'group': 'Disoluciones', 'name': 'Molaridad', 'expr': 'M = n / V(L)'},
  {'group': 'Disoluciones', 'name': 'Molalidad', 'expr': 'm = n / kg disolvente'},
  {'group': 'Disoluciones', 'name': 'Dilución', 'expr': 'M₁V₁ = M₂V₂'},
  {'group': 'Ácido-base', 'name': 'pH', 'expr': 'pH = −log[H₃O⁺]'},
  {'group': 'Ácido-base', 'name': 'Kw (25 °C)', 'expr': '[H₃O⁺][OH⁻] = 1.0×10⁻¹⁴'},
  {'group': 'Ácido-base', 'name': 'Henderson-Hasselbalch', 'expr': 'pH = pKa + log([A⁻]/[HA])'},
  {'group': 'Equilibrio', 'name': 'Kc', 'expr': 'Kc = Π[productos]ᶜ / Π[reactivos]ᵃ'},
  {'group': 'Equilibrio', 'name': 'Kp', 'expr': 'Kp = Kc(RT)^Δn'},
  {'group': 'Termo y cinética', 'name': 'Gibbs', 'expr': 'ΔG = ΔH − TΔS'},
  {'group': 'Termo y cinética', 'name': 'Calorimetría', 'expr': 'q = m·c·ΔT'},
  {'group': 'Termo y cinética', 'name': 'Velocidad', 'expr': 'v = k[A]ᵐ[B]ⁿ'},
  {'group': 'Termo y cinética', 'name': 'Primer orden', 'expr': 't½ = ln 2 / k'},
];
