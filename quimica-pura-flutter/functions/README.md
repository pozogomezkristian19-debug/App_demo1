# Cloud Functions de Quemia — notificaciones push (FCM)

Funciones 2nd gen (firebase-functions v2) que escuchan Firestore y mandan
push con el Admin SDK. **NO desplegado todavía**: ver "Desplegar" abajo.

## ⚠️ Decisión pendiente: el plan Spark NO sirve para Cloud Functions

Verificado el 2026-11-12 en la página oficial de precios de Firebase
(https://firebase.google.com/pricing): en la tabla de **Cloud Functions**,
la columna del plan **Spark dice "Not applicable"** en todas las filas
(invocaciones, GB-segundos, CPU, red saliente, Cloud Build); las cuotas
gratuitas solo aparecen en la columna **Blaze**. Es decir: **con el plan
Spark (gratis) actual de quemia-8410a, `firebase deploy --only functions`
va a fallar**.

Para desplegar hay que pasar el proyecto a **Blaze (pago por uso)** en
Firebase console → Configuración del proyecto → Facturación. Blaze exige
una tarjeta, **pero** incluye una cuota gratuita mensual que cubre de sobra
el volumen de Quemia:

| Recurso | Gratis en Blaze al mes |
|---|---|
| Invocaciones | 2.000.000 |
| GB-segundos de cómputo | 400.000 |
| CPU-segundos | 200.000 |
| Red saliente | 5 GB |

Con el uso esperado (unos cientos de notificaciones al día) el coste real
será **0 $/mes**. Aun así, el cambio a Blaze es una decisión del usuario:
sin tarjeta no hay despliegue, y sin despliegue no hay push (los avisos
siguen llegando solo a la bandeja local al abrir la app, como hoy).

Se usó la **API v2** (2nd gen, la recomendada por Firebase para funciones
nuevas) porque la v1 tampoco evita el requisito de Blaze según la página
oficial de precios: no hay ventaja de plan en usar la API vieja. Los
constructores de payload (`payloads.js`) no dependen de la versión de la
API: si algún día se prefiere v1, solo cambian los envoltorios de
`index.js`.

## Qué hace cada trigger

| Función | Disparador Firestore | A quién avisa | Notificación |
|---|---|---|---|
| `onFriendRequestCreated` | `friend_requests/{requestId}` onCreate, status `pendiente` | `receiverUid` | "{senderUsername} te envió una solicitud de amistad" |
| `onFriendRequestUpdated` | `friend_requests/{requestId}` onUpdate, `pendiente` → `aceptada`/`rechazada` | `senderUid` | "{receiverUsername} aceptó / rechazó tu solicitud de amistad" |
| `onDuelCreated` | `duels/{duelId}` onCreate | `playerB` (el retado; `playerA` es quien crea el duelo) | "¡Te retaron a un duelo!" |
| `onDuelFinished` | `duels/{duelId}` onUpdate a status `finished` | los DOS jugadores | "¡Ganaste el duelo!" / "Perdiste el duelo contra {nombre}" / "El duelo terminó en empate" si `winnerUid` es null |
| `onSupportReplied` | `support_messages/{messageId}` onUpdate, `reply` pasa de vacío a texto | `authorUid` | "Soporte te respondió" (el cuerpo ES la respuesta, como la bandeja local) |
| `onAnnouncementCreated` | `announcements/{announcementId}` onCreate (si `active` no es `false` **y `sendPush` es `true`**) | TODOS los usuarios con token | título/cuerpo del documento |
| `onUserCreatedNotifyAdmins` | `users/{uid}` onCreate | TODOS los admins | "Nuevo usuario: {username}" |
| `onReportCreatedNotifyAdmins` | `reports/{reportId}` onCreate | TODOS los admins | "Nueva pregunta reportada" |
| `onSupportCreatedNotifyAdmins` | `support_messages/{messageId}` onCreate | TODOS los admins | "Nuevo mensaje de soporte de {username}" |

Detalles que importan:

- **Sin token no hay push**: el token se lee de `users/{uid}.fcmToken`
  (o `admins/{uid}.fcmToken`). Si no hay token (instalación vieja, sin
  permiso), se salta en silencio. La app debe guardar el token en ese
  campo junto con `fcmTokenUpdatedAt` (milisegundos).
- **Ningún fallo rompe el trigger**: cada envío va en try/catch y se
  loguea con `logger`. Un token inválido (app desinstalada) se borra del
  documento para no reintentarlo.
- **Envíos masivos** (avisos a todos, avisos a admins) en tandas de 500
  tokens (límite de `sendEach`) y leyendo solo el campo `fcmToken`.
- **Quitar un amigo no avisa**: el paso `aceptada` → `rechazada` no es
  una respuesta a una solicitud, así que no dispara push.
- **Aviso en bandeja ≠ aviso + push**: un aviso solo llega como push si
  el documento trae `sendPush: true`. Si `sendPush` está ausente o es
  `false`, el aviso queda solo en la bandeja local de la app (al abrirla)
  y la función no manda nada. **Cambio de comportamiento**: antes todos
  los avisos activos mandaban push; ahora solo los que piden push
  explícitamente con `sendPush: true`.
- **Sin emojis, español llano, una línea**, igual que los avisos de la
  bandeja local de la app.

## Contrato `data` con las apps (para abrir la pantalla correcta)

Todos los valores son strings (FCM lo exige):

| `type` | Campos extra | La app debe abrir |
|---|---|---|
| `friend_request` | `requestId`, `senderUid` | Amigos |
| `friend_request_result` | `requestId`, `status` (`aceptada`/`rechazada`) | Amigos |
| `duel_challenge` | `duelId` | Duelos (el reto) |
| `duel_result` | `duelId` | Resultado del duelo |
| `support_reply` | `messageId` | Soporte |
| `announcement` | `announcementId` | Avisos |
| `admin_new_user` | `uid` | Admin → Usuarios |
| `admin_new_report` | `reportId` | Admin → Reportes |
| `admin_new_support` | `messageId` | Admin → Soporte |

La app principal y la Admin todavía tienen que (a) guardar su token FCM
en `fcmToken`/`fcmTokenUpdatedAt` y (b) leer este `data` al tocar la
notificación. Sin eso, la función manda el push pero la app no sabrá a
dónde llevar al tocarlo.

## Estructura

```
functions/
  package.json   deps: firebase-admin, firebase-functions (v2 API)
  index.js       triggers + envío (Admin SDK). Sin lógica de textos.
  payloads.js    constructores PUROS de los payloads (sin Firebase).
  test/
    payloads.test.js   tests con node:test, sin red ni emulador.
```

## Probar en local (sin desplegar)

```bash
cd ~/workspace/quimica-pura-flutter/functions
npm install
node --check index.js
node --check payloads.js
npm test
```

## Desplegar (paso manual, lo hace el agente principal)

### 0. Decisión previa: pasar quemia-8410a a Blaze

Firebase console → Configuración del proyecto → Facturación → cambiar a
Blaze (pago por uso, tarjeta requerida, cuota gratuita mensual
suficiente; coste esperado 0 $/mes). Sin esto el despliegue falla.

### 1. Instalar el CLI de Firebase (si no está)

```bash
npm install -g firebase-tools
firebase --version
```

### 2. Entrar con la cuenta de Google del proyecto

El login usa el navegador y 2FA, así que hay que hacerlo con una
terminal con TTY. En la VM:

```bash
cd ~/workspace/quimica-pura-flutter
script -qec 'firebase login:ci' /dev/null
```

Se imprime una URL: abrirla en el navegador, aprobar con la cuenta de
Google que es dueña de quemia-8410a y completar el 2FA. El navegador
redirige a `http://localhost:9005/?code=...`; esa URL hay que pedirla
desde la VM para completar el login:

```bash
curl 'http://localhost:9005/?code=PEGAR_AQUI_EL_CODIGO_COMPLETO_DE_LA_URL'
```

Si el login ya está hecho en la VM (`firebase projects:list` muestra
quemia-8410a), saltar este paso.

### 3. Instalar dependencias y desplegar

```bash
cd ~/workspace/quimica-pura-flutter/functions
npm install
cd ~/workspace/quimica-pura-flutter
firebase deploy --only functions --project quemia-8410a
```

### 4. Verificar

```bash
firebase functions:list --project quemia-8410a
```

Deben aparecer las 9 funciones de la tabla de arriba. Los logs de cada
envío se ven con:

```bash
firebase functions:log --project quemia-8410a
```

### 5. Probar de extremo a extremo

Pedir a Kristian que, desde la app (versión con token FCM guardado),
envíe una solicitud de amistad a otro usuario y comprobar que el push
llega con la app cerrada. Si no llega: revisar que `users/{uid}.fcmToken`
existe en Firestore y mirar `functions:log`.

## Campos de Firestore usados (verificados contra el código de la app)

- `friend_requests`: `senderUid`, `senderUsername`, `receiverUid`,
  `receiverUsername`, `status` (`pendiente`/`aceptada`/`rechazada`).
  Ver `lib/services/friends_groups_service.dart`.
- `duels`: `playerA` (creador), `playerB` (retado), `playerAName`,
  `playerBName`, `status` (`waiting`/`playing`/`finished`/`cancelled`),
  `winnerUid` (null = empate). Ver `lib/services/duels_service.dart`.
- `support_messages`: `authorUid`, `username`, `message`, `createdAt`
  (Timestamp), `status` (`abierto`/`respondido`), `reply` (null hasta
  responder), `replyAt` (Timestamp). Ver `lib/services/support_service.dart`.
- `announcements`: `title`, `body`, `createdAtMs`, `active` (ausente =
  activo), `sendPush` (solo `true` manda push a todos los usuarios con
  token; ausente o `false` = aviso solo en bandeja, sin push).
  Ver `lib/services/announcements_service.dart`.
- `reports`: `questionId`, `note`, `uid`, `username`, `createdAtMs`.
  Ver `lib/services/reports_service.dart`.
- `users`: documento id = uid, campo `username`; el token va en
  `fcmToken` + `fcmTokenUpdatedAt` (a implementar en la app).
- `admins`: colección de la app Admin, documento id = uid; el token va
  en `fcmToken` + `fcmTokenUpdatedAt` (a implementar en la app Admin).
  Ver `quemia-admin/lib/models.dart`.
