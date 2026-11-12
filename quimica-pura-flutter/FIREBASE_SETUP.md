# Firebase — Quemia (Melli-Qui) v7.0

Guía corta de setup de Firebase para la app principal y la app de admin.
**La app principal funciona 100 % offline sin Firebase**: la sincronización
es opcional y solo ocurre si el usuario da su permiso explícito en la app.
Sin permiso, no se sube nada; sin internet, la app sigue funcionando igual.

La 7.0 añade las funciones online: duelos, torneos, grupos de estudio,
amigos, tienda, reportes de preguntas, anuncios, contenido remoto de
niveles y mensajes de Soporte (bandeja de la app de admin). Todo vive en su propio lugar (ver "Modelo de datos"): nada de
esto se mete dentro de las pantallas de estudio, y sin internet la app
sigue funcionando igual, solo que las partes online muestran una línea
tranquila en vez de errores.

## Proyecto

| Dato | Valor |
| --- | --- |
| Proyecto | Quemia |
| ID del proyecto | `quemia-8410a` |
| Plan | Spark (gratis, 0 USD) |
| Base de datos | Firestore, base de datos `default`, región `nam5` (EE. UU.), modo producción |
| App principal (Android) | paquete `com.melliqui.quimica_pura`, app id `1:898001909401:android:f4c91c3bfcfca657076a08` |
| App de admin (Android) | paquete `com.melliqui.quemia_admin` (registrar en el mismo proyecto) |
| Autenticación | Firebase Auth: **Anónimo** (app principal, automático) + **Google** (app principal al enlazar y app de admin) |

## Autenticación (Firebase Auth)

- **App principal: sesión anónima automática.** Al abrir la app, inicia sesión
  anónima en Firebase Auth sin que el usuario haga nada (sin correo, sin
  contraseña). El **uid** de esa sesión es el **id del documento** del usuario
  en la colección `users`: cada usuario solo puede escribir en su propio
  documento (`request.auth.uid == uid` en las reglas).
- **"Continuar con Google" enlaza sin cambiar el uid.** Si el usuario enlaza
  su cuenta de Google, la sesión anónima se convierte en sesión con Google
  pero el **uid no cambia**: su documento en `users` sigue siendo el mismo.
  Por eso, si pierde el teléfono o instala la app en uno nuevo e inicia
  sesión con Google, recupera su progreso y su respaldo.
- **Puerta de Google para jugar online (7.0): la puerta es de la APP, no de
  las reglas.** Para duelos, torneos, grupos, amigos y tienda, la app exige
  tener Google vinculada antes de activar la sincronización. En Firestore
  Rules no se puede verificar de forma fiable qué proveedores tiene
  vinculados una cuenta, así que las reglas NO exigen Google: solo exigen
  que cada usuario escriba su propio documento (su `uid`). Un usuario
  anónimo que escribiera su propio documento directo por API no afecta a
  nadie: no puede escribir en el documento de otro ni tocar nada ajeno.
- **La app de admin usa inicio de sesión con Google** (cuenta del dueño:
  `pozogomezkristian19@gmail.com`).
- **Hay que habilitar los proveedores en la consola**: Firebase →
  **Authentication → Sign-in method** → activar **Anónimo** y **Google**.
  Sin el proveedor Anónimo habilitado, la app principal no puede iniciar
  sesión y no sincroniza nada (la app sigue funcionando offline).

## Cómo aplicar las reglas de Firestore

Las reglas viven en [`firestore.rules`](firestore.rules) (junto a este archivo).
**No se aplican solas**: hay que publicarlas a mano en la consola.

