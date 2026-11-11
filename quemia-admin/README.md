# Quemia Admin

Panel de administración de la app **Quemia** (química pura) — **Quemia 7.0,
la aplicación completa en una sola entrega**. Permite ver cuántos usuarios
se unieron, su progreso y estadísticas, banearlos, gestionar
administradores, mandar avisos a todos, editar el banco de preguntas,
resolver reportes, responder mensajes de soporte y cambiar los ajustes
remotos que la app principal lee al abrir (`settings/app`).

- Paquete Android: `com.melliqui.quemia_admin`
- Proyecto Firebase: **Quemia** (`quemia-8410a`, plan Spark gratis)
- Flutter 3.47.9 / Dart 3.13.7

## Diseño

Tema claro, moderno, con el sistema de diseño de Quemia: teal **#00C2A8**
como primario, tarjetas grandes redondeadas (18 px), tipografía limpia,
filas de usuario con avatar de inicial (círculo con la primera letra del
nombre). Navegación inferior simple: **Panel / Usuarios / Admins**. Desde el Panel
se abren además: **Avisos**, **Editor de contenido**, **Reportes** y
**Ajustes remotos** (tarjetas de gestión).

## google-services.json — DEFINITIVO, no provisional

`android/app/google-services.json` es el archivo **propio y definitivo** de
este paquete, no una copia provisional de la app principal:

- Proyecto `quemia-8410a`, paquete `com.melliqui.quemia_admin`
- App id `1:898001909401:android:c5c003015f8234d0076a08`
- `api_key` presente
- Contiene **solo el cliente OAuth web (tipo 3)**, sin cliente Android ni
  huella SHA-1 — por eso el inicio de sesión usa el flujo por navegador de
  Firebase Auth (ver abajo) y NO ningún plugin de inicio de sesión de
  Google.

Si Firebase regenera el archivo (por ejemplo, al crear nuevos clientes
OAuth), hay que sustituir este archivo por el nuevo descargado de la
consola. El inicio de la app es defensivo: si Firebase no se puede
inicializar, muestra una pantalla clara *"Falta configurar Firebase"* en
vez de romperse.

## Inicio de sesión

**Solo Firebase Auth con `signInWithProvider(GoogleAuthProvider())`.**
No hay ningún plugin de inicio de sesión de Google en `pubspec.yaml` ni
en el código: en un APK release sin keystore firmado ese plugin falla
porque su cliente OAuth exige la huella SHA-1, mientras que el flujo por
navegador de Firebase Auth no la necesita y funciona en el APK instalado
directamente (sin Play Store). El proveedor Google está habilitado en la
consola de Firebase.

Manejo de error honesto: mientras firma, el botón muestra estado de carga;
si falla, la app muestra *"No se pudo iniciar sesión con Google. Inténtalo
de nuevo."* (con el detalle técnico en letra pequeña) y el botón queda
disponible para reintentarlo. La app nunca se cuelga ni se cierra por un
fallo de login.

Puerta de auth: tras el login se lee el documento `admins/<uid>`; si NO
existe, se muestra *"No tienes acceso de administrador"* con el uid del
usuario (para darlo de alta) y botón de cerrar sesión.

## Distribución (APK de Quemia Admin)

- **Workflow de GitHub Actions**: `build-admin-apk.yml` — compilación con
  Flutter 3.47.9, `flutter build apk --release`, publicación como Release
  con tag `quemia-admin-v1` y asset `quemia-admin-release.apk`. Como la
  app de GitHub no puede escribir `.github/workflows/`, el archivo vive
  **solo como copia local** en
  `~/workspace/melli-qui-workflow/.github/workflows/build-admin-apk.yml` y
  el agente principal lo crea en el repo por la web de GitHub cuando
  llegue el momento. **NO se puede probar en local** (no hay Actions
  aquí); se revisó línea por línea contra el workflow principal
  (`build-apk.yml`): mismos pasos, rutas adaptadas a `quemia-admin/`,
  tag y asset correctos.
