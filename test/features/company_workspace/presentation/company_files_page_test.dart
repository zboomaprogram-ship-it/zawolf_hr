import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_capability.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_access_grant.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_operation.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_resource.dart';
import 'package:zawolf_hr/features/company_workspace/domain/repositories/company_workspace_repository.dart';
import 'package:zawolf_hr/features/company_workspace/domain/repositories/workspace_resource_repository.dart';
import 'package:zawolf_hr/features/company_workspace/domain/use_cases/list_accessible_resources.dart';
import 'package:zawolf_hr/features/company_workspace/presentation/cubit/workspace_browser_cubit.dart';
import 'package:zawolf_hr/features/company_workspace/presentation/cubit/workspace_operations_cubit.dart';
import 'package:zawolf_hr/features/company_workspace/presentation/pages/company_files_page.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    WorkspaceResourceRepository repository,
  ) async {
    final cubit = WorkspaceBrowserCubit(ListAccessibleResources(repository));
    final operations = WorkspaceOperationsCubit(
      repository: const _OperationRepository(),
      actorId: 'tester',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: operations),
          ],
          child: const CompanyFilesPage(),
        ),
      ),
    );
    await cubit.load();
    await tester.pumpAndSettle();
    addTearDown(cubit.close);
    addTearDown(operations.close);
  }

  testWidgets('shows allowed resources in RTL', (tester) async {
    await pumpPage(
      tester,
      _Repository(
        const WorkspaceResourcePage(
          resources: [
            WorkspaceResource(
              id: 'folder-1',
              name: 'ملفات التسويق',
              type: WorkspaceResourceType.folder,
              parentId: null,
              version: 'v1',
              capabilities: {WorkspaceCapability.edit},
            ),
          ],
        ),
      ),
    );

    expect(find.text('ملفات التسويق'), findsOneWidget);
    expect(
      tester
          .widgetList<Directionality>(find.byType(Directionality))
          .map((widget) => widget.textDirection),
      contains(TextDirection.rtl),
    );
  });

  testWidgets('shows loading before the first resource response', (
    tester,
  ) async {
    final cubit = WorkspaceBrowserCubit(
      ListAccessibleResources(
        _Repository(const WorkspaceResourcePage(resources: [])),
      ),
    );
    final operations = WorkspaceOperationsCubit(
      repository: const _OperationRepository(),
      actorId: 'tester',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: operations),
          ],
          child: const CompanyFilesPage(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await cubit.close();
    await operations.close();
  });

  testWidgets('shows an Arabic empty state', (tester) async {
    await pumpPage(
      tester,
      _Repository(const WorkspaceResourcePage(resources: [])),
    );

    expect(find.text('لا توجد ملفات مسندة إليك حالياً.'), findsOneWidget);
  });

  testWidgets('shows a clear denial state', (tester) async {
    await pumpPage(tester, _DeniedRepository());

    expect(find.text('لا توجد ملفات متاحة لك حالياً.'), findsOneWidget);
  });

  testWidgets('opens a spreadsheet through the composition callback', (
    tester,
  ) async {
    WorkspaceResource? opened;
    final cubit = WorkspaceBrowserCubit(
      ListAccessibleResources(
        _Repository(
          const WorkspaceResourcePage(
            resources: [
              WorkspaceResource(
                id: 'sheet-1',
                name: 'متابعة الفريق',
                type: WorkspaceResourceType.spreadsheet,
                parentId: null,
                version: 'v1',
                capabilities: {WorkspaceCapability.edit},
              ),
            ],
          ),
        ),
      ),
    );
    final operations = WorkspaceOperationsCubit(
      repository: const _OperationRepository(),
      actorId: 'tester',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: operations),
          ],
          child: CompanyFilesPage(
            onOpenSpreadsheet: (resource) => opened = resource,
          ),
        ),
      ),
    );
    await cubit.load();
    await tester.pumpAndSettle();

    await tester.tap(find.text('متابعة الفريق'));
    expect(opened?.id, 'sheet-1');
    await cubit.close();
    await operations.close();
  });

  testWidgets('shows a retry action after load failure', (tester) async {
    await pumpPage(tester, _FailingRepository());

    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.textContaining('تعذر تحميل'), findsOneWidget);
  });

  testWidgets('shows only safe management actions for an editable resource', (
    tester,
  ) async {
    await pumpPage(
      tester,
      _Repository(
        const WorkspaceResourcePage(
          resources: [
            WorkspaceResource(
              id: 'file-1',
              name: 'ملف الفريق',
              type: WorkspaceResourceType.file,
              parentId: null,
              version: 'v1',
              capabilities: {WorkspaceCapability.edit},
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byTooltip('إجراءات الملف'));
    await tester.pumpAndSettle();

    expect(find.text('إعادة تسمية'), findsOneWidget);
    expect(find.text('نقل إلى سلة المحذوفات'), findsOneWidget);
    expect(find.textContaining('Google'), findsNothing);
  });

  testWidgets('offers a secure download only when the grant permits it', (
    tester,
  ) async {
    await pumpPage(
      tester,
      _Repository(
        const WorkspaceResourcePage(
          resources: [
            WorkspaceResource(
              id: 'file-download',
              name: 'كشف الحضور.pdf',
              type: WorkspaceResourceType.file,
              parentId: null,
              version: 'v1',
              capabilities: {WorkspaceCapability.download},
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byTooltip('إجراءات الملف'));
    await tester.pumpAndSettle();

    expect(find.text('تنزيل آمن'), findsOneWidget);
    expect(find.text('إعادة تسمية'), findsNothing);
  });
}

final class _OperationRepository implements CompanyWorkspaceRepository {
  const _OperationRepository();

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

final class _Repository implements WorkspaceResourceRepository {
  const _Repository(this.page);
  final WorkspaceResourcePage page;

  @override
  Future<WorkspaceResourcePage> listAccessible({
    required String? parentId,
    String? pageToken,
  }) async => page;

  @override
  Future<WorkspaceDownloadedFile> download(String resourceId) async =>
      const WorkspaceDownloadedFile(
        bytes: [1],
        fileName: 'test.txt',
        mimeType: 'text/plain',
      );
}

final class _FailingRepository implements WorkspaceResourceRepository {
  @override
  Future<WorkspaceResourcePage> listAccessible({
    required String? parentId,
    String? pageToken,
  }) => Future<WorkspaceResourcePage>.error(StateError('offline'));

  @override
  Future<WorkspaceDownloadedFile> download(String resourceId) =>
      Future<WorkspaceDownloadedFile>.error(StateError('offline'));
}

final class _DeniedRepository implements WorkspaceResourceRepository {
  @override
  Future<WorkspaceResourcePage> listAccessible({
    required String? parentId,
    String? pageToken,
  }) => Future<WorkspaceResourcePage>.error(
    const WorkspaceAccessDeniedException(),
  );

  @override
  Future<WorkspaceDownloadedFile> download(String resourceId) =>
      Future<WorkspaceDownloadedFile>.error(
        const WorkspaceAccessDeniedException(),
      );
}
