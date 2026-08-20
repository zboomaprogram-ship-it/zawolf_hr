import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/entities/check_in_action.dart';
import '../../domain/entities/pending_check_in.dart';
import 'checkin_outbox.dart';

part 'checkin_outbox_database.g.dart';

class PendingCheckInRows extends Table {
  TextColumn get actionId => text()();
  TextColumn get employeeScopeId => text()();
  TextColumn get dateKey => text()();
  DateTimeColumn get capturedAt => dateTime()();
  TextColumn get payloadJson => text()();
  TextColumn get state => text()();
  IntColumn get attemptCount => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {actionId};
}

@DriftDatabase(tables: [PendingCheckInRows])
class CheckInOutboxDatabase extends _$CheckInOutboxDatabase {
  CheckInOutboxDatabase()
    : super(driftDatabase(name: 'attendance_checkin_outbox'));

  /// Keeps the production database platform-owned while allowing deterministic
  /// in-memory verification of account isolation and persistence semantics.
  CheckInOutboxDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

class DriftCheckInOutbox implements CheckInOutbox {
  DriftCheckInOutbox(this._database);

  final CheckInOutboxDatabase _database;

  @override
  Future<PendingCheckIn?> getForEmployee(String employeeScopeId) async {
    final row =
        await (_database.select(_database.pendingCheckInRows)
              ..where((row) => row.employeeScopeId.equals(employeeScopeId))
              ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> put(PendingCheckIn item) async {
    await _database
        .into(_database.pendingCheckInRows)
        .insertOnConflictUpdate(
          PendingCheckInRowsCompanion.insert(
            actionId: item.action.actionId,
            employeeScopeId: item.action.employeeScopeId,
            dateKey: item.action.dateKey,
            capturedAt: item.action.capturedAt.toUtc(),
            payloadJson: jsonEncode(item.action.payload),
            state: item.state.name,
            attemptCount: item.attemptCount,
            updatedAt: item.updatedAt.toUtc(),
          ),
        );
  }

  @override
  Future<void> remove(String actionId, String employeeScopeId) async {
    await (_database.delete(_database.pendingCheckInRows)..where(
          (row) =>
              row.actionId.equals(actionId) &
              row.employeeScopeId.equals(employeeScopeId),
        ))
        .go();
  }

  PendingCheckIn _toDomain(PendingCheckInRow row) {
    final rawPayload = jsonDecode(row.payloadJson);
    return PendingCheckIn(
      action: CheckInAction(
        actionId: row.actionId,
        employeeScopeId: row.employeeScopeId,
        dateKey: row.dateKey,
        capturedAt: row.capturedAt.toUtc(),
        payload: rawPayload is Map
            ? rawPayload.map((key, value) => MapEntry('$key', value))
            : const {},
      ),
      state: PendingCheckInState.values.byName(row.state),
      attemptCount: row.attemptCount,
      updatedAt: row.updatedAt,
    );
  }
}
