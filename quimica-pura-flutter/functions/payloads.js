// Constructores puros de las notificaciones push de Quemia.
//
// Este módulo NO toca Firebase: solo recibe los campos de un documento
// de Firestore y devuelve el payload FCM (notification + data) o null
// cuando no hay que avisar. Por eso se puede probar sin emulador ni
// credenciales: ver test/payloads.test.js.
//
// Tono: español llano, una línea, sin emojis (igual que los avisos
// que la app ya escribe en su bandeja local). Todos los valores del
// `data` son strings: FCM no acepta otros tipos.

'use strict';

const MAX_BODY_CHARS = 200;

/** Nombre visible o un genérico cuando el documento no trae nombre. */
function cleanName(value, fallback) {
  const name = typeof value === 'string' ? value.trim() : '';
  return name === '' ? fallback : name;
}

/** Recorta un texto a N caracteres sin romper a mitad de palabra brusca. */
function trunc(text, max = MAX_BODY_CHARS) {
  const clean = typeof text === 'string' ? text.trim() : '';
  if (clean.length <= max) return clean;
  return clean.slice(0, max - 1).trimEnd() + '…';
}

function hasReply(doc) {
  return typeof doc.reply === 'string' && doc.reply.trim() !== '';
}

// ---------------------------------------------------------------------------
// Amistad (colección friend_requests)
// Campos: senderUid, senderUsername, receiverUid, receiverUsername,
// status ('pendiente' | 'aceptada' | 'rechazada'), createdAtMs.
// ---------------------------------------------------------------------------

/**
 * onCreate de friend_requests: avisa al receptor. Solo si sigue
 * 'pendiente' (defensa por si alguien crea el doc ya resuelto).
 * Devuelve { toUid, notification, data } o null.
 */
function friendRequestCreated(doc, requestId) {
  if (!doc || doc.status !== 'pendiente') return null;
  const sender = cleanName(doc.senderUsername, 'Alguien');
  return {
    toUid: doc.receiverUid || '',
    notification: {
      title: `${sender} te envió una solicitud de amistad`,
      body: 'Toca para verla y aceptar o rechazar.',
    },
    data: {
      type: 'friend_request',
      requestId: String(requestId || ''),
      senderUid: String(doc.senderUid || ''),
    },
  };
}

/**
 * onUpdate de friend_requests: avisa al que envió la solicitud cuando
 * el receptor la acepta o rechaza. Solo vale pendiente -> aceptada /
 * rechazada: una aceptada que pasa a rechazada es quitar un amigo,
 * no una respuesta, y no avisa.
 * Devuelve { toUid, notification, data } o null.
 */
function friendRequestResult(before, after, requestId) {
  if (!before || !after) return null;
  if (before.status !== 'pendiente') return null;
  if (after.status !== 'aceptada' && after.status !== 'rechazada') {
    return null;
  }
  const receiver = cleanName(after.receiverUsername, 'Tu amigo');
  const accepted = after.status === 'aceptada';
  return {
    toUid: after.senderUid || '',
    notification: {
      title: accepted
        ? `${receiver} aceptó tu solicitud de amistad`
        : `${receiver} rechazó tu solicitud de amistad`,
      body: accepted
        ? 'Ya son amigos en Quemia.'
        : 'Puedes seguir jugando y sumando puntos.',
    },
    data: {
      type: 'friend_request_result',
      requestId: String(requestId || ''),
      status: String(after.status),
    },
  };
}

// ---------------------------------------------------------------------------
// Duelos (colección duels)
// Campos: playerA (creador), playerB (retado), playerAName,
// playerBName, questionIds, seed, status ('waiting' | 'playing' |
// 'finished' | 'cancelled'), createdAtMs, results, winnerUid
// (null si empate), forfeit.
// ---------------------------------------------------------------------------

/**
 * onCreate de duels: avisa al retado (playerB, el que no creó el duelo).
 * Devuelve { toUid, notification, data } o null.
 */
function duelChallenge(doc, duelId) {
  if (!doc) return null;
  const challenged = doc.playerB || '';
  if (challenged === '') return null;
  const creator = cleanName(doc.playerAName, 'Un amigo');
  return {
    toUid: challenged,
    notification: {
      title: '¡Te retaron a un duelo!',
      body: `${creator} te retó a un duelo en Quemia.`,
    },
    data: {
      type: 'duel_challenge',
      duelId: String(duelId || ''),
    },
  };
}

/**
 * onUpdate de duels: cuando el duelo pasa a 'finished', avisa a los
 * DOS jugadores con su resultado. winnerUid null = empate.
 * Devuelve un array (0, 1 o 2 entradas { toUid, notification, data }).
 */
