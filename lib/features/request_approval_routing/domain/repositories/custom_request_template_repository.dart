import '../entities/custom_request_template.dart';

abstract interface class CustomRequestTemplateRepository {
  Future<List<CustomRequestType>> loadRequestTypes();
  Future<void> saveRequestType(CustomRequestType requestType);
  Future<void> deleteRequestType(String id);
  Stream<CustomRequestType> watchPermissionTemplate();
  Future<CustomRequestType> getPermissionTemplate();
  Stream<CustomRequestType> watchLeaveTemplate();
  Stream<CustomRequestType> watchAdvanceTemplate();
  Stream<CustomRequestType> watchResignationTemplate();
  Stream<List<CustomRequestType>> watchAllTemplates();
}
