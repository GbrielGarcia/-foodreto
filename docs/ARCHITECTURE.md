# FoodReto — Arquitectura

> "Elige qué vas a comer, invita a tus amigos, cuenta cada bocado y compite por el récord."

Este documento cubre los puntos 1–8 de la forma de trabajo acordada: arquitectura,
carpetas, modelos, navegación, flujo de datos, Firebase, realtime y rankings.
Las decisiones marcadas con **Decisión** son las que condicionan el resto del diseño.

---

## 1. Arquitectura propuesta

Una sola base de código Flutter (Android, iOS, Web) + Firebase como backend.

```
┌──────────────────────── Flutter (cliente) ────────────────────────┐
│ Presentation  →  Widgets + Riverpod (Notifier / AsyncNotifier)    │
│ Domain        →  Entidades, contratos de Repository, UseCases     │
│ Data          →  Repository impl + DataSources (Firebase, local)  │
│ Core          →  Router, theme, errores, config, utilidades       │
└───────────────────────────────┬───────────────────────────────────┘
                                │ SDKs Firebase (Auth, Firestore, FCM…)
┌───────────────────────────────┴───────────────────────────────────┐
│ Firebase                                                          │
│  Auth · Firestore (+ Security Rules) · Storage · FCM · Analytics  │
│  Crashlytics · Cloud Functions (TypeScript) · Hosting (web + SEO) │
└───────────────────────────────────────────────────────────────────┘
```

Reglas de dependencia (Clean Architecture):

- `domain` no importa Flutter ni Firebase. Solo Dart puro.
- `data` implementa los contratos de `domain` y es la única capa que toca Firebase.
- `presentation` solo habla con UseCases/Repositories vía providers de Riverpod.
- Riverpod es el contenedor de inyección de dependencias: cada Repository se expone
  como `Provider` y se puede sobrescribir en tests (`ProviderScope(overrides: …)`).

Flujo de una acción:

```
Widget → Provider (Notifier) → UseCase → Repository (contrato) → RepositoryImpl → DataSource → Firebase
```

**Decisión — modo local sin Firebase.** Mientras no se ejecute `flutterfire configure`,
la app arranca en *modo local* con repositorios en memoria (mismos contratos). Esto
permite desarrollar la UI y correr tests sin backend. En cuanto existe configuración,
se usa Firebase automáticamente. También se puede forzar con
`--dart-define=FOODRETO_BACKEND=local`.

**Decisión — lógica crítica en el servidor.** El cliente nunca escribe resultados,
rankings, récords ni estadísticas. Solo escribe: su perfil, sus eventos de contador
(validados por reglas) y solicitudes (crear/unirse/finalizar) que ejecuta una Cloud Function.

---

## 2. Estructura de carpetas

```
foodreto/
├── lib/
│   ├── main.dart                 # Punto de entrada → bootstrap()
│   ├── firebase_options.dart     # Generado por `flutterfire configure`
│   ├── app/                      # MaterialApp.router, bootstrap, configuración de arranque
│   ├── core/
│   │   ├── config/               # AppConfig, BackendMode
│   │   ├── error/                # Failure, Result
│   │   ├── router/               # GoRouter, rutas, guard de auth
│   │   ├── theme/                # Colores, tipografía, espaciado, ThemeData
│   │   └── utils/                # Validadores, helpers puros
│   ├── shared/
│   │   └── widgets/              # Botones, inputs, layout adaptativo, estados vacíos
│   └── features/
│       ├── auth/            ├── home/          ├── profile/
│       ├── challenge/       ├── restaurant/    ├── category/
│       ├── leaderboard/     ├── friends/       ├── achievements/
│       ├── notifications/   └── settings/
│           (cada feature)
│           ├── domain/        entities/ repositories/ usecases/
│           ├── data/          datasources/ models/ repositories/
│           └── presentation/  providers/ pages/ widgets/
├── functions/                    # Cloud Functions (TypeScript) — desde la Fase 3
├── web/                          # index.html, manifest (PWA)
├── firebase.json · firestore.rules · firestore.indexes.json · storage.rules
├── docs/ARCHITECTURE.md
└── test/                         # Espejo de lib/ (unit + widget)
```

"Explorar" (mapa) vive en `features/restaurant/` porque su dominio son restaurantes.

---

## 3. Modelos (Firestore)

Convenciones: IDs como strings, fechas como `Timestamp` del servidor
(`FieldValue.serverTimestamp()`), claves normalizadas (`slug`, `cityKey`) para consultas.

| Colección | Escribe | Contenido |
|---|---|---|
| `users/{uid}` | dueño (campos limitados) | Perfil público |
| `users/{uid}/private/settings` | dueño | Preferencias, tokens FCM, privacidad |
| `usernames/{username}` | Function | `{uid}` — garantiza unicidad |
| `categories/{categoryId}` | admin / Function | Categorías del sistema y personalizadas |
| `restaurants/{restaurantId}` | Function | Restaurantes (deduplicados) |
| `inviteCodes/{code}` | Function | `{challengeId, expiresAt}` |
| `challenges/{challengeId}` | Function (+ owner campos limitados) | Reto |
| `challenges/{id}/participants/{uid}` | Function + participante (solo contador) | Participante |
| `challenges/{id}/events/{clientEventId}` | participante (create-only) | Eventos +1/−1 |
| `challengeResults/{challengeId_uid}` | Function | Resultado inmutable |
| `leaderboards/{scopeKey}` | Function | Resumen del ranking y récord actual |
| `leaderboards/{scopeKey}/entries/{uid}` | Function | Mejor marca del usuario en ese ámbito |
| `recordHistory/{id}` | Function | Evolución del récord |
| `friendships/{uidA_uidB}` | Function | Solicitudes y amistades |
| `userStats/{uid}` · `restaurantStats/{id}` | Function | Agregados |
| `achievements/{id}` · `users/{uid}/achievements/{id}` | admin / Function | Logros |
| `notifications/{uid}/items/{id}` | Function | Bandeja in-app |
| `reports/{id}` | usuario (create) / admin | Moderación |

Campos principales (los del brief, con los añadidos justificados):

- **User**: `id, username, displayName, avatarStyle, avatarSeed, avatarOptions (map), bio,
  visibility (public|private), createdAt, updatedAt`. El avatar se renderiza desde DiceBear
  a partir de estilo + semilla + opciones; no se guarda ninguna imagen.
- **Restaurant**: `id, name, normalizedName, address, city, cityKey, country (ISO-2),
  latitude, longitude, geohash, imageUrl, website, createdBy, createdAt, updatedAt`.
  `geohash` permite buscar candidatos cercanos para detectar duplicados y pintar el mapa.
- **FoodCategory**: `id (slug), name, slug, icon (emoji), defaultUnit, isSystemCategory,
  rankingEligible, createdBy, createdAt`. Las personalizadas nacen con
  `rankingEligible = false` hasta ser aprobadas.
