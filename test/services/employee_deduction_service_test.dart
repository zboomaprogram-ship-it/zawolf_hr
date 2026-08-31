import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/services/employee_deduction_service.dart';

void main() {
  group('EmployeeDeductionEntry', () {
    test(
      'builds a complete Arabic explanation from recorded deduction fields',
      () {
        const entry = EmployeeDeductionEntry(
          id: 'attendance-2026-08-20',
          date: '2026-08-20',
          sourceLabel: 'الحضور والانصراف',
          reasonLabel: 'تأخير حضور لمدة 35 دقيقة',
          dayFraction: 0.25,
          approvalStatus: 'approved',
          amount: 250,
          currency: 'EGP',
        );

        expect(entry.detailLines, contains('المصدر: الحضور والانصراف'));
        expect(entry.detailLines, contains('السبب: تأخير حضور لمدة 35 دقيقة'));
        expect(entry.detailLines, contains('تاريخ الاستحقاق: 2026-08-20'));
        expect(entry.detailLines, contains('الخصم: ربع يوم'));
        expect(entry.detailLines, contains('القيمة: 250.00 EGP'));
        expect(entry.detailLines, contains('حالة المراجعة: معتمد'));
        expect(entry.hasCompleteDetails, isTrue);
      },
    );

    test('uses an honest Arabic fallback for incomplete legacy details', () {
      const entry = EmployeeDeductionEntry(
        id: 'legacy-1',
        date: '',
        sourceLabel: 'سجل تاريخي',
        reasonLabel: '',
        dayFraction: 0.5,
        approvalStatus: 'pending_hr',
      );

      expect(entry.detailLines, contains('السبب: غير مسجل في السجل التاريخي'));
      expect(entry.detailLines, contains('تاريخ الاستحقاق: غير متاح'));
      expect(entry.detailLines, contains('القيمة: غير مسجلة'));
      expect(entry.hasCompleteDetails, isFalse);
    });
  });
}
