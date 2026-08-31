// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_operation_outbox_database.dart';

// ignore_for_file: type=lint
class $PendingWorkspaceOperationRowsTable extends PendingWorkspaceOperationRows
    with
        TableInfo<
          $PendingWorkspaceOperationRowsTable,
          PendingWorkspaceOperationRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingWorkspaceOperationRowsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
    'actor_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resourceIdMeta = const VerificationMeta(
    'resourceId',
  );
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
    'resource_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _expectedVersionMeta = const VerificationMeta(
    'expectedVersion',
  );
  @override
  late final GeneratedColumn<String> expectedVersion = GeneratedColumn<String>(
    'expected_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _safeMessageMeta = const VerificationMeta(
    'safeMessage',
  );
  @override
  late final GeneratedColumn<String> safeMessage = GeneratedColumn<String>(
    'safe_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  List<GeneratedColumn> get $columns => [
    operationId,
    actorId,
    resourceId,
    kind,
    state,
    expectedVersion,
    safeMessage,
    payloadJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_workspace_operation_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingWorkspaceOperationRow> instance, {
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
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_actorIdMeta);
    }
    if (data.containsKey('resource_id')) {
      context.handle(
        _resourceIdMeta,
        resourceId.isAcceptableOrUnknown(data['resource_id']!, _resourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_resourceIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
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
    if (data.containsKey('safe_message')) {
      context.handle(
        _safeMessageMeta,
        safeMessage.isAcceptableOrUnknown(
          data['safe_message']!,
          _safeMessageMeta,
        ),
      );
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  PendingWorkspaceOperationRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingWorkspaceOperationRow(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_id'],
      )!,
      resourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      expectedVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expected_version'],
      ),
      safeMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}safe_message'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingWorkspaceOperationRowsTable createAlias(String alias) {
    return $PendingWorkspaceOperationRowsTable(attachedDatabase, alias);
  }
}

