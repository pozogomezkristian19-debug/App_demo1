// Paywall Premium (SOLO WEB): pago manual por Transfermóvil.
//
// Flujo (el de la maqueta 'Pantallas del pago por Transfermóvil'):
//   1. Planes: comparación Gratis vs Premium + 1 / 3 / 12 meses.
//      Precios de settings/app (RemoteTuning.planPrices), con los
//      ejemplos 250 / 600 / 1800 CUP como fallback; si el Admin los
//      cambia, el paywall se actualiza AL INSTANTE (settingsVersion).
//   2. Pago: instrucciones de Transfermóvil (monto del plan +
//      número de TARJETA destino + detalles, todos de settings/app
//      con fallbacks de ejemplo — la UI dice EJEMPLO mientras el
//      Admin no configure el real) → el usuario paga → sube la
//      captura (con vista previa) → se crea la solicitud.
//   3. Estado 'En revisión': la app escucha EN VIVO la solicitud
//      y el documento del usuario; al aprobar en Admin pasa a
//      Premium AL INSTANTE sin reabrir.
// Resultado aprobado: '¡Ya tienes Premium!' + vencimiento +
// contador EN VIVO (días · hh:mm:ss, tick cada segundo); al llegar
// a cero el Premium se quita solo. Resultado denegado: 'Pago
// denegado' + la razón que escribió el admin.
//
// La captura va SOLO por Firestore (base64 en screenshotData):
// el bucket de Storage no existe (404 verificado 2026-11-15).
// screenshotUrl y screenshotPath quedan en ''.
//
// Diseño Duolingo: sólido + labio 4 pt, Nunito, 17 pt extra-bold
// MAYÚSCULAS solo en etiquetas de BOTONES. Sin anuncios en ningún
// lado. La app habla como ORGANIZACIÓN.
//
// Correcciones 2026-11-15 (Kristian, "Si exactamente"):
//   * Pantalla FIJA, sin deslizar: Column compacta, sin ListView.
//   * La Tabla periódica NO lleva fila en la comparación (sigue
//     gratis, solo no aparece ahí).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/accent.dart';
import '../services/localization.dart';
import '../services/premium.dart';
import '../services/premium_screenshot.dart';
import '../services/premium_service.dart';
import '../services/remote_tuning.dart';
import '../services/trial.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/premium_countdown.dart';

