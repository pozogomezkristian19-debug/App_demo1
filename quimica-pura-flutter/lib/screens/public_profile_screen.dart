// Perfil público de otro usuario (Kristian 2026-11-16, lote de
// 11 puntos, punto 7): se abre al tocar una sugerencia o a alguien
// de las listas de seguidos/seguidores, aunque no seamos amigos,
// como el de Keilan en las capturas de Duolingo.
//
// TODOS LOS DATOS SON REALES (SocialService.publicProfile): los
// niveles, puntos, racha, trofeos, progreso semanal y seguidores
// salen de lo que esa persona tiene guardado en la base de datos,
// nunca números inventados. Sin historial de puntos por día sale
// una nota honesta ("Aún no hay puntos registrados esta semana"),
// no una gráfica inventada. Los logros que no se pueden derivar
// de datos guardados (repaso al día) salen en gris, como los que
// faltan.
//
// Al final: REPORTAR USUARIO (reporte real a la cola del Admin) y
// BLOQUEAR USUARIO (persiste; deja de salir en sugerencias y en
// Amigos).
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/achievements.dart';
import '../services/accent.dart';
import '../services/auth_service.dart';
import '../services/localization.dart';
import '../services/progress.dart';
import '../services/social_service.dart';
import '../services/sound_service.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/motion.dart';
import '../widgets/social_avatar.dart';
import 'profile_qr_screen.dart';

/// Colores del perfil público según el tema (igual que Cuenta).
class _PublicColors {
  const _PublicColors({
    required this.bg,
    required this.ink,
    required this.inkSoft,
    required this.border,
    required this.card,
  });

  factory _PublicColors.of(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return _PublicColors(
        bg: AppAccent.darkBackground,
        ink: Colors.white,
        inkSoft: AppAccent.darkInkSoft,
        border: AppAccent.darkBorder,
        card: AppAccent.darkCard,
      );
    }
    return const _PublicColors(
      bg: Colors.white,
      ink: Color(0xFF4B4B4B),
      inkSoft: Color(0xFF777777),
      border: Color(0xFFE5E5E5),
      card: Colors.white,
    );
  }

  final Color bg;
  final Color ink;
  final Color inkSoft;
  final Color border;
  final Color card;
}

