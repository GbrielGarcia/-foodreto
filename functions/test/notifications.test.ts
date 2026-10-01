import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  NotificationIds,
  buildChallengeInvitationNotification,
  buildFriendAcceptedNotification,
  buildFriendJoinedNotifications,
  buildFriendRequestNotification,
  buildOfficialResultNotifications,
} from "../src/notifications.ts";

const createdAt = { seconds: 1, nanoseconds: 0 } as never;

const actor = {
  userId: "u1",
  username: "gabriel",
  displayName: "Gabriel",
};

describe("notifications", () => {
  it("ids deterministic", () => {
    assert.equal(NotificationIds.friendRequest("a_b"), "friendRequest_a_b");
    assert.equal(
      NotificationIds.challengeWon("c1", "u1"),
      "challengeWon_c1_u1",
    );
  });

  it("friend request recipient is addressee", () => {
    const n = buildFriendRequestNotification({
      friendshipId: "a_b",
      recipientUserId: "b",
      actor,
      createdAt,
    });
    assert.equal(n.id, "friendRequest_a_b");
    assert.equal(n.data.recipientUserId, "b");
    assert.equal(n.data.type, "friendRequest");
    assert.equal(n.data.read, false);
  });

  it("friend accepted notifies requester", () => {
    const n = buildFriendAcceptedNotification({
      friendshipId: "a_b",
      recipientUserId: "a",
      actor: { ...actor, userId: "b", username: "bob" },
      createdAt,
    });
    assert.equal(n.data.recipientUserId, "a");
    assert.equal(n.data.type, "friendRequestAccepted");
  });

  it("challenge invitation", () => {
    const n = buildChallengeInvitationNotification({
      challengeId: "c1",
      recipientUserId: "u2",
      actor,
      createdAt,
      challengeTitle: "Sushi",
    });
    assert.equal(n.id, "challengeInvitation_c1_u2");
    assert.equal(n.data.challengeId, "c1");
  });

  it("friend joined fans out without self", () => {
    const list = buildFriendJoinedNotifications({
      challengeId: "c1",
      actor,
      friendUserIds: ["u1", "f1", "f2"],
      createdAt,
      categoryName: "Sushi",
    });
    assert.equal(list.length, 2);
    assert.ok(list.every((n) => n.data.recipientUserId !== "u1"));
    assert.equal(list[0].id, "friendJoined_c1_u1_f1");
  });

  it("official result: won + records idempotent", () => {
    const p1 = { ...actor, userId: "u1", username: "u1", displayName: "U1" };
    const p2 = { ...actor, userId: "u2", username: "u2", displayName: "U2" };
    const once = buildOfficialResultNotifications({
      challengeId: "c1",
      categoryId: "sushi",
      categoryName: "Sushi",
      participants: [p1, p2],
      winnerIds: ["u1"],
      recordEvents: [
        { userId: "u1", type: "recordBroken", score: 20 },
        { userId: "u1", type: "recordBroken", score: 20 },
      ],
      createdAt,
    });
    const twice = buildOfficialResultNotifications({
      challengeId: "c1",
      categoryId: "sushi",
      categoryName: "Sushi",
      participants: [p1, p2],
      winnerIds: ["u1"],
      recordEvents: [{ userId: "u1", type: "recordBroken", score: 20 }],
      createdAt,
    });
    assert.deepEqual(
      once.map((n) => n.id).sort(),
      twice.map((n) => n.id).sort(),
    );
    assert.ok(once.some((n) => n.data.type === "challengeWon"));
    assert.equal(
      once.filter((n) => n.data.type === "recordBroken").length,
      1,
    );
    const won = once.find((n) => n.data.type === "challengeWon")!;
    assert.equal(won.data.recipientUserId, "u1");
  });
});
