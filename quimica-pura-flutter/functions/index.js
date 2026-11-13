// Cloud Functions de Quemia (2nd gen, firebase-functions v2).
//
// Qué hace: escucha escrituras en Firestore y manda notificaciones
// push con FCM (Admin SDK). La app NO se suscribe a topics: todo es
// por token, que cada app guarda en su documento:
//   - usuario: users/{uid}  -> fcmToken, fcmTokenUpdatedAt (ms)
//   - admin:   admins/{uid} -> fcmToken, fcmTokenUpdatedAt (ms)
// Sin token no hay push: se salta en silencio, nunca se rompe nada.
//
// Reglas de todos los triggers:
//   - Cada envío va en try/catch: un fallo de FCM nunca hace fallar
//     el trigger ni reintenta en bucle.
//   - Un token inválido (app desinstalada) se borra del documento
//     para no volver a intentarlo; cualquier otro error solo se loguea.
//   - Los envíos masivos (avisos a todos, avisos a admins) van en
//     tandas de 500 (límite de sendEach) y solo leen el campo
//     fcmToken (select), no el documento entero.
//
// Contratos con las apps (el `data` que la app usa para abrir la
// pantalla correcta): ver payloads.js y README.md.

'use strict';

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');

const {
  friendRequestCreated,
  friendRequestResult,
  duelChallenge,
  duelResult,
  supportReply,
  announcementCreated,
  adminNewUser,
  adminNewReport,
  adminNewSupport,
} = require('./payloads');

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

const MULTICAST_CHUNK = 500;
const FCM_TOKEN_FIELD = 'fcmToken';

// ---------------------------------------------------------------------------
// Ayudas de envío
// ---------------------------------------------------------------------------

/** Token FCM de un documento de usuario/admin, o null si no tiene. */
async function tokenOf(collection, uid) {
  try {
    if (!uid) return null;
    const snap = await db.collection(collection).doc(uid).get();
    if (!snap.exists) return null;
    const token = snap.get(FCM_TOKEN_FIELD);
    return typeof token === 'string' && token.trim() !== '' ? token : null;
  } catch (error) {
    logger.error(`tokenOf ${collection}/${uid} falló`, error);
    return null;
  }
}

/** Borra un token que FCM dice que ya no existe (app desinstalada). */
async function dropStaleToken(collection, uid) {
  try {
    await db
      .collection(collection)
      .doc(uid)
      .update({ [FCM_TOKEN_FIELD]: null, fcmTokenUpdatedAt: null });
  } catch (error) {
    logger.warn(`No se pudo limpiar el token viejo de ${collection}/${uid}`, error);
  }
}

function isTokenGone(error) {
  const code = (error && error.code) || '';
  return (
    code === 'messaging/invalid-registration-token' ||
    code === 'messaging/registration-token-not-registered'
  );
}

/**
 * Envía un payload a UN usuario/admin por su uid. Sin token: silencio.
 * Devuelve true si FCM lo aceptó, false en cualquier otro caso.
 */
async function sendToUid(collection, uid, payload, context) {
  if (!payload || !payload.toUid) return false;
  const token = await tokenOf(collection, uid);
  if (!token) {
    logger.info(`Sin token FCM en ${collection}/${uid}, se salta (${context}).`);
    return false;
  }
  try {
    await messaging.send({
      token,
      notification: payload.notification,
      data: payload.data,
    });
    logger.info(`Push enviado a ${collection}/${uid} (${context}).`);
    return true;
  } catch (error) {
    logger.error(`Push a ${collection}/${uid} falló (${context})`, error);
    if (isTokenGone(error)) await dropStaleToken(collection, uid);
    return false;
  }
}

/** Todos los tokens FCM no vacíos de una colección (solo lee fcmToken). */
async function tokensOf(collection) {
  try {
    const snap = await db.collection(collection).select(FCM_TOKEN_FIELD).get();
    const tokens = [];
    snap.forEach((doc) => {
      const token = doc.get(FCM_TOKEN_FIELD);
      if (typeof token === 'string' && token.trim() !== '') tokens.push(token);
    });
    return tokens;
  } catch (error) {
    logger.error(`tokensOf ${collection} falló`, error);
    return [];
  }
}

/**
 * Envía un payload a una lista de tokens en tandas de 500.
 * Devuelve cuántos se aceptaron.
 */
async function sendToTokens(tokens, payload, context) {
  let sent = 0;
  for (let i = 0; i < tokens.length; i += MULTICAST_CHUNK) {
    const chunk = tokens.slice(i, i + MULTICAST_CHUNK);
    try {
      const res = await messaging.sendEach(
        chunk.map((token) => ({
          token,
          notification: payload.notification,
          data: payload.data,
        })),
      );
      sent += res.successCount;
      if (res.failureCount > 0) {
        logger.warn(
          `${context}: ${res.failureCount} de ${chunk.length} fallaron en esta tanda.`,
        );
        res.responses.forEach((r, index) => {
          if (!r.success && isTokenGone(r.error)) {
            logger.info(`${context}: token inválido, se ignora (${chunk[index].slice(0, 12)}…).`);
          }
        });
      }
    } catch (error) {
      logger.error(`${context}: la tanda de ${chunk.length} falló entera`, error);
    }
  }
  logger.info(`${context}: ${sent}/${tokens.length} pushes aceptados.`);
  return sent;
}

