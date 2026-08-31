import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_operation_receipt.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_change_set.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_membership.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_snapshot.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_unit.dart';
import 'package:zawolf_hr/features/organization_structure/domain/repositories/organization_structure_repository.dart';
import 'package:zawolf_hr/features/organization_structure/presentation/pages/organization_structure_editor_page.dart';

final class _LargeRepository implements OrganizationStructureRepository {
  @override
  Future<OrganizationSnapshot> loadHierarchy({
    bool includeArchived = false,
  }) async => OrganizationSnapshot(
    units: [
      const OrganizationUnit(
        id: 's',
        type: OrganizationUnitType.sector,
        name: 'قطاع الاختبار',
        order: 0,
        version: 1,
      ),
      for (var index = 0; index < 150; index++)
        OrganizationUnit(
          id: 'd$index',
          type: OrganizationUnitType.department,
          name: 'قسم $index',
          parentId: 's',
          order: index,
          version: 1,
        ),
    ],
    memberships: const [],
    version: 151,
    loadedAt: DateTime(2026),
  );
  @override
  Future<CompanyOsOperationReceipt> apply(OrganizationChangeSet change) =>
      throw UnimplementedError();
  @override
  Future<CompanyOsOperationReceipt?> operationStatus(
    String operationId,
  ) async => null;
  @override
  Future<OrganizationImpactPreview> preview(
    OrganizationChangeSet change,
  ) async => const OrganizationImpactPreview(
    affectedEmployees: 0,
    affectedDepartments: 0,
  );
  @override
  Future<List<OrganizationMembership>> searchEmployees(String query) async =>
      const [];
}

void main() {
  testWidgets('large hierarchy remains scrollable on mobile and desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: OrganizationStructureEditorPage(repository: _LargeRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('قطاع الاختبار'), findsOneWidget);
    expect(find.bySemanticsLabel('قطاع قطاع الاختبار'), findsOneWidget);
  });
}
