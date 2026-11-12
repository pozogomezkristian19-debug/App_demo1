// Amigos (Quemia 7.0): POR SOLICITUD (ronda 2d): yo te veo, te
// mando la solicitud y a ti te llega para confirmarla o eliminarla.
// Agregar por nombre ya no añade directo — envía la solicitud; las
// entrantes se ven en la sección "Solicitudes" con Confirmar y
// Eliminar aunque no haya llegado la notificación, y las enviadas
// con "Solicitud enviada" + Cancelar. Solo los amigos confirmados
// se pueden retar (el botón Retar solo existe en la fila de amigo).
// Sin Google, la puerta (OnlineGate) muestra solo el inicio con
// Google.
//
// DISEÑO (rediseño Duolingo 7.0, Zona C): filas planas sin
// tarjeta y sin sombra, separadas por líneas finas #E5E5E5;
// avatares con cara (SocialAvatar, nunca inicial); "Retar" =
// DuoButton.secondary, "Confirmar" = teal sólido con labio,
// "Eliminar"/"Cancelar" = secundario gris; campo de nombre con
// radio 16 y botón "AGREGAR" a ancho completo debajo; sin icono
// de papelera en las filas; secciones a 20 pt peso 800.

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/social_service.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/online_gate.dart';
import '../widgets/social_avatar.dart';
import 'duel_screen.dart';

/// Línea divisoria de lista (rediseño Duolingo 7.0): 1 pt #E5E5E5
/// en claro, #37464F en oscuro.
const _lineLight = Color(0xFFE5E5E5);
const _lineDark = Color(0xFF37464F);

