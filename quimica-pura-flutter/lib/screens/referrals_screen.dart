// Referidos (Quemia 7.3): Invitar y Canjear código.
//
// Invitar: el código grande + copiar, las gemelas arriba, "los
// dos ganan", usos restantes, aviso de amigo nuevo, hitos con
// barra de progreso y los que más invitan. La barra de compartir
// va FIJA abajo (fuera del scroll). Sin "Mensaje listo" (Quemia
// 7.6, Kristian: la pantalla se sentía muy cargada): el mensaje
// para compartir se sigue armando al tocar Compartir/WhatsApp/
// Messenger, pero ya no se enseña como tarjeta en la pantalla.
// Canjear: 6 casillas + regalo + botón Canjear + tarjeta de
// error como en el mockup. Sin sección de contactos (la app no
// vincula el número de teléfono).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/accent.dart';
import '../services/localization.dart';
import '../services/referral_rewards.dart';
import '../services/referral_service.dart';
import '../services/social_service.dart';
import '../services/user_prefs.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/online_gate.dart';
import '../widgets/share_bar.dart';
import '../widgets/social_avatar.dart';

/// Pantalla Invitar (mockup_invitar): el código y los hitos. La
/// entrada vive en Cuenta (fila Referidos).
class ReferralsScreen extends StatefulWidget {
  const ReferralsScreen({
    super.key,
    this.isGoogleLinked,
    this.onLinkGoogle,
  });

  /// null = preguntar a AuthService (patrón OnlineGate).
  final bool? isGoogleLinked;