/** Envía a todos los admins (tokens de la colección 'admins'). */
async function sendToAllAdmins(payload, context) {
  const tokens = await tokensOf('admins');
  if (tokens.length === 0) {
    logger.info(`Sin admins con token FCM (${context}), no se avisa a nadie.`);
    return 0;
  }
  return sendToTokens(tokens, payload, context);
}

// ---------------------------------------------------------------------------
// MAIN APP: avisar al usuario
// ---------------------------------------------------------------------------

/** friend_requests onCreate (pendiente) -> receptor. */
exports.onFriendRequestCreated = onDocumentCreated(
  'friend_requests/{requestId}',
  async (event) => {
    try {
      const after = event.data ? event.data.data() : null;
      const payload = friendRequestCreated(after, event.params.requestId);
      if (!payload) return;
      await sendToUid('users', payload.toUid, payload, 'friend_request_created');
    } catch (error) {
      logger.error('onFriendRequestCreated falló', error);
    }
  },
);

/** friend_requests onUpdate pendiente -> aceptada/rechazada -> remitente. */
exports.onFriendRequestUpdated = onDocumentUpdated(
  'friend_requests/{requestId}',
  async (event) => {
    try {
      const before = event.data ? event.data.before.data() : null;
      const after = event.data ? event.data.after.data() : null;
      const payload = friendRequestResult(before, after, event.params.requestId);
      if (!payload) return;
      await sendToUid('users', payload.toUid, payload, 'friend_request_result');
    } catch (error) {
      logger.error('onFriendRequestUpdated falló', error);
    }
  },
);

/** duels onCreate -> retado (playerB, el que no creó el duelo). */
exports.onDuelCreated = onDocumentCreated('duels/{duelId}', async (event) => {
  try {
    const after = event.data ? event.data.data() : null;
    const payload = duelChallenge(after, event.params.duelId);
    if (!payload) return;
    await sendToUid('users', payload.toUid, payload, 'duel_challenge');
  } catch (error) {
    logger.error('onDuelCreated falló', error);
  }
});

/** duels onUpdate -> 'finished': resultado a los DOS jugadores. */
exports.onDuelFinished = onDocumentUpdated('duels/{duelId}', async (event) => {
  try {
    const before = event.data ? event.data.before.data() : null;
    const after = event.data ? event.data.after.data() : null;
    const payloads = duelResult(before, after, event.params.duelId);
    for (const payload of payloads) {
      await sendToUid('users', payload.toUid, payload, 'duel_result');
    }
  } catch (error) {
    logger.error('onDuelFinished falló', error);
  }
});

/**
 * support_messages onUpdate: el admin respondió (reply pasa de vacío
 * a texto) -> autor del mensaje.
 */
exports.onSupportReplied = onDocumentUpdated(
  'support_messages/{messageId}',
  async (event) => {
    try {
      const before = event.data ? event.data.before.data() : null;
      const after = event.data ? event.data.after.data() : null;
      const payload = supportReply(before, after, event.params.messageId);
      if (!payload) return;
      await sendToUid('users', payload.toUid, payload, 'support_reply');
    } catch (error) {
      logger.error('onSupportReplied falló', error);
    }
  },
);

/** announcements onCreate -> TODOS los usuarios con token. */
exports.onAnnouncementCreated = onDocumentCreated(
  'announcements/{announcementId}',
  async (event) => {
    try {
      const after = event.data ? event.data.data() : null;
      const payload = announcementCreated(after, event.params.announcementId);
      if (!payload) return;
      const tokens = await tokensOf('users');
      if (tokens.length === 0) {
        logger.info('Sin usuarios con token FCM (announcement), no se avisa a nadie.');
        return;
      }
      await sendToTokens(tokens, payload, 'announcement');
    } catch (error) {
      logger.error('onAnnouncementCreated falló', error);
    }
  },
);

// ---------------------------------------------------------------------------
// ADMIN: avisar a los administradores
// ---------------------------------------------------------------------------

/** users onCreate -> todos los admins. */
exports.onUserCreatedNotifyAdmins = onDocumentCreated(
  'users/{uid}',
  async (event) => {
    try {
      const after = event.data ? event.data.data() : null;
      const payload = adminNewUser(after, event.params.uid);
      await sendToAllAdmins(payload, 'admin_new_user');
    } catch (error) {
      logger.error('onUserCreatedNotifyAdmins falló', error);
    }
  },
);

/** reports onCreate -> todos los admins. */
exports.onReportCreatedNotifyAdmins = onDocumentCreated(
  'reports/{reportId}',
  async (event) => {
    try {
      const after = event.data ? event.data.data() : null;
      const payload = adminNewReport(after, event.params.reportId);
      await sendToAllAdmins(payload, 'admin_new_report');
    } catch (error) {
      logger.error('onReportCreatedNotifyAdmins falló', error);
    }
  },
);

/** support_messages onCreate -> todos los admins. */
exports.onSupportCreatedNotifyAdmins = onDocumentCreated(
  'support_messages/{messageId}',
  async (event) => {
    try {
      const after = event.data ? event.data.data() : null;
      const payload = adminNewSupport(after, event.params.messageId);
      await sendToAllAdmins(payload, 'admin_new_support');
    } catch (error) {
      logger.error('onSupportCreatedNotifyAdmins falló', error);
    }
  },
);
