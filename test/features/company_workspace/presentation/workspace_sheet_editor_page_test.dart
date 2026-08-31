import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/spreadsheet_range.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_access_grant.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_capability.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_operation.dart';
import 'package:zawolf_hr/features/company_workspace/domain/repositories/company_workspace_repository.dart';
import 'package:zawolf_hr/features/company_workspace/domain/repositories/workspace_sheet_repository.dart';
import 'package:zawolf_hr/features/company_workspace/presentation/cubit/workspace_sheet_cubit.dart';
import 'package:zawolf_hr/features/company_workspace/presentation/cubit/workspace_sheet_sync_cubit.dart';
import 'package:zawolf_hr/features/company_workspace/presentation/pages/workspace_sheet_editor_page.dart';

void main() {
  testWidgets(
    'renders an RTL full-page grid, tabs, formula bar, and direct-cell editor',
    (tester) async {
      final cubit = WorkspaceSheetCubit(repository: _SheetRepository());
      final syncCubit = WorkspaceSheetSyncCubit(
        repository: _OperationsRepository(),
        actorId: 'actor-1',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: syncCubit),
            ],
            child: const WorkspaceSheetEditorPage(
              resourceId: 'resource',
              initialTab: 'Sheet1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('محرر الجداول'), findsOneWidget);
      expect(find.text('Sheet1'), findsOneWidget);
      expect(find.text('Sheet2'), findsOneWidget);
      expect(find.text('ندى'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(2));

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('ندى')),
      );
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 40));
      final secondGesture = await tester.startGesture(
        tester.getCenter(find.text('ندى')),
      );
      await secondGesture.up();
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(TextField), findsAtLeastNWidgets(2));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(find.text('بحث داخل الورقة'), findsOneWidget);
      await cubit.close();
      await syncCubit.close();
    },
  );
}

final class _OperationsRepository implements CompanyWorkspaceRepository {
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
      operation.acknowledge();
}

final class _SheetRepository implements WorkspaceSheetRepository {
  @override
  Future<SpreadsheetSnapshot> readViewport({
    required String resourceId,
    required SpreadsheetRange range,
  }) async => SpreadsheetSnapshot(
    tabName: range.tabName,
    tabs: const <String>['Sheet1', 'Sheet2'],
    headers: const <String>['الاسم', 'الحالة'],
    cells: const <SpreadsheetCell>[
      SpreadsheetCell(row: 2, column: 1, value: 'ندى'),
      SpreadsheetCell(row: 2, column: 2, value: 'جديد'),
    ],
    viewport: const SpreadsheetViewport(
      startRow: 2,
      startColumn: 1,
      rowCount: 50,
      columnCount: 20,
      totalRows: 1000,
      totalColumns: 26,
    ),
    version: const SpreadsheetVersion('version'),
    compatibility: SpreadsheetCompatibility.fullyEditable,
    canEdit: true,
    canStructure: true,
    canFormat: true,
  );
}
