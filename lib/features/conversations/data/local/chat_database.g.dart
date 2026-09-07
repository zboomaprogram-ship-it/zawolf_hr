// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_database.dart';

// ignore_for_file: type=lint
class $ChatLocalRowsTable extends ChatLocalRows
    with TableInfo<$ChatLocalRowsTable, ChatLocalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatLocalRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _actorMeta = const VerificationMeta('actor');
  @override
  late final GeneratedColumn<String> actor = GeneratedColumn<String>(
    'actor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelMeta = const VerificationMeta(
    'channel',
  );
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
    'channel',
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
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [actor, channel, kind, id, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_local_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatLocalRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('actor')) {
      context.handle(
        _actorMeta,
        actor.isAcceptableOrUnknown(data['actor']!, _actorMeta),
      );
    } else if (isInserting) {
      context.missing(_actorMeta);
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    } else if (isInserting) {
      context.missing(_channelMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {actor, channel, kind, id};
  @override
  ChatLocalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatLocalRow(
      actor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}actor'],
          )!,
      channel:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}channel'],
          )!,
      kind:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}kind'],
          )!,
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      payload:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}payload'],
          )!,
    );
  }

  @override
  $ChatLocalRowsTable createAlias(String alias) {
    return $ChatLocalRowsTable(attachedDatabase, alias);
  }
}