- **Challenge**: `id, creatorId, name, categoryId, unitType, restaurantId, city, cityKey,
  country, type (competition|cooperative|personalGoal|logOnly), visibility
  (private|friends|public), targetAmount?, status (waiting|active|finished|cancelled),
  inviteCode, participantIds[], locationDetected (bool), createdAt, startedAt, finishedAt`.
  `participantIds` existe para Security Rules y para consultar "mis retos".
- **ChallengeParticipant**: `challengeId, userId, role (owner|participant|viewer),
  currentCount, lastEventId, status (joined|ready|left|removed), joinedAt` + copia de
  `displayName/username/avatar*` para pintar la sala sin leer N perfiles.
- **ChallengeEvent**: `id (= clientEventId), challengeId, userId, clientEventId,
  type (increment|decrement), amount (+1|−1), timestamp (cliente), syncedAt (servidor)`.
- **ChallengeResult**: `id, challengeId, userId, restaurantId, categoryId, unitType,
  cityKey, country, amount, rank, isPublic, status (active|removed), userSnapshot,
  createdAt`. Inmutable salvo `status` (moderación / borrado por el usuario).
- **LeaderboardEntry** (`leaderboards/{scopeKey}/entries/{uid}`): `userId, amount,
  challengeId, restaurantId, cityKey, achievedAt, userSnapshot`.
- **RecordHistory**: `id, scopeKey, restaurantId?, categoryId, userId, challengeId,
  amount, previousAmount, previousHolderIds[], createdAt`.
- **Report**: `id, userId, challengeId?, targetType, targetId, reason, createdAt, status
  (pending|reviewed|resolved|rejected)`.

El resto (`Friendship`, `Notification`, `UserStatistics`, `RestaurantStatistics`,
`Achievement`, `UserAchievement`) se detalla en la fase que los implementa.

---

## 4. Navegación

`go_router` con `StatefulShellRoute.indexedStack`: cada pestaña conserva su pila y su estado.

| Ruta | Pantalla | Auth |
|---|---|---|
| `/login`, `/register` | Autenticación | No |
| `/` | Inicio | Sí |
| `/rankings` | Rankings | Sí* |
| `/create` | Wizard de reto | Sí |
| `/explore` | Mapa | Sí* |
| `/profile` | Mi perfil | Sí |
| `/join/:code` | Unirse a reto (deep link) | Sí (redirige a login y vuelve) |
| `/challenge/:code` | Resultado público | No |
| `/restaurant/:slug`, `/category/:slug`, `/user/:username` | Páginas públicas | No |

\* En la Fase 9 las páginas de consulta se abren sin sesión para la web pública.

Navegación adaptativa:

- `< 600 px` → `NavigationBar` inferior (uso con una mano).
- `600–1199 px` → `NavigationRail` compacto.
- `≥ 1200 px` → `NavigationRail` extendido con etiquetas.

El guard de auth es una función pura (`authRedirect`) que decide la redirección según el
estado de sesión y la ruta; conserva el destino original en `?from=` (necesario para
que `/join/AB12CD` funcione aunque el usuario tenga que iniciar sesión antes).

---

## 5. Flujo de datos

- **Lecturas en vivo** (sala, contador, ranking abierto): `StreamProvider` sobre un
  `Stream` del Repository → snapshot listener de Firestore. Se cancelan al salir de la
  pantalla (`autoDispose`).
- **Lecturas puntuales** (perfil ajeno, página de restaurante): `FutureProvider` con caché
  de Firestore.
- **Acciones** (crear reto, finalizar): `AsyncNotifier` que llama al UseCase y expone
  `AsyncValue` para loading/error.
- **Errores**: los Repositories devuelven `Result<T>` (`Success` | `Err(Failure)`).
  Las excepciones de Firebase se traducen a `Failure` con mensaje en español dentro de
  `data/`; nunca llegan a los widgets.

---

## 6. Estrategia de Firebase

- **Auth**: email/contraseña en el MVP. Google y Apple Sign-In más adelante detrás del
  mismo `AuthRepository`.
- **Firestore**: persistencia offline activada (por defecto en móvil y habilitada
  explícitamente en web).
- **Cloud Functions (TypeScript, 2ª generación)**:
  - Callables: `createChallenge`, `joinChallenge`, `startChallenge`,
    `finishChallenge`, `setChallengeVisibility`, `createRestaurant`, `claimUsername`,
    `respondFriendRequest`, `deleteMyResult`.
  - Triggers: `onResultWritten` (rankings + récords + estadísticas + notificaciones),
    `onReportResolved` (moderación).
- **Security Rules**: denegar por defecto; cada colección abre solo lo imprescindible.
  Todo lo derivado (resultados, rankings, récords, estadísticas) es de solo lectura
  para el cliente.
- **Storage**: solo fotos de restaurantes (opcional); reglas por tamaño y tipo MIME.
- **FCM**: tokens en `users/{uid}/private/settings`; las envía siempre una Function.
- **Crashlytics** en Android/iOS (no tiene soporte web). **Analytics** en todas las plataformas.
- **Hosting**: sirve la web Flutter + `/.well-known/assetlinks.json` y
  `apple-app-site-association` para App Links / Universal Links.

**Decisión — sin Firebase Dynamic Links.** El servicio se apagó en 2025. Los enlaces
`https://foodreto.app/join/AB12CD` se resuelven con App Links (Android) y Universal Links
(iOS); si la app no está instalada, Hosting sirve la web.

**Decisión — invitaciones.** Código de 6 caracteres de un alfabeto sin ambiguos
(`ABCDEFGHJKMNPQRSTUVWXYZ23456789`, ~887 millones de combinaciones), generado por
`createChallenge` en una transacción contra `inviteCodes/` para garantizar unicidad.
Unirse requiere `joinChallenge` porque quien aún no participa no puede leer el reto.

**Decisión — ubicación.** Al iniciar el reto el cliente calcula la distancia al
restaurante y solo envía `locationDetected: true|false`. No se guarda la posición del
usuario. Como el cliente puede falsearla, la UI dice "📍 Ubicación detectada", nunca
"verificado". Hay un campo `trustLevel` reservado para niveles futuros.

---

## 7. Estrategia de realtime (contador)

Objetivo: el +1 se ve al instante, llega a los demás en ~1 s, funciona sin conexión y
nunca se cuenta dos veces.

```
Pulsar +1
  ├─ UI: 17 → 18 (estado optimista local, sin esperar a red)
  ├─ Outbox local (Drift): {clientEventId: uuid v4, amount: +1, ts, synced: false}
  └─ SyncService (en cuanto hay red), por cada evento pendiente:
       WriteBatch atómico:
         1. create challenges/{id}/events/{clientEventId}
         2. update participants/{uid}: currentCount += 1, lastEventId = clientEventId
       → OK: marcar synced
       → ya existía: marcar synced (era un reintento)
Otros participantes: snapshot listener en participants/ → ven 18
```

**Idempotencia.** El ID del documento de evento es el `clientEventId`. Las reglas solo
permiten *crear* eventos, nunca sobrescribirlos, y solo permiten cambiar `currentCount`
si en el mismo batch se crea un evento nuevo cuyo `amount` coincide con la diferencia
(`existsAfter` + `!exists`). Un reintento de un evento ya aplicado falla entero, así que
el contador no se duplica ni con reconexiones ni con dobles sincronizaciones.

