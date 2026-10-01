#!/usr/bin/env node
// Carga el catálogo de categorías (tool/seed/categories.json) en Firestore.
//
// Las reglas prohíben que los clientes escriban `categories`, así que el
// script usa la API REST con credenciales de administrador (IAM), que no pasa
// por las reglas. Es idempotente: vuelve a escribir los campos del catálogo
// sin tocar `createdAt` ni campos añadidos a mano. Nunca borra documentos.
//
// Uso (Node 18+, sin dependencias):
//   Emulador:
//     FIRESTORE_EMULATOR_HOST=localhost:8080 node tool/seed/seed_categories.mjs --project demo-foodreto
//   Producción con cuenta de servicio (JSON descargado de la consola):
//     GOOGLE_APPLICATION_CREDENTIALS=~/foodreto-sa.json node tool/seed/seed_categories.mjs --project foodreto
//   Producción con token OAuth (p. ej. `gcloud auth print-access-token`):
//     FIRESTORE_ACCESS_TOKEN=$(gcloud auth print-access-token) node tool/seed/seed_categories.mjs --project foodreto
//
// Opciones: --project <id> (obligatorio), --dry-run (muestra sin escribir).

import { createSign } from 'node:crypto';
import { readFileSync } from 'node:fs';

const args = process.argv.slice(2);
const flag = (name) => {
  const i = args.indexOf(name);
  return i === -1 ? undefined : args[i + 1];
};
const projectId = flag('--project');
const dryRun = args.includes('--dry-run');

if (!projectId) {
  console.error('Falta --project <id>. Ejemplo: --project demo-foodreto');
  process.exit(64);
}

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const base = emulatorHost
  ? `http://${emulatorHost}/v1`
  : 'https://firestore.googleapis.com/v1';
const database = `projects/${projectId}/databases/(default)`;

const categories = JSON.parse(
  readFileSync(new URL('./categories.json', import.meta.url), 'utf8'),
);
validate(categories);

const token = await accessToken();
let created = 0;
let updated = 0;

for (const category of categories) {
  const name = `${database}/documents/categories/${category.slug}`;
  const exists = await documentExists(name);
  const fields = {
    name: { stringValue: category.name },
    slug: { stringValue: category.slug },
    icon: { stringValue: category.icon },
    defaultUnit: { stringValue: category.defaultUnit },
    order: { integerValue: String(category.order) },
    isActive: { booleanValue: true },
    isSystemCategory: { booleanValue: true },
    rankingEligible: { booleanValue: true },
  };
  const transforms = [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }];
  if (!exists) {
    transforms.push({ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' });
  }

  console.log(`${exists ? 'actualizar' : 'crear     '} categories/${category.slug}`);
  if (dryRun) continue;

  await request('POST', `${base}/${database}/documents:commit`, {
    writes: [
      {
        update: { name, fields },
        updateMask: { fieldPaths: Object.keys(fields) },
        updateTransforms: transforms,
      },
    ],
  });
  exists ? updated++ : created++;
}

console.log(
  dryRun
    ? `Simulación: ${categories.length} categorías (sin escribir).`
    : `Listo en ${emulatorHost ? 'el emulador' : projectId}: ${created} creadas, ${updated} actualizadas.`,
);

function validate(list) {
  const units = new Set([
    'units', 'pieces', 'portions', 'plates', 'bowls', 'glasses',
    'bottles', 'rounds', 'orders', 'custom',
  ]);
  const slugs = new Set();
  for (const c of list) {
    const problems = [];
    if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(c.slug ?? '')) problems.push('slug');
    if (slugs.has(c.slug)) problems.push('slug duplicado');
    if (!c.name) problems.push('name');
    if (!c.icon) problems.push('icon');
    if (!units.has(c.defaultUnit)) problems.push('defaultUnit');
    if (!Number.isInteger(c.order)) problems.push('order');
    if (problems.length) {
      throw new Error(`Categoría inválida ${JSON.stringify(c)}: ${problems.join(', ')}`);
    }
    slugs.add(c.slug);
  }
}

async function documentExists(name) {
  const res = await fetch(`${base}/${name}`, { headers: headers() });
  if (res.status === 404) return false;
  if (!res.ok) throw new Error(`GET ${name}: ${res.status} ${await res.text()}`);
  return true;
}

async function request(method, url, body) {
  const res = await fetch(url, {
    method,
    headers: { ...headers(), 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`${method} ${url}: ${res.status} ${await res.text()}`);
  return res.json();
}

function headers() {
  return { Authorization: `Bearer ${token}` };
}

async function accessToken() {
  // El emulador acepta "owner" como credencial de administrador.
  if (emulatorHost) return 'owner';
  if (process.env.FIRESTORE_ACCESS_TOKEN) return process.env.FIRESTORE_ACCESS_TOKEN;

  const keyFile = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!keyFile) {
    console.error(
      'Sin credenciales. Usa FIRESTORE_EMULATOR_HOST, FIRESTORE_ACCESS_TOKEN ' +
        'o GOOGLE_APPLICATION_CREDENTIALS (ver cabecera del script).',
    );
    process.exit(77);
  }
  const key = JSON.parse(readFileSync(keyFile.replace(/^~/, process.env.HOME), 'utf8'));
  const now = Math.floor(Date.now() / 1000);
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const unsigned = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({
    iss: key.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: key.token_uri ?? 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })}`;
  const signature = createSign('RSA-SHA256').update(unsigned).sign(key.private_key, 'base64url');
  const res = await fetch(key.token_uri ?? 'https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${signature}`,
    }),
  });
  if (!res.ok) throw new Error(`Token: ${res.status} ${await res.text()}`);
  return (await res.json()).access_token;
}
