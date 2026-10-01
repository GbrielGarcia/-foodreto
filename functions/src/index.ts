import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentCreated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import {
  buildOfficialActivities,
  type ActivityDoc,
} from "./activities";
import {
  buildChallengeInvitationNotification,
  buildFriendAcceptedNotification,
  buildFriendJoinedNotifications,
  buildFriendRequestNotification,
  buildOfficialResultNotifications,
  type NotificationDoc,
} from "./notifications";
import {
  buildProcessingPlan,
  type ChallengeResultDoc,
  type ResultParticipant,
} from "./processResult";
import { scopesForResult } from "./scopeKeys";
import { registerEstablishmentCallables } from "./establishments";

admin.initializeApp();
const db = admin.firestore();

/**
 * Costo bajo por defecto:
 * - sin minInstances (cold start ok; no pagar idle)
 * - 256MiB / timeout corto
 * - maxInstances bajo para evitar picos de factura
 * - region unica
 */
setGlobalOptions({
  region: "us-central1",
  memory: "256MiB",
  timeoutSeconds: 60,
  maxInstances: 5,
  concurrency: 40,
});

const establishmentCallables = registerEstablishmentCallables(db);
export const approveEstablishment =
  establishmentCallables.approveEstablishment;
export const rejectEstablishment =
  establishmentCallables.rejectEstablishment;
export const suspendEstablishment =
  establishmentCallables.suspendEstablishment;
export const reactivateEstablishment =
  establishmentCallables.reactivateEstablishment;
export const transferEstablishmentOwnership =
  establishmentCallables.transferEstablishmentOwnership;
export const setSuperAdminClaim = establishmentCallables.setSuperAdminClaim;

type Holder = {
  userId: string;
  username: string;
  displayName: string;
  avatarStyle?: string;
  avatarSeed?: string;
  avatarOptions?: Record<string, unknown>;
  challengeId: string;
  achievedAt: FirebaseFirestore.FieldValue;
};

