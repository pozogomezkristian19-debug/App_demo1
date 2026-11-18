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
// Búsqueda (Kristian 2026-11-15): UNA SOLA casilla ("Buscar por
// nombre de usuario"); al escribir salen los nombres parecidos
// como resultados. NO hay segunda casilla ni botón AGREGAR grande:
// cada resultado lleva a la derecha la IMAGEN de agregar amigo
// (assets/add_friend.png, logo real de Flaticon) y al tocarla se
// envía la solicitud (el mismo flujo de siempre).
//
// DISEÑO (rediseño Duolingo 7.0, Zona C): filas planas sin
// tarjeta y sin sombra, separadas por líneas finas #E5E5E5;
// avatares con cara (SocialAvatar, nunca inicial); "Retar" =
// DuoButton.secondary, "Confirmar" = color del acento sólido con labio,
// "Eliminar"/"Cancelar" = secundario gris; sin icono
// de papelera en las filas; secciones a 20 pt peso 800.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/accent.dart';
import '../services/auth_service.dart';
import '../services/localization.dart';
import '../services/social_service.dart';
import '../services/user_prefs.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/online_gate.dart';
import '../widgets/social_avatar.dart';
import 'duel_screen.dart';
import 'friend_profile_screen.dart';

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
  var _online = true;
  String? _addMessage;

  /// Búsqueda de amigos (Kristian 2026-11-15): barra arriba, con
  /// debounce de 300 ms; _searched = ya se buscó algo (para el
  /// mensaje de "no encontramos a nadie").
  final _searchCtrl = TextEditingController();
  Timer? _searchTimer;
  var _searching = false;
  var _searched = false;
  var _searchResults = <FriendEntry>[];

  /// Ids de mis amigos (para el estado del botón Invitar y para
  /// abrir el perfil solo de quien ya es amigo).
  var _friendIds = <String>{};

  /// Solicitudes pendientes: las que me llegaron y las que envié.
  var _incoming = <FriendRequest>[];
  var _sent = <FriendRequest>[];

  /// Mis duelos abiertos (para que el retado abra el suyo).
  List<DuelState> _myDuels = [];

  /// Mi nombre de usuario público (Quemia 7.3, Kristian): el que
  /// le doy a un amigo para que me agregue. null = aún cargando;
  /// '' = sin poner (Kristian 2026-11-16: ya nada lo reclama solo;
  /// se pone en el perfil, con la tarjeta "¡Completa tu perfil!").
  String? _myUsername;

  @override
  void initState() {
    super.initState();
    SocialService.online.then((v) {
      if (mounted) setState(() => _online = v);
    });
    _loadDuels();
    _loadRequests();
    _loadUsername();
    _searchCtrl.addListener(_onSearchChanged);
  }

  /// Solo LEE el nombre guardado (Kristian 2026-11-16: ya nada lo
  /// reclama solo). Sin nombre, la tarjeta enseña que hay que
  /// ponerlo en el perfil.
  void _loadUsername() {
    if (!mounted) return;
    setState(() => _myUsername = UserPrefs.publicUsername);
  }

  Future<void> _copyUsername() async {
    final username = _myUsername ?? '';
    if (username.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: username));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('myUsernameCopied'))),
    );
  }

  Future<void> _loadDuels() async {
    final duels = await SocialService.myOpenDuels();
    if (!mounted) return;
    setState(() => _myDuels = duels);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Ids de mis amigos: se recargan con las solicitudes, así el
  /// botón Invitar y el perfil se actualizan al aceptar o enviar.
  /// Incluye los mutuos sin solicitud (ver [_mutualOnly]).
  Future<void> _loadFriendIds() async {
    final friends = await SocialService.friends();
    if (!mounted) return;
    final ids = friends.map((f) => f.deviceId).toSet();
    setState(() => _friendIds = ids);
    await _loadMutualOnly(ids);
  }

  /// Amigos por seguimiento mutuo SIN solicitud (lote 2026-11-16):
  /// Amigos = los que se siguen mutuamente. Dos personas que se
  /// siguen (botón SEGUIR) sin haberse mandado solicitud también
  /// son amigas: se suman a la lista de amigos del flujo de
  /// solicitudes, sin duplicar, y sus ids entran en [_friendIds]
  /// para que la búsqueda los vea como amigos. Sin sesión no hay
  /// nada que sumar.
  List<FriendEntry> _mutualOnly = [];

  Future<void> _loadMutualOnly(Set<String> friendIds) async {
    final me = AuthService.currentUid ?? '';
    if (me.isEmpty) return;
    final following = await SocialService.followingList(me);
    final followers = await SocialService.followersList(me);
    final followerIds = followers.map((f) => f.deviceId).toSet();
    final mutual = following
        .where((f) =>
            followerIds.contains(f.deviceId) &&
            !friendIds.contains(f.deviceId))
        .toList();
    if (!mounted) return;
    setState(() {
      _mutualOnly = mutual;
      _friendIds = {
        ...friendIds,
        ...mutual.map((m) => m.deviceId),
      };
    });
  }

  void _onSearchChanged() {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searched = false;
          _searching = false;
        });
      }
      return;
    }
    if (!_online) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searched = true;
          _searching = false;
        });
      }
      return;
    }
    setState(() => _searching = true);
    final results = await SocialService.searchUsers(q);
    if (!mounted) return;
    // Si el usuario ya escribió otra cosa, no pisar con
    // resultados viejos.
    if (_searchCtrl.text.trim() != q) return;
    setState(() {
      _searchResults = results;
      _searched = true;
      _searching = false;
    });
  }

  /// Estado del botón de un resultado: amigo (abre el perfil),
  /// solicitud ya enviada, solicitud entrante pendiente, o nadie
  /// todavía (Invitar).
  _SearchButtonState _stateOf(FriendEntry user) {
    if (_friendIds.contains(user.deviceId)) {
      return _SearchButtonState.friend;
    }
    if (_sent.any((r) => r.receiverUid == user.deviceId)) {
      return _SearchButtonState.sent;
    }
    if (_incoming.any((r) => r.senderUid == user.deviceId)) {
      return _SearchButtonState.incoming;
    }
    return _SearchButtonState.none;
  }

  /// Invitar desde un resultado (tocando la imagen de agregar
  /// amigo a la derecha del nombre): manda la solicitud; el
  /// resultado cambia a Enviada (o Amigo si ya lo era). Sin
  /// duplicados: la solicitud pendiente ya deja el resultado en
  /// Enviada. El aviso tranquilo sale debajo del buscador.
  Future<void> _invite(FriendEntry user) async {
    final result = await SocialService.sendFriendRequest(user.username);
    if (!mounted) return;
    switch (result) {
      case FriendRequestResult.sent:
        setState(() => _addMessage = tr('friendsRequestSentOk'));
        _loadRequests();
        _loadFriendIds();
      case FriendRequestResult.queued:
        // Sin internet: quedó guardada y se envía sola.
        setState(() => _addMessage = tr('friendsRequestQueued'));
        _loadRequests();
        _loadFriendIds();
      case FriendRequestResult.alreadySent:
      case FriendRequestResult.alreadyFriends:
      case FriendRequestResult.incomingPending:
        _loadRequests();
        _loadFriendIds();
        setState(() {});
      case FriendRequestResult.self:
        setState(() => _addMessage = tr('friendsRequestSelf'));
      case FriendRequestResult.notFound:
        setState(() => _addMessage = tr('friendsAddNotFound'));
      case FriendRequestResult.unavailable:
        setState(() => _addMessage = tr('friendsRequestUnavailable'));
    }
  }

  /// Abre el perfil de un amigo (Kristian 2026-11-15): solo los
  /// amigos tienen perfil visible.
  void _openProfile(FriendEntry friend) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendProfileScreen(
          friend: friend,
          isGoogleLinked: widget.isGoogleLinked,
          onLinkGoogle: widget.onLinkGoogle,
        ),
      ),
    );
  }

  /// Filas de resultados de la búsqueda (sin el mensaje ni el
  /// cargando): cada una con su estado calculado una sola vez.
  List<Widget> _searchResultWidgets(bool isDark, ColorScheme scheme) {
    final out = <Widget>[];
    for (final u in _searchResults) {
      final state = _stateOf(u);
      out.add(
        _SearchResultRow(
          entry: u,
          state: state,
          isDark: isDark,
          scheme: scheme,
          onInvite: () => _invite(u),
          onProfile:
              state == _SearchButtonState.friend ? () => _openProfile(u) : null,
        ),
      );
      out.add(
        Divider(
          height: 1,
          thickness: 1,
          color: isDark ? _lineDark : _lineLight,
        ),
      );
    }
    return out;
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
    _loadFriendIds();
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
    final accent = AppAccent.primary;
    return Scaffold(
      appBar: AppBar(title: Text(tr('friendsTitle'))),
      body: OnlineGate(
        isGoogleLinked: widget.isGoogleLinked,
        onLinkGoogle: widget.onLinkGoogle,
        // Toda la página desplaza como una sola (fix8_amigos):
        // antes el Column fijo + Expanded(lista) se desbordaba
        // 14 px cuando había duelo entrante Y solicitudes a la
        // vez, porque las secciones fijas sumaban más que la
        // pantalla y la lista quedaba en altura ~0.
        child: SingleChildScrollView(
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: 0.14),
                            ),
                            alignment: Alignment.center,
                            child: LucideIcon(
                              LucideIcons.gamepad2,
                              size: 22,
                              color: accent,
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
              // Mi nombre de usuario (Quemia 7.3, Kristian): para
              // que un amigo me agregue, le doy ESTE nombre, no el
              // código de referido (ese es para invitar). Tarjeta con
              // tinte del acento + botón COPIAR; si aún no existe
              // (sin internet), se dice que aparecerá aquí.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('myUsernameTitle'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _myUsername == null
                                  ? '…'
                                  : (_myUsername!.isEmpty
                                      ? tr('myUsernamePending')
                                      : _myUsername!),
                              // 2 líneas (antes 1): el mensaje pendiente
                              // "Tu nombre de usuario aparecerá aquí" se
                              // cortaba a "Tu nombre de usuario…" porque
                              // el botón COPIAR ocupa ancho; el nombre
                              // real es una sola palabra y cabe en 1.
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _myUsername != null &&
                                        _myUsername!.isNotEmpty
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DuoButton.secondary(
                            label: tr('referralCopy'),
                            onPressed:
                                (_myUsername != null && _myUsername!.isNotEmpty)
                                    ? _copyUsername
                                    : null,
                            fontSize: 15,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('myUsernameHint'),
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Búsqueda de amigos (Kristian 2026-11-15): barra
              // arriba; SOLO por nombre de usuario (sin correo).
              // Nombre exacto → solo ese usuario, nombre parcial
              // → todos los relacionados. Cada resultado muestra
              // el nombre de usuario real (para verificar la
              // cuenta antes de invitar), la imagen de agregar
              // amigo a la derecha (al tocarla se envía la
              // solicitud) y, si ya es amigo, abre su perfil.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  key: const ValueKey('friends-search-results'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 56,
                      child: TextField(
                        key: const ValueKey('friends-search-field'),
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: tr('friendsSearchHint'),
                          prefixIcon: const LucideIcon(
                            LucideIcons.search,
                            size: 22,
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? _lineDark : _lineLight,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? _lineDark : _lineLight,
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
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) {
                          _searchTimer?.cancel();
                          _runSearch();
                        },
                      ),
                    ),
                    if (_searching) ...[
                      const SizedBox(height: 16),
                      const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    ] else if (_searched && _searchResults.isEmpty) ...[
                      const SizedBox(height: 16),
                      _CalmLine(
                        text: _online
                            ? tr('friendsSearchNoResults')
                            : tr('friendsSearchOffline'),
                      ),
                    ] else if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ..._searchResultWidgets(isDark, scheme),
                    ],
                    // Aviso tranquilo (solicitud enviada, aceptada
                    // o en cola): una línea debajo del buscador,
                    // sin diálogo ni SnackBar.
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
              // Sin Expanded: dentro del scroll, la lista mide su
              // propio alto (shrinkWrap) y la página entera desplaza.
              if (!_online)
                _CalmLine(text: tr('socialOffline'))
              else
                StreamBuilder<List<FriendEntry>>(
                  stream: SocialService.friendsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _CalmLine(text: tr('socialOffline'));
                    }
                    final friends = snapshot.data ?? [];
                    // Amigos por seguimiento mutuo sin solicitud
                    // (ver [_mutualOnly]): se suman sin duplicar.
                    final ids =
                        friends.map((f) => f.deviceId).toSet();
                    final all = [
                      ...friends,
                      ..._mutualOnly.where(
                          (m) => !ids.contains(m.deviceId)),
                    ];
                    if (all.isEmpty) {
                      return _EmptyFriends(scheme: scheme);
                    }
                    // Filas planas separadas por líneas finas
                    // (rediseño Duolingo 7.0).
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                      itemCount: all.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark ? _lineDark : _lineLight,
                      ),
                      itemBuilder: (context, index) => _FriendRow(
                        friend: all[index],
                        isDark: isDark,
                        scheme: scheme,
                        onChallenge: () => _challenge(all[index]),
                        onProfile: () => _openProfile(all[index]),
                      ),
                    );
                  },
                ),
            ],
          ),
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
                color: AppAccent.primary.withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: LucideIcon(
                LucideIcons.userRound,
                size: 34,
                color: AppAccent.primary,
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
    this.onProfile,
  });

  final FriendEntry friend;
  final bool isDark;
  final ColorScheme scheme;
  final VoidCallback onChallenge;

  /// Abrir el perfil del amigo (Kristian 2026-11-15): tocar la
  /// fila (no el botón Retar) abre su perfil.
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    // Fila plana (rediseño Duolingo 7.0): sin tarjeta, sin sombra;
    // la línea divisoria la pone el separador de la lista. Sin
    // icono de papelera: la eliminación no vive en la fila.
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          // Avatar con cara (SocialAvatar; la Zona A lo reescribe
          // con la cara por defecto) o la foto premium del amigo.
          SocialAvatar(
            username: friend.username,
            avatarAsset: friend.avatarAsset,
            badgeId: friend.badgeId,
            frameItem: friend.frameItem,
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
                  _friendStatsLine(friend),
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
          // peso 700), no píldora con borde del acento.
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
    if (onProfile == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onProfile, child: content),
    );
  }
}

