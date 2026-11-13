// Tests de la lógica pura de payloads.js (sin Firebase ni red).
// Se corre con: npm test   (o: node --test test/payloads.test.js)

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

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
  trunc,
} = require('../payloads');

// --- Amistad ---------------------------------------------------------------

test('friendRequestCreated: avisa al receptor con el nombre del remitente', () => {
  const p = friendRequestCreated(
    {
      senderUid: 'u1',
      senderUsername: 'Ana',
      receiverUid: 'u2',
      receiverUsername: 'Luis',
      status: 'pendiente',
    },
    'req1',
  );
  assert.equal(p.toUid, 'u2');
  assert.equal(p.notification.title, 'Ana te envió una solicitud de amistad');
  assert.deepEqual(p.data, { type: 'friend_request', requestId: 'req1', senderUid: 'u1' });
});

test('friendRequestCreated: no avisa si el doc ya no está pendiente', () => {
  assert.equal(
    friendRequestCreated({ status: 'aceptada', receiverUid: 'u2' }, 'req1'),
    null,
  );
});

test('friendRequestCreated: nombre vacío usa el genérico', () => {
  const p = friendRequestCreated(
    { senderUid: 'u1', senderUsername: '  ', receiverUid: 'u2', status: 'pendiente' },
    'req1',
  );
  assert.equal(p.notification.title, 'Alguien te envió una solicitud de amistad');
});

test('friendRequestResult: aceptada avisa al remitente', () => {
  const p = friendRequestResult(
    { status: 'pendiente', senderUid: 'u1' },
    { status: 'aceptada', senderUid: 'u1', receiverUsername: 'Luis' },
    'req1',
  );
  assert.equal(p.toUid, 'u1');
  assert.equal(p.notification.title, 'Luis aceptó tu solicitud de amistad');
  assert.equal(p.data.type, 'friend_request_result');
  assert.equal(p.data.status, 'aceptada');
});

test('friendRequestResult: rechazada avisa al remitente', () => {
  const p = friendRequestResult(
    { status: 'pendiente', senderUid: 'u1' },
    { status: 'rechazada', senderUid: 'u1', receiverUsername: 'Luis' },
    'req1',
  );
  assert.equal(p.notification.title, 'Luis rechazó tu solicitud de amistad');
  assert.equal(p.data.status, 'rechazada');
});

test('friendRequestResult: aceptada -> rechazada (quitar amigo) NO avisa', () => {
  assert.equal(
    friendRequestResult(
      { status: 'aceptada', senderUid: 'u1' },
      { status: 'rechazada', senderUid: 'u1', receiverUsername: 'Luis' },
      'req1',
    ),
    null,
  );
});

// --- Duelos ----------------------------------------------------------------

test('duelChallenge: avisa al retado (playerB), no al creador', () => {
  const p = duelChallenge(
    { playerA: 'u1', playerB: 'u2', playerAName: 'Ana', playerBName: 'Luis', status: 'waiting' },
    'd1',
  );
  assert.equal(p.toUid, 'u2');
  assert.equal(p.notification.title, '¡Te retaron a un duelo!');
  assert.equal(p.notification.body, 'Ana te retó a un duelo en Quemia.');
  assert.deepEqual(p.data, { type: 'duel_challenge', duelId: 'd1' });
});

test('duelChallenge: sin playerB no hay a quién avisar', () => {
  assert.equal(duelChallenge({ playerA: 'u1', playerAName: 'Ana' }, 'd1'), null);
});

test('duelResult: ganador y perdedor reciben su mensaje', () => {
  const out = duelResult(
    { status: 'playing', playerA: 'u1', playerB: 'u2' },
    {
      status: 'finished',
      playerA: 'u1',
      playerB: 'u2',
      playerAName: 'Ana',
      playerBName: 'Luis',
      winnerUid: 'u1',
    },
    'd1',
  );
  assert.equal(out.length, 2);
  const byUid = Object.fromEntries(out.map((p) => [p.toUid, p]));
  assert.equal(byUid.u1.notification.title, '¡Ganaste el duelo!');
  assert.equal(byUid.u1.notification.body, 'Ganaste el duelo contra Luis.');
  assert.equal(byUid.u2.notification.title, 'Perdiste el duelo');
  assert.equal(byUid.u2.notification.body, 'Perdiste el duelo contra Ana.');
  assert.equal(byUid.u1.data.type, 'duel_result');
});

test('duelResult: empate (winnerUid null) avisa igual a los dos', () => {
  const out = duelResult(
    { status: 'playing', playerA: 'u1', playerB: 'u2' },
    {
      status: 'finished',
      playerA: 'u1',
      playerB: 'u2',
      playerAName: 'Ana',
      playerBName: 'Luis',
      winnerUid: null,
    },
    'd1',
  );
  assert.equal(out.length, 2);
  assert.ok(out.every((p) => p.notification.title === 'El duelo terminó en empate'));
});

