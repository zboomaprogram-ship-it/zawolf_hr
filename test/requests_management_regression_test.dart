import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/employee_role.dart';

void main() {
  final screenSource = File(
    'lib/screens/manager/requests_mgmt.dart',
  ).readAsStringSync();
  final administrativeServiceSource = File(
    'lib/services/administrative_request_service.dart',
  ).readAsStringSync();
  final firestoreRules = File('firestore.rules').readAsStringSync();

  test('manager request search covers deduction and request fields', () {
    expect(
      screenSource,
      contains('List<AttendanceModel> _filterSalaryDeductions'),
    );
    expect(screenSource, contains("item.salaryDeductionLabel,"));
    expect(screenSource, contains("data['employeeId'],"));
    expect(screenSource, contains("data['department'],"));
  });

  test('approved deduction cancellation shows reason validation', () {
    expect(screenSource, contains('سبب الإلغاء يجب أن يكون 5 أحرف على الأقل.'));
    expect(
      screenSource,
      isNot(contains("if (reasonController.text.trim().length < 5) return;")),
    );
  });

  test('attendance correction accepts legacy deductions safely', () {
    expect(
      firestoreRules,
      contains("resource.data.get('originalCheckInTime', null) == null"),
    );
    expect(
      firestoreRules,
      contains('request.resource.data.salaryDeductionFraction <= 1'),
    );
    expect(
      firestoreRules,
      isNot(
        contains(
          'request.resource.data.salaryDeductionFraction in [0, 0.25, 0.5, 1]',
        ),
      ),
    );
    expect(screenSource, contains('EmployeeRole.isHr(reviewer.role)'));
    expect(
      screenSource,
      contains("'تعذر تعديل الوقت: \${userFacingError(error)}'"),
    );
  });

  test(
    'request loading has errors, timeout, and retry instead of endless wait',
    () {
      expect(screenSource, contains('snapshot.hasError'));
      expect(screenSource, contains('Duration(seconds: 15)'));
      expect(
        screenSource,
        contains('استغرق تحميل الطلبات وقتاً أطول من المتوقع.'),
      );
      expect(screenSource, contains('إعادة المحاولة'));
    },
  );

  test('super admin can perform HR-stage reviews but cannot self approve', () {
    expect(EmployeeRole.isHr(EmployeeRole.superAdmin), isTrue);
    expect(
      administrativeServiceSource,
      contains("status == 'pending_hr' && EmployeeRole.isHr(reviewer.role)"),
    );
    expect(
      firestoreRules,
      contains("resource.data.status == 'pending_hr'\n          && isHR()"),
    );
    expect(firestoreRules, contains('&& uid() != resource.data.userId'));
  });

  test(
    'HR monitors manager-stage requests and CEO receives final CEO stage',
    () {
      expect(
        screenSource,
        contains("whereIn: ['pending_manager', 'pending_ceo']"),
      );
      expect(screenSource, contains('final reviewerIsCeo'));
      expect(
        screenSource,
        contains("reviewer.employeeId.trim().toUpperCase() == 'CEO-100'"),
      );
      expect(
        screenSource,
        isNot(contains("collection == 'leaves' && employeeId == 'CEO-100'")),
      );
    },
  );

  test('latest HR salary deductions are not hidden by the bounded query', () {
    expect(screenSource, contains("isEqualTo: 'pending_hr'"));
    expect(screenSource, contains('reversal:\$reversalOnly'));
  });
}
