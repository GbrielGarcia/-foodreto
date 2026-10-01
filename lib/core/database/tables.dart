import 'package:drift/drift.dart';

/// Estados de un evento en la cola offline.
enum OutboxStatus { pending, syncing, synced, failed }

/// Cola de eventos del contador pendientes de Firestore.
class EventOutboxEntries extends Table {
  IntColumn get localId => integer().autoIncrement()();

  TextColumn get challengeId => text()();

  /// Idempotencia: mismo ID local y en Firestore.
  TextColumn get clientEventId => text().unique()();

  TextColumn get userId => text()();

  /// `increment` | `decrement`
  TextColumn get type => text()();

  IntColumn get amount => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();

  TextColumn get status => textEnum<OutboxStatus>()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  TextColumn get lastError => text().nullable()();

  DateTimeColumn get syncedAt => dateTime().nullable()();
}

/// Caché local del reto (lectura offline; Firestore sigue siendo remoto).
class ChallengesLocal extends Table {
  TextColumn get id => text()();

  TextColumn get hostUserId => text()();
  TextColumn get categoryId => text()();
  TextColumn get restaurantId => text().nullable()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get inviteCode => text()();
  TextColumn get visibility => text()();
  TextColumn get status => text()();
  IntColumn get maxParticipants => integer()();
  TextColumn get participantIdsJson =>
      text().withDefault(const Constant('[]'))();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Caché local de participantes (conteo remoto + overlay de outbox en UI).
class ParticipantsLocal extends Table {
  TextColumn get challengeId => text()();
  TextColumn get userId => text()();
  TextColumn get username => text()();
  TextColumn get displayName => text()();
  TextColumn get avatarStyle => text().nullable()();
  TextColumn get avatarSeed => text().nullable()();
  TextColumn get role => text()();
  TextColumn get status => text().withDefault(const Constant('joined'))();
  IntColumn get currentCount => integer().withDefault(const Constant(0))();
  TextColumn get lastEventId => text().nullable()();
  DateTimeColumn get joinedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {challengeId, userId};
}