**Validaciones en reglas:** el reto está `active`, el usuario es participante con rol
`owner` o `participant`, solo toca su propio documento, `amount ∈ {+1, −1}` y
`currentCount ≥ 0`.

**Fuente de verdad.** Al finalizar, `finishChallenge` recalcula cada total sumando los
eventos. El `currentCount` del participante es una proyección rápida para la UI; el
resultado oficial sale de los eventos.

**Estado visible.** El contador muestra `max(servidor, servidor + pendientes locales)`
y un indicador "Sincronizando… (3)" mientras el outbox tenga eventos. Si al finalizar
quedan eventos pendientes de algún participante, la Function espera un periodo de gracia
corto y la UI del owner lo avisa.

**Por qué un outbox propio además de la caché offline de Firestore:** da un contador
exacto de pendientes, reintentos controlados, el mismo comportamiento en web y tests
deterministas. Ambas capas son compatibles gracias a la idempotencia por ID.

Coste: 1 escritura de evento + 1 actualización por pulsación. No se lee nada al pulsar.

---

## 8. Estrategia de rankings y récords

**Ámbitos (scopeKey)** — una clave por combinación con sentido, siempre por categoría
(nunca se mezclan unidades):

```
restaurant:{restaurantId}:cat:{categoryId}
city:{country}:{cityKey}:cat:{categoryId}
country:{country}:cat:{categoryId}
global:cat:{categoryId}
```

**Entrada por usuario, no por resultado.** `leaderboards/{scopeKey}/entries/{uid}`
guarda la *mejor marca* de cada usuario en ese ámbito. Así un ranking es una sola
consulta paginada: `orderBy(amount desc).orderBy(achievedAt asc).limit(50)`.
Con N resultados, cada uno cuesta como máximo 4 escrituras de entrada, y las lecturas
no dependen del tamaño total.

**Mi posición** sin leer todo el ranking: consulta de agregación
`count(where amount > miMarca) + 1` (se factura ~1 lectura por cada 1000 entradas).

**Empates.** Ranking de competición (1, 1, 3): misma cantidad = misma posición y misma
medalla. `achievedAt` solo se usa para ordenar de forma estable dentro del empate, nunca
para decidir un ganador.

**Récord.** `leaderboards/{scopeKey}` guarda `topAmount` y `topHolderIds[]`.
`onResultWritten`, en una transacción por ámbito:

1. Actualiza la entrada del usuario si mejora su marca.
2. Si `amount > topAmount` → nuevo récord: crea `recordHistory`, sustituye los titulares
   y notifica a los anteriores ("🔥 ¡Te superaron!").
3. Si `amount == topAmount` → empate en el récord: añade titular (sin notificación de
   "superado").

**Elegibilidad para rankings públicos:** reto `finished` + visibilidad `public` +
restaurante y categoría identificados + categoría con `rankingEligible` + `unitType`
igual a la unidad por defecto de la categoría + el participante no ha desactivado la
opción "aparecer en rankings públicos" (por defecto activada; se avisa al unirse a un
reto público). Se aplica a los cuatro tipos de reto; en el cooperativo cuenta la cantidad
individual.

**Amigos.** Se consulta `global:cat:{categoryId}/entries` filtrando por los IDs de amigos
en bloques de 30 (`whereIn` sobre el ID de documento). Si las listas crecen mucho se
pasaría a fan-out por usuario.

**Moderación / borrado.** El resultado pasa a `status: removed` (nunca se borra el
histórico de récords). La Function recalcula la mejor marca de ese usuario en cada ámbito
a partir de sus resultados activos y, si era el titular, recalcula `topAmount`.

**Escala.** Nada se carga completo en memoria: todo ranking es paginado y todo agregado
se mantiene de forma incremental en Functions. Los índices compuestos se declaran en
`firestore.indexes.json` en la fase que los necesita.

---

## 9. Fase 2 — Perfil, @username, avatar, categorías y reglas

Esta sección documenta lo implementado en la Fase 2. Donde contradice lo anterior
(por ejemplo, quién escribe `usernames/`), manda esta sección; el resto sigue vigente.

### 9.1 Auth → perfil

- **Google Sign-In** detrás del mismo `AuthRepository` (`signInWithGoogle`,
  `supportsGoogleSignIn`). Web usa `signInWithPopup`; Android/iOS obtienen un ID token con
  `google_sign_in` 7 (`GoogleIdTokenSource`) y lo cambian por una credencial de Firebase.
  Cancelar no es un error (`AuthFailure.cancelled` → la UI no muestra nada). En modo local
  el botón no aparece.
- Tras autenticarse, el router consulta `profileStatusProvider`
  (`unknown | missing | complete`):

```
sin sesión ─► /login?from=…
sesión + perfil cargando ─► /splash?from=…
sesión + sin perfil ─► /onboarding?from=…   (elige @username y avatar)
sesión + perfil ─► destino original (?from=) o /
```

  `authRedirect` sigue siendo una función pura; `from` nunca puede apuntar a rutas de
  auth ni a `/onboarding` (evita bucles). `/join/:code` sobrevive a registro + onboarding.

### 9.2 Modelo de datos implementado

| Documento | Escribe | Lee | Campos |
|---|---|---|---|
| `users/{uid}` | dueño (transacción) | dueño | `uid, username, displayName, bio, avatarStyle, avatarSeed, avatarOptions, visibility, isActive, createdAt, updatedAt` |
| `users/{uid}/private/account` | dueño | dueño | `email, updatedAt` |
| `usernames/{username}` | dueño (misma transacción) | usuarios con sesión (`get`, no `list`) | `uid, createdAt` |
| `userStatistics/{uid}` | solo servidor | dueño | `challengeCount, recordCount, totalUnits, restaurantCount, updatedAt` |
| `categories/{slug}` | solo servidor / seed | público | `name, slug, icon, defaultUnit, order, isActive, isSystemCategory, rankingEligible, createdAt, updatedAt` |
| `restaurants/{id}` | solo servidor | público si `isActive` | `name, slug, normalizedName, city, country, address, description, imageUrl, categoryIds, latitude, longitude, isActive, createdAt, updatedAt` |

- **El correo no va en `users/{uid}`.** Ese documento será legible por otros usuarios
  cuando existan perfiles públicos; el email vive en `private/account` y las reglas exigen
  que coincida con `request.auth.token.email`.
- `userStatistics/{uid}` sustituye al `userStats/{uid}` de la §3. Si el documento no
  existe, la app muestra 0; nunca inventa cifras. Lo escribirán las Functions de las
  fases 5–7.
- `categories` usa el slug como ID de documento (`/category/sushi` → `categories/sushi`);
  el repositorio tiene un respaldo por campo `slug` por si se crean con ID automático.

### 9.3 @username

