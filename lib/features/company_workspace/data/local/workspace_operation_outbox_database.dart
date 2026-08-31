import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'dart:convert';

import '../../../../core/sync/workspace_operation_outbox.dart';
import '../../domain/entities/workspace_operation.dart';

part 'workspace_operation_outbox_database.g.dart';

class PendingWorkspaceOperationRows extends Table {
  TextColumn get operationId => text()();
  TextColumn get actorId => text()();
  TextColumn get resourceId => text()();
  TextColumn get kind => text()();
  TextColumn get state => text()();
  TextColumn get expectedVersion => text().nullable()();
  TextColumn get safeMessage => text().nullable()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {operationId};
}

@DriftDatabase(tables: [PendingWorkspaceOperationRows])
class WorkspaceOperationOutboxDatabase
    extends _$WorkspaceOperationOutboxDatabase {
  WorkspaceOperationOutboxDatabase()
    : super(driftDatabase(name: 'company_workspace_outbox'));

  WorkspaceOperationOutboxDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  /// Existing pilot devices may already have the original outbox table. Keep
  /// their pending operations intact while adding the serialised payload used
  /// by spreadsheet batch edits and structural operations.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(
          pendingWorkspaceOperationRows,
          pendingWorkspaceOperationRows.payloadJson,
        );
      }
    },
  );
}

class DriftWorkspaceOperationOutbox implements WorkspaceOperationOutbox {
  DriftWorkspaceOperationOutbox(this._database);

  final WorkspaceOperationOutboxDatabase _database;

  @override
  Future<void> put(WorkspaceOperation operation) => _database
      .into(_database.pendingWorkspaceOperationRows)
      .insertOnConflictUpdate(
        PendingWorkspaceOperationRowsCompanion.insert(
          operationId: operation.id,
          actorId: operation.actorId,
          resourceId: operation.resourceId,
          kind: operation.kind.name,
          state: operation.state.name,
          expectedVersion: Value(operation.expectedVersion),
          safeMessage: Value(operation.safeMessage),
          payloadJson: Value(jsonEncode(operation.payload)),
          createdAt: operation.createdAt.toUtc(),
        ),
      );

  @override
  Future<List<WorkspaceOperation>> pendingForActor(String actorId) async {
    final rows =
        await (_database.select(_database.pendingWorkspaceOperationRows)
              ..where(
                (row) =>
                    row.actorId.equals(actorId) & row.state.equals('pending'),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<void> remove(String operationId, String actorId) =>
      (_database.delete(_database.pendingWorkspaceOperationRows)..where(
            (row) =>
                row.operationId.equals(operationId) &
                row.actorId.equals(actorId),
          ))
          .go();

  WorkspaceOperation _toDomain(PendingWorkspaceOperationRow row) =>
      WorkspaceOperation(
        id: row.operationId,
        actorId: row.actorId,
        resourceId: row.resourceId,
        kind: WorkspaceOperationKind.values.byName(row.kind),
        createdAt: row.createdAt.toUtc(),
        expectedVersion: row.expectedVersion,
        state: WorkspaceOperationState.values.byName(row.state),
        safeMessage: row.safeMessage,
        payload: _decodePayload(row.payloadJson),
      );

  Map<String, Object?> _decodePayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? Map<String, Object?>.from(decoded)
          : const <String, Object?>{};
    } on FormatException {
      return const <String, Object?>{};
    }
  }
}
