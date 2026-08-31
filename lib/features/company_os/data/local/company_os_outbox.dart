import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/company_os_pending_operation.dart';
import '../../domain/entities/company_os_sync_state.dart';
import 'company_os_database.dart';

final class CompanyOsOutbox {
  CompanyOsOutbox(this._database);

  final CompanyOsDatabase _database;

  Future<void> put(CompanyOsPendingOperation operation) => _database
      .into(_database.companyOsOutboxRows)
      .insertOnConflictUpdate(
        CompanyOsOutboxRowsCompanion.insert(
          operationId: operation.operationId,
          actorUid: operation.actorUid,
          operationType: operation.operationType,
          targetId: operation.targetId,
          payloadJson: Value(jsonEncode(operation.payload)),
          expectedVersion: Value(operation.expectedVersion),
          state: operation.state.name,
          attemptCount: Value(operation.attemptCount),
          nextAttemptAt: operation.nextAttemptAt.toUtc(),
          createdAt: operation.createdAt.toUtc(),
          lastSafeCode: Value(operation.lastSafeCode),
        ),
      );

  Future<List<CompanyOsPendingOperation>> readyForActor(
    String actorUid,
    DateTime now, {
    int limit = 25,
  }) async {
    final safeLimit = limit.clamp(1, 25);
    final rows =
        await (_database.select(_database.companyOsOutboxRows)
              ..where(
                (row) =>
                    row.actorUid.equals(actorUid) &
                    row.state.equals(CompanyOsSyncState.pending.name) &
                    row.nextAttemptAt.isSmallerOrEqualValue(now.toUtc()),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
              ..limit(safeLimit))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  Future<void> reconcile({
    required String operationId,
    required String actorUid,
    required CompanyOsSyncState state,
    String? lastSafeCode,
  }) =>
      (_database.update(_database.companyOsOutboxRows)..where(
            (row) =>
                row.operationId.equals(operationId) &
                row.actorUid.equals(actorUid),
          ))
          .write(
            CompanyOsOutboxRowsCompanion(
              state: Value(state.name),
              lastSafeCode: Value(lastSafeCode),
            ),
          );

  Future<void> remove(String operationId, String actorUid) =>
      (_database.delete(_database.companyOsOutboxRows)..where(
            (row) =>
                row.operationId.equals(operationId) &
                row.actorUid.equals(actorUid),
          ))
          .go();

  Duration retryDelay(int attempt) {
    final seconds = 5 * (1 << attempt.clamp(0, 5));
    return Duration(seconds: seconds.clamp(5, 120));
  }

  CompanyOsPendingOperation _toDomain(CompanyOsOutboxRow row) =>
      CompanyOsPendingOperation(
        operationId: row.operationId,
        actorUid: row.actorUid,
        operationType: row.operationType,
        targetId: row.targetId,
        payload: _payload(row.payloadJson),
        expectedVersion: row.expectedVersion,
        state: CompanyOsSyncState.values.byName(row.state),
        attemptCount: row.attemptCount,
        nextAttemptAt: row.nextAttemptAt.toUtc(),
        createdAt: row.createdAt.toUtc(),
        lastSafeCode: row.lastSafeCode,
      );

  Map<String, Object?> _payload(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic>
          ? Map<String, Object?>.from(value)
          : const {};
    } catch (_) {
      return const {};
    }
  }
}
