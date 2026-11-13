// Referidos (Quemia 7.3): invita con tu código y los dos ganan
// puntos. Sin deep link en la V1: el amigo escribe el código de
// 6 letras y números en "Canjear código".
//
// REGLAS (diseño aprobado 2026-11-12, sin contactos: la app no
// vincula el número de teléfono ni tiene permiso de contactos):
// - Solo con Google vinculada (puerta de identidad 7.0): sin
//   Google no hay código, ni canje, ni premios.
// - Código aleatorio de 6 caracteres por usuario; el documento
//   'referral_codes/<CÓDIGO>' es el dueño del código (la unicidad
//   la garantizan las reglas: crear solo si no existe; ver
//   REFERRALS_FIRESTORE.md).
// - Invitador +50 puntos / invitado +20 puntos cuando el invitado
//   pasa el Nivel 1 (cualquier tema). Los puntos se suman EN LOCAL
//   (ProgressService) y la subida normal de progreso los lleva a
//   la nube; el conteo de referidos y los hitos van en el propio
//   documento del usuario.
// - Hitos: 3 → avatar Embajador; 5 → tema Embajador + insignia
//   Embajador; 10 → avatar Leyenda + 200 puntos (ver
//   referral_rewards.dart).
// - Un código vale hasta 10 usos; un amigo solo puede canjear un
//   código una vez, y nunca el propio.
// - USERNAMES ÚNICOS: el nombre público (el que se ve en la tabla,
//   en Amigos y en los avisos) es único en toda la app; si choca,
//   se le añade un sufijo numérico entre bastidores (Vanessa0394).
//   El saludo ("Bienvenida Vanessa") NO cambia: sigue usando el
//   nombre del onboarding (UserPrefs.userName).
// - Sin internet no pasa nada malo (Regla 2): cada llamada lleva
//   timeout de 5 s; lo que no se pudo escribir queda encolado en
//   local y se reintenta solo (retryPending).
//
// CÓMO SE PAGAN LOS PUNTOS DEL INVITADOR (sin Cloud Function):
// el invitado NO puede escribir en el documento del invitador
// (las reglas lo prohíben), así que el pago es en dos pasos:
// 1) al pasar el Nivel 1, el invitado marca su propio documento
//    de referido ('referrals/<id>') como 'rewarded';
// 2) al abrir Invitar, el invitador lee sus referidos en estado
//    'rewarded' y sin cobrar, y se paga a sí mismo (+50, conteo,
//    hitos) marcando el documento como cobrado. Idempotente: un
//    referido solo se cobra una vez (inviterRewarded).
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_sync.dart';
import 'auth_service.dart';
import 'localization.dart';
import 'online_common.dart';
import 'progress.dart';
import 'referral_rewards.dart';
import 'social_service.dart';
import 'user_prefs.dart';

/// Puntos del invitador cuando su amigo pasa el Nivel 1.
const int kReferralInviterPoints = 50;

/// Puntos del invitado cuando pasa el Nivel 1.
const int kReferralInviteePoints = 20;

/// Usos máximos de un código (mockup: "5 de 10 usos").
const int kReferralMaxUses = 10;

/// Longitud del código.
const int kReferralCodeLength = 6;

/// Caracteres del código: sin 0, 1, I, L ni O (se confunden).
const String kReferralCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Genera un código aleatorio de 6 caracteres. Puro y testeable.
String generateReferralCode([Random? random]) {
  final r = random ?? Random.secure();
  final buf = StringBuffer();
  for (var i = 0; i < kReferralCodeLength; i++) {
    buf.write(kReferralCodeAlphabet[r.nextInt(kReferralCodeAlphabet.length)]);
  }
  return buf.toString();
}

/// Resultado de canjear un código.
enum RedeemResult {
  ok,
  needsGoogle,
  invalid,
  notFound,
  ownCode,
  alreadyRedeemed,
  exhausted,
  offline,
  error,
}

/// Lo que el invitador cobró al abrir Invitar (para celebrarlo
/// en la pantalla): nombres de los amigos nuevos y hitos nuevos.
class ClaimResult {
  const ClaimResult({
    this.newReferrals = const [],
    this.newMilestones = const [],
  });

