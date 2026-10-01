import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  buildProcessingPlan,
  compareRankingEntries,
  contentHash,
  winnersOf,
} from "../src/processResult";
import { scopesForResult } from "../src/scopeKeys";

describe("processResult", () => {
  const base = {
    challengeId: "c1",
    categoryId: "alitas",
    restaurantId: "r1",
    participants: [
      { userId: "a", username: "a", displayName: "A", count: 10 },
      { userId: "b", username: "b", displayName: "B", count: 10 },
      { userId: "c", username: "c", displayName: "C", count: 8 },
    ],
  };

  it("detecta empate de ganadores", () => {
    assert.deepEqual(winnersOf(base.participants), ["a", "b"]);
  });

  it("idempotencia por contentHash", () => {
    const hash = contentHash(base);
    const first = buildProcessingPlan(base);
    assert.equal(first.skipped, false);
    const second = buildProcessingPlan(base, hash);
    assert.equal(second.skipped, true);
  });

  it("scopes incluyen global, categoría y restaurante", () => {
    assert.deepEqual(scopesForResult({ categoryId: "alitas", restaurantId: "r1" }), [
      "global",
      "global:cat:alitas",
      "restaurant:r1:cat:alitas",
    ]);
  });

  it("orden ranking score > wins > fecha", () => {
    const a = { amount: 10, wins: 1, achievedAtMs: 100, userId: "a" };
    const b = { amount: 10, wins: 2, achievedAtMs: 50, userId: "b" };
    const c = { amount: 12, wins: 0, achievedAtMs: 200, userId: "c" };
    const sorted = [a, b, c].sort(compareRankingEntries);
    assert.deepEqual(sorted.map((x) => x.userId), ["c", "b", "a"]);
  });

  it("reto sin eventos: todos en 0, todos ganan", () => {
    const empty = {
      ...base,
      participants: [
        { userId: "a", username: "a", displayName: "A", count: 0 },
        { userId: "b", username: "b", displayName: "B", count: 0 },
      ],
    };
    assert.deepEqual(winnersOf(empty.participants), ["a", "b"]);
  });
});
