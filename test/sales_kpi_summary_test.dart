import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/sales_kpi_summary.dart';

void main() {
  test('SalesKpiSummary parses API summary values defensively', () {
    final syncedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 29, 8));
    final summary = SalesKpiSummary.fromMap({
      'periodKey': '2026-08',
      'periodStart': '2026-07-26',
      'periodEnd': '2026-08-25',
      'totalLeads': 120,
      'confirmedMeetings': 42.0,
      'closings': 8,
      'paidCustomers': 5,
      'totalPrice': 750000,
      'currency': 'SAR',
      'salesConversionRate': 0.25,
      'mappedEmployees': 7,
      'unmatchedEmployees': 1,
      'createdTasks': 28,
      'syncedAt': syncedAt,
    });

    expect(summary.periodKey, '2026-08');
    expect(summary.confirmedMeetings, 42);
    expect(summary.totalPrice, 750000);
    expect(summary.currency, 'SAR');
    expect(summary.salesConversionRate, 0.25);
    expect(summary.mappedEmployees, 7);
    expect(
      summary.syncedAt?.millisecondsSinceEpoch,
      DateTime.utc(2026, 7, 29, 8).millisecondsSinceEpoch,
    );
    expect(summary.teleSalesTarget, 0);
  });

  test('SalesKpiSummary defaults legacy records to SAR', () {
    final summary = SalesKpiSummary.fromMap(const {});
    expect(summary.currency, 'SAR');
  });

  test('SalesKpiSummary exposes API identity diagnostics', () {
    final summary = SalesKpiSummary.fromMap({
      'apiAgentCount': 24,
      'apiIdentifiedAgentCount': 0,
      'apiMissingAgentIdCount': 24,
      'apiIdentityMappingReady': false,
      'integrationWarnings': ['API agent ids are missing'],
      'unmappedApiAgentKeys': ['s4', 'tsm2'],
    });

    expect(summary.apiAgentCount, 24);
    expect(summary.apiMissingAgentIdCount, 24);
    expect(summary.apiIdentityMappingReady, isFalse);
    expect(summary.integrationWarnings, hasLength(1));
    expect(summary.unmappedApiAgentKeys, ['s4', 'tsm2']);
  });

  test(
    'legacy tele-sales agent mappings use the persisted tele_sales kind',
    () {
      final summary = SalesKpiSummary.fromMap({
        'agentSummaries': [
          {
            'kind': 'tele_sales',
            'mappedUserId': 'user-1',
            'mappedEmployeeId': 'BD-1201',
          },
        ],
      });

      expect(summary.effectiveTeleSalesMappedEmployees, 1);
    },
  );
}