/// Perfil público de [uid]: flecha atrás + nombre centrado, avatar
/// grande en zona de fondo claro, @usuario · SE UNIÓ EN <año>,
/// Niveles / Siguiendo / Seguidores reales, botón SEGUIR grande +
/// botón QR, PROGRESO SEMANAL (esa persona vs "Tú"), RESUMEN,
/// LOGROS y REPORTAR / BLOQUEAR al final.
class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  PublicProfile? _profile;
  Map<String, int> _myDailyPoints = {};
  bool _notFound = false;
  bool _followBusy = false;
  bool _blocked = false;
  final _reasonController = TextEditingController();

  bool get _isOwn => widget.uid == AuthService.currentUid;

  /// Sesión iniciada (Google o correo): lo social — SEGUIR,
  /// listas de seguidos/seguidores — solo sale con sesión
  /// (Kristian 2026-11-16).
  bool get _signedIn =>
      AuthService.isGoogleLinked || AuthService.isEmailLinked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await SocialService.publicProfile(widget.uid);
    if (!mounted) return;
    if (profile == null) {
      setState(() => _notFound = true);
      return;
    }
    final me = AuthService.currentUid ?? '';
    Map<String, int> myDaily = {};
    if (me.isNotEmpty && me != widget.uid) {
      final mine = await SocialService.publicProfile(me);
      myDaily = mine?.dailyPoints ?? {};
    }
    final blocked = await SocialService.isBlocked(widget.uid);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _myDailyPoints = myDaily;
      _blocked = blocked;
    });
  }

  /// Seguir / dejar de seguir desde el perfil público. Solo se
  /// llega aquí con sesión: el botón SEGUIR no se enseña a un
  /// invitado (Kristian 2026-11-16: a un invitado no le sale lo
  /// de buscar otra gente, así que no puede seguir a nadie).
  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _followBusy) return;
    setState(() => _followBusy = true);
    final ok = profile.isFollowing
        ? await SocialService.unfollowUser(widget.uid)
        : await SocialService.followUser(widget.uid);
    if (!mounted) return;
    setState(() => _followBusy = false);
    if (ok) await _load();
  }

  void _openQr() {
    final profile = _profile;
    if (profile == null || profile.username.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QrScreen(
          username: profile.username,
          displayName: profile.displayName,
          avatarAsset:
              SocialService.avatarAssetForId(profile.avatarId),
        ),
      ),
    );
  }

  void _openFollowList(String kind) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FollowListScreen(uid: widget.uid, kind: kind),
      ),
    );
  }

  /// Reportar: diálogo con el motivo (obligatorio) y reporte real
  /// a la cola del Admin.
  Future<void> _askReport() async {
    final reported = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('profileReportTitle')),
        content: TextField(
          controller: _reasonController,
          decoration: InputDecoration(
            hintText: tr('profileReportReason'),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('closeWord')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('profileReportUser')),
          ),
        ],
      ),
    );
    if (reported != true) return;
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) return;
    final ok = await SocialService.reportUser(widget.uid, reason);
    if (!mounted) return;
    _reasonController.clear();
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('profileReportThanks'))),
      );
    }
  }

  /// Bloquear / desbloquear: persiste; bloqueado deja de salir en
  /// sugerencias y en Amigos. No se sale de la pantalla (así se
  /// puede deshacer).
  Future<void> _toggleBlock() async {
    if (_blocked) {
      final ok = await SocialService.unblockUser(widget.uid);
      if (!mounted) return;
      if (ok) {
        setState(() => _blocked = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('profileUnblocked'))),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('profileBlockTitle')),
        content: Text(tr('profileBlockBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('closeWord')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('profileBlockUser')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await SocialService.blockUser(widget.uid);
    if (!mounted) return;
    if (ok) {
      setState(() => _blocked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('profileBlocked'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _PublicColors.of(context);
    final profile = _profile;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        centerTitle: true,
        title: profile == null
            ? null
            : Text(
                profile.displayName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
        iconTheme: IconThemeData(color: c.ink),
      ),
      body: _notFound
          ? Center(
              child: Text(
                tr('profileQrNoUser'),
                style: TextStyle(fontSize: 16, color: c.inkSoft),
              ),
            )
          : profile == null
              ? const Center(child: CircularProgressIndicator())
              : _buildProfile(context, c, profile),
    );
  }

  Widget _buildProfile(
      BuildContext context, _PublicColors c, PublicProfile profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Zona del avatar con su propio fondo (como en Cuenta).
    final zoneColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : AppAccent.primary.withValues(alpha: 0.08);
    // Línea @usuario · SE UNIÓ EN <año>: solo las partes que hay.
    final joinedParts = <String>[];
    if (profile.username.isNotEmpty) {
      joinedParts.add('@${profile.username}');
    }
    if (profile.joinedAtMs > 0) {
      final year = DateTime.fromMillisecondsSinceEpoch(profile.joinedAtMs)
          .year
          .toString();
      joinedParts.add(
          tr('accountJoinedYear').replaceFirst('%s', year));
    }
    final joinedLine = joinedParts.join(' · ').toUpperCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          decoration: BoxDecoration(
            color: zoneColor,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              SocialAvatar(
                username: profile.username,
                avatarAsset:
                    SocialService.avatarAssetForId(profile.avatarId),
                size: 120,
              ),
              const SizedBox(height: 12),
              Text(
                profile.displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
              if (joinedLine.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  joinedLine,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: c.inkSoft),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Niveles / Siguiendo / Seguidores con números reales.
        // Las listas SOLO se abren con sesión (Kristian
        // 2026-11-16: un invitado no ve lo de buscar otra
        // gente): sin sesión los números se ven pero no se
        // tocan (onTap null = sin InkWell).
        Row(
          children: [
            _PublicStat(
              value: '${profile.levelsPassedTotal}',
              label: tr('accountLevels'),
            ),
            _PublicStat(
              value: '${profile.followingCount}',
              label: tr('accountFollowing'),
              onTap: _signedIn ? () => _openFollowList('following') : null,
            ),
            _PublicStat(
              value: '${profile.followersCount}',
              label: tr('accountFollowers'),
              onTap: _signedIn ? () => _openFollowList('followers') : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // SEGUIR grande + QR; en mi propio perfil solo el QR.
        // SEGUIR NO se enseña a un invitado (Kristian
        // 2026-11-16): el invitado solo ve el QR de la persona,
        // sin botón para seguirla.
        if (_isOwn)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (profile.username.isNotEmpty) _qrButton(),
            ],
          )
        else if (_signedIn)
          Row(
            children: [
              Expanded(
                child: FollowPulse(
                  following: profile.isFollowing,
                  child: profile.isFollowing
                      ? DuoButton.secondary(
                          label: tr('accountFollowingBtn').toUpperCase(),
                          icon: profile.isMutual
                              ? LucideIcons.heart
                              : LucideIcons.check,
                          onPressed:
                              _followBusy ? null : _toggleFollow,
                        )
                      : DuoButton.primary(
                          label: tr('accountFollow').toUpperCase(),
                          onPressed:
                              _followBusy ? null : _toggleFollow,
                        ),
                ),
              ),
              if (profile.username.isNotEmpty) ...[
                const SizedBox(width: 12),
                _qrButton(),
              ],
            ],
          )
        else if (profile.username.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_qrButton()],
          ),
        _SectionTitle(title: tr('profileWeeklyTitle')),
        _WeeklySection(
          theirName: profile.displayName,
          theirDailyPoints: profile.dailyPoints,
          myDailyPoints: _myDailyPoints,
        ),
        _SectionTitle(title: tr('accountSummary')),
        _PublicSummaryGrid(profile: profile),
        _SectionTitle(title: tr('accountAchievements')),
        _PublicAchievementsGrid(
            earned: profile.achievementsWon.toSet()),
        const SizedBox(height: 24),
        _EndRow(
          icon: LucideIcons.flag,
          iconColor: const Color(0xFFF59E0B),
          label: tr('profileReportUser'),
          onTap: _askReport,
        ),
        const SizedBox(height: 12),
        _EndRow(
          icon: LucideIcons.ban,
          iconColor: const Color(0xFFEF4444),
          label: _blocked
              ? tr('profileUnblockUser')
              : tr('profileBlockUser'),
          onTap: _toggleBlock,
        ),
      ],
    );
  }

  Widget _qrButton() {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          SoundService.tap();
          _openQr();
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppAccent.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppAccent.primary.withValues(alpha: 0.35),
            ),
          ),
          alignment: Alignment.center,
          child: LucideIcon(
            LucideIcons.qrCode,
            size: 28,
            color: AppAccent.primary,
          ),
        ),
      ),
    );
  }
}

