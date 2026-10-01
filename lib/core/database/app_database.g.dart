// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $EventOutboxEntriesTable extends EventOutboxEntries
    with TableInfo<$EventOutboxEntriesTable, EventOutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventOutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<int> localId = GeneratedColumn<int>(
    'local_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _challengeIdMeta = const VerificationMeta(
    'challengeId',
  );
  @override
  late final GeneratedColumn<String> challengeId = GeneratedColumn<String>(
    'challenge_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientEventIdMeta = const VerificationMeta(
    'clientEventId',
  );
  @override
  late final GeneratedColumn<String> clientEventId = GeneratedColumn<String>(
    'client_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<OutboxStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<OutboxStatus>($EventOutboxEntriesTable.$converterstatus);
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    challengeId,
    clientEventId,
    userId,
    type,
    amount,
    createdAt,
    status,
    attempts,
    lastAttemptAt,
    lastError,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_outbox_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventOutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    }
    if (data.containsKey('challenge_id')) {
      context.handle(
        _challengeIdMeta,
        challengeId.isAcceptableOrUnknown(
          data['challenge_id']!,
          _challengeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_challengeIdMeta);
    }
    if (data.containsKey('client_event_id')) {
      context.handle(
        _clientEventIdMeta,
        clientEventId.isAcceptableOrUnknown(
          data['client_event_id']!,
          _clientEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientEventIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  EventOutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventOutboxEntry(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_id'],
      )!,
      challengeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}challenge_id'],
      )!,
      clientEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_event_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      status: $EventOutboxEntriesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $EventOutboxEntriesTable createAlias(String alias) {
    return $EventOutboxEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OutboxStatus, String, String> $converterstatus =
      const EnumNameConverter<OutboxStatus>(OutboxStatus.values);
}

class EventOutboxEntry extends DataClass
    implements Insertable<EventOutboxEntry> {
  final int localId;
  final String challengeId;

  /// Idempotencia: mismo ID local y en Firestore.
  final String clientEventId;
  final String userId;

  /// `increment` | `decrement`
  final String type;
  final int amount;
  final DateTime createdAt;
  final OutboxStatus status;
  final int attempts;
  final DateTime? lastAttemptAt;
  final String? lastError;
  final DateTime? syncedAt;
  const EventOutboxEntry({
    required this.localId,
    required this.challengeId,
    required this.clientEventId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.createdAt,
    required this.status,
    required this.attempts,
    this.lastAttemptAt,
    this.lastError,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<int>(localId);
    map['challenge_id'] = Variable<String>(challengeId);
    map['client_event_id'] = Variable<String>(clientEventId);
    map['user_id'] = Variable<String>(userId);
    map['type'] = Variable<String>(type);
    map['amount'] = Variable<int>(amount);
    map['created_at'] = Variable<DateTime>(createdAt);
    {
      map['status'] = Variable<String>(
        $EventOutboxEntriesTable.$converterstatus.toSql(status),
      );
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  EventOutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return EventOutboxEntriesCompanion(
      localId: Value(localId),
      challengeId: Value(challengeId),
      clientEventId: Value(clientEventId),
      userId: Value(userId),
      type: Value(type),
      amount: Value(amount),
      createdAt: Value(createdAt),
      status: Value(status),
      attempts: Value(attempts),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory EventOutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventOutboxEntry(
      localId: serializer.fromJson<int>(json['localId']),
      challengeId: serializer.fromJson<String>(json['challengeId']),
      clientEventId: serializer.fromJson<String>(json['clientEventId']),
      userId: serializer.fromJson<String>(json['userId']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<int>(json['amount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: $EventOutboxEntriesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<int>(localId),
      'challengeId': serializer.toJson<String>(challengeId),
      'clientEventId': serializer.toJson<String>(clientEventId),
      'userId': serializer.toJson<String>(userId),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<int>(amount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer.toJson<String>(
        $EventOutboxEntriesTable.$converterstatus.toJson(status),
      ),
      'attempts': serializer.toJson<int>(attempts),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  EventOutboxEntry copyWith({
    int? localId,
    String? challengeId,
    String? clientEventId,
    String? userId,
    String? type,
    int? amount,
    DateTime? createdAt,
    OutboxStatus? status,
    int? attempts,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => EventOutboxEntry(
    localId: localId ?? this.localId,
    challengeId: challengeId ?? this.challengeId,
    clientEventId: clientEventId ?? this.clientEventId,
    userId: userId ?? this.userId,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  EventOutboxEntry copyWithCompanion(EventOutboxEntriesCompanion data) {
    return EventOutboxEntry(
      localId: data.localId.present ? data.localId.value : this.localId,
      challengeId: data.challengeId.present
          ? data.challengeId.value
          : this.challengeId,
      clientEventId: data.clientEventId.present
          ? data.clientEventId.value
          : this.clientEventId,
      userId: data.userId.present ? data.userId.value : this.userId,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventOutboxEntry(')
          ..write('localId: $localId, ')
          ..write('challengeId: $challengeId, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    challengeId,
    clientEventId,
    userId,
    type,
    amount,
    createdAt,
    status,
    attempts,
    lastAttemptAt,
    lastError,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventOutboxEntry &&
          other.localId == this.localId &&
          other.challengeId == this.challengeId &&
          other.clientEventId == this.clientEventId &&
          other.userId == this.userId &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.lastError == this.lastError &&
          other.syncedAt == this.syncedAt);
}

class EventOutboxEntriesCompanion extends UpdateCompanion<EventOutboxEntry> {
  final Value<int> localId;
  final Value<String> challengeId;
  final Value<String> clientEventId;
  final Value<String> userId;
  final Value<String> type;
  final Value<int> amount;
  final Value<DateTime> createdAt;
  final Value<OutboxStatus> status;
  final Value<int> attempts;
  final Value<DateTime?> lastAttemptAt;
  final Value<String?> lastError;
  final Value<DateTime?> syncedAt;
  const EventOutboxEntriesCompanion({
    this.localId = const Value.absent(),
    this.challengeId = const Value.absent(),
    this.clientEventId = const Value.absent(),
    this.userId = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  EventOutboxEntriesCompanion.insert({
    this.localId = const Value.absent(),
    required String challengeId,
    required String clientEventId,
    required String userId,
    required String type,
    this.amount = const Value.absent(),
    required DateTime createdAt,
    required OutboxStatus status,
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.syncedAt = const Value.absent(),
  }) : challengeId = Value(challengeId),
       clientEventId = Value(clientEventId),
       userId = Value(userId),
       type = Value(type),
       createdAt = Value(createdAt),
       status = Value(status);
  static Insertable<EventOutboxEntry> custom({
    Expression<int>? localId,
    Expression<String>? challengeId,
    Expression<String>? clientEventId,
    Expression<String>? userId,
    Expression<String>? type,
    Expression<int>? amount,
    Expression<DateTime>? createdAt,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<DateTime>? lastAttemptAt,
    Expression<String>? lastError,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (challengeId != null) 'challenge_id': challengeId,
      if (clientEventId != null) 'client_event_id': clientEventId,
      if (userId != null) 'user_id': userId,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  EventOutboxEntriesCompanion copyWith({
    Value<int>? localId,
    Value<String>? challengeId,
    Value<String>? clientEventId,
    Value<String>? userId,
    Value<String>? type,
    Value<int>? amount,
    Value<DateTime>? createdAt,
    Value<OutboxStatus>? status,
    Value<int>? attempts,
    Value<DateTime?>? lastAttemptAt,
    Value<String?>? lastError,
    Value<DateTime?>? syncedAt,
  }) {
    return EventOutboxEntriesCompanion(
      localId: localId ?? this.localId,
      challengeId: challengeId ?? this.challengeId,
      clientEventId: clientEventId ?? this.clientEventId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<int>(localId.value);
    }
    if (challengeId.present) {
      map['challenge_id'] = Variable<String>(challengeId.value);
    }
    if (clientEventId.present) {
      map['client_event_id'] = Variable<String>(clientEventId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $EventOutboxEntriesTable.$converterstatus.toSql(status.value),
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventOutboxEntriesCompanion(')
          ..write('localId: $localId, ')
          ..write('challengeId: $challengeId, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $ChallengesLocalTable extends ChallengesLocal
    with TableInfo<$ChallengesLocalTable, ChallengesLocalData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChallengesLocalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostUserIdMeta = const VerificationMeta(
    'hostUserId',
  );
  @override
  late final GeneratedColumn<String> hostUserId = GeneratedColumn<String>(
    'host_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restaurantIdMeta = const VerificationMeta(
    'restaurantId',
  );
  @override
  late final GeneratedColumn<String> restaurantId = GeneratedColumn<String>(
    'restaurant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _inviteCodeMeta = const VerificationMeta(
    'inviteCode',
  );
  @override
  late final GeneratedColumn<String> inviteCode = GeneratedColumn<String>(
    'invite_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  @override
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
    'visibility',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxParticipantsMeta = const VerificationMeta(
    'maxParticipants',
  );
  @override
  late final GeneratedColumn<int> maxParticipants = GeneratedColumn<int>(
    'max_participants',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _participantIdsJsonMeta =
      const VerificationMeta('participantIdsJson');
  @override
  late final GeneratedColumn<String> participantIdsJson =
      GeneratedColumn<String>(
        'participant_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    hostUserId,
    categoryId,
    restaurantId,
    title,
    description,
    inviteCode,
    visibility,
    status,
    maxParticipants,
    participantIdsJson,
    createdAt,
    startedAt,
    finishedAt,
    updatedAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'challenges_local';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChallengesLocalData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('host_user_id')) {
      context.handle(
        _hostUserIdMeta,
        hostUserId.isAcceptableOrUnknown(
          data['host_user_id']!,
          _hostUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hostUserIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('restaurant_id')) {
      context.handle(
        _restaurantIdMeta,
        restaurantId.isAcceptableOrUnknown(
          data['restaurant_id']!,
          _restaurantIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('invite_code')) {
      context.handle(
        _inviteCodeMeta,
        inviteCode.isAcceptableOrUnknown(data['invite_code']!, _inviteCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_inviteCodeMeta);
    }
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    } else if (isInserting) {
      context.missing(_visibilityMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('max_participants')) {
      context.handle(
        _maxParticipantsMeta,
        maxParticipants.isAcceptableOrUnknown(
          data['max_participants']!,
          _maxParticipantsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxParticipantsMeta);
    }
    if (data.containsKey('participant_ids_json')) {
      context.handle(
        _participantIdsJsonMeta,
        participantIdsJson.isAcceptableOrUnknown(
          data['participant_ids_json']!,
          _participantIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChallengesLocalData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChallengesLocalData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      hostUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_user_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      restaurantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}restaurant_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      inviteCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invite_code'],
      )!,
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visibility'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      maxParticipants: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_participants'],
      )!,
      participantIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}participant_ids_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $ChallengesLocalTable createAlias(String alias) {
    return $ChallengesLocalTable(attachedDatabase, alias);
  }
}

class ChallengesLocalData extends DataClass
    implements Insertable<ChallengesLocalData> {
  final String id;
  final String hostUserId;
  final String categoryId;
  final String? restaurantId;
  final String title;
  final String description;
  final String inviteCode;
  final String visibility;
  final String status;
  final int maxParticipants;
  final String participantIdsJson;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? updatedAt;
  final DateTime syncedAt;
  const ChallengesLocalData({
    required this.id,
    required this.hostUserId,
    required this.categoryId,
    this.restaurantId,
    required this.title,
    required this.description,
    required this.inviteCode,
    required this.visibility,
    required this.status,
    required this.maxParticipants,
    required this.participantIdsJson,
    this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.updatedAt,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['host_user_id'] = Variable<String>(hostUserId);
    map['category_id'] = Variable<String>(categoryId);
    if (!nullToAbsent || restaurantId != null) {
      map['restaurant_id'] = Variable<String>(restaurantId);
    }
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['invite_code'] = Variable<String>(inviteCode);
    map['visibility'] = Variable<String>(visibility);
    map['status'] = Variable<String>(status);
    map['max_participants'] = Variable<int>(maxParticipants);
    map['participant_ids_json'] = Variable<String>(participantIdsJson);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  ChallengesLocalCompanion toCompanion(bool nullToAbsent) {
    return ChallengesLocalCompanion(
      id: Value(id),
      hostUserId: Value(hostUserId),
      categoryId: Value(categoryId),
      restaurantId: restaurantId == null && nullToAbsent
          ? const Value.absent()
          : Value(restaurantId),
      title: Value(title),
      description: Value(description),
      inviteCode: Value(inviteCode),
      visibility: Value(visibility),
      status: Value(status),
      maxParticipants: Value(maxParticipants),
      participantIdsJson: Value(participantIdsJson),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      syncedAt: Value(syncedAt),
    );
  }

  factory ChallengesLocalData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChallengesLocalData(
      id: serializer.fromJson<String>(json['id']),
      hostUserId: serializer.fromJson<String>(json['hostUserId']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      restaurantId: serializer.fromJson<String?>(json['restaurantId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      inviteCode: serializer.fromJson<String>(json['inviteCode']),
      visibility: serializer.fromJson<String>(json['visibility']),
      status: serializer.fromJson<String>(json['status']),
      maxParticipants: serializer.fromJson<int>(json['maxParticipants']),
      participantIdsJson: serializer.fromJson<String>(
        json['participantIdsJson'],
      ),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hostUserId': serializer.toJson<String>(hostUserId),
      'categoryId': serializer.toJson<String>(categoryId),
      'restaurantId': serializer.toJson<String?>(restaurantId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'inviteCode': serializer.toJson<String>(inviteCode),
      'visibility': serializer.toJson<String>(visibility),
      'status': serializer.toJson<String>(status),
      'maxParticipants': serializer.toJson<int>(maxParticipants),
      'participantIdsJson': serializer.toJson<String>(participantIdsJson),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  ChallengesLocalData copyWith({
    String? id,
    String? hostUserId,
    String? categoryId,
    Value<String?> restaurantId = const Value.absent(),
    String? title,
    String? description,
    String? inviteCode,
    String? visibility,
    String? status,
    int? maxParticipants,
    String? participantIdsJson,
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> finishedAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    DateTime? syncedAt,
  }) => ChallengesLocalData(
    id: id ?? this.id,
    hostUserId: hostUserId ?? this.hostUserId,
    categoryId: categoryId ?? this.categoryId,
    restaurantId: restaurantId.present ? restaurantId.value : this.restaurantId,
    title: title ?? this.title,
    description: description ?? this.description,
    inviteCode: inviteCode ?? this.inviteCode,
    visibility: visibility ?? this.visibility,
    status: status ?? this.status,
    maxParticipants: maxParticipants ?? this.maxParticipants,
    participantIdsJson: participantIdsJson ?? this.participantIdsJson,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  ChallengesLocalData copyWithCompanion(ChallengesLocalCompanion data) {
    return ChallengesLocalData(
      id: data.id.present ? data.id.value : this.id,
      hostUserId: data.hostUserId.present
          ? data.hostUserId.value
          : this.hostUserId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      restaurantId: data.restaurantId.present
          ? data.restaurantId.value
          : this.restaurantId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      inviteCode: data.inviteCode.present
          ? data.inviteCode.value
          : this.inviteCode,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      status: data.status.present ? data.status.value : this.status,
      maxParticipants: data.maxParticipants.present
          ? data.maxParticipants.value
          : this.maxParticipants,
      participantIdsJson: data.participantIdsJson.present
          ? data.participantIdsJson.value
          : this.participantIdsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChallengesLocalData(')
          ..write('id: $id, ')
          ..write('hostUserId: $hostUserId, ')
          ..write('categoryId: $categoryId, ')
          ..write('restaurantId: $restaurantId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('inviteCode: $inviteCode, ')
          ..write('visibility: $visibility, ')
          ..write('status: $status, ')
          ..write('maxParticipants: $maxParticipants, ')
          ..write('participantIdsJson: $participantIdsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    hostUserId,
    categoryId,
    restaurantId,
    title,
    description,
    inviteCode,
    visibility,
    status,
    maxParticipants,
    participantIdsJson,
    createdAt,
    startedAt,
    finishedAt,
    updatedAt,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChallengesLocalData &&
          other.id == this.id &&
          other.hostUserId == this.hostUserId &&
          other.categoryId == this.categoryId &&
          other.restaurantId == this.restaurantId &&
          other.title == this.title &&
          other.description == this.description &&
          other.inviteCode == this.inviteCode &&
          other.visibility == this.visibility &&
          other.status == this.status &&
          other.maxParticipants == this.maxParticipants &&
          other.participantIdsJson == this.participantIdsJson &&
          other.createdAt == this.createdAt &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.updatedAt == this.updatedAt &&
          other.syncedAt == this.syncedAt);
}

class ChallengesLocalCompanion extends UpdateCompanion<ChallengesLocalData> {
  final Value<String> id;
  final Value<String> hostUserId;
  final Value<String> categoryId;
  final Value<String?> restaurantId;
  final Value<String> title;
  final Value<String> description;
  final Value<String> inviteCode;
  final Value<String> visibility;
  final Value<String> status;
  final Value<int> maxParticipants;
  final Value<String> participantIdsJson;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const ChallengesLocalCompanion({
    this.id = const Value.absent(),
    this.hostUserId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.restaurantId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.inviteCode = const Value.absent(),
    this.visibility = const Value.absent(),
    this.status = const Value.absent(),
    this.maxParticipants = const Value.absent(),
    this.participantIdsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChallengesLocalCompanion.insert({
    required String id,
    required String hostUserId,
    required String categoryId,
    this.restaurantId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    required String inviteCode,
    required String visibility,
    required String status,
    required int maxParticipants,
    this.participantIdsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       hostUserId = Value(hostUserId),
       categoryId = Value(categoryId),
       inviteCode = Value(inviteCode),
       visibility = Value(visibility),
       status = Value(status),
       maxParticipants = Value(maxParticipants),
       syncedAt = Value(syncedAt);
  static Insertable<ChallengesLocalData> custom({
    Expression<String>? id,
    Expression<String>? hostUserId,
    Expression<String>? categoryId,
    Expression<String>? restaurantId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? inviteCode,
    Expression<String>? visibility,
    Expression<String>? status,
    Expression<int>? maxParticipants,
    Expression<String>? participantIdsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hostUserId != null) 'host_user_id': hostUserId,
      if (categoryId != null) 'category_id': categoryId,
      if (restaurantId != null) 'restaurant_id': restaurantId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (inviteCode != null) 'invite_code': inviteCode,
      if (visibility != null) 'visibility': visibility,
      if (status != null) 'status': status,
      if (maxParticipants != null) 'max_participants': maxParticipants,
      if (participantIdsJson != null)
        'participant_ids_json': participantIdsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChallengesLocalCompanion copyWith({
    Value<String>? id,
    Value<String>? hostUserId,
    Value<String>? categoryId,
    Value<String?>? restaurantId,
    Value<String>? title,
    Value<String>? description,
    Value<String>? inviteCode,
    Value<String>? visibility,
    Value<String>? status,
    Value<int>? maxParticipants,
    Value<String>? participantIdsJson,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<DateTime?>? updatedAt,
    Value<DateTime>? syncedAt,
    Value<int>? rowid,
  }) {
    return ChallengesLocalCompanion(
      id: id ?? this.id,
      hostUserId: hostUserId ?? this.hostUserId,
      categoryId: categoryId ?? this.categoryId,
      restaurantId: restaurantId ?? this.restaurantId,
      title: title ?? this.title,
      description: description ?? this.description,
      inviteCode: inviteCode ?? this.inviteCode,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participantIdsJson: participantIdsJson ?? this.participantIdsJson,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (hostUserId.present) {
      map['host_user_id'] = Variable<String>(hostUserId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (restaurantId.present) {
      map['restaurant_id'] = Variable<String>(restaurantId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (inviteCode.present) {
      map['invite_code'] = Variable<String>(inviteCode.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (maxParticipants.present) {
      map['max_participants'] = Variable<int>(maxParticipants.value);
    }
    if (participantIdsJson.present) {
      map['participant_ids_json'] = Variable<String>(participantIdsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChallengesLocalCompanion(')
          ..write('id: $id, ')
          ..write('hostUserId: $hostUserId, ')
          ..write('categoryId: $categoryId, ')
          ..write('restaurantId: $restaurantId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('inviteCode: $inviteCode, ')
          ..write('visibility: $visibility, ')
          ..write('status: $status, ')
          ..write('maxParticipants: $maxParticipants, ')
          ..write('participantIdsJson: $participantIdsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ParticipantsLocalTable extends ParticipantsLocal
    with TableInfo<$ParticipantsLocalTable, ParticipantsLocalData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParticipantsLocalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _challengeIdMeta = const VerificationMeta(
    'challengeId',
  );
  @override
  late final GeneratedColumn<String> challengeId = GeneratedColumn<String>(
    'challenge_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarStyleMeta = const VerificationMeta(
    'avatarStyle',
  );
  @override
  late final GeneratedColumn<String> avatarStyle = GeneratedColumn<String>(
    'avatar_style',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarSeedMeta = const VerificationMeta(
    'avatarSeed',
  );
  @override
  late final GeneratedColumn<String> avatarSeed = GeneratedColumn<String>(
    'avatar_seed',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('joined'),
  );
  static const VerificationMeta _currentCountMeta = const VerificationMeta(
    'currentCount',
  );
  @override
  late final GeneratedColumn<int> currentCount = GeneratedColumn<int>(
    'current_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastEventIdMeta = const VerificationMeta(
    'lastEventId',
  );
  @override
  late final GeneratedColumn<String> lastEventId = GeneratedColumn<String>(
    'last_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _joinedAtMeta = const VerificationMeta(
    'joinedAt',
  );
  @override
  late final GeneratedColumn<DateTime> joinedAt = GeneratedColumn<DateTime>(
    'joined_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    challengeId,
    userId,
    username,
    displayName,
    avatarStyle,
    avatarSeed,
    role,
    status,
    currentCount,
    lastEventId,
    joinedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'participants_local';
  @override
  VerificationContext validateIntegrity(
    Insertable<ParticipantsLocalData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('challenge_id')) {
      context.handle(
        _challengeIdMeta,
        challengeId.isAcceptableOrUnknown(
          data['challenge_id']!,
          _challengeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_challengeIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('avatar_style')) {
      context.handle(
        _avatarStyleMeta,
        avatarStyle.isAcceptableOrUnknown(
          data['avatar_style']!,
          _avatarStyleMeta,
        ),
      );
    }
    if (data.containsKey('avatar_seed')) {
      context.handle(
        _avatarSeedMeta,
        avatarSeed.isAcceptableOrUnknown(data['avatar_seed']!, _avatarSeedMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('current_count')) {
      context.handle(
        _currentCountMeta,
        currentCount.isAcceptableOrUnknown(
          data['current_count']!,
          _currentCountMeta,
        ),
      );
    }
    if (data.containsKey('last_event_id')) {
      context.handle(
        _lastEventIdMeta,
        lastEventId.isAcceptableOrUnknown(
          data['last_event_id']!,
          _lastEventIdMeta,
        ),
      );
    }
    if (data.containsKey('joined_at')) {
      context.handle(
        _joinedAtMeta,
        joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {challengeId, userId};
  @override
  ParticipantsLocalData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParticipantsLocalData(
      challengeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}challenge_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      avatarStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_style'],
      ),
      avatarSeed: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_seed'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      currentCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_count'],
      )!,
      lastEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_event_id'],
      ),
      joinedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}joined_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ParticipantsLocalTable createAlias(String alias) {
    return $ParticipantsLocalTable(attachedDatabase, alias);
  }
}

class ParticipantsLocalData extends DataClass
    implements Insertable<ParticipantsLocalData> {
  final String challengeId;
  final String userId;
  final String username;
  final String displayName;
  final String? avatarStyle;
  final String? avatarSeed;
  final String role;
  final String status;
  final int currentCount;
  final String? lastEventId;
  final DateTime? joinedAt;
  final DateTime updatedAt;
  const ParticipantsLocalData({
    required this.challengeId,
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarStyle,
    this.avatarSeed,
    required this.role,
    required this.status,
    required this.currentCount,
    this.lastEventId,
    this.joinedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['challenge_id'] = Variable<String>(challengeId);
    map['user_id'] = Variable<String>(userId);
    map['username'] = Variable<String>(username);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || avatarStyle != null) {
      map['avatar_style'] = Variable<String>(avatarStyle);
    }
    if (!nullToAbsent || avatarSeed != null) {
      map['avatar_seed'] = Variable<String>(avatarSeed);
    }
    map['role'] = Variable<String>(role);
    map['status'] = Variable<String>(status);
    map['current_count'] = Variable<int>(currentCount);
    if (!nullToAbsent || lastEventId != null) {
      map['last_event_id'] = Variable<String>(lastEventId);
    }
    if (!nullToAbsent || joinedAt != null) {
      map['joined_at'] = Variable<DateTime>(joinedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ParticipantsLocalCompanion toCompanion(bool nullToAbsent) {
    return ParticipantsLocalCompanion(
      challengeId: Value(challengeId),
      userId: Value(userId),
      username: Value(username),
      displayName: Value(displayName),
      avatarStyle: avatarStyle == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarStyle),
      avatarSeed: avatarSeed == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarSeed),
      role: Value(role),
      status: Value(status),
      currentCount: Value(currentCount),
      lastEventId: lastEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEventId),
      joinedAt: joinedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(joinedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ParticipantsLocalData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParticipantsLocalData(
      challengeId: serializer.fromJson<String>(json['challengeId']),
      userId: serializer.fromJson<String>(json['userId']),
      username: serializer.fromJson<String>(json['username']),
      displayName: serializer.fromJson<String>(json['displayName']),
      avatarStyle: serializer.fromJson<String?>(json['avatarStyle']),
      avatarSeed: serializer.fromJson<String?>(json['avatarSeed']),
      role: serializer.fromJson<String>(json['role']),
      status: serializer.fromJson<String>(json['status']),
      currentCount: serializer.fromJson<int>(json['currentCount']),
      lastEventId: serializer.fromJson<String?>(json['lastEventId']),
      joinedAt: serializer.fromJson<DateTime?>(json['joinedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'challengeId': serializer.toJson<String>(challengeId),
      'userId': serializer.toJson<String>(userId),
      'username': serializer.toJson<String>(username),
      'displayName': serializer.toJson<String>(displayName),
      'avatarStyle': serializer.toJson<String?>(avatarStyle),
      'avatarSeed': serializer.toJson<String?>(avatarSeed),
      'role': serializer.toJson<String>(role),
      'status': serializer.toJson<String>(status),
      'currentCount': serializer.toJson<int>(currentCount),
      'lastEventId': serializer.toJson<String?>(lastEventId),
      'joinedAt': serializer.toJson<DateTime?>(joinedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ParticipantsLocalData copyWith({
    String? challengeId,
    String? userId,
    String? username,
    String? displayName,
    Value<String?> avatarStyle = const Value.absent(),
    Value<String?> avatarSeed = const Value.absent(),
    String? role,
    String? status,
    int? currentCount,
    Value<String?> lastEventId = const Value.absent(),
    Value<DateTime?> joinedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => ParticipantsLocalData(
    challengeId: challengeId ?? this.challengeId,
    userId: userId ?? this.userId,
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    avatarStyle: avatarStyle.present ? avatarStyle.value : this.avatarStyle,
    avatarSeed: avatarSeed.present ? avatarSeed.value : this.avatarSeed,
    role: role ?? this.role,
    status: status ?? this.status,
    currentCount: currentCount ?? this.currentCount,
    lastEventId: lastEventId.present ? lastEventId.value : this.lastEventId,
    joinedAt: joinedAt.present ? joinedAt.value : this.joinedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ParticipantsLocalData copyWithCompanion(ParticipantsLocalCompanion data) {
    return ParticipantsLocalData(
      challengeId: data.challengeId.present
          ? data.challengeId.value
          : this.challengeId,
      userId: data.userId.present ? data.userId.value : this.userId,
      username: data.username.present ? data.username.value : this.username,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      avatarStyle: data.avatarStyle.present
          ? data.avatarStyle.value
          : this.avatarStyle,
      avatarSeed: data.avatarSeed.present
          ? data.avatarSeed.value
          : this.avatarSeed,
      role: data.role.present ? data.role.value : this.role,
      status: data.status.present ? data.status.value : this.status,
      currentCount: data.currentCount.present
          ? data.currentCount.value
          : this.currentCount,
      lastEventId: data.lastEventId.present
          ? data.lastEventId.value
          : this.lastEventId,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParticipantsLocalData(')
          ..write('challengeId: $challengeId, ')
          ..write('userId: $userId, ')
          ..write('username: $username, ')
          ..write('displayName: $displayName, ')
          ..write('avatarStyle: $avatarStyle, ')
          ..write('avatarSeed: $avatarSeed, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('currentCount: $currentCount, ')
          ..write('lastEventId: $lastEventId, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    challengeId,
    userId,
    username,
    displayName,
    avatarStyle,
    avatarSeed,
    role,
    status,
    currentCount,
    lastEventId,
    joinedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParticipantsLocalData &&
          other.challengeId == this.challengeId &&
          other.userId == this.userId &&
          other.username == this.username &&
          other.displayName == this.displayName &&
          other.avatarStyle == this.avatarStyle &&
          other.avatarSeed == this.avatarSeed &&
          other.role == this.role &&
          other.status == this.status &&
          other.currentCount == this.currentCount &&
          other.lastEventId == this.lastEventId &&
          other.joinedAt == this.joinedAt &&
          other.updatedAt == this.updatedAt);
}

class ParticipantsLocalCompanion
    extends UpdateCompanion<ParticipantsLocalData> {
  final Value<String> challengeId;
  final Value<String> userId;
  final Value<String> username;
  final Value<String> displayName;
  final Value<String?> avatarStyle;
  final Value<String?> avatarSeed;
  final Value<String> role;
  final Value<String> status;
  final Value<int> currentCount;
  final Value<String?> lastEventId;
  final Value<DateTime?> joinedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ParticipantsLocalCompanion({
    this.challengeId = const Value.absent(),
    this.userId = const Value.absent(),
    this.username = const Value.absent(),
    this.displayName = const Value.absent(),
    this.avatarStyle = const Value.absent(),
    this.avatarSeed = const Value.absent(),
    this.role = const Value.absent(),
    this.status = const Value.absent(),
    this.currentCount = const Value.absent(),
    this.lastEventId = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ParticipantsLocalCompanion.insert({
    required String challengeId,
    required String userId,
    required String username,
    required String displayName,
    this.avatarStyle = const Value.absent(),
    this.avatarSeed = const Value.absent(),
    required String role,
    this.status = const Value.absent(),
    this.currentCount = const Value.absent(),
    this.lastEventId = const Value.absent(),
    this.joinedAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : challengeId = Value(challengeId),
       userId = Value(userId),
       username = Value(username),
       displayName = Value(displayName),
       role = Value(role),
       updatedAt = Value(updatedAt);
  static Insertable<ParticipantsLocalData> custom({
    Expression<String>? challengeId,
    Expression<String>? userId,
    Expression<String>? username,
    Expression<String>? displayName,
    Expression<String>? avatarStyle,
    Expression<String>? avatarSeed,
    Expression<String>? role,
    Expression<String>? status,
    Expression<int>? currentCount,
    Expression<String>? lastEventId,
    Expression<DateTime>? joinedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (challengeId != null) 'challenge_id': challengeId,
      if (userId != null) 'user_id': userId,
      if (username != null) 'username': username,
      if (displayName != null) 'display_name': displayName,
      if (avatarStyle != null) 'avatar_style': avatarStyle,
      if (avatarSeed != null) 'avatar_seed': avatarSeed,
      if (role != null) 'role': role,
      if (status != null) 'status': status,
      if (currentCount != null) 'current_count': currentCount,
      if (lastEventId != null) 'last_event_id': lastEventId,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ParticipantsLocalCompanion copyWith({
    Value<String>? challengeId,
    Value<String>? userId,
    Value<String>? username,
    Value<String>? displayName,
    Value<String?>? avatarStyle,
    Value<String?>? avatarSeed,
    Value<String>? role,
    Value<String>? status,
    Value<int>? currentCount,
    Value<String?>? lastEventId,
    Value<DateTime?>? joinedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ParticipantsLocalCompanion(
      challengeId: challengeId ?? this.challengeId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarStyle: avatarStyle ?? this.avatarStyle,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      role: role ?? this.role,
      status: status ?? this.status,
      currentCount: currentCount ?? this.currentCount,
      lastEventId: lastEventId ?? this.lastEventId,
      joinedAt: joinedAt ?? this.joinedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (challengeId.present) {
      map['challenge_id'] = Variable<String>(challengeId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (avatarStyle.present) {
      map['avatar_style'] = Variable<String>(avatarStyle.value);
    }
    if (avatarSeed.present) {
      map['avatar_seed'] = Variable<String>(avatarSeed.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (currentCount.present) {
      map['current_count'] = Variable<int>(currentCount.value);
    }
    if (lastEventId.present) {
      map['last_event_id'] = Variable<String>(lastEventId.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<DateTime>(joinedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParticipantsLocalCompanion(')
          ..write('challengeId: $challengeId, ')
          ..write('userId: $userId, ')
          ..write('username: $username, ')
          ..write('displayName: $displayName, ')
          ..write('avatarStyle: $avatarStyle, ')
          ..write('avatarSeed: $avatarSeed, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('currentCount: $currentCount, ')
          ..write('lastEventId: $lastEventId, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EventOutboxEntriesTable eventOutboxEntries =
      $EventOutboxEntriesTable(this);
  late final $ChallengesLocalTable challengesLocal = $ChallengesLocalTable(
    this,
  );
  late final $ParticipantsLocalTable participantsLocal =
      $ParticipantsLocalTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    eventOutboxEntries,
    challengesLocal,
    participantsLocal,
  ];
}

typedef $$EventOutboxEntriesTableCreateCompanionBuilder =
    EventOutboxEntriesCompanion Function({
      Value<int> localId,
      required String challengeId,
      required String clientEventId,
      required String userId,
      required String type,
      Value<int> amount,
      required DateTime createdAt,
      required OutboxStatus status,
      Value<int> attempts,
      Value<DateTime?> lastAttemptAt,
      Value<String?> lastError,
      Value<DateTime?> syncedAt,
    });
typedef $$EventOutboxEntriesTableUpdateCompanionBuilder =
    EventOutboxEntriesCompanion Function({
      Value<int> localId,
      Value<String> challengeId,
      Value<String> clientEventId,
      Value<String> userId,
      Value<String> type,
      Value<int> amount,
      Value<DateTime> createdAt,
      Value<OutboxStatus> status,
      Value<int> attempts,
      Value<DateTime?> lastAttemptAt,
      Value<String?> lastError,
      Value<DateTime?> syncedAt,
    });

class $$EventOutboxEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EventOutboxEntriesTable> {
  $$EventOutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get challengeId => $composableBuilder(
    column: $table.challengeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OutboxStatus, OutboxStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventOutboxEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EventOutboxEntriesTable> {
  $$EventOutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get challengeId => $composableBuilder(
    column: $table.challengeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventOutboxEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventOutboxEntriesTable> {
  $$EventOutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get challengeId => $composableBuilder(
    column: $table.challengeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OutboxStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$EventOutboxEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventOutboxEntriesTable,
          EventOutboxEntry,
          $$EventOutboxEntriesTableFilterComposer,
          $$EventOutboxEntriesTableOrderingComposer,
          $$EventOutboxEntriesTableAnnotationComposer,
          $$EventOutboxEntriesTableCreateCompanionBuilder,
          $$EventOutboxEntriesTableUpdateCompanionBuilder,
          (
            EventOutboxEntry,
            BaseReferences<
              _$AppDatabase,
              $EventOutboxEntriesTable,
              EventOutboxEntry
            >,
          ),
          EventOutboxEntry,
          PrefetchHooks Function()
        > {
  $$EventOutboxEntriesTableTableManager(
    _$AppDatabase db,
    $EventOutboxEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventOutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventOutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventOutboxEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> localId = const Value.absent(),
                Value<String> challengeId = const Value.absent(),
                Value<String> clientEventId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<OutboxStatus> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
              }) => EventOutboxEntriesCompanion(
                localId: localId,
                challengeId: challengeId,
                clientEventId: clientEventId,
                userId: userId,
                type: type,
                amount: amount,
                createdAt: createdAt,
                status: status,
                attempts: attempts,
                lastAttemptAt: lastAttemptAt,
                lastError: lastError,
                syncedAt: syncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> localId = const Value.absent(),
                required String challengeId,
                required String clientEventId,
                required String userId,
                required String type,
                Value<int> amount = const Value.absent(),
                required DateTime createdAt,
                required OutboxStatus status,
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
              }) => EventOutboxEntriesCompanion.insert(
                localId: localId,
                challengeId: challengeId,
                clientEventId: clientEventId,
                userId: userId,
                type: type,
                amount: amount,
                createdAt: createdAt,
                status: status,
                attempts: attempts,
                lastAttemptAt: lastAttemptAt,
                lastError: lastError,
                syncedAt: syncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EventOutboxEntriesTable, EventOutboxEntry>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $EventOutboxEntriesTable,
                    EventOutboxEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventOutboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventOutboxEntriesTable,
      EventOutboxEntry,
      $$EventOutboxEntriesTableFilterComposer,
      $$EventOutboxEntriesTableOrderingComposer,
      $$EventOutboxEntriesTableAnnotationComposer,
      $$EventOutboxEntriesTableCreateCompanionBuilder,
      $$EventOutboxEntriesTableUpdateCompanionBuilder,
      (
        EventOutboxEntry,
        BaseReferences<
          _$AppDatabase,
          $EventOutboxEntriesTable,
          EventOutboxEntry
        >,
      ),
      EventOutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$ChallengesLocalTableCreateCompanionBuilder =
    ChallengesLocalCompanion Function({
      required String id,
      required String hostUserId,
      required String categoryId,
      Value<String?> restaurantId,
      Value<String> title,
      Value<String> description,
      required String inviteCode,
      required String visibility,
      required String status,
      required int maxParticipants,
      Value<String> participantIdsJson,
      Value<DateTime?> createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> finishedAt,
      Value<DateTime?> updatedAt,
      required DateTime syncedAt,
      Value<int> rowid,
    });
typedef $$ChallengesLocalTableUpdateCompanionBuilder =
    ChallengesLocalCompanion Function({
      Value<String> id,
      Value<String> hostUserId,
      Value<String> categoryId,
      Value<String?> restaurantId,
      Value<String> title,
      Value<String> description,
      Value<String> inviteCode,
      Value<String> visibility,
      Value<String> status,
      Value<int> maxParticipants,
      Value<String> participantIdsJson,
      Value<DateTime?> createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> finishedAt,
      Value<DateTime?> updatedAt,
      Value<DateTime> syncedAt,
      Value<int> rowid,
    });

class $$ChallengesLocalTableFilterComposer
    extends Composer<_$AppDatabase, $ChallengesLocalTable> {
  $$ChallengesLocalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hostUserId => $composableBuilder(
    column: $table.hostUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get restaurantId => $composableBuilder(
    column: $table.restaurantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inviteCode => $composableBuilder(
    column: $table.inviteCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxParticipants => $composableBuilder(
    column: $table.maxParticipants,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get participantIdsJson => $composableBuilder(
    column: $table.participantIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChallengesLocalTableOrderingComposer
    extends Composer<_$AppDatabase, $ChallengesLocalTable> {
  $$ChallengesLocalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hostUserId => $composableBuilder(
    column: $table.hostUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get restaurantId => $composableBuilder(
    column: $table.restaurantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inviteCode => $composableBuilder(
    column: $table.inviteCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxParticipants => $composableBuilder(
    column: $table.maxParticipants,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get participantIdsJson => $composableBuilder(
    column: $table.participantIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChallengesLocalTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChallengesLocalTable> {
  $$ChallengesLocalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get hostUserId => $composableBuilder(
    column: $table.hostUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get restaurantId => $composableBuilder(
    column: $table.restaurantId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inviteCode => $composableBuilder(
    column: $table.inviteCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get maxParticipants => $composableBuilder(
    column: $table.maxParticipants,
    builder: (column) => column,
  );

  GeneratedColumn<String> get participantIdsJson => $composableBuilder(
    column: $table.participantIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$ChallengesLocalTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChallengesLocalTable,
          ChallengesLocalData,
          $$ChallengesLocalTableFilterComposer,
          $$ChallengesLocalTableOrderingComposer,
          $$ChallengesLocalTableAnnotationComposer,
          $$ChallengesLocalTableCreateCompanionBuilder,
          $$ChallengesLocalTableUpdateCompanionBuilder,
          (
            ChallengesLocalData,
            BaseReferences<
              _$AppDatabase,
              $ChallengesLocalTable,
              ChallengesLocalData
            >,
          ),
          ChallengesLocalData,
          PrefetchHooks Function()
        > {
  $$ChallengesLocalTableTableManager(
    _$AppDatabase db,
    $ChallengesLocalTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChallengesLocalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChallengesLocalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChallengesLocalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hostUserId = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String?> restaurantId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> inviteCode = const Value.absent(),
                Value<String> visibility = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> maxParticipants = const Value.absent(),
                Value<String> participantIdsJson = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChallengesLocalCompanion(
                id: id,
                hostUserId: hostUserId,
                categoryId: categoryId,
                restaurantId: restaurantId,
                title: title,
                description: description,
                inviteCode: inviteCode,
                visibility: visibility,
                status: status,
                maxParticipants: maxParticipants,
                participantIdsJson: participantIdsJson,
                createdAt: createdAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                updatedAt: updatedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String hostUserId,
                required String categoryId,
                Value<String?> restaurantId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                required String inviteCode,
                required String visibility,
                required String status,
                required int maxParticipants,
                Value<String> participantIdsJson = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                required DateTime syncedAt,
                Value<int> rowid = const Value.absent(),
              }) => ChallengesLocalCompanion.insert(
                id: id,
                hostUserId: hostUserId,
                categoryId: categoryId,
                restaurantId: restaurantId,
                title: title,
                description: description,
                inviteCode: inviteCode,
                visibility: visibility,
                status: status,
                maxParticipants: maxParticipants,
                participantIdsJson: participantIdsJson,
                createdAt: createdAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                updatedAt: updatedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChallengesLocalTable, ChallengesLocalData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ChallengesLocalTable,
                    ChallengesLocalData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChallengesLocalTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChallengesLocalTable,
      ChallengesLocalData,
      $$ChallengesLocalTableFilterComposer,
      $$ChallengesLocalTableOrderingComposer,
      $$ChallengesLocalTableAnnotationComposer,
      $$ChallengesLocalTableCreateCompanionBuilder,
      $$ChallengesLocalTableUpdateCompanionBuilder,
      (
        ChallengesLocalData,
        BaseReferences<
          _$AppDatabase,
          $ChallengesLocalTable,
          ChallengesLocalData
        >,
      ),
      ChallengesLocalData,
      PrefetchHooks Function()
    >;
typedef $$ParticipantsLocalTableCreateCompanionBuilder =
    ParticipantsLocalCompanion Function({
      required String challengeId,
      required String userId,
      required String username,
      required String displayName,
      Value<String?> avatarStyle,
      Value<String?> avatarSeed,
      required String role,
      Value<String> status,
      Value<int> currentCount,
      Value<String?> lastEventId,
      Value<DateTime?> joinedAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ParticipantsLocalTableUpdateCompanionBuilder =
    ParticipantsLocalCompanion Function({
      Value<String> challengeId,
      Value<String> userId,
      Value<String> username,
      Value<String> displayName,
      Value<String?> avatarStyle,
      Value<String?> avatarSeed,
      Value<String> role,
      Value<String> status,
      Value<int> currentCount,
      Value<String?> lastEventId,
      Value<DateTime?> joinedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ParticipantsLocalTableFilterComposer
    extends Composer<_$AppDatabase, $ParticipantsLocalTable> {
  $$ParticipantsLocalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get challengeId => $composableBuilder(
    column: $table.challengeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarStyle => $composableBuilder(
    column: $table.avatarStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarSeed => $composableBuilder(
    column: $table.avatarSeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentCount => $composableBuilder(
    column: $table.currentCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastEventId => $composableBuilder(
    column: $table.lastEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ParticipantsLocalTableOrderingComposer
    extends Composer<_$AppDatabase, $ParticipantsLocalTable> {
  $$ParticipantsLocalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get challengeId => $composableBuilder(
    column: $table.challengeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarStyle => $composableBuilder(
    column: $table.avatarStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarSeed => $composableBuilder(
    column: $table.avatarSeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentCount => $composableBuilder(
    column: $table.currentCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastEventId => $composableBuilder(
    column: $table.lastEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ParticipantsLocalTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParticipantsLocalTable> {
  $$ParticipantsLocalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get challengeId => $composableBuilder(
    column: $table.challengeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarStyle => $composableBuilder(
    column: $table.avatarStyle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarSeed => $composableBuilder(
    column: $table.avatarSeed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get currentCount => $composableBuilder(
    column: $table.currentCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastEventId => $composableBuilder(
    column: $table.lastEventId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ParticipantsLocalTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParticipantsLocalTable,
          ParticipantsLocalData,
          $$ParticipantsLocalTableFilterComposer,
          $$ParticipantsLocalTableOrderingComposer,
          $$ParticipantsLocalTableAnnotationComposer,
          $$ParticipantsLocalTableCreateCompanionBuilder,
          $$ParticipantsLocalTableUpdateCompanionBuilder,
          (
            ParticipantsLocalData,
            BaseReferences<
              _$AppDatabase,
              $ParticipantsLocalTable,
              ParticipantsLocalData
            >,
          ),
          ParticipantsLocalData,
          PrefetchHooks Function()
        > {
  $$ParticipantsLocalTableTableManager(
    _$AppDatabase db,
    $ParticipantsLocalTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParticipantsLocalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParticipantsLocalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParticipantsLocalTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> challengeId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> avatarStyle = const Value.absent(),
                Value<String?> avatarSeed = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> currentCount = const Value.absent(),
                Value<String?> lastEventId = const Value.absent(),
                Value<DateTime?> joinedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ParticipantsLocalCompanion(
                challengeId: challengeId,
                userId: userId,
                username: username,
                displayName: displayName,
                avatarStyle: avatarStyle,
                avatarSeed: avatarSeed,
                role: role,
                status: status,
                currentCount: currentCount,
                lastEventId: lastEventId,
                joinedAt: joinedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String challengeId,
                required String userId,
                required String username,
                required String displayName,
                Value<String?> avatarStyle = const Value.absent(),
                Value<String?> avatarSeed = const Value.absent(),
                required String role,
                Value<String> status = const Value.absent(),
                Value<int> currentCount = const Value.absent(),
                Value<String?> lastEventId = const Value.absent(),
                Value<DateTime?> joinedAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ParticipantsLocalCompanion.insert(
                challengeId: challengeId,
                userId: userId,
                username: username,
                displayName: displayName,
                avatarStyle: avatarStyle,
                avatarSeed: avatarSeed,
                role: role,
                status: status,
                currentCount: currentCount,
                lastEventId: lastEventId,
                joinedAt: joinedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ParticipantsLocalTable, ParticipantsLocalData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ParticipantsLocalTable,
                    ParticipantsLocalData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ParticipantsLocalTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParticipantsLocalTable,
      ParticipantsLocalData,
      $$ParticipantsLocalTableFilterComposer,
      $$ParticipantsLocalTableOrderingComposer,
      $$ParticipantsLocalTableAnnotationComposer,
      $$ParticipantsLocalTableCreateCompanionBuilder,
      $$ParticipantsLocalTableUpdateCompanionBuilder,
      (
        ParticipantsLocalData,
        BaseReferences<
          _$AppDatabase,
          $ParticipantsLocalTable,
          ParticipantsLocalData
        >,
      ),
      ParticipantsLocalData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EventOutboxEntriesTableTableManager get eventOutboxEntries =>
      $$EventOutboxEntriesTableTableManager(_db, _db.eventOutboxEntries);
  $$ChallengesLocalTableTableManager get challengesLocal =>
      $$ChallengesLocalTableTableManager(_db, _db.challengesLocal);
  $$ParticipantsLocalTableTableManager get participantsLocal =>
      $$ParticipantsLocalTableTableManager(_db, _db.participantsLocal);
}