async function applyOfficialResult(
  challengeId: string,
  data: FirebaseFirestore.DocumentData,
): Promise<{ skipped: boolean }> {
  const participants = (data.participants ?? []) as ResultParticipant[];
  const result: ChallengeResultDoc = {
    challengeId,
    categoryId: String(data.categoryId ?? ""),
    restaurantId: data.restaurantId ?? null,
    participants,
  };

  const ledgerRef = db.collection("resultProcessing").doc(challengeId);
  const resultRef = db.collection("challengeResults").doc(challengeId);
  const challengeRef = db.collection("challenges").doc(challengeId);

  const userIds = participants.map((p) => p.userId);
  const scopes = scopesForResult({
    categoryId: result.categoryId,
    restaurantId: result.restaurantId,
  });

  await db.runTransaction(async (tx) => {
    const ledgerSnap = await tx.get(ledgerRef);
    const challengeSnap = await tx.get(challengeRef);

    const previousHash = ledgerSnap.exists
      ? (ledgerSnap.data()?.contentHash as string | undefined)
      : undefined;
    const plan = buildProcessingPlan(result, previousHash);

    if (plan.skipped) {
      tx.set(
        resultRef,
        {
          processingStatus: "official",
          winnerIds: plan.winnerIds,
          totalUnits: plan.totalUnits,
        },
        { merge: true },
      );
      return;
    }

    // Lecturas previas (Firestore: todo read antes de write).
    const prevDeltas = ledgerSnap.exists
      ? ((ledgerSnap.data()?.userDeltas ?? {}) as Record<
          string,
          { units: number; won: boolean; score: number }
        >)
      : {};
    const affectedUserIds = new Set([
      ...userIds,
      ...Object.keys(prevDeltas),
    ]);

    const userSnaps = new Map<string, FirebaseFirestore.DocumentSnapshot>();
    const profileSnaps = new Map<string, FirebaseFirestore.DocumentSnapshot>();
    for (const uid of affectedUserIds) {
      userSnaps.set(uid, await tx.get(db.collection("userStatistics").doc(uid)));
    }
    for (const uid of userIds) {
      profileSnaps.set(uid, await tx.get(db.collection("users").doc(uid)));
    }

    const boardSnaps = new Map<string, FirebaseFirestore.DocumentSnapshot>();
    const entrySnaps = new Map<string, FirebaseFirestore.DocumentSnapshot>();
    for (const scope of scopes) {
      boardSnaps.set(scope, await tx.get(db.collection("leaderboards").doc(scope)));
      for (const p of participants) {
        const key = `${scope}::${p.userId}`;
        entrySnaps.set(
          key,
          await tx.get(
            db.collection("leaderboards").doc(scope).collection("entries").doc(p.userId),
          ),
        );
      }
    }

    const visibility = challengeSnap.data()?.visibility as string | undefined;
    const rankingEligible = visibility === "public";
    const achievedAt = admin.firestore.FieldValue.serverTimestamp();
    const recordEvents: Array<{
      userId: string;
      type: "recordCreated" | "recordBroken";
      score: number;
      previousRecordScore?: number;
      scopeKey: string;
      participant: ResultParticipant;
    }> = [];

    // Revert deltas previos si el hash cambió.
    for (const [uid, delta] of Object.entries(prevDeltas)) {
      const snap = userSnaps.get(uid);
      const cur = snap?.data() ?? {};
      tx.set(
        db.collection("userStatistics").doc(uid),
        {
          challengeCount: Math.max(0, Number(cur.challengeCount ?? 0) - 1),
          winCount: Math.max(0, Number(cur.winCount ?? 0) - (delta.won ? 1 : 0)),
          totalUnits: Math.max(0, Number(cur.totalUnits ?? 0) - delta.units),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    // Aplicar user stats.
    for (const [uid, delta] of Object.entries(plan.userDeltas)) {
      const snap = userSnaps.get(uid);
      const cur = snap?.data() ?? {};
      // Si revertimos arriba en la misma tx, usar valores base del snap
      // y aplicar neto: -prev + new cuando mismo uid.
      const prev = prevDeltas[uid];
      const baseChallenges =
        Number(cur.challengeCount ?? 0) - (prev ? 1 : 0);
      const baseWins =
        Number(cur.winCount ?? 0) - (prev?.won ? 1 : 0);
      const baseUnits =
        Number(cur.totalUnits ?? 0) - (prev ? prev.units : 0);
      const restaurants = new Set<string>(
        (cur.restaurantIds as string[] | undefined) ?? [],
      );
      const categories = new Set<string>(
        (cur.categoryIds as string[] | undefined) ?? [],
      );
      if (delta.restaurantId) restaurants.add(delta.restaurantId);
      categories.add(delta.categoryId);
      const bestScore = Math.max(Number(cur.bestScore ?? 0), delta.score);

      tx.set(
        db.collection("userStatistics").doc(uid),
        {
          challengeCount: baseChallenges + 1,
          winCount: baseWins + (delta.won ? 1 : 0),
          totalUnits: baseUnits + delta.units,
          bestScore,
          restaurantIds: [...restaurants],
          categoryIds: [...categories],
          restaurantCount: restaurants.size,
          categoryCount: categories.size,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    if (rankingEligible) {
      for (const scope of scopes) {
        for (const p of participants) {
          const entrySnap = entrySnaps.get(`${scope}::${p.userId}`)!;
          const prevAmount = Number(entrySnap.data()?.amount ?? 0);
          const prevWins = Number(entrySnap.data()?.wins ?? 0);
          const won = plan.winnerIds.includes(p.userId);
          const improved = p.count > prevAmount;
          tx.set(
            db.collection("leaderboards").doc(scope).collection("entries").doc(p.userId),
            {
              userId: p.userId,
              username: p.username,
              displayName: p.displayName,
              avatarStyle: p.avatarStyle ?? null,
              avatarSeed: p.avatarSeed ?? null,
              avatarOptions: p.avatarOptions ?? {},
              amount: Math.max(prevAmount, p.count),
              wins: prevWins + (won ? 1 : 0),
              achievedAt: improved
                ? achievedAt
                : (entrySnap.data()?.achievedAt ?? achievedAt),
              challengeId: improved
                ? challengeId
                : (entrySnap.data()?.challengeId ?? challengeId),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }

        const boardSnap = boardSnaps.get(scope)!;
        const topAmount = Number(boardSnap.data()?.topAmount ?? 0);
        const maxInChallenge = Math.max(0, ...participants.map((p) => p.count));
        const topParticipants = participants.filter(
          (p) => p.count === maxInChallenge,
        );

        if (maxInChallenge > topAmount) {
          const holders: Holder[] = topParticipants.map((p) => ({
            userId: p.userId,
            username: p.username,
            displayName: p.displayName,
            avatarStyle: p.avatarStyle,
            avatarSeed: p.avatarSeed,
            avatarOptions: p.avatarOptions,
            challengeId,
            achievedAt,
          }));
          tx.set(
            db.collection("leaderboards").doc(scope),
            {
              scopeKey: scope,
              categoryId: result.categoryId,
              restaurantId: result.restaurantId ?? null,
              topAmount: maxInChallenge,
              topHolders: holders,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
          for (const h of holders) {
            tx.set(db.collection("recordHistory").doc(), {
              scopeKey: scope,
              score: maxInChallenge,
              userId: h.userId,
              username: h.username,
              displayName: h.displayName,
              challengeId,
              achievedAt,
              eventType: topAmount === 0 ? "created" : "broken",
              notificationHint:
                topAmount === 0 ? "record_created" : "record_broken",
            });
            const participant = participants.find((p) => p.userId === h.userId);
            if (participant) {
              recordEvents.push({
                userId: h.userId,
                type: topAmount === 0 ? "recordCreated" : "recordBroken",
                score: maxInChallenge,
                previousRecordScore: topAmount > 0 ? topAmount : undefined,
                scopeKey: scope,
                participant,
              });
            }
            const u = userSnaps.get(h.userId)?.data() ?? {};
            tx.set(
              db.collection("userStatistics").doc(h.userId),
              {
                recordCount: Number(u.recordCount ?? 0) + 1,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true },
            );
          }
        } else if (maxInChallenge === topAmount && maxInChallenge > 0) {
          const existing = (boardSnap.data()?.topHolders ?? []) as Array<{
            userId: string;
          }>;
          const existingIds = new Set(existing.map((h) => h.userId));
          const added: Holder[] = [];
          for (const p of topParticipants) {
            if (existingIds.has(p.userId)) continue;
            added.push({
              userId: p.userId,
              username: p.username,
              displayName: p.displayName,
              avatarStyle: p.avatarStyle,
              avatarSeed: p.avatarSeed,
              avatarOptions: p.avatarOptions,
              challengeId,
              achievedAt,
            });
          }
          if (added.length) {
            tx.set(
              db.collection("leaderboards").doc(scope),
              {
                topHolders: [...existing, ...added],
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true },
            );
            for (const h of added) {
              tx.set(db.collection("recordHistory").doc(), {
                scopeKey: scope,
                score: maxInChallenge,
                userId: h.userId,
                username: h.username,
                displayName: h.displayName,
                challengeId,
                achievedAt,
                eventType: "tied",
                notificationHint: "record_created",
              });
            }
          }
        }

        if (scope.startsWith("global:cat:")) {
          tx.set(
            db.collection("categoryStats").doc(result.categoryId),
            {
              categoryId: result.categoryId,
              challengeCount: admin.firestore.FieldValue.increment(1),
              totalUnits: admin.firestore.FieldValue.increment(plan.totalUnits),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }
        if (scope.startsWith("restaurant:") && result.restaurantId) {
          const id = `${result.restaurantId}_${result.categoryId}`;
          tx.set(
            db.collection("restaurantCategoryStats").doc(id),
            {
              restaurantId: result.restaurantId,
              categoryId: result.categoryId,
              challengeCount: admin.firestore.FieldValue.increment(1),
              totalUnits: admin.firestore.FieldValue.increment(plan.totalUnits),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }
      }
    }

    tx.set(ledgerRef, {
      challengeId,
      contentHash: plan.contentHash,
      status: "official",
      userDeltas: plan.userDeltas,
      winnerIds: plan.winnerIds,
      totalUnits: plan.totalUnits,
      appliedAt: admin.firestore.FieldValue.serverTimestamp(),
      notificationHints: plan.notificationHints,
    });

    tx.set(
      resultRef,
      {
        processingStatus: "official",
        winnerIds: plan.winnerIds,
        totalUnits: plan.totalUnits,
        officialAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const profileVisibilityByUser: Record<string, string | undefined> = {};
    for (const uid of userIds) {
      profileVisibilityByUser[uid] = profileSnaps.get(uid)?.data()
        ?.visibility as string | undefined;
    }
    const activities = buildOfficialActivities({
      result,
      winnerIds: plan.winnerIds,
      challengeVisibility: visibility,
      profileVisibilityByUser,
      recordEvents,
      createdAt: achievedAt,
    });
    for (const act of activities) {
      tx.set(db.collection("activities").doc(act.id), act.data as ActivityDoc, {
        merge: true,
      });
    }

    const participantActors = participants.map((p) => ({
      userId: p.userId,
      username: p.username,
      displayName: p.displayName,
      avatarStyle: p.avatarStyle,
      avatarSeed: p.avatarSeed,
      avatarOptions: p.avatarOptions,
    }));
    const notifs = buildOfficialResultNotifications({
      challengeId,
      categoryId: result.categoryId,
      participants: participantActors,
      winnerIds: plan.winnerIds,
      recordEvents: recordEvents.map((e) => ({
        userId: e.userId,
        type: e.type,
        score: e.score,
      })),
      createdAt: achievedAt,
    });
    for (const n of notifs) {
      tx.set(db.collection("notifications").doc(n.id), n.data as NotificationDoc, {
        merge: true,
      });
    }
  });

  return { skipped: false };
}

export const onChallengeResultCreated = onDocumentCreated(
  "challengeResults/{challengeId}",
  async (event) => {
    const data = event.data?.data();
    const challengeId = event.params.challengeId as string;
    if (!data) return;
    try {
      const out = await applyOfficialResult(challengeId, data);
      logger.info("FoodReto: processed result", { challengeId, ...out });
    } catch (err) {
      logger.error("FoodReto: process result failed", err);
      await resultFail(challengeId, err);
    }
  },
);

async function resultFail(challengeId: string, err: unknown): Promise<void> {
  await db.collection("challengeResults").doc(challengeId).set(
    {
      processingStatus: "failed",
      processingError: String(err),
    },
    { merge: true },
  );
  await db.collection("resultProcessing").doc(challengeId).set(
    {
      status: "failed",
      error: String(err),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

/** Reprocesamiento (callable autenticado). Idempotente vía contentHash. */
export const reprocessChallengeResult = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Auth required");
  }
  const challengeId = String(request.data?.challengeId ?? "");
  if (!challengeId) {
    throw new HttpsError("invalid-argument", "challengeId required");
  }
  const snap = await db.collection("challengeResults").doc(challengeId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Result not found");
  }
  // Borrar ledger fuerza recálculo completo.
  await db.collection("resultProcessing").doc(challengeId).delete();
  await applyOfficialResult(challengeId, snap.data()!);
  return { ok: true, challengeId };
});

function actorFromSnapshot(data: FirebaseFirestore.DocumentData | undefined, fallbackUid: string) {
  if (!data) {
    return { userId: fallbackUid, username: "", displayName: "" };
  }
  return {
    userId: String(data.userId ?? fallbackUid),
    username: String(data.username ?? ""),
    displayName: String(data.displayName ?? ""),
    avatarStyle: data.avatarStyle as string | undefined,
    avatarSeed: data.avatarSeed as string | undefined,
  };
}

/** Solicitud de amistad / aceptacion → notificacion al destinatario. */
export const onFriendshipWritten = onDocumentWritten(
  "friendships/{fid}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;
    const fid = event.params.fid as string;
    const createdAt = admin.firestore.FieldValue.serverTimestamp();

    try {
      // Nueva solicitud pending
      if ((!before || before.status !== "pending") && after.status === "pending") {
        const actor = actorFromSnapshot(
          after.requester as FirebaseFirestore.DocumentData | undefined,
          String(after.requesterId ?? ""),
        );
        const n = buildFriendRequestNotification({
          friendshipId: fid,
          recipientUserId: String(after.addresseeId),
          actor,
          createdAt,
        });
        await db.collection("notifications").doc(n.id).set(n.data, { merge: true });
        return;
      }

      // Aceptada
      if (
        before?.status === "pending" &&
        after.status === "accepted"
      ) {
        const actor = actorFromSnapshot(
          after.addressee as FirebaseFirestore.DocumentData | undefined,
          String(after.addresseeId ?? ""),
        );
        const n = buildFriendAcceptedNotification({
          friendshipId: fid,
          recipientUserId: String(after.requesterId),
          actor,
          createdAt,
        });
        await db.collection("notifications").doc(n.id).set(n.data, { merge: true });
      }
    } catch (err) {
      logger.error("FoodReto: friendship notification failed", err);
    }
  },
);

/** Invitacion a reto → notificacion al invitado. */
export const onChallengeInvitationCreated = onDocumentCreated(
  "challengeInvitations/{id}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    try {
      const n = buildChallengeInvitationNotification({
        challengeId: String(data.challengeId),
        recipientUserId: String(data.toUserId),
        actor: {
          userId: String(data.fromUserId),
          username: String(data.fromUsername ?? ""),
          displayName: String(data.fromDisplayName ?? ""),
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        challengeTitle: data.challengeTitle as string | undefined,
      });
      await db.collection("notifications").doc(n.id).set(n.data, { merge: true });
    } catch (err) {
      logger.error("FoodReto: invitation notification failed", err);
    }
  },
);

/** Amigo se une a reto (actividad friendJoinedChallenge) → notifica amigos. */
export const onFriendJoinedActivityCreated = onDocumentCreated(
  "activities/{activityId}",
  async (event) => {
    const data = event.data?.data();
    if (!data || data.type !== "friendJoinedChallenge") return;
    const actorUserId = String(data.actorUserId ?? "");
    const challengeId = String(data.challengeId ?? "");
    if (!actorUserId || !challengeId) return;

    try {
      const friendsSnap = await db
        .collection("friendships")
        .where("userIds", "array-contains", actorUserId)
        .where("status", "==", "accepted")
        .limit(30)
        .get()
        .catch(async () => {
          const snap = await db
            .collection("friendships")
            .where("userIds", "array-contains", actorUserId)
            .limit(50)
            .get();
          return {
            docs: snap.docs.filter((d) => d.data().status === "accepted"),
          };
        });

      const friendIds: string[] = [];
      for (const doc of friendsSnap.docs) {
        const ids = (doc.data().userIds as string[]) ?? [];
        for (const id of ids) {
          if (id !== actorUserId) friendIds.push(id);
        }
      }

      const notifs = buildFriendJoinedNotifications({
        challengeId,
        actor: {
          userId: actorUserId,
          username: String(data.actorUsername ?? ""),
          displayName: String(data.actorDisplayName ?? ""),
          avatarStyle: data.actorAvatarStyle as string | undefined,
          avatarSeed: data.actorAvatarSeed as string | undefined,
          avatarOptions: data.actorAvatarOptions as
            | Record<string, unknown>
            | undefined,
        },
        friendUserIds: friendIds.slice(0, 29),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        categoryName: data.categoryName as string | undefined,
      });

      const batch = db.batch();
      for (const n of notifs) {
        batch.set(db.collection("notifications").doc(n.id), n.data, {
          merge: true,
        });
      }
      if (notifs.length) await batch.commit();
    } catch (err) {
      logger.error("FoodReto: friendJoined notification failed", err);
    }
  },
);
