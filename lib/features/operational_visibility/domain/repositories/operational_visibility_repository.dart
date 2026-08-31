import '../entities/employee_timeline_entry.dart';
import '../entities/employee_timeline_query.dart';
import '../entities/operational_visibility_setting.dart';

abstract interface class OperationalVisibilityRepository {
  Stream<Set<String>> watchHiddenEmployeeIds();

  Future<OperationalVisibilitySetting> setHidden({
    required String employeeUserId,
    required bool hidden,
    required String reasonAr,
    required String operationId,
  });

  Future<EmployeeTimelinePage> loadTimeline(EmployeeTimelineQuery query);
}
