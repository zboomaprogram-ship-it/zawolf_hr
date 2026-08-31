import '../entities/spreadsheet_range.dart';
import '../repositories/workspace_sheet_repository.dart';

final class ReadWorkspaceSheetViewport {
  const ReadWorkspaceSheetViewport(this._repository);
  final WorkspaceSheetRepository _repository;

  Future<SpreadsheetSnapshot> call({
    required String resourceId,
    required SpreadsheetRange range,
  }) => _repository.readViewport(resourceId: resourceId, range: range);
}
