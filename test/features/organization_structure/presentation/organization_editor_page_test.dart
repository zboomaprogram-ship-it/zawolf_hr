import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_operation_receipt.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_safe_error.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_sync_state.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_change_set.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_membership.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_snapshot.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_tree.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_tree_bootstrap.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_unit.dart';
import 'package:zawolf_hr/features/organization_structure/domain/repositories/multi_tree_organization_repository.dart';
import 'package:zawolf_hr/features/organization_structure/domain/repositories/organization_structure_repository.dart';
import 'package:zawolf_hr/features/organization_structure/presentation/pages/organization_structure_editor_page.dart';
import 'package:zawolf_hr/features/organization_structure/presentation/cubit/organization_editor_cubit.dart';

class _Repository implements OrganizationStructureRepository {
  _Repository({
    this.empty = false,
    this.fail = false,
    this.saveState = CompanyOsSyncState.synced,
    this.saveError,
  });
  final bool empty;
  final bool fail;
  final CompanyOsSyncState saveState;
  final CompanyOsSafeError? saveError;
  OrganizationChangeSet? lastChange;
  @override
  Future<OrganizationSnapshot> loadHierarchy({
    bool includeArchived = false,
  }) async {
    if (fail) throw StateError('offline');
    return OrganizationSnapshot(
      units: empty
          ? const []
          : const [
              OrganizationUnit(
                id: 's1',
                type: OrganizationUnitType.sector,
                name: 'الإدارة',
                order: 0,
                version: 1,
              ),
              OrganizationUnit(
                id: 'd1',
                type: OrganizationUnitType.department,
                name: 'الموارد البشرية',
                parentId: 's1',
                order: 0,
                version: 1,
              ),
            ],
      memberships: const [],
      version: 1,
      loadedAt: DateTime(2026),
    );
  }

  @override
  Future<CompanyOsOperationReceipt> apply(OrganizationChangeSet change) async {
    lastChange = change;
    if (saveError != null) throw saveError!;
    return CompanyOsOperationReceipt(
      operationId: change.operationId,
      status: saveState,
    );
  }

  @override
  Future<CompanyOsOperationReceipt?> operationStatus(
    String operationId,
  ) async => null;
  @override
  Future<OrganizationImpactPreview> preview(
    OrganizationChangeSet change,
  ) async => const OrganizationImpactPreview(
    affectedEmployees: 1,
    affectedDepartments: 1,
  );
  @override
  Future<List<OrganizationMembership>> searchEmployees(String query) async =>
      const [];
}

final class _MultiTreeMembershipRepository extends _MultiTreeRepository {
  @override
  Future<OrganizationSnapshot> loadTreeSnapshot(String treeId) async {
    lastTreeId = treeId;
    return OrganizationSnapshot(
      units: [
        OrganizationUnit(
          id: 'sector-$treeId',
          treeId: treeId,
          type: OrganizationUnitType.sector,
          name: 'القطاع',
          order: 0,
          version: 1,
        ),
        OrganizationUnit(
          id: 'department-$treeId',
          treeId: treeId,
          type: OrganizationUnitType.department,
          name: 'القسم',
          parentId: 'sector-$treeId',
          order: 0,
          version: 1,
        ),
      ],
      memberships: [
        OrganizationMembership(
          id: 'membership-secondary',
          treeId: treeId,
          employeeUid: 'employee-2',
          employeeName: 'موظف ثانوي',
          employeeCode: 'EMP-2',
          departmentUnitId: 'department-$treeId',
          version: 3,
          isPrimary: false,
        ),
        OrganizationMembership(
          id: 'membership-primary',
          treeId: treeId,
          employeeUid: 'employee-1',
          employeeName: 'موظف أساسي',
          employeeCode: 'EMP-1',
          departmentUnitId: 'department-$treeId',
          version: 2,
          isPrimary: true,
        ),
      ],
      selectedTreeId: treeId,
      version: 1,
      loadedAt: DateTime(2026),
    );
  }
}

class _MultiTreeRepository extends _Repository
    implements MultiTreeOrganizationRepository {
  String? lastTreeId;

  @override
  Future<List<OrganizationTree>> loadTrees({
    bool includeArchived = false,
  }) async => const [
    OrganizationTree(
      id: 'tree-main',
      name: 'الشركة الأساسية',
      status: OrganizationTreeStatus.active,
      version: 1,
      isDefault: true,
    ),
    OrganizationTree(
      id: 'tree-secondary',
      name: 'شركة ثانوية',
      status: OrganizationTreeStatus.active,
      version: 1,
    ),
  ];

  @override
  Future<OrganizationSnapshot> loadTreeSnapshot(String treeId) async {
    lastTreeId = treeId;
    return OrganizationSnapshot(
      units: [
        OrganizationUnit(
          id: 'sector-$treeId',
          treeId: treeId,
          type: OrganizationUnitType.sector,
          name: treeId == 'tree-main' ? 'القطاع الرئيسي' : 'القطاع الثانوي',
          order: 0,
          version: 1,
        ),
      ],
      memberships: const [],
      selectedTreeId: treeId,
      version: 1,
      loadedAt: DateTime(2026),
    );
  }

  @override
  Future<OrganizationTreeBootstrapPreview> previewLegacyBootstrap() async =>
      const OrganizationTreeBootstrapPreview(
        fingerprint: 'bootstrap-fingerprint',
        trees: 0,
        units: 1,
        memberships: 1,
        users: 1,
        legacyUnits: 0,
        legacyIssues: 0,
      );

  @override
  Future<void> applyLegacyBootstrap({
    required String operationId,
    required String approvedFingerprint,
  }) async {}
}

