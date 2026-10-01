# FoodReto

> Come. Cuenta. Compite. Rompe récords.

**Idea by Alberto Guaman**

Plataforma social de retos gastronómicos (Flutter + Firebase) para Android, iOS y Web.
La arquitectura, los modelos y las estrategias de realtime y rankings están en
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Licencia

Puedes usar, modificar y distribuir este proyecto libremente bajo los términos de
[`LICENSE`](LICENSE), siempre que mantengas el crédito visible a **Alberto Guaman**
como creador de la idea.

## Requisitos

- Flutter 3.44+ (Dart 3.12+)
- iOS 15+ · Android minSdk de Flutter
- Firebase CLI y FlutterFire CLI (para conectar el backend)

## Firebase (credenciales locales)

**No subas** `google-services.json`, `GoogleService-Info.plist` ni `firebase_options.dart`
al repositorio. Están en `.gitignore`. En local:

```bash
flutterfire configure --project=foodreto
# o copia los archivos desde la consola de Firebase usando los `.example`
```

## Ejecutar

```bash
flutter pub get
flutter run -d emulator-5554   # Android Emulator → Firebase REAL (proyecto foodreto)
flutter run -d chrome          # web → Firebase REAL
```

`emulator-5554` es solo el **dispositivo Android virtual**. No es Firebase Emulator Suite.
Sin `--dart-define=FOODRETO_BACKEND=…`, la app usa `DefaultFirebaseOptions` → proyecto
**foodreto** (Auth + Firestore reales).

Modo local (repositorios en memoria, sin Firebase):

```bash
flutter run --dart-define=FOODRETO_BACKEND=local
```

### Opcional: Firebase Emulator Suite

Solo si quieres Auth/Firestore **locales** (banner "EMULADOR"). Es distinto del Android Emulator.
App y seed deben compartir el mismo `projectId` lógico `demo-foodreto`:

```bash
firebase emulators:start --only auth,firestore --project demo-foodreto
FIRESTORE_EMULATOR_HOST=localhost:8080 node tool/seed/seed_categories.mjs --project demo-foodreto
flutter run --dart-define=FOODRETO_BACKEND=emulator
# Android AVD: host por defecto 10.0.2.2; LAN: FOODRETO_EMULATOR_HOST=<ip>
```

**Importante:** un seed con `FIRESTORE_EMULATOR_HOST=…` **no** escribe en Firebase real.
Para el catálogo en producción hay que seedear el proyecto `foodreto` (ver más abajo).

## Conectar Firebase

```bash
firebase login
flutterfire configure --project=<id-del-proyecto> --platforms=android,ios,web
```

Después, en la consola de Firebase: **Authentication → Sign-in method → Email/Password**.
Las reglas (`firestore.rules`, `storage.rules`) niegan todo por defecto; se despliegan con
`firebase deploy --only firestore:rules,storage`.

### Google Sign-In

Activar **Authentication → Sign-in method → Google**. En Android, Google exige la huella
SHA-1 del certificado con el que se firma la app. La de depuración ya está registrada; para
la versión de la tienda hay que añadir la de release (y la de Play App Signing) y volver a
ejecutar `flutterfire configure`:

```bash
keytool -list -v -keystore <release.jks> -alias <alias>     # copiar SHA-1
firebase apps:android:sha:create <app-id-android> <SHA-1> --project foodreto
```

### Reglas e índices

```bash
firebase deploy --only firestore:rules,firestore:indexes --project foodreto
cd tool/rules_test && npm install && npm test   # tests de reglas en el emulador (Java 21+)
```

### Cargar categorías

La app **nunca** inserta el catálogo. Lectura pública; escritura solo por Admin SDK
(`tool/seed/seed_categories.mjs` + `categories.json`, idempotente).

```bash
# ❌ Esto NO carga Firebase real (escribe en Emulator Suite):
FIRESTORE_EMULATOR_HOST=localhost:8080 node tool/seed/seed_categories.mjs --project demo-foodreto

# ✅ Firebase REAL (proyecto foodreto) — NO ejecutar sin revisión:
# Dry-run primero:
FIRESTORE_ACCESS_TOKEN=$(gcloud auth print-access-token) \
  node tool/seed/seed_categories.mjs --project foodreto --dry-run

# Luego, si el dry-run lista las 10 categorías esperadas:
FIRESTORE_ACCESS_TOKEN=$(gcloud auth print-access-token) \
  node tool/seed/seed_categories.mjs --project foodreto

# Alternativa: cuenta de servicio (Consola → Cuentas de servicio → Generar clave)
# GOOGLE_APPLICATION_CREDENTIALS=~/foodreto-sa.json \
#   node tool/seed/seed_categories.mjs --project foodreto
```

Pollo debe quedar con el emoji **🐔**. No subas la clave de servicio al repositorio.

## Calidad

```bash
flutter analyze
flutter test
```
