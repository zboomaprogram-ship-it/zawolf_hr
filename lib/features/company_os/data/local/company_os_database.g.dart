// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_os_database.dart';

// ignore_for_file: type=lint
class $CompanyOsOutboxRowsTable extends CompanyOsOutboxRows
    with TableInfo<$CompanyOsOutboxRowsTable, CompanyOsOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompanyOsOutboxRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorUidMeta = const VerificationMeta(
    'actorUid',
  );
  @override
  late final GeneratedColumn<String> actorUid = GeneratedColumn<String>(
    'actor_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _expectedVersionMeta = const VerificationMeta(
    'expectedVersion',
  );
  @override
  late final GeneratedColumn<int> expectedVersion = GeneratedColumn<int>(
    'expected_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
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
  static const VerificationMeta _lastSafeCodeMeta = const VerificationMeta(
    'lastSafeCode',
  );
  @override
  late final GeneratedColumn<String> lastSafeCode = GeneratedColumn<String>(
    'last_safe_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    actorUid,
    operationType,
    targetId,
    payloadJson,
    expectedVersion,
    state,
    attemptCount,
    nextAttemptAt,
    createdAt,
    lastSafeCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'company_os_outbox_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompanyOsOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('actor_uid')) {
      context.handle(
        _actorUidMeta,
        actorUid.isAcceptableOrUnknown(data['actor_uid']!, _actorUidMeta),
      );
    } else if (isInserting) {
      context.missing(_actorUidMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('expected_version')) {
      context.handle(
        _expectedVersionMeta,
        expectedVersion.isAcceptableOrUnknown(
          data['expected_version']!,
          _expectedVersionMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_safe_code')) {
      context.handle(
        _lastSafeCodeMeta,
        lastSafeCode.isAcceptableOrUnknown(
          data['last_safe_code']!,
          _lastSafeCodeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  CompanyOsOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompanyOsOutboxRow(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      actorUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_uid'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      expectedVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_version'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastSafeCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_safe_code'],
      ),
    );
  }

  @override
  $CompanyOsOutboxRowsTable createAlias(String alias) {
    return $CompanyOsOutboxRowsTable(attachedDatabase, alias);
  }
}

class CompanyOsOutboxRow extends DataClass
    implements Insertable<CompanyOsOutboxRow> {
  final String operationId;
  final String actorUid;
  final String operationType;
  final String targetId;
  final String payloadJson;
  final int? expectedVersion;
  final String state;
  final int attemptCount;
  final DateTime nextAttemptAt;
  final DateTime createdAt;
  final String? lastSafeCode;
  const CompanyOsOutboxRow({
    required this.operationId,
    required this.actorUid,
    required this.operationType,
    required this.targetId,
    required this.payloadJson,
    this.expectedVersion,
    required this.state,
    required this.attemptCount,
    required this.nextAttemptAt,
    required this.createdAt,
    this.lastSafeCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['actor_uid'] = Variable<String>(actorUid);
    map['operation_type'] = Variable<String>(operationType);
    map['target_id'] = Variable<String>(targetId);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || expectedVersion != null) {
      map['expected_version'] = Variable<int>(expectedVersion);
    }
    map['state'] = Variable<String>(state);
    map['attempt_count'] = Variable<int>(attemptCount);
    map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastSafeCode != null) {
      map['last_safe_code'] = Variable<String>(lastSafeCode);
    }
    return map;
  }

  CompanyOsOutboxRowsCompanion toCompanion(bool nullToAbsent) {
    return CompanyOsOutboxRowsCompanion(
      operationId: Value(operationId),
      actorUid: Value(actorUid),
      operationType: Value(operationType),
      targetId: Value(targetId),
      payloadJson: Value(payloadJson),
      expectedVersion: expectedVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedVersion),
      state: Value(state),
      attemptCount: Value(attemptCount),
      nextAttemptAt: Value(nextAttemptAt),
      createdAt: Value(createdAt),
      lastSafeCode: lastSafeCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSafeCode),
    );
  }

  factory CompanyOsOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompanyOsOutboxRow(
      operationId: serializer.fromJson<String>(json['operationId']),
      actorUid: serializer.fromJson<String>(json['actorUid']),
      operationType: serializer.fromJson<String>(json['operationType']),
      targetId: serializer.fromJson<String>(json['targetId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      expectedVersion: serializer.fromJson<int?>(json['expectedVersion']),
      state: serializer.fromJson<String>(json['state']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextAttemptAt: serializer.fromJson<DateTime>(json['nextAttemptAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastSafeCode: serializer.fromJson<String?>(json['lastSafeCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'actorUid': serializer.toJson<String>(actorUid),
      'operationType': serializer.toJson<String>(operationType),
      'targetId': serializer.toJson<String>(targetId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'expectedVersion': serializer.toJson<int?>(expectedVersion),
      'state': serializer.toJson<String>(state),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextAttemptAt': serializer.toJson<DateTime>(nextAttemptAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastSafeCode': serializer.toJson<String?>(lastSafeCode),
    };
  }

  CompanyOsOutboxRow copyWith({
    String? operationId,
    String? actorUid,
    String? operationType,
    String? targetId,
    String? payloadJson,
    Value<int?> expectedVersion = const Value.absent(),
    String? state,
    int? attemptCount,
    DateTime? nextAttemptAt,
    DateTime? createdAt,
    Value<String?> lastSafeCode = const Value.absent(),
  }) => CompanyOsOutboxRow(
    operationId: operationId ?? this.operationId,
    actorUid: actorUid ?? this.actorUid,
    operationType: operationType ?? this.operationType,
    targetId: targetId ?? this.targetId,
    payloadJson: payloadJson ?? this.payloadJson,
    expectedVersion: expectedVersion.present
        ? expectedVersion.value
        : this.expectedVersion,
    state: state ?? this.state,
    attemptCount: attemptCount ?? this.attemptCount,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    createdAt: createdAt ?? this.createdAt,
    lastSafeCode: lastSafeCode.present ? lastSafeCode.value : this.lastSafeCode,
  );
  CompanyOsOutboxRow copyWithCompanion(CompanyOsOutboxRowsCompanion data) {
    return CompanyOsOutboxRow(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      actorUid: data.actorUid.present ? data.actorUid.value : this.actorUid,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      expectedVersion: data.expectedVersion.present
          ? data.expectedVersion.value
          : this.expectedVersion,
      state: data.state.present ? data.state.value : this.state,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastSafeCode: data.lastSafeCode.present
          ? data.lastSafeCode.value
          : this.lastSafeCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompanyOsOutboxRow(')
          ..write('operationId: $operationId, ')
          ..write('actorUid: $actorUid, ')
          ..write('operationType: $operationType, ')
          ..write('targetId: $targetId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('expectedVersion: $expectedVersion, ')
          ..write('state: $state, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSafeCode: $lastSafeCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    actorUid,
    operationType,
    targetId,
    payloadJson,
    expectedVersion,
    state,
    attemptCount,
    nextAttemptAt,
    createdAt,
    lastSafeCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompanyOsOutboxRow &&
          other.operationId == this.operationId &&
          other.actorUid == this.actorUid &&
          other.operationType == this.operationType &&
          other.targetId == this.targetId &&
          other.payloadJson == this.payloadJson &&
          other.expectedVersion == this.expectedVersion &&
          other.state == this.state &&
          other.attemptCount == this.attemptCount &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.createdAt == this.createdAt &&
          other.lastSafeCode == this.lastSafeCode);
}

class CompanyOsOutboxRowsCompanion extends UpdateCompanion<CompanyOsOutboxRow> {
  final Value<String> operationId;
  final Value<String> actorUid;
  final Value<String> operationType;
  final Value<String> targetId;
  final Value<String> payloadJson;
  final Value<int?> expectedVersion;
  final Value<String> state;
  final Value<int> attemptCount;
  final Value<DateTime> nextAttemptAt;
  final Value<DateTime> createdAt;
  final Value<String?> lastSafeCode;
  final Value<int> rowid;
  const CompanyOsOutboxRowsCompanion({
    this.operationId = const Value.absent(),
    this.actorUid = const Value.absent(),
    this.operationType = const Value.absent(),
    this.targetId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.expectedVersion = const Value.absent(),
    this.state = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastSafeCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompanyOsOutboxRowsCompanion.insert({
    required String operationId,
    required String actorUid,
    required String operationType,
    required String targetId,
    this.payloadJson = const Value.absent(),
    this.expectedVersion = const Value.absent(),
    required String state,
    this.attemptCount = const Value.absent(),
    required DateTime nextAttemptAt,
    required DateTime createdAt,
    this.lastSafeCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       actorUid = Value(actorUid),
       operationType = Value(operationType),
       targetId = Value(targetId),
       state = Value(state),
       nextAttemptAt = Value(nextAttemptAt),
       createdAt = Value(createdAt);
  static Insertable<CompanyOsOutboxRow> custom({
    Expression<String>? operationId,
    Expression<String>? actorUid,
    Expression<String>? operationType,
    Expression<String>? targetId,
    Expression<String>? payloadJson,
    Expression<int>? expectedVersion,
    Expression<String>? state,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextAttemptAt,
    Expression<DateTime>? createdAt,
    Expression<String>? lastSafeCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (actorUid != null) 'actor_uid': actorUid,
      if (operationType != null) 'operation_type': operationType,
      if (targetId != null) 'target_id': targetId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (expectedVersion != null) 'expected_version': expectedVersion,
      if (state != null) 'state': state,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (createdAt != null) 'created_at': createdAt,
      if (lastSafeCode != null) 'last_safe_code': lastSafeCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompanyOsOutboxRowsCompanion copyWith({
    Value<String>? operationId,
    Value<String>? actorUid,
    Value<String>? operationType,
    Value<String>? targetId,
    Value<String>? payloadJson,
    Value<int?>? expectedVersion,
    Value<String>? state,
    Value<int>? attemptCount,
    Value<DateTime>? nextAttemptAt,
    Value<DateTime>? createdAt,
    Value<String?>? lastSafeCode,
    Value<int>? rowid,
  }) {
    return CompanyOsOutboxRowsCompanion(
      operationId: operationId ?? this.operationId,
      actorUid: actorUid ?? this.actorUid,
      operationType: operationType ?? this.operationType,
      targetId: targetId ?? this.targetId,
      payloadJson: payloadJson ?? this.payloadJson,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      state: state ?? this.state,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      createdAt: createdAt ?? this.createdAt,
      lastSafeCode: lastSafeCode ?? this.lastSafeCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (actorUid.present) {
      map['actor_uid'] = Variable<String>(actorUid.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (expectedVersion.present) {
      map['expected_version'] = Variable<int>(expectedVersion.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastSafeCode.present) {
      map['last_safe_code'] = Variable<String>(lastSafeCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompanyOsOutboxRowsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('actorUid: $actorUid, ')
          ..write('operationType: $operationType, ')
          ..write('targetId: $targetId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('expectedVersion: $expectedVersion, ')
          ..write('state: $state, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSafeCode: $lastSafeCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CompanyOsSnapshotRowsTable extends CompanyOsSnapshotRows
    with TableInfo<$CompanyOsSnapshotRowsTable, CompanyOsSnapshotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompanyOsSnapshotRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loadedAtMeta = const VerificationMeta(
    'loadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> loadedAt = GeneratedColumn<DateTime>(
    'loaded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cacheKey, payloadJson, loadedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'company_os_snapshot_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompanyOsSnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('loaded_at')) {
      context.handle(
        _loadedAtMeta,
        loadedAt.isAcceptableOrUnknown(data['loaded_at']!, _loadedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_loadedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  CompanyOsSnapshotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompanyOsSnapshotRow(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      loadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}loaded_at'],
      )!,
    );
  }

  @override
  $CompanyOsSnapshotRowsTable createAlias(String alias) {
    return $CompanyOsSnapshotRowsTable(attachedDatabase, alias);
  }
}

class CompanyOsSnapshotRow extends DataClass
    implements Insertable<CompanyOsSnapshotRow> {
  final String cacheKey;
  final String payloadJson;
  final DateTime loadedAt;
  const CompanyOsSnapshotRow({
    required this.cacheKey,
    required this.payloadJson,
    required this.loadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['payload_json'] = Variable<String>(payloadJson);
    map['loaded_at'] = Variable<DateTime>(loadedAt);
    return map;
  }

  CompanyOsSnapshotRowsCompanion toCompanion(bool nullToAbsent) {
    return CompanyOsSnapshotRowsCompanion(
      cacheKey: Value(cacheKey),
      payloadJson: Value(payloadJson),
      loadedAt: Value(loadedAt),
    );
  }

  factory CompanyOsSnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompanyOsSnapshotRow(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      loadedAt: serializer.fromJson<DateTime>(json['loadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'loadedAt': serializer.toJson<DateTime>(loadedAt),
    };
  }

  CompanyOsSnapshotRow copyWith({
    String? cacheKey,
    String? payloadJson,
    DateTime? loadedAt,
  }) => CompanyOsSnapshotRow(
    cacheKey: cacheKey ?? this.cacheKey,
    payloadJson: payloadJson ?? this.payloadJson,
    loadedAt: loadedAt ?? this.loadedAt,
  );
  CompanyOsSnapshotRow copyWithCompanion(CompanyOsSnapshotRowsCompanion data) {
    return CompanyOsSnapshotRow(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      loadedAt: data.loadedAt.present ? data.loadedAt.value : this.loadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompanyOsSnapshotRow(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('loadedAt: $loadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, payloadJson, loadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompanyOsSnapshotRow &&
          other.cacheKey == this.cacheKey &&
          other.payloadJson == this.payloadJson &&
          other.loadedAt == this.loadedAt);
}

class CompanyOsSnapshotRowsCompanion
    extends UpdateCompanion<CompanyOsSnapshotRow> {
  final Value<String> cacheKey;
  final Value<String> payloadJson;
  final Value<DateTime> loadedAt;
  final Value<int> rowid;
  const CompanyOsSnapshotRowsCompanion({
    this.cacheKey = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.loadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompanyOsSnapshotRowsCompanion.insert({
    required String cacheKey,
    required String payloadJson,
    required DateTime loadedAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       payloadJson = Value(payloadJson),
       loadedAt = Value(loadedAt);
  static Insertable<CompanyOsSnapshotRow> custom({
    Expression<String>? cacheKey,
    Expression<String>? payloadJson,
    Expression<DateTime>? loadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (loadedAt != null) 'loaded_at': loadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompanyOsSnapshotRowsCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? payloadJson,
    Value<DateTime>? loadedAt,
    Value<int>? rowid,
  }) {
    return CompanyOsSnapshotRowsCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      payloadJson: payloadJson ?? this.payloadJson,
      loadedAt: loadedAt ?? this.loadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (loadedAt.present) {
      map['loaded_at'] = Variable<DateTime>(loadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompanyOsSnapshotRowsCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('loadedAt: $loadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CompanyOsDatabase extends GeneratedDatabase {
  _$CompanyOsDatabase(QueryExecutor e) : super(e);
  $CompanyOsDatabaseManager get managers => $CompanyOsDatabaseManager(this);
  late final $CompanyOsOutboxRowsTable companyOsOutboxRows =
      $CompanyOsOutboxRowsTable(this);
  late final $CompanyOsSnapshotRowsTable companyOsSnapshotRows =
      $CompanyOsSnapshotRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    companyOsOutboxRows,
    companyOsSnapshotRows,
  ];
}

typedef $$CompanyOsOutboxRowsTableCreateCompanionBuilder =
    CompanyOsOutboxRowsCompanion Function({
      required String operationId,
      required String actorUid,
      required String operationType,
      required String targetId,
      Value<String> payloadJson,
      Value<int?> expectedVersion,
      required String state,
      Value<int> attemptCount,
      required DateTime nextAttemptAt,
      required DateTime createdAt,
      Value<String?> lastSafeCode,
      Value<int> rowid,
    });
typedef $$CompanyOsOutboxRowsTableUpdateCompanionBuilder =
    CompanyOsOutboxRowsCompanion Function({
      Value<String> operationId,
      Value<String> actorUid,
      Value<String> operationType,
      Value<String> targetId,
      Value<String> payloadJson,
      Value<int?> expectedVersion,
      Value<String> state,
      Value<int> attemptCount,
      Value<DateTime> nextAttemptAt,
      Value<DateTime> createdAt,
      Value<String?> lastSafeCode,
      Value<int> rowid,
    });

class $$CompanyOsOutboxRowsTableFilterComposer
    extends Composer<_$CompanyOsDatabase, $CompanyOsOutboxRowsTable> {
  $$CompanyOsOutboxRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorUid => $composableBuilder(
    column: $table.actorUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSafeCode => $composableBuilder(
    column: $table.lastSafeCode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CompanyOsOutboxRowsTableOrderingComposer
    extends Composer<_$CompanyOsDatabase, $CompanyOsOutboxRowsTable> {
  $$CompanyOsOutboxRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorUid => $composableBuilder(
    column: $table.actorUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSafeCode => $composableBuilder(
    column: $table.lastSafeCode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CompanyOsOutboxRowsTableAnnotationComposer
    extends Composer<_$CompanyOsDatabase, $CompanyOsOutboxRowsTable> {
  $$CompanyOsOutboxRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actorUid =>
      $composableBuilder(column: $table.actorUid, builder: (column) => column);

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get lastSafeCode => $composableBuilder(
    column: $table.lastSafeCode,
    builder: (column) => column,
  );
}

class $$CompanyOsOutboxRowsTableTableManager
    extends
        RootTableManager<
          _$CompanyOsDatabase,
          $CompanyOsOutboxRowsTable,
          CompanyOsOutboxRow,
          $$CompanyOsOutboxRowsTableFilterComposer,
          $$CompanyOsOutboxRowsTableOrderingComposer,
          $$CompanyOsOutboxRowsTableAnnotationComposer,
          $$CompanyOsOutboxRowsTableCreateCompanionBuilder,
          $$CompanyOsOutboxRowsTableUpdateCompanionBuilder,
          (
            CompanyOsOutboxRow,
            BaseReferences<
              _$CompanyOsDatabase,
              $CompanyOsOutboxRowsTable,
              CompanyOsOutboxRow
            >,
          ),
          CompanyOsOutboxRow,
          PrefetchHooks Function()
        > {
  $$CompanyOsOutboxRowsTableTableManager(
    _$CompanyOsDatabase db,
    $CompanyOsOutboxRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompanyOsOutboxRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompanyOsOutboxRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CompanyOsOutboxRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> actorUid = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int?> expectedVersion = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime> nextAttemptAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> lastSafeCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompanyOsOutboxRowsCompanion(
                operationId: operationId,
                actorUid: actorUid,
                operationType: operationType,
                targetId: targetId,
                payloadJson: payloadJson,
                expectedVersion: expectedVersion,
                state: state,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                lastSafeCode: lastSafeCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String actorUid,
                required String operationType,
                required String targetId,
                Value<String> payloadJson = const Value.absent(),
                Value<int?> expectedVersion = const Value.absent(),
                required String state,
                Value<int> attemptCount = const Value.absent(),
                required DateTime nextAttemptAt,
                required DateTime createdAt,
                Value<String?> lastSafeCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompanyOsOutboxRowsCompanion.insert(
                operationId: operationId,
                actorUid: actorUid,
                operationType: operationType,
                targetId: targetId,
                payloadJson: payloadJson,
                expectedVersion: expectedVersion,
                state: state,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                lastSafeCode: lastSafeCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CompanyOsOutboxRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$CompanyOsDatabase,
      $CompanyOsOutboxRowsTable,
      CompanyOsOutboxRow,
      $$CompanyOsOutboxRowsTableFilterComposer,
      $$CompanyOsOutboxRowsTableOrderingComposer,
      $$CompanyOsOutboxRowsTableAnnotationComposer,
      $$CompanyOsOutboxRowsTableCreateCompanionBuilder,
      $$CompanyOsOutboxRowsTableUpdateCompanionBuilder,
      (
        CompanyOsOutboxRow,
        BaseReferences<
          _$CompanyOsDatabase,
          $CompanyOsOutboxRowsTable,
          CompanyOsOutboxRow
        >,
      ),
      CompanyOsOutboxRow,
      PrefetchHooks Function()
    >;
typedef $$CompanyOsSnapshotRowsTableCreateCompanionBuilder =
    CompanyOsSnapshotRowsCompanion Function({
      required String cacheKey,
      required String payloadJson,
      required DateTime loadedAt,
      Value<int> rowid,
    });
typedef $$CompanyOsSnapshotRowsTableUpdateCompanionBuilder =
    CompanyOsSnapshotRowsCompanion Function({
      Value<String> cacheKey,
      Value<String> payloadJson,
      Value<DateTime> loadedAt,
      Value<int> rowid,
    });

class $$CompanyOsSnapshotRowsTableFilterComposer
    extends Composer<_$CompanyOsDatabase, $CompanyOsSnapshotRowsTable> {
  $$CompanyOsSnapshotRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get loadedAt => $composableBuilder(
    column: $table.loadedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CompanyOsSnapshotRowsTableOrderingComposer
    extends Composer<_$CompanyOsDatabase, $CompanyOsSnapshotRowsTable> {
  $$CompanyOsSnapshotRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get loadedAt => $composableBuilder(
    column: $table.loadedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CompanyOsSnapshotRowsTableAnnotationComposer
    extends Composer<_$CompanyOsDatabase, $CompanyOsSnapshotRowsTable> {
  $$CompanyOsSnapshotRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get loadedAt =>
      $composableBuilder(column: $table.loadedAt, builder: (column) => column);
}

class $$CompanyOsSnapshotRowsTableTableManager
    extends
        RootTableManager<
          _$CompanyOsDatabase,
          $CompanyOsSnapshotRowsTable,
          CompanyOsSnapshotRow,
          $$CompanyOsSnapshotRowsTableFilterComposer,
          $$CompanyOsSnapshotRowsTableOrderingComposer,
          $$CompanyOsSnapshotRowsTableAnnotationComposer,
          $$CompanyOsSnapshotRowsTableCreateCompanionBuilder,
          $$CompanyOsSnapshotRowsTableUpdateCompanionBuilder,
          (
            CompanyOsSnapshotRow,
            BaseReferences<
              _$CompanyOsDatabase,
              $CompanyOsSnapshotRowsTable,
              CompanyOsSnapshotRow
            >,
          ),
          CompanyOsSnapshotRow,
          PrefetchHooks Function()
        > {
  $$CompanyOsSnapshotRowsTableTableManager(
    _$CompanyOsDatabase db,
    $CompanyOsSnapshotRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompanyOsSnapshotRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CompanyOsSnapshotRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CompanyOsSnapshotRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> loadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompanyOsSnapshotRowsCompanion(
                cacheKey: cacheKey,
                payloadJson: payloadJson,
                loadedAt: loadedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String payloadJson,
                required DateTime loadedAt,
                Value<int> rowid = const Value.absent(),
              }) => CompanyOsSnapshotRowsCompanion.insert(
                cacheKey: cacheKey,
                payloadJson: payloadJson,
                loadedAt: loadedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CompanyOsSnapshotRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$CompanyOsDatabase,
      $CompanyOsSnapshotRowsTable,
      CompanyOsSnapshotRow,
      $$CompanyOsSnapshotRowsTableFilterComposer,
      $$CompanyOsSnapshotRowsTableOrderingComposer,
      $$CompanyOsSnapshotRowsTableAnnotationComposer,
      $$CompanyOsSnapshotRowsTableCreateCompanionBuilder,
      $$CompanyOsSnapshotRowsTableUpdateCompanionBuilder,
      (
        CompanyOsSnapshotRow,
        BaseReferences<
          _$CompanyOsDatabase,
          $CompanyOsSnapshotRowsTable,
          CompanyOsSnapshotRow
        >,
      ),
      CompanyOsSnapshotRow,
      PrefetchHooks Function()
    >;

class $CompanyOsDatabaseManager {
  final _$CompanyOsDatabase _db;
  $CompanyOsDatabaseManager(this._db);
  $$CompanyOsOutboxRowsTableTableManager get companyOsOutboxRows =>
      $$CompanyOsOutboxRowsTableTableManager(_db, _db.companyOsOutboxRows);
  $$CompanyOsSnapshotRowsTableTableManager get companyOsSnapshotRows =>
      $$CompanyOsSnapshotRowsTableTableManager(_db, _db.companyOsSnapshotRows);
}
