import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/data/local/company_os_database.dart';
import 'package:zawolf_hr/features/company_os/data/local/company_os_outbox.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_sync_state.dart';
import 'package:zawolf_hr/features/organization_structure/data/local/organization_structure_local_store.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_membership.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_snapshot.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_tree.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_unit.dart';

void main() {
  late CompanyOsDatabase database;
  late CompanyOsOutbox outbox;
  late OrganizationStructureLocalStore store;

  setUp(() {
    database = CompanyOsDatabase.forTesting(NativeDatabase.memory());
    outbox = CompanyOsOutbox(database);
    store = OrganizationStructureLocalStore(outbox: outbox, database: database);
  });
  tearDown(() => database.close());

  test('persists a tree-scoped snapshot across store recreation', () async {
    final loadedAt = DateTime.utc(2026, 8, 24, 12);
    final snapshot = OrganizationSnapshot(
      units: const [
        OrganizationUnit(
          id: 'unit-1',
          treeId: 'tree-1',
          type: OrganizationUnitType.department,
          name: 'التشغيل',
          order: 2,
          version: 4,
        ),
      ],
      memberships: const [
        OrganizationMembership(
          id: 'membership-1',
          treeId: 'tree-1',
          employeeUid: 'employee-1',
          employeeName: 'موظف تجريبي',
          employeeCode: 'EMP-1',
          isPrimary: true,
        ),
      ],
      trees: const [
        OrganizationTree(
          id: 'tree-1',
          name: 'الشجرة التجريبية',
          status: OrganizationTreeStatus.active,
          version: 4,
        ),
      ],
      selectedTreeId: 'tree-1',
      version: 4,
      loadedAt: loadedAt,
    );
    await store.cache('tree:tree-1', snapshot);

    final restored = await OrganizationStructureLocalStore(
      outbox: CompanyOsOutbox(database),
      database: database,
    ).snapshot('tree:tree-1');

    expect(restored?.selectedTreeId, 'tree-1');
    expect(restored?.units.single.name, 'التشغيل');
    expect(restored?.memberships.single.isPrimary, isTrue);
    expect(restored?.loadedAt.toUtc(), loadedAt);
  });

  test('queues retryable mutations and reconciles status safely', () async {
    await store.enqueue(
      actorUid: 'actor-1',
      operationId: 'operation-1',
      operationType: 'rename_unit',
      targetId: 'unit-1',
      payload: const {'name': 'قسم جديد'},
      expectedVersion: 2,
    );
    expect(
      await outbox.readyForActor(
        'actor-1',
        DateTime.now().add(const Duration(seconds: 1)),
      ),
      hasLength(1),
    );

    await store.reconcile(
      actorUid: 'actor-1',
      operationId: 'operation-1',
      state: CompanyOsSyncState.needsStatusCheck,
      safeCode: 'status_check_required',
    );
    expect(
      await outbox.readyForActor(
        'actor-1',
        DateTime.now().add(const Duration(seconds: 1)),
      ),
      isEmpty,
    );
  });
}
