import 'package:intl/intl.dart';
import '../domain/hr_period_report.dart';

class EmployeeDeductionSummaryItem {
  final HrReportEmployee employee;
  final int scheduledDays;
  final int presentDays;
  final int lateDays;
  final int lateMinutes;
  final int absentDays;
  final int leaveDays;
  final double totalDeductionDays;
  final double approvedDeductionDays;
  final int deductionCount;
  final double lateDeductionDays;
  final double absentDeductionDays;
  final double otherDeductionDays;
  final double totalAmount;
  final List<HrDeductionRecord> deductions;

  const EmployeeDeductionSummaryItem({
    required this.employee,
    required this.scheduledDays,
    required this.presentDays,
    required this.lateDays,
    required this.lateMinutes,
    required this.absentDays,
    required this.leaveDays,
    required this.totalDeductionDays,
    required this.approvedDeductionDays,
    required this.deductionCount,
    required this.lateDeductionDays,
    required this.absentDeductionDays,
    required this.otherDeductionDays,
    required this.totalAmount,
    required this.deductions,
  });

  static EmployeeDeductionSummaryItem fromReport({
    required HrReportEmployee employee,
    required HrPeriodReport report,
  }) {
    final records = report.forEmployee(employee.id);
    final deductions = report.deductionsForEmployee(employee.id);

    final scheduled = records.where((r) => r.status != 'day_off').length;
    final present = records
        .where(
          (r) =>
              r.status == 'present' ||
              r.status == 'late' ||
              r.status == 'permission' ||
              r.status == 'field_mission',
        )
        .length;
    final late = records.where((r) => r.status == 'late').length;
    final lateMins = records.fold<int>(0, (sum, r) => sum + r.lateMinutes);
    final absent = records.where((r) => r.status == 'not_attended').length;
    final leave = records
        .where(
          (r) =>
              r.status == 'day_off' &&
              (r.statusDetail?.startsWith('إجازة') == true ||
                  r.statusDetail == 'عمل عن بعد'),
        )
        .length;

    final totalDedDays = deductions.fold<double>(
      0.0,
      (sum, d) => sum + d.fraction,
    );
    final approvedDedDays = deductions
        .where((d) => d.affectsDiscipline)
        .fold<double>(0.0, (sum, d) => sum + d.fraction);

    final lateDedDays = deductions
        .where(
          (d) =>
              d.reason.contains('تأخير') ||
              (d.detail != null && d.detail!.contains('تأخير')),
        )
        .fold<double>(0.0, (sum, d) => sum + d.fraction);

    final absentDedDays = deductions
        .where(
          (d) =>
              d.source.contains('غياب') ||
              d.reason.contains('غياب') ||
              d.fraction >= 1.0,
        )
        .fold<double>(0.0, (sum, d) => sum + d.fraction);

    final otherDedDays = (totalDedDays - lateDedDays - absentDedDays).clamp(
      0.0,
      double.infinity,
    );

    final totalAmt = deductions.fold<double>(
      0.0,
      (sum, d) => sum + d.resolvedAmount(),
    );

    return EmployeeDeductionSummaryItem(
      employee: employee,
      scheduledDays: scheduled,
      presentDays: present,
      lateDays: late,
      lateMinutes: lateMins,
      absentDays: absent,
      leaveDays: leave,
      totalDeductionDays: totalDedDays,
      approvedDeductionDays: approvedDedDays,
      deductionCount: deductions.length,
      lateDeductionDays: lateDedDays,
      absentDeductionDays: absentDedDays,
      otherDeductionDays: otherDedDays,
      totalAmount: totalAmt,
      deductions: deductions,
    );
  }
}

class HrReportPdfGenerator {
  static String generateHtml({
    required HrPeriodReport report,
    required HrReportPeriod period,
    required List<EmployeeDeductionSummaryItem> items,
  }) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final startDateStr = dateFormat.format(period.start);
    final endDateStr = dateFormat.format(period.end);
    final printTimeStr = DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(DateTime.now());

    final totalEmployees = items.length;
    final totalDeductionDays = items.fold<double>(0.0, (sum, e) => sum + e.totalDeductionDays);
    final totalLateDays = items.fold<int>(0, (sum, e) => sum + e.lateDays);
    final totalAbsentDays = items.fold<int>(0, (sum, e) => sum + e.absentDays);
    final totalDeductionCount = items.fold<int>(0, (sum, e) => sum + e.deductionCount);
    final totalEstAmount = items.fold<double>(0.0, (sum, e) => sum + e.totalAmount);

    final rowsBuffer = StringBuffer();
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final dedColor = item.totalDeductionDays > 0 ? '#b91c1c' : '#15803d';
      final dedBg = item.totalDeductionDays > 0 ? '#fef2f2' : '#f0fdf4';

      final breakdownText = [
        if (item.lateDeductionDays > 0) 'تأخير: ${item.lateDeductionDays.toStringAsFixed(2)} يوم',
        if (item.absentDeductionDays > 0) 'غياب: ${item.absentDeductionDays.toStringAsFixed(2)} يوم',
        if (item.otherDeductionDays > 0) 'أخرى: ${item.otherDeductionDays.toStringAsFixed(2)} يوم',
      ].join(' · ');

