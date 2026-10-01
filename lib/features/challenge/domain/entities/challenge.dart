/// Ciclo de vida de un reto.
///
/// ```
/// draft ──► waiting ──► active ──► finished
///   │           │           │
///   └───────────┴───────────┴──► cancelled
/// ```
///
/// En la Fase 3 el formulario de creación hace de borrador: el reto se
/// persiste directamente en `waiting`. `draft` existe para que el modelo y las
/// transiciones estén completos cuando se guarden borradores.
enum ChallengeStatus {
  draft,
  waiting,
  active,
  finished,
  cancelled;

  static ChallengeStatus fromId(Object? id) => ChallengeStatus.values
      .firstWhere((s) => s.name == id, orElse: () => ChallengeStatus.cancelled);

  static const _transitions = <ChallengeStatus, Set<ChallengeStatus>>{
    draft: {waiting, cancelled},
    waiting: {active, cancelled},
    active: {finished, cancelled},
    finished: {},
    cancelled: {},
  };

  bool canTransitionTo(ChallengeStatus next) =>
      _transitions[this]!.contains(next);

  /// Terminado o cancelado: ya no admite cambios.
  bool get isClosed => this == finished || this == cancelled;

  /// Solo se puede entrar mientras el reto espera participantes.
  bool get acceptsParticipants => this == waiting;

  /// Solo se cuentan unidades con el reto en curso.
  bool get acceptsEvents => this == active;
}

/// Quién puede ver y encontrar el reto.
///
/// `friends` está reservado: hasta que exista el sistema de amistades se
/// comporta como `private` (solo con código) y la UI no lo ofrece.
enum ChallengeVisibility {
  private,
  friends,
  public;

  static ChallengeVisibility fromId(Object? id) =>
      ChallengeVisibility.values.firstWhere(
        (v) => v.name == id,
        orElse: () => ChallengeVisibility.private,
      );
}

/// Confirmación del compañero tras un reto en el mismo celular (solo amigos).
enum PartnerResultStatus {
  notRequired,
  pending,
  confirmed,
  rejected;

  static PartnerResultStatus fromId(Object? id) =>
      PartnerResultStatus.values.firstWhere(
        (s) => s.name == id,
        orElse: () => PartnerResultStatus.notRequired,
      );
}

/// Reto (`challenges/{id}`).
class Challenge {
  const Challenge({
    required this.id,
    required this.hostUserId,
    required this.categoryId,
    required this.inviteCode,
    required this.status,
    required this.maxParticipants,
    required this.participantIds,
    this.restaurantId,
    this.title = '',
    this.description = '',
    this.visibility = ChallengeVisibility.private,
    this.sameDevicePlay = false,
    this.sameDevicePartnerId,
    this.partnerResultStatus = PartnerResultStatus.notRequired,
    this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.updatedAt,
  });

  static const minParticipants = 1;

  /// Límite duro (también en `firestore.rules`, que verifica el resultado
  /// participante a participante).
  static const maxParticipantsLimit = 8;
  static const defaultMaxParticipants = 4;
  static const maxTitleLength = 60;
  static const maxDescriptionLength = 280;

  final String id;
  final String hostUserId;
  final String categoryId;
  final String? restaurantId;
  final String title;
  final String description;
  final String inviteCode;
  final ChallengeVisibility visibility;
  final ChallengeStatus status;
  final int maxParticipants;

  /// Copia de los uid de `participants/` para reglas y para "mis retos".
  final List<String> participantIds;

  /// Dos jugadores en un solo dispositivo (host cuenta por ambos).
  final bool sameDevicePlay;
  final String? sameDevicePartnerId;
  final PartnerResultStatus partnerResultStatus;

  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? updatedAt;

  bool isHost(String? uid) => uid != null && uid == hostUserId;
  bool isParticipant(String? uid) =>
      uid != null && participantIds.contains(uid);
  bool get isFull => participantIds.length >= maxParticipants;
  int get spotsLeft => maxParticipants - participantIds.length;
  bool isSameDevicePartner(String? uid) =>
      uid != null && sameDevicePartnerId == uid;

  /// Título a mostrar; si el host no puso uno, "Reto de {categoría}".
  String displayTitle(String? categoryName) {
    if (title.isNotEmpty) return title;
    return categoryName == null ? 'Reto' : 'Reto de $categoryName';
  }
}

/// Datos del formulario de creación.
class NewChallenge {
  const NewChallenge({
    required this.categoryId,
    this.restaurantId,
    this.title = '',
    this.description = '',
    this.visibility = ChallengeVisibility.private,
    this.maxParticipants = Challenge.defaultMaxParticipants,
    this.sameDevicePlay = false,
    this.sameDevicePartnerId,
    this.sameDevicePartnerIds = const [],
    this.sameDeviceGuestName,
    this.sameDeviceGuestEmail,
    this.sameDeviceGuestPassword,
  });

  final String categoryId;
  final String? restaurantId;
  final String title;
  final String description;
  final ChallengeVisibility visibility;
  final int maxParticipants;

  /// Jugar en el mismo celular (amigos o partida libre).
  final bool sameDevicePlay;
  final String? sameDevicePartnerId;
  final List<String> sameDevicePartnerIds;
  final String? sameDeviceGuestName;
  final String? sameDeviceGuestEmail;
  final String? sameDeviceGuestPassword;

  List<String> get resolvedPartnerIds {
    final ids = <String>{
      ...sameDevicePartnerIds,
      if (sameDevicePartnerId != null && sameDevicePartnerId!.isNotEmpty)
        sameDevicePartnerId!,
    };
    return ids.toList();
  }
}
