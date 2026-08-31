import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zawolf_hr/core/sync/authenticated_operation_client.dart';
import 'package:zawolf_hr/features/company_os/data/local/company_os_database.dart';
import 'package:zawolf_hr/features/company_os/data/local/company_os_outbox.dart';
import 'package:zawolf_hr/features/company_os/data/remote/company_os_api_client.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_safe_error.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_sync_state.dart';
import 'package:zawolf_hr/features/organization_structure/data/local/organization_structure_local_store.dart';
import 'package:zawolf_hr/features/organization_structure/data/remote/organization_structure_api.dart';
import 'package:zawolf_hr/features/organization_structure/data/repositories/organization_structure_repository_impl.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_change_set.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_snapshot.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_tree.dart';

void main() {
  late CompanyOsDatabase database;
  late CompanyOsOutbox outbox;
  late OrganizationStructureLocalStore local;

  setUp(() {
    database = CompanyOsDatabase.forTesting(NativeDatabase.memory());
    outbox = CompanyOsOutbox(database);
    local = OrganizationStructureLocalStore(outbox: outbox, database: database);
  });

  tearDown(() => database.close());

  OrganizationStructureRepositoryImpl repository(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    final operationClient = AuthenticatedOperationClient(
      client: MockClient(handler),
      tokenProvider: () async => 'test-token',
    );
    return OrganizationStructureRepositoryImpl(
      api: OrganizationStructureApi(
        CompanyOsApiClient(
          baseUri: Uri.parse('https://example.test/company-os/'),
          client: operationClient,
        ),
      ),
      local: local,
      actorUid: 'actor-1',
    );
  }

  const change = OrganizationChangeSet(
    operationId: 'operation-1',
    kind: 'rename_unit',
    expectedVersion: 2,
    payload: {'unitId': 'unit-1', 'name': 'قسم جديد'},
  );

  test('saved mutation returns a synced receipt', () async {
    final result = await repository(
      (_) async => http.Response(
        jsonEncode({
          'ok': true,
          'operationId': 'operation-1',
          'status': 'saved',
          'resourceId': 'unit-1',
          'version': 3,
        }),
        200,
      ),
    ).apply(change);

    expect(result.status, CompanyOsSyncState.synced);
    expect(result.version, 3);
  });

  test('temporary interruption queues exactly one pending mutation', () async {
    final result = await repository(
      (_) async => throw http.ClientException('offline'),
    ).apply(change);

    expect(result.status, CompanyOsSyncState.pending);
    expect(
      await outbox.readyForActor(
        'actor-1',
        DateTime.now().add(const Duration(seconds: 1)),
      ),
      hasLength(1),
    );
  });

  test('conflict is surfaced and is never queued for blind retry', () async {
    final repo = repository(
      (_) async =>
          http.Response(jsonEncode({'ok': false, 'code': 'conflict'}), 409),
    );

    await expectLater(
      repo.apply(change),
      throwsA(
        isA<CompanyOsSafeError>().having(
          (error) => error.code,
          'code',
          CompanyOsSafeCode.conflict,
        ),
      ),
    );
    expect(
      await outbox.readyForActor(
        'actor-1',
        DateTime.now().add(const Duration(seconds: 1)),
      ),
      isEmpty,
    );
  });

  test('status check reconciles an interrupted operation', () async {
    await local.enqueue(
      actorUid: 'actor-1',
      operationId: 'operation-1',
      operationType: 'rename_unit',
      targetId: 'unit-1',
      payload: change.payload,
      expectedVersion: 2,
    );
    final result = await repository(
      (_) async => http.Response(
        jsonEncode({
          'ok': true,
          'data': {
            'operationId': 'operation-1',
            'status': 'status_check_required',
            'safeCode': 'status_check_required',
          },
        }),
        200,
      ),
    ).operationStatus('operation-1');

    expect(result?.status, CompanyOsSyncState.needsStatusCheck);
    expect(
      await outbox.readyForActor(
        'actor-1',
        DateTime.now().add(const Duration(seconds: 1)),
      ),
      isEmpty,
    );
  });

  test(
    'remote failure falls back to the durable stale tree snapshot',
    () async {
      final oldLoadedAt = DateTime.utc(2026, 8, 1);
      await local.cache(
        'tree:tree-1',
        OrganizationSnapshot(
          units: const [],
          memberships: const [],
          trees: const [
            OrganizationTree(
              id: 'tree-1',
              name: 'شجرة مخزنة',
              status: OrganizationTreeStatus.active,
              version: 4,
            ),
          ],
          selectedTreeId: 'tree-1',
          version: 4,
          loadedAt: oldLoadedAt,
        ),
      );

      final result = await repository(
        (_) async => throw http.ClientException('offline'),
      ).loadTreeSnapshot('tree-1');

      expect(result.trees.single.name, 'شجرة مخزنة');
      expect(result.loadedAt.toUtc(), oldLoadedAt);
    },
  );
}