final class _EmptyMultiTreeRepository extends _MultiTreeRepository {
  @override
  Future<List<OrganizationTree>> loadTrees({
    bool includeArchived = false,
  }) async => const [];

  @override
  Future<OrganizationSnapshot> loadHierarchy({
    bool includeArchived = false,
  }) async => OrganizationSnapshot(
    units: const [],
    memberships: const [],
    version: 0,
    loadedAt: DateTime(2026),
  );
}

void main() {
  testWidgets('renders Arabic RTL full hierarchy and search', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrganizationStructureEditorPage(
          repository: _Repository(),
          canManage: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('إدارة الهيكل الوظيفي'), findsOneWidget);
    expect(find.text('الإدارة'), findsOneWidget);
    expect(find.text('الموارد البشرية'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(Scaffold).first)),
      TextDirection.rtl,
    );
    await tester.enterText(
      find.byKey(const Key('organization-search')),
      'غير موجود',
    );
    await tester.pump();
    expect(find.text('لا توجد نتائج مطابقة.'), findsOneWidget);
  });

  testWidgets('renders empty and retry states safely', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrganizationStructureEditorPage(
          repository: _Repository(empty: true),
          canManage: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ابدأ بإضافة أول قطاع.'), findsOneWidget);
    expect(
      find.byKey(const Key('organization-empty-add-sector')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('organization-empty-add-sector')));
    await tester.pumpAndSettle();
    expect(find.text('إضافة قطاع'), findsOneWidget);
    expect(find.text('اسم القطاع'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        home: OrganizationStructureEditorPage(
          key: const ValueKey('failing-editor'),
          repository: _Repository(fail: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذر تحميل'), findsOneWidget);
  });

  test(
    'editor reports pending sync, conflict, and denial without raw errors',
    () async {
      const change = OrganizationChangeSet(
        operationId: 'operation-1234',
        kind: 'rename_unit',
        payload: {'unitId': 'd1', 'name': 'قسم جديد'},
      );
      final pending = OrganizationEditorCubit(
        _Repository(saveState: CompanyOsSyncState.pending),
      );
      addTearDown(pending.close);
      await pending.apply(change);
      expect(pending.state.status, OrganizationSaveStatus.pendingSync);
      expect(pending.state.message, 'تم حفظ التغيير للمزامنة.');

      final conflict = OrganizationEditorCubit(
        _Repository(
          saveError: const CompanyOsSafeError(
            code: CompanyOsSafeCode.conflict,
            arabicMessage: 'تغيرت البيانات. حدّث الصفحة ثم أعد المحاولة.',
          ),
        ),
      );
      addTearDown(conflict.close);
      await conflict.apply(change);
      expect(conflict.state.status, OrganizationSaveStatus.conflict);

      final denied = OrganizationEditorCubit(
        _Repository(
          saveError: const CompanyOsSafeError(
            code: CompanyOsSafeCode.accessDenied,
            arabicMessage: 'لا تتوفر لك صلاحية تنفيذ هذا الإجراء.',
          ),
        ),
      );
      addTearDown(denied.close);
      await denied.apply(change);
      expect(denied.state.status, OrganizationSaveStatus.denied);
      expect(denied.state.message, isNot(contains('Firebase')));
    },
  );

  testWidgets('management actions are absent for read-only users', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrganizationStructureEditorPage(repository: _Repository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('إضافة وحدة'), findsNothing);
    expect(find.text('إضافة قسم'), findsNothing);
    await tester.tap(find.text('إدارة الوحدات'));
    await tester.pumpAndSettle();
    expect(find.text('لا يوجد مدير حاليًا'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('multi-tree selector loads an independent hierarchy', (
    tester,
  ) async {
    final repository = _MultiTreeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: OrganizationStructureEditorPage(
          repository: repository,
          canManage: true,
          multiTreeEnabled: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.lastTreeId, 'tree-main');
    expect(find.text('القطاع الرئيسي'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شركة ثانوية').last);
    await tester.pumpAndSettle();

    expect(repository.lastTreeId, 'tree-secondary');
    expect(find.text('القطاع الثانوي'), findsOneWidget);
  });

  testWidgets('empty multi-tree workspace still exposes tree creation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrganizationStructureEditorPage(
          repository: _EmptyMultiTreeRepository(),
          canManage: true,
          multiTreeEnabled: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('شجرة فارغة'), findsOneWidget);
    expect(find.text('ابدأ بإضافة أول قطاع.'), findsOneWidget);
  });

  testWidgets(
    'multi-tree memberships show primary status and support removal',
    (tester) async {
      final repository = _MultiTreeMembershipRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: OrganizationStructureEditorPage(
            repository: repository,
            canManage: true,
            multiTreeEnabled: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-list-view-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('العضوية الأساسية'), findsOneWidget);
      expect(find.textContaining('عضوية إضافية'), findsOneWidget);

      expect(find.byTooltip('إدارة العضوية الأساسية'), findsOneWidget);
      final membershipMenus = find.byTooltip('إدارة العضوية الإضافية');
      expect(membershipMenus, findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -280));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('إدارة العضوية الإضافية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إزالة من هذه الشجرة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد الإزالة'));
      await tester.pumpAndSettle();
      expect(repository.lastChange?.kind, 'archive_tree_membership');
      expect(repository.lastChange?.expectedVersion, 3);
    },
  );
}
