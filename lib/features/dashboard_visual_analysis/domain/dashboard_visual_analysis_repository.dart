import '../../../models/user_model.dart';
import 'dashboard_visual_analysis.dart';

abstract interface class DashboardVisualAnalysisRepository {
  Future<DashboardVisualAnalysis> loadManagement({required UserModel reviewer, required DashboardPeriod period});
}