- **`google-services.json` en el workflow**: viaja como **archivo plano**
  en `quemia-admin/android/app/google-services.json` junto con el
  proyecto (es JSON UTF-8 y su `api_key` es una clave pública de cliente,
  no un secreto; la seguridad real está en las reglas de Firestore). El
  workflow no tiene que decodificarlo ni hacer nada especial con él, solo
  comprobar que existe. Los binarios (jar de Gradle e iconos) sí se
  restauran desde base64 como en la app principal, por si llegan al repo
  como texto.
- **El enlace del APK de admin es PRIVADO**: el Release
  (`quemia-admin-v1`) existe para que Kristian descargue el APK, pero su
  enlace se le entrega **por chat, solo a él**, y **NO va en ninguna
  página pública** — ni en la landing de Firebase Hosting (que lleva SOLO
  el botón de Quemia) ni en ningún otro sitio público. Por eso el workflow
  de admin **no** tiene el fallback de "commit APK a `docs/`" de la app
  principal: el APK de admin nunca debe acabar en GitHub Pages. Si la
  publicación del Release falla, el job falla a la vista (sin
  `continue-on-error`).

## Sin conexión

La app es online por naturaleza (lee Firestore), pero **sin internet no
pasa nada malo**: cada llamada a Firestore lleva un timeout de 20 s y
todas las pantallas atrapan el error y muestran un estado tranquilo
(*"Sin conexión"* + botón *Reintentar*). Ningún diálogo de error, ningún
banner rojo, ningún bloqueo ni cierre. Las acciones (banear, invitar,
guardar ajustes) que fallan por red muestran solo un aviso neutro
(*"Sin conexión. Inténtalo de nuevo."*) y se pueden reintentar. Ver
`CalmOfflineState` en `lib/screens.dart` y `test/offline_test.dart`.

## Cómo se agrega el primer admin (dueño)

El dueño es **pozogomezkristian19@gmail.com**, `role: 'owner'`, todos los
permisos en `true` — y es dueño **por configuración** (constante
`kOwnerEmail` en `lib/models.dart`):

1. El dueño abre la app y toca *"Entrar con Google"* con su cuenta.
2. La app detecta que es el correo del dueño y **crea sola su documento**
   en `admins/<uid>` con todos los permisos, aunque la colección esté
   vacía. Entra directo como dueño, sin ningún alta manual previa.
3. Si el documento ya existe, simplemente entra.

Cualquier otra cuenta que intente entrar sin estar en `admins` ve
*"No tienes acceso de administrador"* y no entra.

Después, el dueño agrega más admins desde la pantalla **Admins** por
correo de Google: se crea una invitación pendiente (documento `admins` con
id = el correo) con permisos solo de lectura; el nuevo admin entra con su
cuenta de Google y la invitación se adopta automáticamente a su uid.
Nadie puede eliminar al dueño, quitarle permisos, ni concederse a sí mismo
un permiso que no tiene (ver `AdminService`).

## Compilar

```sh
cd quemia-admin
~/sdks/flutter-3.47.9/bin/flutter pub get
~/sdks/flutter-3.47.9/bin/flutter analyze
~/sdks/flutter-3.47.9/bin/flutter test
~/sdks/flutter-3.47.9/bin/flutter build apk --release
```

El plugin `com.google.gms.google-services` (4.4.3) está declarado en
`android/settings.gradle.kts` y aplicado en `android/app/build.gradle.kts`.

## Estructura

| Archivo | Qué hace |
|---|---|
| `lib/main.dart` | Arranque defensivo de Firebase + puerta de auth |
| `lib/models.dart` | `AppUser`, `AdminRecord`, `AdminPermissions`, `RemoteSettings`, `QuizQuestion`, `LevelContent`, `Announcement`, `QuestionReport` |
| `lib/repositories.dart` | Interfaces de repositorio + impl. Firestore + fakes en memoria + `AdminService` (matriz de permisos) |
| `lib/stats.dart` | Estadísticas del Panel (cálculo puro, probado con fakes) |
| `lib/auth_service.dart` | Login con Google vía `signInWithProvider` |
| `lib/screens.dart` | Pantallas + tema `quemiaAdminTheme()` |
| `firestore.rules` | Reglas de Firestore propuestas (referencia, desplegar desde la consola) |

### Contrato de datos (el mismo que la app principal)