/// Número + etiqueta del perfil público (Siguiendo/Seguidores se
/// tocan y abren sus listas).
class _PublicStat extends StatelessWidget {
  const _PublicStat({
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = _PublicColors.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: c.inkSoft),
        ),
      ],
    );
    if (onTap == null) return Expanded(child: content);
    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            SoundService.tap();
            onTap!();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Título de sección del perfil público (mayúsculas, como Cuenta).
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = _PublicColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: c.inkSoft,
        ),
      ),
    );
  }
}

/// PROGRESO SEMANAL: puntos por día de los últimos 7 días, esa
/// persona vs "Tú". La línea se dibuja animada al entrar; los
/// puntos aparecen con pop escalonado; los totales cuentan hacia
/// arriba. Sin historial en ninguno de los dos sale una nota
/// honesta (y la gráfica en cero con los días de la semana, sin
/// inventar puntos).
class _WeeklySection extends StatelessWidget {
  const _WeeklySection({
    required this.theirName,
    required this.theirDailyPoints,
    required this.myDailyPoints,
  });

  final String theirName;
  final Map<String, int> theirDailyPoints;
  final Map<String, int> myDailyPoints;

  @override
  Widget build(BuildContext context) {
    final c = _PublicColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final days = List.generate(
        7, (i) => today.subtract(Duration(days: 6 - i)));
    final keys = days.map(ProgressService.dateKey).toList();
    final theirValues =
        keys.map((k) => theirDailyPoints[k] ?? 0).toList();
    final myValues = keys.map((k) => myDailyPoints[k] ?? 0).toList();
    final theirTotal = theirValues.fold(0, (a, b) => a + b);
    final myTotal = myValues.fold(0, (a, b) => a + b);
    final bothEmpty = theirTotal == 0 &&
        myTotal == 0 &&
        theirDailyPoints.isEmpty &&
        myDailyPoints.isEmpty;
    final theirColor = isDark ? scheme.primary : AppAccent.primary;
    const myColor = Color(0xFF9CA3AF);
    const valueStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
    Widget legendRow(Color dot, String name, int total, Color color) {
      return Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(fontSize: 14, color: c.ink),
            ),
          ),
          CountUp(value: total, style: valueStyle.copyWith(color: color)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bothEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              tr('profileWeeklyEmpty'),
              style: TextStyle(fontSize: 14, color: c.inkSoft),
            ),
          ),
        legendRow(theirColor, theirName, theirTotal, theirColor),
        const SizedBox(height: 6),
        legendRow(myColor, tr('profileWeeklyYou'), myTotal, c.inkSoft),
        const SizedBox(height: 12),
        _WeeklyLineChart(
          theirValues: theirValues,
          myValues: myValues,
          theirColor: theirColor,
          myColor: myColor,
          dayLabels: days.map((d) => d.day).toList(),
        ),
      ],
    );
  }
}

