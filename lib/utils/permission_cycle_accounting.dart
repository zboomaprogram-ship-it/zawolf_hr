import 'payroll_cycle.dart';

/// The permission's execution day is the only source of truth for accounting.
/// Submission and approval timestamps must never move it to another cycle.
String permissionAccountingCycle(String requestDate) {
  final day = DateTime.tryParse(requestDate);
  if (day == null) return '';
  return PayrollCycle.keyFor(day);
}

bool permissionBelongsToActiveBalance({
  required String requestDate,
  required String activeCycleKey,
}) {
  final requestCycle = permissionAccountingCycle(requestDate);
  return requestCycle.isNotEmpty && requestCycle == activeCycleKey;
}

class PermissionCycleUsage {
  final int usedCount;
  final double usedHours;

  const PermissionCycleUsage({
    required this.usedCount,
    required this.usedHours,
  });

  static const zero = PermissionCycleUsage(usedCount: 0, usedHours: 0);
}