  /// null = AuthService.linkWithGoogle().
  final Future<bool> Function()? onLinkGoogle;

  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> {
  ReferralState? _state;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Quemia 7.5: primero lo guardado en el teléfono (instantáneo)
    // y luego el refresco de la red en segundo plano. Antes la
    // pantalla esperaba a TODAS las llamadas en serie y con la
    // conexión lenta tardaba 30-60 s en abrir. El cobro va dentro
    // de loadState (una sola vez) y su aviso sale de state.claim.
    final local = await ReferralService.localState();
    if (!mounted) return;
    setState(() {
      _state = local;
      _loading = false;
    });
    final state = await ReferralService.loadState();
    if (!mounted) return;
    setState(() {
      _state = state;
    });
    final claim = state.claim;
    if (claim != null && claim.hasNews) {
      final parts = <String>[];
      if (claim.newReferrals.isNotEmpty) {
        parts.add(tr('referralNewFriend')
            .replaceAll('{name}', claim.newReferrals.last));
      }
      if (claim.newMilestones.isNotEmpty) {
        parts.add(tr('referralMilestoneUnlocked'));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parts.join(' '))),
      );
    }
  }

  Future<void> _copyCode() async {
    final code = _state?.code ?? '';
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('referralCopied'))),
    );
  }

  String get _message => _state?.shareMessage() ?? '';

  Future<void> _share() async {
    try {
      // share_plus 13: share() recibe ShareParams, no un String
      // (mismo patrón que stats_screen.dart:204).
      await SharePlus.instance.share(ShareParams(text: _message));
    } catch (_) {}
  }

  Future<void> _sms() async {
    try {
      await launchUrl(Uri(
        scheme: 'sms',
        queryParameters: {'body': _message},
      ));
    } catch (_) {}
  }

  Future<void> _whatsApp() async {
    try {
      await launchUrl(
        Uri.parse(
            'https://wa.me/?text=${Uri.encodeComponent(_message)}'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _messenger() async {
    // Messenger no tiene esquema para compartir texto sin su SDK:
    // se abre la app con el enlace de Quemia y, si no se puede,
    // se copia el mensaje para pegarlo a mano.
    try {
      final ok = await launchUrl(
        Uri.parse(
            'fb-messenger://share?link=${Uri.encodeComponent('https://quemia-8410a.web.app')}'),
        mode: LaunchMode.externalApplication,
      );
      if (ok || !mounted) return;
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: _message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('referralMessengerCopy'))),
    );
  }

  Future<void> _equipMilestone(ReferralMilestone milestone) async {
    for (final item in milestone.rewards) {
      await SocialService.equipItem(item);
      if (item.kind == 'theme') {
        // Como en la Tienda: avisa de que el acento cambió.
        UserPrefs.themeAccentNotifier.value = item.id;
      }
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('referralEquippedMsg'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? null : Border.all(
      color: const Color(0xFFE5E5E5),
      width: 2,
    );
    return Scaffold(
      // Sin título en la barra: el título grande "Invita y gana"
      // ya está en el cuerpo (28 pt) y se veía duplicado.
      appBar: AppBar(),
      body: OnlineGate(
        isGoogleLinked: widget.isGoogleLinked,
        onLinkGoogle: widget.onLinkGoogle,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _state == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        tr('socialOffline'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurface),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_state!.offline)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    tr('referralOfflineLine'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              // Las gemelas arriba, como en el
                              // mockup: Brenda (violeta) y Britany
                              // (azul) en círculo, sin texto. Más
                              // pequeñas (Quemia 7.6, Kristian: la
                              // pantalla se sentía muy cargada).
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ClipOval(
                                    child: Image.asset(
                                      'assets/brenda.png',
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ClipOval(
                                    child: Image.asset(
                                      'assets/britany.png',
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                tr('referralInviteTitle'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr('referralInviteSub'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Tarjeta del código.
                              Container(
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: border,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 20),
                                child: Column(
                                  children: [
                                    Text(
                                      tr('referralYourCode'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _state!.code.isEmpty
                                          ? '······'
                                          : _state!.code,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 4,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: 200,
                                      child: ElevatedButton(
                                        onPressed: _state!.code.isEmpty
                                            ? null
                                            : _copyCode,
                                        child: Text(tr('referralCopy')),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Canjear el código de un amigo ya NO
                              // vive aquí: es un apartado SEPARADO en
                              // Cuenta ("Canjear código", Quemia 7.6,
                              // Kristian, como en la app de Muse).
                              // Los dos ganan: dos tarjetas
                              // EXACTAMENTE iguales (regla 8).
                              Row(
                                children: [
                                  Expanded(
                                    child: _WinCard(
                                      label: tr('referralYouWin'),
                                      points:
                                          '+$kReferralInviterPoints ${tr('pointsWord')}',
                                      color: AppAccent.primary,
                                      border: border,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _WinCard(
                                      label: tr('referralFriendWins'),
                                      points:
                                          '+$kReferralInviteePoints ${tr('pointsWord')}',
                                      color: const Color(0xFF3B82F6),
                                      border: border,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tr('referralFriendWinsWhen'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    border: border,
                                    color: scheme.surface,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  child: Text(
                                    tr('referralUsesLeft').replaceAll(
                                        '{n}', '${_state!.usesLeft}'),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                              // Aviso: un amigo canjeó tu código.
                              if (_state!.lastInvitee != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppAccent.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tr('referralFriendJoined'),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppAccent.primaryDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        tr('referralFriendJoinedSub')
                                            .replaceAll('{name}',
                                                _state!.lastInvitee!),
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tr('referralMilestones'),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    tr('referralMilestonesOf').replaceAll(
                                        '{n}',
                                        '${_state!.referralsCount}'),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              for (final m in kReferralMilestones)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 12),
                                  child: _MilestoneRow(
                                    milestone: m,
                                    count: _state!.referralsCount,
                                    granted: _state!.milestonesGranted
                                        .contains(m.count),
                                    border: border,
                                    onEquip: () => _equipMilestone(m),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              const SizedBox(height: 24),
                              Text(
                                tr('referralTop'),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_state!.topReferrers.isEmpty)
                                Text(
                                  tr('referralTopEmpty'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                )
                              else
                                for (var i = 0;
                                    i < _state!.topReferrers.length &&
                                        i < 5;
                                    i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 28,
                                          child: Text(
                                            '${i + 1}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: scheme.onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ),
                                        SocialAvatar(
                                          username: _state!
                                              .topReferrers[i].username,
                                          size: 36,
                                          avatarAsset: SocialService
                                              .avatarAssetForId(_state!
                                                  .topReferrers[i].avatarId),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _state!
                                                .topReferrers[i].username,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${_state!.topReferrers[i].referralsCount}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: AppAccent.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              const SizedBox(height: 16),
                              Text(
                                tr('referralFootnote'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Barra fija abajo: no se mueve al deslizar.
                      ShareBar(
                        onShare: _share,
                        onSms: _sms,
                        onWhatsApp: _whatsApp,
                        onMessenger: _messenger,
                      ),
                    ],
                  ),
      ),
    );
  }
}

/// Tarjeta "TÚ GANAS / TU AMIGO GANA": las dos miden lo mismo.
class _WinCard extends StatelessWidget {
  const _WinCard({
    required this.label,
    required this.points,
    required this.color,
    required this.border,
  });

  final String label;
  final String points;
  final Color color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            points,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una fila de hito: círculo con el número, título, barra de
/// progreso y "n/m". Si está conseguido: "¡Tuyo!" + EQUIPAR.
class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.count,
    required this.granted,
    required this.border,
    required this.onEquip,
  });

  final ReferralMilestone milestone;
  final int count;
  final bool granted;
  final BoxBorder? border;
  final VoidCallback onEquip;

  Color get _numberColor => switch (milestone.count) {
        3 => const Color(0xFF8B5CF6),
        5 => const Color(0xFF3B82F6),
        _ => const Color(0xFF00C2A8),
      };

  String _titleKey() => switch (milestone.count) {
        3 => 'referralMilestone3',
        5 => 'referralMilestone5',
        _ => 'referralMilestone10',
      };

  bool _isEquipped() {
    for (final item in milestone.rewards) {
      final equipped = switch (item.kind) {
        'theme' => SocialService.equippedThemeId,
        'avatar' => SocialService.equippedAvatarId,
        'badge' => SocialService.equippedBadgeId,
        _ => null,
      };
      if (equipped == item.id) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = (count / milestone.count).clamp(0.0, 1.0);
    final equipped = granted && _isEquipped();
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _numberColor,
            ),
            alignment: Alignment.center,
            child: Text(
              '${milestone.count}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(_titleKey()),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: scheme.onSurface.withValues(alpha: 0.12),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress == 0 ? 0 : progress,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: AppAccent.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (granted)
            equipped
                ? Text(
                    tr('referralEquipped'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppAccent.primary,
                    ),
                  )
                : OutlinedButton(
                    onPressed: onEquip,
                    child: Text(tr('referralEquip')),
                  )
          else
            Text(
              '$count/${milestone.count}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pantalla Canjear código (mockup_canjear): 6 casillas, regalo,
/// botón Canjear y tarjeta de error. El premio (+20) se paga al
/// pasar el Nivel 1, no aquí.
class RedeemCodeScreen extends StatefulWidget {
  const RedeemCodeScreen({
    super.key,
    this.isGoogleLinked,
    this.onLinkGoogle,
  });

  /// null = preguntar a AuthService (patrón OnlineGate).
  final bool? isGoogleLinked;

  /// null = AuthService.linkWithGoogle().
  final Future<bool> Function()? onLinkGoogle;

  @override
  State<RedeemCodeScreen> createState() => _RedeemCodeScreenState();
}

class _RedeemCodeScreenState extends State<RedeemCodeScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  var _busy = false;
  var _done = false;
  RedeemResult? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  bool get _complete => _code.length == 6;

  void _onBoxChanged(int index, String value) {
    final clean =
        value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean != value) {
      _controllers[index].value = TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
    }
    setState(() {
      _error = null;
    });
    if (clean.length == 1 && index < 5) {
      _nodes[index + 1].requestFocus();
    } else if (clean.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
  }

  Future<void> _redeem() async {
    if (!_complete || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ReferralService.redeemCode(_code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result == RedeemResult.ok) {
        _done = true;
      } else {
        _error = result;
      }
    });
  }

  (String, String) _errorTexts(RedeemResult result) => switch (result) {
        RedeemResult.invalid || RedeemResult.notFound => (
            tr('referralInvalidTitle'),
            tr('referralInvalidSub'),
          ),
        RedeemResult.ownCode => (
            tr('referralOwnTitle'),
            tr('referralOwnSub'),
          ),
        RedeemResult.alreadyRedeemed => (
            tr('referralAlreadyTitle'),
            tr('referralAlreadySub'),
          ),
        RedeemResult.exhausted => (
            tr('referralExhaustedTitle'),
            tr('referralExhaustedSub'),
          ),
        RedeemResult.offline => (
            tr('referralOfflineTitle'),
            tr('referralOfflineSub'),
          ),
        _ => (
            tr('referralErrorTitle'),
            tr('referralErrorSub'),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxBorder = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : const Color(0xFFE5E5E5);
    return Scaffold(
      appBar: AppBar(title: Text(tr('referralRedeemTitle'))),
      body: OnlineGate(
        isGoogleLinked: widget.isGoogleLinked,
        onLinkGoogle: widget.onLinkGoogle,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('referralRedeemSub'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              // Regalo en círculo teal claro (mockup).
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppAccent.primary.withValues(alpha: 0.14),
                  ),
                  alignment: Alignment.center,
                  child: LucideIcon(
                    LucideIcons.gift,
                    size: 56,
                    color: AppAccent.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Las 6 casillas.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 6; i++)
                    SizedBox(
                      width: 48,
                      height: 56,
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _nodes[i],
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        keyboardType: TextInputType.text,
                        maxLength: 1,
                        buildCounter: (context,
                                {required currentLength,
                                required isFocused,
                                maxLength}) =>
                            null,
                        onChanged: (v) => _onBoxChanged(i, v),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppAccent.primary,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          // Relleno explícito (mismos valores que el tema
                          // de la app en main.dart): sin él, el fill
                          // heredado del tema parpadeó entre corridas
                          // de fotos (casillas transparentes en una
                          // captura y rellenas en la siguiente).
                          filled: true,
                          fillColor: isDark
                              ? (AppAccent.isViolet
                                  ? const Color(0xFF1C1533)
                                  : const Color(0xFF0F241E))
                              : Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: boxBorder, width: 2),
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
              Text(
                tr('referralYouWin20'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr('referralWhenLevel1'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              // Letra BLANCA también deshabilitado (como "Usar
              // resultado" en el teclado): el gris por defecto
              // sobre el teal apagado no se leía
              // (foto73_referidos_canjear). Fondo teal OSCURO
              // (primaryDark) sin Opacity: con Opacity el blanco
              // se apagaba y en oscuro se volvía a ver gris.
              ElevatedButton(
                onPressed: _complete && !_busy && !_done ? _redeem : null,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: AppAccent.primaryDark,
                  disabledForegroundColor: Colors.white,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : Text(tr('referralRedeem')),
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                _ErrorCard(
                  title: _errorTexts(_error!).$1,
                  subtitle: _errorTexts(_error!).$2,
                ),
              ],
              if (_done) ...[
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: AppAccent.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        tr('referralRedeemOk'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppAccent.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('referralRedeemOkSub'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: scheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('referralBack')),
                ),
              ],
              const SizedBox(height: 32),
              Text(
                tr('referralNoCode'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de error (mockup Canjear): círculo rojo con "!" +
/// título y explicación.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: const Color(0xFFE5E5E5), width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEF4444),
            ),
            alignment: Alignment.center,
            child: const Text(
              '!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 15,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
