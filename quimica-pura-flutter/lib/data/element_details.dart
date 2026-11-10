// Datos extra de cada elemento (estándar IUPAC): estados de oxidación
// más comunes, electronegatividad de Pauling, estado de agregación a
// temperatura ambiente (25 °C) y configuración electrónica.
//
// La configuración se genera con el orden de Madelung (n + l) y las
// excepciones conocidas (Cr, Cu, Nb, Mo, Ru, Rh, Pd, Ag, La, Ce, Gd,
// Pt, Au y varios actínidos). Los estados de oxidación y la
// electronegatividad son los valores estándar de las tablas habituales;
// para los elementos sin dato fiable, la electronegatividad es null.

/// Estados de oxidación comunes, por número atómico.
const Map<int, String> oxidationStates = {
  1: '−1, +1',
  2: '0',
  3: '+1',
  4: '+2',
  5: '+3',
  6: '−4, +2, +4',
  7: '−3, +1, +2, +3, +4, +5',
  8: '−2, −1, +2',
  9: '−1',
  10: '0',
  11: '+1',
  12: '+2',
  13: '+3',
  14: '−4, +2, +4',
  15: '−3, +3, +5',
  16: '−2, +2, +4, +6',
  17: '−1, +1, +3, +5, +7',
  18: '0',
  19: '+1',
  20: '+2',
  21: '+3',
  22: '+2, +3, +4',
  23: '+2, +3, +4, +5',
  24: '+2, +3, +6',
  25: '+2, +3, +4, +6, +7',
  26: '+2, +3',
  27: '+2, +3',
  28: '+2, +3',
  29: '+1, +2',
  30: '+2',
  31: '+1, +3',
  32: '+2, +4',
  33: '−3, +3, +5',
  34: '−2, +4, +6',
  35: '−1, +1, +3, +5, +7',
  36: '+2',
  37: '+1',
  38: '+2',
  39: '+3',
  40: '+4',
  41: '+3, +5',
  42: '+3, +4, +5, +6',
  43: '+4, +7',
  44: '+2, +3, +4, +6, +8',
  45: '+2, +3, +4',
  46: '+2, +4',
  47: '+1, +2',
  48: '+2',
  49: '+1, +3',
  50: '+2, +4',
  51: '−3, +3, +5',
  52: '−2, +4, +6',
  53: '−1, +1, +3, +5, +7',
  54: '+2, +4, +6, +8',
  55: '+1',
  56: '+2',
  57: '+3',
  58: '+3, +4',
  59: '+3, +4',
  60: '+2, +3',
  61: '+3',
  62: '+2, +3',
  63: '+2, +3',
  64: '+3',
  65: '+3, +4',
  66: '+2, +3',
  67: '+3',
  68: '+3',
  69: '+2, +3',
  70: '+2, +3',
  71: '+3',
  72: '+4',
  73: '+3, +4, +5',
  74: '+4, +5, +6',
  75: '+4, +6, +7',
  76: '+2, +3, +4, +6, +8',
  77: '+2, +3, +4, +6',
  78: '+2, +4',
  79: '+1, +3',
  80: '+1, +2',
  81: '+1, +3',
  82: '+2, +4',
  83: '+3, +5',
  84: '+2, +4',
  85: '−1, +1, +3, +5, +7',
  86: '0, +2',
  87: '+1',
  88: '+2',
  89: '+3',
  90: '+4',
  91: '+4, +5',
  92: '+3, +4, +5, +6',
  93: '+3, +4, +5, +6, +7',
  94: '+3, +4, +5, +6, +7',
  95: '+3, +4, +5, +6',
  96: '+3, +4',
  97: '+3, +4',
  98: '+2, +3, +4',
  99: '+2, +3',
  100: '+2, +3',
  101: '+2, +3',
  102: '+2, +3',
  103: '+3',
  104: '+4',
  105: '+5',
  106: '+6',
  107: '+7',
  108: '+8',
  109: '+3, +9',
  110: '+2',
  111: '+1',
  112: '+2',
  113: '+1, +3',
  114: '+2, +4',
  115: '+1, +3',
  116: '+2, +4',
  117: '−1, +1, +3, +5',
  118: '0',
};