  final List<String> newReferrals;
  final List<int> newMilestones;

  bool get hasNews => newReferrals.isNotEmpty || newMilestones.isNotEmpty;
}

/// Un puesto de la tabla de los que más invitan.
class TopReferrer {
  const TopReferrer({
    required this.username,
    required this.referralsCount,
    this.avatarId,
  });

  final String username;
  final int referralsCount;
  final String? avatarId;
}

/// Foto del estado de referidos para la pantalla Invitar.
class ReferralState {
  const ReferralState({
    this.code = '',
    this.usesLeft = kReferralMaxUses,
    this.referralsCount = 0,
    this.milestonesGranted = const [],
    this.lastInvitee,
    this.topReferrers = const [],
    this.needsGoogle = false,
    this.offline = false,
    this.claim,
  });

  final String code;
  final int usesLeft;
  final int referralsCount;
  final List<int> milestonesGranted;
  final String? lastInvitee;
  final List<TopReferrer> topReferrers;
  final bool needsGoogle;
  final bool offline;

  /// Lo que se cobró al cargar (referidos nuevos / hitos): lo pone
  /// [ReferralService.loadState] para que la pantalla celebre el
  /// cobro sin llamar dos veces a claimInviterRewards (Quemia 7.5:
  /// la pantalla lo llamaba y loadState también, y el doble cobro
  /// en paralelo podía pagar dos veces).
  final ClaimResult? claim;

  /// Mensaje listo para compartir (mockup Invitar). Usa la misma
  /// clave que la tarjeta "Mensaje listo" de la pantalla.
  String shareMessage() =>
      '${tr('referralMessageBody').replaceAll('{code}', code)} '
      'https://quemia-8410a.web.app';
}

class ReferralService {
  ReferralService._();

  static const _kMyCode = 'referral_my_code';
  static const _kReferredBy = 'referral_referred_by';
  static const _kReferredByUid = 'referral_referred_by_uid';
  static const _kReferredDocId = 'referral_referred_doc_id';
  static const _kRewarded = 'referral_rewarded';
  static const _kCount = 'referral_count';
  static const _kMilestones = 'referral_milestones';
  static const _kLastInvitee = 'referral_last_invitee';
  static const _kPendingCode = 'referral_pending_code';
  static const _kPendingRedeem = 'referral_pending_redeem';
  static const _kPendingReward = 'referral_pending_reward';

  static AnalyticsRepository get _repo => AnalyticsSync.repository;
  static String get _me => AuthService.currentUid ?? '';
  static bool get _allowed => OnlineCommon.allowed && _me.isNotEmpty;

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  // ---- Nombre público único ----

