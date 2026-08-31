/// Pure policy for platform back gestures. Screens with a dirty form or a
/// pending attendance submission can ask for confirmation before navigation;
/// the shell itself uses the same rule to avoid leaving the app from a tab.
enum GuardedBackDecision {
  navigatePrevious,
  navigateHome,
  confirmDiscardChanges,
  confirmPendingAttendance,
  stay,
}

abstract final class GuardedBackNavigation {
  static GuardedBackDecision decide({
    required bool hasPreviousRoute,
    required bool isHomeRoute,
    bool hasUnsavedChanges = false,
    bool hasPendingAttendanceSync = false,
  }) {
    if (hasPendingAttendanceSync) {
      return GuardedBackDecision.confirmPendingAttendance;
    }
    if (hasUnsavedChanges) {
      return GuardedBackDecision.confirmDiscardChanges;
    }
    if (hasPreviousRoute) return GuardedBackDecision.navigatePrevious;
    if (!isHomeRoute) return GuardedBackDecision.navigateHome;
    return GuardedBackDecision.stay;
  }
}
