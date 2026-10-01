import * as admin from "firebase-admin";
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import {
  buildEstablishmentApprovedNotification,
  buildEstablishmentRejectedNotification,
  buildEstablishmentTransferredNotification,
} from "./notifications";

export type EstablishmentStatus =
  | "pending"
  | "approved"
  | "rejected"
  | "suspended";

export type AuditAction =
  | "approve"
  | "reject"
  | "suspend"
  | "reactivate"
  | "transfer";

export function isSuperAdminToken(
  token: Record<string, unknown> | undefined,
): boolean {
  if (token?.superAdmin === true) return true;
  const email =
    typeof token?.email === "string" ? token.email.trim().toLowerCase() : "";
  return email === "administracion@tinguar.com";
}

export function requireSuperAdmin(request: CallableRequest): string {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Auth required");
  }
  if (!isSuperAdminToken(request.auth.token as Record<string, unknown>)) {
    throw new HttpsError("permission-denied", "Super Admin required");
  }
  return request.auth.uid;
}

export function canGrantSuperAdmin(
  callerToken: Record<string, unknown> | undefined,
  callerUid: string,
  bootstrapUid: string | undefined,
): boolean {
  if (isSuperAdminToken(callerToken)) return true;
  return (
    bootstrapUid != null &&
    bootstrapUid.length > 0 &&
    callerUid === bootstrapUid
  );
}

type RestaurantDoc = {
  status?: EstablishmentStatus;
  isActive?: boolean;
  name?: string;
  ownerUserId?: string;
  creatorUserId?: string;
};

export function approvePatch(
  adminUid: string,
  now: FirebaseFirestore.FieldValue,
): Record<string, unknown> {
  return {
    status: "approved",
    isActive: true,
    approvedAt: now,
    approvedByUserId: adminUid,
    updatedAt: now,
    rejectedAt: admin.firestore.FieldValue.delete(),
    rejectedByUserId: admin.firestore.FieldValue.delete(),
    rejectionReason: admin.firestore.FieldValue.delete(),
    suspendedAt: admin.firestore.FieldValue.delete(),
    suspendedByUserId: admin.firestore.FieldValue.delete(),
    suspensionReason: admin.firestore.FieldValue.delete(),
  };
}

export function rejectPatch(
  adminUid: string,
  reason: string,
  now: FirebaseFirestore.FieldValue,
): Record<string, unknown> {
  return {
    status: "rejected",
    isActive: false,
    rejectedAt: now,
    rejectedByUserId: adminUid,
    rejectionReason: reason,
    updatedAt: now,
  };
}

export function suspendPatch(
  adminUid: string,
  reason: string,
  now: FirebaseFirestore.FieldValue,
): Record<string, unknown> {
  return {
    status: "suspended",
    isActive: false,
    suspendedAt: now,
    suspendedByUserId: adminUid,
    suspensionReason: reason,
    updatedAt: now,
  };
}

export function reactivatePatch(
  adminUid: string,
  now: FirebaseFirestore.FieldValue,
): Record<string, unknown> {
  return {
    status: "approved",
    isActive: true,
    approvedAt: now,
    approvedByUserId: adminUid,
    updatedAt: now,
    suspendedAt: admin.firestore.FieldValue.delete(),
    suspendedByUserId: admin.firestore.FieldValue.delete(),
    suspensionReason: admin.firestore.FieldValue.delete(),
  };
}