class PendingWorkspaceOperationRow extends DataClass
    implements Insertable<PendingWorkspaceOperationRow> {
  final String operationId;
  final String actorId;
  final String resourceId;
  final String kind;
  final String state;
  final String? expectedVersion;
  final String? safeMessage;
  final String payloadJson;
  final DateTime createdAt;
  const PendingWorkspaceOperationRow({
    required this.operationId,
    required this.actorId,
    required this.resourceId,
    required this.kind,
    required this.state,
    this.expectedVersion,
    this.safeMessage,
    required this.payloadJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['actor_id'] = Variable<String>(actorId);
    map['resource_id'] = Variable<String>(resourceId);
    map['kind'] = Variable<String>(kind);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || expectedVersion != null) {
      map['expected_version'] = Variable<String>(expectedVersion);
    }
    if (!nullToAbsent || safeMessage != null) {
      map['safe_message'] = Variable<String>(safeMessage);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingWorkspaceOperationRowsCompanion toCompanion(bool nullToAbsent) {
    return PendingWorkspaceOperationRowsCompanion(
      operationId: Value(operationId),
      actorId: Value(actorId),
      resourceId: Value(resourceId),
      kind: Value(kind),
      state: Value(state),
      expectedVersion: expectedVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedVersion),
      safeMessage: safeMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(safeMessage),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
    );
  }

  factory PendingWorkspaceOperationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingWorkspaceOperationRow(
      operationId: serializer.fromJson<String>(json['operationId']),
      actorId: serializer.fromJson<String>(json['actorId']),
      resourceId: serializer.fromJson<String>(json['resourceId']),
      kind: serializer.fromJson<String>(json['kind']),
      state: serializer.fromJson<String>(json['state']),
      expectedVersion: serializer.fromJson<String?>(json['expectedVersion']),
      safeMessage: serializer.fromJson<String?>(json['safeMessage']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'actorId': serializer.toJson<String>(actorId),
      'resourceId': serializer.toJson<String>(resourceId),
      'kind': serializer.toJson<String>(kind),
      'state': serializer.toJson<String>(state),
      'expectedVersion': serializer.toJson<String?>(expectedVersion),
      'safeMessage': serializer.toJson<String?>(safeMessage),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingWorkspaceOperationRow copyWith({
    String? operationId,
    String? actorId,
    String? resourceId,
    String? kind,
    String? state,
    Value<String?> expectedVersion = const Value.absent(),
    Value<String?> safeMessage = const Value.absent(),
    String? payloadJson,
    DateTime? createdAt,
  }) => PendingWorkspaceOperationRow(
    operationId: operationId ?? this.operationId,
    actorId: actorId ?? this.actorId,
    resourceId: resourceId ?? this.resourceId,
    kind: kind ?? this.kind,
    state: state ?? this.state,
    expectedVersion: expectedVersion.present
        ? expectedVersion.value
        : this.expectedVersion,
    safeMessage: safeMessage.present ? safeMessage.value : this.safeMessage,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingWorkspaceOperationRow copyWithCompanion(
    PendingWorkspaceOperationRowsCompanion data,
  ) {
    return PendingWorkspaceOperationRow(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      resourceId: data.resourceId.present
          ? data.resourceId.value
          : this.resourceId,
      kind: data.kind.present ? data.kind.value : this.kind,
      state: data.state.present ? data.state.value : this.state,
      expectedVersion: data.expectedVersion.present
          ? data.expectedVersion.value
          : this.expectedVersion,
      safeMessage: data.safeMessage.present
          ? data.safeMessage.value
          : this.safeMessage,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingWorkspaceOperationRow(')
          ..write('operationId: $operationId, ')
          ..write('actorId: $actorId, ')
          ..write('resourceId: $resourceId, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('expectedVersion: $expectedVersion, ')
          ..write('safeMessage: $safeMessage, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    actorId,
    resourceId,
    kind,
    state,
    expectedVersion,
    safeMessage,
    payloadJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingWorkspaceOperationRow &&
          other.operationId == this.operationId &&
          other.actorId == this.actorId &&
          other.resourceId == this.resourceId &&
          other.kind == this.kind &&
          other.state == this.state &&
          other.expectedVersion == this.expectedVersion &&
          other.safeMessage == this.safeMessage &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt);
}

class PendingWorkspaceOperationRowsCompanion
    extends UpdateCompanion<PendingWorkspaceOperationRow> {
  final Value<String> operationId;
  final Value<String> actorId;
  final Value<String> resourceId;
  final Value<String> kind;
  final Value<String> state;
  final Value<String?> expectedVersion;
  final Value<String?> safeMessage;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PendingWorkspaceOperationRowsCompanion({
    this.operationId = const Value.absent(),
    this.actorId = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.kind = const Value.absent(),
    this.state = const Value.absent(),
    this.expectedVersion = const Value.absent(),
    this.safeMessage = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingWorkspaceOperationRowsCompanion.insert({
    required String operationId,
    required String actorId,
    required String resourceId,
    required String kind,
    required String state,
    this.expectedVersion = const Value.absent(),
    this.safeMessage = const Value.absent(),
    this.payloadJson = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       actorId = Value(actorId),
       resourceId = Value(resourceId),
       kind = Value(kind),
       state = Value(state),
       createdAt = Value(createdAt);
  static Insertable<PendingWorkspaceOperationRow> custom({
    Expression<String>? operationId,
    Expression<String>? actorId,
    Expression<String>? resourceId,
    Expression<String>? kind,
    Expression<String>? state,
    Expression<String>? expectedVersion,
    Expression<String>? safeMessage,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (actorId != null) 'actor_id': actorId,
      if (resourceId != null) 'resource_id': resourceId,
      if (kind != null) 'kind': kind,
      if (state != null) 'state': state,
      if (expectedVersion != null) 'expected_version': expectedVersion,
      if (safeMessage != null) 'safe_message': safeMessage,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingWorkspaceOperationRowsCompanion copyWith({
    Value<String>? operationId,
    Value<String>? actorId,
    Value<String>? resourceId,
    Value<String>? kind,
    Value<String>? state,
    Value<String?>? expectedVersion,
    Value<String?>? safeMessage,
    Value<String>? payloadJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PendingWorkspaceOperationRowsCompanion(
      operationId: operationId ?? this.operationId,
      actorId: actorId ?? this.actorId,
      resourceId: resourceId ?? this.resourceId,
      kind: kind ?? this.kind,
      state: state ?? this.state,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      safeMessage: safeMessage ?? this.safeMessage,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (expectedVersion.present) {
      map['expected_version'] = Variable<String>(expectedVersion.value);
    }
    if (safeMessage.present) {
      map['safe_message'] = Variable<String>(safeMessage.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingWorkspaceOperationRowsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('actorId: $actorId, ')
          ..write('resourceId: $resourceId, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('expectedVersion: $expectedVersion, ')
          ..write('safeMessage: $safeMessage, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$WorkspaceOperationOutboxDatabase extends GeneratedDatabase {
  _$WorkspaceOperationOutboxDatabase(QueryExecutor e) : super(e);
  $WorkspaceOperationOutboxDatabaseManager get managers =>
      $WorkspaceOperationOutboxDatabaseManager(this);
  late final $PendingWorkspaceOperationRowsTable pendingWorkspaceOperationRows =
      $PendingWorkspaceOperationRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    pendingWorkspaceOperationRows,
  ];
}

typedef $$PendingWorkspaceOperationRowsTableCreateCompanionBuilder =
    PendingWorkspaceOperationRowsCompanion Function({
      required String operationId,
      required String actorId,
      required String resourceId,
      required String kind,
      required String state,
      Value<String?> expectedVersion,
      Value<String?> safeMessage,
      Value<String> payloadJson,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PendingWorkspaceOperationRowsTableUpdateCompanionBuilder =
    PendingWorkspaceOperationRowsCompanion Function({
      Value<String> operationId,
      Value<String> actorId,
      Value<String> resourceId,
      Value<String> kind,
      Value<String> state,
      Value<String?> expectedVersion,
      Value<String?> safeMessage,
      Value<String> payloadJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$PendingWorkspaceOperationRowsTableFilterComposer
    extends
        Composer<
          _$WorkspaceOperationOutboxDatabase,
          $PendingWorkspaceOperationRowsTable
        > {
  $$PendingWorkspaceOperationRowsTableFilterComposer({
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

  ColumnFilters<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get safeMessage => $composableBuilder(
    column: $table.safeMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingWorkspaceOperationRowsTableOrderingComposer
    extends
        Composer<
          _$WorkspaceOperationOutboxDatabase,
          $PendingWorkspaceOperationRowsTable
        > {
  $$PendingWorkspaceOperationRowsTableOrderingComposer({
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

  ColumnOrderings<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get safeMessage => $composableBuilder(
    column: $table.safeMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingWorkspaceOperationRowsTableAnnotationComposer
    extends
        Composer<
          _$WorkspaceOperationOutboxDatabase,
          $PendingWorkspaceOperationRowsTable
        > {
  $$PendingWorkspaceOperationRowsTableAnnotationComposer({
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

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get safeMessage => $composableBuilder(
    column: $table.safeMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingWorkspaceOperationRowsTableTableManager
    extends
        RootTableManager<
          _$WorkspaceOperationOutboxDatabase,
          $PendingWorkspaceOperationRowsTable,
          PendingWorkspaceOperationRow,
          $$PendingWorkspaceOperationRowsTableFilterComposer,
          $$PendingWorkspaceOperationRowsTableOrderingComposer,
          $$PendingWorkspaceOperationRowsTableAnnotationComposer,
          $$PendingWorkspaceOperationRowsTableCreateCompanionBuilder,
          $$PendingWorkspaceOperationRowsTableUpdateCompanionBuilder,
          (
            PendingWorkspaceOperationRow,
            BaseReferences<
              _$WorkspaceOperationOutboxDatabase,
              $PendingWorkspaceOperationRowsTable,
              PendingWorkspaceOperationRow
            >,
          ),
          PendingWorkspaceOperationRow,
          PrefetchHooks Function()
        > {
  $$PendingWorkspaceOperationRowsTableTableManager(
    _$WorkspaceOperationOutboxDatabase db,
    $PendingWorkspaceOperationRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingWorkspaceOperationRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PendingWorkspaceOperationRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingWorkspaceOperationRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> actorId = const Value.absent(),
                Value<String> resourceId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> expectedVersion = const Value.absent(),
                Value<String?> safeMessage = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingWorkspaceOperationRowsCompanion(
                operationId: operationId,
                actorId: actorId,
                resourceId: resourceId,
                kind: kind,
                state: state,
                expectedVersion: expectedVersion,
                safeMessage: safeMessage,
                payloadJson: payloadJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String actorId,
                required String resourceId,
                required String kind,
                required String state,
                Value<String?> expectedVersion = const Value.absent(),
                Value<String?> safeMessage = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingWorkspaceOperationRowsCompanion.insert(
                operationId: operationId,
                actorId: actorId,
                resourceId: resourceId,
                kind: kind,
                state: state,
                expectedVersion: expectedVersion,
                safeMessage: safeMessage,
                payloadJson: payloadJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingWorkspaceOperationRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$WorkspaceOperationOutboxDatabase,
      $PendingWorkspaceOperationRowsTable,
      PendingWorkspaceOperationRow,
      $$PendingWorkspaceOperationRowsTableFilterComposer,
      $$PendingWorkspaceOperationRowsTableOrderingComposer,
      $$PendingWorkspaceOperationRowsTableAnnotationComposer,
      $$PendingWorkspaceOperationRowsTableCreateCompanionBuilder,
      $$PendingWorkspaceOperationRowsTableUpdateCompanionBuilder,
      (
        PendingWorkspaceOperationRow,
        BaseReferences<
          _$WorkspaceOperationOutboxDatabase,
          $PendingWorkspaceOperationRowsTable,
          PendingWorkspaceOperationRow
        >,
      ),
      PendingWorkspaceOperationRow,
      PrefetchHooks Function()
    >;

class $WorkspaceOperationOutboxDatabaseManager {
  final _$WorkspaceOperationOutboxDatabase _db;
  $WorkspaceOperationOutboxDatabaseManager(this._db);
  $$PendingWorkspaceOperationRowsTableTableManager
  get pendingWorkspaceOperationRows =>
      $$PendingWorkspaceOperationRowsTableTableManager(
        _db,
        _db.pendingWorkspaceOperationRows,
      );
}