/// Electronegatividad de Pauling (escala estándar). Null = sin dato
/// fiable en las tablas habituales (gases nobles y sintéticos pesados).
const Map<int, double> electronegativity = {
  1: 2.20,
  3: 0.98,
  4: 1.57,
  5: 2.04,
  6: 2.55,
  7: 3.04,
  8: 3.44,
  9: 3.98,
  11: 0.93,
  12: 1.31,
  13: 1.61,
  14: 1.90,
  15: 2.19,
  16: 2.58,
  17: 3.16,
  19: 0.82,
  20: 1.00,
  21: 1.36,
  22: 1.54,
  23: 1.63,
  24: 1.66,
  25: 1.55,
  26: 1.83,
  27: 1.88,
  28: 1.91,
  29: 1.90,
  30: 1.65,
  31: 1.81,
  32: 2.01,
  33: 2.18,
  34: 2.55,
  35: 2.96,
  36: 3.00,
  37: 0.82,
  38: 0.95,
  39: 1.22,
  40: 1.33,
  41: 1.60,
  42: 2.16,
  43: 1.90,
  44: 2.20,
  45: 2.28,
  46: 2.20,
  47: 1.93,
  48: 1.69,
  49: 1.78,
  50: 1.96,
  51: 2.05,
  52: 2.10,
  53: 2.66,
  54: 2.60,
  55: 0.79,
  56: 0.89,
  57: 1.10,
  58: 1.12,
  59: 1.13,
  60: 1.14,
  61: 1.13,
  62: 1.17,
  63: 1.20,
  64: 1.20,
  65: 1.20,
  66: 1.22,
  67: 1.23,
  68: 1.24,
  69: 1.25,
  70: 1.10,
  71: 1.27,
  72: 1.30,
  73: 1.50,
  74: 2.36,
  75: 1.90,
  76: 2.20,
  77: 2.20,
  78: 2.28,
  79: 2.54,
  80: 2.00,
  81: 1.62,
  82: 2.33,
  83: 2.02,
  84: 2.00,
  85: 2.20,
  87: 0.70,
  88: 0.90,
  89: 1.10,
  90: 1.30,
  91: 1.50,
  92: 1.38,
  93: 1.36,
  94: 1.28,
  95: 1.30,
  96: 1.30,
};

/// Estado de agregación a temperatura ambiente (25 °C, 1 atm).
String elementState(int z) {
  const gases = {1, 7, 8, 9, 10, 17, 18, 36, 54, 86};
  if (gases.contains(z)) return 'Gas';
  if (z == 35 || z == 80) return 'Líquido';
  return 'Sólido';
}

/// Configuración electrónica en notación abreviada con gas noble
/// (p. ej. "[Ar] 3d6 4s2"). Generada por el orden de Madelung con las
/// excepciones conocidas.
String electronConfig(int z) {
  if (z == 1) return '1s1';
  if (z == 2) return '1s2';
  const exceptions = <int, String>{
    24: '[Ar] 3d5 4s1',
    29: '[Ar] 3d10 4s1',
    41: '[Kr] 4d4 5s1',
    42: '[Kr] 4d5 5s1',
    44: '[Kr] 4d7 5s1',
    45: '[Kr] 4d8 5s1',
    46: '[Kr] 4d10',
    47: '[Kr] 4d10 5s1',
    57: '[Xe] 5d1 6s2',
    58: '[Xe] 4f1 5d1 6s2',
    64: '[Xe] 4f7 5d1 6s2',
    78: '[Xe] 4f14 5d9 6s1',
    79: '[Xe] 4f14 5d10 6s1',
    89: '[Rn] 6d1 7s2',
    90: '[Rn] 6d2 7s2',
    91: '[Rn] 5f2 6d1 7s2',
    92: '[Rn] 5f3 6d1 7s2',
    93: '[Rn] 5f4 6d1 7s2',
    96: '[Rn] 5f7 6d1 7s2',
    103: '[Rn] 5f14 7s2 7p1',
  };
  final exc = exceptions[z];
  if (exc != null) return exc;

  // Orden de llenado de Madelung: (subnivel, capacidad).
  const order = <({String sub, int cap})>[
    (sub: '1s', cap: 2),
    (sub: '2s', cap: 2),
    (sub: '2p', cap: 6),
    (sub: '3s', cap: 2),
    (sub: '3p', cap: 6),
    (sub: '4s', cap: 2),
    (sub: '3d', cap: 10),
    (sub: '4p', cap: 6),
    (sub: '5s', cap: 2),
    (sub: '4d', cap: 10),
    (sub: '5p', cap: 6),
    (sub: '6s', cap: 2),
    (sub: '4f', cap: 14),
    (sub: '5d', cap: 10),
    (sub: '6p', cap: 6),
    (sub: '7s', cap: 2),
    (sub: '5f', cap: 14),
    (sub: '6d', cap: 10),
    (sub: '7p', cap: 6),
  ];
  const noble = <(int z, String sym)>[
    (2, 'He'),
    (10, 'Ne'),
    (18, 'Ar'),
    (36, 'Kr'),
    (54, 'Xe'),
    (86, 'Rn'),
  ];

  final counts = <String, int>{};
  var remaining = z;
  for (final e in order) {
    if (remaining <= 0) break;
    final n = remaining < e.cap ? remaining : e.cap;
    counts[e.sub] = n;
    remaining -= n;
  }

  var core = '';
  var coreZ = 0;
  for (final (nz, sym) in noble) {
    if (nz < z) {
      core = sym;
      coreZ = nz;
    }
  }

  // Subniveles de valencia: los que quedan fuera del gas noble.
  var cumulative = 0;
  final valence = <String>[];
  for (final e in order) {
    final c = counts[e.sub] ?? 0;
    if (c == 0) continue;
    cumulative += c;
    if (cumulative <= coreZ) continue; // dentro del gas noble
    valence.add('${e.sub}$c');
  }
  // Orden de escritura estándar: por n y luego por l (s, p, d, f).
  int nOf(String s) => int.parse(s[0]);
  int lOf(String s) => 'spdf'.indexOf(s[1]);
  valence.sort((a, b) {
    final d = nOf(a) - nOf(b);
    return d != 0 ? d : lOf(a) - lOf(b);
  });
  if (core.isEmpty) return valence.join(' ');
  return '[$core] ${valence.join(' ')}';
}
