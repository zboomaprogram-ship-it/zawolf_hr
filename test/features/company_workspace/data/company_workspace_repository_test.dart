import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zawolf_hr/core/errors/errors.dart';
import 'package:zawolf_hr/core/sync/workspace_operation_outbox.dart';
import 'package:zawolf_hr/features/company_workspace/data/datasources/company_workspace_remote_data_source.dart';
import 'package:zawolf_hr/features/company_workspace/data/models/workspace_operation_dto.dart';
import 'package:zawolf_hr/features/company_workspace/data/repositories/company_workspace_repository_impl.dart';
import 'package:zawolf_hr/features/company_workspace/data/datasources/workspace_resource_remote_data_source.dart';
import 'package:zawolf_hr/features/company_workspace/data/datasources/workspace_access_admin_remote_data_source.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_access_grant.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_capability.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_operation.dart';

void main() {
  final operation = WorkspaceOperation(
    id: 'stable-op-1',
    actorId: 'actor-1',
    resourceId: 'resource-1',
    kind: WorkspaceOperationKind.sheetEdit,
    createdAt: DateTime.utc(2026, 8, 20),
    expectedVersion: 'v1',
  );

  test(
    'gateway refreshes identity and sends only the stable operation ID',
    () async {
      late http.Request captured;
      final remote = HttpCompanyWorkspaceRemoteDataSource(
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'state': 'acknowledged'}), 200);
        }),
        session: const _Session('fresh-token'),
        baseUri: Uri.parse('https://workspace.example/'),
      );

      await remote.submitOperation(WorkspaceOperationDto.fromDomain(operation));

      expect(captured.headers['authorization'], 'Bearer fresh-token');
      expect(captured.headers['x-workspace-operation-id'], operation.id);
      expect(captured.body, isNot(contains(operation.actorId)));
    },
  );

  test(
    'gateway converts a provider denial into a safe structured failure',
    () async {
      final remote = HttpCompanyWorkspaceRemoteDataSource(
        client: MockClient(
          (_) async => http.Response('provider stack trace', 403),
        ),
        session: const _Session('fresh-token'),
        baseUri: Uri.parse('https://workspace.example/'),
      );

      await expectLater(
        () =>
            remote.submitOperation(WorkspaceOperationDto.fromDomain(operation)),
        throwsA(
          isA<WorkspaceRemoteFailure>().having(
            (error) => error.failure.category,
            'category',
            FailureCategory.access,
          ),
        ),
      );
    },
  );

  test('unconfirmed write remains in outbox and reuses its ID', () async {
    final outbox = _MemoryOutbox();
    final repository = CompanyWorkspaceRepositoryImpl(
      remote: const _UnavailableRemote(),
      outbox: outbox,
      grantsLoader: (_) async => const <WorkspaceAccessGrant>[],
      accessChecker: ({required resourceId, required capability}) async => true,
    );

    final result = await repository.submit(operation);

    expect(result.state, WorkspaceOperationState.pending);
    expect(
      (await outbox.pendingForActor(operation.actorId)).single.id,
      operation.id,
    );
  });

  test('resource page mapper accepts only safe resource metadata', () async {
    final remote = HttpWorkspaceResourceRemoteDataSource(
      client: MockClient((request) async {
        expect(request.url.path, '/company-workspace/v2/resources');
        return http.Response(
          jsonEncode({
            'resources': [
              {
                'id': 'resource-1',
                'name': 'ملف المبيعات',
                'type': 'spreadsheet',
                'version': 'v1',
                'capabilities': ['view', 'edit'],
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      session: const _Session('fresh-token'),
      baseUri: Uri.parse('https://workspace.example/'),
    );

    final page = await remote.listAccessible(parentId: null);

    expect(page.resources.single.name, 'ملف المبيعات');
    expect(page.resources.single.can(WorkspaceCapability.edit), isTrue);
  });

  test(
    'workspace configuration refreshes and retries once after an expired token',
    () async {
      var calls = 0;
      final remote = HttpWorkspaceAccessAdminRemoteDataSource(
        client: MockClient((request) async {
          calls++;
          if (calls == 1) return http.Response('{"error":"Unauthorized"}', 401);
          expect(request.headers['authorization'], 'Bearer renewed-token');
          return http.Response('{"ok":true,"enabled":false}', 200);
        }),
        session: _RefreshingSession(),
        baseUri: Uri.parse('https://workspace.example/'),
      );

      await expectLater(
        remote.loadPilotConfiguration(),
        completion(isNotEmpty),
      );
      expect(calls, 2);
    },
  );
}

final class _Session implements WorkspaceSession {
  const _Session(this.token);
  final String token;

  @override
  Future<String?> refreshedBearerToken() async => token;
}

final class _RefreshingSession implements WorkspaceSession {
  var _calls = 0;

  @override
  Future<String?> refreshedBearerToken() async =>
      ++_calls == 1 ? 'expired-token' : 'renewed-token';
}

final class _UnavailableRemote implements CompanyWorkspaceRemoteDataSource {
  const _UnavailableRemote();

  @override
  Future<WorkspaceOperationReceiptDto> submitOperation(
    WorkspaceOperationDto operation,
  ) =>
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.connectivity(writeMayHaveStarted: true),
      );
}

final class _MemoryOutbox implements WorkspaceOperationOutbox {
  final Map<String, WorkspaceOperation> _operations = {};

  @override
  Future<void> put(WorkspaceOperation operation) async {
    _operations[operation.id] = operation;
  }

  @override
  Future<List<WorkspaceOperation>> pendingForActor(String actorId) async =>
      _operations.values
          .where(
            (operation) =>
                operation.actorId == actorId &&
                operation.state == WorkspaceOperationState.pending,
          )
          .toList(growable: false);

  @override
  Future<void> remove(String operationId, String actorId) async {
    final operation = _operations[operationId];
    if (operation?.actorId == actorId) _operations.remove(operationId);
  }
}
