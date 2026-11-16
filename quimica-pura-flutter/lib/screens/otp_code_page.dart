/// Página de código OTP reutilizable (Kristian 2026-11-16): 6
/// casillas, como el OTP del registro. La usa el flujo de
/// "ponerle una contraseña" a una cuenta de Google (propósito
/// setPassword): el código confirma que el correo es suyo antes
/// de dejarle crear la contraseña DENTRO de la app, sin el correo
/// de restablecer de Firebase.
///
/// El registro por correo NO se toca: su OTP sigue incrustado en
/// el flujo de registro (riesgo de regresión).
///
/// La página MANDA el código sola al abrirse. Un código
/// incorrecto muestra el error y NUNCA avanza (mismo arreglo
/// que el bug del OTP del registro: `_busy` se mantiene hasta
/// que `onVerified` termina y el padre avanza).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/accent.dart';
import '../services/localization.dart';
import '../services/otp_service.dart';
import '../services/platform_check.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';

/// Página entera de código OTP para un correo y un propósito.
class OtpCodePage extends StatefulWidget {
  const OtpCodePage({
    super.key,
    required this.email,
    required this.purpose,
    required this.title,
    required this.body,
    required this.onVerified,
    required this.onBack,
  });

  /// Correo al que se manda el código.
  final String email;

  /// Para qué es el código (registro, ponerle contraseña...).
  final OtpPurpose purpose;

  /// Título de la pantalla (ya traducido).
  final String title;

  /// Texto debajo del título (ya traducido).
  final String body;

  /// Con el código correcto: el padre avanza de pantalla (o
  /// cierra la página). Se llama con `_busy` activo; el botón
  /// no se reactiva hasta que esto termina.
  final Future<void> Function() onVerified;

  /// Volver atrás (flecha o botón del teléfono).
  final VoidCallback onBack;

  @override
  State<OtpCodePage> createState() => _OtpCodePageState();
}

class _OtpCodePageState extends State<OtpCodePage> {
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpNodes = List.generate(6, (_) => FocusNode());
  var _busy = false;
  var _sending = true;
  String? _error;
  var _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  void _startResendCooldown() {
    _resendTimer?.cancel();
    // En pruebas no hay temporizador periódico: pumpAndSettle no
    // termina nunca con un Timer.periodic vivo. El botón de
    // reenviar queda disponible de inmediato en los tests.
    if (isFlutterTest) {
      setState(() => _resendIn = 0);
      return;
    }
    setState(() => _resendIn = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendIn <= 1) {
        timer.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn--);
      }
    });
  }

  /// Manda el código al abrir la página (y al reenviar). Si
  /// falla, se queda el error y el reenvío sirve de reintento.
  Future<void> _sendOtp() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final ok = await OtpService.requestCode(widget.email, widget.purpose);
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) {
      setState(() => _error = tr('obOtpNotSent'));
      return;
    }
    _startResendCooldown();
  }

  void _onOtpBoxChanged(int index, String value) {
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean != value) {
      _otpControllers[index].value = TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
    }
    if (clean.length == 1 && index < 5) {
      _otpNodes[index + 1].requestFocus();
    } else if (clean.isEmpty && index > 0) {
      _otpNodes[index - 1].requestFocus();
    }
    // El error de un código viejo se limpia en cuanto se escribe
    // uno nuevo: si no, el "incorrecto" se queda pegado aunque el
    // código nuevo sea bueno.
    setState(() => _error = null);
  }

  Future<void> _verifyOtp() async {
    if (_otpCode.length != 6 || _busy || _sending) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await OtpService.verifyCode(
      widget.email,
      _otpCode,
      widget.purpose,
    );
    if (!mounted) return;
    if (result != OtpVerifyResult.valid) {
      setState(
        () {
          _busy = false;
          _error = tr(switch (result) {
            OtpVerifyResult.expired => 'obOtpExpired',
            OtpVerifyResult.exhausted => 'obOtpAttemptsOut',
            _ => 'obOtpInvalid',
          });
        },
      );
      return;
    }
    // CAUSA RAÍZ del bug "error y luego avanza" del registro
    // (Kristian 2026-11-15): `_busy` se mantiene hasta que el
    // padre avanza de pantalla. Un código correcto nunca muestra
    // error y un segundo toque no hace nada.
    await widget.onVerified();
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _resendOtp() async {
    if (_resendIn > 0 || _busy || _sending) return;
    await _sendOtp();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final sub =
        isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF777777);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        widget.onBack();
      },
      child: Scaffold(
        key: const ValueKey('otpCodePage'),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              8 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: widget.onBack,
                    icon: const LucideIcon(LucideIcons.arrowLeft, size: 28),
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.body,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.4, color: sub),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 6; i++)
                      SizedBox(
                        width: 48,
                        height: 56,
                        child: TextField(
                          controller: _otpControllers[i],
                          focusNode: _otpNodes[i],
                          textAlign: TextAlign.center,
                          cursorHeight: 28,
                          textAlignVertical: TextAlignVertical.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          buildCounter: (context,
                                  {required currentLength,
                                  required isFocused,
                                  maxLength}) =>
                              null,
                          onChanged: (v) => _onOtpBoxChanged(i, v),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppAccent.primary,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor:
                                isDark ? AppAccent.darkCard : Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : const Color(0xFFC7CBD1),
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: AppAccent.primary, width: 2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                DuoButton.primary(
                  label: tr('obContinue').toUpperCase(),
                  onPressed: _otpCode.length == 6 && !_busy && !_sending
                      ? _verifyOtp
                      : null,
                  fontSize: 17,
                ),
                if (_busy || _sending) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _resendIn > 0 || _busy || _sending
                        ? null
                        : _resendOtp,
                    child: Text(
                      _resendIn > 0
                          ? '${tr('obOtpResend')} ($_resendIn)'
                          : tr('obOtpResend'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