- Formato: 3–20 caracteres `[a-z0-9_]`. Se normaliza (trim, minúsculas, sin `@` inicial)
  antes de validar, comparar y guardar; se muestra siempre como `@username`.
  `Username.suggest()` propone uno a partir del nombre o del correo
  (`Gabriel Guamán` → `gabriel_guaman`).
- Casos de uso: `CheckUsernameAvailability` (valida el formato antes de ir a red),
  `CreateProfileWithUsername` (onboarding) y `UpdateProfile` / `UpdateUsername`.
  La UI solo habla con providers; nunca con Firestore.
- La disponibilidad en vivo (`usernameAvailabilityProvider`) espera 350 ms entre
  pulsaciones y distingue `Available | Taken | Owned (es el tuyo) | Invalid`. Es solo
  informativa: la garantía real está en la escritura.

**Decisión — unicidad sin Cloud Function.** En lugar del callable `claimUsername`
previsto en la §6, perfil e índice se escriben en **una transacción** de Firestore:

```
crear:   get users/{uid} (no debe tener perfil)
         get usernames/{name} (libre o ya mío)
         set usernames/{name} = {uid, createdAt}
         set users/{uid}
         set users/{uid}/private/account
cambiar: get usernames/{nuevo} → set usernames/{nuevo}
         delete usernames/{anterior}
         update users/{uid}.username
```

No es "comprobar y luego escribir": si dos clientes compiten, la transacción del segundo
se invalida (el documento que leyó cambió) y, al reintentar, ve el nombre ocupado. Además
las reglas lo hacen imposible aunque un cliente se salte el repositorio:

- `usernames/{name}` nunca se actualiza (`update: false`): si existe, está ocupado.
- Crear la reserva exige que `getAfter(users/{uid}).username == name`, y crear o cambiar
  el perfil exige que `getAfter(usernames/{name}).uid == uid`. Uno no se puede escribir
  sin el otro.
- Cambiar de username exige `!existsAfter(usernames/{anterior})`: no se pueden acaparar
  nombres.
- Solo el dueño puede borrar su reserva y solo si ya no la usa.

Los tests de reglas (`tool/rules_test`) incluyen dos usuarios reservando el mismo nombre
a la vez: siempre gana exactamente uno y el otro no queda con un perfil a medias.

### 9.4 Avatar DiceBear

- Se guarda la configuración, nunca una imagen: `avatarStyle`, `avatarSeed`,
  `avatarOptions` (hoy solo `backgroundColor`). `AvatarConfig` sanea lo que viene de
  Firestore (estilo desconocido → `adventurer`, semilla inválida → `foodreto`, opciones
  fuera de la lista blanca descartadas) y las reglas validan lo mismo.
- URL: `https://api.dicebear.com/10.x/{style}/svg?seed=…&backgroundColor=…`. La versión
  está **fijada** (`DiceBear.apiVersion`) para que el mismo avatar se vea igual en todas
  las plataformas y en el futuro.
- Estilos ofrecidos: adventurer, avataaars, big-smile, fun-emoji, lorelei, micah,
  notionists, open-peeps, pixel-art, thumbs. `bottts` se excluye porque usa filtros SVG
  que `flutter_svg` no pinta.
- `UserAvatar` renderiza con `flutter_svg` (placeholder mientras carga, fallback 🙂 si
  falla) y admite `Hero`. En tests se desactiva la red con `avatarNetworkEnabledProvider`.
- Selector (`showAvatarPicker`): bottom sheet en móvil, diálogo en ≥ 600 px. Vista previa,
  "Generar otro", estilos, colores de la paleta, galería de semillas y semilla manual.

### 9.5 Categorías y restaurantes

- `CategoryRepository` (`getCategories`, `getCategoryBySlug`) con implementación
  Firestore (ordenada por `order`, solo activas) y en memoria (modo local, usa
  `devCategorySeed`).
- `UnitType`: units, pieces, portions, plates, glasses, bottles, rounds, orders, custom
  (con singular/plural en español). Una unidad desconocida cae a `units`.
- `RestaurantRepository` (`getById`, `getBySlug`, `searchByName` por prefijo de
  `normalizedName`). Aún sin mapa ni alta de restaurantes; la búsqueda usa el índice
  compuesto `restaurants(isActive, normalizedName)` de `firestore.indexes.json`.
- Catálogo inicial (`tool/seed/categories.json`): Alitas, Sushi, Pizza, Hamburguesas,
  Tacos, Pollo, Hot Dogs, Postres, Donas, Parrillada. Un test comprueba que coincide con
  `devCategorySeed`.

**Seed controlado.** La app nunca inserta datos. `tool/seed/seed_categories.mjs`
(Node 18+, sin dependencias) escribe por la API REST con credenciales de administrador
(emulador, cuenta de servicio o token OAuth), es idempotente (no toca `createdAt`) y
tiene `--dry-run`. Ver README.

### 9.6 Providers

| Provider | Tipo | Uso |
|---|---|---|
| `currentUserProvider` | `Provider<AuthUser?>` | Usuario autenticado |
| `profileRepositoryProvider`, `userStatisticsRepositoryProvider` | `Provider` | Firestore o memoria según `AppConfig` |
| `currentUserProfileProvider` | `StreamProvider<UserProfile?>` | Perfil propio en vivo |
| `userStatisticsProvider` | `StreamProvider` | Estadísticas (0 si no hay doc) |
| `profileStatusProvider` | `Provider<ProfileStatus>` | Guard de onboarding |
| `usernameAvailabilityProvider` | `FutureProvider.autoDispose.family` | Disponibilidad con debounce |
| `onboardingControllerProvider`, `editProfileControllerProvider` | `Notifier` | Guardar con estado `idle / saving / saved / error` |
| `categoryRepositoryProvider`, `categoriesProvider`, `categoryProvider(slug)` | | Catálogo |
| `restaurantRepositoryProvider`, `restaurantProvider(id)`, `restaurantSearchProvider(q)` | | Restaurantes |

### 9.7 Rutas y navegación

| Ruta | Pantalla |
|---|---|
| `/onboarding` | Crear perfil (@username + avatar) |
| `/` | Inicio: "¿Qué vas a comer hoy?", crear / unirse, retos activos, categorías, cerca de ti, récords, explorar |
| `/categories` | Todas las categorías con búsqueda |
| `/category/:slug` | Detalle: unidad, récord, ranking, restaurantes y retos públicos (vacíos hasta que existan datos) |
| `/explore`, `/challenges`, `/rankings` | Pestañas Explorar, Retos, Ranking |
| `/profile`, `/profile/edit` | Mi perfil y edición (solo el propio) |
| `/join/:code`, `/create` | Sin cambios de la Fase 1 |

Pestañas: Inicio · Explorar · Retos · Ranking · Perfil. `NavigationBar` en < 600 px y
`NavigationRail` en tablet/escritorio (extendido desde 1200 px). `/categories` y
`/category/:slug` cuelgan de la rama Inicio y `/profile/edit` de Perfil, así que cada
pestaña conserva su pila.

### 9.8 Security Rules (desplegadas)

Denegar por defecto; sin reglas temporales `request.time < …`. Resumen:

