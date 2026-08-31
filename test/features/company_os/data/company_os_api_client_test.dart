import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zawolf_hr/core/sync/authenticated_operation_client.dart';
import 'package:zawolf_hr/features/company_os/data/remote/company_os_api_client.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_safe_error.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_sync_state.dart';

void main() {
  test('validates a saved mutation receipt', () async {
    final api = _api(
      (request) async => http.Response(
        '{"ok":true,"operationId":"operation-0001","status":"saved","resourceId":"ticket-1","version":2}',
        200,
      ),
    );
    final result = await api.mutate(
      '/tickets',
      operationId: 'operation-0001',
      payload: const {'subject': 'حاسوب'},
    );
    expect(result.status, CompanyOsSyncState.synced);
    expect(result.resourceId, 'ticket-1');
  });

  test('maps raw or malformed server failures to safe Arabic errors', () async {
    final api = _api(
      (request) async => http.Response(
        'FirebaseException permission-denied token=secret',
        500,
      ),
    );
    try {
      await api.list('/tickets');
      fail('expected a safe error');
    } on CompanyOsSafeError catch (error) {
      expect(error.code, CompanyOsSafeCode.temporaryUnavailable);
      expect(error.arabicMessage, isNot(contains('Firebase')));
      expect(error.arabicMessage, isNot(contains('secret')));
    }
  });

  test('rejects unbounded list page sizes before transport', () async {
    final api = _api((request) async => http.Response('{}', 200));
    expect(() => api.list('/tickets', limit: 500), throwsArgumentError);
  });

  test('validates a bounded object envelope and safeCode failures', () async {
    final objectApi = _api(
      (request) async =>
          http.Response('{"ok":true,"data":{"id":"ticket-1"}}', 200),
    );
    expect((await objectApi.getObject('/tickets/ticket-1'))['id'], 'ticket-1');

    final deniedApi = _api(
      (request) async =>
          http.Response('{"ok":false,"safeCode":"access_denied"}', 403),
    );
    expect(
      () => deniedApi.getObject('/tickets/private'),
      throwsA(
        isA<CompanyOsSafeError>().having(
          (error) => error.code,
          'code',
          CompanyOsSafeCode.accessDenied,
        ),
      ),
    );
  });
}

CompanyOsApiClient _api(
  Future<http.Response> Function(http.Request request) handler,
) {
  final transport = AuthenticatedOperationClient(
    client: MockClient(handler),
    tokenProvider: () async => 'firebase-id-token',
  );
  return CompanyOsApiClient(
    baseUri: Uri.parse('https://notification.zawolf.ai/company-os/'),
    client: transport,
  );
}
