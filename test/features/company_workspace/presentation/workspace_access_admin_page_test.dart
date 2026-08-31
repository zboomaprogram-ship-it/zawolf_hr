import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_access_grant.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_source_import.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_pilot_configuration.dart';
import 'package:zawolf_hr/features/company_workspace/domain/repositories/workspace_access_administration_repository.dart';
import 'package:zawolf_hr/features/company_workspace/presentation/cubit/workspace_access_admin_cubit.dart';
import 'package:zawolf_hr/features/company_workspace/presentation/pages/workspace_access_admin_page.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, _Repository repository) async {
    final cubit = WorkspaceAccessAdminCubit(repository);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const WorkspaceAccessAdminPage(),
        ),
      ),
    );
    addTearDown(cubit.close);
  }

  testWidgets('creates, lists, and revokes a grant from the controller page', (
    tester,
  ) async {
    final repository = _Repository();
    await pumpPage(tester, repository);

    await tester.enterText(find.byType(TextField).at(0), 'resource-1');
    await tester.enterText(find.byType(TextField).at(1), 'employee-1');
    await tester.tap(find.text('منح الوصول'));
    await tester.pumpAndSettle();

    expect(repository.created?.resourceId, 'resource-1');
    expect(find.text('موظف محدد: employee-1'), findsOneWidget);
    expect(find.text('سماح · عرض · نشطة'), findsOneWidget);

    await tester.tap(find.byTooltip('سحب الوصول'));
    await tester.pumpAndSettle();
    expect(repository.revokedGrantId, 'grant-1');
    expect(find.text('سماح · عرض · مسحوبة'), findsOneWidget);
  });

  testWidgets('reports a protected-access failure safely in Arabic', (
    tester,
  ) async {
    await pumpPage(tester, _Repository(failList: true));

    await tester.enterText(find.byType(TextField).first, 'private-resource');
    await tester.tap(find.text('عرض الصلاحيات'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workspace-access-error')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workspace-access-error')),
      findsOneWidget,
    );
  });

  testWidgets('starts the controller-only source synchronization', (
    tester,
  ) async {
    final repository = _Repository();
    await pumpPage(tester, repository);

    await tester.tap(find.text('مزامنة Google Drive'));
    await tester.pumpAndSettle();

    expect(repository.imported, isTrue);
    expect(find.textContaining('تمت المزامنة: 7'), findsOneWidget);
  });

  testWidgets('prefills a department-scoped grant from an employee folder', (
    tester,
  ) async {
    await pumpPage(tester, _Repository());

    await tester.tap(find.byTooltip('تعيين مجلد موظف لقسم'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), 'folder-42');
    await tester.enterText(find.byType(TextField).at(3), 'department-hr');
    await tester.tap(find.text('استخدام في الصلاحيات'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      'folder-42',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      'department-hr',
    );
    expect(find.text('قسم'), findsOneWidget);
  });

  testWidgets('offers a controller an audited pilot rollback control', (
    tester,
  ) async {
    final repository = _Repository();
    await pumpPage(tester, repository);

    await tester.tap(find.byTooltip('تجربة V2 والتراجع'));
    await tester.pumpAndSettle();
    expect(find.text('تراجع فوري'), findsOneWidget);

    await tester.tap(find.text('تراجع فوري'));
    await tester.pumpAndSettle();
    expect(repository.savedPilot?.enabledForEveryone, isFalse);
    expect(repository.savedPilot?.enabledActorIds, isEmpty);
  });
}

final class _Repository implements WorkspaceAccessAdministrationRepository {
  _Repository({this.failList = false});

  final bool failList;
  WorkspaceAccessGrant? created;
  String? revokedGrantId;
  bool imported = false;
  WorkspacePilotConfiguration? savedPilot;

  @override
  Future<String> createGrant(WorkspaceAccessGrant grant) async {
    created = WorkspaceAccessGrant(
      id: 'grant-1',
      resourceId: grant.resourceId,
      scope: grant.scope,
      subjectId: grant.subjectId,
      capability: grant.capability,
      isActive: true,
      updatedAt: grant.updatedAt,
    );
    return 'grant-1';
  }

  @override
  Future<WorkspaceSourceImportResult> importCompanySource() async {
    imported = true;
    return const WorkspaceSourceImportResult(
      discovered: 7,
      created: 5,
      updated: 2,
      grants: 0,
    );
  }

  @override
  Future<List<WorkspaceAccessGrant>> listGrants(String resourceId) async {
    if (failList) throw StateError('protected');
    if (created == null) return const [];
    return [
      WorkspaceAccessGrant(
        id: created!.id,
        resourceId: created!.resourceId,
        scope: created!.scope,
        subjectId: created!.subjectId,
        capability: created!.capability,
        isActive: revokedGrantId != created!.id,
        updatedAt: created!.updatedAt,
      ),
    ];
  }

  @override
  Future<void> revokeGrant(String grantId) async => revokedGrantId = grantId;

  @override
  Future<WorkspacePilotConfiguration> loadPilotConfiguration() async =>
      const WorkspacePilotConfiguration(
        enabledForEveryone: false,
        enabledActorIds: ['pilot-user'],
      );

  @override
  Future<void> savePilotConfiguration(
    WorkspacePilotConfiguration configuration, {
    required String reason,
  }) async => savedPilot = configuration;
}
