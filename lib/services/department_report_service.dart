import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/productivity_score_model.dart';
import '../models/user_model.dart';
import '../utils/csv_file_download.dart';
import '../utils/payroll_cycle.dart';
import 'employee_deduction_service.dart';
import 'request_log_service.dart';
import 'sheets_export_service.dart';

class DepartmentAnalyticsDetail {
  final ProductivityScoreModel score;
  final List<EmployeeDeductionEntry> deductions;
  final List<RequestLogItem> requests;
  final double totalDeductionDays;
  final double totalDeductionAmount;

  const DepartmentAnalyticsDetail({
    required this.score,
    this.deductions = const [],
    this.requests = const [],
    this.totalDeductionDays = 0.0,
    this.totalDeductionAmount = 0.0,
  });

  String get employeeId => score.employeeId;
  String get employeeName => score.employeeName;
  String get department => score.department;
  String get userId => score.userId;

  int get deductionCount => deductions.length;
  int get requestsCount => requests.length;
  int get leavesCount => requests.where((r) => r.type == 'leave').length;
  int get permissionsCount =>
      requests.where((r) => r.type == 'permission').length;
  int get otherRequestsCount =>
      requests.where((r) => r.type != 'leave' && r.type != 'permission').length;
  int get approvedRequestsCount =>
      requests.where((r) => r.status == 'approved').length;
  int get pendingRequestsCount =>
      requests.where((r) => r.isPending).length;

  int get absentDays => score.absentDays;
  int get lateDays => score.lateDays;
  int get completedTasks => score.completedTasks;
  int get totalTasks => score.totalTasks;
  int get overdueTasks => score.overdueTasks;
  double get overallScore => score.overallScore;
}

class DepartmentAnalyticsSummary {
  final String department;
  final int employeeCount;
  final double averageScore;
  final int totalAbsentDays;
  final int totalLateDays;
  final int totalDeductionCount;
  final double totalDeductionDays;
  final double totalDeductionAmount;
  final int totalRequestsCount;
  final int totalLeavesCount;
  final int totalPermissionsCount;
  final int totalCompletedTasks;
  final int totalOverdueTasks;
  final List<DepartmentAnalyticsDetail> employeeDetails;

  const DepartmentAnalyticsSummary({
    required this.department,
    required this.employeeCount,
    required this.averageScore,
    required this.totalAbsentDays,
    required this.totalLateDays,
    required this.totalDeductionCount,
    required this.totalDeductionDays,
    required this.totalDeductionAmount,
    required this.totalRequestsCount,
    required this.totalLeavesCount,
    required this.totalPermissionsCount,
    required this.totalCompletedTasks,
    required this.totalOverdueTasks,
    required this.employeeDetails,
  });

  factory DepartmentAnalyticsSummary.fromDetails({
    required String department,
    required List<DepartmentAnalyticsDetail> details,
  }) {
    if (details.isEmpty) {
      return DepartmentAnalyticsSummary(
        department: department,
        employeeCount: 0,
        averageScore: 0,
        totalAbsentDays: 0,
        totalLateDays: 0,
        totalDeductionCount: 0,
        totalDeductionDays: 0,
        totalDeductionAmount: 0,
        totalRequestsCount: 0,
        totalLeavesCount: 0,
        totalPermissionsCount: 0,
        totalCompletedTasks: 0,
        totalOverdueTasks: 0,
        employeeDetails: const [],
      );
    }

    final avg =
        details.fold<double>(0, (sum, d) => sum + d.score.overallScore) /
        details.length;
    final absent =
        details.fold<int>(0, (sum, d) => sum + d.score.absentDays);
    final late =
        details.fold<int>(0, (sum, d) => sum + d.score.lateDays);
    final dedCount =
        details.fold<int>(0, (sum, d) => sum + d.deductionCount);
    final dedDays =
        details.fold<double>(0, (sum, d) => sum + d.totalDeductionDays);
    final dedAmt =
        details.fold<double>(0, (sum, d) => sum + d.totalDeductionAmount);
    final reqCount =
        details.fold<int>(0, (sum, d) => sum + d.requestsCount);
    final leaves =
        details.fold<int>(0, (sum, d) => sum + d.leavesCount);
    final permissions =
        details.fold<int>(0, (sum, d) => sum + d.permissionsCount);
    final completed =
        details.fold<int>(0, (sum, d) => sum + d.score.completedTasks);
    final overdue =
        details.fold<int>(0, (sum, d) => sum + d.score.overdueTasks);

    return DepartmentAnalyticsSummary(
      department: department,
      employeeCount: details.length,
      averageScore: avg,
      totalAbsentDays: absent,
      totalLateDays: late,
      totalDeductionCount: dedCount,
      totalDeductionDays: dedDays,
      totalDeductionAmount: dedAmt,
      totalRequestsCount: reqCount,
      totalLeavesCount: leaves,
      totalPermissionsCount: permissions,
      totalCompletedTasks: completed,
      totalOverdueTasks: overdue,
      employeeDetails: details,
    );
  }
}

