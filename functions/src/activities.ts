import type { ChallengeResultDoc, ResultParticipant } from "./processResult";

export type ActivityType =
  | "challengeCompleted"
  | "challengeWon"
  | "recordCreated"
  | "recordBroken"
  | "friendJoinedChallenge";

export type ActivityVisibility = "public" | "friends" | "private";

export function activityId(
  challengeId: string,
  userId: string,
  type: ActivityType,
): string {
  return `${challengeId}_${userId}_${type}`;
}

export function resolveActivityVisibility(args: {
  challengeVisibility?: string | null;
  profileVisibility?: string | null;
}): ActivityVisibility | null {
  if (args.challengeVisibility === "private") return null;
  if (args.profileVisibility === "private") return "friends";
  if (args.challengeVisibility === "friends") return "friends";
  return "public";
}

export type ActivityDoc = {
  type: ActivityType;
  actorUserId: string;
  actorUsername: string;
  actorDisplayName: string;
  actorAvatarStyle?: string;
  actorAvatarSeed?: string;
  actorAvatarOptions?: Record<string, unknown>;
  visibility: ActivityVisibility;
  createdAt: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
  challengeId: string;
  categoryId: string;
  restaurantId?: string | null;
  restaurantName?: string | null;
  score?: number;
  previousRecordScore?: number | null;
  scopeKey?: string | null;
};

export function buildOfficialActivities(args: {
  result: ChallengeResultDoc;
  winnerIds: string[];
  challengeVisibility?: string | null;
  profileVisibilityByUser?: Record<string, string | undefined>;
  recordEvents: Array<{
    userId: string;
    type: "recordCreated" | "recordBroken";
    score: number;
    previousRecordScore?: number;
    scopeKey: string;
    participant: ResultParticipant;
  }>;
  createdAt: FirebaseFirestore.FieldValue;
}): Array<{ id: string; data: ActivityDoc }> {
  const out: Array<{ id: string; data: ActivityDoc }> = [];
  const winners = new Set(args.winnerIds);

  for (const p of args.result.participants) {
    const visibility = resolveActivityVisibility({
      challengeVisibility: args.challengeVisibility,
      profileVisibility: args.profileVisibilityByUser?.[p.userId],
    });
    if (!visibility) continue;
    const base = {
      actorUserId: p.userId,
      actorUsername: p.username,
      actorDisplayName: p.displayName,
      actorAvatarStyle: p.avatarStyle,
      actorAvatarSeed: p.avatarSeed,
      actorAvatarOptions: p.avatarOptions,
      visibility,
      createdAt: args.createdAt,
      challengeId: args.result.challengeId,
      categoryId: args.result.categoryId,
      restaurantId: args.result.restaurantId ?? null,
      score: p.count,
    };

    out.push({
      id: activityId(args.result.challengeId, p.userId, "challengeCompleted"),
      data: { ...base, type: "challengeCompleted" },
    });
    if (winners.has(p.userId)) {
      out.push({
        id: activityId(args.result.challengeId, p.userId, "challengeWon"),
        data: { ...base, type: "challengeWon" },
      });
    }
  }

  const seen = new Set<string>();
  for (const e of args.recordEvents) {
    if (!e.scopeKey.startsWith("global:cat:")) continue;
    const id = activityId(args.result.challengeId, e.userId, e.type);
    if (seen.has(id)) continue;
    seen.add(id);
    const visibility = resolveActivityVisibility({
      challengeVisibility: args.challengeVisibility,
      profileVisibility: args.profileVisibilityByUser?.[e.userId],
    });
    if (!visibility) continue;
    out.push({
      id,
      data: {
        type: e.type,
        actorUserId: e.userId,
        actorUsername: e.participant.username,
        actorDisplayName: e.participant.displayName,
        actorAvatarStyle: e.participant.avatarStyle,
        actorAvatarSeed: e.participant.avatarSeed,
        actorAvatarOptions: e.participant.avatarOptions,
        visibility,
        createdAt: args.createdAt,
        challengeId: args.result.challengeId,
        categoryId: args.result.categoryId,
        restaurantId: args.result.restaurantId ?? null,
        score: e.score,
        previousRecordScore: e.previousRecordScore ?? null,
        scopeKey: e.scopeKey,
      },
    });
  }

  return out;
}
