import { scopesForResult, type ScopeKey } from "./scopeKeys";

export type ResultParticipant = {
  userId: string;
  username: string;
  displayName: string;
  avatarStyle?: string;
  avatarSeed?: string;
  avatarOptions?: Record<string, unknown>;
  count: number;
};

export type ChallengeResultDoc = {
  challengeId: string;
  categoryId: string;
  restaurantId?: string | null;
  participants: ResultParticipant[];
  finishedAt?: FirebaseFirestore.Timestamp | Date | null;
  visibilityHint?: "public" | "private";
};

export type UserDelta = {
  units: number;
  won: boolean;
  score: number;
  restaurantId?: string | null;
  categoryId: string;
};

export type ProcessingPlan = {
  contentHash: string;
  winnerIds: string[];
  totalUnits: number;
  userDeltas: Record<string, UserDelta>;
  scopes: ScopeKey[];
  skipped: boolean;
  notificationHints: Array<"record_created" | "record_broken" | "ranking_changed">;
};

export function contentHash(result: ChallengeResultDoc): string {
  const parts = [...result.participants]
    .sort((a, b) => a.userId.localeCompare(b.userId))
    .map((p) => `${p.userId}:${p.count}`);
  return `${result.challengeId}|${result.categoryId}|${result.restaurantId ?? ""}|${parts.join(",")}`;
}

export function winnersOf(participants: ResultParticipant[]): string[] {
  if (participants.length === 0) return [];
  const max = Math.max(...participants.map((p) => p.count));
  return participants.filter((p) => p.count === max).map((p) => p.userId).sort();
}

export function buildProcessingPlan(
  result: ChallengeResultDoc,
  previousHash?: string | null,
): ProcessingPlan {
  const hash = contentHash(result);
  if (previousHash && previousHash === hash) {
    return {
      contentHash: hash,
      winnerIds: winnersOf(result.participants),
      totalUnits: result.participants.reduce((s, p) => s + p.count, 0),
      userDeltas: {},
      scopes: [],
      skipped: true,
      notificationHints: [],
    };
  }
  const winnerIds = winnersOf(result.participants);
  const winnerSet = new Set(winnerIds);
  const userDeltas: Record<string, UserDelta> = {};
  for (const p of result.participants) {
    userDeltas[p.userId] = {
      units: p.count,
      won: winnerSet.has(p.userId),
      score: p.count,
      restaurantId: result.restaurantId,
      categoryId: result.categoryId,
    };
  }
  return {
    contentHash: hash,
    winnerIds,
    totalUnits: result.participants.reduce((s, p) => s + p.count, 0),
    userDeltas,
    scopes: scopesForResult({
      categoryId: result.categoryId,
      restaurantId: result.restaurantId,
    }),
    skipped: false,
    notificationHints: ["ranking_changed"],
  };
}

/** Comparador de ranking: amount DESC, wins DESC, achievedAt ASC. */
export function compareRankingEntries(
  a: { amount: number; wins: number; achievedAtMs: number; userId: string },
  b: { amount: number; wins: number; achievedAtMs: number; userId: string },
): number {
  if (b.amount !== a.amount) return b.amount - a.amount;
  if (b.wins !== a.wins) return b.wins - a.wins;
  if (a.achievedAtMs !== b.achievedAtMs) return a.achievedAtMs - b.achievedAtMs;
  return a.userId.localeCompare(b.userId);
}