/// Gráfica semanal de líneas: la línea se dibuja animada al entrar
/// (trazado 0→1 en ~800 ms) y los puntos aparecen con pop
/// escalonado. Con movimiento reducido, la línea sale completa.
class _WeeklyLineChart extends StatefulWidget {
  const _WeeklyLineChart({
    required this.theirValues,
    required this.myValues,
    required this.theirColor,
    required this.myColor,
    required this.dayLabels,
  });

  final List<int> theirValues;
  final List<int> myValues;
  final Color theirColor;
  final Color myColor;
  final List<int> dayLabels;

  @override
  State<_WeeklyLineChart> createState() => _WeeklyLineChartState();
}

class _WeeklyLineChartState extends State<_WeeklyLineChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery (movimiento reducido) no se puede leer en
    // initState: aquí el contexto ya está listo.
    if (!_started) {
      _started = true;
      if (!reducedMotion(context)) _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _PublicColors.of(context);
    return Column(
      children: [
        SizedBox(
          height: 140,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _WeeklyLinePainter(
                theirValues: widget.theirValues,
                myValues: widget.myValues,
                theirColor: widget.theirColor,
                myColor: widget.myColor,
                progress: reducedMotion(context) ? 1.0 : _controller.value,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: widget.dayLabels
              .map((d) => Expanded(
                    child: Text(
                      '$d',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: c.inkSoft),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _WeeklyLinePainter extends CustomPainter {
  _WeeklyLinePainter({
    required this.theirValues,
    required this.myValues,
    required this.theirColor,
    required this.myColor,
    required this.progress,
  });

  final List<int> theirValues;
  final List<int> myValues;
  final Color theirColor;
  final Color myColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = math.max(
        1,
        [...theirValues, ...myValues]
            .fold(0, (a, b) => math.max(a, b)));
    Offset point(int i, int v) {
      final x = 12.0 + i * (size.width - 24.0) / 6;
      final y = size.height - 12.0 - (v / maxV) * (size.height - 24.0);
      return Offset(x, y);
    }

    void drawLine(List<int> values, Color color) {
      if (values.isEmpty) return;
      final path = Path()..moveTo(point(0, values[0]).dx, point(0, values[0]).dy);
      for (var i = 1; i < values.length; i++) {
        final p = point(i, values[i]);
        path.lineTo(p.dx, p.dy);
      }
      // OJO: PathMetrics es un iterable de UN SOLO USO: un
      // isEmpty seguido de .first ya no encuentra nada ("No
      // element"). Se recorre una sola vez.
      PathMetric? metric;
      for (final m in path.computeMetrics()) {
        metric = m;
        break;
      }
      if (metric == null) return;
      final total = metric.length;
      final shown =
          metric.extractPath(0, total * progress.clamp(0.0, 1.0));
      canvas.drawPath(
        shown,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      // Puntos con pop escalonado al llegar el trazado a ellos.
      for (var i = 0; i < values.length; i++) {
        final dotT = (progress * values.length - i).clamp(0.0, 1.0);
        if (dotT <= 0) continue;
        final scale = Curves.elasticOut.transform(dotT);
        final p = point(i, values[i]);
        canvas.drawCircle(p, 4 * scale, Paint()..color = color);
      }
    }

    drawLine(myValues, myColor);
    drawLine(theirValues, theirColor);
  }

  @override
  bool shouldRepaint(_WeeklyLinePainter old) =>
      old.progress != progress ||
      old.theirValues != theirValues ||
      old.myValues != myValues;
}

/// RESUMEN del perfil público 2×2: racha, niveles, trofeos y
/// puntos, con los iconos nuevos del lote (llama, capas, trofeo,
/// rayo) y CountUp en racha, niveles y puntos.
class _PublicSummaryGrid extends StatelessWidget {
  const _PublicSummaryGrid({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final c = _PublicColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final boltColor = isDark ? scheme.primary : const Color(0xFFF59E0B);
    final trophyColor = isDark ? scheme.primary : const Color(0xFF8B5CF6);
    final medalColor = isDark ? scheme.primary : AppAccent.primary;
    const valueStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
    Widget cell(Widget icon, Widget value, String label) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 5),
              value,
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: c.inkSoft),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: cell(
                Image.asset(
                  'assets/streak_fire_orange.png',
                  width: 28,
                  height: 28,
                ),
                CountUp(value: profile.streak, style: valueStyle),
                tr('accountStreak'),
              ),
            ),
            Expanded(
              child: cell(
                LucideIcon(
                  LucideIcons.layers,
                  size: 22,
                  color: medalColor,
                  threeD: true,
                ),
                CountUp(
                    value: profile.levelsPassedTotal, style: valueStyle),
                tr('accountLevels'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: cell(
                LucideIcon(
                  LucideIcons.trophy,
                  size: 22,
                  color: trophyColor,
                  threeD: true,
                ),
                Text(
                  '${profile.trophiesWon}/${profile.trophiesTotal}',
                  style: valueStyle,
                ),
                tr('trophiesWord'),
              ),
            ),
            Expanded(
              child: cell(
                LucideIcon(
                  LucideIcons.zap,
                  size: 22,
                  color: boltColor,
                  filled: true,
                  threeD: true,
                ),
                CountUp(value: profile.points, style: valueStyle),
                tr('accountPoints'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// LOGROS del perfil público: los 10, en color los ganados (según
/// sus datos reales) y en gris los que faltan. Al tocar uno sale
/// su título y su descripción.
class _PublicAchievementsGrid extends StatelessWidget {
  const _PublicAchievementsGrid({required this.earned});

  final Set<String> earned;

  @override
  Widget build(BuildContext context) {
    final c = _PublicColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        childAspectRatio: 0.62,
      ),
      itemCount: allAchievements.length,
      itemBuilder: (context, i) {
        final a = allAchievements[i];
        final unlocked = earned.contains(a.id);
        final bg = unlocked
            ? AppAccent.primary.withValues(alpha: 0.12)
            : (isDark ? c.border : const Color(0xFFE5E5E5));
        final fg = unlocked
            ? (isDark ? scheme.primary : AppAccent.primary)
            : (isDark ? AppAccent.darkInkSoft : const Color(0xFF9CA3AF));
        return GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${a.title} — ${a.body}')),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: LucideIcon(a.icon, size: 28, color: fg),
              ),
              const SizedBox(height: 4),
              Text(
                a.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: unlocked ? c.ink : c.inkSoft,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Fila final del perfil público: reportar o bloquear.
class _EndRow extends StatelessWidget {
  const _EndRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final LucideIconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = _PublicColors.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          SoundService.tap();
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              LucideIcon(icon, size: 22, color: iconColor),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista de seguidos o seguidores de [uid], con datos reales: al
/// tocar una persona se abre su perfil público.
class FollowListScreen extends StatefulWidget {
  const FollowListScreen({
    super.key,
    required this.uid,
    required this.kind,
  });

  /// 'following' (a quiénes sigue) o 'followers' (quiénes lo siguen).
  final String uid;
  final String kind;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<FriendEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = widget.kind == 'followers'
        ? await SocialService.followersList(widget.uid)
        : await SocialService.followingList(widget.uid);
    if (!mounted) return;
    setState(() => _entries = list);
  }

  @override
  Widget build(BuildContext context) {
    final c = _PublicColors.of(context);
    final isFollowers = widget.kind == 'followers';
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          tr(isFollowers
              ? 'followListFollowersTitle'
              : 'followListFollowingTitle'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: c.ink,
          ),
        ),
        iconTheme: IconThemeData(color: c.ink),
      ),
      body: _entries == null
          ? const Center(child: CircularProgressIndicator())
          : _entries!.isEmpty
              ? Center(
                  child: Text(
                    tr(isFollowers
                        ? 'followListEmptyFollowers'
                        : 'followListEmptyFollowing'),
                    style: TextStyle(fontSize: 16, color: c.inkSoft),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: _entries!.length,
                  itemBuilder: (context, i) {
                    final entry = _entries![i];
                    return Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          SoundService.tap();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PublicProfileScreen(
                                  uid: entry.deviceId),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.border),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              SocialAvatar(
                                username: entry.username,
                                avatarAsset: entry.avatarAsset,
                                badgeId: entry.badgeId,
                                size: 48,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.username,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: c.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${entry.points} ${tr('accountPoints')} · ${entry.levelsPassedTotal} ${tr('accountLevels')}',
                                      style: TextStyle(
                                          fontSize: 13, color: c.inkSoft),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
