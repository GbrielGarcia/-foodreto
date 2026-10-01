import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  canGrantSuperAdmin,
  isSuperAdminToken,
  approvePatch,
  rejectPatch,
  suspendPatch,
  reactivatePatch,
} from "../src/establishments.ts";
import {
  NotificationIds,
  buildEstablishmentApprovedNotification,
  buildEstablishmentRejectedNotification,
  buildEstablishmentTransferredNotification,
} from "../src/notifications.ts";

const createdAt = { seconds: 1, nanoseconds: 0 } as never;

describe("establishments helpers", () => {
  it("superAdmin claim", () => {
    assert.equal(isSuperAdminToken({ superAdmin: true }), true);
    assert.equal(isSuperAdminToken({ superAdmin: false }), false);
    assert.equal(isSuperAdminToken({}), false);
  });

  it("bootstrap can grant when env matches", () => {
    assert.equal(
      canGrantSuperAdmin({}, "bootstrap-uid", "bootstrap-uid"),
      true,
    );
    assert.equal(
      canGrantSuperAdmin({ superAdmin: true }, "x", "y"),
      true,
    );
    assert.equal(
      canGrantSuperAdmin({}, "other", "bootstrap-uid"),
      false,
    );
  });

  it("approve patch sets approved + active", () => {
    const patch = approvePatch("admin1", createdAt);
    assert.equal(patch.status, "approved");
    assert.equal(patch.isActive, true);
    assert.equal(patch.approvedByUserId, "admin1");
  });

  it("reject and suspend patches", () => {
    const rej = rejectPatch("a", "bad data", createdAt);
    assert.equal(rej.status, "rejected");
    assert.equal(rej.isActive, false);
    assert.equal(rej.rejectionReason, "bad data");
    const sus = suspendPatch("a", "spam", createdAt);
    assert.equal(sus.status, "suspended");
    assert.equal(sus.suspensionReason, "spam");
  });

  it("reactivate patch", () => {
    const patch = reactivatePatch("admin", createdAt);
    assert.equal(patch.status, "approved");
    assert.equal(patch.isActive, true);
  });
});

describe("establishment notifications", () => {
  it("deterministic ids", () => {
    assert.equal(
      NotificationIds.establishmentApproved("e1", "u1"),
      "establishmentApproved_e1_u1",
    );
  });

  it("approved notification targets mine route", () => {
    const n = buildEstablishmentApprovedNotification({
      establishmentId: "e1",
      recipientUserId: "u1",
      actorUserId: "admin",
      establishmentName: "Wing House",
      createdAt,
    });
    assert.equal(n.data.type, "establishmentApproved");
    assert.equal(n.data.recipientUserId, "u1");
    assert.equal(n.data.targetRoute, "/establishments/mine");
  });

  it("rejected includes reason", () => {
    const n = buildEstablishmentRejectedNotification({
      establishmentId: "e1",
      recipientUserId: "u1",
      actorUserId: "admin",
      establishmentName: "X",
      reason: "Duplicado",
      createdAt,
    });
    assert.match(n.data.body, /Duplicado/);
    assert.equal(n.data.type, "establishmentRejected");
  });

  it("transfer notification", () => {
    const n = buildEstablishmentTransferredNotification({
      establishmentId: "e1",
      recipientUserId: "u2",
      actorUserId: "admin",
      establishmentName: "Cafe",
      createdAt,
    });
    assert.equal(n.data.type, "establishmentTransferred");
    assert.equal(
      n.data.targetRoute,
      "/admin/establishments/e1",
    );
  });
});