export async function writeEstablishmentAuditLog(
  db: FirebaseFirestore.Firestore,
  args: {
    establishmentId: string;
    action: AuditAction;
    actorUserId: string;
    before?: Record<string, unknown>;
    after?: Record<string, unknown>;
    note?: string;
  },
): Promise<void> {
  await db.collection("establishmentAuditLogs").add({
    establishmentId: args.establishmentId,
    action: args.action,
    actorUserId: args.actorUserId,
    before: args.before ?? null,
    after: args.after ?? null,
    note: args.note ?? null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

export async function writeOwnershipTransfer(
  db: FirebaseFirestore.Firestore,
  args: {
    establishmentId: string;
    fromUserId: string;
    toUserId: string;
    actorUserId: string;
  },
): Promise<void> {
  await db.collection("establishmentOwnershipTransfers").add({
    establishmentId: args.establishmentId,
    fromUserId: args.fromUserId,
    toUserId: args.toUserId,
    actorUserId: args.actorUserId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function notifyRecipient(
  db: FirebaseFirestore.Firestore,
  n: { id: string; data: Record<string, unknown> },
): Promise<FirebaseFirestore.WriteResult> {
  return db.collection("notifications").doc(n.id).set(n.data, { merge: true });
}

export function createEstablishmentHandlers(
  db: FirebaseFirestore.Firestore,
) {
  async function loadRestaurant(id: string): Promise<{
    ref: FirebaseFirestore.DocumentReference;
    data: RestaurantDoc;
  }> {
    const ref = db.collection("restaurants").doc(id);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Establishment not found");
    }
    return { ref, data: snap.data() as RestaurantDoc };
  }

  return {
    async approveEstablishment(
      establishmentId: string,
      adminUid: string,
    ): Promise<{ ok: boolean; skipped?: boolean }> {
      const { ref, data } = await loadRestaurant(establishmentId);
      if (data.status === "approved" && data.isActive === true) {
        return { ok: true, skipped: true };
      }
      const now = admin.firestore.FieldValue.serverTimestamp();
      const patch = approvePatch(adminUid, now);
      await ref.update(patch);
      await writeEstablishmentAuditLog(db, {
        establishmentId,
        action: "approve",
        actorUserId: adminUid,
        before: { status: data.status, isActive: data.isActive },
        after: { status: "approved", isActive: true },
      });
      const recipient =
        data.ownerUserId ?? data.creatorUserId ?? adminUid;
      const n = buildEstablishmentApprovedNotification({
        establishmentId,
        recipientUserId: recipient,
        actorUserId: adminUid,
        establishmentName: data.name ?? "Establecimiento",
        createdAt: now,
      });
      await notifyRecipient(db, n);
      return { ok: true };
    },

    async rejectEstablishment(
      establishmentId: string,
      adminUid: string,
      reason: string,
    ): Promise<{ ok: boolean; skipped?: boolean }> {
      const { ref, data } = await loadRestaurant(establishmentId);
      if (data.status === "rejected") {
        return { ok: true, skipped: true };
      }
      const trimmed = reason.trim() || "Sin motivo";
      const now = admin.firestore.FieldValue.serverTimestamp();
      await ref.update(rejectPatch(adminUid, trimmed, now));
      await writeEstablishmentAuditLog(db, {
        establishmentId,
        action: "reject",
        actorUserId: adminUid,
        before: { status: data.status },
        after: { status: "rejected", rejectionReason: trimmed },
      });
      const recipient =
        data.creatorUserId ?? data.ownerUserId ?? adminUid;
      const n = buildEstablishmentRejectedNotification({
        establishmentId,
        recipientUserId: recipient,
        actorUserId: adminUid,
        establishmentName: data.name ?? "Establecimiento",
        reason: trimmed,
        createdAt: now,
      });
      await notifyRecipient(db, n);
      return { ok: true };
    },

    async suspendEstablishment(
      establishmentId: string,
      adminUid: string,
      reason: string,
    ): Promise<{ ok: boolean; skipped?: boolean }> {
      const { ref, data } = await loadRestaurant(establishmentId);
      if (data.status === "suspended") {
        return { ok: true, skipped: true };
      }
      const trimmed = reason.trim() || "Suspendido";
      const now = admin.firestore.FieldValue.serverTimestamp();
      await ref.update(suspendPatch(adminUid, trimmed, now));
      await writeEstablishmentAuditLog(db, {
        establishmentId,
        action: "suspend",
        actorUserId: adminUid,
        before: { status: data.status },
        after: { status: "suspended", suspensionReason: trimmed },
      });
      return { ok: true };
    },

    async reactivateEstablishment(
      establishmentId: string,
      adminUid: string,
    ): Promise<{ ok: boolean; skipped?: boolean }> {
      const { ref, data } = await loadRestaurant(establishmentId);
      if (data.status === "approved" && data.isActive === true) {
        return { ok: true, skipped: true };
      }
      const now = admin.firestore.FieldValue.serverTimestamp();
      await ref.update(reactivatePatch(adminUid, now));
      await writeEstablishmentAuditLog(db, {
        establishmentId,
        action: "reactivate",
        actorUserId: adminUid,
        before: { status: data.status, isActive: data.isActive },
        after: { status: "approved", isActive: true },
      });
      return { ok: true };
    },

    async transferEstablishmentOwnership(
      establishmentId: string,
      adminUid: string,
      newOwnerUserId: string,
    ): Promise<{ ok: boolean; skipped?: boolean }> {
      const toUid = newOwnerUserId.trim();
      if (!toUid) {
        throw new HttpsError("invalid-argument", "newOwnerUserId required");
      }
      const { ref, data } = await loadRestaurant(establishmentId);
      const fromUid = data.ownerUserId ?? "";
      if (fromUid === toUid) {
        return { ok: true, skipped: true };
      }
      const now = admin.firestore.FieldValue.serverTimestamp();
      await ref.update({
        ownerUserId: toUid,
        updatedAt: now,
      });
      await writeOwnershipTransfer(db, {
        establishmentId,
        fromUserId: fromUid,
        toUserId: toUid,
        actorUserId: adminUid,
      });
      await writeEstablishmentAuditLog(db, {
        establishmentId,
        action: "transfer",
        actorUserId: adminUid,
        before: { ownerUserId: fromUid },
        after: { ownerUserId: toUid },
      });
      const n = buildEstablishmentTransferredNotification({
        establishmentId,
        recipientUserId: toUid,
        actorUserId: adminUid,
        establishmentName: data.name ?? "Establecimiento",
        createdAt: now,
      });
      await notifyRecipient(db, n);
      return { ok: true };
    },
  };
}

export function registerEstablishmentCallables(
  db: FirebaseFirestore.Firestore,
) {
  const handlers = createEstablishmentHandlers(db);

  const approveEstablishment = onCall(async (request) => {
    const adminUid = requireSuperAdmin(request);
    const establishmentId = String(request.data?.establishmentId ?? "");
    if (!establishmentId) {
      throw new HttpsError("invalid-argument", "establishmentId required");
    }
    return handlers.approveEstablishment(establishmentId, adminUid);
  });

  const rejectEstablishment = onCall(async (request) => {
    const adminUid = requireSuperAdmin(request);
    const establishmentId = String(request.data?.establishmentId ?? "");
    const reason = String(request.data?.reason ?? "");
    if (!establishmentId) {
      throw new HttpsError("invalid-argument", "establishmentId required");
    }
    return handlers.rejectEstablishment(establishmentId, adminUid, reason);
  });

  const suspendEstablishment = onCall(async (request) => {
    const adminUid = requireSuperAdmin(request);
    const establishmentId = String(request.data?.establishmentId ?? "");
    const reason = String(request.data?.reason ?? "");
    if (!establishmentId) {
      throw new HttpsError("invalid-argument", "establishmentId required");
    }
    return handlers.suspendEstablishment(establishmentId, adminUid, reason);
  });

  const reactivateEstablishment = onCall(async (request) => {
    const adminUid = requireSuperAdmin(request);
    const establishmentId = String(request.data?.establishmentId ?? "");
    if (!establishmentId) {
      throw new HttpsError("invalid-argument", "establishmentId required");
    }
    return handlers.reactivateEstablishment(establishmentId, adminUid);
  });

  const transferEstablishmentOwnership = onCall(async (request) => {
    const adminUid = requireSuperAdmin(request);
    const establishmentId = String(request.data?.establishmentId ?? "");
    const newOwnerUserId = String(request.data?.newOwnerUserId ?? "");
    if (!establishmentId) {
      throw new HttpsError("invalid-argument", "establishmentId required");
    }
    return handlers.transferEstablishmentOwnership(
      establishmentId,
      adminUid,
      newOwnerUserId,
    );
  });

  const setSuperAdminClaim = onCall(async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Auth required");
    }
    const bootstrapUid = process.env.BOOTSTRAP_SUPER_ADMIN_UID;
    if (
      !canGrantSuperAdmin(
        request.auth.token as Record<string, unknown>,
        request.auth.uid,
        bootstrapUid,
      )
    ) {
      throw new HttpsError("permission-denied", "Not allowed");
    }
    const targetUid = String(request.data?.uid ?? request.auth.uid);
    const grant = request.data?.superAdmin !== false;
    await admin.auth().setCustomUserClaims(targetUid, {
      superAdmin: grant,
    });
    return { ok: true, uid: targetUid, superAdmin: grant };
  });

  return {
    approveEstablishment,
    rejectEstablishment,
    suspendEstablishment,
    reactivateEstablishment,
    transferEstablishmentOwnership,
    setSuperAdminClaim,
  };
}
