import '../entities/developer_tools_employee.dart';

/// Provides a bounded employee directory for an authorized grant screen.
abstract interface class DeveloperToolsDirectoryRepository {
  Future<List<DeveloperToolsEmployee>> loadActiveEmployees();
}