- `users/{uid}`: solo el dueño lee y escribe. Claves exactas (`hasOnly` + `hasAll`),
  tipos, longitudes (`displayName` ≤ 40 y no vacío, `bio` ≤ 160), avatar en lista blanca,
  `createdAt`/`updatedAt == request.time`. `uid`, `isActive`, `visibility` y `createdAt`
  no se pueden cambiar desde el cliente. Borrar: nunca.
- `usernames/{name}`: ver §9.3.
- `userStatistics`, `categories`, `restaurants`: el cliente no escribe nunca.
  Categorías de lectura pública; restaurantes solo si `isActive == true`.
- Todo lo demás (retos, resultados, rankings, récords…) sigue cerrado hasta su fase.

Tests: `cd tool/rules_test && npm install && npm test` (arranca el emulador de Firestore;
necesita Java 21+).

### 9.9 Tests añadidos

Username (validación, minúsculas, sugerencias), casos de uso de perfil (disponibilidad,
unicidad, cambio de username), `FirestoreProfileRepository` sobre `fake_cloud_firestore`
(transacciones, correo privado, estadísticas a 0), `AvatarConfig` y URL de DiceBear,
parseo y repositorio de categorías, seed, restaurantes y normalización de texto, redirect
de onboarding, cancelación de Google, flujos de widget auth → onboarding → perfil →
editar, inicio → categorías → detalle, búsqueda, y un barrido responsive
(320–1440 px) de todas las rutas comprobando que no hay overflow.

### 9.10 Pendiente para fases siguientes

- Drift (outbox offline) llega con el contador en la Fase 4.
- Perfiles públicos (`/user/:username`): abrir `get` de `users/{uid}` a otros usuarios.
- Estadísticas, récords y rankings reales: Functions de las fases 5–7.

---

## 10. Fase 3 — Challenges

Sala de reto completa: crear, unirse por código / `/join/:code`, lobby en vivo,
contador ±1, finalizar con resultado e historial básico. Sin Drift, sin Functions
complejas, sin rankings ni amistades.

### 10.1 Modelos

| Colección | Rol |
|---|---|
| `challenges/{id}` | Reto: host, categoría, restaurante?, título, visibilidad, status, `maxParticipants` (1–8), `participantIds`, timestamps |
| `challenges/{id}/participants/{uid}` | Snapshot del perfil + `role`, `currentCount`, `lastEventId` |
| `challenges/{id}/events/{clientEventId}` | Evento create-only: `type` increment/decrement, `amount: 1`, `userId` |
| `inviteCodes/{code}` | Reserva del código → `challengeId` (create-only) |
| `challengeResults/{id}` | Resultado inmutable al finalizar (copia de contadores) |

Estados: `draft → waiting → active → finished`, y desde draft/waiting/active →
`cancelled`. En esta fase el formulario es el borrador: se persiste directo en
`waiting`. Visibilidad `friends` existe en el modelo pero la UI no la ofrece.

### 10.2 Código de invitación

6 caracteres del alfabeto `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (sin 0/O/1/I/L).
Se reserva en la misma transacción que crea el reto; si choca, el repo reintenta
con otro código (hasta 5). Entrada: normaliza mayúsculas, espacios y guiones.

### 10.3 Realtime

Solo listeners de Firestore (sin Realtime Database, sin polling):

- `watchChallenge(id)` — estado de la sala
- `watchParticipants(id)` — marcador y lobby
- `watchResult(id)` — pantalla de resultado
- `watchUserChallenges(uid)` — historial (`participantIds arrayContains`, limit 50)

Al pasar a `active` / `finished` todos los clientes cambian de pantalla solos.

### 10.4 Contador e idempotencia

Cada ±1 es un `WriteBatch`: `set events/{clientEventId}` +
`update participant { currentCount: increment(±1), lastEventId }`.
No es transacción a propósito: la caché local aplica el batch al instante
(latency compensation). El `clientEventId` (20 alfanuméricos) lo genera el
cliente; un reintento con el mismo id es create → update y las reglas lo
rechazan. `currentCount` nunca baja de 0. Fuente de verdad verificable:
`tallyEvents(events)`.

### 10.5 Unirse y finalizar

- Unirse: transacción `participantIds = old + [uid]` + create participante.
  Las reglas exigen igualdad exacta y `size ≤ maxParticipants` → seguro bajo
  carrera por el último cupo.
- Finalizar: el host lee contadores en transacción, escribe `finished` +
  `challengeResults/{id}`. Si un +1 entra entre lectura y commit, las reglas
  responden `permission-denied` y el repo reintenta. Ranking de competición
  (1, 1, 3); empates comparten posición, sin desempate inventado.

### 10.6 Coste Firestore (decisiones)

| Acción | Escrituras | Lecturas extra |
|---|---|---|
| +1 / −1 | 2 (evento + participante) | 0 (el batch no lee) |
| Unirse / salir / start / cancel | 1–2 en transacción | 1 (reto) |
| Finalizar | 2 (reto + resultado) | 1 + N participantes |
| Listeners abiertos | — | 1 stream por reto / participantes / resultado |

No se duplica el marcador en el documento del reto (evita writes de todos
contra el mismo doc). Historial sin índice compuesto (filtro + sort en cliente).

### 10.7 Security Rules (resumen)

Se mantienen las de Fase 2. Añadidas: create de reto exigiendo código reservado
+ participante host; join/leave/start/finish/cancel acotados; eventos create-only
ligados al contador; resultado create-only con conteos exactos (hasta 8
desenrollados); A no escribe eventos de B; no-host no inicia; resultado no se
actualiza. Tests: `tool/rules_test` (54 casos, incl. concurrencia y realtime
A/B/C). **No desplegado a producción en esta fase.**

### 10.8 Modo emulador (opcional)

`flutter run -d emulator-5554` **sin** `FOODRETO_BACKEND=emulator` usa Firebase
**real** (`projectId: foodreto`). El Android Emulator solo es el dispositivo.

El Firebase Emulator Suite es opcional (`FOODRETO_BACKEND=emulator` + seed a
`demo-foodreto`). Un seed con `FIRESTORE_EMULATOR_HOST` no rellena producción.

### 10.9 Qué NO entra (a propósito)

Rankings, récords, amigos, feed, torneos, Functions complejas, Dynamic Links,
SHA-256 / App Links productivos, release. (Drift / outbox → §11.)

---

## 11. Fase 4 — Persistencia local y Offline

### 11.1 Separación de responsabilidades

| Capa | Rol |
|---|---|
| **Firestore** | Backend remoto compartido (retos, participantes, eventos, resultados) |
| **Drift (SQLite)** | Persistencia local: caché de sala + **event outbox** del contador |

Drift **no** sustituye Firestore ni las Security Rules. El cliente no puede
“saltarse” reglas escribiendo en Drift: la sincronización vuelve a pasar por
el mismo `WriteBatch` remoto autenticado.

### 11.2 Tablas

- `event_outbox_entries` — cola (`clientEventId`, challenge, user, type, amount,
  status pending/syncing/synced/failed, attempts, lastError, timestamps)
- `challenges_local` — caché del reto para lectura offline
- `participants_local` — caché del marcador para lectura offline

Los eventos `synced` se eliminan tras confirmarse (no se acumulan).

### 11.3 Flujo del contador (offline-first)

```
UI (+1 / −1)
  → RecordCounterEvent (genera clientEventId una sola vez)
  → OfflineChallengeEventRepository
       1. enqueue en Drift (InsertOrIgnore por clientEventId)
       2. EventSyncService.flush() si hay señal de red
  → FirestoreChallengeEventRepository.recordEvent (WriteBatch)