class ChatLocalRow extends DataClass implements Insertable<ChatLocalRow> {
  final String actor;
  final String channel;
  final String kind;
  final String id;
  final String payload;
  const ChatLocalRow({
    required this.actor,
    required this.channel,
    required this.kind,
    required this.id,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['actor'] = Variable<String>(actor);
    map['channel'] = Variable<String>(channel);
    map['kind'] = Variable<String>(kind);
    map['id'] = Variable<String>(id);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  ChatLocalRowsCompanion toCompanion(bool nullToAbsent) {
    return ChatLocalRowsCompanion(
      actor: Value(actor),
      channel: Value(channel),
      kind: Value(kind),
      id: Value(id),
      payload: Value(payload),
    );
  }

  factory ChatLocalRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatLocalRow(
      actor: serializer.fromJson<String>(json['actor']),
      channel: serializer.fromJson<String>(json['channel']),
      kind: serializer.fromJson<String>(json['kind']),
      id: serializer.fromJson<String>(json['id']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'actor': serializer.toJson<String>(actor),
      'channel': serializer.toJson<String>(channel),
      'kind': serializer.toJson<String>(kind),
      'id': serializer.toJson<String>(id),
      'payload': serializer.toJson<String>(payload),
    };
  }

  ChatLocalRow copyWith({
    String? actor,
    String? channel,
    String? kind,
    String? id,
    String? payload,
  }) => ChatLocalRow(
    actor: actor ?? this.actor,
    channel: channel ?? this.channel,
    kind: kind ?? this.kind,
    id: id ?? this.id,
    payload: payload ?? this.payload,
  );
  ChatLocalRow copyWithCompanion(ChatLocalRowsCompanion data) {
    return ChatLocalRow(
      actor: data.actor.present ? data.actor.value : this.actor,
      channel: data.channel.present ? data.channel.value : this.channel,
      kind: data.kind.present ? data.kind.value : this.kind,
      id: data.id.present ? data.id.value : this.id,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatLocalRow(')
          ..write('actor: $actor, ')
          ..write('channel: $channel, ')
          ..write('kind: $kind, ')
          ..write('id: $id, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(actor, channel, kind, id, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatLocalRow &&
          other.actor == this.actor &&
          other.channel == this.channel &&
          other.kind == this.kind &&
          other.id == this.id &&
          other.payload == this.payload);
}

class ChatLocalRowsCompanion extends UpdateCompanion<ChatLocalRow> {
  final Value<String> actor;
  final Value<String> channel;
  final Value<String> kind;
  final Value<String> id;
  final Value<String> payload;
  final Value<int> rowid;
  const ChatLocalRowsCompanion({
    this.actor = const Value.absent(),
    this.channel = const Value.absent(),
    this.kind = const Value.absent(),
    this.id = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatLocalRowsCompanion.insert({
    required String actor,
    required String channel,
    required String kind,
    required String id,
    required String payload,
    this.rowid = const Value.absent(),
  }) : actor = Value(actor),
       channel = Value(channel),
       kind = Value(kind),
       id = Value(id),
       payload = Value(payload);
  static Insertable<ChatLocalRow> custom({
    Expression<String>? actor,
    Expression<String>? channel,
    Expression<String>? kind,
    Expression<String>? id,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (actor != null) 'actor': actor,
      if (channel != null) 'channel': channel,
      if (kind != null) 'kind': kind,
      if (id != null) 'id': id,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatLocalRowsCompanion copyWith({
    Value<String>? actor,
    Value<String>? channel,
    Value<String>? kind,
    Value<String>? id,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return ChatLocalRowsCompanion(
      actor: actor ?? this.actor,
      channel: channel ?? this.channel,
      kind: kind ?? this.kind,
      id: id ?? this.id,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (actor.present) {
      map['actor'] = Variable<String>(actor.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatLocalRowsCompanion(')
          ..write('actor: $actor, ')
          ..write('channel: $channel, ')
          ..write('kind: $kind, ')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatBlobRowsTable extends ChatBlobRows
    with TableInfo<$ChatBlobRowsTable, ChatBlobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatBlobRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _actorMeta = const VerificationMeta('actor');
  @override
  late final GeneratedColumn<String> actor = GeneratedColumn<String>(
    'actor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [actor, id, bytes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_blob_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatBlobRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('actor')) {
      context.handle(
        _actorMeta,
        actor.isAcceptableOrUnknown(data['actor']!, _actorMeta),
      );
    } else if (isInserting) {
      context.missing(_actorMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {actor, id};
  @override
  ChatBlobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatBlobRow(
      actor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}actor'],
          )!,
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      bytes:
          attachedDatabase.typeMapping.read(
            DriftSqlType.blob,
            data['${effectivePrefix}bytes'],
          )!,
    );
  }

  @override
  $ChatBlobRowsTable createAlias(String alias) {
    return $ChatBlobRowsTable(attachedDatabase, alias);
  }
}

class ChatBlobRow extends DataClass implements Insertable<ChatBlobRow> {
  final String actor;
  final String id;
  final Uint8List bytes;
  const ChatBlobRow({
    required this.actor,
    required this.id,
    required this.bytes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['actor'] = Variable<String>(actor);
    map['id'] = Variable<String>(id);
    map['bytes'] = Variable<Uint8List>(bytes);
    return map;
  }

  ChatBlobRowsCompanion toCompanion(bool nullToAbsent) {
    return ChatBlobRowsCompanion(
      actor: Value(actor),
      id: Value(id),
      bytes: Value(bytes),
    );
  }

  factory ChatBlobRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatBlobRow(
      actor: serializer.fromJson<String>(json['actor']),
      id: serializer.fromJson<String>(json['id']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'actor': serializer.toJson<String>(actor),
      'id': serializer.toJson<String>(id),
      'bytes': serializer.toJson<Uint8List>(bytes),
    };
  }

  ChatBlobRow copyWith({String? actor, String? id, Uint8List? bytes}) =>
      ChatBlobRow(
        actor: actor ?? this.actor,
        id: id ?? this.id,
        bytes: bytes ?? this.bytes,
      );
  ChatBlobRow copyWithCompanion(ChatBlobRowsCompanion data) {
    return ChatBlobRow(
      actor: data.actor.present ? data.actor.value : this.actor,
      id: data.id.present ? data.id.value : this.id,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatBlobRow(')
          ..write('actor: $actor, ')
          ..write('id: $id, ')
          ..write('bytes: $bytes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(actor, id, $driftBlobEquality.hash(bytes));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatBlobRow &&
          other.actor == this.actor &&
          other.id == this.id &&
          $driftBlobEquality.equals(other.bytes, this.bytes));
}

class ChatBlobRowsCompanion extends UpdateCompanion<ChatBlobRow> {
  final Value<String> actor;
  final Value<String> id;
  final Value<Uint8List> bytes;
  final Value<int> rowid;
  const ChatBlobRowsCompanion({
    this.actor = const Value.absent(),
    this.id = const Value.absent(),
    this.bytes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatBlobRowsCompanion.insert({
    required String actor,
    required String id,
    required Uint8List bytes,
    this.rowid = const Value.absent(),
  }) : actor = Value(actor),
       id = Value(id),
       bytes = Value(bytes);
  static Insertable<ChatBlobRow> custom({
    Expression<String>? actor,
    Expression<String>? id,
    Expression<Uint8List>? bytes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (actor != null) 'actor': actor,
      if (id != null) 'id': id,
      if (bytes != null) 'bytes': bytes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatBlobRowsCompanion copyWith({
    Value<String>? actor,
    Value<String>? id,
    Value<Uint8List>? bytes,
    Value<int>? rowid,
  }) {
    return ChatBlobRowsCompanion(
      actor: actor ?? this.actor,
      id: id ?? this.id,
      bytes: bytes ?? this.bytes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (actor.present) {
      map['actor'] = Variable<String>(actor.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatBlobRowsCompanion(')
          ..write('actor: $actor, ')
          ..write('id: $id, ')
          ..write('bytes: $bytes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ChatDatabase extends GeneratedDatabase {
  _$ChatDatabase(QueryExecutor e) : super(e);
  $ChatDatabaseManager get managers => $ChatDatabaseManager(this);
  late final $ChatLocalRowsTable chatLocalRows = $ChatLocalRowsTable(this);
  late final $ChatBlobRowsTable chatBlobRows = $ChatBlobRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    chatLocalRows,
    chatBlobRows,
  ];
}

typedef $$ChatLocalRowsTableCreateCompanionBuilder =
    ChatLocalRowsCompanion Function({
      required String actor,
      required String channel,
      required String kind,
      required String id,
      required String payload,
      Value<int> rowid,
    });
typedef $$ChatLocalRowsTableUpdateCompanionBuilder =
    ChatLocalRowsCompanion Function({
      Value<String> actor,
      Value<String> channel,
      Value<String> kind,
      Value<String> id,
      Value<String> payload,
      Value<int> rowid,
    });

class $$ChatLocalRowsTableFilterComposer
    extends Composer<_$ChatDatabase, $ChatLocalRowsTable> {
  $$ChatLocalRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get actor => $composableBuilder(
    column: $table.actor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatLocalRowsTableOrderingComposer
    extends Composer<_$ChatDatabase, $ChatLocalRowsTable> {
  $$ChatLocalRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get actor => $composableBuilder(
    column: $table.actor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatLocalRowsTableAnnotationComposer
    extends Composer<_$ChatDatabase, $ChatLocalRowsTable> {
  $$ChatLocalRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get actor =>
      $composableBuilder(column: $table.actor, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$ChatLocalRowsTableTableManager
    extends
        RootTableManager<
          _$ChatDatabase,
          $ChatLocalRowsTable,
          ChatLocalRow,
          $$ChatLocalRowsTableFilterComposer,
          $$ChatLocalRowsTableOrderingComposer,
          $$ChatLocalRowsTableAnnotationComposer,
          $$ChatLocalRowsTableCreateCompanionBuilder,
          $$ChatLocalRowsTableUpdateCompanionBuilder,
          (
            ChatLocalRow,
            BaseReferences<_$ChatDatabase, $ChatLocalRowsTable, ChatLocalRow>,
          ),
          ChatLocalRow,
          PrefetchHooks Function()
        > {
  $$ChatLocalRowsTableTableManager(_$ChatDatabase db, $ChatLocalRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ChatLocalRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$ChatLocalRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ChatLocalRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> actor = const Value.absent(),
                Value<String> channel = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatLocalRowsCompanion(
                actor: actor,
                channel: channel,
                kind: kind,
                id: id,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String actor,
                required String channel,
                required String kind,
                required String id,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => ChatLocalRowsCompanion.insert(
                actor: actor,
                channel: channel,
                kind: kind,
                id: id,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatLocalRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChatDatabase,
      $ChatLocalRowsTable,
      ChatLocalRow,
      $$ChatLocalRowsTableFilterComposer,
      $$ChatLocalRowsTableOrderingComposer,
      $$ChatLocalRowsTableAnnotationComposer,
      $$ChatLocalRowsTableCreateCompanionBuilder,
      $$ChatLocalRowsTableUpdateCompanionBuilder,
      (
        ChatLocalRow,
        BaseReferences<_$ChatDatabase, $ChatLocalRowsTable, ChatLocalRow>,
      ),
      ChatLocalRow,
      PrefetchHooks Function()
    >;
typedef $$ChatBlobRowsTableCreateCompanionBuilder =
    ChatBlobRowsCompanion Function({
      required String actor,
      required String id,
      required Uint8List bytes,
      Value<int> rowid,
    });
typedef $$ChatBlobRowsTableUpdateCompanionBuilder =
    ChatBlobRowsCompanion Function({
      Value<String> actor,
      Value<String> id,
      Value<Uint8List> bytes,
      Value<int> rowid,
    });

class $$ChatBlobRowsTableFilterComposer
    extends Composer<_$ChatDatabase, $ChatBlobRowsTable> {
  $$ChatBlobRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get actor => $composableBuilder(
    column: $table.actor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatBlobRowsTableOrderingComposer
    extends Composer<_$ChatDatabase, $ChatBlobRowsTable> {
  $$ChatBlobRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get actor => $composableBuilder(
    column: $table.actor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatBlobRowsTableAnnotationComposer
    extends Composer<_$ChatDatabase, $ChatBlobRowsTable> {
  $$ChatBlobRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get actor =>
      $composableBuilder(column: $table.actor, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);
}

class $$ChatBlobRowsTableTableManager
    extends
        RootTableManager<
          _$ChatDatabase,
          $ChatBlobRowsTable,
          ChatBlobRow,
          $$ChatBlobRowsTableFilterComposer,
          $$ChatBlobRowsTableOrderingComposer,
          $$ChatBlobRowsTableAnnotationComposer,
          $$ChatBlobRowsTableCreateCompanionBuilder,
          $$ChatBlobRowsTableUpdateCompanionBuilder,
          (
            ChatBlobRow,
            BaseReferences<_$ChatDatabase, $ChatBlobRowsTable, ChatBlobRow>,
          ),
          ChatBlobRow,
          PrefetchHooks Function()
        > {
  $$ChatBlobRowsTableTableManager(_$ChatDatabase db, $ChatBlobRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ChatBlobRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ChatBlobRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$ChatBlobRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> actor = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatBlobRowsCompanion(
                actor: actor,
                id: id,
                bytes: bytes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String actor,
                required String id,
                required Uint8List bytes,
                Value<int> rowid = const Value.absent(),
              }) => ChatBlobRowsCompanion.insert(
                actor: actor,
                id: id,
                bytes: bytes,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatBlobRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChatDatabase,
      $ChatBlobRowsTable,
      ChatBlobRow,
      $$ChatBlobRowsTableFilterComposer,
      $$ChatBlobRowsTableOrderingComposer,
      $$ChatBlobRowsTableAnnotationComposer,
      $$ChatBlobRowsTableCreateCompanionBuilder,
      $$ChatBlobRowsTableUpdateCompanionBuilder,
      (
        ChatBlobRow,
        BaseReferences<_$ChatDatabase, $ChatBlobRowsTable, ChatBlobRow>,
      ),
      ChatBlobRow,
      PrefetchHooks Function()
    >;

class $ChatDatabaseManager {
  final _$ChatDatabase _db;
  $ChatDatabaseManager(this._db);
  $$ChatLocalRowsTableTableManager get chatLocalRows =>
      $$ChatLocalRowsTableTableManager(_db, _db.chatLocalRows);
  $$ChatBlobRowsTableTableManager get chatBlobRows =>
      $$ChatBlobRowsTableTableManager(_db, _db.chatBlobRows);
}
