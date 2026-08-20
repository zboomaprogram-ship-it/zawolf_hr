import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/utils/permission_cycle_accounting.dart';

void main() {
  test('permission is accounted by execution date, not approval date', () {
    expect(permissionAccountingCycle('2026-07-22'), '2026-07');
    expect(
      permissionBelongsToActiveBalance(
        requestDate: '2026-07-22',
        activeCycleKey: '2026-08',
      ),
      isFalse,
    );
  });

  test('permission on opening day belongs to the new payroll cycle', () {
    expect(permissionAccountingCycle('2026-07-26'), '2026-08');
    expect(
      permissionBelongsToActiveBalance(
        requestDate: '2026-07-26',
        activeCycleKey: '2026-08',
      ),
      isTrue,
    );
  });

  test('late approval cannot move an early leave into a newer cycle', () {
    const executionDate = '2026-07-22';
    const laterApprovalCycle = '2026-08';

    expect(permissionAccountingCycle(executionDate), '2026-07');
    expect(
      permissionBelongsToActiveBalance(
        requestDate: executionDate,
        activeCycleKey: laterApprovalCycle,
      ),
      isFalse,
    );
  });

  test('invalid execution dates never affect an active balance', () {
    expect(permissionAccountingCycle(''), isEmpty);
    expect(
      permissionBelongsToActiveBalance(
        requestDate: 'not-a-date',
        activeCycleKey: '2026-08',
      ),
      isFalse,
    );
  });
}
