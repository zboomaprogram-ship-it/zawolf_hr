import '../../domain/entities/company_os_page.dart';
import '../../domain/entities/financial_ledger_entry.dart';
import '../../domain/entities/payslip_summary.dart';
import '../../domain/repositories/finance_repository.dart';
import '../remote/company_os_api_client.dart';

final class FinanceRepositoryImpl implements FinanceRepository {
  FinanceRepositoryImpl(this._api);
  final CompanyOsApiClient _api;
  final Map<String, ({DateTime expiresAt, Object? value})> _cache = {};

  @override
  Future<CompanyOsPage<FinancialLedgerEntry>> ledger({
    required DateTime from,
    required DateTime to,
    String? employeeUid,
    String? cursor,
    int limit = 25,
  }) async {
    final cacheKey =
        'ledger:${from.toUtc()}:${to.toUtc()}:$employeeUid:$cursor:$limit';
    final cached = _cache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.value as CompanyOsPage<FinancialLedgerEntry>;
    }
    final page = await _api.list(
      '/finance/ledger',
      cursor: cursor,
      limit: limit,
      filters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        if (employeeUid != null && employeeUid.isNotEmpty)
          'employeeUid': employeeUid,
      },
    );
    final result = CompanyOsPage(
      items: page.items.map(_entry).toList(growable: false),
      appliedScope: page.appliedScope,
      nextCursor: page.nextCursor,
      appliedFilters: page.appliedFilters,
    );
    _cache[cacheKey] = (
      expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      value: result,
    );
    return result;
  }

  @override
  Future<PayslipSummary?> payslip({
    required String period,
    String? employeeUid,
  }) async {
    final cacheKey = 'payslip:$period:$employeeUid';
    final cached = _cache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.value as PayslipSummary?;
    }
    final row = await _api.getOptionalObject(
      '/finance/payslip',
      filters: {
        'period': period,
        if (employeeUid != null && employeeUid.isNotEmpty)
          'employeeUid': employeeUid,
      },
    );
    final result = row == null ? null : _payslip(row);
    _cache[cacheKey] = (
      expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      value: result,
    );
    return result;
  }

  FinancialLedgerEntry _entry(Map<String, Object?> row) => FinancialLedgerEntry(
    id: '${row['id'] ?? ''}',
    employeeUid: '${row['employeeUid'] ?? ''}',
    entryType: '${row['entryType'] ?? ''}',
    sourceType: '${row['sourceType'] ?? ''}',
    sourceId: '${row['sourceId'] ?? ''}',
    effectiveDate:
        DateTime.tryParse('${row['effectiveDate']}')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    amount: row['amount'] is num
        ? row['amount'] as num
        : num.tryParse('${row['amount']}') ?? 0,
    currency: '${row['currency'] ?? 'EGP'}',
    direction: '${row['direction'] ?? ''}',
    status: '${row['status'] ?? ''}',
    description: '${row['description'] ?? ''}',
  );

  PayslipSummary _payslip(Map<String, Object?> row) => PayslipSummary(
    id: '${row['id'] ?? ''}',
    employeeUid: '${row['employeeUid'] ?? ''}',
    period: '${row['period'] ?? ''}',
    gross: _number(row['gross']),
    net: _number(row['net']),
    deductions: _number(row['deductions']),
    currency: '${row['currency'] ?? 'EGP'}',
  );

  num _number(Object? value) =>
      value is num ? value : num.tryParse('$value') ?? 0;
}
