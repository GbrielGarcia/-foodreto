import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  activityId,
  buildOfficialActivities,
  resolveActivityVisibility,
} from "../src/activities.ts";

describe("activities", () => {
  it("ids determinísticos", () => {
    assert.equal(
      activityId("c1", "u1", "challengeWon"),
      "c1_u1_challengeWon",
    );
  });

  it("visibilidad: private challenge → null", () => {
    assert.equal(
      resolveActivityVisibility({ challengeVisibility: "private" }),
      null,
    );
    assert.equal(
      resolveActivityVisibility({
        challengeVisibility: "public",
        profileVisibility: "private",
      }),
      "friends",
    );
  });

  it("buildOfficialActivities dedupe records", () => {
    const createdAt = { seconds: 1, nanoseconds: 0 } as never;
    const p = {
      userId: "u1",
      username: "u1",
      displayName: "U1",
      count: 12,
    };
    const acts = buildOfficialActivities({
      result: {
        challengeId: "c1",
        categoryId: "sushi",
        participants: [p],
      },
      winnerIds: ["u1"],
      challengeVisibility: "public",
      recordEvents: [
        {
          userId: "u1",
          type: "recordBroken",
          score: 12,
          previousRecordScore: 10,
          scopeKey: "global:cat:sushi",
          participant: p,
        },
        {
          userId: "u1",
          type: "recordBroken",
          score: 12,
          scopeKey: "global",
          participant: p,
        },
      ],
      createdAt,
    });
    const types = acts.map((a) => a.data.type).sort();
    assert.deepEqual(types, [
      "challengeCompleted",
      "challengeWon",
      "recordBroken",
    ]);
  });
});
