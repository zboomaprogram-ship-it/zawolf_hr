import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? workspaceDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

class CompanyWorkspaceResource {
  final String id;
  final String name;
  final String type;
  final String department;
  final String description;
  final bool hasExternalId;
  final String schemaProfileId;
  final String sheetTab;
  final List<String> managerIds;
  final bool isActive;
  final String syncStatus;
  final DateTime? updatedAt;

  const CompanyWorkspaceResource({
    required this.id,
    required this.name,
    required this.type,
    required this.department,
    required this.description,
    required this.hasExternalId,
    required this.schemaProfileId,
    required this.sheetTab,
    required this.managerIds,
    required this.isActive,
    required this.syncStatus,
    this.updatedAt,
  });

  factory CompanyWorkspaceResource.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CompanyWorkspaceResource(
      id: doc.id,
      name: '${data['name'] ?? ''}',
      type: '${data['type'] ?? 'file'}',
      department: '${data['department'] ?? ''}',
      description: '${data['description'] ?? ''}',
      hasExternalId: data['hasExternalId'] as bool? ?? false,
      schemaProfileId: '${data['schemaProfileId'] ?? ''}',
      sheetTab: '${data['sheetTab'] ?? ''}',
      managerIds: (data['managerIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      isActive: data['isActive'] as bool? ?? true,
      syncStatus: '${data['syncStatus'] ?? 'not_connected'}',
      updatedAt: workspaceDateTime(data['updatedAt']),
    );
  }
}

class WorkspaceSchemaProfile {
  final String id;
  final String name;
  final int headerRow;
  final String keyColumn;
  final Map<String, String> columnMappings;
  final List<String> editableFields;

  const WorkspaceSchemaProfile({
    required this.id,
    required this.name,
    required this.headerRow,
    required this.keyColumn,
    required this.columnMappings,
    required this.editableFields,
  });

  factory WorkspaceSchemaProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return WorkspaceSchemaProfile(
      id: doc.id,
      name: '${data['name'] ?? ''}',
      headerRow: (data['headerRow'] as num?)?.toInt() ?? 1,
      keyColumn: '${data['keyColumn'] ?? 'employee_code'}',
      columnMappings: Map<String, String>.from(
        data['columnMappings'] as Map? ?? const {},
      ),
      editableFields: (data['editableFields'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

class WorkspaceAccessGrant {
  final String id;
  final String resourceId;
  final String resourceName;
  final String userId;
  final String userName;
  final String employeeCode;
  final String permission;
  final String grantedBy;
  final bool isActive;

  const WorkspaceAccessGrant({
    required this.id,
    required this.resourceId,
    required this.resourceName,
    required this.userId,
    required this.userName,
    required this.employeeCode,
    required this.permission,
    required this.grantedBy,
    required this.isActive,
  });

  factory WorkspaceAccessGrant.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return WorkspaceAccessGrant(
      id: doc.id,
      resourceId: '${data['resourceId'] ?? ''}',
      resourceName: '${data['resourceName'] ?? ''}',
      userId: '${data['userId'] ?? ''}',
      userName: '${data['userName'] ?? ''}',
      employeeCode: '${data['employeeCode'] ?? ''}',
      permission: '${data['permission'] ?? 'view'}',
      grantedBy: '${data['grantedBy'] ?? ''}',
      isActive: data['isActive'] as bool? ?? true,
    );
  }
}

class WorkspaceAccessTemplate {
  final String id;
  final String name;
  final String scopeType;
  final String permission;
  final bool isActive;

  const WorkspaceAccessTemplate({
    required this.id,
    required this.name,
    required this.scopeType,
    required this.permission,
    required this.isActive,
  });

  factory WorkspaceAccessTemplate.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return WorkspaceAccessTemplate(
      id: doc.id,
      name: '${data['name'] ?? ''}',
      scopeType: '${data['scopeType'] ?? 'employee'}',
      permission: '${data['permission'] ?? 'view'}',
      isActive: data['isActive'] as bool? ?? true,
    );
  }
}

class WorkspaceBulkResourceRow {
  final int rowNumber;
  final String name;
  final String type;
  final String googleId;
  final String department;
  final String description;
  final String schemaProfile;
  final String managerCode;
  final String employeeCode;
  final String permission;

  const WorkspaceBulkResourceRow({
    required this.rowNumber,
    required this.name,
    required this.type,
    required this.googleId,
    required this.department,
    required this.description,
    required this.schemaProfile,
    required this.managerCode,
    required this.employeeCode,
    required this.permission,
  });
}

class WorkspaceBulkImportResult {
  final int resourcesCreated;
  final int grantsCreated;

  const WorkspaceBulkImportResult({
    required this.resourcesCreated,
    required this.grantsCreated,
  });
}