```

La UI muestra `currentCount remoto + pendingDelta(outbox)` para feedback
inmediato sin esperar a Firestore.

### 11.4 Sincronización y reintentos

`EventSyncService`:

1. Al arrancar: `recoverStaleSyncing` (syncing antiguo → pending)
2. Procesa pendientes **en orden** `createdAt`, `localId`
3. Solo eventos del `currentUserId` (nunca mezcla cuentas)
4. Marca syncing → escribe remoto → synced (purge) o failed
5. Backoff corto entre fallos; `maxAttempts` acota reintentos agresivos
6. `connectivity_plus` es **señal** para intentar sync, no garantía de Firebase

### 11.5 Idempotencia

`clientEventId` se genera en el caso de uso y **no** se regenera en reintentos.
Firestore: create-only de `events/{clientEventId}` → reintento idempotente.

### 11.6 Realtime

Listeners Firestore se mantienen. Al emitir, se actualiza la caché Drift.
Si el stream falla (sin red / permission), se sirve el último snapshot local.

Categorías **no** se duplican en Drift (siguen en Firestore real).

### 11.7 Online-only (sin outbox)

Crear / unirse / iniciar / finalizar / cancelar siguen yendo directo a Firestore.
Solo el ±1 del contador usa outbox.

### 11.8 Arranque

Firebase → Drift (`AppDatabase` vía Riverpod) → recuperar `syncing` → iniciar
`EventSyncService` → listeners + flush de pendientes. Sin bloquear el primer frame.

---



## 12. Fase 5 — Resultados, Records y Rankings

### 12.1 Flujo oficial

```
Challenge (active)
  → Events (contador, offline-first Fase 4)
  → Host finish (transacción + challengeResults/{id})  [cliente, reglas isExactResult]
  → Cliente Spark: FirestoreOfficialResultApplier (OfficialResultProcessor Dart)
       → resultProcessing ledger (idempotencia)
       → userStatistics
       → leaderboards/{scopeKey} + entries/{uid}
       → recordHistory
       → activities / notifications oficiales
       → challengeResults.processingStatus = official
  → (Futuro Blaze) Cloud Function onChallengeResultCreated (Admin SDK) — mismo efecto
```

Firestore = fuente oficial de rankings/records.  
Drift = sin tablas nuevas en Fase 5 (solo cache/outbox de Fase 4).

**Modo Spark (actual):** el host materializa stats tras `finish` y al abrir
Rankings se hace backfill de `challengeResults` pendientes. Las Rules permiten
esas escrituras solo si el firmante es host del reto finalizado.

**Modo Blaze (opcional):** Functions con Admin SDK; más a prueba de trampas.
El código TypeScript se mantiene para cuando se active Blaze; no es obligatorio.

### 12.2 Resultado oficial

Documento existente `challengeResults/{challengeId}` (create del host; update
limitado de campos oficiales).

Campos oficiales (merge):

- `processingStatus`: pending | processing | official | failed
- `winnerIds[]` (empates soportados)
- `totalUnits`
- `officialAt`

UI de sala usa standings locales; un resultado solo se trata como récord/ranking
oficial cuando `processingStatus == official`.

### 12.3 Métrica de ranking

1. `amount` = mejor score oficial del usuario en el ámbito  
2. Desempate: `wins` (victorias en posición 1, empates cuentan)  
3. Desempate técnico: `achievedAt` ASC  

Scopes Fase 5:

- `global`
- `global:cat:{categoryId}`
- `restaurant:{restaurantId}:cat:{categoryId}`

(Ciudad/país preparados en §8, no materializados aún.)

### 12.4 Records e historial

- Actual: `leaderboards/{scopeKey}` → `topAmount`, `topHolders[]`
- Historial: `recordHistory/{id}` → created | tied | broken  
- Empate: se añaden holders; no se borra el historial previo  
- Hints `notificationHint` / `notificationHints` listos para FCM (fase posterior)

### 12.5 Idempotencia y reproceso

Ledger `resultProcessing/{challengeId}` con `contentHash` de participantes/scores.  
Mismo hash → skip. Callable `reprocessChallengeResult` borra ledger y reaplica.

### 12.6 Seguridad

**Spark:** create/update de `leaderboards`, `entries`, `userStatistics`,
`recordHistory`, `resultProcessing`, activities/notifications oficiales y
update de `challengeResults` (campos oficiales) restringidos al **host** del
reto `finished`. No es equivalente a Admin SDK.

**Blaze (futuro):** solo Admin SDK escribe; cliente `write: if false` otra vez.

Cliente puede leer (auth): leaderboards, entries, recordHistory, categoryStats (get).

### 12.7 UI

- `/rankings`: global + por categoría, puesto personal  
- Perfil: retos / victorias / mejor score / récords  
- Home: acceso a rankings + preview de récords  

### 12.8 Deploy

Código Functions + rules + indexes preparados.  
**No desplegados** en Fase 5 (requiere autorización explícita).




## 13. Fase 6 — Social

### 13.1 Flujo

```
User / Profile (users/{uid})
  → Search (username exacto + prefijos públicos)
  → Friend Request (friendships/{low_high}, status=pending)
  → Friendship (accepted)
  → Friends Ranking (leaderboard entries whereIn amigos)
  → Challenge Invitation (challengeInvitations/{challengeId_toUid})
