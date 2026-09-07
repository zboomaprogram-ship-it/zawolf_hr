import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/leave_entitlement_policy.dart';

void main() {
  test('company annual leave quota is 15 days', () {
    expect(LeaveEntitlementPolicy.defaultAnnualQuota, 15);
  });

  test('employee remains on probation until six-month anniversary', () {
    final hiringDate = DateTime(2026, 1, 10);

    expect(
      LeaveEntitlementPolicy.isOnProbation(
        hiringDate,
        onDate: DateTime(2026, 7, 9),
      ),
      isTrue,
    );
    expect(
      LeaveEntitlementPolicy.isOnProbation(
        hiringDate,
        onDate: DateTime(2026, 7, 10),
      ),
      isFalse,
    );
  });

  test('month-end hiring dates produce a valid six-month anniversary', () {
    expect(
      LeaveEntitlementPolicy.eligibleFrom(DateTime(2026, 8, 31)),
      DateTime(2027, 2, 28),
    );
  });

  test(
    'annual quota follows first year, completed year, service and age tiers',
    () {
      expect(
        LeaveEntitlementPolicy.calculateAnnualQuota(
          hiringDate: DateTime(2026, 1, 1),
          asOfDate: DateTime(2026, 12, 31),
        ),
        15,
      );
      expect(
        LeaveEntitlementPolicy.calculateAnnualQuota(
          hiringDate: DateTime(2025, 1, 1),
          asOfDate: DateTime(2026, 1, 1),
        ),
        21,
      );
      expect(
        LeaveEntitlementPolicy.calculateAnnualQuota(
          hiringDate: DateTime(2016, 1, 1),
          asOfDate: DateTime(2026, 1, 1),
        ),
        30,
      );
      expect(
        LeaveEntitlementPolicy.calculateAnnualQuota(
          hiringDate: DateTime(2026, 1, 1),
          birthDate: DateTime(1976, 1, 1),
          asOfDate: DateTime(2026, 1, 1),
        ),
        30,
      );
    },
  );
}