      rowsBuffer.write('''
      <tr>
        <td style="text-align: center;">${i + 1}</td>
        <td><strong>${item.employee.name}</strong><br><small style="color: #64748b;">${item.employee.code}</small></td>
        <td>${item.employee.department}</td>
        <td style="text-align: center;">${item.presentDays}</td>
        <td style="text-align: center;">${item.lateDays}${item.lateMinutes > 0 ? ' <small>(${item.lateMinutes}د)</small>' : ''}</td>
        <td style="text-align: center; color: ${item.absentDays > 0 ? '#b91c1c' : '#334155'}; font-weight: ${item.absentDays > 0 ? 'bold' : 'normal'};">${item.absentDays}</td>
        <td style="text-align: center; background-color: $dedBg; color: $dedColor; font-weight: bold;">
          ${item.totalDeductionDays.toStringAsFixed(2)} يوم
        </td>
        <td style="text-align: center;">${item.deductionCount}</td>
        <td style="font-size: 11px; color: #475569;">${breakdownText.isEmpty ? 'لا توجد خصومات' : breakdownText}</td>
        <td style="text-align: center;">${item.totalAmount > 0 ? '${item.totalAmount.toStringAsFixed(2)} ج.م' : '—'}</td>
      </tr>
      ''');
    }

    return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
  <meta charset="utf-8">
  <title>تقرير الموارد البشرية والخصومات للفترة</title>
  <style>
    @page {
      size: A4 landscape;
      margin: 12mm 10mm;
    }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      direction: rtl;
      background: #ffffff;
      color: #0f172a;
      margin: 0;
      padding: 10px;
      font-size: 12px;
      line-height: 1.4;
    }
    .header-bar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 2px solid #0284c7;
      padding-bottom: 12px;
      margin-bottom: 16px;
    }
    .company-title {
      font-size: 22px;
      font-weight: 800;
      color: #0369a1;
      margin: 0;
    }
    .report-title {
      font-size: 15px;
      font-weight: bold;
      color: #334155;
      margin: 4px 0 0 0;
    }
    .meta-info {
      text-align: left;
      font-size: 11px;
      color: #64748b;
    }
    .kpi-grid {
      display: grid;
      grid-template-columns: repeat(6, 1fr);
      gap: 10px;
      margin-bottom: 18px;
    }
    .kpi-card {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 8px 12px;
      text-align: center;
    }
    .kpi-val {
      font-size: 18px;
      font-weight: 800;
      color: #0f172a;
    }
    .kpi-lbl {
      font-size: 10px;
      color: #64748b;
      margin-top: 2px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 20px;
      font-size: 11.5px;
    }
    th {
      background: #0f172a;
      color: #ffffff;
      font-weight: 600;
      padding: 8px 6px;
      border: 1px solid #334155;
      text-align: center;
    }
    td {
      padding: 7px 6px;
      border: 1px solid #cbd5e1;
      vertical-align: middle;
    }
    tr:nth-child(even) {
      background-color: #f8fafc;
    }
    .footer-bar {
      margin-top: 20px;
      display: flex;
      justify-content: space-between;
      border-top: 1px solid #cbd5e1;
      padding-top: 8px;
      font-size: 10px;
      color: #64748b;
    }
    @media print {
      body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .no-print { display: none !important; }
      th { background-color: #0f172a !important; color: #ffffff !important; }
    }
  </style>
</head>
<body>

  <div class="header-bar">
    <div>
      <div class="company-title">زاوولف | ZaWolf HR & ERP System</div>
      <div class="report-title">تقرير الموارد البشرية وحصر الخصومات الشامل للفترة</div>
    </div>
    <div class="meta-info">
      <div><strong>الفترة:</strong> $startDateStr — $endDateStr (${period.days} يوماً)</div>
      <div><strong>تاريخ الاستخراج:</strong> $printTimeStr</div>
      <div><strong>نطاق التقرير:</strong> شامل جميع موظفي الشركة</div>
    </div>
  </div>

  <div class="kpi-grid">
    <div class="kpi-card">
      <div class="kpi-val">$totalEmployees</div>
      <div class="kpi-lbl">إجمالي الموظفين</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-val" style="color: #b91c1c;">${totalDeductionDays.toStringAsFixed(2)} يوم</div>
      <div class="kpi-lbl">إجمالي الخصومات</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-val">$totalDeductionCount</div>
      <div class="kpi-lbl">عدد إجراءات الخصم</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-val" style="color: #d97706;">$totalLateDays يوم</div>
      <div class="kpi-lbl">إجمالي أيام التأخير</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-val" style="color: #dc2626;">$totalAbsentDays يوم</div>
      <div class="kpi-lbl">إجمالي أيام الغياب</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-val" style="color: #0369a1;">${totalEstAmount > 0 ? '${totalEstAmount.toStringAsFixed(0)} ج.م' : '—'}</div>
      <div class="kpi-lbl">إجمالي القيمة المقدرة</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th style="width: 28px;">#</th>
        <th style="text-align: right; width: 140px;">الموظف والكود</th>
        <th style="text-align: right; width: 90px;">القسم</th>
        <th style="width: 50px;">الحضور</th>
        <th style="width: 65px;">التأخير</th>
        <th style="width: 50px;">الغياب</th>
        <th style="width: 80px;">إجمالي الخصم</th>
        <th style="width: 65px;">عدد الإجراءات</th>
        <th style="text-align: right;">تفصيل الخصومات والبنود</th>
        <th style="width: 80px;">القيمة المقدرة</th>
      </tr>
    </thead>
    <tbody>
      ${rowsBuffer.toString()}
    </tbody>
  </table>

  <div class="footer-bar">
    <div>تم استخراج هذا التقرير آلياً عبر نظام زاوولف لإدارة الموارد البشرية والمؤسسات.</div>
    <div>صفحة 1 من 1</div>
  </div>

</body>
</html>
    ''';
  }
}
