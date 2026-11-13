# Referidos — modelo Firestore (Quemia 7.3)

> SOLO documentación y semilla. NO se ha publicado nada en
> Firestore: ni documentos ni reglas. Las reglas están en
> `firestore.rules` (repo) y hay que publicarlas a mano desde la
> consola cuando Kristian lo diga (igual que las reglas de la 7.0).

## Resumen del flujo

1. **Mi código**: cada usuario con Google vinculada reclama un
   código aleatorio de 6 caracteres (`referral_codes/<CÓDIGO>`).
   El código ES el id del documento: las reglas solo dejan
   crearlo si no existe (dos usuarios no pueden reclamar el
   mismo; al segundo le falla y prueba con otro).
2. **Canjear**: el amigo escribe el código en "Canjear código".
   Se crea `referrals/<autoId>` en estado `pending` y el
   invitado guarda `referredBy` en su documento. El premio NO
   se paga aquí.
3. **Nivel 1**: al pasar el Nivel 1 (cualquier tema), el
   invitado suma +20 puntos EN LOCAL y marca su referido como
   `rewarded`. La subida normal de progreso lleva los puntos a
   la nube.
4. **Cobro del invitador**: al abrir Invitar, el invitador lee
   sus referidos `rewarded` sin cobrar y se paga a sí mismo:
   +50 puntos (local), +1 al conteo y hitos si tocan, marcando
   `inviterRewarded: true`. Idempotente: un referido solo se
   cobra una vez. El invitado nunca escribe en el documento del
   invitador (las reglas lo prohíben): por eso el cobro es en
   dos pasos y lo hace el propio invitador.
5. **Hitos**: 3 referidos → avatar Embajador; 5 → tema
   Embajador + insignia Embajador; 10 → avatar Leyenda + 200
   puntos. Se regalan con `SocialService.grantItem` (sin
   descontar puntos) y se equipan desde la pantalla Invitar.
6. **Usernames únicos**: el nombre público (tabla, Amigos,
   avisos) es único. Se reserva en `usernames/<nombre>` (solo
   crear si no existe). Si choca, sufijo de 4 dígitos
   (Vanessa0394). El saludo ("Bienvenida Vanessa") NO cambia:
   sigue usando el nombre del onboarding.

## Colecciones

### `referral_codes/<CÓDIGO>` — un documento por código

| Campo | Tipo | Notas |
|---|---|---|
| `uid` | string | Uid del dueño del código |
| `createdAtMs` | int | ms desde epoch |
| `maxUses` | int | Siempre 10 (lo exigen las reglas) |

Los usos se CUENTAN desde `referrals` (cuántos documentos
tienen ese `code`): no hay contador aparte, para no pelear por
un campo que escribe otro usuario. `usesLeft = 10 - count`.

### `referrals/<autoId>` — un documento por canje

| Campo | Tipo | Notas |
|---|---|---|
| `code` | string | El código canjeado |
| `inviterUid` | string | Uid del dueño del código |
| `inviteeUid` | string | Uid del que canjeó |
| `inviteeUsername` | string | Nombre público único del invitado |
| `status` | string | `pending` → `rewarded` (al pasar el Nivel 1) |
| `inviterRewarded` | bool | false → true (al cobrar el invitador) |
| `createdAtMs` | int | ms desde epoch |
| `rewardedAtMs` | int | Solo cuando status = `rewarded` |

Lectura: invitador, invitado o admin. Escritura: solo el
invitado (crear + marcar `rewarded`) y el invitador (marcar
`inviterRewarded`). Nadie borra.

### `usernames/<nombre-en-minúsculas>` — reserva de nombres

| Campo | Tipo | Notas |
|---|---|---|
| `uid` | string | Uid del dueño del nombre |
| `createdAtMs` | int | ms desde epoch |

Solo crear si no existe. Nunca se actualiza ni se borra: si
un usuario cambia de nombre, el viejo queda reservado (evita
que otro lo coja y se haga pasar por él). La reserva es
best-effort en el cliente (sin transacciones en el repo); las
reglas son las que garantizan que no haya dos dueños.