```

### 13.2 Colecciones

- `friendships/{minUid_maxUid}` — `userIds[]`, requester/addressee, status, snapshots
- `challengeInvitations/{challengeId_toUid}` — pending/accepted/rejected/expired

### 13.3 Privacidad

- `ProfileVisibility.public|private` editable en perfil
- Lectura de `users/{uid}` y `userStatistics/{uid}` para terceros solo si público
- Email sigue en `users/{uid}/private/account`

### 13.4 Ranking de amigos

Reutiliza métrica Fase 5 (`amount`, `wins`, `achievedAt`) vía
`getEntriesByUserIds` sobre el scope global/categoría. No hay segunda métrica.

### 13.5 Retos

- `ChallengeVisibility.friends` habilitado en create
- Lobby: invitaciones internas a amigos (sin FCM)

### 13.6 Drift

Sin cache social. Firestore es la fuente oficial.

### 13.7 Deploys pendientes (no ejecutados)

- Firestore Rules (perfiles públicos, friendships, invitations)
- Firestore Indexes (búsqueda + friendships + invitations)
- Cloud Functions de Fase 5 siguen pendientes; Fase 6 no añade Functions obligatorias


## 14. Fase 7 — Feed + Actividad Social

### 14.1 Objetivo

Capa social de actividades derivadas de hechos reales (retos, victorias,
récords, uniones), consumible como feed personal + actividad pública relevante.
Sin likes, comentarios, FCM ni publicaciones manuales.

### 14.2 Modelo

`SocialActivity` (`lib/features/activity/`):

- `type`: `challengeCompleted` | `challengeWon` | `recordCreated` |
  `recordBroken` | `friendJoinedChallenge`
- Actor (uid, username, displayName, avatar DiceBear)
- Contexto opcional: challengeId, categoryId/name/icon, restaurantId/name, score
- `visibility`: `public` | `friends` (retos `private` **no** generan actividad)
- `createdAt`

### 14.3 Colección e IDs

`activities/{challengeId}_{userId}_{type}` — ID determinístico / idempotente.

### 14.4 Origen de escritura

| Tipo | Quién escribe |
|---|---|
| Completó / ganó / récord | Cloud Functions (`onChallengeResultCreated`) vía Admin SDK |
| `friendJoinedChallenge` | Cliente en la misma tx de `join` (rules estrictas) |

El cliente **no** puede crear ni mutar actividades oficiales.
`FirestoreActivityRepository.upsertOfficialActivities` es no-op.

Modo local: `InMemoryChallengeBackend` + `OfficialActivityBuilder` +
`InMemoryActivityRepository`.

### 14.5 Feed

- Consulta A: `actorUserId in [viewer + ≤29 amigos]` orderBy `createdAt DESC`, `__name__`
- Consulta B: `visibility == public` mismo orden
- Merge + dedupe por id en cliente (`FeedMerger`)
- Cursor compuesto `createdAtMs_id`
- Tope amigos: 29 (+ viewer = 30, límite `in` de Firestore)

UI: sección **Actividad** en Home + ruta `/feed` (fuera del shell).

### 14.6 Privacidad

- Perfil privado → actividades como máximo `friends`
- Reto private → sin actividad de feed
- Rules: lectura si actor, `public`, o `friends` + amistad accepted

### 14.7 Pendiente de deploy

- Functions (escritura oficial de activities)
- Rules + indexes de `activities`
- FCM / likes / comentarios → fases posteriores (antes el plan listaba FCM como Fase 7; FCM queda aplazado)


## 15. Fase 8 — Notificaciones + Centro de Actividad

### 15.1 Objetivo

Centro de notificaciones **in-app** independiente de `SocialActivity`.
Informa de amistad, invitaciones, resultados y records sin FCM obligatorio.

### 15.2 Modelo

`AppNotification` (`lib/features/notifications/`):

- `recipientUserId`, `type`, actor snapshot, `title`, `body`, `read`, `createdAt`
- Opcionales: `challengeId`, `activityId`, `recordId`, `targetRoute`, categoria

`NotificationType`: friendRequest, friendRequestAccepted, challengeInvitation,
friendJoinedChallenge, challengeCompleted, challengeWon, recordCreated, recordBroken.

### 15.3 Coleccion e IDs

`notifications/{id}` plano (no subcoleccion por uid).

IDs deterministas, p.ej. `friendRequest_{fid}`, `challengeWon_{challengeId}_{uid}`.

### 15.4 Escritura

| Evento | Origen |
|---|---|
| Resultado / victoria / record | `applyOfficialResult` (Admin) |
| Solicitud / aceptacion | `onFriendshipWritten` |
| Invitacion a reto | `onChallengeInvitationCreated` |
| Amigo se une | `onFriendJoinedActivityCreated` |

Cliente: **solo** `update` del campo `read` en notificaciones propias.

### 15.5 Lectura / UI

- Lista paginada: `recipientUserId == me` orderBy `createdAt DESC`, `__name__`
- Unread: stream/count `read == false` (realtime badge)
- Ruta `/notifications` + campana en Home (sin tocar bottom nav)
- Deep links via `NotificationDeepLink` / `targetRoute`

### 15.6 Realtime

- Contador unread: listener Firestore
- Lista: fetch paginado + pull-to-refresh (no listener infinito de toda la bandeja)

### 15.7 FCM

Preparacion documental. Token management / push real: **Pendiente Fase 8.1 / deploy posterior**.

### 15.8 Pendiente de deploy

- Functions (notificaciones + triggers sociales)
- Rules + indexes `notifications`
- FCM


## 16. Fase 9 — Explorar + Mapa + Restaurantes

### 16.1 Objetivo

Descubrir restaurantes, categorías, retos públicos, récords y actividad pública
desde `/explore`, sin duplicar Fases 2–8.

### 16.2 Modelo de restaurante

Colección existente `restaurants/{id}` (escritura administrativa, no cliente).

Campos relevantes:

| Campo | Notas |
|---|---|
| `id`, `name`, `slug`, `normalizedName` (`nameLower` alias) | Identidad y búsqueda |
| `description`, `address`, `imageUrl` | Opcionales |
| `city`, `country` | Ubicación administrativa |
| `latitude`, `longitude` | Coordenadas del **restaurante** |
| `categoryIds` | Relación con categorías oficiales |
| `isActive`, `createdAt`, `updatedAt` | Ciclo de vida |

No se persiste nunca la ubicación exacta del usuario.

### 16.3 MapProvider

Abstracción `MapProviderView` (capa restaurant).

**Proveedor elegido:** OpenStreetMap vía `flutter_map` + `latlong2`
(`FlutterOsmMapProvider`).

Motivos:

- Android / iOS / Web sin API key.
- No inventar claves Google/Mapbox.
- Attribution OSM en el widget.

Futuro: Google Maps / Mapbox detrás de la misma interfaz.

**Clustering:** documentado / preparado. Volumen actual = markers individuales.
Cuando haya densidad alta, añadir capa de clustering sin cambiar dominio.

### 16.4 Ubicación y permisos

- `LocationService` + `GeolocatorLocationService`.
- Permiso **solo** al pulsar «Usar ubicación» en Explorar (no al arrancar).
- Distancia Haversine local (`GeoDistance`); no se guarda en Firestore.
- Sin permiso: mapa con centro por defecto (`ExploreDefaults` ≈ Quito) o primer
  restaurante con coordenadas.
- Android: `ACCESS_COARSE/FINE_LOCATION`.
- iOS: `NSLocationWhenInUseUsageDescription`.
- Web: Geolocation API del navegador (geolocator_web).

### 16.5 UI / rutas

| Ruta | Página |
|---|---|
| `/explore` | `ExplorePage` (mapa + lista + búsqueda + filtros) |
| `/restaurant/:restaurantId` | `RestaurantDetailPage` |

Responsive: móvil mapa arriba / lista abajo; ≥900px dos columnas.

Detalle integra: categorías + récords (`restaurant:{id}:cat:{cat}`), ranking
oficial, retos públicos (`listPublicByRestaurant`), actividad pública
(`getRestaurantActivities`).

### 16.6 Búsqueda, filtros, paginación

- Debounce 350 ms en `ExploreController.setQuery`.
- Prefijo `normalizedName` + prefijo `city` (merge, sin N+1).
- Filtros: categoría, ciudad (provider), solo con ubicación (cliente).
- Paginación Firestore cursor (`getRestaurantsPage`).
- Búsqueda full-text avanzada: pendiente motor externo (no Algolia aún).

### 16.7 Rules / Indexes (preparados, sin deploy Fase 9)

Rules: `restaurants` read si `isActive`; write false (coords/admin protegidos).

Indexes añadidos en `firestore.indexes.json` (no desplegados en esta fase):

- `restaurants`: `isActive` + `createdAt`
- `restaurants`: `isActive` + `city` (+ `createdAt`)
- `restaurants`: `isActive` + `categoryIds` + `createdAt`
- `challenges`: `restaurantId` + `visibility` + `createdAt`
- `activities`: `restaurantId` + `visibility` + `createdAt` + `__name__`

### 16.8 Configuración mapa por plataforma

| Plataforma | Estado |
|---|---|
| Android / iOS / Web | OSM tiles (`tile.openstreetmap.org`) — sin key |
| Google Maps (futuro) | Requiere API key + Maps SDK (no configurado) |
| Mapbox (futuro) | Requiere access token (no configurado) |

Respetar ToS OSM / user-agent del paquete.

### 16.9 Pendientes

- Deploy Rules + Indexes.
- Seed/admin de restaurantes oficiales con coordenadas.
- Clustering real si el volumen lo exige.
- Motor de búsqueda si el prefijo Firestore no basta.
- Opcional: Google/Mapbox detrás de `MapProviderView`.

### 16.10 Fase 9.1 — Solicitudes de establecimiento + Super Admin

**Objetivo:** usuarios registran locales (`status=pending`); Super Admin aprueba,
rechaza, suspende, reactiva y transfiere ownership. Retos solo pueden elegir
locales `approved` / `isActive`.

**Modelo (`restaurants/{id}`):**

| Campo | Notas |
|---|---|
| `creatorUserId` | Inmutable (quien envió la solicitud) |
| `ownerUserId` | Responsable operativo; cambio solo vía callable admin |
| `status` | `pending` \| `approved` \| `rejected` \| `suspended` |
| `isActive` | Sincronizado: `true` solo si `approved` (compat queries públicas) |
| Auditoría | `approvedAt`, `rejectedAt`, `suspensionReason`, etc. |

**Repositorio (`RestaurantRepository`):** `createRequest`, `listMine`,
`listByStatus`, `updateOwnerFields`, `findPossibleDuplicates`.

**Cloud Functions (`functions/src/establishments.ts`):**

- Custom claim `superAdmin === true` (`setSuperAdminClaim` + env
  `BOOTSTRAP_SUPER_ADMIN_UID` para bootstrap).
- Callables: `approveEstablishment`, `rejectEstablishment`,
  `suspendEstablishment`, `reactivateEstablishment`,
  `transferEstablishmentOwnership` (idempotentes donde aplica).
- Colecciones server-only: `establishmentAuditLogs`,
  `establishmentOwnershipTransfers`.
- Notificaciones in-app: `establishmentApproved`, `establishmentRejected`,
  `establishmentTransferred`.

**Rules / Storage / Indexes:**

- `firestore.rules`: lectura pública si `approved` o legacy `isActive`; creator
  lee `pending`/`rejected`; owner lee el suyo; Super Admin lee todo; create
  cliente solo `pending`; update owner solo campos públicos (sin status/ownership).
- `storage.rules`: `establishments/{id}/cover/**` — lectura pública, escritura
  owner o Super Admin.
- Índices: `status+createdAt`, `creatorUserId+createdAt`, `ownerUserId+createdAt`,
  `normalizedName+city`.

**UI / rutas:**

| Ruta | Página |
|---|---|
| `/establishments/create` | `CreateEstablishmentPage` |
| `/establishments/mine` | `MyEstablishmentsPage` |
| `/admin/establishments` | `AdminEstablishmentsPage` (solo nav si claim) |
| `/admin/establishments/:id` | `AdminEstablishmentDetailPage` |

`isSuperAdminProvider` lee `IdTokenResult.claims`. Enlaces desde Explorar
(crear / mis locales / admin).

**Tests:** `establishment_phase91_test.dart`, `functions/test/establishments.test.ts`.

### 16.11 Fase 9.2 — Perfil publico del local + gestion del responsable

**Idea mejorada:** un establecimiento aprobado es una **ficha publica**
(contacto, redes, mapa, galeria, videos por enlace) + **ranking propio**
`restaurant:{id}:cat:{catId}` + retos hechos ahi. El responsable
(`ownerUserId`) administra solo su local; no puede cambiar status ni ownership.

**Decisiones de diseno:**

| Tema | Decision |
|---|---|
| Videos | Enlaces (YouTube/TikTok/Vimeo), no upload binario (costo Spark) |
| Imagenes | Portada + galeria via Storage (`cover/`, `gallery/`), max 5 MB, image/* |
| Contacto | `phone`, `whatsapp`, `websiteUrl`, redes |
| Ranking | Pagina `/restaurant/:id/ranking` (scope por categoria del local) |
| Super Admin | Custom claim; bootstrap `scripts/bootstrap_super_admin.mjs` (sin password) |

**Campos nuevos en `restaurants`:** `phone`, `whatsapp`, `websiteUrl`,
`instagramUrl`, `facebookUrl`, `tiktokUrl`, `galleryUrls[]`, `videoUrls[]`.

**UI:** `EditEstablishmentPage`, perfil enriquecido, ranking del local,
boton Gestionar en Mis establecimientos.

**Storage Rules:** cover + gallery; solo owner/superAdmin y local `approved`.


## Plan por fases

| Fase | Contenido | Estado |
|---|---|---|
| 1 | Flutter, Firebase bootstrap, arquitectura, routing, theme, auth | ✅ |
| 2 | Perfil, avatar DiceBear, Home, categorías (ver §9) | ✅ |
| 3 | Challenges: crear, unirse, lobby, contador, resultado (ver §10) | ✅ |
| 4 | Persistencia local Drift + outbox offline (ver §11) | ✅ |
| 5 | Resultados oficiales, records y rankings (ver §12) | ✅ |
| 6 | Social: perfiles públicos, amigos, invitaciones (ver §13) | ✅ |
| 7 | Feed + actividad social (ver §14); FCM aplazado | ✅ |
| 8 | Notificaciones in-app + centro (ver §15); mapa aplazado | ✅ |
| 9 | Explorar + mapa + restaurantes (ver §16) | ✅ |
| 9.1 | Admin establecimientos + Super Admin (ver §16.10) | ✅ (sin deploy Functions) |
| 9.2 | Perfil local + gestion owner (ver §16.11) | ✅ |
| 10 | Compartir, paginas publicas, SEO / FCM | |

## Poner Firebase en marcha

```bash
firebase login
flutterfire configure --project=<tu-proyecto> --platforms=android,ios,web
# Sobrescribe lib/firebase_options.dart; al reiniciar, la app deja el modo local.
```

En la consola de Firebase: activar Authentication → Email/Password.
