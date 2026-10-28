import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zawolf_hr/core/sync/authenticated_operation_client.dart';
import 'package:zawolf_hr/features/remote_work/data/remote_policy_api.dart';
import 'package:zawolf_hr/features/remote_work/data/remote_policy_repository_impl.dart';
import 'package:zawolf_hr/features/remote_work/domain/entities/remote_policy.dart';

void main() {
  test(
    'remote policy draft uses authenticated versioned command endpoint',
    () async {
      http.Request? captured;
      final api = RemotePolicyApi(
        baseUri: 'https://example.test',
        client: AuthenticatedOperationClient(
          client: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'ok': true,
                'operationId': 'op-1',
                'draftId': 'draft-1',
                'status': 'draft_saved',
                'version': 2,
              }),
              200,
            );
          }),
          tokenProvider: () async => 'firebase-token',
        ),
      );
      final repository = RemotePolicyRepositoryImpl(api: api);

      final receipt = await repository.saveDraft(
        operationId: 'op-1',
        draftId: 'draft-1',
        expectedVersion: 1,
        aggregate: const RemotePolicyAggregate(
          attendancePolicy: {'defaultStartTime': '08:30'},
          remoteWorkPolicy: {'enabled': false},
        ),
        effectiveFrom: DateTime.utc(2026, 12, 1),
      );

      expect(receipt.status, 'draft_saved');
      expect(receipt.version, 2);
      expect(captured!.url.path, '/attendance/remote-work/policies/commands');
      expect(captured!.headers['authorization'], 'Bearer firebase-token');
      final request = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(request['command']['kind'], 'save_policy_draft');
      expect(request['command']['expectedVersion'], 1);
      expect(
        request['command']['payload']['aggregate']['attendancePolicy']['remoteWorkPolicy']['enabled'],
        false,
      );
    },
  );

  test(
    'aggregate migration retains legacy shared fields and remote extensions',
    () {
      final aggregate = RemotePolicyAggregate.fromMap({
        'attendancePolicy': {
          'defaultStartTime': '08:15',
          'remoteWorkPolicy': {
            'enabled': false,
            'extraSchemaField': {'value': 3},
          },
        },
        'revision': 4,
        'version': 7,
      });

      expect(aggregate.revision, 4);
      expect(aggregate.version, 7);
      expect(aggregate.attendancePolicy['defaultStartTime'], '08:15');
      expect(aggregate.toAggregateMap()['remoteWorkPolicy'], {
        'enabled': false,
        'extraSchemaField': {'value': 3},
      });
    },
  );
}
