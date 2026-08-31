import '../entities/company_os_page.dart';
import '../entities/financial_ledger_entry.dart';
import '../entities/payslip_summary.dart';

abstract interface class FinanceRepository {
  Future<CompanyOsPage<FinancialLedgerEntry>> ledger({
    required DateTime from,
    required DateTime to,
    String? employeeUid,
    String? cursor,
    int limit = 25,
  });

  Future<PayslipSummary?> payslip({
    required String period,
    String? employeeUid,
  });
}
