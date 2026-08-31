import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'company_os_database.g.dart';

class CompanyOsOutboxRows extends Table {
  TextColumn get operationId => text()();
  TextColumn get actorUid => text()();
  TextColumn get operationType => text()();
  TextColumn get targetId => text()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  IntColumn get expectedVersion => integer().nullable()();
  TextColumn get state => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get lastSafeCode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {operationId};
}

class CompanyOsSnapshotRows extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get loadedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {cacheKey};
}

@DriftDatabase(tables: [CompanyOsOutboxRows, CompanyOsSnapshotRows])
class CompanyOsDatabase extends _$CompanyOsDatabase {
  CompanyOsDatabase() : super(driftDatabase(name: 'company_os'));

  CompanyOsDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createTable(companyOsSnapshotRows);
    },
  );
}
