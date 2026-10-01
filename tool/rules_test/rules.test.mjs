// Ejecutar con `npm test` (arranca el emulador de Firestore).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  collection,
  increment,
  onSnapshot,
  query,
  where,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-foodreto',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const db = (uid, email = `${uid}@foodreto.app`) =>
  env.authenticatedContext(uid, { email }).firestore();
const anon = () => env.unauthenticatedContext().firestore();

const profile = (uid, username, extra = {}) => ({
  uid,
  username,
  displayName: 'Gabriel',
  bio: '',
  avatarStyle: 'adventurer',
  avatarSeed: 'gabriel123',
  avatarOptions: { backgroundColor: 'ffc53d' },
  visibility: 'public',
  isActive: true,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...extra,
});

/** Igual que FirestoreProfileRepository.createProfile. */
function createProfile(firestore, uid, username, extra = {}) {
  return runTransaction(firestore, async (tx) => {
    const nameRef = doc(firestore, 'usernames', username);
    const reservation = await tx.get(nameRef);
    if (reservation.exists() && reservation.data().uid !== uid) {
      throw new Error('username-taken');
    }
    if (!reservation.exists()) {
      tx.set(nameRef, { uid, createdAt: serverTimestamp() });
    }
    tx.set(doc(firestore, 'users', uid), profile(uid, username, extra));
  });
}

/** Igual que FirestoreProfileRepository.updateProfile al cambiar username. */
function changeUsername(firestore, uid, from, to) {
  return runTransaction(firestore, async (tx) => {
    const newRef = doc(firestore, 'usernames', to);
    const reservation = await tx.get(newRef);
    if (reservation.exists() && reservation.data().uid !== uid) {
      throw new Error('username-taken');
    }
    if (!reservation.exists()) {
      tx.set(newRef, { uid, createdAt: serverTimestamp() });
    }
    tx.delete(doc(firestore, 'usernames', from));
    tx.update(doc(firestore, 'users', uid), {
      username: to,
      updatedAt: serverTimestamp(),
    });
  });
}

async function seed(path, data) {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));
}

