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

class HiringManagerOption {
  const HiringManagerOption({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.department,
  });
  final String id, name, employeeId, department;
}

class HiringEmployeeOption {
  const HiringEmployeeOption({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.department,
    required this.jobTitle,
  });
  final String id, name, employeeId, department, jobTitle;
}

abstract interface class HiringRequestRepository {
  Future<List<HiringRequest>> list();
  Future<List<HiringManagerOption>> getManagers();
  Future<List<String>> getJobTitles();
  Future<List<HiringEmployeeOption>> getEmployees();
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