class DepartmentReportService {
  DepartmentReportService._();
  static final DepartmentReportService instance = DepartmentReportService._();

  final EmployeeDeductionService _deductionService = EmployeeDeductionService();
  final SheetsExportService _sheetsExportService = SheetsExportService();

  Future<Map<String, DepartmentAnalyticsDetail>> loadDepartmentDetails({
    required List<ProductivityScoreModel> scores,
    UserModel? reviewer,
    DateTime? startDate,
    DateTime? endDate,
    String? monthKey,
  }) async {
    final now = DateTime.now();
    final effectiveCycle = monthKey != null && monthKey.isNotEmpty
        ? PayrollCycle.forKey(monthKey)
        : PayrollCycle.forDate(now);

    final start = startDate ?? effectiveCycle.start;
    final end = endDate ?? now;

    final startKey = DateFormat('yyyy-MM-dd').format(start);
    final endKey = DateFormat('yyyy-MM-dd').format(end);

    // 1. Fetch requests for reviewer's scope if reviewer is available
    final requestsByEmployeeId = <String, List<RequestLogItem>>{};
    if (reviewer != null) {
      try {
        final logs = await RequestLogService.instance.getMonthlyLogs(
          reviewer,
          selectedCycle: effectiveCycle,
          allTime: false,
        );

        for (final item in logs) {
          final occurs = item.occursAt ?? item.submittedAt;
          if (occurs.isAfter(start.subtract(const Duration(days: 1))) &&
              occurs.isBefore(end.add(const Duration(days: 1)))) {
            requestsByEmployeeId
                .putIfAbsent(item.employeeId, () => [])
                .add(item);
          }
        }
      } catch (_) {}
    }

    // 2. Fetch deductions for each employee
    final deductionsByUserId = <String, List<EmployeeDeductionEntry>>{};
    final userIds = scores.map((s) => s.userId).toSet().toList();

    const chunkSize = 8;
    for (int i = 0; i < userIds.length; i += chunkSize) {
      final chunk = userIds.sublist(
        i,
        i + chunkSize > userIds.length ? userIds.length : i + chunkSize,
      );
      final futures = chunk.map((uid) {
        return _deductionService.getDeductionsForRange(
          userId: uid,
          startDateKey: startKey,
          endDateKey: endKey,
          monthKey: monthKey ?? effectiveCycle.key,
        );
      });
      final results = await Future.wait(futures);
      for (int j = 0; j < chunk.length; j++) {
        deductionsByUserId[chunk[j]] = results[j];
      }
    }

    // 3. Assemble details
    final detailsMap = <String, DepartmentAnalyticsDetail>{};
    for (final score in scores) {
      final deductions = deductionsByUserId[score.userId] ?? const [];
      final requests = requestsByEmployeeId[score.employeeId] ?? const [];

      final totalDays = deductions.fold<double>(
        0.0,
        (sum, d) => sum + d.dayFraction,
      );
      final totalAmount = deductions.fold<double>(
        0.0,
        (sum, d) => sum + (d.amount ?? 0.0),
      );

      detailsMap[score.userId] = DepartmentAnalyticsDetail(
        score: score,
        deductions: deductions,
        requests: requests,
        totalDeductionDays: totalDays,
        totalDeductionAmount: totalAmount,
      );
    }

    return detailsMap;
  }

  Future<bool> exportReport({
    required List<DepartmentAnalyticsDetail> details,
    required String periodLabel,
    required String exportFileName,
  }) async {
    final rows = details.map((d) {
      return DepartmentPerformanceExportRow(
        employeeId: d.employeeId,
        employeeName: d.employeeName,
        department: d.department,
        overallScore: d.score.overallScore,
        kpiScore: d.score.kpiScore,
        attendanceScore: d.score.attendanceComponentScore,
        behaviorScore: d.score.behaviorScore,
        absentDays: d.absentDays,
        lateDays: d.lateDays,
        deductionCount: d.deductionCount,
        deductionDays: d.totalDeductionDays,
        deductionAmount: d.totalDeductionAmount,
        requestsCount: d.requestsCount,
        leavesCount: d.leavesCount,
        permissionsCount: d.permissionsCount,
        otherRequestsCount: d.otherRequestsCount,
        completedTasks: d.completedTasks,
        totalTasks: d.totalTasks,
        overdueTasks: d.overdueTasks,
        period: periodLabel,
      );
    }).toList();

    final csv = await _sheetsExportService.exportDepartmentPerformanceReport(
      periodLabel: periodLabel,
      rows: rows,
    );

    try {
      if (await downloadCsvFile(csv, exportFileName)) {
        return true;
      }
      final file = XFile.fromData(
        Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]),
        mimeType: 'text/csv',
        name: '$exportFileName.csv',
      );
      await SharePlus.instance.share(
        ShareParams(files: [file], subject: exportFileName),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
