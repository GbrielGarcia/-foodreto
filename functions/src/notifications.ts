export type NotificationType =
  | "friendRequest"
  | "friendRequestAccepted"
  | "challengeInvitation"
  | "friendJoinedChallenge"
  | "challengeCompleted"
  | "challengeWon"
  | "recordCreated"
  | "recordBroken"
  | "establishmentApproved"
  | "establishmentRejected"
  | "establishmentTransferred";

export type NotificationDoc = {
  recipientUserId: string;
  type: NotificationType;
  actorUserId: string;
  actorUsername: string;
  actorDisplayName: string;
  actorAvatarStyle?: string;
  actorAvatarSeed?: string;
  actorAvatarOptions?: Record<string, unknown>;
  title: string;
  body: string;
  read: boolean;
  createdAt: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
  challengeId?: string | null;
  activityId?: string | null;
  recordId?: string | null;
  targetRoute?: string | null;
  categoryId?: string | null;
  categoryName?: string | null;
};

export const NotificationIds = {
  friendRequest: (friendshipId: string) => `friendRequest_${friendshipId}`,
  friendAccepted: (friendshipId: string) => `friendAccepted_${friendshipId}`,
  challengeInvitation: (challengeId: string, recipientUserId: string) =>
    `challengeInvitation_${challengeId}_${recipientUserId}`,
  friendJoined: (
    challengeId: string,
    actorUserId: string,
    recipientUserId: string,
  ) => `friendJoined_${challengeId}_${actorUserId}_${recipientUserId}`,
  challengeWon: (challengeId: string, userId: string) =>
    `challengeWon_${challengeId}_${userId}`,
  challengeCompleted: (challengeId: string, userId: string) =>
    `challengeCompleted_${challengeId}_${userId}`,
  recordCreated: (challengeId: string, userId: string) =>
    `recordCreated_${challengeId}_${userId}`,
  recordBroken: (challengeId: string, userId: string) =>
    `recordBroken_${challengeId}_${userId}`,
  establishmentApproved: (establishmentId: string, recipientUserId: string) =>
    `establishmentApproved_${establishmentId}_${recipientUserId}`,
  establishmentRejected: (establishmentId: string, recipientUserId: string) =>
    `establishmentRejected_${establishmentId}_${recipientUserId}`,
  establishmentTransferred: (
    establishmentId: string,
    recipientUserId: string,
  ) => `establishmentTransferred_${establishmentId}_${recipientUserId}`,
};

type Actor = {
  userId: string;
  username: string;
  displayName: string;
  avatarStyle?: string;
  avatarSeed?: string;
  avatarOptions?: Record<string, unknown>;
};

function base(
  recipientUserId: string,
  type: NotificationType,
  actor: Actor,
  title: string,
  body: string,
  createdAt: FirebaseFirestore.FieldValue,
  extra: Partial<NotificationDoc> = {},
): NotificationDoc {
  return {
    recipientUserId,
    type,
    actorUserId: actor.userId,
    actorUsername: actor.username,
    actorDisplayName: actor.displayName,
    actorAvatarStyle: actor.avatarStyle,
    actorAvatarSeed: actor.avatarSeed,
    actorAvatarOptions: actor.avatarOptions,
    title,
    body,
    read: false,
    createdAt,
    ...extra,
  };
}

export function buildFriendRequestNotification(args: {
  friendshipId: string;
  recipientUserId: string;
  actor: Actor;
  createdAt: FirebaseFirestore.FieldValue;
}): { id: string; data: NotificationDoc } {
  return {
    id: NotificationIds.friendRequest(args.friendshipId),
    data: base(
      args.recipientUserId,
      "friendRequest",
      args.actor,
      "Nueva solicitud",
      `@${args.actor.username} te envi\u00f3 una solicitud de amistad`,
      args.createdAt,
      { targetRoute: "/friends/requests" },
    ),
  };
}

export function buildFriendAcceptedNotification(args: {
  friendshipId: string;
  recipientUserId: string;
  actor: Actor;
  createdAt: FirebaseFirestore.FieldValue;
}): { id: string; data: NotificationDoc } {
  return {
    id: NotificationIds.friendAccepted(args.friendshipId),
    data: base(
      args.recipientUserId,
      "friendRequestAccepted",
      args.actor,
      "Solicitud aceptada",
      `@${args.actor.username} acept\u00f3 tu solicitud de amistad`,
      args.createdAt,
      { targetRoute: `/u/${args.actor.userId}` },
    ),
  };
}

export function buildChallengeInvitationNotification(args: {
  challengeId: string;
  recipientUserId: string;
  actor: Actor;
  createdAt: FirebaseFirestore.FieldValue;
  challengeTitle?: string;
}): { id: string; data: NotificationDoc } {
  const titleHint = args.challengeTitle?.trim()
    ? ` a ${args.challengeTitle.trim()}`
    : "";
  return {
    id: NotificationIds.challengeInvitation(
      args.challengeId,
      args.recipientUserId,
    ),
    data: base(
      args.recipientUserId,
      "challengeInvitation",
      args.actor,
      "Invitaci\u00f3n a reto",
      `@${args.actor.username} te invit\u00f3${titleHint}`,
      args.createdAt,
      {
        challengeId: args.challengeId,
        targetRoute: `/challenges/${args.challengeId}`,
      },
    ),
  };
}

