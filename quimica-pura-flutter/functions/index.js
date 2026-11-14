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

/* ==========================================================================
 * OTP por correo (Quemia 7.7, Kristian)
 * --------------------------------------------------------------------------
 * Firebase Auth NO manda códigos de 6 dígitos (manda enlaces), así que
 * el registro con correo y la recuperación de contraseña usan estas tres
 * funciones HTTP (POST JSON, respuesta {ok: true/false}):
 *   - sendOtp: genera un código de 6 dígitos, lo guarda en
 *     `otp_codes/{correo}_{proposito}` (caduca en 10 min) y lo manda
 *     por correo con Nodemailer + SMTP de Gmail.
 *   - verifyOtp: comprueba el código (máx. 5 intentos; al acertar lo
 *     borra para que no se reutilice).
 *   - resetPasswordWithOtp: verifica el código y cambia la contraseña
 *     con el Admin SDK (la app no puede hacerlo sola: el usuario no
 *     ha iniciado sesión).
 *
 * Límites anti-spam: 60 s entre envíos al mismo correo, 5 intentos
 * por código, caducidad de 10 min.
 *
 * Configuración (secretos, NO en el código): SMTP_USER = cuenta de
 * Gmail que manda los correos; SMTP_PASS = contraseña de aplicación
 * de esa cuenta (Google > Seguridad > Contraseñas de aplicaciones).
 *   firebase functions:secrets:set SMTP_USER
 *   firebase functions:secrets:set SMTP_PASS
 *
 * Despliegue: necesita el plan Blaze (estas funciones son HTTP, no
 * triggers de Firestore). Sin desplegar, la app no puede mandar los
 * códigos y OtpService devuelve false.
 * ========================================================================== */

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getAuth } = require('firebase-admin/auth');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

const smtpUser = defineSecret('SMTP_USER');
const smtpPass = defineSecret('SMTP_PASS');
const auth = getAuth();

const OTP_TTL_MS = 10 * 60 * 1000; // 10 min
const OTP_RESEND_MS = 60 * 1000; // 60 s entre envíos
const OTP_MAX_ATTEMPTS = 5;
const OTP_PURPOSES = ['register', 'reset'];

function otpDocId(email, purpose) {
  return `${String(email).trim().toLowerCase()}_${purpose}`;
}

function otpCode() {
  return String(crypto.randomInt(100000, 1000000));
}

function validEmail(email) {
  return typeof email === 'string' &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

function mailer() {
  return nodemailer.createTransport({
    service: 'gmail',
    auth: { user: smtpUser.value(), pass: smtpPass.value() },
  });
}

function otpMail(email, code, purpose) {
  const para = purpose === 'reset'
    ? 'recuperar tu contraseña de Quemia'
    : 'confirmar tu correo en Quemia';
  return {
    from: `"Quemia" <${smtpUser.value()}>`,
    to: email,
    subject: `Tu código de Quemia: ${code}`,
    text: `Hola,\n\nTu código para ${para} es:\n\n${code}\n\nCaduca en 10 minutos. Si no fuiste tú quien lo pidió, ignora este correo.\n\nQuemia`,
    html: `<p>Hola,</p><p>Tu código para ${para} es:</p>` +
      `<p style="font-size:32px;font-weight:bold;letter-spacing:6px;">${code}</p>` +
      `<p>Caduca en 10 minutos. Si no fuiste tú quien lo pidió, ignora este correo.</p><p>Quemia</p>`,
  };
}

/** Lee el JSON del body (onRequest no lo parsea solo). */
function readJson(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  try {
    return JSON.parse(req.body || '{}');
  } catch (_) {
    return {};
  }
}

/** Genera el código, lo guarda y lo manda por correo. */
exports.sendOtp = onRequest(
  { secrets: [smtpUser, smtpPass] },
  async (req, res) => {
    try {
      if (req.method !== 'POST') return res.status(405).json({ ok: false });
      const { email, purpose } = readJson(req);
      if (!validEmail(email) || !OTP_PURPOSES.includes(purpose)) {
        return res.status(400).json({ ok: false });
      }
      const id = otpDocId(email, purpose);
      const ref = db.collection('otp_codes').doc(id);
      const snap = await ref.get();
      const now = Date.now();
      if (snap.exists) {
        const createdAt = snap.get('createdAtMs') || 0;
        if (now - createdAt < OTP_RESEND_MS) {
          return res.json({ ok: false, error: 'too_soon' });
        }
      }
      const code = otpCode();
      await ref.set({
        code,
        email: String(email).trim().toLowerCase(),
        purpose,
        createdAtMs: now,
        expiresAtMs: now + OTP_TTL_MS,
        attempts: 0,
      });
      await mailer().sendMail(otpMail(email, code, purpose));
      return res.json({ ok: true });
    } catch (error) {
      logger.error('sendOtp falló', error);
      return res.status(500).json({ ok: false });
    }
  },
);

/** Comprueba el código (lo borra al acertar). */
exports.verifyOtp = onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') return res.status(405).json({ ok: false });
    const { email, code, purpose } = readJson(req);
    if (!validEmail(email) || !OTP_PURPOSES.includes(purpose) ||
        typeof code !== 'string') {
      return res.status(400).json({ ok: false });
    }
    const ref = db.collection('otp_codes').doc(otpDocId(email, purpose));
    const snap = await ref.get();
    if (!snap.exists) return res.json({ ok: false });
    const data = snap.data();
    if (Date.now() > (data.expiresAtMs || 0)) {
      await ref.delete();
      return res.json({ ok: false, error: 'expired' });
    }
    if ((data.attempts || 0) >= OTP_MAX_ATTEMPTS) {
      await ref.delete();
      return res.json({ ok: false, error: 'too_many_attempts' });
    }
    if (String(data.code) !== code.trim()) {
      await ref.update({ attempts: (data.attempts || 0) + 1 });
      return res.json({ ok: false });
    }
    await ref.delete();
    return res.json({ ok: true });
  } catch (error) {
    logger.error('verifyOtp falló', error);
    return res.status(500).json({ ok: false });
  }
});

/** Verifica el código y cambia la contraseña (Admin SDK). */
exports.resetPasswordWithOtp = onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') return res.status(405).json({ ok: false });
    const { email, code, newPassword } = readJson(req);
    if (!validEmail(email) || typeof code !== 'string' ||
        typeof newPassword !== 'string' || newPassword.length < 6) {
      return res.status(400).json({ ok: false });
    }
    const ref = db.collection('otp_codes').doc(otpDocId(email, 'reset'));
    const snap = await ref.get();
    if (!snap.exists) return res.json({ ok: false });
    const data = snap.data();
    if (Date.now() > (data.expiresAtMs || 0)) {
      await ref.delete();
      return res.json({ ok: false, error: 'expired' });
    }
    if ((data.attempts || 0) >= OTP_MAX_ATTEMPTS) {
      await ref.delete();
      return res.json({ ok: false, error: 'too_many_attempts' });
    }
    if (String(data.code) !== code.trim()) {
      await ref.update({ attempts: (data.attempts || 0) + 1 });
      return res.json({ ok: false });
    }
    await ref.delete();
    const user = await auth.getUserByEmail(email.trim().toLowerCase());
    await auth.updateUser(user.uid, { password: newPassword });
    return res.json({ ok: true });
  } catch (error) {
    logger.error('resetPasswordWithOtp falló', error);
    return res.status(500).json({ ok: false });
  }
});
