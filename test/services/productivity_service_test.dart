import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/productivity_score_model.dart';

void main() {
  test(
    'an unavailable task or KPI input is not silently counted as zero work',
    () {
      final score = ProductivityScoreModel.calculateAvailableOverall(
        attendanceScore: 100,
        punctualityScore: 100,
        taskCompletionScore: null,
        taskQualityScore: null,
        kpiScore: null,
        hasKpiData: false,
      );

      // With KPI data unavailable, the documented fallback uses attendance and
      // behaviour only. It must not manufacture a failed task/KPI score.
      expect(score, 100);
    },
  );

  test(
    'productivity exposes complete, partial, and unavailable input states',
    () {
      ProductivityScoreModel fixture({
        required bool tasks,
        required bool quality,
        required bool kpi,
      }) => ProductivityScoreModel(
        scoreId: 'score',
        userId: 'employee',
        employeeId: 'EMP-1',
        employeeName: 'Employee',
        department: 'Operations',
        managerId: 'manager',
        monthKey: '2026-08',
        attendanceScore: 100,
        punctualityScore: 100,
        taskCompletionScore: 0,
        taskQualityScore: 0,
        kpiScore: 0,
        overallScore: 100,
        completedTasks: 0,
        totalTasks: 0,
        overdueTasks: 0,
        absentDays: 0,
        lateDays: 0,
        hasTaskData: tasks,
        hasTaskQualityData: quality,
        hasKpiData: kpi,
      );

      expect(
        fixture(tasks: true, quality: true, kpi: true).inputState,
        ProductivityInputState.complete,
      );
      expect(
        fixture(tasks: true, quality: false, kpi: true).inputState,
        ProductivityInputState.partial,
      );
      expect(
        fixture(tasks: false, quality: false, kpi: false).inputState,
        ProductivityInputState.unavailable,
      );
    },
  );

  test(
    'productivity reads a single employee and the selected payroll period',
    () {
      final source = File(
        'lib/services/productivity_service.dart',
      ).readAsStringSync();

      expect(source, contains(".where('assigneeId', isEqualTo: user.uid)"));
      expect(
        source,
        contains("'dueDate',\n            isGreaterThanOrEqualTo:"),
      );
      expect(
        source,
        contains(
          ".where('dueDate', isLessThan: Timestamp.fromDate(cycle.nextStart))",
        ),
      );
      expect(source, contains(".where('userId', isEqualTo: user.uid)"));
      expect(source, contains(".where('monthKey', isEqualTo: monthKey)"));
    },
  );

  test(
    'approved leave and permission are passed through the attendance period input',
    () {
      final source = File(
        'lib/services/attendance_period_summary_service.dart',
      ).readAsStringSync();

      expect(source, contains(".collection('leaves')"));
      expect(source, contains(".where('status', isEqualTo: 'approved')"));
      expect(source, contains(".collection('permissions')"));
      expect(source, contains('approvedPermissionDates'));
      expect(source, contains('!isApprovedPermission'));
    },
  );
}
