/// Estado de una relación social entre dos usuarios.
enum FriendshipStatus { pending, accepted, rejected, cancelled }

/// Relación A↔B en `friendships/{lowUid_highUid}`.
class Friendship {
  const Friendship({
    required this.id,
    required this.userIds,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.requester,
    required this.addressee,
    this.createdAt,
    this.updatedAt,
    this.acceptedAt,
  });

  final String id;
  final List<String> userIds;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final FriendProfileSnapshot requester;
  final FriendProfileSnapshot addressee;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;

  bool involves(String uid) => userIds.contains(uid);

  bool isPendingFor(String uid) =>
      status == FriendshipStatus.pending && addresseeId == uid;

  bool isOutgoingFrom(String uid) =>
      status == FriendshipStatus.pending && requesterId == uid;

  bool get isAccepted => status == FriendshipStatus.accepted;

  String otherUserId(String uid) =>
      uid == requesterId ? addresseeId : requesterId;

  FriendProfileSnapshot otherSnapshot(String uid) =>
      uid == requesterId ? addressee : requester;

  /// Id determinístico: `minUid_maxUid`.
  static String idFor(String a, String b) {
    if (a == b) {
      throw ArgumentError('Cannot create friendship with self');
    }
    return a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';
  }
}

/// Snapshot de presentación (no fuente oficial del perfil).
class FriendProfileSnapshot {
  const FriendProfileSnapshot({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarStyle,
    this.avatarSeed,
  });

  final String userId;
  final String username;
  final String displayName;
  final String? avatarStyle;
  final String? avatarSeed;
}

/// Estado de amistad visto desde el usuario actual hacia otro.
enum FriendshipRelation {
  none,
  outgoingPending,
  incomingPending,
  friends,
  self,
}