- `users/<id anónimo>`: `username`, `joinedAt`, `lastActive`,
  `levelsPassed {bach, uni}`, `points`, `streak`, `track`, `appVersion`,
  `banned`, `bannedReason`, `bannedAt`.
- `admins/<uid>`: `email`, `displayName`, `role` (`owner`|`admin`),
  `permissions {viewUsers, viewProgress, banUsers, manageAdmins}`,
  `createdAt`, `createdBy`, `pending` (solo invitaciones por correo).
- `settings/app`: `passThreshold` (4), `pointsEasyGain` (3),
  `pointsEasyLoss` (-5), `pointsMediumGain` (5), `pointsMediumLoss` (-8),
  `pointsHardGain` (8), `pointsHardLoss` (-12), `maxLives` (5).
- `levels/<track>-<topic>-<nivel>` (contenido remoto, Quemia 7.0):
  `track`, `topic`, `topicTitle`, `level` (int), `title`, `questions`
  (array de `{id, text, options[4], correctIndex, difficulty}`).
  La app principal lo lee con fallback al contenido local si es inválido
  o no hay internet.
- `announcements/<autoId>` (Quemia 7.0): `title`, `body`, `createdAt`,
  `createdBy`, `active`. La app principal muestra los activos en su
  bandeja de notificaciones.
- `reports/<autoId>` (Quemia 7.0): `questionId`, `levelId`, `questionText`,
  `username`, `note`, `createdAt`, `status` (`open`|`fixed`). Los crea la
  app principal cuando un usuario reporta una pregunta.
- `support_messages/<autoId>` (Quemia 7.0): `authorUid`, `username`,
  `message`, `createdAt`, `status` (`abierto`|`respondido`), `reply`,
  `replyAt`. Los crea la app principal desde la ventanita de Soporte; al
  responder, la admin escribe `reply` + `replyAt` y pone `status`
  `respondido`; el usuario ve la respuesta en su ventanita (con aviso en
  su bandeja). La respuesta automática de Muse NO va en esta versión:
  responde Kristian (o un admin) cuando puede.
- `settings/app` también guarda el soporte: `supportNumber`
  (`+5356519431` por defecto) y `showWhatsApp` (`false` por defecto). La
  app principal muestra el botón de WhatsApp en su ventanita solo si
  `showWhatsApp` está encendido; Kristian cambia el número y el
  interruptor desde esta app de admin cuando tenga el número de Quemia,
  sin actualizar la app.

### Estadísticas del Panel (Quemia 7.0)

Calculadas en `lib/stats.dart` solo con los datos que ya existen:

- **Activos por día** (últimos 7 días) y **versiones de la app**: de
  `users` (`lastActive`, `appVersion`).
- **Nivel donde más se atascan**: PROXY a partir del progreso (`users`):
  el nivel actual de cada usuario es (niveles superados en su pista + 1)
  y el más repetido es donde más usuarios están parados. Cuando la app
  principal envíe telemetría de intentos por nivel, se afina con intentos
  fallidos reales.
- **Preguntas con más fallos**: PROXY a partir de `reports`: las preguntas
  más reportadas (y aún abiertas) son las que más problemas dan. Igual que
  arriba: con telemetría real de intentos fallidos se sustituye por el
  conteo real.

### Para después (sin código en esta ronda)

**Torneos** (versión posterior a la 7.0): los organiza Muse conectada a la
app — Muse crea los torneos, pone cientos/miles de preguntas nuevas,
reparte los premios y añade animaciones nuevas. Hueco previsto: futura
colección `tournaments` con `id`, `título`, `tema`, `fechas`, `preguntas`,
`premio`. Sin pantallas ni lógica de torneos en esta entrega.

## Tests

`flutter test` — todo con fakes en memoria, sin Firebase real:

- `test/auth_gate_test.dart`: puerta de auth (entra admin listado /
  rechaza no listado / adopta invitación por correo).
- `test/owner_bootstrap_test.dart`: el dueño entra directo con `admins`
  vacía y se crea su documento; otra cuenta no entra; el dueño agrega a
  otro admin y ese entra con sus permisos.
