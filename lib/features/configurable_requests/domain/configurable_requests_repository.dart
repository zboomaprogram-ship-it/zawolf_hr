class CustomRequestType {
  const CustomRequestType({
    required this.id,
    required this.name,
    required this.description,
    required this.fields,
  });
  final String id;
  final String name;
  final String description;
  final List<Map<String, dynamic>> fields;
}

class CustomRequestDirectoryUser {
  const CustomRequestDirectoryUser({
    required this.id,
    required this.name,
    required this.department,
    required this.role,
  });
  final String id;
  final String name;
  final String department;
  final String role;
}

abstract interface class ConfigurableRequestsRepository {
  Future<List<CustomRequestType>> types();
  Future<List<CustomRequestDirectoryUser>> directory();
  Future<void> saveType({
    required String name,
    required String description,
    required List<String> approverIds,
    required bool allActive,
    required List<String> employeeIds,
    required List<Map<String, Object?>> fields,
  });
  Future<void> submit({
    required String typeId,
    required String description,
    required Map<String, String> answers,
  });
  Future<void> submitDirect({
    required String title,
    required String description,
    required List<String> approverIds,
    String? attachmentUrl,
  });
  Future<List<Map<String, dynamic>>> requests({required bool queue});
  Future<void> decide({
    required String id,
    required bool approved,
    String comment = '',
  });
}
