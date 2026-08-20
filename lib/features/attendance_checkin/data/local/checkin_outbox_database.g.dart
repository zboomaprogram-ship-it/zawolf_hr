// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkin_outbox_database.dart';

// ignore_for_file: type=lint
class $PendingCheckInRowsTable extends PendingCheckInRows
    with TableInfo<$PendingCheckInRowsTable, PendingCheckInRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingCheckInRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _actionIdMeta = const VerificationMeta(
    'actionId',
  );
  @override
  late final GeneratedColumn<String> actionId = GeneratedColumn<String>(
    'action_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _employeeScopeIdMeta = const VerificationMeta(
    'employeeScopeId',
  );
  @override
  late final GeneratedColumn<String> employeeScopeId = GeneratedColumn<String>(
    'employee_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
    requiredDuringInsert: true,
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
    actionId,
    employeeScopeId,
    dateKey,
    capturedAt,
    payloadJson,
    state,
    attemptCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_check_in_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingCheckInRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('action_id')) {
      context.handle(
        _actionIdMeta,
        actionId.isAcceptableOrUnknown(data['action_id']!, _actionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_actionIdMeta);
    }
    if (data.containsKey('employee_scope_id')) {
      context.handle(
        _employeeScopeIdMeta,
        employeeScopeId.isAcceptableOrUnknown(
          data['employee_scope_id']!,
          _employeeScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_employeeScopeIdMeta);
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
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
    } else if (isInserting) {
      context.missing(_attemptCountMeta);
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
  Set<GeneratedColumn> get $primaryKey => {actionId};
  @override
  PendingCheckInRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingCheckInRow(
      actionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_id'],
      )!,
      employeeScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_scope_id'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PendingCheckInRowsTable createAlias(String alias) {
    return $PendingCheckInRowsTable(attachedDatabase, alias);
  }
}

class PendingCheckInRow extends DataClass
    implements Insertable<PendingCheckInRow> {
  final String actionId;
  final String employeeScopeId;
  final String dateKey;
  final DateTime capturedAt;
  final String payloadJson;
  final String state;
  final int attemptCount;
  final DateTime updatedAt;
  const PendingCheckInRow({
    required this.actionId,
    required this.employeeScopeId,
    required this.dateKey,
    required this.capturedAt,
    required this.payloadJson,
    required this.state,
    required this.attemptCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['action_id'] = Variable<String>(actionId);
    map['employee_scope_id'] = Variable<String>(employeeScopeId);
    map['date_key'] = Variable<String>(dateKey);
    map['captured_at'] = Variable<DateTime>(capturedAt);
    map['payload_json'] = Variable<String>(payloadJson);
    map['state'] = Variable<String>(state);
    map['attempt_count'] = Variable<int>(attemptCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PendingCheckInRowsCompanion toCompanion(bool nullToAbsent) {
    return PendingCheckInRowsCompanion(
      actionId: Value(actionId),
      employeeScopeId: Value(employeeScopeId),
      dateKey: Value(dateKey),
      capturedAt: Value(capturedAt),
      payloadJson: Value(payloadJson),
      state: Value(state),
      attemptCount: Value(attemptCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory PendingCheckInRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingCheckInRow(
      actionId: serializer.fromJson<String>(json['actionId']),
      employeeScopeId: serializer.fromJson<String>(json['employeeScopeId']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      state: serializer.fromJson<String>(json['state']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'actionId': serializer.toJson<String>(actionId),
      'employeeScopeId': serializer.toJson<String>(employeeScopeId),
      'dateKey': serializer.toJson<String>(dateKey),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'state': serializer.toJson<String>(state),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PendingCheckInRow copyWith({
    String? actionId,
    String? employeeScopeId,
    String? dateKey,
    DateTime? capturedAt,
    String? payloadJson,
    String? state,
    int? attemptCount,
    DateTime? updatedAt,
  }) => PendingCheckInRow(
    actionId: actionId ?? this.actionId,
    employeeScopeId: employeeScopeId ?? this.employeeScopeId,
    dateKey: dateKey ?? this.dateKey,
    capturedAt: capturedAt ?? this.capturedAt,
    payloadJson: payloadJson ?? this.payloadJson,
    state: state ?? this.state,
    attemptCount: attemptCount ?? this.attemptCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PendingCheckInRow copyWithCompanion(PendingCheckInRowsCompanion data) {
    return PendingCheckInRow(
      actionId: data.actionId.present ? data.actionId.value : this.actionId,
      employeeScopeId: data.employeeScopeId.present
          ? data.employeeScopeId.value
          : this.employeeScopeId,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      state: data.state.present ? data.state.value : this.state,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingCheckInRow(')
          ..write('actionId: $actionId, ')
          ..write('employeeScopeId: $employeeScopeId, ')
          ..write('dateKey: $dateKey, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    actionId,
    employeeScopeId,
    dateKey,
    capturedAt,
    payloadJson,
    state,
    attemptCount,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingCheckInRow &&
          other.actionId == this.actionId &&
          other.employeeScopeId == this.employeeScopeId &&
          other.dateKey == this.dateKey &&
          other.capturedAt == this.capturedAt &&
          other.payloadJson == this.payloadJson &&
          other.state == this.state &&
          other.attemptCount == this.attemptCount &&
          other.updatedAt == this.updatedAt);
}

class PendingCheckInRowsCompanion extends UpdateCompanion<PendingCheckInRow> {
  final Value<String> actionId;
  final Value<String> employeeScopeId;
  final Value<String> dateKey;
  final Value<DateTime> capturedAt;
  final Value<String> payloadJson;
  final Value<String> state;
  final Value<int> attemptCount;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PendingCheckInRowsCompanion({
    this.actionId = const Value.absent(),
    this.employeeScopeId = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.state = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingCheckInRowsCompanion.insert({
    required String actionId,
    required String employeeScopeId,
    required String dateKey,
    required DateTime capturedAt,
    required String payloadJson,
    required String state,
    required int attemptCount,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : actionId = Value(actionId),
       employeeScopeId = Value(employeeScopeId),
       dateKey = Value(dateKey),
       capturedAt = Value(capturedAt),
       payloadJson = Value(payloadJson),
       state = Value(state),
       attemptCount = Value(attemptCount),
       updatedAt = Value(updatedAt);
  static Insertable<PendingCheckInRow> custom({
    Expression<String>? actionId,
    Expression<String>? employeeScopeId,
    Expression<String>? dateKey,
    Expression<DateTime>? capturedAt,
    Expression<String>? payloadJson,
    Expression<String>? state,
    Expression<int>? attemptCount,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (actionId != null) 'action_id': actionId,
      if (employeeScopeId != null) 'employee_scope_id': employeeScopeId,
      if (dateKey != null) 'date_key': dateKey,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (state != null) 'state': state,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingCheckInRowsCompanion copyWith({
    Value<String>? actionId,
    Value<String>? employeeScopeId,
    Value<String>? dateKey,
    Value<DateTime>? capturedAt,
    Value<String>? payloadJson,
    Value<String>? state,
    Value<int>? attemptCount,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PendingCheckInRowsCompanion(
      actionId: actionId ?? this.actionId,
      employeeScopeId: employeeScopeId ?? this.employeeScopeId,
      dateKey: dateKey ?? this.dateKey,
      capturedAt: capturedAt ?? this.capturedAt,
      payloadJson: payloadJson ?? this.payloadJson,
      state: state ?? this.state,
      attemptCount: attemptCount ?? this.attemptCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (actionId.present) {
      map['action_id'] = Variable<String>(actionId.value);
    }
    if (employeeScopeId.present) {
      map['employee_scope_id'] = Variable<String>(employeeScopeId.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
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
    return (StringBuffer('PendingCheckInRowsCompanion(')
          ..write('actionId: $actionId, ')
          ..write('employeeScopeId: $employeeScopeId, ')
          ..write('dateKey: $dateKey, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CheckInOutboxDatabase extends GeneratedDatabase {
  _$CheckInOutboxDatabase(QueryExecutor e) : super(e);
  $CheckInOutboxDatabaseManager get managers =>
      $CheckInOutboxDatabaseManager(this);
  late final $PendingCheckInRowsTable pendingCheckInRows =
      $PendingCheckInRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [pendingCheckInRows];
}

typedef $$PendingCheckInRowsTableCreateCompanionBuilder =
    PendingCheckInRowsCompanion Function({
      required String actionId,
      required String employeeScopeId,
      required String dateKey,
      required DateTime capturedAt,
      required String payloadJson,
      required String state,
      required int attemptCount,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PendingCheckInRowsTableUpdateCompanionBuilder =
    PendingCheckInRowsCompanion Function({
      Value<String> actionId,
      Value<String> employeeScopeId,
      Value<String> dateKey,
      Value<DateTime> capturedAt,
      Value<String> payloadJson,
      Value<String> state,
      Value<int> attemptCount,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PendingCheckInRowsTableFilterComposer
    extends Composer<_$CheckInOutboxDatabase, $PendingCheckInRowsTable> {
  $$PendingCheckInRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get actionId => $composableBuilder(
    column: $table.actionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get employeeScopeId => $composableBuilder(
    column: $table.employeeScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingCheckInRowsTableOrderingComposer
    extends Composer<_$CheckInOutboxDatabase, $PendingCheckInRowsTable> {
  $$PendingCheckInRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get actionId => $composableBuilder(
    column: $table.actionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get employeeScopeId => $composableBuilder(
    column: $table.employeeScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingCheckInRowsTableAnnotationComposer
    extends Composer<_$CheckInOutboxDatabase, $PendingCheckInRowsTable> {
  $$PendingCheckInRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get actionId =>
      $composableBuilder(column: $table.actionId, builder: (column) => column);

  GeneratedColumn<String> get employeeScopeId => $composableBuilder(
    column: $table.employeeScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PendingCheckInRowsTableTableManager
    extends
        RootTableManager<
          _$CheckInOutboxDatabase,
          $PendingCheckInRowsTable,
          PendingCheckInRow,
          $$PendingCheckInRowsTableFilterComposer,
          $$PendingCheckInRowsTableOrderingComposer,
          $$PendingCheckInRowsTableAnnotationComposer,
          $$PendingCheckInRowsTableCreateCompanionBuilder,
          $$PendingCheckInRowsTableUpdateCompanionBuilder,
          (
            PendingCheckInRow,
            BaseReferences<
              _$CheckInOutboxDatabase,
              $PendingCheckInRowsTable,
              PendingCheckInRow
            >,
          ),
          PendingCheckInRow,
          PrefetchHooks Function()
        > {
  $$PendingCheckInRowsTableTableManager(
    _$CheckInOutboxDatabase db,
    $PendingCheckInRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingCheckInRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingCheckInRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingCheckInRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> actionId = const Value.absent(),
                Value<String> employeeScopeId = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingCheckInRowsCompanion(
                actionId: actionId,
                employeeScopeId: employeeScopeId,
                dateKey: dateKey,
                capturedAt: capturedAt,
                payloadJson: payloadJson,
                state: state,
                attemptCount: attemptCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String actionId,
                required String employeeScopeId,
                required String dateKey,
                required DateTime capturedAt,
                required String payloadJson,
                required String state,
                required int attemptCount,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingCheckInRowsCompanion.insert(
                actionId: actionId,
                employeeScopeId: employeeScopeId,
                dateKey: dateKey,
                capturedAt: capturedAt,
                payloadJson: payloadJson,
                state: state,
                attemptCount: attemptCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingCheckInRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$CheckInOutboxDatabase,
      $PendingCheckInRowsTable,
      PendingCheckInRow,
      $$PendingCheckInRowsTableFilterComposer,
      $$PendingCheckInRowsTableOrderingComposer,
      $$PendingCheckInRowsTableAnnotationComposer,
      $$PendingCheckInRowsTableCreateCompanionBuilder,
      $$PendingCheckInRowsTableUpdateCompanionBuilder,
      (
        PendingCheckInRow,
        BaseReferences<
          _$CheckInOutboxDatabase,
          $PendingCheckInRowsTable,
          PendingCheckInRow
        >,
      ),
      PendingCheckInRow,
      PrefetchHooks Function()
    >;

class $CheckInOutboxDatabaseManager {
  final _$CheckInOutboxDatabase _db;
  $CheckInOutboxDatabaseManager(this._db);
  $$PendingCheckInRowsTableTableManager get pendingCheckInRows =>
      $$PendingCheckInRowsTableTableManager(_db, _db.pendingCheckInRows);
}