1. Abrir la [consola de Firebase](https://console.firebase.google.com/) →
   proyecto **Quemia** → **Firestore Database**.
2. Pestaña **Reglas**.
3. Borrar el contenido actual y pegar el contenido completo de `firestore.rules`.
4. Pulsar **Publicar** y esperar la confirmación.
5. Comprobar que no hay errores: si la consola marca un error de sintaxis,
   no publicar y revisar el archivo (las reglas no se guardan a medias).

> Hasta que no se publiquen, la base de datos sigue con las reglas que tenga
> ahora (modo producción: denegado por defecto), así que la sincronización y
> la tabla de posiciones no funcionarán hasta este paso.

## Arranque del primer administrador

**El dueño: `pozogomezkristian19@gmail.com`.** Es el único dueño, con todos
los permisos, y es el primer administrador. No hace falta crearle ningún
documento a mano en la consola: el arranque funciona aunque la colección
`admins` esté **vacía**.

### Por qué funciona con `admins` vacía

La función `isOwner()` de [`firestore.rules`](firestore.rules) (líneas 42–45)
identifica al dueño por una **comparación directa del correo** de la sesión
de Google:

```
function isOwner() {
  return isSignedIn()
    && request.auth.token.email == 'pozogomezkristian19@gmail.com';
}
```

**No lee la colección `admins`**: no hay ningún `get()` ni `exists()` sobre
`admins` dentro de `isOwner()`. Por eso no hay problema de "quién crea al
primer admin": si el dueño se identificara por su documento en `admins`,
nadie podría crear el primer documento porque nadie sería admin todavía.
Las únicas lecturas de `admins` en las reglas son `exists()` dentro de
`isAdmin()` (línea 53) y `get()` dentro de `canManageAdmins()` (línea 62),
y en ambos casos el dueño **no llega a ejecutarlas**: `isOwner()` va
primero en el `||` y el cortocircuito hace que `isAdmin()` y
`canManageAdmins()` devuelvan `true` para el dueño sin leer nada.

Con `admins` vacía, el dueño (por correo) ya puede, según las reglas:

- **Leer y escribir `admins`** (líneas 150–171: `allow read: if isAdmin();`,
  `allow create: if (isOwner() || ...)`): puede crear su propio documento
  `admins/{uid}` con `role: 'owner'` y todos los permisos, y agregar a
  otros admins.
- **Leer y escribir cualquier documento de `users`** (líneas 104 y
  120–135), incluidos `banned` y `bannedReason` (rama `isAdmin()`), para
  ver el progreso y vetar usuarios.
- **Escribir `settings/app`** (línea 189: `allow create, update: if isAdmin();`).

### Flujo de la app (primera entrada del dueño)

1. El dueño abre la app **Quemia Admin** (`com.melliqui.quemia_admin`).
2. Toca **"Iniciar sesión con Google"** y elige su cuenta
   `pozogomezkristian19@gmail.com`.
3. La app lo reconoce como dueño **por configuración** (su correo está
   fijado en la app) y entra directo como dueño: no ve ninguna pantalla de
   "sin acceso".
4. Al entrar por primera vez, la app crea su documento en `admins`
   (`role: 'owner'`, `permissions` todo en `true`, `email`,
   `displayName`, `createdAt`) **si no existe**; si ya existe, no lo
   vuelve a crear. Las reglas lo permiten porque `isOwner()` es `true`
   aunque `admins` esté vacía (ver arriba).
5. Desde ese momento, el dueño puede agregar más admins desde la app
   (o desde la consola). Los demás admins **no** se identifican por
   correo: se identifican por su documento en `admins/{uid}` (regla
   `isAdmin()`, línea 53) y solo pueden lo que su `permissions` les
   permite (`canManageAdmins()`, línea 62).

### Lo que ve cualquier otra cuenta

Cualquier cuenta que **no** sea la del dueño y **no** tenga documento en
`admins` ve **"No tienes acceso de administrador"** y no entra: las
reglas le deniegan la lectura de `admins` (`allow read: if isAdmin();`)
y la escritura en documentos de `users` ajenos (la escritura exige
`request.auth.uid == uid` o ser admin). Un usuario normal sí puede leer
`users` (lectura pública por la tabla de posiciones) y escribir solo en
su propio documento, pero nada de `admins`.

### Si cambia la cuenta del dueño

Si algún día el dueño cambia de cuenta de Google, hay que cambiar el
correo en **tres** sitios y volver a publicar: la función `isOwner()` de
`firestore.rules`, la configuración de la app de admin y esta guía. Ver
también el punto 4 de la nota final de `firestore.rules`.

### Verificación (2026-11-11)

Verificado por revisión manual línea por línea y por script de
estructura: `firestore.rules` ya estaba bien — **no hizo falta cambiar
nada**. `isOwner()` (líneas 42–45) es comparación directa de correo sin
leer `admins`; las 32 reglas `allow` tienen condición; llaves (30/30),
paréntesis (102/102) y corchetes (11/11) balanceados. La validación por
emulador queda pendiente (ver el estado honesto en "Pruebas de seguridad
de las reglas" más abajo): no se pudo ejecutar en esta máquina.

## Dónde va `google-services.json`

Cada app Android lleva **su propio** `google-services.json` (uno por paquete
registrado en el proyecto). No se comparten: el de la principal no sirve
para la de admin ni al revés.

| App | Archivo |
| --- | --- |
| Principal (`com.melliqui.quimica_pura`) | `android/app/google-services.json` — **ya existe** en este repositorio, no tocar |
| Admin (`com.melliqui.quemia_admin`) | Registrar el paquete en el mismo proyecto Quemia: consola de Firebase → ⚙️ Configuración del proyecto → **Tus apps** → **Agregar app** → Android → paquete `com.melliqui.quemia_admin`, descargar su `google-services.json` y ponerlo en `android/app/google-services.json` **de la app de admin** (`~/workspace/quemia-admin/`) |

## Modelo de datos

### Colección `users` — un documento por usuario

- **ID del documento**: el **uid de Firebase Auth** del usuario. La app
  principal inicia sesión anónima automáticamente al abrir, y si el usuario
  enlaza su cuenta con Google el uid **no cambia** (mismo documento, el
  progreso se recupera en un teléfono nuevo).
- **Campos**: `username` (string), `joinedAt` (timestamp), `lastActive` (timestamp),
  `levelsPassed` (map `{bach: int, uni: int}`), `points` (int), `streak` (int),
  `track` (string: `bach` o `uni`), `appVersion` (string),
  `purchases` (lista de ids de artículos comprados en la tienda — **solo ids,
  nunca precios ni datos de pago**, porque este documento es de lectura
  pública, ver abajo), `friends` (lista de uid o usernames — solo si la app
  decide guardarla también aquí; la lista privada vive en la colección
  `friends`), `tournamentMedals` (lista de medallas de torneos),
  `bestTournamentScores` (map con los mejores puntajes por torneo),
  `banned` (bool), `bannedReason` (string, solo si `banned == true`).
- **Solo existen los usuarios que aceptaron compartir**: la app principal pide
  permiso una sola vez; sin permiso no se crea documento.
- **Permisos (reglas)**: lectura pública (la tabla de posiciones lee el progreso
  de todos los que aceptaron); escritura **solo del propio usuario en su propio
  documento** (`request.auth.uid == uid`) y **solo** con los campos `username,
  joinedAt, lastActive, levelsPassed, points, streak, track, appVersion,
  purchases, friends, tournamentMedals, bestTournamentScores` —
  nunca `banned` ni `bannedReason`. Los admins pueden escribir en cualquier
  documento, y son los únicos que escriben `banned`/`bannedReason`.
  Borrado prohibido desde clientes.

### Colección `admins` — un documento por administrador

- **ID del documento**: uid de Firebase Auth (inicio de sesión con Google en la app de admin).
- **Campos**: `email` (string), `displayName` (string), `role` (`'owner'` o `'admin'`),
  `permissions` (map `{viewUsers, viewProgress, banUsers, manageAdmins}` — todos bool),
  `createdAt` (timestamp), `createdBy` (string, uid o correo de quien lo creó).
- **Dueño**: `pozogomezkristian19@gmail.com`, `role: 'owner'`, todos los permisos en `true`.
  El primer documento del dueño lo crea él mismo iniciando sesión con su
  Google; las reglas lo reconocen por su correo (ver `isOwner()` en
  `firestore.rules`), así no hace falta ningún documento previo.
- **Permisos (reglas)**: lectura solo para admins; escritura solo para el dueño
  o admins con `manageAdmins == true`; nadie puede borrar el documento del
  dueño ni cambiar su `role` a `'admin'`.

### Documento `settings/app` — ajustes remotos de la app

- **Campos**: `passThreshold` (int, respuestas para aprobar un nivel, 4 de 5),
  `pointsEasyGain`, `pointsEasyLoss`, `pointsMediumGain`, `pointsMediumLoss`,
  `pointsHardGain`, `pointsHardLoss` (int; p. ej. fácil +3/−5, media +5/−8,
  difícil +8/−12), `maxLives` (int, 5),
  `supportNumber` (string: número de soporte en formato internacional, sin
  `+` ni espacios, p. ej. `5356519431` — es el número que la ventanita de
  Soporte ofrece como opción de WhatsApp cuando `showWhatsApp` está en
  `true`), `showWhatsApp` (bool: muestra o no la opción de WhatsApp en la
  ventanita de Soporte; **apagado (`false`) por ahora**, hasta que haya un
  número propio de Quemia).
- **Permisos (reglas)**: lectura pública (la app principal los lee al abrir);
  escritura solo para admins; borrado prohibido. **Estos dos campos nuevos
  NO cambian las reglas**: `settings/app` ya era solo-escritura para
  admins, así que `supportNumber` y `showWhatsApp` solo se editan desde la
  app de admin (o la consola). Como el documento es de lectura pública, el
  número de soporte es un dato pensado para mostrarse al usuario, no un
  dato privado.

### Colección `duels` — duelos entre 2 jugadores (7.0)

- **ID del documento**: id generado por la app al crear el duelo.
- **Campos**: `participants` (lista de **exactamente 2 uid**), `questions`
  (lista de ids de pregunta), `status` (string: p. ej. `esperando`,
  `en curso`, `terminado`), `answers` (map por uid: respuestas y tiempos
  de cada jugador), `winner` (uid del ganador, o `null` mientras no hay
  ganador).
- **Permisos (reglas)**: **solo los 2 participantes** leen y escriben su
  duelo; nadie más puede verlo. Al crear, el creador tiene que incluirse
  en `participants` y los 2 uid tienen que ser distintos. Al actualizar,
  `participants` y `questions` son **inmutables**: nadie puede meter a un
  tercero en un duelo en curso ni cambiar las preguntas. Borrado prohibido
  desde clientes.
- **Por qué así**: un duelo es privado entre sus dos jugadores (preguntas,
  respuestas y tiempos no son para nadie más), y fijar las preguntas al
  crear evita que alguien cambie el duelo a mitad de partida.

### Colección `tournaments` — torneos (7.0)

- **ID del documento**: id del torneo.
- **Campos**: `title`, `theme` (tema), `dates` (fechas de inicio y fin),
  `questions` (lista de ids de pregunta), `prize` (premio).
- **Permisos (reglas)**: lectura **pública** (todos ven los torneos activos
  y próximos sin iniciar sesión); escritura **solo admins**. La app
  principal **no escribe torneos nunca**: los torneos reales los crea el
  agente principal desde Firebase (consola o Admin SDK). Los resultados
  por jugador no viven aquí, sino en `users` (`bestTournamentScores`,
  `tournamentMedals`).
- **Por qué así**: el torneo es un evento público (título, tema, fechas,
  premio) y su contenido lo controla el dueño, no los jugadores.

### Colección `reports` — reportes de preguntas (7.0)

- **ID del documento**: id generado por la app al crear el reporte.
- **Campos**: `questionId` (id de la pregunta reportada), `authorUid` (uid
  del usuario que reporta — **tiene que ser el uid de la sesión**),
  `note` (nota del usuario), `createdAt` (fecha),
  `status` (`pendiente` | `en revisión` | `arreglado` | `rechazado`).
- **Permisos (reglas)**: crear lo puede **cualquier usuario autenticado**,
  solo como autor de su propio reporte (`authorUid == uid` de la sesión)
  y con estado inicial `pendiente`. Leer lo pueden **solo los admins y el
  propio autor**: un usuario **no** lee los reportes de otros. Actualizar
  lo pueden **solo los admins, y solo el `status`** (la pregunta, el autor,
  la nota y la fecha no se pueden tocar después de creado). Borrado
  prohibido desde clientes.
- **Por qué así**: cualquiera puede avisar de una pregunta rota, pero nadie
  puede reportar en nombre de otro ni espiar los reportes ajenos, y solo
  un admin cierra un reporte (p. ej. `arreglado`).

### Colección `support_messages` — Mensajes de Soporte (7.0)

- **ID del documento**: id generado por la app al crear el mensaje.
- **Campos CANÓNICOS** (los mismos en la app principal, la app de admin
  y `firestore.rules` — no usar otros nombres): `authorUid` (uid del
  usuario que escribe — **tiene que ser el uid de la sesión**),
  `username` (nombre del usuario, el que ve el admin en su bandeja),
  `message` (texto del usuario), `createdAt` (fecha de envío),
  `status` (`abierto` | `respondido`), `reply` (respuesta del admin;
  ausente mientras el mensaje está `abierto`), `replyAt` (fecha de la
  respuesta, la escribe el admin al responder).
- **Cómo funciona**: el usuario escribe su mensaje en una ventanita
  dentro de la app — **ya NO abre WhatsApp directo**. Sin internet, el
  mensaje se guarda en local en el teléfono y se envía a Firestore al
  volver la conexión (la cola offline la gestiona la app, no Firebase:
  las reglas solo ven la escritura cuando llega). La app de admin tiene
  una bandeja de Soporte para leer los mensajes y responderlos; la
  respuesta la ve el usuario en su ventanita. El número de soporte y el
  interruptor de WhatsApp viven en `settings/app` (`supportNumber`,
  `showWhatsApp`, ver arriba): no son parte de cada mensaje.
- **Permisos (reglas)**: crear lo puede **cualquier usuario autenticado**,
  solo como autor de su propio mensaje (`authorUid == uid` de la sesión),
  con estado inicial `abierto`, `message` no vacío y **sin `reply`** (un
  usuario no puede crear un mensaje que ya trae respuesta). Leer lo
  pueden **solo los admins y el propio autor**: un usuario **no** lee los
  mensajes de otros. Actualizar lo pueden **solo los admins, y solo los
  campos de respuesta y estado** (`reply`, `replyAt`, `status`); al
  responder, el admin escribe `reply` + `replyAt` y pone `status:
  'respondido'` (un `respondido` sin `reply` no vacío se rechaza).
  El usuario **NO** puede editar su propio mensaje una vez enviado ni
  cambiar el estado (ni marcarlo `respondido` él mismo, ni reabrirlo).
  Borrado prohibido desde clientes (los mensajes se conservan como
  historial; si hay que borrar uno, se hace a mano desde la consola).
- **Por qué así**: es el mismo patrón que `reports` (autor + estado que
  solo tocan los admins), pero con respuesta visible para el autor: el
  Soporte es una conversación privada entre cada usuario y el admin, no
  un tablón público, y solo el admin puede cerrar un hilo con una
  respuesta. Que el usuario no pueda editar su mensaje evita que borre
  o cambie lo que ya leyó el admin; que no pueda crear con `reply`
  evita que se fabrique una respuesta falsa.

### Colección `announcements` — anuncios a todos los usuarios (7.0)

- **ID del documento**: id generado al crear el anuncio.
- **Campos**: `title`, `body` (texto), `createdAt` (fecha).
- **Permisos (reglas)**: lectura **pública**; escritura **solo admins**.
- **Por qué así**: es un tablón del dueño para todos; ningún usuario puede
  publicar anuncios.

### Colección `groups` — grupos de estudio (7.0)

- **ID del documento**: **el propio código de invitación** (o el id del
  documento compartido junto con el código) — ver el aviso abajo.
- **Campos**: `name`, `inviteCode` (código de invitación), `members`
  (lista de uid), `creatorUid` (uid del creador).
- **Permisos (reglas)**: leer lo pueden **solo los miembros**. Crear lo
  puede cualquier usuario autenticado, siendo el creador y su único miembro
  inicial. Actualizar: el **creador** edita el nombre, el código o los
  miembros (sin cambiar el `creatorUid` ni quitarse a sí mismo); **unirse**
  lo puede quien no era miembro, añadiéndose **solo a sí mismo** a
  `members` sin tocar ningún otro campo; **salirse** lo puede un miembro
  quitándose solo a sí mismo. Un miembro que no es creador no puede editar
  el nombre, el código ni a otros miembros. Borrar, solo el creador.
- **⚠️ Aviso importante — cómo se entra con el código**: como la lectura es
  solo para miembros, alguien que todavía no es miembro **no puede buscar
  el grupo por su código** (una consulta por `inviteCode` fallaría: las
  reglas no pueden comparar el código que el usuario escribe con el del
  documento). Por eso el documento tiene que ser localizable sin buscar:
  la app debe usar el propio código de invitación como id del documento
  (o compartir el id del documento junto con el código), y comprobar en
  local que el código escrito coincide con `inviteCode` antes de intentar
  unirse. **El código es la única llave**: quien lo conoce puede unirse,
  como el enlace de un grupo de WhatsApp; no hay verificación del código
  en el servidor. Si algún día hace falta una unión verificada en
  servidor, hará falta una Cloud Function (no existe en esta ronda).
- **Por qué así**: el grupo es privado (nombre, miembros y código no se
  ven desde fuera) y el creador manda en él, pero cualquiera con el código
  puede entrar, que es justo para lo que sirve un código de invitación.

### Colección `friends` — lista de amigos por usuario (7.0)

- **ID del documento**: el **uid de Firebase Auth** del usuario (igual que
  en `users`).
- **Campos**: `friends` (lista de uid o de usernames de los amigos).
- **Permisos (reglas)**: leer y escribir, **solo el propio usuario**
  (`request.auth.uid == uid`). Nadie más ve ni toca la lista de amigos
  de otro. Borrado prohibido desde clientes (vaciar la lista es una
  actualización con `friends: []`).
- **Por qué así**: la lista de amigos es privada. Ojo: `friends` también
  está en la lista blanca de `users` por si la app lo guarda en el
  documento de usuario, pero **eso es público** (la lectura de `users` es
  pública por la tabla de posiciones). Si la lista debe ser privada, hay
  que guardarla **solo aquí**, nunca en el documento de `users`.

### Colección `friend_requests` — solicitudes de amistad (ronda 2d)

- **ID del documento**: id generado por Firestore (`createDoc`).
- **Campos**: `senderUid`, `senderUsername`, `receiverUid`,
  `receiverUsername`, `status` (`'pendiente' | 'aceptada' |
  'rechazada'`), `createdAtMs`.
- **Permisos (reglas)**: leer, **solo remitente y destinatario**
  (nadie más ve quién le pidió amistad a quién). Crear, **solo el
  remitente** con su propio uid como `senderUid`, estado inicial
  `'pendiente'` y sin poder pedirse amistad a sí mismo; solo los 6
  campos del contrato. Actualizar, **solo cambia `status`**: el
  destinatario confirma (`'aceptada'`) o elimina (`'rechazada'`) la
  que le llegó; el remitente cancela la suya (`'rechazada'`). Borrar
  prohibido desde clientes: rechazar o cancelar es un cambio de
  estado, nunca un borrado.
- **Por qué así**: la solicitud es privada entre los dos. La
  amistad confirmada se guarda en la `friends` de cada usuario (ver
  `users`): al confirmar, el destinatario añade el uid del remitente
  a su propia lista y añade **solo su propio uid** a la lista del
  remitente (excepción estrecha en las reglas de `users`: la
  escritura solo puede cambiar `friends`, conservar a todos los que
  ya había y añadir como mucho el propio uid). Además, la lista de
  amigos de la app es la unión de `friends` con las solicitudes
  `'aceptada'` en los dos sentidos: aunque la escritura espejo aún
  no haya llegado, los dos quedan amigos al confirmar. Al quitar a
  un amigo, la solicitud aceptada pasa a `'rechazada'` para que no
  vuelva a aparecer solo.
- **Límite honesto**: la confirmación mutua depende de las reglas
  publicadas (sin el bloque `friend_requests` y sin la excepción
  estrecha en `users`, el envío y la confirmación se deniegan y la
  app encola el envío). El agente principal aplica las reglas en la
  consola antes de que la función pueda usarse. Una solicitud
  enviada sin internet se guarda en local y se reenvía sola al
  abrir la app o al volver a primer plano.

### Colección `levels` — contenido remoto de preguntas (7.0)

- **ID del documento**: id del nivel o de la pregunta.
- **Campos**: `text` (texto de la pregunta), `options` (opciones),
  `answer` (respuesta correcta), `difficulty` (dificultad), `level`
  (nivel al que pertenece).
- **Permisos (reglas)**: lectura **pública**; escritura **solo admins**
  (editor de contenido de la app de admin o consola).
- **Por qué así**: las preguntas remotas son contenido de estudio para
  todos, y solo los admins pueden cambiarlas. La app principal siempre
  guarda una copia local, así que sin internet sigue funcionando con el
  contenido incluido en la app.

### Todo lo demás

Denegado por defecto: cualquier colección o documento fuera de `users`,
`admins`, `settings/app`, `duels`, `tournaments`, `reports`,
`support_messages`, `announcements`, `groups`, `friends`,
`friend_requests` y `levels` no se puede leer ni escribir desde ningún
cliente. Cada colección nueva tiene que añadirse a
`firestore.rules` con su propio bloque y volver a publicarse; hasta
entonces, la denegación por defecto la bloquea. Hueco futuro: el modelo
admite ampliaciones, pero en esta ronda no se inventa ninguna colección
más (`tournaments` ya está cubierto arriba).

## Pruebas de seguridad de las reglas — "A escribe lo de B → DENEGADO"

**Estado honesto de la validación (2026-11-11): el emulador NO se pudo
usar en esta máquina.** Se instaló `firebase-tools` 15.35.0 y el emulador
de Firestore (`cloud-firestore-emulator-v1.22.0.jar`, Java 21), el
emulador arranca y dice "All emulators ready", pero **toda** petición a
su puerto 8085 falla: la API REST devuelve
`503 {"error":{"code":503,"message":"Network closed for unknown reason"}}`
y el SDK de JS recibe `RST_STREAM ... Protocol error` en cada stream
gRPC. Se probó con el CLI, con el jar directo, con/sin variables de proxy
y con otro puerto: mismo fallo. Es un problema del emulador en este
entorno, no de las reglas (las reglas ni llegan a evaluarse). Por eso los
casos de abajo **no están ejecutados contra el emulador**: están
documentados para verificarse a mano en la consola antes de publicar, y
existe además un script automático (`~/.fbtest/test-rules.mjs`, 40 casos
con `@firebase/rules-unit-testing`, emulador en `127.0.0.1:8085`) para
correrlos donde el emulador sí funcione. La estructura del archivo sí
está verificada por script (tras quitar comentarios y strings, para no
contar los paréntesis de los comentarios): llaves (32/32), paréntesis
(115/115) y corchetes (13/13) balanceados y los 36 `allow` tienen
condición — conteo actualizado 2026-11-11 al añadir `support_messages`
(antes: 32 `allow`). Revisión manual línea por línea del bloque
`support_messages` también hecha en esta ronda.

**Cómo verificar a mano (consola de Firebase → Firestore Database →
pestaña "Reglas" → "Playground" / "Simulador de reglas"):** para cada
caso, elegir el tipo (get / create / update / delete), la ruta del
documento y la identidad (uid de Firebase Auth; para los casos de admin,
un uid con documento en `admins` o el correo del dueño
`pozogomezkristian19@gmail.com`). El resultado esperado es "Permitido"
o "Denegado" según la tabla. Los uids de ejemplo son `alice` (A) y
`bob` (B); hay que sembrar antes los documentos que cada caso necesita
(duelo `duels/d1` con participantes `[alice, bob]`, grupo `groups/g1`
con creadora `alice`, reporte `reports/r1` con autora `bob`, mensaje de
Soporte `support_messages/sm1` con autor `bob` y `status: abierto`).

| Colección | Caso | Esperado | Regla que lo decide |
| --- | --- | --- | --- |
| `users` | Alice escribe `users/alice` (campos de la lista blanca) | ✅ Permitido | `request.auth.uid == uid` + `hasOnly(lista blanca)` |
| `users` | Alice escribe `users/bob` | ❌ Denegado | `request.auth.uid == uid` no se cumple (no es admin) |
| `users` | Alice escribe `banned: true` en su propio doc | ❌ Denegado | `banned` no está en la lista blanca y se excluye explícito |
| `users` | Admin escribe `banned: true` en `users/bob` | ✅ Permitido | Rama `isAdmin()` con chequeo `banned is bool` |
| `duels` | Alice crea `duels/d2` con `participants: [alice, bob]` | ✅ Permitido | Creadora incluida, 2 uid distintos, `questions is list` |
| `duels` | Carol crea duelo con `participants: [alice, bob]` | ❌ Denegado | Creadora no está en `participants` |
| `duels` | Carol lee o actualiza `duels/d1` (duelo alice-bob) | ❌ Denegado | Lectura/escritura exigen `auth.uid in participants` |
| `duels` | Alice cambia `participants` o `questions` de `d1` | ❌ Denegado | Ambos campos son inmutables en `update` |
| `duels` | Alice cambia `answers.bob` (la entrada del otro) | ❌ Denegado | Solo se puede tocar la clave propia en `answers` (`diff().affectedKeys().hasOnly([uid])`) |
| `duels` | Alice cambia `answers.alice` (su propia entrada) | ✅ Permitido | La clave afectada es su propio uid |
| `duels` | Alice borra el campo `answers` entero | ❌ Denegado | Si `answers` existía, no se puede quitar |
| `tournaments` | Alice crea o edita un torneo | ❌ Denegado | Escritura solo `isAdmin()` |
| `tournaments` | Admin crea un torneo; cualquiera lo lee | ✅ Permitido | `isAdmin()` / lectura pública |
| `reports` | Alice crea reporte con `authorUid: alice`, `status: pendiente` | ✅ Permitido | Autor = uid de la sesión, estado inicial `pendiente` |
| `reports` | Alice crea reporte con `authorUid: bob` | ❌ Denegado | `authorUid == request.auth.uid` no se cumple |
| `reports` | Alice lee el reporte de Bob | ❌ Denegado | Lectura: solo admins o el propio autor |
| `reports` | Bob actualiza el estado de su propio reporte | ❌ Denegado | Actualizar: solo admins |
| `reports` | Admin cambia `status` a `arreglado` | ✅ Permitido | Solo cambia `status` y el valor está en la lista |
| `reports` | Admin cambia `questionId` o la nota | ❌ Denegado | `affectedKeys().hasOnly(['status'])` |
| `support_messages` | Alice crea su mensaje con `authorUid: alice`, `status: abierto`, `message` no vacío | ✅ Permitido | Autor = uid de la sesión, estado inicial `abierto` |
| `support_messages` | Alice crea un mensaje con `authorUid: bob` | ❌ Denegado | `authorUid == request.auth.uid` no se cumple |
| `support_messages` | Alice crea un mensaje con `status: respondido` o con `reply` ya puesto | ❌ Denegado | Estado inicial tiene que ser `abierto`; `reply` no puede venir en la creación |
| `support_messages` | Alice lee el mensaje de Bob (`support_messages/sm1`) | ❌ Denegado | Lectura: solo admins o el propio autor |
| `support_messages` | Bob intenta responder su propio mensaje (escribe `reply` y pone `status: respondido`) | ❌ Denegado | Actualizar: solo admins (`isAdmin()`); el autor no puede cambiar el estado ni responder |
| `support_messages` | Bob edita su propio `message` después de enviado | ❌ Denegado | Actualizar: solo admins, y solo `status`/`reply`/`replyAt` |
| `support_messages` | Admin responde: escribe `reply` + `replyAt` y pone `status: respondido` | ✅ Permitido | Solo cambian `reply`/`replyAt`/`status`, y `respondido` trae `reply` no vacío |
| `support_messages` | Admin cambia `message`, `authorUid` o `username` de un mensaje | ❌ Denegado | `affectedKeys().hasOnly(['status', 'reply', 'replyAt'])` |
| `support_messages` | Admin pone `status: respondido` sin escribir `reply` | ❌ Denegado | `respondido` exige `reply` presente, string y no vacío |
| `support_messages` | Alice o un admin borra un mensaje | ❌ Denegado | `allow delete: if false;` (borrado solo a mano en consola) |
| `announcements` | Alice crea un anuncio | ❌ Denegado | Escritura solo `isAdmin()` |
| `announcements` | Admin crea un anuncio; cualquiera lo lee | ✅ Permitido | `isAdmin()` / lectura pública |
| `groups` | Alice crea grupo con `creatorUid: alice`, `members: [alice]` | ✅ Permitido | Creadora = uid de la sesión, única miembro inicial |
| `groups` | Alice crea grupo con `members: [alice, bob]` | ❌ Denegado | Al crear, `members` tiene que ser solo la creadora |
| `groups` | Bob lee `groups/g1` (no es miembro) | ❌ Denegado | Lectura solo para miembros |
| `groups` | Bob se une: cambia solo `members` a `[alice, bob]` | ✅ Permitido | Rama "unirse": no era miembro y se añade solo a sí mismo |
| `groups` | Bob edita el nombre (no es creador) | ❌ Denegado | Solo el creador edita nombre/código/miembros |
| `groups` | Alice (creadora) edita el nombre | ✅ Permitido | Rama "creador" |
| `groups` | Bob se sale: cambia solo `members` a `[alice]` | ✅ Permitido | Rama "salirse": se quita solo a sí mismo |
| `groups` | Carol borra el grupo; Alice (creadora) lo borra | ❌ / ✅ | Borrar: solo `creatorUid == uid` |
| `friends` | Alice escribe `friends/alice` | ✅ Permitido | `request.auth.uid == uid` |
| `friends` | Alice escribe o lee `friends/bob` | ❌ Denegado | `request.auth.uid == uid` no se cumple |
| `friend_requests` | Alice crea solicitud con `senderUid: alice`, `status: pendiente` | ✅ Permitido | Remitente = uid de la sesión, estado inicial `pendiente` |
| `friend_requests` | Alice crea solicitud con `senderUid: bob` | ❌ Denegado | `senderUid` tiene que ser el uid de la sesión |
| `friend_requests` | Alice crea solicitud para sí misma (`receiverUid: alice`) | ❌ Denegado | `senderUid != receiverUid` |
| `friend_requests` | Carol lee la solicitud de Alice a Bob | ❌ Denegado | Lectura solo remitente o destinatario |
| `friend_requests` | Bob confirma la solicitud de Alice (`status: aceptada`) | ✅ Permitido | Destinatario cambia solo `status` a `aceptada` |
| `friend_requests` | Alice confirma su propia solicitud (`status: aceptada`) | ❌ Denegado | Solo el destinatario puede aceptar |
| `friend_requests` | Bob elimina la solicitud de Alice (`status: rechazada`) | ✅ Permitido | Destinatario cambia solo `status` a `rechazada` |
| `friend_requests` | Alice cancela su solicitud (`status: rechazada`) | ✅ Permitido | Remitente cambia solo `status` a `rechazada` |
| `friend_requests` | Bob cambia `senderUsername` en la solicitud | ❌ Denegado | Solo puede cambiar `status` |
| `friend_requests` | Alice o Bob borra la solicitud | ❌ Denegado | `allow delete: if false;` (rechazar es un estado, no un borrado) |
| `users` | Bob confirma la solicitud de Alice: añade solo su uid a `friends` de Alice | ✅ Permitido | Excepción estrecha: solo cambia `friends`, conserva los demás y añade como mucho el propio uid |
| `users` | Bob añade a Carol a `friends` de Alice (o quita a alguien) | ❌ Denegado | La excepción estrecha solo permite añadir el propio uid |
| `users` | Bob cambia `points` en `users/alice` | ❌ Denegado | La excepción estrecha solo permite cambiar `friends` |
| `levels` | Alice crea un nivel | ❌ Denegado | Escritura solo `isAdmin()` |
| `levels` | Admin crea un nivel; cualquiera lo lee | ✅ Permitido | `isAdmin()` / lectura pública |
| `admins` | **Dueño con `admins` VACÍA** crea su propio doc `admins/{uid}` (`role: 'owner'`) | ✅ Permitido | `isOwner()` es comparación directa de correo, no lee `admins` |
| `admins` | **Dueño con `admins` VACÍA** lee `admins` (o cualquier doc de `admins`) | ✅ Permitido | `allow read: if isAdmin();` y el dueño es admin por correo |
| `users` | **Dueño con `admins` VACÍA** lee `users/bob` y escribe `banned: true` | ✅ Permitido | Lectura pública + rama `isAdmin()` (dueño por correo) |
| `settings/app` | **Dueño con `admins` VACÍA** escribe `settings/app` | ✅ Permitido | `allow create, update: if isAdmin();` |
| `admins` | Alice (cuenta cualquiera, sin doc en `admins`) lee `admins` | ❌ Denegado | `isAdmin()` falso: no es dueña ni tiene doc en `admins` |
| `admins` | Alice crea `admins/alice` con `role: 'admin'` | ❌ Denegado | Crear exige `isOwner()` o `manageAdmins` |
| `users` | Alice (cuenta cualquiera) escribe en `users/bob` | ❌ Denegado | `request.auth.uid == uid` no se cumple (no es admin) |
| `admins` | Dueño agrega un segundo admin: crea `admins/bob` con `role: 'admin'` | ✅ Permitido | `isOwner()` + `role` en `['owner', 'admin']` |
| `users` | **Segundo admin (Bob)** lee `users/alice` | ✅ Permitido | Lectura pública de `users` (tabla de posiciones) |
| `users` | **Segundo admin (Bob)** escribe `banned: true` en `users/alice` | ✅ Permitido | Rama `isAdmin()` (doc en `admins` existe) + `banned is bool` |
| `admins` | **Segundo admin (Bob, sin `manageAdmins`)** crea otro admin | ❌ Denegado | `canManageAdmins()` falso: su `permissions.manageAdmins` no es `true` |

**Para los casos de "dueño con `admins` VACÍA":** no sembrar ningún
documento en `admins` antes de probar — la colección tiene que estar
vacía. La identidad del dueño es el correo
`pozogomezkristian19@gmail.com` (no un uid concreto), así que en el
simulador de reglas hay que autenticarse con ese correo (o usar el uid
que Firebase le asigne a esa cuenta de Google en la app de admin; el
correo es lo que decide `isOwner()`).

**Límites que las reglas NO cubren (a verificar en la app, no aquí):**
un participante puede inflar sus **propios** tiempos/respuestas en un
duelo o declararse ganador sin haber ganado (las reglas no conocen las
respuestas correctas); un usuario puede inflar sus **propios** puntos en
`users`; y en `groups` quien conoce el código puede unirse (el código es
la llave, ver la sección `groups`). Un usuario también puede enviar
muchos mensajes de Soporte seguidos (las reglas no limitan la cantidad,
solo quién escribe cada uno). Todo eso se detecta en la bandeja de la app
de admin y se corrige vetando (`banned = true`).

## Privacidad y lectura pública de `users`

La lectura pública de `users` es **intencionada**: la tabla de posiciones
necesita leer el progreso de todos los usuarios que aceptaron compartirlo.
Es seguro porque en Firestore solo están los datos de quienes dieron permiso
explícito y los campos son solo progreso de estudio (nombre, puntos, niveles,
racha), nunca correo, teléfono, ubicación ni contraseñas. La **escritura**
sí está protegida por identidad: la app principal usa Firebase Auth anónimo
y cada usuario solo puede escribir en su propio documento
(`request.auth.uid == uid`); nadie puede tocar el documento de otro ni
escribir `banned`/`bannedReason`. Ver la nota completa al final de
[`firestore.rules`](firestore.rules).

## Qué NO hace Firebase en esta ronda

- No sustituye el progreso local: todo el progreso, vidas, puntos y niveles
  siguen guardados en el teléfono y funcionan sin internet.
- No hay registro con contraseña para los usuarios de la app principal: la
  sesión es anónima y automática, y solo se enlaza a Google si el usuario
  elige "Continuar con Google" (para recuperar su progreso en otro teléfono).
- No se envían notificaciones desde Firebase (las notificaciones de la app son locales).
- No hay Cloud Functions: la unión a un grupo con el código no se verifica
  en el servidor (el código es la llave; ver la sección `groups`), y los
  torneos los crea el agente principal desde Firebase, no la app.
- No hay verificación en servidor de los resultados de duelos y torneos:
  un participante puede inflar su propio puntaje/tiempo; eso se detecta en
  la app de admin y se corrige vetando (`banned = true`).
- No se guarda en Firestore ningún dato de pago: `purchases` guarda solo
  ids de artículos, y la lista de amigos privada vive solo en la colección
  `friends`, nunca en el documento público de `users`.
