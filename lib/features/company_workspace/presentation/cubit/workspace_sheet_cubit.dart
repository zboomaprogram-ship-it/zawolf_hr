import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/spreadsheet_range.dart';
import '../../domain/repositories/workspace_sheet_repository.dart';

sealed class WorkspaceSheetState {
  const WorkspaceSheetState();
}

final class WorkspaceSheetLoading extends WorkspaceSheetState {
  const WorkspaceSheetLoading();
}

final class WorkspaceSheetFailure extends WorkspaceSheetState {
  const WorkspaceSheetFailure(this.message);
  final String message;
}

final class WorkspaceSheetReady extends WorkspaceSheetState {
  const WorkspaceSheetReady({
    required this.resourceId,
    required this.snapshot,
    required this.range,
  });
  final String resourceId;
  final SpreadsheetSnapshot snapshot;
  final SpreadsheetRange range;
}

final class WorkspaceSheetCubit extends Cubit<WorkspaceSheetState> {
  WorkspaceSheetCubit({required WorkspaceSheetRepository repository})
    : _repository = repository,
      super(const WorkspaceSheetLoading());

  final WorkspaceSheetRepository _repository;
  final Map<String, WorkspaceSheetReady> _viewportCache =
      <String, WorkspaceSheetReady>{};
  Timer? _scheduledRefresh;

  String _cacheKey(String resourceId, SpreadsheetRange range) =>
      '$resourceId:${range.tabName}:${range.startRow}:${range.startColumn}:'
      '${range.endRow}:${range.endColumn}';

  Future<void> load({
    required String resourceId,
    required String tabName,
    int startRow = 2,
    int startColumn = 1,
    int rowCount = 50,
    int columnCount = 20,
    bool force = false,
  }) async {
    final range = SpreadsheetRange(
      tabName: tabName,
      startRow: startRow,
      endRow: startRow + rowCount - 1,
      startColumn: startColumn,
      endColumn: startColumn + columnCount - 1,
    );
    final cacheKey = _cacheKey(resourceId, range);
    final cached = _viewportCache[cacheKey];
    if (!force && cached != null) {
      emit(cached);
      return;
    }

    // A refresh should not replace an already usable sheet with a blank loader.
    // This keeps typing, selection and scrolling responsive while data syncs.
    if (state is! WorkspaceSheetReady) {
      emit(const WorkspaceSheetLoading());
    }
    try {
      final snapshot = await _repository.readViewport(
        resourceId: resourceId,
        range: range,
      );
      final ready = WorkspaceSheetReady(
          resourceId: resourceId,
          snapshot: snapshot,
          range: range,
        );
      _viewportCache[cacheKey] = ready;
      emit(ready);
    } on Exception {
      // Preserve the last visible viewport during a transient API outage.
      if (state is! WorkspaceSheetReady) {
        emit(
          const WorkspaceSheetFailure(
            'تعذر فتح الجدول الآن. أعد المحاولة بعد لحظات.',
          ),
        );
      }
    }
  }

  Future<void> reload() async {
    final current = state;
    if (current is! WorkspaceSheetReady) return;
    await load(
      resourceId: current.resourceId,
      tabName: current.snapshot.tabName,
      startRow: current.range.startRow,
      startColumn: current.range.startColumn,
      rowCount: current.range.endRow - current.range.startRow + 1,
      columnCount: current.range.endColumn - current.range.startColumn + 1,
      force: true,
    );
  }

  Future<void> openTab(String tabName) async {
    final current = state;
    if (current is! WorkspaceSheetReady) return;
    await load(
      resourceId: current.resourceId,
      tabName: tabName,
      startRow: current.range.startRow,
      startColumn: current.range.startColumn,
      rowCount: current.range.endRow - current.range.startRow + 1,
      columnCount: current.range.endColumn - current.range.startColumn + 1,
    );
  }

  /// Updates the grid immediately, then lets the sync cubit save remotely.
  /// The editor must never wait for a full Google read after every keystroke.
  void applyCells(List<SpreadsheetCell> changedCells) {
    final current = state;
    if (current is! WorkspaceSheetReady || changedCells.isEmpty) return;

    final byCoordinate = <String, SpreadsheetCell>{
      for (final cell in current.snapshot.cells) '${cell.row}:${cell.column}': cell,
    };
    for (final cell in changedCells) {
      final existing = byCoordinate['${cell.row}:${cell.column}'];
      byCoordinate['${cell.row}:${cell.column}'] = SpreadsheetCell(
        row: cell.row,
        column: cell.column,
        value: cell.value,
        formattedValue: cell.formattedValue ?? existing?.formattedValue,
        note: cell.note ?? existing?.note,
        hyperlink: cell.hyperlink ?? existing?.hyperlink,
        backgroundColor: cell.backgroundColor ?? existing?.backgroundColor,
        textColor: cell.textColor ?? existing?.textColor,
        bold: cell.bold || (existing?.bold ?? false),
        italic: cell.italic || (existing?.italic ?? false),
        validationType: cell.validationType ?? existing?.validationType,
        validationValues: cell.validationValues.isEmpty
            ? (existing?.validationValues ?? const <String>[])
            : cell.validationValues,
      );
    }
    final snapshot = SpreadsheetSnapshot(
      tabName: current.snapshot.tabName,
      tabs: current.snapshot.tabs,
      headers: current.snapshot.headers,
      cells: byCoordinate.values.toList()
        ..sort((left, right) => left.row == right.row
            ? left.column.compareTo(right.column)
            : left.row.compareTo(right.row)),
      viewport: current.snapshot.viewport,
      version: current.snapshot.version,
      compatibility: current.snapshot.compatibility,
      canEdit: current.snapshot.canEdit,
      canStructure: current.snapshot.canStructure,
      canFormat: current.snapshot.canFormat,
    );
    final ready = WorkspaceSheetReady(
      resourceId: current.resourceId,
      snapshot: snapshot,
      range: current.range,
    );
    _viewportCache[_cacheKey(current.resourceId, current.range)] = ready;
    emit(ready);
  }

  /// Coalesces several rapid saves into a single quiet refresh.
  void scheduleRefresh([Duration delay = const Duration(seconds: 2)]) {
    _scheduledRefresh?.cancel();
    _scheduledRefresh = Timer(delay, () => unawaited(reload()));
  }

  @override
  Future<void> close() {
    _scheduledRefresh?.cancel();
    return super.close();
  }
}
