#!/usr/bin/env node
/**
 * Bootstrap Super Admin claim (Fase 9.1).
 *
 * NO incluye ni acepta passwords. Usa Firebase Admin SDK con ADC
 * (GOOGLE_APPLICATION_CREDENTIALS o `gcloud auth application-default login`).
 *
 * Uso:
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
 *   node scripts/bootstrap_super_admin.mjs --email=administracion@tinguar.com
 *
 * O por UID:
 *   node scripts/bootstrap_super_admin.mjs --uid=XXXX
 */
const admin = require("firebase-admin");

function arg(name) {
  const prefix = `--${name}=`;
  const hit = process.argv.find((a) => a.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : null;
}

async function main() {
  const email = arg("email");
  const uidArg = arg("uid");
  if (!email && !uidArg) {
    console.error("Required: --email=... or --uid=...");
    process.exit(1);
  }

  admin.initializeApp({ projectId: "foodreto" });

  const user = uidArg
    ? await admin.auth().getUser(uidArg)
    : await admin.auth().getUserByEmail(email);

  const claims = { ...(user.customClaims || {}), superAdmin: true };
  await admin.auth().setCustomUserClaims(user.uid, claims);
  console.log(JSON.stringify({ ok: true, uid: user.uid, email: user.email, claims }, null, 2));
  console.log("User must sign out/in (or force token refresh) for claim to apply.");
}

main().catch((e) => {
  console.error(e.code || e.message || e);
  process.exit(1);
});
