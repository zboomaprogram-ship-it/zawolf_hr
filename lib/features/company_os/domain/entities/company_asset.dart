enum CompanyAssetStatus { available, assigned, maintenance, damaged, retired }

final class CompanyAsset {
  const CompanyAsset({
    required this.id,
    required this.assetCode,
    required this.name,
    required this.type,
    required this.status,
    required this.version,
    this.currentEmployeeUid,
    this.locationId,
  });

  final String id;
  final String assetCode;
  final String name;
  final String type;
  final CompanyAssetStatus status;
  final int version;
  final String? currentEmployeeUid;
  final String? locationId;

  bool get canBeAssigned =>
      status == CompanyAssetStatus.available && currentEmployeeUid == null;
}

final class AssetAssignment {
  const AssetAssignment({
    required this.id,
    required this.assetId,
    required this.employeeUid,
    required this.assignedBy,
    required this.assignedAt,
    required this.conditionAtHandover,
    this.returnedAt,
    this.returnReason,
    this.conditionAtReturn,
  });

  final String id;
  final String assetId;
  final String employeeUid;
  final String assignedBy;
  final DateTime assignedAt;
  final String conditionAtHandover;
  final DateTime? returnedAt;
  final String? returnReason;
  final String? conditionAtReturn;

  bool get active => returnedAt == null;
}

final class AssetMaintenance {
  const AssetMaintenance({
    required this.id,
    required this.assetId,
    required this.openedBy,
    required this.openedAt,
    required this.problem,
    required this.cost,
    required this.currency,
    this.costRequestId,
    this.completedAt,
    this.outcome,
  });

  final String id;
  final String assetId;
  final String openedBy;
  final DateTime openedAt;
  final String problem;
  final num cost;
  final String currency;
  final String? costRequestId;
  final DateTime? completedAt;
  final String? outcome;

  bool get hasValidCostLink =>
      cost <= 0 || (costRequestId?.isNotEmpty ?? false);
}