/// 'Niveles X · Puntos Y · Racha Z · Trofeos a/b': la misma línea
/// de la fila de amigo, en la lista y en los resultados de la
/// búsqueda. Trofeos solo cuando el amigo tiene exámenes por tema.
String _friendStatsLine(FriendEntry friend) =>
    '${tr('lbLevels')} ${friend.levelsPassedTotal} · '
    '${tr('pointsWord')} ${friend.points} · '
    '${tr('streakWord')} ${friend.streak}'
    // Trofeos (examen por tema, Kristian 2026-11-14): los demás
    // ven cuántos trofeos lleva cada amigo.
    '${friend.trophiesTotal > 0 ? ' · ${tr('trophiesWord')} ${friend.trophiesWon}/${friend.trophiesTotal}' : ''}';

/// Estado del botón de un resultado de búsqueda: amigo (abre el
/// perfil), solicitud ya enviada, solicitud entrante pendiente, o
/// nadie todavía (Invitar).
enum _SearchButtonState { friend, sent, incoming, none }

/// Un resultado de la búsqueda: avatar con cara + nombre + la
/// misma línea de puntos/niveles/racha/trofeos de la fila de
/// amigo, y a la DERECHA la imagen de agregar amigo (Kristian
/// 2026-11-15: en vez de botón, el logo real de Flaticon
/// assets/add_friend.png); al tocarla se envía la solicitud.
/// Solo es táctil (abre el perfil) cuando ya es amigo; los demás
/// muestran la imagen, Enviada o Pendiente según el estado.
class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.entry,
    required this.state,
    required this.isDark,
    required this.scheme,
    required this.onInvite,
    this.onProfile,
  });

  final FriendEntry entry;
  final _SearchButtonState state;
  final bool isDark;
  final ColorScheme scheme;
  final VoidCallback onInvite;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          SocialAvatar(
            username: entry.username,
            avatarAsset: entry.avatarAsset,
            badgeId: entry.badgeId,
            frameItem: entry.frameItem,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.username,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _friendStatsLine(entry),
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
          const SizedBox(width: 8),
          _inviteButton(),
        ],
      ),
    );
    if (onProfile == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onProfile, child: content),
    );
  }

  Widget _inviteButton() {
    switch (state) {
      case _SearchButtonState.friend:
        return DuoButton.secondary(
          label: tr('friendsIsFriend').toUpperCase(),
          onPressed: null,
          textColor: const Color(0xFF777777),
          edgeColor: const Color(0xFFE5E5E5),
          fontSize: 15,
        );
      case _SearchButtonState.sent:
        return DuoButton.secondary(
          label: tr('friendsInviteSent').toUpperCase(),
          onPressed: null,
          textColor: const Color(0xFF777777),
          edgeColor: const Color(0xFFE5E5E5),
          fontSize: 15,
        );
      case _SearchButtonState.incoming:
        return DuoButton.secondary(
          label: tr('friendsInvitePending').toUpperCase(),
          onPressed: null,
          textColor: const Color(0xFF777777),
          edgeColor: const Color(0xFFE5E5E5),
          fontSize: 15,
        );
      case _SearchButtonState.none:
        // Imagen REAL de agregar amigo (Kristian 2026-11-15:
        // logo de Flaticon, assets/add_friend.png, guardado en
        // el proyecto para que funcione sin internet). Al
        // tocarla se envía la solicitud, como el botón Invitar
        // de antes. Sin texto: la imagen es el botón.
        return GestureDetector(
          key: ValueKey('addFriendImage-${entry.username}'),
          onTap: onInvite,
          child: Tooltip(
            message: tr('friendsInvite'),
            child: Image.asset(
              'assets/add_friend.png',
              width: 44,
              height: 44,
              semanticLabel: tr('friendsInvite'),
            ),
          ),
        );
    }
  }
}

/// Una solicitud pendiente en la sección "Solicitudes":
/// entrante = nombre + "te envió una solicitud" + Confirmar y
/// Eliminar; enviada = nombre + "Solicitud enviada" + Cancelar.
/// Fila plana sin tarjeta ni sombra (rediseño Duolingo 7.0):
/// "Confirmar" es el color del acento sólido con labio; "Eliminar"/"Cancelar"
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