  /// Base del nombre público: primer nombre del onboarding, solo
  /// letras y números, con la primera en mayúscula. Vacío si no
  /// hay nombre (entonces 'Quimico').
  static String _usernameBase() {
    final first = UserPrefs.firstName;
    final clean = first.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9]'), '');
    if (clean.isEmpty) return 'Quimico';
    final capped = clean.length > 20 ? clean.substring(0, 20) : clean;
    return capped[0].toUpperCase() + capped.substring(1);
  }

  /// Reclama un nombre público único para este usuario (o devuelve
  /// el que ya tiene). Si el nombre base está cogido, se prueba con
  /// un sufijo de 4 dígitos (Vanessa0394) hasta 12 intentos. El
  /// saludo no cambia: sigue usando el nombre del onboarding.
  /// Devuelve '' si no hay Google o si no se pudo reclamar (sin
  /// internet): se reintenta en la próxima apertura de Invitar.
  static Future<String> ensureUniqueUsername() async {
    if (!_allowed) return UserPrefs.publicUsername;
    final existing = UserPrefs.publicUsername;
    if (existing.isNotEmpty) return existing;
    final base = _usernameBase();
    final random = Random.secure();
    for (var attempt = 0; attempt < 12; attempt++) {
      final candidate =
          attempt == 0 ? base : '$base${1000 + random.nextInt(9000)}';
      final lower = candidate.toLowerCase();
      // ¿Está cogido? Se lee primero: el falso en memoria (y el
      // cliente) no distingue "no existe" de "sin internet" en la
      // escritura, así que la lectura decide. Si existe y es mío,
      // es mi nombre; si es de otro, se prueba con otro sufijo.
      // En producción las reglas son el respaldo: crear falla si
      // el documento ya existe (carrera entre dos usuarios).
      final existing = await OnlineCommon.call(
          () => _repo.getDoc('usernames', lower));
      if (existing != null) {
        if (existing['uid'] == _me) {
          await UserPrefs.savePublicUsername(candidate);
          return candidate;
        }
        continue;
      }
      final ok = await OnlineCommon.write(() => _repo.setDoc(
            'usernames',
            lower,
            <String, dynamic>{
              'uid': _me,
              'createdAtMs': DateTime.now().millisecondsSinceEpoch,
            },
            merge: false,
          ));
      if (!ok) continue;
      // Reclamado: se guarda en local y en el propio documento
      // (la subida de progreso lo conserva: _buildSnapshot usa
      // el nombre público cuando lo hay).
      await UserPrefs.savePublicUsername(candidate);
      final synced = await OnlineCommon.write(() =>
          _repo.setDoc('users', _me, {'username': candidate}));
      if (!synced) {
        await OnlineCommon.enqueue(
            _kPendingCode, {'username': candidate});
      }
      return candidate;
    }
    return '';
  }

  // ---- Mi código ----

  /// Mi código de invitación (lo crea si no existe). '' sin
  /// Google o sin internet (se reintenta en la próxima apertura).
  static Future<String> ensureMyCode() async {
    if (!_allowed) return '';
    try {
      final prefs = await _prefs;
      final cached = prefs.getString(_kMyCode) ?? '';
      if (cached.isNotEmpty) return cached;
      final doc = await OnlineCommon.call(() => _repo.getDoc('users', _me));
      final fromDoc = doc?['referralCode']?.toString() ?? '';
      if (fromDoc.isNotEmpty) {
        await prefs.setString(_kMyCode, fromDoc);
        return fromDoc;
      }
      // Sin código: se reclama uno nuevo. Si el documento ya
      // existe (otro usuario lo reclamó antes), la escritura
      // falla por las reglas y se prueba con otro código.
      for (var attempt = 0; attempt < 8; attempt++) {
        final code = generateReferralCode();
        final ok = await OnlineCommon.write(() => _repo.setDoc(
              'referral_codes',
              code,
              <String, dynamic>{
                'uid': _me,
                'createdAtMs': DateTime.now().millisecondsSinceEpoch,
                'maxUses': kReferralMaxUses,
              },
              merge: false,
            ));
        if (!ok) continue;
        await prefs.setString(_kMyCode, code);
        final synced = await OnlineCommon.write(
            () => _repo.setDoc('users', _me, {'referralCode': code}));
        if (!synced) {
          await OnlineCommon.enqueue(_kPendingCode, {'code': code});
        }
        return code;
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  // ---- Canjear ----

  /// Canjea el código de un amigo. El premio (+20) NO se paga
  /// aquí: se paga cuando el invitado pasa el Nivel 1
  /// ([maybeRewardInviteeOnLevelPass]).
  static Future<RedeemResult> redeemCode(String rawCode) async {
    if (!OnlineCommon.allowed || _me.isEmpty) {
      return RedeemResult.needsGoogle;
    }
    final code = rawCode.trim().toUpperCase();
    if (code.length != kReferralCodeLength ||
        !RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      return RedeemResult.invalid;
    }
    try {
      final prefs = await _prefs;
      if ((prefs.getString(_kReferredBy) ?? '').isNotEmpty) {
        return RedeemResult.alreadyRedeemed;
      }
      final myCode = prefs.getString(_kMyCode) ?? '';
      if (myCode.isNotEmpty && myCode == code) {
        return RedeemResult.ownCode;
      }
      final codeDoc = await OnlineCommon.call(
          () => _repo.getDoc('referral_codes', code));
      if (codeDoc == null) {
        // Sin internet la lectura devuelve null igual que un
        // código inexistente: se distingue con un ping.
        final online =
            await OnlineCommon.call(() => _repo.ping('users', _me));
        if (online != true) return RedeemResult.offline;
        return RedeemResult.notFound;
      }
      final inviterUid = codeDoc['uid']?.toString() ?? '';
      if (inviterUid.isEmpty || inviterUid == _me) {
        return RedeemResult.ownCode;
      }
      // Usos del código: se cuentan los referidos que ya lo
      // usaron (sin contador aparte, para no pelear por un campo
      // que escribe otro usuario).
      final used = await OnlineCommon.call(() => _repo.queryDocs(
            'referrals',
            whereField: 'code',
            isEqualTo: code,
          ));
      if (used == null) return RedeemResult.offline;
      if (used.length >= kReferralMaxUses) {
        return RedeemResult.exhausted;
      }
      // Nombre público único antes de escribir el referido (el
      // aviso del invitador enseña este nombre).
      await ensureUniqueUsername();
      final inviteeName = UserPrefs.publicUsername.isNotEmpty
          ? UserPrefs.publicUsername
          : UserPrefs.firstName;
      final now = DateTime.now().millisecondsSinceEpoch;
      final docId = await OnlineCommon.call(() => _repo.createDoc(
            'referrals',
            <String, dynamic>{
              'code': code,
              'inviterUid': inviterUid,
              'inviteeUid': _me,
              'inviteeUsername': inviteeName,
              'status': 'pending',
              'inviterRewarded': false,
              'createdAtMs': now,
            },
          ));
      if (docId == null) return RedeemResult.offline;
      // Se guarda en local primero (sin internet, el canje no se
      // pierde: el premio se paga al pasar el Nivel 1 y la
      // sincronización se reintenta sola).
      await prefs.setString(_kReferredBy, code);
      await prefs.setString(_kReferredByUid, inviterUid);
      await prefs.setString(_kReferredDocId, docId);
      await prefs.setBool(_kRewarded, false);
      final synced = await OnlineCommon.write(() => _repo.setDoc(
            'users',
            _me,
            <String, dynamic>{
              'referredBy': code,
              'referredByUid': inviterUid,
              'referralRewarded': false,
            },
          ));
      if (!synced) {
        await OnlineCommon.enqueue(_kPendingRedeem, {
          'code': code,
          'inviterUid': inviterUid,
        });
      }
      return RedeemResult.ok;
    } catch (_) {
      return RedeemResult.error;
    }
  }

  // ---- Premio del invitado (Nivel 1) ----

  /// Se llama al pasar un nivel ([level]): si es el Nivel 1 y el
  /// usuario canjeó un código sin cobrar, le suma +20 puntos y
  /// marca su referido como 'rewarded' (el invitador lo cobra al
  /// abrir Invitar). Sin internet se paga en local igual y la
  /// sincronización queda encolada. Si el teléfono es nuevo (sin
  /// el id del documento en local), busca su referido pendiente
  /// en la nube. Nunca lanza.
  static Future<void> maybeRewardInviteeOnLevelPass(int level) async {
    if (level != 1) return;
    try {
      final prefs = await _prefs;
      var code = prefs.getString(_kReferredBy) ?? '';
      if (code.isEmpty && _allowed) {
        // Teléfono nuevo: el canje vive en el documento propio.
        final doc =
            await OnlineCommon.call(() => _repo.getDoc('users', _me));
        final docCode = doc?['referredBy']?.toString() ?? '';
        final rewarded = doc?['referralRewarded'] == true;
        if (docCode.isNotEmpty && !rewarded) {
          code = docCode;
          await prefs.setString(_kReferredBy, code);
          await prefs.setString(
              _kReferredByUid, doc?['referredByUid']?.toString() ?? '');
        }
      }
      if (code.isEmpty) return;
      if (prefs.getBool(_kRewarded) == true) return;
      var docId = prefs.getString(_kReferredDocId) ?? '';
      if (docId.isEmpty && _allowed) {
        final rows = await OnlineCommon.call(() => _repo.queryDocs(
              'referrals',
              whereField: 'inviteeUid',
              isEqualTo: _me,
            ));
        final pending = (rows ?? [])
            .where((r) => r['status'] == 'pending')
            .toList();
        if (pending.isNotEmpty) {
          docId = pending.first['id']?.toString() ?? '';
          if (docId.isNotEmpty) {
            await prefs.setString(_kReferredDocId, docId);
          }
        }
      }
      // El premio es en local primero: los puntos ya son del
      // usuario aunque no haya internet.
      ProgressService.instance.addPoints(kReferralInviteePoints);
      await prefs.setBool(_kRewarded, true);
      final now = DateTime.now().millisecondsSinceEpoch;
      var synced = false;
      if (_allowed && docId.isNotEmpty) {
        synced = await OnlineCommon.write(() async {
          await _repo.setDoc('users', _me, {'referralRewarded': true});
          await _repo.setDoc('referrals', docId, <String, dynamic>{
            'status': 'rewarded',
            'rewardedAtMs': now,
          });
        });
      }
      if (!synced) {
        await OnlineCommon.enqueue(_kPendingReward, {
          'referralDocId': docId,
          'rewardedAtMs': now,
        });
      }
    } catch (_) {
      // Sin premio: se reintenta en el próximo Nivel 1 (el flag
      // local sigue en false).
    }
  }

  // ---- Cobro del invitador ----

  /// Cobra los referidos confirmados: por cada referido en estado
  /// 'rewarded' y sin cobrar, +50 puntos, +1 al conteo y hitos si
  /// tocan. Idempotente (inviterRewarded). Devuelve lo nuevo para
  /// celebrarlo en la pantalla. Nunca lanza.
  static Future<ClaimResult> claimInviterRewards() async {
    if (!_allowed) return const ClaimResult();
    try {
      final prefs = await _prefs;
      final rows = await OnlineCommon.call(() => _repo.queryDocs(
            'referrals',
            whereField: 'inviterUid',
            isEqualTo: _me,
          ));
      if (rows == null) return const ClaimResult();
      final pending = rows.where((r) =>
          r['status'] == 'rewarded' && r['inviterRewarded'] != true);
      if (pending.isEmpty) return const ClaimResult();
      var count = prefs.getInt(_kCount) ?? 0;
      final granted = prefs.getStringList(_kMilestones) ?? <String>[];
      final newReferrals = <String>[];
      final newMilestones = <int>[];
      String? lastInvitee;
      var claimedAny = false;
      for (final row in pending) {
        final docId = row['id']?.toString() ?? '';
        if (docId.isEmpty) continue;
        final name = row['inviteeUsername']?.toString() ?? '';
        // Primero se marca el cobro en la nube y DESPUÉS se paga
        // en local: si la escritura falla (sin internet), este
        // referido se cobra en la próxima apertura, no dos veces.
        final marked = await OnlineCommon.write(() => _repo.setDoc(
              'referrals',
              docId,
              {'inviterRewarded': true},
            ));
        if (!marked) continue;
        claimedAny = true;
        ProgressService.instance.addPoints(kReferralInviterPoints);
        count++;
        if (name.isNotEmpty) newReferrals.add(name);
        lastInvitee = name.isNotEmpty ? name : lastInvitee;
      }
      if (!claimedAny) return const ClaimResult();
      // Hitos que tocan con el conteo nuevo.
      for (final m in kReferralMilestones) {
        if (count >= m.count && !granted.contains('${m.count}')) {
          for (final item in m.rewards) {
            await SocialService.grantItem(item);
          }
          if (m.bonusPoints > 0) {
            ProgressService.instance.addPoints(m.bonusPoints);
          }
          granted.add('${m.count}');
          newMilestones.add(m.count);
        }
      }
      await prefs.setInt(_kCount, count);
      await prefs.setStringList(_kMilestones, granted);
      if (lastInvitee != null && lastInvitee.isNotEmpty) {
        await prefs.setString(_kLastInvitee, lastInvitee);
      }
      // Conteo, hitos y último invitado en el propio documento.
      await OnlineCommon.write(() => _repo.setDoc('users', _me, {
            'referralsCount': count,
            'referralMilestones': granted,
            if (lastInvitee != null && lastInvitee.isNotEmpty)
              'referralLastInvitee': lastInvitee,
          }));
      return ClaimResult(
        newReferrals: newReferrals,
        newMilestones: newMilestones,
      );
    } catch (_) {
      return const ClaimResult();
    }
  }

  // ---- Tabla de los que más invitan ----

  static Future<List<TopReferrer>> topReferrers({int limit = 20}) async {
    try {
      final rows = await OnlineCommon.call(() => _repo.queryDocs(
            'users',
            orderByField: 'referralsCount',
            descending: true,
            limit: limit,
          ));
      if (rows == null) return const [];
      final out = <TopReferrer>[];
      for (final row in rows) {
        final count = (row['referralsCount'] as num?)?.toInt() ?? 0;
        if (count <= 0) continue;
        out.add(TopReferrer(
          username: row['username']?.toString() ?? '',
          referralsCount: count,
          avatarId: row['equippedAvatar']?.toString(),
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  // ---- Estado para la pantalla ----

  /// Estado SOLO con lo guardado en el teléfono (Quemia 7.5): sin
  /// red, instantáneo. La pantalla lo enseña al abrir y luego lo
  /// refresca con [loadState]; así Invitar no se queda en el
  /// circulito esperando a la conexión lenta. La línea de "sin
  /// conexión" avisa de que son los datos guardados.
  static Future<ReferralState> localState() async {
    if (!OnlineCommon.allowed || _me.isEmpty) {
      return const ReferralState(needsGoogle: true);
    }
    final prefs = await _prefs;
    final lastInvitee = prefs.getString(_kLastInvitee);
    return ReferralState(
      code: prefs.getString(_kMyCode) ?? '',
      referralsCount: prefs.getInt(_kCount) ?? 0,
      milestonesGranted:
          (prefs.getStringList(_kMilestones) ?? <String>[])
              .map((g) => int.tryParse(g) ?? 0)
              .toList(),
      lastInvitee:
          lastInvitee != null && lastInvitee.isNotEmpty ? lastInvitee : null,
      offline: true,
    );
  }

  /// Carga todo lo que enseña Invitar: código, usos restantes,
  /// conteo, hitos, último invitado y la tabla. Aprovecha para
  /// cobrar los referidos confirmados. Sin Google devuelve el
  /// estado "necesita Google"; sin internet, los valores locales.
  /// Quemia 7.5: las llamadas van en PARALELO (Future.wait), no
  /// una detrás de otra — en serie, con la conexión lenta, la
  /// pantalla tardaba 30-60 s en abrir. El cobro se hace UNA sola
  /// vez aquí y su resultado viaja en el estado (la pantalla ya no
  /// lo llama aparte: el doble cobro en paralelo podía pagar dos
  /// veces el mismo referido).
  static Future<ReferralState> loadState() async {
    if (!OnlineCommon.allowed || _me.isEmpty) {
      return const ReferralState(needsGoogle: true);
    }
    var offline = false;
    try {
      // Lote 1 (independientes): reintentos, nombre y código.
      final first = await Future.wait([
        retryPending(),
        ensureUniqueUsername(),
        ensureMyCode(),
      ]);
      final code = first[2] as String;
      if (code.isEmpty) offline = true;
      // Lote 2 (independientes con el código ya en mano): cobrar,
      // documento propio, usos restantes y tabla.
      final second = await Future.wait([
        claimInviterRewards(),
        OnlineCommon.call(() => _repo.getDoc('users', _me)),
        code.isEmpty
            ? Future<List<Map<String, dynamic>>?>.value(null)
            : OnlineCommon.call(() => _repo.queryDocs(
                  'referrals',
                  whereField: 'code',
                  isEqualTo: code,
                )),
        topReferrers(),
      ]);
      final claim = second[0] as ClaimResult;
      final doc = second[1] as Map<String, dynamic>?;
      final used = second[2] as List<Map<String, dynamic>>?;
      final top = second[3] as List<TopReferrer>;
      final prefs = await _prefs;
      var count = prefs.getInt(_kCount) ?? 0;
      final granted = prefs.getStringList(_kMilestones) ?? <String>[];
      var lastInvitee = prefs.getString(_kLastInvitee);
      // El documento propio manda si trae más (cambio de teléfono:
      // las prefs locales están vacías pero la nube recuerda el
      // conteo, los hitos y el último invitado).
      if (doc != null) {
        final docCount = (doc['referralsCount'] as num?)?.toInt() ?? 0;
        if (docCount > count) count = docCount;
        final docMilestones = doc['referralMilestones'];
        if (docMilestones is List) {
          for (final m in docMilestones) {
            final s = m.toString();
            if (!granted.contains(s)) granted.add(s);
          }
        }
        final docLast = doc['referralLastInvitee']?.toString() ?? '';
        if ((lastInvitee == null || lastInvitee.isEmpty) &&
            docLast.isNotEmpty) {
          lastInvitee = docLast;
        }
        await prefs.setInt(_kCount, count);
        await prefs.setStringList(_kMilestones, granted);
        if (lastInvitee != null && lastInvitee.isNotEmpty) {
          await prefs.setString(_kLastInvitee, lastInvitee);
        }
      }
      var usesLeft = kReferralMaxUses;
      if (code.isNotEmpty) {
        if (used == null) {
          offline = true;
        } else {
          usesLeft =
              (kReferralMaxUses - used.length).clamp(0, kReferralMaxUses);
        }
      }
      return ReferralState(
        code: code,
        usesLeft: usesLeft,
        referralsCount: count,
        milestonesGranted:
            granted.map((g) => int.tryParse(g) ?? 0).toList(),
        lastInvitee:
            lastInvitee != null && lastInvitee.isNotEmpty ? lastInvitee : null,
        topReferrers: top,
        offline: offline,
        claim: claim,
      );
    } catch (_) {
      return const ReferralState(offline: true);
    }
  }

  // ---- Reintento ----

  /// Reintenta lo que quedó pendiente sin internet: el código en
  /// el documento propio, el canje y el premio del invitado.
  /// Lo llama Invitar al cargar y el canje tras escribir.
  static Future<void> retryPending() async {
    if (!_allowed) return;
    try {
      // Por índice de atrás hacia delante (patrón ShopService):
      // la lista se lee UNA vez y se borra por índice; buscar el
      // elemento con indexOf no funciona (los mapas se decodifican
      // de nuevo cada vez y no son el mismo objeto).
      final codes = await OnlineCommon.pending(_kPendingCode);
      for (var i = codes.length - 1; i >= 0; i--) {
        final item = codes[i];
        final code = item['code']?.toString() ?? '';
        final username = item['username']?.toString() ?? '';
        final ok = await OnlineCommon.write(() => _repo.setDoc(
              'users',
              _me,
              {
                if (code.isNotEmpty) 'referralCode': code,
                if (username.isNotEmpty) 'username': username,
              },
            ));
        if (ok) await OnlineCommon.removeAt(_kPendingCode, i);
      }
      final redeems = await OnlineCommon.pending(_kPendingRedeem);
      for (var i = redeems.length - 1; i >= 0; i--) {
        final item = redeems[i];
        final code = item['code']?.toString() ?? '';
        final inviterUid = item['inviterUid']?.toString() ?? '';
        if (code.isEmpty) {
          await OnlineCommon.removeAt(_kPendingRedeem, i);
          continue;
        }
        final ok = await OnlineCommon.write(() => _repo.setDoc(
              'users',
              _me,
              {
                'referredBy': code,
                'referredByUid': inviterUid,
                'referralRewarded': false,
              },
            ));
        if (ok) await OnlineCommon.removeAt(_kPendingRedeem, i);
      }
      final rewards = await OnlineCommon.pending(_kPendingReward);
      for (var i = rewards.length - 1; i >= 0; i--) {
        final item = rewards[i];
        final docId = item['referralDocId']?.toString() ?? '';
        final atMs = (item['rewardedAtMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch;
        final ok = await OnlineCommon.write(() async {
          await _repo.setDoc('users', _me, {'referralRewarded': true});
          if (docId.isNotEmpty) {
            await _repo.setDoc('referrals', docId, <String, dynamic>{
              'status': 'rewarded',
              'rewardedAtMs': atMs,
            });
          }
        });
        if (ok) await OnlineCommon.removeAt(_kPendingReward, i);
      }
    } catch (_) {
      // Se reintenta en la próxima apertura.
    }
  }

  /// Solo para tests: limpia el estado en memoria (las prefs las
  /// limpia el test con setMockInitialValues).
  @visibleForTesting
  static void resetForTests() {}
}
