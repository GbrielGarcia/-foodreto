enum ChallengeEventType {
  increment,
  decrement;

  static ChallengeEventType? fromId(Object? id) {
    for (final type in values) {
      if (type.name == id) return type;
    }
    return null;
  }

  int get delta => this == increment ? 1 : -1;
}

/// Evento del contador (`challenges/{id}/events/{clientEventId}`).
///
/// El ID lo genera el cliente antes de enviar; es la clave de idempotencia:
/// el mismo evento reenviado nunca se cuenta dos veces.
class ChallengeEvent {
  const ChallengeEvent({
    required this.clientEventId,
    required this.userId,
    required this.type,
    this.createdAt,
  });

  static const amount = 1;

  final String clientEventId;
  final String userId;
  final ChallengeEventType type;
  final DateTime? createdAt;

  int get delta => type.delta;
}

/// Reconstruye el total de cada participante a partir de sus eventos.
///
/// Es la fuente de verdad del resultado: `currentCount` es solo la proyección
/// rápida para la UI. Los eventos duplicados (mismo ID) se ignoran.
Map<String, int> tallyEvents(Iterable<ChallengeEvent> events) {
  final seen = <String>{};
  final totals = <String, int>{};
  for (final event in events) {
    if (!seen.add(event.clientEventId)) continue;
    totals[event.userId] = (totals[event.userId] ?? 0) + event.delta;
  }
  return totals;
}
