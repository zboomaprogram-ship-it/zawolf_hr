final class SpreadsheetRange {
  const SpreadsheetRange({
    required this.tabName,
    required this.startRow,
    required this.endRow,
    required this.startColumn,
    required this.endColumn,
  });

  final String tabName;
  final int startRow;
  final int endRow;
  final int startColumn;
  final int endColumn;

  bool get isValid =>
      tabName.trim().isNotEmpty &&
      tabName.length <= 100 &&
      startRow >= 1 &&
      endRow >= startRow &&
      startColumn >= 1 &&
      endColumn >= startColumn &&
      endRow <= 100000 &&
      endColumn <= 702;

  int get cellCount => (endRow - startRow + 1) * (endColumn - startColumn + 1);
}

final class SpreadsheetVersion {
  const SpreadsheetVersion(this.value);
  final String value;
  bool get isValid => value.isNotEmpty && value.length <= 160;
}

enum SpreadsheetCompatibility {
  fullyEditable,
  protectedReadOnly,
  unsupportedReadOnly,
}

final class SpreadsheetCapabilityPolicy {
  const SpreadsheetCapabilityPolicy();

  bool mayMutate(SpreadsheetCompatibility compatibility) =>
      compatibility == SpreadsheetCompatibility.fullyEditable;
}

final class SpreadsheetCell {
  const SpreadsheetCell({
    required this.row,
    required this.column,
    required this.value,
    this.formattedValue,
    this.note,
    this.hyperlink,
    this.backgroundColor,
    this.textColor,
    this.bold = false,
    this.italic = false,
    this.validationType,
    this.validationValues = const <String>[],
  });

  final int row;
  final int column;
  final String value;
  final String? formattedValue;
  final String? note;
  final String? hyperlink;
  final String? backgroundColor;
  final String? textColor;
  final bool bold;
  final bool italic;
  final String? validationType;
  final List<String> validationValues;
}

final class SpreadsheetViewport {
  const SpreadsheetViewport({
    required this.startRow,
    required this.startColumn,
    required this.rowCount,
    required this.columnCount,
    required this.totalRows,
    required this.totalColumns,
  });

  final int startRow;
  final int startColumn;
  final int rowCount;
  final int columnCount;
  final int totalRows;
  final int totalColumns;
}

final class SpreadsheetSnapshot {
  const SpreadsheetSnapshot({
    required this.tabName,
    required this.tabs,
    required this.headers,
    required this.cells,
    required this.viewport,
    required this.version,
    required this.compatibility,
    required this.canEdit,
    required this.canStructure,
    required this.canFormat,
  });

  final String tabName;
  final List<String> tabs;
  final List<String> headers;
  final List<SpreadsheetCell> cells;
  final SpreadsheetViewport viewport;
  final SpreadsheetVersion version;
  final SpreadsheetCompatibility compatibility;
  final bool canEdit;
  final bool canStructure;
  final bool canFormat;
}