/// Pantalla del paywall Premium. Solo se abre en web (los candados
/// y la fila Premium de Cuenta, que solo existen en web, son sus
/// únicas entradas).
class PremiumPaywallScreen extends StatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  /// 0 = planes, 1 = pago + captura, 2 = estado de la solicitud.
  int _step = 0;
  String _selectedPlan = '1m';
  PremiumScreenshot? _screenshot;
  bool _picking = false;
  bool _submitting = false;
  String? _error;

  /// Premium PAGADO vigente (sin contar la prueba gratuita): solo
  /// con él se enseña "¡Ya tienes Premium!" y se salta a su
  /// estado. Con la prueba activa se enseñan los planes + el
  /// aviso de prueba, no el resultado.
  bool get _isPremium => PremiumService.hasPaidPremium;
  PaymentRequest? get _request => PremiumService.latestRequestNotifier.value;

  @override
  void initState() {
    super.initState();
    // Si ya hay una solicitud en revisión, abrir directo en su estado.
    final req = _request;
    if (_isPremium) {
      _step = 2;
    } else if (req != null && req.isPending) {
      _step = 2;
    } else if (req != null && req.isDenied) {
      _step = 2;
    }
  }

  Future<void> _pickScreenshot() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    final shot = await pickAndEncodeScreenshot();
    if (!mounted) return;
    setState(() {
      _picking = false;
      if (shot != null) _screenshot = shot;
    });
  }

  Future<void> _submit() async {
    if (_screenshot == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await PremiumService.instance.submitPaymentRequest(
      plan: _selectedPlan,
      screenshotData: _screenshot!.dataUrl,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      setState(() => _step = 2);
    } else {
      // Error concreto (2026-11-16, Kristian: el envío falló con
      // la conexión lenta): decir QUÉ pasó, no solo "revisa tu
      // conexión".
      final reason = PremiumService.instance.lastSubmitError;
      setState(() => _error = switch (reason) {
            'timeout' =>
              'La conexión va lenta y no se pudo enviar. Inténtalo de nuevo.',
            'denied' =>
              'No se pudo enviar: cierra sesión y vuelve a entrar, e inténtalo de nuevo.',
            'no-session' =>
              'No se pudo enviar: inicia sesión e inténtalo de nuevo.',
            _ =>
              'No se pudo enviar la solicitud. Revisa tu conexión e inténtalo de nuevo.',
          });
    }
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Se repinta con CUALQUIER cambio Premium: aprobación en vivo,
    // estado de la solicitud, precios del Admin y la prueba.
    return AnimatedBuilder(
      animation: Listenable.merge([
        PremiumService.premiumNotifier,
        PremiumService.expiresNotifier,
        PremiumService.latestRequestNotifier,
        PremiumService.settingsVersion,
        TrialService.trialNotifier,
        TrialService.trialDaysLeftNotifier,
      ]),
      builder: (context, _) {
        // "¡Ya tienes Premium!" SOLO con Premium pagado: con la
        // prueba activa se enseñan los planes + el aviso.
        final isPremium = PremiumService.hasPaidPremium;
        final request = PremiumService.latestRequestNotifier.value;
        final showApproved = isPremium;
        final showDenied =
            !isPremium && request != null && request.isDenied;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Premium'),
            centerTitle: true,
          ),
          // Pantalla FIJA, sin deslizar (2026-11-15, Kristian, como
          // las pantallas del mockup): Column compacta, sin
          // ListView ni scroll. Todo el contenido cabe en una
          // pantalla de teléfono en vertical.
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showApproved) ..._approvedBody(scheme),
                if (!showApproved && showDenied) ..._deniedBody(scheme),
                if (!showApproved && !showDenied) ...[
                  if (_step == 0) ..._plansBody(scheme, isDark),
                  if (_step == 1) ..._payBody(scheme, isDark),
                  if (_step == 2) ..._pendingBody(scheme),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Resultado: aprobado ----

  List<Widget> _approvedBody(ColorScheme scheme) {
    final expires = PremiumService.expiresNotifier.value;
    return [
      const SizedBox(height: 8),
      _ResultHeader(
        icon: LucideIcons.crown,
        iconColor: const Color(0xFFFFC800),
        title: '¡Ya tienes Premium!',
        scheme: scheme,
      ),
      const SizedBox(height: 8),
      Text(
        expires == null
            ? 'Tu Premium está activo.'
            : 'Activo hasta el ${formatPremiumDate(expires)}.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 17, color: scheme.onSurface),
      ),
      const SizedBox(height: 12),
      const Center(child: PremiumCountdown(prefix: 'Te quedan ')),
      const SizedBox(height: 24),
      DuoButton.secondary(
        label: 'SEGUIR ESTUDIANDO',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ];
  }

  // ---- Resultado: denegado ----

  List<Widget> _deniedBody(ColorScheme scheme) {
    final request = PremiumService.latestRequestNotifier.value;
    final reason = request?.reason.trim() ?? '';
    return [
      const SizedBox(height: 8),
      _ResultHeader(
        icon: LucideIcons.x,
        iconColor: const Color(0xFFFF4B4B),
        title: 'Pago denegado',
        scheme: scheme,
      ),
      const SizedBox(height: 8),
      Text(
        reason.isEmpty
            ? 'Tu pago no se pudo verificar. Revisa los datos e inténtalo de nuevo.'
            : 'Motivo: $reason',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 17, color: scheme.onSurface),
      ),
      const SizedBox(height: 24),
      DuoButton.primary(
        label: 'INTENTAR DE NUEVO',
        onPressed: () => setState(() {
          _step = 0;
          _screenshot = null;
          _error = null;
        }),
      ),
    ];
  }

  // ---- Paso 2: en revisión ----

  List<Widget> _pendingBody(ColorScheme scheme) {
    final request = PremiumService.latestRequestNotifier.value;
    final plan = premiumPlanById(request?.plan ?? _selectedPlan);
    return [
      const SizedBox(height: 8),
      _ResultHeader(
        icon: LucideIcons.clock,
        iconColor: AppAccent.primary,
        title: 'En revisión',
        scheme: scheme,
      ),
      const SizedBox(height: 8),
      Text(
        plan == null
            ? 'Tu solicitud está en revisión. Cuando se apruebe, el Premium se activa solo, sin reabrir la app.'
            : 'Tu solicitud del plan de ${plan.monthsLabel} está en revisión. Cuando se apruebe, el Premium se activa solo, sin reabrir la app.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 17, color: scheme.onSurface),
      ),
      const SizedBox(height: 24),
      DuoButton.secondary(
        label: 'VOLVER',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ];
  }

  // ---- Paso 0: planes ----

  List<Widget> _plansBody(ColorScheme scheme, bool isDark) {
    final prices = RemoteTuning.planPrices;
    return [
      Text(
        'Quemia Premium',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Estudia sin límites y repasa todo lo que fallaste.',
        style: TextStyle(fontSize: 14, color: scheme.onSurface),
      ),
      // Aviso de la versión de prueba (Kristian 2026-11-15): el
      // paywall también dice que estás en prueba y cuántos días
      // quedan. Sin prueba, no ocupa nada.
      if (TrialService.isTrialActiveNow) ...[
        const SizedBox(height: 12),
        _TrialNoticeCard(scheme: scheme, isDark: isDark),
      ],
      const SizedBox(height: 8),
      _ComparisonCard(scheme: scheme, isDark: isDark),
      const SizedBox(height: 8),
      Text(
        'Elige tu plan',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      const SizedBox(height: 8),
      for (final plan in premiumPlans)
        _PlanCard(
          plan: plan,
          price: premiumPriceFor(plan.id, prices),
          selected: _selectedPlan == plan.id,
          scheme: scheme,
          isDark: isDark,
          onTap: () => setState(() => _selectedPlan = plan.id),
        ),
      const SizedBox(height: 12),
      DuoButton.primary(
        label: 'CONTINUAR',
        onPressed: () => setState(() => _step = 1),
      ),
      const SizedBox(height: 6),
      Text(
        // Corto (2026-11-16): el texto largo ocupaba 5 líneas
        // (95 px) y empujaba el paywall fuera de 393x852. El
        // detalle de la duración ya está en cada plan.
        'Pago manual por Transfermóvil. Sin suscripción automática.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: scheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
    ];
  }

  // ---- Paso 1: pago + captura ----

  List<Widget> _payBody(ColorScheme scheme, bool isDark) {
    final plan = premiumPlanById(_selectedPlan)!;
    final price = premiumPriceFor(_selectedPlan, RemoteTuning.planPrices);
    final isExample = RemoteTuning.transfermovilIsExample;
    final cardColor = isDark ? AppAccent.darkCard : Colors.white;
    final borderColor =
        isDark ? AppAccent.darkBorder : const Color(0xFFE5E5E5);
    return [
      Text(
        'Paga con Transfermóvil',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Plan de ${plan.monthsLabel} · ${formatCupPrice(price)} CUP',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      const SizedBox(height: 8),
      Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1 · Haz la transferencia',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _PayRow(
                label: 'Monto',
                value: '${formatCupPrice(price)} CUP',
                onCopy: () => _copy('$price', 'El monto'),
              ),
              _PayRow(
                label: isExample
                    ? 'Tarjeta destino (EJEMPLO)'
                    : 'Tarjeta destino',
                value: RemoteTuning.transfermovilCard,
                onCopy: () => _copy(
                    RemoteTuning.transfermovilCard, 'La tarjeta'),
              ),
              _PayRow(
                label: 'Número de Transfermóvil',
                value: RemoteTuning.transfermovilNumber,
                onCopy: () => _copy(
                    RemoteTuning.transfermovilNumber, 'El número'),
              ),
              Text(
                RemoteTuning.paymentDetails,
                style: TextStyle(fontSize: 13, color: scheme.onSurface),
              ),
              if (isExample) ...[
                const SizedBox(height: 6),
                Text(
                  'Los datos de arriba son un EJEMPLO. El número real lo configura el equipo de Quemia.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '2 · Sube la captura del pago',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      if (_screenshot != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            _screenshot!.bytes,
            height: 80,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      if (_screenshot != null) const SizedBox(height: 8),
      DuoButton.secondary(
        label: _picking
            ? 'ELIGIENDO…'
            : (_screenshot == null
                ? 'ELEGIR CAPTURA'
                : 'CAMBIAR CAPTURA'),
        onPressed: _picking ? null : _pickScreenshot,
      ),
      const SizedBox(height: 8),
      DuoButton.primary(
        label: _submitting ? 'ENVIANDO…' : 'ENVIAR SOLICITUD',
        onPressed: (_screenshot == null || _submitting) ? null : _submit,
      ),
      if (_screenshot == null) ...[
        const SizedBox(height: 6),
        Text(
          'Sube la captura del pago para enviar la solicitud.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ],
      const SizedBox(height: 2),
      TextButton(
        onPressed: () => setState(() => _step = 0),
        style: TextButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        child: const Text('Volver a los planes'),
      ),
    ];
  }
}

/// Cabecera de resultado (aprobado / denegado / en revisión).
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.scheme,
  });

  final LucideIconData icon;
  final Color iconColor;
  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor,
          ),
          alignment: Alignment.center,
          child: LucideIcon(icon, size: 36, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Comparación Gratis vs Premium.
class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.scheme, required this.isDark});

  final ColorScheme scheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppAccent.darkCard : Colors.white;
    final borderColor =
        isDark ? AppAccent.darkBorder : const Color(0xFFE5E5E5);
    // La Tabla periódica NO aparece aquí (2026-11-15, Kristian):
    // sigue siendo gratis, solo no lleva fila en esta tabla.
    // "10 al día" (2026-11-16): "10 vidas al día" no cabía y se
    // partía en dos líneas; la fila ya dice "Corazones".
    const rows = <(String, String, String)>[
      ('Corazones ilimitados', '10 al día', 'Ilimitados'),
      ('Aprender, Resolver y Temas', 'Con candado', 'Sin candado'),
      ('Mis errores', 'Con candado', 'Sin candado'),
      ('Lecciones sin conexión', 'Limitado', 'Sin límite'),
    ];
    // Celda de valor: el texto ("10 al día", "Limitado") se pinta
    // tal cual; "Con candado" es una crucecita verde y "Sin
    // candado" un ✓ verde (2026-11-17, Kristian: "eso de con
    // candado, no, pon una crucecita... mejor verde que del mismo
    // color" — el verde es el de Premium, AppAccent.primary, el
    // mismo de los valores de la columna PREMIUM). Lucide, como
    // el resto de la pantalla (Icons.close/check de Material salen
    // como ▯ en las fotos de prueba: esa fuente no se carga ahí).
    Widget valueCell(String value, {required bool premium}) {
      if (value == 'Con candado') {
        return LucideIcon(LucideIcons.x,
            size: 20, color: AppAccent.primary);
      }
      if (value == 'Sin candado') {
        return LucideIcon(LucideIcons.check,
            size: 22, color: AppAccent.primary);
      }
      return Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: premium ? FontWeight.w800 : null,
          color: premium
              ? AppAccent.primary
              : scheme.onSurface.withValues(alpha: 0.8),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: Padding(
        // Aireada (2026-11-17, Kristian: "se ve todo junto,
        // achicado y feo así"): la versión compacta de 12 pt sin
        // hueco entre filas se leía como una tabla apretada. Ahora
        // cada fila respira (8 pt arriba y abajo), letra 14 en las
        // etiquetas y 13 en los valores (a 14 los valores
        // "Con/Sin candado" se partían en 2 líneas y la tarjeta
        // desbordaba 115 px con Nunito en 393x852), y una línea
        // fina separa las filas. La etiqueta larga ("Aprender,
        // Resolver y Temas") puede ocupar 2 líneas: con el hueco
        // se ve a propósito, no apretada.
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(flex: 4, child: SizedBox.shrink()),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    'GRATIS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    'PREMIUM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppAccent.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(height: 1, thickness: 1, color: borderColor),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(height: 1, thickness: 1, color: borderColor),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        rows[i].$1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: valueCell(rows[i].$2, premium: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: valueCell(rows[i].$3, premium: true),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Aviso de la versión de prueba dentro del paywall (Kristian
/// 2026-11-15): "Estás en la versión de prueba · te quedan X
/// días. Cuando termine, podrás seguir con Premium." Tarjeta
/// plana con tinte del acento, sin degradados.
class _TrialNoticeCard extends StatelessWidget {
  const _TrialNoticeCard({required this.scheme, required this.isDark});

  final ColorScheme scheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final days = TrialService.daysLeftNow;
    final text = days <= 1
        ? tr('trialPaywallDay')
        : tr('trialPaywallDays').replaceFirst('%s', days.toString());
    return Container(
      key: const ValueKey('trialNoticeCard'),
      decoration: BoxDecoration(
        color: AppAccent.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppAccent.primary.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppAccent.primary.withValues(alpha: 0.14),
            ),
            alignment: Alignment.center,
            child: LucideIcon(
              LucideIcons.clock,
              size: 20,
              color: AppAccent.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color:
                    isDark ? Colors.white : const Color(0xFF4B4B4B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de un plan (seleccionable).
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.price,
    required this.selected,
    required this.scheme,
    required this.isDark,
    required this.onTap,
  });

  final PremiumPlan plan;
  final int price;
  final bool selected;
  final ColorScheme scheme;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppAccent.darkCard : Colors.white;
    // Planes con MUCHO más aire (Kristian 2026-11-15: se veían muy
    // pegados y raros): tarjeta más alta y 16 pt de separación
    // entre ellas, sin cambiar precios ni beneficios.
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? AppAccent.primary : (isDark
              ? AppAccent.darkBorder
              : const Color(0xFFE5E5E5)),
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppAccent.primary : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? AppAccent.primary
                        : const Color(0xFFAFAFAF),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const LucideIcon(
                        LucideIcons.check,
                        size: 13,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plan.monthsLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${formatCupPrice(price)} CUP',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  // Precio en el acento, oscurecido en claro hasta
                  // contraste ≥ 3,0 sobre la tarjeta (WCAG texto
                  // grande; Kristian 2026-11-16: el teal sobre
                  // blanco daba 2,26).
                  color: AppAccent.planPriceColor(isDark: isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una fila de dato de pago con botón de copiar.
class _PayRow extends StatelessWidget {
  const _PayRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            tooltip: 'Copiar',
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: const LucideIcon(LucideIcons.copy, size: 18),
          ),
        ],
      ),
    );
  }
}
