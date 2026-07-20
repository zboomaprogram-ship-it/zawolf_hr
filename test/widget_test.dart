import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/attendance_model.dart';
import 'package:zawolf_hr/models/attendance_policy.dart';
import 'package:zawolf_hr/models/employee_role.dart';
import 'package:zawolf_hr/models/kpi_model.dart';
import 'package:zawolf_hr/models/leave_model.dart';
import 'package:zawolf_hr/models/payroll_run_model.dart';
import 'package:zawolf_hr/models/productivity_score_model.dart';
import 'package:zawolf_hr/models/task_model.dart';
import 'package:zawolf_hr/models/warning_reward_model.dart';
import 'package:zawolf_hr/models/user_model.dart';
import 'package:zawolf_hr/services/sheets_export_service.dart';

void main() {
  group('Employee work schedule', () {
    test('preserves custom workdays and shift times', () {
      final schedule = WorkSchedule.fromMap({
        'startTime': '10:00',
        'endTime': '18:00',
        'workDays': [1, 3, 6],
      });

      expect(schedule.startTime, '10:00');
      expect(schedule.endTime, '18:00');
      expect(schedule.workDays, [1, 3, 6]);
      expect(schedule.toMap()['workDays'], [1, 3, 6]);
    });
  });

  group('Employee roles', () {
    test('team leader is team-scoped but not a manager or HR approver', () {
      expect(EmployeeRole.isTeamLeader(EmployeeRole.teamLeader), isTrue);
      expect(EmployeeRole.hasTeamScope(EmployeeRole.teamLeader), isTrue);
      expect(EmployeeRole.isManager(EmployeeRole.teamLeader), isFalse);
      expect(EmployeeRole.isHr(EmployeeRole.teamLeader), isFalse);
      expect(EmployeeRole.arabicLabel(EmployeeRole.teamLeader), 'قائد فريق');
    });
  });

  group('SheetsExportService CSV export', () {
    test('escapes commas and quotes in attendance rows', () async {
      final service = SheetsExportService();
      final csv = await service.exportAttendanceToSheet('attendance', [
        AttendanceModel(
          attendanceId: 'att-1',
          userId: 'user-1',
          employeeId: 'ZW-1',
          employeeName: 'Sara, "Ops"',
          locationId: 'loc-1',
          locationName: 'HQ',
          managerId: 'manager-1',
          date: '2026-07-02',
          checkInTime: DateTime(2026, 7, 2, 9),
          checkInLocation: const GeoPoint(30.0, 31.0),
          isWithinGeofence: true,
          isLate: false,
          lateMinutes: 0,
          status: 'present',
        ),
      ]);

      expect(csv, contains('"Sara, ""Ops"""'));
      expect(csv, contains('حاضر'));
    });

    test('includes leave status translations', () async {
      final service = SheetsExportService();
      final csv = await service.exportLeavesToSheet('leaves', [
        LeaveModel(
          leaveId: 'leave-1',
          userId: 'user-1',
          employeeId: 'ZW-1',
          employeeName: 'Sara',
          department: 'Operations',
          locationId: 'loc-1',
          managerId: 'manager-1',
          leaveType: 'annual',
          startDate: DateTime(2026, 7, 2),
          endDate: DateTime(2026, 7, 3),
          numberOfDays: 2,
          workHandoverTo: 'زميل العمل',
          status: 'approved',
        ),
      ]);

      expect(csv, contains('إجازة سنوية'));
      expect(csv, contains('مقبول'));
    });
  });

  group('AttendancePolicy', () {
    test('applies Zawolf late salary deduction windows', () {
      AttendanceDeduction at(int hour, int minute) {
        return AttendancePolicy.evaluateLateArrival(
          arrivalTime: DateTime(2026, 7, 4, hour, minute),
        );
      }

      expect(at(9, 0).dayFraction, 0);
      expect(at(9, 15).dayFraction, 0);
      expect(at(9, 16).dayFraction, 0.25);
      expect(at(9, 30).dayFraction, 0.25);
      expect(at(9, 31).dayFraction, 0.5);
      expect(at(10, 0).dayFraction, 0.5);
      expect(at(10, 1).dayFraction, 1);
      expect(at(17, 0).dayFraction, 1);
    });

    test('supports company-configured late deduction windows', () {
      const config = AttendancePolicyConfig(
        graceMinutes: 20,
        quarterDayUntilMinutes: 35,
        halfDayUntilMinutes: 70,
      );

      AttendanceDeduction at(int hour, int minute) {
        return config.evaluateLateArrival(
          arrivalTime: DateTime(2026, 7, 4, hour, minute),
        );
      }

      expect(at(9, 20).dayFraction, 0);
      expect(at(9, 21).dayFraction, 0.25);
      expect(at(9, 35).dayFraction, 0.25);
      expect(at(9, 36).dayFraction, 0.5);
      expect(at(10, 10).dayFraction, 0.5);
      expect(at(10, 11).dayFraction, 1);
    });

    test('supports configurable attendance action time gates', () {
      const defaults = AttendancePolicyConfig();
      expect(defaults.checkInOpenTime, '07:00');
      expect(defaults.defaultEndTime, '17:00');
      expect(defaults.latestCheckoutTime, '23:00');

      final custom = AttendancePolicyConfig.fromMap({
        'checkInOpenTime': '06:30',
        'defaultEndTime': '16:45',
        'latestCheckoutTime': '22:30',
      });
      expect(custom.checkInOpenTime, '06:30');
      expect(custom.defaultEndTime, '16:45');
      expect(custom.latestCheckoutTime, '22:30');
    });

    test(
      'calculates deduction amount from monthly salary over 26 work days',
      () {
        expect(
          AttendancePolicy.calculateSalaryDeductionAmount(
            monthlySalary: 26000,
            dayFraction: 0.25,
          ),
          250,
        );
        expect(
          AttendancePolicy.calculateSalaryDeductionAmount(
            monthlySalary: 26000,
            dayFraction: 0.5,
          ),
          500,
        );
        expect(
          AttendancePolicy.calculateSalaryDeductionAmount(
            monthlySalary: 26000,
            dayFraction: 1,
          ),
          1000,
        );
      },
    );
  });

  group('TaskModel helpers', () {
    test('translates priorities and statuses for Arabic UI', () {
      expect(TaskPriority.arabicLabel(TaskPriority.urgent), 'عاجلة');
      expect(TaskPriority.arabicLabel(TaskPriority.low), 'منخفضة');
      expect(TaskStatus.arabicLabel(TaskStatus.newTask), 'جديدة');
      expect(TaskStatus.arabicLabel(TaskStatus.inProgress), 'قيد التنفيذ');
      expect(TaskStatus.arabicLabel(TaskStatus.done), 'مكتملة');
    });
  });

  group('KPI progress', () {
    test('supports higher, lower, and pass/fail directions', () {
      const higher = EmployeeKpiMetric(
        name: 'Sales',
        unit: 'deal',
        target: 10,
        actual: 8,
        weight: 1,
      );
      const lower = EmployeeKpiMetric(
        name: 'Errors',
        unit: 'error',
        target: 4,
        actual: 2,
        weight: 1,
        direction: KpiMetricDirection.lowerIsBetter,
      );
      const passed = EmployeeKpiMetric(
        name: 'Audit',
        unit: 'result',
        target: 1,
        actual: 1,
        weight: 1,
        direction: KpiMetricDirection.passFail,
      );

      expect(higher.completion, 80);
      expect(lower.completion, 150);
      expect(passed.completion, 100);
    });

    test('calculates weighted monthly KPI progress', () {
      final metrics = [
        const EmployeeKpiMetric(
          name: 'Calls',
          unit: 'call',
          target: 100,
          actual: 80,
          weight: 1,
        ),
        const EmployeeKpiMetric(
          name: 'Deals',
          unit: 'deal',
          target: 10,
          actual: 10,
          weight: 2,
        ),
      ];

      expect(
        EmployeeKpiModel.calculateProgress(metrics).toStringAsFixed(1),
        '93.3',
      );
    });

    test('caps KPI progress at 100 for overall score', () {
      final metrics = [
        const EmployeeKpiMetric(
          name: 'Revenue',
          unit: 'EGP',
          target: 1000,
          actual: 2000,
          weight: 1,
        ),
      ];

      expect(EmployeeKpiModel.calculateProgress(metrics), 100);
    });
  });

  group('Productivity score', () {
    test('does not invent scores when tasks or KPI are missing', () {
      final score = ProductivityScoreModel.calculateAvailableOverall(
        attendanceScore: 100,
        punctualityScore: 80,
      );

      expect(score, 92.5);
    });

    test('calculates weighted productivity score', () {
      final score = ProductivityScoreModel.calculateOverall(
        attendanceScore: 90,
        punctualityScore: 80,
        taskCompletionScore: 70,
        taskQualityScore: 100,
        kpiScore: 75,
      );

      expect(score, 82);
    });

    test('clamps productivity score to 100', () {
      final score = ProductivityScoreModel.calculateOverall(
        attendanceScore: 120,
        punctualityScore: 100,
        taskCompletionScore: 100,
        taskQualityScore: 100,
        kpiScore: 100,
      );

      expect(score, 100);
    });
  });

  group('Warnings and rewards helpers', () {
    test('translates record types and statuses', () {
      expect(WarningRewardType.arabicLabel(WarningRewardType.warning), 'إنذار');
      expect(WarningRewardType.arabicLabel(WarningRewardType.reward), 'مكافأة');
      expect(
        WarningRewardStatus.arabicLabel(WarningRewardStatus.suggested),
        'مقترح',
      );
      expect(
        WarningRewardStatus.arabicLabel(WarningRewardStatus.acknowledged),
        'تم الاطلاع',
      );
    });
  });

  group('Payroll helpers', () {
    test('calculates net salary from base deductions and rewards', () {
      final netSalary = PayrollRunModel.calculateNetSalary(
        baseSalary: 10000,
        deductions: 1500,
        bonus: 500,
        advances: 0,
      );

      expect(netSalary, 9000);
    });

    test('does not allow negative net salary', () {
      final netSalary = PayrollRunModel.calculateNetSalary(
        baseSalary: 1000,
        deductions: 2500,
        bonus: 0,
        advances: 0,
      );

      expect(netSalary, 0);
    });

    test('subtracts approved advances from net salary', () {
      final netSalary = PayrollRunModel.calculateNetSalary(
        baseSalary: 10000,
        deductions: 1000,
        bonus: 500,
        advances: 2000,
      );

      expect(netSalary, 7500);
    });
  });
}