- `test/users_test.dart`: lista de usuarios, ban y quitar baneo.
- `test/permissions_test.dart`: matriz de permisos completa.
- `test/settings_test.dart`: lectura y guardado de ajustes remotos.
- `test/support_test.dart`: bandeja de soporte (abiertos primero),
  responder guarda la respuesta y cambia el estado, número de WhatsApp e
  interruptor se guardan y se leen (también desde la UI).
- `test/preview_test.dart`: genera los previews en
  `~/workspace/quemia-admin-previews/` (`panel.png`, `estadisticas.png`,
  `usuarios.png`, `detalle_usuario.png`, `administradores.png`,
  `ajustes.png`, `avisos.png`, `editor.png`, `reportes.png`,
  `soporte.png`). **NO se corre con `flutter test test/preview_test.dart` directamente**: en este
  VM `RenderRepaintBoundary.toImage()` dentro de un widget test deja el
  test colgado al cerrarse (el PNG ya está escrito en <1 s, pero el runner
  nunca recibe "test completado"; ni `image.dispose()` lo evita — es un
  quirk del `flutter_tester` aquí, no de la app). Se generan con
  `./preview.sh`, que corre cada preview en su propio proceso y lo mata en
  cuanto su PNG existe. El test usa pumps acotados (3 × 100 ms) en vez de
  `pumpAndSettle`, porque los fakes completan en el acto. Dos quirks más
  del mismo entorno, ya diagnosticados: (1) el IO asíncrono
  (`Directory.create`, `File.writeAsBytes`) se queda colgado dentro del
  `flutter_tester`, así que el test escribe con IO síncrono
  (`createSync`/`writeAsBytesSync`); (2) cada pantalla se envuelve en un
  `Scaffold` (como hace `HomeShell` en la app real): sin él, `Usuarios`
  se rompía con "No Material widget found" por su `TextField` de
  búsqueda. Y un artefacto SOLO del rasterizador de test: el texto sin
  color explícito se ve rojo en los PNG (la fuente de test no tiene
  Roboto); el tema está verificado correcto (texto oscuro) y los colores
  explícitos (teal, gris, azul) salen bien — en el teléfono la app se ve
  con sus colores reales. Los previews sirven para verificar layout,
  espaciado, tarjetas y desbordes.
- `test/offline_test.dart`: sin conexión (Firestore falso que falla) cada
  pantalla muestra el estado tranquilo *"Sin conexión"* + Reintentar.
- `test/stats_test.dart`: estadísticas con los 12 usuarios de ejemplo.
- `test/announcements_test.dart`: envío de avisos y permisos.
- `test/editor_test.dart`: validación del editor y guardado en el nivel.
- `test/reports_test.dart`: lista de reportes y marcar como arreglado.

Los previews del Panel y de Usuarios usan los mismos 12 usuarios falsos
realistas (kristian, laura, miguel, sofia, daniel, valeria, pedro,
camila, yordanis, lucia, andres, rosa) y las estadísticas se calculan de
esos datos.

## Qué NO está probado con fakes (informe honesto)

Los tests usan fakes en memoria, así que hay cosas de lo online que NO se
pueden dar por buenas aquí y hay que probarlas en el teléfono con el APK:

- **Firestore real**: latencia, timeouts reales de 20 s, reglas de
  Firestore (las de `firestore.rules` son una propuesta; D2 actualiza las
  que impiden escribir en el documento de otro), permisos del proyecto y
  que las colecciones `levels`, `announcements` y `reports` existan con
  los campos del contrato.
- **Inicio de sesión con Google** (`signInWithProvider`): el flujo por
  navegador y la puerta de auth solo se pueden probar con la cuenta real
  y el `google-services.json` definitivo instalado.
- **La app principal leyendo lo remoto**: que Quemia lea `settings/app`,
  `levels`, `announcements` y `reports` con fallback local es trabajo del
  agente de la app principal; esta app solo escribe y muestra esos datos.

## Dependencias Firebase (resueltas por `flutter pub get`)

- `firebase_core` ^5.1.0 (5.1.0)
- `cloud_firestore` ^7.1.0 (7.1.0)
- `firebase_auth` ^7.0.1 (7.0.1)

Sin plugin de inicio de sesión de Google, a propósito (ver "Inicio de
sesión").