function duelResult(before, after, duelId) {
  if (!before || !after) return [];
  if (before.status === 'finished' || after.status !== 'finished') {
    return [];
  }
  const a = after.playerA || '';
  const b = after.playerB || '';
  const aName = cleanName(after.playerAName, 'Tu rival');
  const bName = cleanName(after.playerBName, 'Tu rival');
  const winner = after.winnerUid || '';
  const data = { type: 'duel_result', duelId: String(duelId || '') };

  if (winner === '') {
    // Empate: el mismo mensaje para los dos.
    const tied = (uid) => ({
      toUid: uid,
      notification: {
        title: 'El duelo terminó en empate',
        body: 'Nadie se llevó la victoria esta vez.',
      },
      data: { ...data },
    });
    return [a, b].filter((uid) => uid !== '').map(tied);
  }

  const loser = winner === a ? b : a;
  const winnerName = winner === a ? aName : bName;
  const loserName = winner === a ? bName : aName;
  const out = [];
  if (winner !== '') {
    out.push({
      toUid: winner,
      notification: {
        title: '¡Ganaste el duelo!',
        body: `Ganaste el duelo contra ${loserName}.`,
      },
      data: { ...data },
    });
  }
  if (loser !== '') {
    out.push({
      toUid: loser,
      notification: {
        title: 'Perdiste el duelo',
        body: `Perdiste el duelo contra ${winnerName}.`,
      },
      data: { ...data },
    });
  }
  return out;
}

// ---------------------------------------------------------------------------
// Soporte (colección support_messages)
// Campos: authorUid, username, message, createdAt (Timestamp),
// status ('abierto' | 'respondido'), reply (null hasta la respuesta),
// replyAt (Timestamp, null hasta la respuesta).
// ---------------------------------------------------------------------------

/**
 * onUpdate de support_messages: avisa al autor cuando el admin
 * responde (reply pasa de vacío a texto). El cuerpo ES la respuesta,
 * igual que hace la bandeja local de la app.
 * Devuelve { toUid, notification, data } o null.
 */
function supportReply(before, after, messageId) {
  if (!before || !after) return null;
  if (hasReply(before)) return null; // Ya tenía respuesta: no repetir.
  if (!hasReply(after)) return null;
  return {
    toUid: after.authorUid || '',
    notification: {
      title: 'Soporte te respondió',
      body: trunc(after.reply),
    },
    data: {
      type: 'support_reply',
      messageId: String(messageId || ''),
    },
  };
}

// ---------------------------------------------------------------------------
// Avisos del admin (colección announcements)
// Campos: title, body, createdAtMs, active (si falta, se considera activo),
// sendPush (solo true manda push; ausente o false = solo en bandeja).
// ---------------------------------------------------------------------------

/**
 * onCreate de announcements: el aviso va a TODOS los usuarios con
 * token, pero SOLO si el documento trae `sendPush: true`. Sin sendPush
 * (o con sendPush false) el aviso queda solo en la bandeja de la app
 * y no se manda push. Devuelve { notification, data } o null si está
 * inactivo, si no pide push o si no tiene título ni cuerpo.
 */
function announcementCreated(doc, announcementId) {
  if (!doc) return null;
  if (doc.active === false) return null;
  if (doc.sendPush !== true) return null;
  const title = typeof doc.title === 'string' ? doc.title.trim() : '';
  const body = typeof doc.body === 'string' ? doc.body.trim() : '';
  if (title === '' && body === '') return null;
  return {
    notification: {
      title: title === '' ? 'Nuevo aviso de Quemia' : title,
      body: body === '' ? 'Abre la app para leerlo.' : trunc(body),
    },
    data: {
      type: 'announcement',
      announcementId: String(announcementId || ''),
    },
  };
}

// ---------------------------------------------------------------------------
// Avisos al admin (colecciones users, reports, support_messages)
// Los admins viven en la colección 'admins', documento id = uid.
// ---------------------------------------------------------------------------

/**
 * onCreate de users: avisa a los admins. El `data` lleva el uid del
 * usuario nuevo (documento id = uid de Firebase Auth).
 */
function adminNewUser(doc, uid) {
  const username = cleanName(doc && doc.username, 'Sin nombre');
  return {
    notification: {
      title: `Nuevo usuario: ${username}`,
      body: 'Se unió a Quemia.',
    },
    data: { type: 'admin_new_user', uid: String(uid || '') },
  };
}

/**
 * onCreate de reports: avisa a los admins.
 * Campos del reporte: questionId, note, uid, username, createdAtMs.
 */
function adminNewReport(doc, reportId) {
  const username = cleanName(doc && doc.username, 'Un usuario');
  const questionId =
    doc && typeof doc.questionId === 'string' && doc.questionId !== ''
      ? doc.questionId
      : 'pregunta sin id';
  return {
    notification: {
      title: 'Nueva pregunta reportada',
      body: `${username} reportó la pregunta ${questionId}.`,
    },
    data: { type: 'admin_new_report', reportId: String(reportId || '') },
  };
}

/**
 * onCreate de support_messages: avisa a los admins. El cuerpo lleva el
 * principio del mensaje del usuario (recortado).
 */
function adminNewSupport(doc, messageId) {
  const username = cleanName(doc && doc.username, 'Un usuario');
  const message = trunc(doc && doc.message ? doc.message : '', 120);
  return {
    notification: {
      title: 'Nuevo mensaje de soporte',
      body: message === '' ? `${username} te escribió.` : `${username}: ${message}`,
    },
    data: { type: 'admin_new_support', messageId: String(messageId || '') },
  };
}

module.exports = {
  cleanName,
  trunc,
  hasReply,
  friendRequestCreated,
  friendRequestResult,
  duelChallenge,
  duelResult,
  supportReply,
  announcementCreated,
  adminNewUser,
  adminNewReport,
  adminNewSupport,
};
