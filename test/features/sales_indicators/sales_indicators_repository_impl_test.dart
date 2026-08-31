import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zawolf_hr/core/sync/authenticated_operation_client.dart';
import 'package:zawolf_hr/features/sales_indicators/data/sales_indicators_repository_impl.dart';
import 'package:zawolf_hr/features/sales_indicators/domain/entities/sales_indicator_filter.dart';
import 'package:zawolf_hr/features/sales_indicators/domain/repositories/sales_indicators_repository.dart';

void main() {
  test(
    'preserves provider totals for visible but safely unmapped rows',
    () async {
      final transport = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'ok': true,
            'snapshot': {
              'filters': const <String, Object?>{},
              'sourceHealth': 'partial',
              'agentSummaries': [
                {
                  'kind': 'sales',
                  'key': 'S4',
                  'name': 'Yara',
                  'mappingStatus': 'unmapped',
                  'target': 20000,
                  'actual': 11500,
                  'finalKpi': 57.5,
                },
              ],
            },
          }),
          200,
        ),
      );
      final repository = SalesIndicatorsRepositoryImpl(
        operationClient: AuthenticatedOperationClient(
          client: transport,
          tokenProvider: () async => 'test-token',
        ),
        operationsBaseUri: Uri.parse('https://notification.zawolf.ai'),
      );

      final result = await repository.load(
        const SalesIndicatorFilter(
          startDate: '2026-08-01',
          endDate: '2026-08-25',
        ),
      );

      final loaded = result as SalesIndicatorsLoaded;
      expect(loaded.snapshot.rows.single.actual, 11500);
      expect(loaded.snapshot.rows.single.target, 20000);
      expect(loaded.snapshot.rows.single.finalKpi, 57.5);
      expect(loaded.snapshot.rows.single.isMapped, isFalse);
    },
  );

  test('syncs a missing filtered snapshot and retries the read once', () async {
    var reads = 0;
    var syncs = 0;
    final transport = MockClient((request) async {
      if (request.url.path == '/operations/sales-indicators/sync') {
        syncs += 1;
        expect(request.method, 'POST');
        expect(request.headers['x-operation-id'], startsWith('sales-sync-'));
        return http.Response(jsonEncode({'ok': true, 'code': 'synced'}), 200);
      }
      expect(request.url.path, '/operations/sales-indicators');
      reads += 1;
      if (reads == 1) {
        return http.Response(
          jsonEncode({'ok': false, 'code': 'snapshot_not_ready'}),
          409,
        );
      }
      return http.Response(
        jsonEncode({
          'ok': true,
          'snapshot': {
            'snapshotId': 'filtered-snapshot',
            'filterVersion': 'v1',
            'filters': {
              'startDate': '2026-08-01',
              'endDate': '2026-08-25',
              'company': 'SEG',
              'sales': ['S4'],
              'teleSales': <String>[],
              'entryChannel': 'ALL',
              'salesTarget': 20000,
              'teleTarget': 50,
            },
            'sourceHealth': 'healthy',
            'agentSummaries': <Object>[],
          },
        }),
        200,
      );
    });
    final repository = SalesIndicatorsRepositoryImpl(
      operationClient: AuthenticatedOperationClient(
        client: transport,
        tokenProvider: () async => 'test-token',
      ),
      operationsBaseUri: Uri.parse('https://notification.zawolf.ai'),
    );

    final result = await repository.load(
      const SalesIndicatorFilter(
        startDate: '2026-08-01',
        endDate: '2026-08-25',
        company: 'SEG',
        sales: ['S4'],
      ),
    );

    expect(result, isA<SalesIndicatorsLoaded>());
    expect(reads, 2);
    expect(syncs, 1);
  });
}
