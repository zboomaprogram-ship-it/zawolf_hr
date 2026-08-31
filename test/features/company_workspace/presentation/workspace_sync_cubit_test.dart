import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/spreadsheet_range.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_access_grant.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_capability.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_operation.dart';
import 'package:zawolf_hr/features/company_workspace/domain/repositories/company_workspace_repository.dart';
import 'package:zawolf_hr/features/company_workspace/presentation/cubit/workspace_sheet_sync_cubit.dart';

void main() {
  final viewport = SpreadsheetRange(
    tabName: 'Sheet1',
    startRow: 1,
    startColumn: 1,
    endRow: 10,
    endColumn: 10,
  );
  final version = SpreadsheetVersion('v1');

  test(
    'temporary failure remains Arabic pending, with no provider text',
    () async {
      final cubit = WorkspaceSheetSyncCubit(
        repository: _Repository((operation) => operation),
        actorId: 'employee-1',
      );
      await cubit.saveCells(
        resourceId: 'sheet-1',
        tabName: 'Sheet1',
        viewport: viewport,
        version: version,
        cells: const [SpreadsheetCell(row: 2, column: 2, value: 'x')],
      );
      expect(cubit.state, isA<WorkspaceSheetSyncPending>());
      expect(
        (cubit.state as WorkspaceSheetSyncPending).message,
        isNot(contains('Firebase')),
      );
      await cubit.close();
    },
  );

  test('conflict and denial remain clear Arabic outcomes', () async {
    final operation = _operation();
    final conflict = WorkspaceSheetSyncCubit(
      repository: _Repository(
        (_) => operation.conflict('تم تعديل الملف. حدّث الصفحة قبل الحفظ.'),
      ),
      actorId: 'employee-1',
    );
    await conflict.saveCells(
      resourceId: 'sheet-1',
      tabName: 'Sheet1',
      viewport: viewport,
      version: version,
      cells: const [SpreadsheetCell(row: 2, column: 2, value: 'x')],
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(conflict.state, isA<WorkspaceSheetSyncConflict>());
    await conflict.close();

    final denied = WorkspaceSheetSyncCubit(
      repository: _Repository(
        (_) => operation.reject('لا تملك صلاحية تعديل هذا الملف.'),
      ),
      actorId: 'employee-1',
    );
    await denied.saveCells(
      resourceId: 'sheet-1',
      tabName: 'Sheet1',
      viewport: viewport,
      version: version,
      cells: const [SpreadsheetCell(row: 2, column: 2, value: 'x')],
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(denied.state, isA<WorkspaceSheetSyncFailure>());
    await denied.close();
  });

  test('a replayed duplicate acknowledgement recovers as saved', () async {
    final operation = _operation();
    final cubit = WorkspaceSheetSyncCubit(
      repository: _Repository(
        (_) => operation.acknowledge(safeMessage: 'تم الحفظ.'),
      ),
      actorId: 'employee-1',
    );
    await cubit.saveCells(
      resourceId: 'sheet-1',
      tabName: 'Sheet1',
      viewport: viewport,
      version: version,
      cells: const [SpreadsheetCell(row: 2, column: 2, value: 'x')],
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(cubit.state, isA<WorkspaceSheetSyncSaved>());
    await cubit.close();
  });
}

WorkspaceOperation _operation() => WorkspaceOperation(
  id: 'operation-1',
  actorId: 'employee-1',
  resourceId: 'sheet-1',
  kind: WorkspaceOperationKind.sheetEdit,
  createdAt: DateTime.utc(2026, 8, 22),
);

final class _Repository implements CompanyWorkspaceRepository {
  _Repository(this._result);
  final WorkspaceOperation Function(WorkspaceOperation) _result;

  @override
  Future<bool> canAccess({
    required String resourceId,
    required WorkspaceCapability capability,
  }) async => true;
  @override
  Future<List<WorkspaceAccessGrant>> grantsFor(String resourceId) async =>
      const [];
  @override
  Future<WorkspaceOperation> submit(WorkspaceOperation operation) async =>
      _result(operation);
}
