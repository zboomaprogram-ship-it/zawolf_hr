import '../entities/spreadsheet_range.dart';

abstract interface class WorkspaceSheetRepository {
  Future<SpreadsheetSnapshot> readViewport({
    required String resourceId,
    required SpreadsheetRange range,
  });
}