### `users/<uid>` — campos nuevos de referidos

| Campo | Tipo | Notas |
|---|---|---|
| `referralCode` | string | Mi código (vacío = aún sin reclamar) |
| `referredBy` | string | Código que canjeé (vacío = ninguno) |
| `referredByUid` | string | Uid del que me invitó |
| `referralRewarded` | bool | true cuando cobré mis +20 |
| `referralsCount` | int | Referidos confirmados (cobrados) |
| `referralMilestones` | list[string] | Hitos concedidos: `['3', '5', '10']` |
| `referralLastInvitee` | string | Último amigo que se unió con mi código |
| `username` | string | Ahora es el nombre público ÚNICO (antes el del onboarding) |

Todos están en la lista blanca de `userWritableFields()` en
`firestore.rules`. La lectura de `users` ya era pública (tabla
de posiciones): estos campos no llevan datos sensibles.

### Tabla de los que más invitan

Consulta: `users` ordenados por `referralsCount` descendente,
límite 20, filtrando `referralsCount > 0` en el teléfono. No
necesita índice compuesto (un solo orden).

## Semilla: artículos de recompensa en `shop_items`

Publicar ESTOS 4 documentos en la colección `shop_items`
(doc id = `id`). Son `referralOnly: true`: la Tienda los
esconde y solo se consiguen por hitos. Las fotos de los dos
avatares ya están empaquetadas en la app
(`assets/avatar_embajador.png`, `assets/avatar_leyenda.png`),
así que `asset` manda sobre `imageUrl` (que queda en null).

```json
{
  "id": "avatar_embajador",
  "name": "Embajador",
  "kind": "avatar",
  "price": 0,
  "color": 4287323382,
  "asset": "assets/avatar_embajador.png",
  "description": "El embajador de Quemia. Solo se consigue invitando amigos.",
  "active": true,
  "sortOrder": 100,
  "referralOnly": true
}
```

```json
{
  "id": "theme_embajador",
  "name": "Embajador",
  "kind": "theme",
  "price": 0,
  "color": 4294286859,
  "description": "Dorado como un embajador. Solo invitando amigos.",
  "active": true,
  "sortOrder": 101,
  "referralOnly": true
}
```

```json
{
  "id": "badge_embajador",
  "name": "Embajador",
  "kind": "badge",
  "price": 0,
  "color": 4294952960,
  "badgeIcon": "trophy",
  "description": "Trofeo de embajador. Solo invitando amigos.",
  "active": true,
  "sortOrder": 102,
  "referralOnly": true
}
```

```json
{
  "id": "avatar_leyenda",
  "name": "Leyenda",
  "kind": "avatar",
  "price": 0,
  "color": 4294952960,
  "asset": "assets/avatar_leyenda.png",
  "description": "Una leyenda de la química. Solo los que invitan a 10 amigos.",
  "active": true,
  "sortOrder": 103,
  "referralOnly": true
}
```

Colores (ARGB int): `avatar_embajador` 0xFF8B5CF6 = 4287323382;
`theme_embajador` 0xFFF59E0B = 4294286859; `badge_embajador` y
`avatar_leyenda` 0xFFFFC800 = 4294952960. Los mismos valores
están en `lib/services/referral_rewards.dart` (fuente de
verdad en la app hasta que se publiquen).

## Pendiente (no código)

- [ ] Publicar las reglas de `firestore.rules` (sección
      referidos) desde la consola de Firebase.
- [ ] Publicar los 4 documentos de `shop_items` de arriba.
- [ ] Gestión en el Admin (entrada "Referidos" ya en el
      drawer, W3): quién invita a quién, detectar fakes
      (mismo dispositivo, códigos circulares), ver el estado
      de cada referido. Lee `referrals` + `users`
      (`referralsCount`, `referralMilestones`).
- [ ] Probar en dos teléfonos con Google vinculada: canjear,
      pasar el Nivel 1, cobrar +50 y ver el hito de 3.
- [ ] (Futuro) Cloud Function para pagar al invitador al
      instante y para reforzar la unicidad con transacción.
      Hoy el cobro lo hace el invitador al abrir Invitar.