describe('users + usernames', () => {
  test('crear perfil con username en una transacción', async () => {
    await assertSucceeds(createProfile(db('u1'), 'u1', 'gabriel'));
    await assertSucceeds(getDoc(doc(db('u1'), 'users/u1')));
  });

  test('no se puede crear el perfil sin reservar el username', async () => {
    await assertFails(setDoc(doc(db('u1'), 'users/u1'), profile('u1', 'gabriel')));
  });

  test('no se puede reservar un username sin perfil que lo use', async () => {
    await assertFails(
      setDoc(doc(db('u1'), 'usernames/gabriel'), { uid: 'u1', createdAt: serverTimestamp() }),
    );
  });

  test('no se puede reservar a nombre de otro usuario', async () => {
    const firestore = db('u1');
    await assertFails(
      runTransaction(firestore, async (tx) => {
        tx.set(doc(firestore, 'usernames/gabriel'), { uid: 'u2', createdAt: serverTimestamp() });
        tx.set(doc(firestore, 'users/u1'), profile('u1', 'gabriel'));
      }),
    );
  });

  test('un username ocupado no se puede sobrescribir', async () => {
    await createProfile(db('u1'), 'u1', 'gabriel');
    const firestore = db('u2');
    // Saltándose la comprobación del repositorio: el set es un update → denegado.
    await assertFails(
      runTransaction(firestore, async (tx) => {
        tx.set(doc(firestore, 'usernames/gabriel'), { uid: 'u2', createdAt: serverTimestamp() });
        tx.set(doc(firestore, 'users/u2'), profile('u2', 'gabriel'));
      }),
    );
  });

  test('carrera: dos usuarios, mismo username, solo uno gana', async () => {
    const results = await Promise.allSettled([
      createProfile(db('u1'), 'u1', 'gabriel'),
      createProfile(db('u2'), 'u2', 'gabriel'),
    ]);
    const ok = results.filter((r) => r.status === 'fulfilled');
    assert.equal(ok.length, 1, JSON.stringify(results.map((r) => r.status + ":" + (r.reason?.code ?? r.reason?.message ?? ""))));
    // withSecurityRulesDisabled no devuelve el valor del callback.
    let owner;
    let winnerProfile;
    const winner = results[0].status === 'fulfilled' ? 'u1' : 'u2';
    const loser = winner === 'u1' ? 'u2' : 'u1';
    let loserProfile;
    await env.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      owner = (await getDoc(doc(fs, 'usernames/gabriel'))).data()?.uid;
      winnerProfile = (await getDoc(doc(fs, `users/${winner}`))).exists();
      loserProfile = (await getDoc(doc(fs, `users/${loser}`))).exists();
    });
    assert.equal(owner, winner);
    assert.equal(winnerProfile, true);
    assert.equal(loserProfile, false, 'el perdedor no queda con perfil a medias');
  });

  test('formato de username validado en servidor', async () => {
    await assertFails(createProfile(db('u1'), 'u1', 'Gabriel'));
    await assertFails(createProfile(db('u1'), 'u1', 'ga'));
    await assertFails(createProfile(db('u1'), 'u1', 'gabriel-dev'));
  });

  test('campos y tipos del perfil', async () => {
    await assertFails(createProfile(db('u1'), 'u1', 'gabriel', { isAdmin: true }));
    await assertFails(createProfile(db('u1'), 'u1', 'gabriel', { bio: 'x'.repeat(161) }));
    await assertFails(createProfile(db('u1'), 'u1', 'gabriel', { displayName: '   ' }));
    await assertFails(createProfile(db('u1'), 'u1', 'gabriel', { avatarStyle: 'bottts' }));
    await assertFails(
      createProfile(db('u1'), 'u1', 'gabriel', { avatarOptions: { radius: '50' } }),
    );
    await assertFails(createProfile(db('u1'), 'u1', 'gabriel', { isActive: false }));
    await assertFails(createProfile(db('u1'), 'u1', 'gabriel', { uid: 'u2' }));
  });

  test('cambiar username libera el anterior', async () => {
    await createProfile(db('u1'), 'u1', 'gabriel');
    await assertSucceeds(changeUsername(db('u1'), 'u1', 'gabriel', 'gabo'));
    // Otro usuario puede quedarse ahora con "gabriel".
    await assertSucceeds(createProfile(db('u2'), 'u2', 'gabriel'));
  });

  test('cambiar username sin liberar el anterior falla (sin acaparar)', async () => {
    await createProfile(db('u1'), 'u1', 'gabriel');
    const firestore = db('u1');
    await assertFails(
      runTransaction(firestore, async (tx) => {
        tx.set(doc(firestore, 'usernames/gabo'), { uid: 'u1', createdAt: serverTimestamp() });
        tx.update(doc(firestore, 'users/u1'), { username: 'gabo', updatedAt: serverTimestamp() });
      }),
    );
  });

  test('no se puede cambiar al username de otro', async () => {
    await createProfile(db('u1'), 'u1', 'gabriel');
    await createProfile(db('u2'), 'u2', 'liss');
    const firestore = db('u2');
    await assertFails(
      runTransaction(firestore, async (tx) => {
        tx.delete(doc(firestore, 'usernames/liss'));
        tx.update(doc(firestore, 'users/u2'), { username: 'gabriel', updatedAt: serverTimestamp() });
      }),
    );
  });

  test('no se puede borrar la reserva de otro ni la propia en uso', async () => {
    await createProfile(db('u1'), 'u1', 'gabriel');
    await assertFails(deleteDoc(doc(db('u2'), 'usernames/gabriel')));
    await assertFails(deleteDoc(doc(db('u1'), 'usernames/gabriel')));
  });

  test('editar nombre, bio y avatar propios', async () => {
    await createProfile(db('u1'), 'u1', 'gabriel');
    await assertSucceeds(
      updateDoc(doc(db('u1'), 'users/u1'), {
        displayName: 'Gabo',
        bio: 'Rey de las alitas',
        avatarStyle: 'micah',
        avatarSeed: 'nuevo-1',
        avatarOptions: {},
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('campos protegidos no se pueden editar', async () => {
    await createProfile(db('u1'), 'u1', 'gabriel');
    const ref = doc(db('u1'), 'users/u1');
    await assertFails(updateDoc(ref, { isActive: false, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { visibility: 'private', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { displayName: 'Sin updatedAt' }));
  });

  test('nadie lee ni edita el perfil de otro', async () => {
    await createProfile(db('u1'), 'u1', 'gabriel');
    await assertFails(getDoc(doc(db('u2'), 'users/u1')));
    await assertFails(
      updateDoc(doc(db('u2'), 'users/u1'), { displayName: 'x', updatedAt: serverTimestamp() }),
    );
    await assertFails(deleteDoc(doc(db('u1'), 'users/u1')));
    await assertFails(getDoc(doc(anon(), 'users/u1')));
  });

  test('disponibilidad: get sí, listar no', async () => {
    await createProfile(db('u1'), 'u1', 'gabriel');
    await assertSucceeds(getDoc(doc(db('u2'), 'usernames/gabriel')));
    await assertFails(getDocs(collection(db('u2'), 'usernames')));
    await assertFails(getDoc(doc(anon(), 'usernames/gabriel')));
  });
});

describe('private/account', () => {
  test('solo el dueño, solo su propio correo', async () => {
    const ref = (fs) => doc(fs, 'users/u1/private/account');
    await assertSucceeds(
      setDoc(ref(db('u1')), { email: 'u1@foodreto.app', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(ref(db('u1')), { email: 'otro@foodreto.app', updatedAt: serverTimestamp() }),
    );
    await assertFails(getDoc(ref(db('u2'))));
    await assertSucceeds(getDoc(ref(db('u1'))));
  });
});

describe('userStatistics', () => {
  test('el dueño lee, nadie escribe', async () => {
    await seed('userStatistics/u1', { challengeCount: 0 });
    await assertSucceeds(getDoc(doc(db('u1'), 'userStatistics/u1')));
    await assertFails(getDoc(doc(db('u2'), 'userStatistics/u1')));
    await assertFails(setDoc(doc(db('u1'), 'userStatistics/u1'), { challengeCount: 999 }));
    await assertFails(updateDoc(doc(db('u1'), 'userStatistics/u1'), { recordCount: 5 }));
  });
});

describe('catálogo', () => {
  test('categorías: lectura pública, sin escritura', async () => {
    await seed('categories/sushi', { name: 'Sushi', order: 2, isActive: true });
    await assertSucceeds(getDoc(doc(anon(), 'categories/sushi')));
    await assertSucceeds(getDocs(collection(anon(), 'categories')));
    await assertFails(setDoc(doc(db('u1'), 'categories/sushi'), { name: 'Hack' }));
    await assertFails(setDoc(doc(db('u1'), 'categories/nueva'), { name: 'Nueva' }));
  });

  test('restaurantes: solo activos, sin escritura', async () => {
    await seed('restaurants/r1', { name: 'Wing House', isActive: true });
    await seed('restaurants/r2', { name: 'Cerrado', isActive: false });
    await assertSucceeds(getDoc(doc(anon(), 'restaurants/r1')));
    await assertFails(getDoc(doc(anon(), 'restaurants/r2')));
    await assertSucceeds(
      getDocs(query(collection(anon(), 'restaurants'), where('isActive', '==', true))),
    );
    await assertFails(getDocs(collection(anon(), 'restaurants')));
    await assertFails(setDoc(doc(db('u1'), 'restaurants/r3'), { name: 'X', isActive: true }));
  });
});

// ───────────────────────── Fase 3: retos ─────────────────────────
// Los helpers reproducen FirestoreChallengeRepository /
// FirestoreChallengeEventRepository (mismos documentos y campos).

const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const ID_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
const pick = (chars, n) =>
  Array.from({ length: n }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
const newCode = () => pick(ALPHABET, 6);
const newEventId = () => pick(ID_CHARS, 20);

const USERS = {
  a: { username: 'ana', displayName: 'Ana' },
  b: { username: 'beto', displayName: 'Beto' },
  c: { username: 'caro', displayName: 'Caro' },
  d: { username: 'dani', displayName: 'Dani' },
};

async function seedChallengeWorld() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    await setDoc(doc(fs, 'categories/alitas'), { name: 'Alitas', isActive: true });
    await setDoc(doc(fs, 'restaurants/r1'), { name: 'Wing House', isActive: true });
    for (const [uid, u] of Object.entries(USERS)) {
      await setDoc(
        doc(fs, `users/${uid}`),
        profile(uid, u.username, { displayName: u.displayName }),
      );
    }
  });
}

const participantData = (uid, role) => ({
  userId: uid,
  username: USERS[uid].username,
  displayName: USERS[uid].displayName,
  avatarStyle: 'adventurer',
  avatarSeed: 'gabriel123',
  avatarOptions: { backgroundColor: 'ffc53d' },
  role,
  status: 'joined',
  currentCount: 0,
  lastEventId: null,
  joinedAt: serverTimestamp(),
});

const challengeData = (host, code, extra = {}) => ({
  hostUserId: host,
  categoryId: 'alitas',
  restaurantId: 'r1',
  title: 'Reto de alitas',
  description: '',
  inviteCode: code,
  visibility: 'private',
  status: 'waiting',
  maxParticipants: 4,
  participantIds: [host],
  createdAt: serverTimestamp(),
  startedAt: null,
  finishedAt: null,
  updatedAt: serverTimestamp(),
  ...extra,
});

/** Crea el reto reservando el código. Devuelve el id. */
async function createChallenge(uid, { code = newCode(), extra = {}, skip = {} } = {}) {
  const fs = db(uid);
  const ref = doc(collection(fs, 'challenges'));
  await runTransaction(fs, async (tx) => {
    const codeRef = doc(fs, `inviteCodes/${code}`);
    if ((await tx.get(codeRef)).exists()) throw new Error('code-taken');
    tx.set(ref, challengeData(uid, code, extra));
    if (!skip.code) tx.set(codeRef, { challengeId: ref.id, createdAt: serverTimestamp() });
    if (!skip.participant) {
      tx.set(doc(fs, `challenges/${ref.id}/participants/${uid}`), participantData(uid, 'host'));
    }
  });
  return ref.id;
}

function join(uid, id, { data = participantData(uid, 'participant') } = {}) {
  const fs = db(uid);
  return runTransaction(fs, async (tx) => {
    const ref = doc(fs, `challenges/${id}`);
    const c = (await tx.get(ref)).data();
    if (!c) throw new Error('not-found');
    if (c.status !== 'waiting') throw new Error('not-waiting');
    if (c.participantIds.length >= c.maxParticipants) throw new Error('full');
    if (c.participantIds.includes(uid)) throw new Error('already-joined');
    tx.update(ref, {
      participantIds: [...c.participantIds, uid],
      updatedAt: serverTimestamp(),
    });
    tx.set(doc(fs, `challenges/${id}/participants/${uid}`), data);
  });
}

/** Igual que join pero sin las comprobaciones del cliente. */
function forceJoin(uid, id, participantIds) {
  const fs = db(uid);
  const batch = writeBatch(fs);
  batch.update(doc(fs, `challenges/${id}`), { participantIds, updatedAt: serverTimestamp() });
  batch.set(doc(fs, `challenges/${id}/participants/${uid}`), participantData(uid, 'participant'));
  return batch.commit();
}

function leave(uid, id) {
  const fs = db(uid);
  return runTransaction(fs, async (tx) => {
    const ref = doc(fs, `challenges/${id}`);
    const c = (await tx.get(ref)).data();
    tx.update(ref, {
      participantIds: c.participantIds.filter((p) => p !== uid),
      updatedAt: serverTimestamp(),
    });
    tx.delete(doc(fs, `challenges/${id}/participants/${uid}`));
  });
}

const setStatus = (uid, id, status, extra = {}) =>
  updateDoc(doc(db(uid), `challenges/${id}`), {
    status,
    updatedAt: serverTimestamp(),
    ...extra,
  });

const start = (uid, id) => setStatus(uid, id, 'active', { startedAt: serverTimestamp() });
const cancel = (uid, id) => setStatus(uid, id, 'cancelled');

/** +1/−1 como WriteBatch: evento create-only + contador propio. */
function recordEvent(uid, id, type = 'increment', {
  eventId = newEventId(),
  owner = uid,
  delta = type === 'increment' ? 1 : -1,
} = {}) {
  const fs = db(uid);
  const batch = writeBatch(fs);
  batch.set(doc(fs, `challenges/${id}/events/${eventId}`), {
    clientEventId: eventId,
    userId: owner,
    type,
    amount: 1,
    createdAt: serverTimestamp(),
  });
  batch.update(doc(fs, `challenges/${id}/participants/${owner}`), {
    currentCount: increment(delta),
    lastEventId: eventId,
  });
  return batch.commit();
}

/**
 * Igual que FirestoreChallengeRepository.finish: si un +1 entra entre la
 * lectura y el commit, las reglas responden permission-denied y se reintenta.
 */
async function finish(uid, id, options = {}, attempts = 3) {
  for (let attempt = 1; ; attempt++) {
    try {
      return await finishOnce(uid, id, options);
    } catch (e) {
      if (e?.code !== 'permission-denied' || attempt >= attempts) throw e;
    }
  }
}

/** [tamper] altera el resultado antes de escribirlo. */
function finishOnce(uid, id, { tamper = (r) => r, withResult = true } = {}) {
  const fs = db(uid);
  return runTransaction(fs, async (tx) => {
    const ref = doc(fs, `challenges/${id}`);
    const c = (await tx.get(ref)).data();
    const participants = [];
    for (const pid of c.participantIds) {
      participants.push((await tx.get(doc(fs, `challenges/${id}/participants/${pid}`))).data());
    }
    tx.update(ref, {
      status: 'finished',
      finishedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    if (withResult) {
      tx.set(doc(fs, `challengeResults/${id}`), tamper({
        challengeId: id,
        hostUserId: c.hostUserId,
        categoryId: c.categoryId,
        restaurantId: c.restaurantId,
        title: c.title,
        participantIds: c.participantIds,
        participants: participants.map((p) => ({
          userId: p.userId,
          username: p.username,
          displayName: p.displayName,
          avatarStyle: p.avatarStyle,
          avatarSeed: p.avatarSeed,
          avatarOptions: p.avatarOptions,
          count: p.currentCount,
        })),
        startedAt: c.startedAt,
        finishedAt: serverTimestamp(),
        createdAt: serverTimestamp(),
      }));
    }
  });
}

async function adminRead(path) {
  let data;
  await env.withSecurityRulesDisabled(async (ctx) => {
    data = (await getDoc(doc(ctx.firestore(), path))).data();
  });
  return data;
}

async function adminEvents(id) {
  let events;
  await env.withSecurityRulesDisabled(async (ctx) => {
    events = (await getDocs(collection(ctx.firestore(), `challenges/${id}/events`))).docs.map(
      (d) => d.data(),
    );
  });
  return events;
}

const tally = (events, uid) =>
  events
    .filter((e) => e.userId === uid)
    .reduce((sum, e) => sum + (e.type === 'increment' ? 1 : -1), 0);

/** Reto activo con a (anfitrión) y b ya dentro. */
async function activeChallenge(extraJoiners = []) {
  const id = await createChallenge('a');
  await join('b', id);
  for (const uid of extraJoiners) await join(uid, id);
  await start('a', id);
  return id;
}

describe('challenges: crear', () => {
  beforeEach(seedChallengeWorld);

  test('crear reto con código reservado y anfitrión como participante', async () => {
    const id = await assertSucceeds(createChallenge('a'));
    const c = await adminRead(`challenges/${id}`);
    assert.equal(c.status, 'waiting');
    assert.deepEqual(c.participantIds, ['a']);
    assert.equal((await adminRead(`inviteCodes/${c.inviteCode}`)).challengeId, id);
    assert.equal((await adminRead(`challenges/${id}/participants/a`)).role, 'host');
  });

  test('sin reservar código o sin participante anfitrión falla', async () => {
    await assertFails(createChallenge('a', { skip: { code: true } }));
    await assertFails(createChallenge('a', { skip: { participant: true } }));
  });

  test('datos inválidos fallan en servidor', async () => {
    await assertFails(createChallenge('a', { extra: { categoryId: 'no-existe' } }));
    await assertFails(createChallenge('a', { extra: { restaurantId: 'r-falso' } }));
    await assertFails(createChallenge('a', { extra: { maxParticipants: 9 } }));
    await assertFails(createChallenge('a', { extra: { maxParticipants: 0 } }));
    await assertFails(createChallenge('a', { extra: { status: 'active' } }));
    await assertFails(createChallenge('a', { extra: { hostUserId: 'b' } }));
    await assertFails(createChallenge('a', { extra: { participantIds: ['a', 'b'] } }));
    await assertFails(createChallenge('a', { extra: { title: 'x'.repeat(61) } }));
    await assertFails(createChallenge('a', { extra: { visibility: 'friends' } }));
    await assertFails(createChallenge('a', { extra: { isFeatured: true } }));
    await assertFails(createChallenge('a', { code: 'ABC10O' }));
    await assertSucceeds(createChallenge('a', { extra: { restaurantId: null } }));
  });

  test('un código ya reservado no se puede reutilizar', async () => {
    await createChallenge('a', { code: 'QWERTY' });
    // Saltándose la comprobación del cliente: el set de la reserva es un update.
    const fs = db('b');
    const ref = doc(collection(fs, 'challenges'));
    const batch = writeBatch(fs);
    batch.set(ref, challengeData('b', 'QWERTY'));
    batch.set(doc(fs, 'inviteCodes/QWERTY'), { challengeId: ref.id, createdAt: serverTimestamp() });
    batch.set(doc(fs, `challenges/${ref.id}/participants/b`), participantData('b', 'host'));
    await assertFails(batch.commit());
  });

  test('carrera: dos retos a la vez con el mismo código, solo uno gana', async () => {
    const results = await Promise.allSettled([
      createChallenge('a', { code: 'ZXCVBN' }),
      createChallenge('b', { code: 'ZXCVBN' }),
    ]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    const winner = results.find((r) => r.status === 'fulfilled').value;
    assert.equal((await adminRead('inviteCodes/ZXCVBN')).challengeId, winner);
  });
});

describe('challenges: unirse y salir', () => {
  beforeEach(seedChallengeWorld);

  test('unirse con un snapshot fiel del perfil', async () => {
    const id = await createChallenge('a');
    await assertSucceeds(join('b', id));
    assert.deepEqual((await adminRead(`challenges/${id}`)).participantIds, ['a', 'b']);
  });

  test('unirse dos veces falla', async () => {
    const id = await createChallenge('a');
    await join('b', id);
    await assertFails(forceJoin('b', id, ['a', 'b', 'b']));
  });

  test('el snapshot del participante no se puede falsear', async () => {
    const id = await createChallenge('a');
    const fake = { ...participantData('b', 'participant'), displayName: 'Admin' };
    await assertFails(join('b', id, { data: fake }));
    await assertFails(join('b', id, { data: participantData('b', 'host') }));
    await assertFails(
      join('b', id, { data: { ...participantData('b', 'participant'), currentCount: 50 } }),
    );
  });

  test('no se puede meter a otro usuario', async () => {
    const id = await createChallenge('a');
    const fs = db('b');
    const batch = writeBatch(fs);
    batch.update(doc(fs, `challenges/${id}`), {
      participantIds: ['a', 'c'],
      updatedAt: serverTimestamp(),
    });
    batch.set(doc(fs, `challenges/${id}/participants/c`), participantData('c', 'participant'));
    await assertFails(batch.commit());
  });

  test('reto lleno: no entra nadie más', async () => {
    const id = await createChallenge('a', { extra: { maxParticipants: 2 } });
    await join('b', id);
    await assertFails(forceJoin('c', id, ['a', 'b', 'c']));
  });

  test('carrera por el último cupo: solo uno entra', async () => {
    const id = await createChallenge('a', { extra: { maxParticipants: 2 } });
    const results = await Promise.allSettled([join('b', id), join('c', id)]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    const c = await adminRead(`challenges/${id}`);
    assert.equal(c.participantIds.length, 2);
  });

  test('no se entra a un reto activo, terminado o cancelado', async () => {
    const id = await createChallenge('a');
    await start('a', id);
    await assertFails(forceJoin('b', id, ['a', 'b']));
    const cancelled = await createChallenge('a');
    await cancel('a', cancelled);
    await assertFails(forceJoin('b', cancelled, ['a', 'b']));
  });

  test('salir en la sala de espera; el anfitrión no puede salir', async () => {
    const id = await createChallenge('a');
    await join('b', id);
    await assertSucceeds(leave('b', id));
    assert.deepEqual((await adminRead(`challenges/${id}`)).participantIds, ['a']);
    await assertFails(leave('a', id));
  });
});

describe('challenges: estados', () => {
  beforeEach(seedChallengeWorld);

  test('un no anfitrión no puede iniciar el reto', async () => {
    const id = await createChallenge('a');
    await join('b', id);
    await assertFails(start('b', id));
    await assertSucceeds(start('a', id));
    assert.equal((await adminRead(`challenges/${id}`)).status, 'active');
  });

  test('transiciones inválidas y campos protegidos', async () => {
    const id = await createChallenge('a');
    await assertFails(setStatus('a', id, 'finished', { finishedAt: serverTimestamp() }));
    await assertFails(start('a', id).then(() => start('a', id)));
    await assertFails(
      updateDoc(doc(db('a'), `challenges/${id}`), {
        maxParticipants: 8,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(db('a'), `challenges/${id}`), {
        hostUserId: 'b',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(deleteDoc(doc(db('a'), `challenges/${id}`)));
  });

  test('solo el anfitrión cancela', async () => {
    const id = await createChallenge('a');
    await join('b', id);
    await assertFails(cancel('b', id));
    await assertSucceeds(cancel('a', id));
    await assertFails(start('a', id));
  });
});

describe('challenges: eventos y contador', () => {
  beforeEach(seedChallengeWorld);

  test('+1 y −1 propios actualizan el contador', async () => {
    const id = await activeChallenge();
    await assertSucceeds(recordEvent('b', id));
    await assertSucceeds(recordEvent('b', id));
    await assertSucceeds(recordEvent('b', id, 'decrement'));
    assert.equal((await adminRead(`challenges/${id}/participants/b`)).currentCount, 1);
  });

  test('A no puede crear eventos para B', async () => {
    const id = await activeChallenge();
    await assertFails(recordEvent('a', id, 'increment', { owner: 'b' }));
    // Ni evento propio + contador ajeno.
    const fs = db('a');
    const eventId = newEventId();
    const batch = writeBatch(fs);
    batch.set(doc(fs, `challenges/${id}/events/${eventId}`), {
      clientEventId: eventId,
      userId: 'a',
      type: 'increment',
      amount: 1,
      createdAt: serverTimestamp(),
    });
    batch.update(doc(fs, `challenges/${id}/participants/b`), {
      currentCount: increment(1),
      lastEventId: eventId,
    });
    await assertFails(batch.commit());
  });

  test('el contador nunca queda negativo', async () => {
    const id = await activeChallenge();
    await assertFails(recordEvent('b', id, 'decrement'));
    assert.equal((await adminRead(`challenges/${id}/participants/b`)).currentCount, 0);
  });

  test('el contador solo cambia con su evento y de uno en uno', async () => {
    const id = await activeChallenge();
    const ref = doc(db('b'), `challenges/${id}/participants/b`);
    await assertFails(updateDoc(ref, { currentCount: 100 }));
    await assertFails(updateDoc(ref, { currentCount: 1, lastEventId: newEventId() }));
    await assertFails(recordEvent('b', id, 'increment', { delta: 5 }));
    await assertFails(recordEvent('b', id, 'decrement', { delta: 1 }));
    await assertFails(updateDoc(ref, { role: 'host' }));
  });

  test('idempotencia: el mismo clientEventId no cuenta dos veces', async () => {
    const id = await activeChallenge();
    const eventId = newEventId();
    await assertSucceeds(recordEvent('b', id, 'increment', { eventId }));
    await assertFails(recordEvent('b', id, 'increment', { eventId }));
    assert.equal((await adminRead(`challenges/${id}/participants/b`)).currentCount, 1);
    assert.equal((await adminEvents(id)).length, 1);
    await assertFails(deleteDoc(doc(db('b'), `challenges/${id}/events/${eventId}`)));
  });

  test('sin eventos antes de iniciar ni después de terminar', async () => {
    const id = await createChallenge('a');
    await join('b', id);
    await assertFails(recordEvent('b', id));
    await start('a', id);
    await recordEvent('b', id);
    await finish('a', id);
    await assertFails(recordEvent('b', id));
  });

  test('un no participante no registra ni lee', async () => {
    const id = await activeChallenge();
    await assertFails(recordEvent('d', id));
    await assertFails(getDocs(collection(db('d'), `challenges/${id}/events`)));
    await assertFails(getDocs(collection(db('d'), `challenges/${id}/participants`)));
    await assertSucceeds(getDocs(collection(db('b'), `challenges/${id}/participants`)));
  });

  test('concurrencia: 15 eventos del mismo usuario a la vez', async () => {
    const id = await activeChallenge();
    await Promise.all(Array.from({ length: 15 }, () => recordEvent('b', id)));
    const events = await adminEvents(id);
    assert.equal(events.length, 15);
    assert.equal((await adminRead(`challenges/${id}/participants/b`)).currentCount, 15);
  });

  test('concurrencia: dos usuarios incrementan a la vez', async () => {
    const id = await activeChallenge();
    await Promise.all([
      ...Array.from({ length: 8 }, () => recordEvent('a', id)),
      ...Array.from({ length: 6 }, () => recordEvent('b', id)),
    ]);
    assert.equal((await adminRead(`challenges/${id}/participants/a`)).currentCount, 8);
    assert.equal((await adminRead(`challenges/${id}/participants/b`)).currentCount, 6);
  });
});

describe('challenges: finalizar y resultado', () => {
  beforeEach(seedChallengeWorld);

  test('el anfitrión finaliza con el resultado exacto', async () => {
    const id = await activeChallenge(['c']);
    await recordEvent('b', id);
    await recordEvent('b', id);
    await recordEvent('c', id);
    await assertSucceeds(finish('a', id));
    const result = await adminRead(`challengeResults/${id}`);
    assert.deepEqual(
      result.participants.map((p) => [p.userId, p.count]),
      [['a', 0], ['b', 2], ['c', 1]],
    );
    assert.equal((await adminRead(`challenges/${id}`)).status, 'finished');
  });

  test('un no anfitrión no puede finalizar', async () => {
    const id = await activeChallenge();
    await assertFails(finish('b', id));
  });

  test('no se puede finalizar sin resultado ni con un resultado falso', async () => {
    const id = await activeChallenge();
    await recordEvent('b', id);
    await assertFails(finish('a', id, { withResult: false }));
    await assertFails(
      finish('a', id, {
        tamper: (r) => ({
          ...r,
          participants: r.participants.map((p) => (p.userId === 'a' ? { ...p, count: 99 } : p)),
        }),
      }),
    );
    await assertFails(
      finish('a', id, { tamper: (r) => ({ ...r, participants: r.participants.slice(1) }) }),
    );
    await assertFails(finish('a', id, { tamper: (r) => ({ ...r, winner: 'a' }) }));
  });

  test('B no puede modificar el resultado de A', async () => {
    const id = await activeChallenge();
    await recordEvent('a', id);
    await finish('a', id);
    const ref = doc(db('b'), `challengeResults/${id}`);
    await assertSucceeds(getDoc(ref));
    const result = await adminRead(`challengeResults/${id}`);
    await assertFails(
      updateDoc(ref, {
        participants: result.participants.map((p) => ({ ...p, count: 0 })),
      }),
    );
    await assertFails(deleteDoc(ref));
    await assertFails(
      updateDoc(doc(db('b'), `challenges/${id}/participants/a`), { currentCount: 0 }),
    );
    await assertFails(getDoc(doc(db('d'), `challengeResults/${id}`)));
  });

  test('finalizar mientras se envían eventos: resultado = contadores = eventos', async () => {
    const id = await activeChallenge(['c']);
    await recordEvent('b', id);
    const settled = await Promise.allSettled([
      ...Array.from({ length: 5 }, () => recordEvent('b', id)),
      ...Array.from({ length: 5 }, () => recordEvent('c', id)),
      finish('a', id),
      ...Array.from({ length: 5 }, () => recordEvent('b', id)),
    ]);
    const finishOutcome = settled[10];
    assert.equal(
      (await adminRead(`challenges/${id}`)).status,
      'finished',
      `finish: ${finishOutcome.status} ${finishOutcome.reason?.code ?? ''} ${finishOutcome.reason?.message ?? ''}`,
    );
    const result = await adminRead(`challengeResults/${id}`);
    const events = await adminEvents(id);
    for (const entry of result.participants) {
      const p = await adminRead(`challenges/${id}/participants/${entry.userId}`);
      assert.equal(entry.count, p.currentCount, `resultado ${entry.userId}`);
      assert.equal(entry.count, tally(events, entry.userId), `eventos ${entry.userId}`);
    }
  });
});

describe('challenges: lecturas', () => {
  beforeEach(seedChallengeWorld);

  test('mis retos: solo los propios, sin listar los ajenos', async () => {
    const mine = await createChallenge('a');
    await createChallenge('c');
    const fs = db('a');
    const snap = await assertSucceeds(
      getDocs(query(collection(fs, 'challenges'), where('participantIds', 'array-contains', 'a'))),
    );
    assert.deepEqual(snap.docs.map((d) => d.id), [mine]);
    await assertFails(getDocs(collection(fs, 'challenges')));
    await assertFails(
      getDocs(query(collection(fs, 'challenges'), where('participantIds', 'array-contains', 'c'))),
    );
  });

  test('código: se consulta uno, no se listan; sin sesión nada', async () => {
    const id = await createChallenge('a', { code: 'HJKMNP' });
    await assertSucceeds(getDoc(doc(db('b'), 'inviteCodes/HJKMNP')));
    await assertSucceeds(getDoc(doc(db('b'), `challenges/${id}`)));
    await assertFails(getDocs(collection(db('b'), 'inviteCodes')));
    await assertFails(getDoc(doc(anon(), `challenges/${id}`)));
    await assertFails(
      updateDoc(doc(db('a'), 'inviteCodes/HJKMNP'), { challengeId: 'otro' }),
    );
  });
});

/** Espera hasta que un listener vea [predicate]. Sin polling. */
function waitFor(ref, predicate, label) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      unsub();
      reject(new Error(`timeout: ${label}`));
    }, 5000);
    const unsub = onSnapshot(
      ref,
      (snap) => {
        if (predicate(snap)) {
          clearTimeout(timer);
          unsub();
          resolve(snap);
        }
      },
      (err) => {
        clearTimeout(timer);
        reject(err);
      },
    );
  });
}

describe('challenges: realtime A/B/C', () => {
  beforeEach(seedChallengeWorld);

  test('tres usuarios ven la sala, el inicio, los contadores y el final', async () => {
    const id = await createChallenge('a');
    const room = (uid) => doc(db(uid), `challenges/${id}`);
    const people = (uid) => collection(db(uid), `challenges/${id}/participants`);

    // A escucha la sala mientras B y C entran.
    const aSeesThree = waitFor(people('a'), (s) => s.size === 3, 'A ve 3 participantes');
    await join('b', id);
    await join('c', id);
    await aSeesThree;

    // Todos cambian solos a "active" cuando A inicia.
    const seeActive = ['a', 'b', 'c'].map((u) =>
      waitFor(room(u), (s) => s.data()?.status === 'active', `${u} ve active`),
    );
    await start('a', id);
    await Promise.all(seeActive);

    // A y C ven el +1 de B.
    const seeCount = ['a', 'c'].map((u) =>
      waitFor(
        doc(db(u), `challenges/${id}/participants/b`),
        (s) => s.data()?.currentCount === 2,
        `${u} ve a B en 2`,
      ),
    );
    await recordEvent('b', id);
    await recordEvent('b', id);
    await Promise.all(seeCount);

    // Todos ven el final y el resultado.
    const seeFinished = ['a', 'b', 'c'].map((u) =>
      waitFor(room(u), (s) => s.data()?.status === 'finished', `${u} ve finished`),
    );
    await finish('a', id);
    await Promise.all(seeFinished);
    for (const u of ['a', 'b', 'c']) {
      const r = await getDoc(doc(db(u), `challengeResults/${id}`));
      assert.equal(r.data().participants.find((p) => p.userId === 'b').count, 2);
    }
  });
});

describe('por defecto', () => {
  test('cualquier otra colección está cerrada', async () => {
    await assertFails(setDoc(doc(db('u1'), 'challenges/c1'), { name: 'x' }));
    await assertFails(getDoc(doc(db('u1'), 'records/r1')));
    await assertFails(setDoc(doc(db('u1'), 'rankings/global'), { top: 'u1' }));
  });
});