export function buildFriendJoinedNotifications(args: {
  challengeId: string;
  actor: Actor;
  friendUserIds: string[];
  createdAt: FirebaseFirestore.FieldValue;
  categoryName?: string;
}): Array<{ id: string; data: NotificationDoc }> {
  const cat = args.categoryName ? ` de ${args.categoryName}` : "";
  return args.friendUserIds
    .filter((uid) => uid && uid !== args.actor.userId)
    .map((recipientUserId) => ({
      id: NotificationIds.friendJoined(
        args.challengeId,
        args.actor.userId,
        recipientUserId,
      ),
      data: base(
        recipientUserId,
        "friendJoinedChallenge",
        args.actor,
        "Amigo en un reto",
        `@${args.actor.username} se uni\u00f3 a un reto${cat}`,
        args.createdAt,
        {
          challengeId: args.challengeId,
          targetRoute: `/challenges/${args.challengeId}`,
          categoryName: args.categoryName ?? null,
        },
      ),
    }));
}

export function buildOfficialResultNotifications(args: {
  challengeId: string;
  categoryId: string;
  categoryName?: string;
  participants: Actor[];
  winnerIds: string[];
  recordEvents: Array<{
    userId: string;
    type: "recordCreated" | "recordBroken";
    score: number;
  }>;
  createdAt: FirebaseFirestore.FieldValue;
}): Array<{ id: string; data: NotificationDoc }> {
  const out: Array<{ id: string; data: NotificationDoc }> = [];
  const winners = new Set(args.winnerIds);
  const cat = args.categoryName ? ` de ${args.categoryName}` : "";
  const byId = new Map(args.participants.map((p) => [p.userId, p]));

  for (const p of args.participants) {
    out.push({
      id: NotificationIds.challengeCompleted(args.challengeId, p.userId),
      data: base(
        p.userId,
        "challengeCompleted",
        p,
        "Reto finalizado",
        `Tu reto${cat} ha terminado`,
        args.createdAt,
        {
          challengeId: args.challengeId,
          categoryId: args.categoryId,
          categoryName: args.categoryName ?? null,
          targetRoute: `/challenges/${args.challengeId}`,
        },
      ),
    });
    if (winners.has(p.userId)) {
      out.push({
        id: NotificationIds.challengeWon(args.challengeId, p.userId),
        data: base(
          p.userId,
          "challengeWon",
          p,
          "\u00a1Victoria!",
          `Ganaste el reto${cat}`,
          args.createdAt,
          {
            challengeId: args.challengeId,
            categoryId: args.categoryId,
            categoryName: args.categoryName ?? null,
            targetRoute: `/challenges/${args.challengeId}`,
          },
        ),
      });
    }
  }

  const seen = new Set<string>();
  for (const e of args.recordEvents) {
    const id =
      e.type === "recordBroken"
        ? NotificationIds.recordBroken(args.challengeId, e.userId)
        : NotificationIds.recordCreated(args.challengeId, e.userId);
    if (seen.has(id)) continue;
    seen.add(id);
    const actor = byId.get(e.userId);
    if (!actor) continue;
    out.push({
      id,
      data: base(
        e.userId,
        e.type,
        actor,
        e.type === "recordBroken" ? "R\u00e9cord superado" : "Nuevo r\u00e9cord",
        e.type === "recordBroken"
          ? `Superaste el r\u00e9cord${cat}`
          : `Conseguiste un nuevo r\u00e9cord${cat}`,
        args.createdAt,
        {
          challengeId: args.challengeId,
          categoryId: args.categoryId,
          categoryName: args.categoryName ?? null,
          recordId: id,
          targetRoute: `/challenges/${args.challengeId}`,
        },
      ),
    });
  }

  return out;
}

export function buildEstablishmentApprovedNotification(args: {
  establishmentId: string;
  recipientUserId: string;
  actorUserId: string;
  establishmentName: string;
  createdAt: FirebaseFirestore.FieldValue;
}): { id: string; data: NotificationDoc } {
  return {
    id: NotificationIds.establishmentApproved(
      args.establishmentId,
      args.recipientUserId,
    ),
    data: base(
      args.recipientUserId,
      "establishmentApproved",
      {
        userId: args.actorUserId,
        username: "admin",
        displayName: "FoodReto",
      },
      "Establecimiento aprobado",
      `"${args.establishmentName}" ya esta visible en Explorar`,
      args.createdAt,
      {
        targetRoute: `/establishments/mine`,
      },
    ),
  };
}

export function buildEstablishmentRejectedNotification(args: {
  establishmentId: string;
  recipientUserId: string;
  actorUserId: string;
  establishmentName: string;
  reason: string;
  createdAt: FirebaseFirestore.FieldValue;
}): { id: string; data: NotificationDoc } {
  return {
    id: NotificationIds.establishmentRejected(
      args.establishmentId,
      args.recipientUserId,
    ),
    data: base(
      args.recipientUserId,
      "establishmentRejected",
      {
        userId: args.actorUserId,
        username: "admin",
        displayName: "FoodReto",
      },
      "Solicitud rechazada",
      `"${args.establishmentName}": ${args.reason}`,
      args.createdAt,
      {
        targetRoute: `/establishments/mine`,
      },
    ),
  };
}

export function buildEstablishmentTransferredNotification(args: {
  establishmentId: string;
  recipientUserId: string;
  actorUserId: string;
  establishmentName: string;
  createdAt: FirebaseFirestore.FieldValue;
}): { id: string; data: NotificationDoc } {
  return {
    id: NotificationIds.establishmentTransferred(
      args.establishmentId,
      args.recipientUserId,
    ),
    data: base(
      args.recipientUserId,
      "establishmentTransferred",
      {
        userId: args.actorUserId,
        username: "admin",
        displayName: "FoodReto",
      },
      "Nuevo establecimiento",
      `Ahora eres dueno de "${args.establishmentName}"`,
      args.createdAt,
      {
        targetRoute: `/admin/establishments/${args.establishmentId}`,
      },
    ),
  };
}
