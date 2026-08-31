import '../../domain/entities/spreadsheet_range.dart';
import '../../domain/repositories/workspace_sheet_repository.dart';
import '../datasources/workspace_sheet_remote_data_source.dart';

final class WorkspaceSheetRepositoryImpl implements WorkspaceSheetRepository {
  WorkspaceSheetRepositoryImpl({required WorkspaceSheetRemoteDataSource remote})
    : _remote = remote;

  final WorkspaceSheetRemoteDataSource _remote;

  @override
  Future<SpreadsheetSnapshot> readViewport({
    required String resourceId,
    required SpreadsheetRange range,
  }) {
    if (!range.isValid || range.cellCount > 10000) {
      throw ArgumentError.value(range, 'range', 'Invalid spreadsheet viewport');
    }
    return _remote.readViewport(resourceId: resourceId, range: range);
  }
}
