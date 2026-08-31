import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/spreadsheet_range.dart';
import '../../domain/entities/workspace_operation.dart';
import '../../domain/repositories/company_workspace_repository.dart';

sealed class WorkspaceSheetSyncState {
  const WorkspaceSheetSyncState();
}

final class WorkspaceSheetSyncIdle extends WorkspaceSheetSyncState {
  const WorkspaceSheetSyncIdle();
}

final class WorkspaceSheetSyncSaving extends WorkspaceSheetSyncState {
  const WorkspaceSheetSyncSaving();
}

final class WorkspaceSheetSyncSaved extends WorkspaceSheetSyncState {
  const WorkspaceSheetSyncSaved(this.message);
  final String message;
}

final class WorkspaceSheetSyncPending extends WorkspaceSheetSyncState {
  const WorkspaceSheetSyncPending(this.message);
  final String message;
}

final class WorkspaceSheetSyncConflict extends WorkspaceSheetSyncState {
  const WorkspaceSheetSyncConflict(
    this.message, {
    this.before = 'تم حفظ نسخة أحدث من الورقة على الخادم.',
    this.current = 'يمكنك تحديث الورقة ثم إعادة تطبيق تعديلك.',
  });
  final String message;
  final String before;
  final String current;
}

final class WorkspaceSheetSyncFailure extends WorkspaceSheetSyncState {
  const WorkspaceSheetSyncFailure(this.message);
  final String message;
}

final class WorkspaceSheetSyncCubit extends Cubit<WorkspaceSheetSyncState> {
  WorkspaceSheetSyncCubit({
    required CompanyWorkspaceRepository repository,
    required String actorId,
  }) : _repository = repository,
       _actorId = actorId,
       super(const WorkspaceSheetSyncIdle());

  final CompanyWorkspaceRepository _repository;
  final String _actorId;
  final Random _random = Random.secure();
  _PendingCellSave? _pendingCellSave;
  Timer? _pendingCellTimer;

  Future<void> saveCells({
    required String resourceId,
    required String tabName,
    required SpreadsheetRange viewport,
    required SpreadsheetVersion version,
    required List<SpreadsheetCell> cells,
  }) async {
    if (cells.isEmpty || cells.length > 500) return;
    final pending = _pendingCellSave;
    if (pending != null &&
        !pending.matches(
          resourceId: resourceId,
          tabName: tabName,
          viewport: viewport,
          version: version,
        )) {
      await _flushPendingCells();
    }

    final batch = _pendingCellSave ??= _PendingCellSave(
      resourceId: resourceId,
      tabName: tabName,
      viewport: viewport,
      version: version,
    );
    batch.replace(cells);
    _pendingCellTimer?.cancel();
    emit(
      const WorkspaceSheetSyncPending(
        'تم التعديل محلياً وسيُحفظ تلقائياً خلال لحظات.',
      ),
    );
    _pendingCellTimer = Timer(
      const Duration(milliseconds: 650),
      () => unawaited(_flushPendingCells()),
    );
  }

  Future<void> _flushPendingCells() async {
    _pendingCellTimer?.cancel();
    _pendingCellTimer = null;
    final batch = _pendingCellSave;
    _pendingCellSave = null;
    if (batch == null || batch.cells.isEmpty) return;
    await submitSheetOperation(
      resourceId: batch.resourceId,
      tabName: batch.tabName,
      viewport: batch.viewport,
      version: batch.version,
      kind: batch.cells.length == 1
          ? WorkspaceOperationKind.sheetEdit
          : WorkspaceOperationKind.sheetPaste,
      payload: <String, Object?>{
        'cells': batch.cells
            .map(
              (cell) => <String, Object?>{
                'row': cell.row,
                'column': cell.column,
                'value': cell.value,
              },
            )
            .toList(growable: false),
      },
    );
  }

  /// Sends a constrained spreadsheet operation through the same durable
  /// outbox as edits. Presentation supplies only provider-neutral values;
  /// the server remains the authority for capability and version checks.
  Future<void> submitSheetOperation({
    required String resourceId,
    required String tabName,
    required SpreadsheetRange viewport,
    required SpreadsheetVersion version,
    required WorkspaceOperationKind kind,
    required Map<String, Object?> payload,
  }) async {
    if (!const <WorkspaceOperationKind>{
      WorkspaceOperationKind.sheetEdit,
      WorkspaceOperationKind.sheetPaste,
      WorkspaceOperationKind.sheetFormat,
      WorkspaceOperationKind.sheetStructure,
      WorkspaceOperationKind.sheetTab,
    }.contains(kind)) {
      return;
    }
    emit(const WorkspaceSheetSyncSaving());
    final result = await _repository.submit(
      WorkspaceOperation(
        id: 'sheet_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32).toRadixString(36)}',
        actorId: _actorId,
        resourceId: resourceId,
        kind: kind,
        expectedVersion: version.value,
        createdAt: DateTime.now().toUtc(),
        payload: <String, Object?>{
          'tabName': tabName,
          'expectedVersion': version.value,
          'expectedStartRow': viewport.startRow,
          'expectedStartColumn': viewport.startColumn,
          'expectedRowCount': viewport.endRow - viewport.startRow + 1,
          'expectedColumnCount': viewport.endColumn - viewport.startColumn + 1,
          ...payload,
        },
      ),
    );
    switch (result.state) {
      case WorkspaceOperationState.acknowledged:
        emit(WorkspaceSheetSyncSaved(result.safeMessage ?? 'تم حفظ التعديل.'));
      case WorkspaceOperationState.pending:
        emit(
          const WorkspaceSheetSyncPending(
            'سيتم حفظ التعديل تلقائياً عند عودة الاتصال.',
          ),
        );
      case WorkspaceOperationState.conflict:
        emit(
          WorkspaceSheetSyncConflict(
            result.safeMessage ?? 'تم تعديل الجدول. حدّث الصفحة قبل الحفظ.',
          ),
        );
      case WorkspaceOperationState.rejected:
        emit(
          WorkspaceSheetSyncFailure(result.safeMessage ?? 'تعذر حفظ التعديل.'),
        );
    }
  }

  @override
  Future<void> close() async {
    _pendingCellTimer?.cancel();
    await _flushPendingCells();
    await super.close();
  }
}

/// Keeps rapid typing and paste changes as one provider request. Later values
/// for the same cell intentionally replace earlier keystrokes.
final class _PendingCellSave {
  _PendingCellSave({
    required this.resourceId,
    required this.tabName,
    required this.viewport,
    required this.version,
  });

  final String resourceId;
  final String tabName;
  final SpreadsheetRange viewport;
  final SpreadsheetVersion version;
  final Map<String, SpreadsheetCell> _cells = <String, SpreadsheetCell>{};

  List<SpreadsheetCell> get cells => _cells.values.toList(growable: false);

  bool matches({
    required String resourceId,
    required String tabName,
    required SpreadsheetRange viewport,
    required SpreadsheetVersion version,
  }) =>
      this.resourceId == resourceId &&
      this.tabName == tabName &&
      this.viewport.startRow == viewport.startRow &&
      this.viewport.endRow == viewport.endRow &&
      this.viewport.startColumn == viewport.startColumn &&
      this.viewport.endColumn == viewport.endColumn &&
      this.version.value == version.value;

  void replace(List<SpreadsheetCell> cells) {
    for (final cell in cells) {
      _cells['${cell.row}:${cell.column}'] = cell;
    }
  }
}
