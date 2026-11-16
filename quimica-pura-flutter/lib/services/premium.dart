// Premium REAL (pago manual por Transfermóvil).
// Lógica pura: sin Firebase, comprobable en tests.
//
// Alcance (2026-11-16, orden de Kristian: al final TODO va en la
// app compilada): el Premium y la prueba funcionan en web Y en
// móvil. La puerta kIsWeb se quitó: este archivo solo calcula y
// quien lo llama decide si algo se aplica, sin mirar la plataforma.
//
// Planes: '1m' (30 días), '3m' (90 días), '12m' (365 días).
// Precios de EJEMPLO (CUP): 250 / 600 / 1800. Los precios reales
// los lee RemoteTuning de Firestore settings/app (los cambia el
// Admin); estos valores son solo el fallback local cuando el
// servidor no trae nada o trae algo roto.

/// Banderín en vivo que pone PremiumService: true
/// mientras el usuario tiene ACCESO COMPLETO vigente, es decir,
/// Premium pagado O prueba gratuita de 3 días (2026-11-15,
/// Kristian). Las pantallas lo leen para el candado (la prueba
/// SÍ abre el contenido). Los corazones ilimitados NO lo usan:
/// desde 2026-11-16 solo el Premium PAGADO tiene ∞ (la prueba
/// deja los 10 corazones al día, como gratis) — para eso está
/// [hasPaidPremium].
class PremiumFlags {
  PremiumFlags._();

  /// True con acceso completo vigente (Premium
  /// pagado o prueba gratuita). El vencimiento y el plan de
  /// abajo siguen siendo SOLO del Premium pagado.
  static bool isPremium = false;

  /// True con Premium PAGADO vigente (sin prueba):
  /// solo este da los corazones ilimitados (Kristian 2026-11-16).
  /// Lo pone PremiumService en _recomputePremium(); lo lee
  /// ProgressService y el chip de vidas.
  static bool hasPaidPremium = false;

  /// Fecha de vencimiento vigente, o null sin Premium.
  static DateTime? expiresAt;

  /// Plan vigente ('1m' | '3m' | '12m'), o null sin Premium.
  static String? plan;

  /// Solo para tests (y para el reset del servicio): vuelve a sin
  /// Premium. Sin anotación @visibleForTesting a propósito: la
  /// llama también PremiumService.resetForTests().
  static void resetForTests() {
    isPremium = false;
    hasPaidPremium = false;
    expiresAt = null;
    plan = null;
  }
}

/// Un plan Premium: id, duración en días y precio de ejemplo (CUP).
class PremiumPlan {
  const PremiumPlan({
    required this.id,
    required this.days,
    required this.monthsLabel,
    required this.examplePrice,
  });

  /// '1m' | '3m' | '12m'.
  final String id;

  /// Duración en días (30 / 90 / 365).
  final int days;

  /// Etiqueta corta: '1 mes' / '3 meses' / '12 meses'.
  final String monthsLabel;

  /// Precio de EJEMPLO en CUP (fallback local).
  final int examplePrice;
}

const List<PremiumPlan> premiumPlans = <PremiumPlan>[
  PremiumPlan(id: '1m', days: 30, monthsLabel: '1 mes', examplePrice: 250),
  PremiumPlan(id: '3m', days: 90, monthsLabel: '3 meses', examplePrice: 600),
  PremiumPlan(
      id: '12m', days: 365, monthsLabel: '12 meses', examplePrice: 1800),
];

/// Plan por id, o null si el id no es un plan conocido.
PremiumPlan? premiumPlanById(String? id) {
  for (final p in premiumPlans) {
    if (p.id == id) return p;
  }
  return null;
}

/// ¿Es un id de plan válido ('1m' | '3m' | '12m')?
bool isValidPremiumPlan(String? id) => premiumPlanById(id) != null;

/// Fecha de vencimiento de un plan que empieza en [start].
/// null si el plan no es válido.
DateTime? premiumExpiryFor(String? planId, DateTime start) {
  final plan = premiumPlanById(planId);
  if (plan == null) return null;
  return start.add(Duration(days: plan.days));
}

/// ¿Está vigente el Premium con este vencimiento? [now] inyectable
/// para tests. null o pasado = sin Premium.
bool isPremiumActive(DateTime? expiresAt, {DateTime? now}) {
  if (expiresAt == null) return false;
  return expiresAt.isAfter(now ?? DateTime.now());
}

/// Tiempo que queda hasta el vencimiento (cero o negativo si ya
/// venció o no hay vencimiento).
Duration premiumRemaining(DateTime? expiresAt, {DateTime? now}) {
  if (expiresAt == null) return Duration.zero;
  final left = expiresAt.difference(now ?? DateTime.now());
  return left.isNegative ? Duration.zero : left;
}

/// Contador EN VIVO: '12 d · 04:05:06' con días, o '04:05:06'
/// cuando queda menos de un día. Cero cuando no queda nada.
String formatPremiumCountdown(Duration remaining) {
  if (remaining.isNegative) remaining = Duration.zero;
  final days = remaining.inDays;
  final hours = remaining.inHours % 24;
  final minutes = remaining.inMinutes % 60;
  final seconds = remaining.inSeconds % 60;
  final clock =
      '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  if (days > 0) return '$days d · $clock';
  return clock;
}

