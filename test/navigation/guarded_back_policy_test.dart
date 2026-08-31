import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/navigation/guarded_back_navigation.dart';

void main() {
  test('pending attendance submission takes precedence over route history', () {
    expect(
      GuardedBackNavigation.decide(
        hasPreviousRoute: true,
        isHomeRoute: false,
        hasPendingAttendanceSync: true,
      ),
      GuardedBackDecision.confirmPendingAttendance,
    );
  });

  test('dirty forms require a discard confirmation before navigating', () {
    expect(
      GuardedBackNavigation.decide(
        hasPreviousRoute: true,
        isHomeRoute: false,
        hasUnsavedChanges: true,
      ),
      GuardedBackDecision.confirmDiscardChanges,
    );
  });

  test('clean nested and root routes have deterministic back outcomes', () {
    expect(
      GuardedBackNavigation.decide(hasPreviousRoute: true, isHomeRoute: false),
      GuardedBackDecision.navigatePrevious,
    );
    expect(
      GuardedBackNavigation.decide(hasPreviousRoute: false, isHomeRoute: false),
      GuardedBackDecision.navigateHome,
    );
    expect(
      GuardedBackNavigation.decide(hasPreviousRoute: false, isHomeRoute: true),
      GuardedBackDecision.stay,
    );
  });
}
