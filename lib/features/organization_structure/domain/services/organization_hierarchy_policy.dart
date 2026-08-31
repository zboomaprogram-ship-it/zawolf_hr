import '../entities/organization_change_set.dart';
import '../entities/organization_membership.dart';
import '../entities/organization_unit.dart';

/// Pure validation rules shared by organization editors and fixture tests.
/// The server remains the authority for every committed mutation.
final class OrganizationHierarchyPolicy {
  const OrganizationHierarchyPolicy();

  String normalizeName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  OrganizationValidationIssue? validateName({
    required OrganizationUnit candidate,
    required Iterable<OrganizationUnit> units,
  }) {
    final normalized = normalizeName(candidate.name);
    final duplicate = units.any(
      (unit) =>
          unit.id != candidate.id &&
          !unit.archived &&
          unit.type == candidate.type &&
          unit.parentId == candidate.parentId &&
          normalizeName(unit.name) == normalized,
    );
    return duplicate
        ? const OrganizationValidationIssue(
            code: OrganizationValidationCode.duplicateName,
            message: 'يوجد اسم مطابق داخل نفس المستوى.',
          )
        : null;
  }

  OrganizationValidationIssue? validateContainment({
    required OrganizationUnit candidate,
    required Iterable<OrganizationUnit> units,
  }) {
    if (candidate.type == OrganizationUnitType.sector) {
      return candidate.parentId == null
          ? null
          : const OrganizationValidationIssue(
              code: OrganizationValidationCode.invalidContainment,
              message: 'لا يمكن وضع قطاع داخل وحدة أخرى.',
            );
    }
    if (candidate.parentId == candidate.id) {
      return const OrganizationValidationIssue(
        code: OrganizationValidationCode.hierarchyCycle,
        message: 'لا يمكن أن تحتوي الوحدة نفسها.',
      );
    }
    final parent = units
        .where((unit) => unit.id == candidate.parentId)
        .firstOrNull;
    if (parent == null ||
        parent.type != OrganizationUnitType.sector ||
        parent.archived) {
      return const OrganizationValidationIssue(
        code: OrganizationValidationCode.invalidContainment,
        message: 'يجب أن يتبع القسم قطاعًا نشطًا.',
      );
    }
    return null;
  }

  OrganizationValidationIssue? validateArchive({
    required OrganizationUnit candidate,
    required Iterable<OrganizationUnit> units,
    required Iterable<OrganizationMembership> memberships,
  }) {
    final hasChildren = units.any(
      (unit) => unit.parentId == candidate.id && !unit.archived,
    );
    final hasMembers = memberships.any(
      (membership) =>
          membership.active && membership.departmentUnitId == candidate.id,
    );
    if (hasChildren || hasMembers || !candidate.hasVacantManager) {
      return const OrganizationValidationIssue(
        code: OrganizationValidationCode.unitHasDependencies,
        message: 'انقل الأقسام والموظفين وألغِ تعيين المدير قبل الأرشفة.',
      );
    }
    return null;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
