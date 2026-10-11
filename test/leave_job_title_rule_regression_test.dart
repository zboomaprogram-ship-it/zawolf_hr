import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('employee leave fields permit the staffing job title snapshot', () {
    final rules = File('firestore.rules').readAsStringSync();
    final leaveSection = rules.substring(
      rules.indexOf('match /leaves/{leaveId}'),
      rules.indexOf('match /permissions/{permissionId}'),
    );
    expect(leaveSection, contains("'jobTitle'"));
  });

  test('casual leave rules provide safe balance fallbacks and allow empty work handover', () {
    final rules = File('firestore.rules').readAsStringSync();
    final leaveSection = rules.substring(
      rules.indexOf('match /leaves/{leaveId}'),
      rules.indexOf('match /permissions/{permissionId}'),
    );
    // Verifies workHandoverTo allows empty string
    expect(leaveSection, contains("request.resource.data.workHandoverTo.size() >= 0"));
    // Verifies fallback for daysOff checks annual / 15
    expect(leaveSection, contains(".get('daysOff', recipientDoc(request.resource.data.userId).get('leaveBalance', {}).get('annual', 15))"));

    // Verifies ownerCasualLeaveBalanceDeduction null-safety
    final deductionSection = rules.substring(
      rules.indexOf('function ownerCasualLeaveBalanceDeduction()'),
      rules.indexOf('function hrCanWriteUser()'),
    );
    expect(deductionSection, contains("prevDaysOff = resource.data.get('leaveBalance', {}).get('daysOff', resource.data.get('leaveBalance', {}).get('annual', 15))"));
    expect(deductionSection, contains("prevCasual = resource.data.get('leaveBalance', {}).get('casual', 7)"));
    expect(deductionSection, contains("nextDaysOff == prevDaysOff - deductedDays"));
    expect(deductionSection, contains("nextCasual == prevCasual - deductedDays"));
  });
}