test('duelResult: si no pasó a finished, no avisa', () => {
  assert.deepEqual(
    duelResult(
      { status: 'waiting', playerA: 'u1', playerB: 'u2' },
      { status: 'playing', playerA: 'u1', playerB: 'u2', winnerUid: null },
      'd1',
    ),
    [],
  );
  // Un update posterior de un duelo ya terminado tampoco re-avisa.
  assert.deepEqual(
    duelResult(
      { status: 'finished', playerA: 'u1', playerB: 'u2', winnerUid: 'u1' },
      { status: 'finished', playerA: 'u1', playerB: 'u2', winnerUid: 'u1' },
      'd1',
    ),
    [],
  );
});

// --- Soporte ---------------------------------------------------------------

test('supportReply: avisa al autor y el cuerpo es la respuesta', () => {
  const p = supportReply(
    { authorUid: 'u1', reply: null, status: 'abierto' },
    { authorUid: 'u1', reply: 'Ya lo revisamos, prueba de nuevo.', status: 'respondido' },
    'm1',
  );
  assert.equal(p.toUid, 'u1');
  assert.equal(p.notification.title, 'Soporte te respondió');
  assert.equal(p.notification.body, 'Ya lo revisamos, prueba de nuevo.');
  assert.deepEqual(p.data, { type: 'support_reply', messageId: 'm1' });
});

test('supportReply: no avisa si ya tenía respuesta (no repetir)', () => {
  assert.equal(
    supportReply(
      { authorUid: 'u1', reply: 'Primera respuesta' },
      { authorUid: 'u1', reply: 'Respuesta editada' },
      'm1',
    ),
    null,
  );
});

test('supportReply: no avisa si sigue sin respuesta', () => {
  assert.equal(
    supportReply(
      { authorUid: 'u1', reply: null },
      { authorUid: 'u1', reply: null, status: 'abierto' },
      'm1',
    ),
    null,
  );
});

test('trunc: recorta respuestas largas', () => {
  assert.ok(trunc('x'.repeat(500)).length <= 201);
  assert.equal(trunc('corto'), 'corto');
});

// --- Avisos ----------------------------------------------------------------

test('announcementCreated: usa título y cuerpo del documento', () => {
  const p = announcementCreated(
    { title: 'Torneo el viernes', body: 'Apúntate antes del jueves.', active: true },
    'a1',
  );
  assert.equal(p.notification.title, 'Torneo el viernes');
  assert.equal(p.notification.body, 'Apúntate antes del jueves.');
  assert.deepEqual(p.data, { type: 'announcement', announcementId: 'a1' });
});

test('announcementCreated: inactivo no avisa; sin active se considera activo', () => {
  assert.equal(
    announcementCreated({ title: 'X', body: 'Y', active: false }, 'a1'),
    null,
  );
  assert.notEqual(announcementCreated({ title: 'X', body: 'Y' }, 'a1'), null);
});

// --- Admin -----------------------------------------------------------------

test('adminNewUser: título con el nombre del usuario nuevo', () => {
  const p = adminNewUser({ username: 'María' }, 'u9');
  assert.equal(p.notification.title, 'Nuevo usuario: María');
  assert.deepEqual(p.data, { type: 'admin_new_user', uid: 'u9' });
});

test('adminNewReport: incluye quién reportó y qué pregunta', () => {
  const p = adminNewReport({ username: 'Luis', questionId: 'q-123', note: 'mal' }, 'r1');
  assert.equal(p.notification.title, 'Nueva pregunta reportada');
  assert.match(p.notification.body, /Luis/);
  assert.match(p.notification.body, /q-123/);
  assert.deepEqual(p.data, { type: 'admin_new_report', reportId: 'r1' });
});

test('adminNewSupport: el cuerpo lleva el principio del mensaje', () => {
  const p = adminNewSupport({ username: 'Ana', message: 'No me deja entrar al duelo' }, 'm1');
  assert.equal(p.notification.title, 'Nuevo mensaje de soporte');
  assert.match(p.notification.body, /Ana: No me deja entrar al duelo/);
  assert.deepEqual(p.data, { type: 'admin_new_support', messageId: 'm1' });
});

// --- Regla común -----------------------------------------------------------

test('todos los data llevan solo strings (FCM lo exige)', () => {
  const payloads = [
    friendRequestCreated({ senderUid: 'u1', senderUsername: 'A', receiverUid: 'u2', status: 'pendiente' }, 'r'),
    friendRequestResult({ status: 'pendiente' }, { status: 'aceptada', senderUid: 'u1', receiverUsername: 'L' }, 'r'),
    duelChallenge({ playerA: 'u1', playerB: 'u2', playerAName: 'A' }, 'd'),
    ...duelResult({ status: 'playing' }, { status: 'finished', playerA: 'u1', playerB: 'u2', playerAName: 'A', playerBName: 'L', winnerUid: 'u1' }, 'd'),
    supportReply({ reply: null }, { authorUid: 'u1', reply: 'ok' }, 'm'),
    announcementCreated({ title: 'T', body: 'B' }, 'a'),
    adminNewUser({ username: 'M' }, 'u'),
    adminNewReport({ username: 'L', questionId: 'q' }, 'r'),
    adminNewSupport({ username: 'A', message: 'hola' }, 'm'),
  ];
  for (const p of payloads) {
    assert.ok(p, 'payload no debe ser null');
    for (const value of Object.values(p.data)) {
      assert.equal(typeof value, 'string', `data no-string en ${JSON.stringify(p.data)}`);
    }
  }
});
