class HiringRequest {
  const HiringRequest({
    required this.id,
    required this.name,
    required this.jobTitle,
    required this.status,
    required this.currentApproverName,
  });
  final String id, name, jobTitle, status, currentApproverName;
}

abstract interface class HiringRequestRepository {
  Future<List<HiringRequest>> list();
  Future<void> create({
    required String name,
    required String jobTitle,
    required String managerId,
    required String managerName,
    required double salary,
    required String currency,
    required DateTime assignmentDate,
    String? existingEmployeeUid,
  });
  Future<void> decide({
    required String id,
    required bool approved,
    String? comment,
  });
}
