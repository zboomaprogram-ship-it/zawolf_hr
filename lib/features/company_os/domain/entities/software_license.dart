final class SoftwareLicense {
  const SoftwareLicense({
    required this.id,
    required this.name,
    required this.vendor,
    required this.totalSeats,
    required this.usedSeats,
    required this.status,
    required this.version,
    this.renewalAt,
  });

  final String id;
  final String name;
  final String vendor;
  final int totalSeats;
  final int usedSeats;
  final String status;
  final int version;
  final DateTime? renewalAt;

  int get availableSeats => totalSeats - usedSeats;
  bool get canAssignSeat => status == 'active' && availableSeats > 0;
}

final class SoftwareAssignment {
  const SoftwareAssignment({
    required this.id,
    required this.licenseId,
    required this.employeeUid,
    required this.assignedBy,
    required this.assignedAt,
    this.revokedAt,
  });

  final String id;
  final String licenseId;
  final String employeeUid;
  final String assignedBy;
  final DateTime assignedAt;
  final DateTime? revokedAt;

  bool get active => revokedAt == null;
}