/// Fecha corta 'dd/mm/aaaa' para el vencimiento.
String formatPremiumDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Precios por plan leídos de settings/app ('planPrices'), con los
/// precios de ejemplo como fallback. Solo acepta enteros sanos
/// (> 0 y < 1.000.000 CUP); lo que falte o venga roto mantiene el
/// ejemplo. Nunca lanza.
Map<String, int> parsePlanPrices(Object? raw) {
  final out = <String, int>{
    for (final p in premiumPlans) p.id: p.examplePrice,
  };
  if (raw is! Map) return out;
  for (final p in premiumPlans) {
    final v = raw[p.id];
    if (v is num) {
      final price = v.toInt();
      if (price > 0 && price < 1000000) out[p.id] = price;
    }
  }
  return out;
}

/// Precio de un plan (del mapa ya parseado, o del ejemplo).
int premiumPriceFor(String planId, Map<String, int> prices) =>
    prices[planId] ?? premiumPlanById(planId)?.examplePrice ?? 0;

/// Precio en CUP con separador de miles español: 250 → '250',
/// 600 → '600', 1800 → '1.800'. Para que el paywall enseñe
/// '1.800 CUP' como la maqueta, no '1800 CUP'.
String formatCupPrice(int price) {
  final digits = price.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return (price < 0 ? '-' : '') + out.toString();
}

/// Datos de Transfermóvil leídos de settings/app, con fallbacks de
/// EJEMPLO. [isExample] dice si el valor es el ejemplo local (el
/// Admin aún no configuró el real): la UI debe decir EJEMPLO.
class TransfermovilDetails {
  const TransfermovilDetails({
    required this.card,
    required this.number,
    required this.details,
    required this.isExample,
  });

  /// Número de TARJETA destino (ejemplo '9225 1234 5678 9012').
  final String card;

  /// Número de teléfono / Transfermóvil (ejemplo '5356519431').
  final String number;

  /// Detalles del pago (ejemplo 'Titular: Quemia · Concepto:
  /// Premium Quemia').
  final String details;

  /// True si alguno de los valores es el ejemplo local.
  final bool isExample;
}

const String kExampleTransfermovilCard = '9225 1234 5678 9012';
const String kExampleTransfermovilNumber = '5356519431';
const String kExamplePaymentDetails =
    'Titular: Quemia · Concepto: Premium Quemia';

/// Parsea los 3 campos de Transfermóvil de settings/app. Un campo
/// vacío o ausente usa su ejemplo y marca [isExample] = true.
TransfermovilDetails parseTransfermovilDetails(Map<String, dynamic> settings) {
  String read(String key, String fallback) {
    final v = settings[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return fallback;
  }

  final card = read('transfermovilCard', kExampleTransfermovilCard);
  final number = read('transfermovilNumber', kExampleTransfermovilNumber);
  final details = read('paymentDetails', kExamplePaymentDetails);
  final isExample = card == kExampleTransfermovilCard ||
      number == kExampleTransfermovilNumber ||
      details == kExamplePaymentDetails;
  return TransfermovilDetails(
    card: card,
    number: number,
    details: details,
    isExample: isExample,
  );
}

/// Secciones con candado en web para el usuario gratis. La Tabla
/// periódica NO está aquí: queda GRATIS siempre, nunca Premium.
/// 'temas' es la lista de temas dentro de Aprender (al bloquear
/// Aprender, los Temas quedan bloqueados con ella).
enum PremiumLockedSection { aprender, resolver, temas, misErrores }

/// ¿Esta sección lleva candado? Solo en web y solo sin Premium.
/// En móvil siempre false: la app se comporta como ahora.
bool premiumSectionLocked({
  required bool isPremium,
  required PremiumLockedSection section,
}) {
  if (isPremium) return false;
  switch (section) {
    case PremiumLockedSection.aprender:
    case PremiumLockedSection.resolver:
    case PremiumLockedSection.temas:
    case PremiumLockedSection.misErrores:
      return true;
  }
}

/// ¿La sesión actual cuenta como "inició sesión" para Premium?
/// True con Google enlazado o con correo+contraseña enlazado; el
/// usuario anónimo (invitado) es false.
bool premiumIsSignedIn({
  required bool googleLinked,
  required bool emailLinked,
}) =>
    googleLinked || emailLinked;

/// ¿El paywall exige iniciar sesión antes de abrirse? Sí, sin
/// sesión (web y móvil: el Premium exige iniciar sesión).
bool premiumPaywallNeedsSignIn({
  required bool isSignedIn,
}) =>
    !isSignedIn;

/// ¿Corazones ilimitados? Solo en web y solo con Premium
/// PAGADO: `isPremium` aquí es el Premium pagado (no la prueba).
/// La prueba de 3 días abre el contenido pero deja los 10
/// corazones al día, como gratis (Kristian 2026-11-16).
bool premiumUnlimitedLives({required bool isPremium}) => isPremium;
