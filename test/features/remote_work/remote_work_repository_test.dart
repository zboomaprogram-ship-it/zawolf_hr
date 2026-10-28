import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zawolf_hr/core/sync/authenticated_operation_client.dart';
import 'package:zawolf_hr/features/remote_work/data/remote_work_api.dart';
import 'package:zawolf_hr/features/remote_work/data/remote_work_repository_impl.dart';
import 'package:zawolf_hr/features/remote_work/domain/entities/remote_work_models.dart';

void main() {
  group('RemoteWorkRepositoryImpl', () {
    test('listRemoteDays sends paginated GET request with cursor and limit', () async {
      http.Request? captured;
      final api = RemoteWorkApi(
        baseUri: 'https://example.test',
        client: AuthenticatedOperationClient(
          client: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'ok': true,
                'items': [
                  {
                    'attendanceId': 'u1_2026-11-02',
                    'date': '2026-11-02',
                    'attendanceMode': 'remote_web',
                  }
                ],
                'nextCursor': null,
              }),
              200,
            );
          }),
          tokenProvider: () async => 'firebase-token',
        ),
      );
      final repository = RemoteWorkRepositoryImpl(api: api);

      final days = await repository.listRemoteDays(userId: 'u1', limit: 20);

      expect(days.length, 1);
      expect(days.first['attendanceId'], 'u1_2026-11-02');
      expect(captured!.url.path, '/attendance/remote-work/days');
      expect(captured!.url.queryParameters['limit'], '20');
      expect(captured!.url.queryParameters['userId'], 'u1');
      expect(captured!.headers['authorization'], 'Bearer firebase-token');
    });

    test('submitAttendanceCommand sends authenticated POST command and returns RemoteReceipt', () async {
      http.Request? captured;
      final api = RemoteWorkApi(
        baseUri: 'https://example.test',
        client: AuthenticatedOperationClient(
          client: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'ok': true,
                'operationId': 'op_cin_1',
                'status': 'recorded',
                'attendanceId': 'u1_2026-11-02',
                'sessionId': 'sess_1',
                'mode': 'remote_web',
                'version': 1,
                'serverTime': '2026-11-02T07:00:00.000Z',
              }),
              200,
            );
          }),
          tokenProvider: () async => 'firebase-token',
        ),
      );
      final repository = RemoteWorkRepositoryImpl(api: api);

      const command = RemoteCommand(
        operationId: 'op_cin_1',
        kind: 'check_in',
        date: '2026-11-02',
        payload: {},
        proof: RemoteProof(
          challengeId: 'ch_1',
          credentialId: 'cred_1',
          assertion: {'clientDataJSON': 'abc'},
        ),
      );

      final receipt = await repository.submitAttendanceCommand(command);

      expect(receipt.operationId, 'op_cin_1');
      expect(receipt.status, 'recorded');
      expect(receipt.attendanceId, 'u1_2026-11-02');
      expect(receipt.sessionId, 'sess_1');
      expect(receipt.mode, 'remote_web');
      expect(receipt.version, 1);

      expect(captured!.url.path, '/attendance/remote-work/commands');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['command']['kind'], 'check_in');
      expect(body['command']['operationId'], 'op_cin_1');
    });

    test('RemoteWorkApi maps error codes to RemoteWorkDomainException', () async {
      final api = RemoteWorkApi(
        baseUri: 'https://example.test',
        client: AuthenticatedOperationClient(
          client: MockClient((request) async {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'ok': false,
                  'code': 'mode_locked',
                  'error': 'لا يمكن التبديل بين الدوام المكتبي والعمل عن بعد في نفس اليوم.',
                }),
              ),
              400,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
          tokenProvider: () async => 'firebase-token',
        ),
      );
      final repository = RemoteWorkRepositoryImpl(api: api);

      expect(
        () => repository.submitAttendanceCommand(
          const RemoteCommand(
            operationId: 'op_cin_fail',
            kind: 'check_in',
            payload: {},
          ),
        ),
        throwsA(
          isA<RemoteWorkDomainException>().having(
            (e) => e.code,
            'code',
            'mode_locked',
          ),
        ),
      );
    });
  });
}
