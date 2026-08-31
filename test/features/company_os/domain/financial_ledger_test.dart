import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/financial_ledger_entry.dart';

void main() {
  test(
    'ledger entry points to a source and effective period without payroll mutation',
    () {
      final entry = FinancialLedgerEntry(
        id: 'l1',
        employeeUid: 'u1',
        entryType: 'expense',
        sourceType: 'operational_request',
        sourceId: 'r1',
        effectiveDate: DateTime(2026, 7, 22),
        amount: 100,
        currency: 'EGP',
        direction: 'debit',
        status: 'approved',
        description: 'طلب تكلفة',
      );
      expect(entry.sourceId, 'r1');
      expect(entry.effectiveDate.month, 7);
    },
  );
}