/// Color de los títulos de sección: #4B4B4B en claro, blanco en
/// oscuro.
const _sectionLight = Color(0xFF4B4B4B);

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({
    super.key,
    this.isGoogleLinked,
    this.onLinkGoogle,
  });

  final bool? isGoogleLinked;
  final Future<bool> Function()? onLinkGoogle;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _nameCtrl = TextEditingController();
  var _online = true;
  var _adding = false;
  String? _addMessage;

  /// Solicitudes pendientes: las que me llegaron y las que envié.
  var _incoming = <FriendRequest>[];
  var _sent = <FriendRequest>[];

  /// Mis duelos abiertos (para que el retado abra el suyo).
  List<DuelState> _myDuels = [];

  @override
  void initState() {
    super.initState();
    SocialService.online.then((v) {
      if (mounted) setState(() => _online = v);
    });
    _loadDuels();
    _loadRequests();
  }

  Future<void> _loadDuels() async {
    final duels = await SocialService.myOpenDuels();
    if (!mounted) return;
    setState(() => _myDuels = duels);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Solicitudes pendientes (entrantes + enviadas) y sincronización
  /// de la bandeja: al abrir Amigos, cada solicitud entrante deja
  /// su entrada en Notificaciones (una por solicitud, sin
  /// duplicados) y la campana sube sola. Aunque la notificación no
  /// llegue, aquí se ven las dos opciones (Confirmar/Eliminar).
  Future<void> _loadRequests() async {
    final incoming = await SocialService.incomingFriendRequests();
    final sent = await SocialService.sentFriendRequests();
    await SocialService.syncFriendRequestInbox();
    if (!mounted) return;
    setState(() {
      _incoming = incoming;
      _sent = sent;
    });
  }

  Future<void> _add() async {
    if (_adding) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _adding = true;
      _addMessage = null;
    });
    final result = await SocialService.sendFriendRequest(name);
    if (!mounted) return;
    setState(() => _adding = false);
    switch (result) {
      case FriendRequestResult.sent:
        _nameCtrl.clear();
        setState(() => _addMessage = tr('friendsRequestSentOk'));
        _loadRequests();
      case FriendRequestResult.queued:
        // Sin internet: quedó guardada y se envía sola.
        _nameCtrl.clear();
        setState(() => _addMessage = tr('friendsRequestQueued'));
        _loadRequests();
      case FriendRequestResult.alreadyFriends:
        setState(() => _addMessage = tr('friendsRequestAlreadyFriends'));
      case FriendRequestResult.alreadySent:
        setState(() => _addMessage = tr('friendsRequestAlreadySent'));
      case FriendRequestResult.incomingPending:
        setState(() => _addMessage =
            tr('friendsRequestIncoming').replaceFirst('%s', name));
        _loadRequests();
      case FriendRequestResult.self:
        setState(() => _addMessage = tr('friendsRequestSelf'));
      case FriendRequestResult.notFound:
        setState(() => _addMessage = tr('friendsAddNotFound'));
      case FriendRequestResult.unavailable:
        setState(() => _addMessage = tr('friendsRequestUnavailable'));
    }
  }

  Future<void> _accept(FriendRequest request) async {
    final ok = await SocialService.acceptFriendRequest(request.id);
    if (!mounted) return;
    if (ok) {
      setState(() => _addMessage = tr('friendsRequestAccepted'));
    }
    _loadRequests();
  }

  Future<void> _reject(FriendRequest request) async {
    await SocialService.rejectFriendRequest(request.id);
    if (!mounted) return;
    _loadRequests();
  }

  Future<void> _cancel(FriendRequest request) async {
    await SocialService.cancelFriendRequest(request.id);
    if (!mounted) return;
    _loadRequests();
  }

  void _challenge(FriendEntry friend) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => DuelScreen(
              opponentUsername: friend.username,
              isGoogleLinked: widget.isGoogleLinked,
              onLinkGoogle: widget.onLinkGoogle,
            ),
          ),
        )
        .then((_) => _loadDuels());
  }

  void _randomDuel() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => DuelScreen(
              random: true,
              isGoogleLinked: widget.isGoogleLinked,
              onLinkGoogle: widget.onLinkGoogle,
            ),
          ),
        )
        .then((_) => _loadDuels());
  }

  /// Abre un duelo de la lista (el retado entra a jugar el suyo).
  void _openDuel(DuelState duel) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => DuelScreen(
              initialMatch: duel,
              isGoogleLinked: widget.isGoogleLinked,
              onLinkGoogle: widget.onLinkGoogle,
            ),
          ),
        )
        .then((_) => _loadDuels());
  }

  /// Estado de un duelo de la lista, en una línea.
  String _duelStatus(DuelState duel) {
    switch (duel.phase) {
      case DuelPhase.searching:
        return tr('myDuelsSearching');
      case DuelPhase.intro:
        return duel.incoming ? tr('myDuelsYourTurn') : tr('myDuelsWaiting');
      case DuelPhase.playing:
        return tr('myDuelsPlaying');
      case DuelPhase.waiting:
        return tr('myDuelsWaiting');
      case DuelPhase.finished:
      case DuelPhase.abandoned:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const teal = Color(0xFF00C2A8);
    return Scaffold(
      appBar: AppBar(title: Text(tr('friendsTitle'))),
      body: OnlineGate(
        isGoogleLinked: widget.isGoogleLinked,
        onLinkGoogle: widget.onLinkGoogle,
        child: Column(
          children: [
            // Duelo al azar: se queda, con su fila plana sin sombra.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _randomDuel,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: teal.withValues(alpha: 0.14),
                          ),
                          alignment: Alignment.center,
                          child: const LucideIcon(
                            LucideIcons.gamepad2,
                            size: 22,
                            color: teal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('friendsRandomDuel'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onSurface,
                                ),
                              ),
                              Text(
                                tr('friendsRandomDuelSub'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const LucideIcon(
                          LucideIcons.chevronRight,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: isDark ? _lineDark : _lineLight,
            ),
            // Mis duelos abiertos: sin la lista, el retado no puede
            // ver ni abrir su duelo. Solo se muestra si hay alguno
            // (y si hay internet); al volver de un duelo se recarga.
            if (_online && _myDuels.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        tr('myDuelsTitle'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : _sectionLight,
                        ),
                      ),
                    ),
                    // Duelos abiertos, filas planas sin tarjeta ni
                    // sombra, separadas por líneas finas.
                    Column(
                      children: [
                        for (var i = 0; i < _myDuels.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 68,
                              color: isDark ? _lineDark : _lineLight,
                            ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _openDuel(_myDuels[i]),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 12),
                                child: Row(
                                  children: [
                                    SocialAvatar(
                                      username: _myDuels[i].opponentName,
                                      size: 40,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _myDuels[i].opponentName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                          Text(
                                            _duelStatus(_myDuels[i]),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const LucideIcon(
                                      LucideIcons.chevronRight,
                                      size: 20,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? _lineDark : _lineLight,
                    ),
                  ],
                ),
              ),
            // Agregar por nombre: campo con radio 16 y borde 2 pt
            // #E5E5E5, 56 pt de alto; el botón "AGREGAR" va a ancho
            // completo DEBAJO del campo (rediseño Duolingo 7.0).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 56,
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: tr('friendsAddHint'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E5E5),
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E5E5),
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF84D8FF),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 16),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: DuoButton.primary(
                      label: tr('friendsAddButton').toUpperCase(),
                      onPressed: _adding ? null : _add,
                      topColor: teal,
                      bottomColor: teal,
                      edgeColor: const Color(0xFF00A18D),
                      fontSize: 17,
                      shine: false,
                    ),
                  ),
                  if (_addMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _addMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Solicitudes pendientes: aunque la notificación no
            // llegue, aquí se ve quién me escribió y puedo confirmar
            // o eliminar; las mías muestran "Solicitud enviada" +
            // Cancelar. Con Retar solo en amigos confirmados.
            if (_online && (_incoming.isNotEmpty || _sent.isNotEmpty))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        tr('friendsRequestsTitle'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : _sectionLight,
                        ),
                      ),
                    ),
                    for (final r in _incoming) ...[
                      _RequestRow(
                        request: r,
                        incoming: true,
                        isDark: isDark,
                        scheme: scheme,
                        onConfirm: () => _accept(r),
                        onDelete: () => _reject(r),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark ? _lineDark : _lineLight,
                      ),
                    ],
                    for (final r in _sent) ...[
                      _RequestRow(
                        request: r,
                        incoming: false,
                        isDark: isDark,
                        scheme: scheme,
                        onConfirm: () {},
                        onDelete: () => _cancel(r),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark ? _lineDark : _lineLight,
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Expanded(
              child: !_online
                  ? _CalmLine(text: tr('socialOffline'))
                  : StreamBuilder<List<FriendEntry>>(
                      stream: SocialService.friendsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return _CalmLine(text: tr('socialOffline'));
                        }
                        final friends = snapshot.data ?? [];
                        if (friends.isEmpty) {
                          return _EmptyFriends(scheme: scheme);
                        }
                        // Filas planas separadas por líneas finas
                        // (rediseño Duolingo 7.0).
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                          itemCount: friends.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            thickness: 1,
                            color: isDark ? _lineDark : _lineLight,
                          ),
                          itemBuilder: (context, index) => _FriendRow(
                            friend: friends[index],
                            isDark: isDark,
                            scheme: scheme,
                            onChallenge: () => _challenge(friends[index]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Línea tranquila centrada (sin internet): sin rojo ni iconos
/// de error.
class _CalmLine extends StatelessWidget {
  const _CalmLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, height: 1.5),
        ),
      ),
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  const _EmptyFriends({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00C2A8).withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: const LucideIcon(
                LucideIcons.userRound,
                size: 34,
                color: Color(0xFF00C2A8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('friendsEmpty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.isDark,
    required this.scheme,
    required this.onChallenge,
  });

  final FriendEntry friend;
  final bool isDark;
  final ColorScheme scheme;
  final VoidCallback onChallenge;

  @override
  Widget build(BuildContext context) {
    // Fila plana (rediseño Duolingo 7.0): sin tarjeta, sin sombra;
    // la línea divisoria la pone el separador de la lista. Sin
    // icono de papelera: la eliminación no vive en la fila.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          // Avatar con cara (SocialAvatar; la Zona A lo reescribe
          // con la cara por defecto) o la foto premium del amigo.
          SocialAvatar(
            username: friend.username,
            avatarAsset: friend.avatarAsset,
            badgeId: friend.badgeId,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.username,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tr('lbLevels')} ${friend.levelsPassedTotal} · '
                  '${tr('pointsWord')} ${friend.points} · '
                  '${tr('streakWord')} ${friend.streak}',
                  // Una sola línea con elipsis: si el texto es
                  // largo, todas las filas siguen midiendo lo
                  // mismo (regla 8) en vez de crecer a dos líneas.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // "Retar": botón secundario Duolingo (blanco + borde 2 pt
          // #E5E5E5 + labio 4 pt #E5E5E5 + texto #4B4B4B 17 pt
          // peso 700), no píldora con borde teal.
          DuoButton.secondary(
            label: tr('friendsChallenge').toUpperCase(),
            onPressed: onChallenge,
            textColor: const Color(0xFF4B4B4B),
            edgeColor: const Color(0xFFE5E5E5),
            fontSize: 17,
          ),
        ],
      ),
    );
  }
}

/// Una solicitud pendiente en la sección "Solicitudes":
/// entrante = nombre + "te envió una solicitud" + Confirmar y
/// Eliminar; enviada = nombre + "Solicitud enviada" + Cancelar.
/// Fila plana sin tarjeta ni sombra (rediseño Duolingo 7.0):
/// "Confirmar" es teal sólido con labio; "Eliminar"/"Cancelar"
/// son botones secundarios con texto gris.
class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.request,
    required this.incoming,
    required this.isDark,
    required this.scheme,
    required this.onConfirm,
    required this.onDelete,
  });

  final FriendRequest request;
  final bool incoming;
  final bool isDark;
  final ColorScheme scheme;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;

  static const _teal = Color(0xFF00C2A8);
  static const _tealLip = Color(0xFF00A18D);

  @override
  Widget build(BuildContext context) {
    final otherName =
        incoming ? request.senderUsername : request.receiverUsername;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Avatar con cara (SocialAvatar) o foto premium.
              SocialAvatar(username: otherName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      otherName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      incoming
                          ? tr('friendsRequestReceived')
                          : tr('friendsRequestSentLabel'),
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (incoming) ...[
                Expanded(
                  child: DuoButton.primary(
                    label: tr('friendsRequestAccept').toUpperCase(),
                    onPressed: onConfirm,
                    topColor: _teal,
                    bottomColor: _teal,
                    edgeColor: _tealLip,
                    fontSize: 17,
                    shine: false,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DuoButton.secondary(
                    label: tr('friendsRequestReject').toUpperCase(),
                    onPressed: onDelete,
                    textColor: const Color(0xFF777777),
                    edgeColor: const Color(0xFFE5E5E5),
                    fontSize: 17,
                  ),
                ),
              ] else
                Expanded(
                  child: DuoButton.secondary(
                    label: tr('friendsRequestCancel').toUpperCase(),
                    onPressed: onDelete,
                    textColor: const Color(0xFF777777),
                    edgeColor: const Color(0xFFE5E5E5),
                    fontSize: 17,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
