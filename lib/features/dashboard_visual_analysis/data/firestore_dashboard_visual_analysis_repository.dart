import '../../../models/task_model.dart';
import '../../../models/user_model.dart';
import '../../../services/dashboard_attendance_summary_service.dart';
import '../../../services/task_service.dart';
import '../domain/dashboard_visual_analysis.dart';
import '../domain/dashboard_visual_analysis_repository.dart';

class FirestoreDashboardVisualAnalysisRepository
    implements DashboardVisualAnalysisRepository {
  FirestoreDashboardVisualAnalysisRepository({
    DashboardAttendanceSummaryService? attendance,
    TaskService? tasks,
  }) : _attendance = attendance ?? DashboardAttendanceSummaryService(),
       _tasks = tasks ?? TaskService();

  final DashboardAttendanceSummaryService _attendance;
  final TaskService _tasks;

  @override
  Future<DashboardVisualAnalysis> loadManagement({
    required UserModel reviewer,
    required DashboardPeriod period,
  }) async {
    final results = await Future.wait([
      _attendance.loadDayDetails(reviewer, period.end),
      _attendance.loadDateRangeForReviewer(
        reviewer,
        start: period.start,
        end: period.end,
      ),
      _tasks.watchManagedTasks(reviewer).first,
    ]);
    final todayDetails = results[0] as DashboardAttendanceDayDetails;
    final trend = results[1] as List<DashboardAttendanceSummary>;
    final tasks = results[2] as List<EmployeeTaskModel>;
    final taskTotals = DashboardTaskTotals(
      newTasks: tasks.where((task) => task.status == TaskStatus.newTask).length,
      inProgress: tasks.where((task) => task.status == TaskStatus.inProgress).length,
      late: tasks.where((task) => task.status == TaskStatus.late).length,
      completed: tasks.where((task) => task.status == TaskStatus.done).length,
    );
    final departments = <String, List<DashboardAttendancePerson>>{};
    if (!todayDetails.summary.teamScoped) {
      for (final person in todayDetails.people) {
        final name = person.employee.department.trim().isEmpty
            ? 'بدون قسم'
            : person.employee.department.trim();
        departments.putIfAbsent(name, () => []).add(person);
      }
    }
    final comparisons = departments.entries.map((entry) {
      int count(String status) => entry.value.where((person) => person.status == status).length;
      return DashboardDepartmentAttendance(
        department: entry.key,
        summary: DashboardAttendanceSummary(
          totalEmployees: entry.value.length,
          present: count('present'),
          late: count('late'),
          permission: count('permission'),
          dayOff: count('day_off'),
          notAttended: count('not_attended'),
          fieldMission: count('field_mission'),
          date: period.end,
          teamScoped: false,
          isComplete: todayDetails.summary.isComplete,
        ),
      );
    }).toList()..sort((a, b) => b.summary.attended.compareTo(a.summary.attended));

    return DashboardVisualAnalysis(
      period: period,
      today: todayDetails.summary,
      trend: trend.reversed.toList(),
      tasks: taskTotals,
      departments: comparisons,
    );
  }
}
