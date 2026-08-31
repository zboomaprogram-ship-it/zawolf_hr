import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zawolf_hr/core/sync/authenticated_operation_client.dart';

void main() {
  test(
    'authenticated operation sends an idempotency ID without exposing it in a log API',
    () async {
      final client = AuthenticatedOperationClient(
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer session-token');
          expect(request.headers['x-operation-id'], 'operation-1');
          expect(request.body, contains('operation-1'));
          return http.Response('{"ok":true,"code":"saved"}', 200);
        }),
        tokenProvider: () async => 'session-token',
      );

      final response = await client.post(
        Uri.parse('https://notification.zawolf.ai/operations/example'),
        operationId: 'operation-1',
      );
      expect(response.ok, isTrue);
      expect(response.safeCode, 'saved');
    },
  );

  test('missing session produces a safe envelope', () async {
    final client = AuthenticatedOperationClient(
      client: MockClient((_) async => http.Response('', 500)),
      tokenProvider: () async => null,
    );
    final response = await client.post(
      Uri.parse('https://notification.zawolf.ai/operations/example'),
      operationId: 'operation-1',
    );
    expect(response.safeCode, 'session_expired');
  });

  test('GET uses a session token without exposing it in the URL', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.headers['authorization'], 'Bearer token');
      expect(request.url.queryParameters.containsKey('token'), isFalse);
      return http.Response('{"ok":true,"code":"loaded"}', 200);
    });
    final operationClient = AuthenticatedOperationClient(
      client: client,
      tokenProvider: () async => 'token',
    );

    final response = await operationClient.get(
      Uri.parse('https://notification.zawolf.ai/operations/developer-tools/me'),
    );

    expect(response.ok, isTrue);
    expect(response.safeCode, 'loaded');
  });
}
