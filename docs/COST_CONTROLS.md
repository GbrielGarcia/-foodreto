# Controles de costo — Functions + Maps

Objetivo: Blaze / Google Maps **sin** disparar consumo a lo loco.

## Cloud Functions (Blaze)

| Regla | Detalle |
| --- | --- |
| Triggers, no spam callables | Ranking: solo `onChallengeResultCreated` (1 vez por reto). Admin: callables raros. |
| Sin `minInstances` | Cold start OK; no pagar idle. |
| `maxInstances: 5`, `256MiB`, 60s | Tope de factura y memoria. |
| Region unica | `us-central1`. |
| Idempotencia | `resultProcessing` + contentHash → skips baratos. |
| Sin doble write | Cliente **no** materializa rankings ni notifs si `FOODRETO_CLOUD_FUNCTIONS=true` (default). |

### Flags Flutter

```bash
# Default: Functions ON
flutter run

# Volver a Spark cliente (sin Functions)
flutter run --dart-define=FOODRETO_CLOUD_FUNCTIONS=false
```

### Deploy

```bash
firebase deploy --only functions
```

Requiere plan **Blaze**. Free tier cubre uso bajo (invocaciones + GB-s).

## Google Maps (bajo consumo)

| Regla | Detalle |
| --- | --- |
| Solo Maps SDK | No Places, Directions, Geocoding, Static Maps extra. |
| Lite mode Android | Ficha de local (1 marker) = bitmap casi gratis. |
| Explorar | Sin traffic/buildings/toolbar/compass; zoom acotado. |
| Fallback OSM | Sin `GOOGLE_MAPS_API_KEY` → `flutter_map` OSM (\$0). |
| Un mapa visible | No embeds en listas / cards. |

### Activar Google Maps

1. Google Cloud Console → habilitar **Maps SDK for Android** + **Maps SDK for iOS**.
2. Restringir la key por app (package / bundle).
3. Android `android/local.properties`:

```properties
GOOGLE_MAPS_API_KEY=AIza...
```

4. iOS `Info.plist` → `GMSApiKey`.
5. Flutter:

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza...
```

Sin key nativa + dart-define, la app sigue en OSM.

## Que NO hacer

- Callables en cada scroll / heartbeat.
- `minInstances > 0` en Functions.
- Places Autocomplete en cada tecla.
- Varios `GoogleMap` en la misma pantalla lista.
- Cliente + Function escribiendo el mismo ranking (doble costo).
