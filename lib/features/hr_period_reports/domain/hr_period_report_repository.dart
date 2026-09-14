import '../../../models/user_model.dart';
import 'hr_period_report.dart';

abstract interface class HrPeriodReportRepository {
  Future<HrPeriodReport> load({
    required UserModel reviewer,
    required HrReportPeriod period,
  });
  Future<String> export({required HrReportPeriod period, String? employeeId});
}
