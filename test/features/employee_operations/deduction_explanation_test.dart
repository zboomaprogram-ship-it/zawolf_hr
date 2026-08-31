import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/employee_operations/domain/entities/deduction_explanation.dart';
import 'package:zawolf_hr/utils/permission_cycle_accounting.dart';

void main() {
  test('late approval keeps the deduction in the execution-date cycle', () {
    final explanation = DeductionExplanation(
      sourceKey: 'attendance:user-1_2026-07-22',
      effectiveDate: DateTime(2026, 7, 22),
      effectiveCycleKey: permissionAccountingCycle('2026-07-22'),
      sourceLabelAr: 'الحضور والانصراف',
      reasonAr: 'تأخير حضور',
      fraction: 0.25,
      status: DeductionReviewStatus.approved,
      reviewedAt: DateTime(2026, 8, 2),
    );

    expect(explanation.effectiveCycleKey, '2026-07');
    expect(explanation.canRequestCorrection, isTrue);
  });

  test('cancelled deductions cannot create correction shortcuts', () {
    final explanation = DeductionExplanation(
      sourceKey: 'attendance:user-1_2026-07-22',
      effectiveDate: DateTime(2026, 7, 22),
      effectiveCycleKey: '2026-07',
      sourceLabelAr: 'الحضور والانصراف',
      reasonAr: 'تأخير حضور',
      fraction: 0.25,
      status: DeductionReviewStatus.cancelled,
    );
    expect(explanation.canRequestCorrection, isFalse);
  });
}
