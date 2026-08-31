enum OrganizationValidationCode {
  duplicateName,
  invalidContainment,
  hierarchyCycle,
  inactiveManager,
  unitHasDependencies,
  conflict,
}

final class OrganizationValidationIssue {
  const OrganizationValidationIssue({
    required this.code,
    required this.message,
  });
  final OrganizationValidationCode code;
  final String message;
}

final class OrganizationImpactPreview {
  const OrganizationImpactPreview({
    required this.affectedEmployees,
    required this.affectedDepartments,
    this.warnings = const [],
  });
  final int affectedEmployees;
  final int affectedDepartments;
  final List<OrganizationValidationIssue> warnings;
}

final class OrganizationChangeSet {
  const OrganizationChangeSet({
    required this.operationId,
    required this.kind,
    required this.payload,
    this.expectedVersion,
  });
  final String operationId;
  final String kind;
  final Map<String, Object?> payload;
  final int? expectedVersion;
}
