import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/company_workspace_models.dart';
import '../models/employee_role.dart';
import '../models/user_model.dart';

class CompanyWorkspaceService {
  final FirebaseFirestore _db;

  static const List<Map<String, Object>> _starterSchemaProfiles = [
    {
      'id': 'tasks_and_performance',
      'name': 'المهام والأداء',
      'headerRow': 1,
      'keyColumn': 'record_id',
      'columnMappings': {
        'record_id': 'recordId',
        'employee_id': 'employeeId',
        'employee_code': 'employeeId',
        'employee_name': 'displayName',
        'task_name': 'taskName',
        'status': 'status',
        'amount': 'actual',
        'target': 'target',
        'actual': 'actual',
        'notes': 'notes',
        'updated_at': 'date',
        'date': 'date',
      },
      'editableFields': ['task_name', 'status', 'amount', 'actual', 'notes'],
    },
    {
      'id': 'attendance',
      'name': 'الحضور والانصراف',
      'headerRow': 1,
      'keyColumn': 'employee_code',
      'columnMappings': {
        'employee_code': 'employeeId',
        'employee_id': 'employeeId',
        'employee_name': 'displayName',
        'date': 'date',
        'check_in': 'checkIn',
        'check_out': 'checkOut',
        'status': 'status',
        'notes': 'notes',
      },
      'editableFields': ['check_in', 'check_out', 'status', 'notes'],
    },
    {
      'id': 'leave_and_permissions',
      'name': 'الإجازات والأذونات',
      'headerRow': 1,
      'keyColumn': 'request_id',
      'columnMappings': {
        'request_id': 'recordId',
        'employee_code': 'employeeId',
        'employee_id': 'employeeId',
        'employee_name': 'displayName',
        'request_type': 'requestType',
        'start_date': 'startDate',
        'end_date': 'endDate',
        'status': 'status',
        'reason': 'notes',
      },
      'editableFields': ['status', 'reason'],
    },
    {
      'id': 'sales_kpi',
      'name': 'المبيعات وKPI',
      'headerRow': 1,
      'keyColumn': 'record_id',
      'columnMappings': {
        'record_id': 'recordId',
        'employee_code': 'employeeId',
        'employee_id': 'employeeId',
        'employee_name': 'displayName',
        'period': 'period',
        'target': 'target',
        'actual': 'actual',
        'amount': 'actual',
        'status': 'status',
        'notes': 'notes',
      },
      'editableFields': ['target', 'actual', 'amount', 'status', 'notes'],
    },
  ];

  CompanyWorkspaceService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  bool canAdminister(UserModel user) => user.role == EmployeeRole.superAdmin;

  /// This is deliberately based on the employee's current role and IT unit,
  /// never a fixed employee code.  Reassigning the IT manager automatically
  /// changes workspace access with no code deployment.
  bool isItManager(UserModel user) {
    if (user.role != EmployeeRole.manager) return false;
    final unit = '${user.department} ${user.position}'.toLowerCase();
    return unit.contains('information technology') ||
        RegExp(r'(^|[^a-z])it([^a-z]|$)').hasMatch(unit) ||
        unit.contains('تكنولوجيا المعلومات') ||
        unit.contains('تقنية المعلومات') ||
        unit.contains('قسم تقنية') ||
        unit.contains('قسم it');
  }

  bool isWorkspaceController(UserModel user) =>
      canAdminister(user) || isItManager(user);

  bool canGrantAccess(UserModel user) => isWorkspaceController(user);

  Future<List<CompanyWorkspaceResource>> loadResources(UserModel user) async {
    if (isWorkspaceController(user)) {
      final snap = await _db.collection('workspaceResources').limit(150).get();
      return snap.docs
          .map(CompanyWorkspaceResource.fromFirestore)
          .where((item) => item.isActive)
          .toList(growable: false);
    }
    if (user.role == EmployeeRole.manager) {
      final snap = await _db
          .collection('workspaceResources')
          .where('managerIds', arrayContains: user.uid)
          .limit(100)
          .get();
      return snap.docs
          .map(CompanyWorkspaceResource.fromFirestore)
          .where((item) => item.isActive)
          .toList(growable: false);
    }

    final grants = await _db
        .collection('workspaceAccessGrants')
        .where('userId', isEqualTo: user.uid)
        .limit(100)
        .get();
    final active = grants.docs
        .map(WorkspaceAccessGrant.fromFirestore)
        .where((grant) => grant.isActive)
        .toList(growable: false);
    if (active.isEmpty) return const [];
    final docs = await Future.wait(
      active.map(
        (grant) =>
            _db.collection('workspaceResources').doc(grant.resourceId).get(),
      ),
    );
    return docs
        .where((doc) => doc.exists)
        .map(CompanyWorkspaceResource.fromFirestore)
        .where((item) => item.isActive)
        .toList(growable: false);
  }

  Future<List<WorkspaceSchemaProfile>> loadSchemaProfiles() async {
    final snap = await _db
        .collection('workspaceSchemaProfiles')
        .limit(100)
        .get();
    return snap.docs
        .map(WorkspaceSchemaProfile.fromFirestore)
        .toList(growable: false);
  }

  Future<List<WorkspaceAccessGrant>> loadGrants(UserModel user) async {
    Query<Map<String, dynamic>> query = _db.collection('workspaceAccessGrants');
    if (!isWorkspaceController(user)) {
      query = query.where('grantedBy', isEqualTo: user.uid);
    }
    final snap = await query.limit(150).get();
    return snap.docs
        .map(WorkspaceAccessGrant.fromFirestore)
        .where((grant) => grant.isActive)
        .toList(growable: false);
  }

  Future<List<WorkspaceAccessTemplate>> loadAccessTemplates() async {
    final snap = await _db
        .collection('workspaceAccessTemplates')
        .limit(50)
        .get();
    return snap.docs
        .map(WorkspaceAccessTemplate.fromFirestore)
        .where((template) => template.isActive)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> loadAuditLogs(UserModel user) async {
    Query<Map<String, dynamic>> query = _db.collection('workspaceAuditLogs');
    if (!isWorkspaceController(user)) {
      query = query.where('managerId', isEqualTo: user.uid);
    }
    final snap = await query.limit(100).get();
    final items = snap.docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList();
    items.sort((a, b) {
      final aTime = workspaceDateTime(a['createdAt']);
      final bTime = workspaceDateTime(b['createdAt']);
      return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
        aTime?.millisecondsSinceEpoch ?? 0,
      );
    });
    return items;
  }

  Future<List<UserModel>> loadGrantableUsers(UserModel actor) async {
    Query<Map<String, dynamic>> query = _db.collection('users');
    if (!isWorkspaceController(actor)) {
      query = query.where('managerIds', arrayContains: actor.uid);
    }
    final snap = await query.limit(200).get();
    return snap.docs
        .map(UserModel.fromFirestore)
        .where((user) => user.isActive && user.uid != actor.uid)
        .toList(growable: false);
  }

  Future<void> saveResource({
    String? id,
    required UserModel actor,
    required String name,
    required String type,
    required String department,
    required String description,
    required String externalId,
    required String schemaProfileId,
    required String sheetTab,
    required List<String> managerIds,
  }) async {
    if (!canAdminister(actor)) {
      throw StateError('إضافة مصادر الشركة متاحة لمسؤول النظام فقط.');
    }
    final ref = id == null
        ? _db.collection('workspaceResources').doc()
        : _db.collection('workspaceResources').doc(id);
    final resourceData = <String, dynamic>{
      'name': name.trim(),
      'type': type,
      'provider': 'google_workspace',
      'department': department.trim(),
      'description': description.trim(),
      'schemaProfileId': schemaProfileId,
      'sheetTab': sheetTab.trim(),
      'managerIds': managerIds.toSet().toList(),
      'isActive': true,
      if (id == null || externalId.trim().isNotEmpty)
        'hasExternalId': externalId.trim().isNotEmpty,
      if (id == null || externalId.trim().isNotEmpty)
        'syncStatus': externalId.trim().isEmpty
            ? 'not_connected'
            : 'configured',
      'createdBy': actor.uid,
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id == null) 'createdAt': FieldValue.serverTimestamp(),
    };
    final batch = _db.batch();
    batch.set(ref, resourceData, SetOptions(merge: true));
    if (externalId.trim().isNotEmpty) {
      batch.set(
        _db.collection('workspaceResourceSecrets').doc(ref.id),
        {
          'externalId': externalId.trim(),
          'provider': 'google_workspace',
          'updatedBy': actor.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    await recordAudit(
      actor: actor,
      action: id == null ? 'resource_created' : 'resource_updated',
      resourceId: ref.id,
      resourceName: name,
    );
  }

  Future<void> saveSchemaProfile({
    String? id,
    required UserModel actor,
    required String name,
    required int headerRow,
    required String keyColumn,
    required Map<String, String> mappings,
    required List<String> editableFields,
  }) async {
    if (!canAdminister(actor)) {
      throw StateError('إدارة مخططات Sheets متاحة لمسؤول النظام فقط.');
    }
    final ref = id == null
        ? _db.collection('workspaceSchemaProfiles').doc()
        : _db.collection('workspaceSchemaProfiles').doc(id);
    await ref.set({
      'name': name.trim(),
      'headerRow': headerRow,
      'keyColumn': keyColumn.trim(),
      'columnMappings': mappings,
      'editableFields': editableFields.toSet().toList(),
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Creates or refreshes the built-in layouts without overwriting a custom
  /// profile with the same id. A system administrator can run this safely
  /// more than once as the company adds Sheets over time.
  Future<int> seedStarterSchemaProfiles({required UserModel actor}) async {
    if (!canAdminister(actor)) {
      throw StateError('إدارة مخططات Sheets متاحة لمسؤول النظام فقط.');
    }
    final batch = _db.batch();
    for (final profile in _starterSchemaProfiles) {
      final id = profile['id']! as String;
      final ref = _db.collection('workspaceSchemaProfiles').doc(id);
      batch.set(ref, {
        ...profile,
        'updatedBy': actor.uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
    return _starterSchemaProfiles.length;
  }

  Future<void> saveAccessTemplate({
    required UserModel actor,
    required String name,
    required String scopeType,
    required String permission,
  }) async {
    if (!canAdminister(actor)) {
      throw StateError('إدارة قوالب الصلاحيات متاحة لمسؤول النظام فقط.');
    }
    if (!const ['employee', 'department', 'manager_team'].contains(scopeType) ||
        !const ['view', 'download', 'edit'].contains(permission)) {
      throw ArgumentError('قالب الصلاحيات غير صالح.');
    }
    await _db.collection('workspaceAccessTemplates').add({
      'name': name.trim(),
      'scopeType': scopeType,
      'permission': permission,
      'isActive': true,
      'createdBy': actor.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<int> applyAccessTemplate({
    required UserModel actor,
    required CompanyWorkspaceResource resource,
    required WorkspaceAccessTemplate template,
    UserModel? selectedUser,
  }) async {
    if (!canGrantAccess(actor)) {
      throw StateError('لا تملك صلاحية تطبيق قالب الوصول.');
    }
    final available = await loadGrantableUsers(actor);
    late final List<UserModel> targets;
    switch (template.scopeType) {
      case 'employee':
        if (selectedUser == null) {
          throw ArgumentError('اختر الموظف أولاً.');
        }
        targets = [selectedUser];
        break;
      case 'department':
        if (resource.department.trim().isEmpty) {
          throw ArgumentError('المصدر غير مرتبط بقسم.');
        }
        targets = available
            .where(
              (user) =>
                  user.department.trim().toLowerCase() ==
                  resource.department.trim().toLowerCase(),
            )
            .toList();
        break;
      case 'manager_team':
        targets =
            !isWorkspaceController(actor) && actor.role == EmployeeRole.manager
            ? available
            : selectedUser == null
            ? <UserModel>[]
            : available
                  .where(
                    (user) =>
                        user.managerId == selectedUser.uid ||
                        user.managerIds.contains(selectedUser.uid),
                  )
                  .toList();
        break;
      default:
        targets = const [];
        break;
    }
    if (targets.isEmpty) {
      throw StateError('لم يتم العثور على موظفين مطابقين للقالب.');
    }
    for (final target in targets) {
      await grantAccess(
        actor: actor,
        resource: resource,
        target: target,
        permission: template.permission,
      );
    }
    return targets.length;
  }

  Future<WorkspaceBulkImportResult> importResources({
    required UserModel actor,
    required List<WorkspaceBulkResourceRow> rows,
    required List<UserModel> directory,
    required List<WorkspaceSchemaProfile> profiles,
  }) async {
    if (!canAdminister(actor)) {
      throw StateError('الاستيراد الجماعي متاح لمسؤول النظام فقط.');
    }
    final usersByCode = <String, UserModel>{
      for (final user in directory) user.employeeId.trim().toUpperCase(): user,
    };
    final profilesByName = <String, WorkspaceSchemaProfile>{
      for (final profile in profiles)
        profile.name.trim().toLowerCase(): profile,
      for (final profile in profiles) profile.id.trim().toLowerCase(): profile,
    };
    var resourcesCreated = 0;
    var grantsCreated = 0;
    for (final row in rows) {
      final manager = usersByCode[row.managerCode.trim().toUpperCase()];
      final employee = usersByCode[row.employeeCode.trim().toUpperCase()];
      final profile = profilesByName[row.schemaProfile.trim().toLowerCase()];
      final ref = _db.collection('workspaceResources').doc();
      final batch = _db.batch();
      batch.set(ref, {
        'name': row.name.trim(),
        'type': row.type,
        'provider': 'google_workspace',
        'department': row.department.trim(),
        'description': row.description.trim(),
        'schemaProfileId': profile?.id ?? '',
        'sheetTab': '',
        'managerIds': manager == null ? <String>[] : <String>[manager.uid],
        'isActive': true,
        'hasExternalId': row.googleId.trim().isNotEmpty,
        'syncStatus': row.googleId.trim().isEmpty
            ? 'not_connected'
            : 'configured',
        'createdBy': actor.uid,
        'updatedBy': actor.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (row.googleId.trim().isNotEmpty) {
        batch.set(_db.collection('workspaceResourceSecrets').doc(ref.id), {
          'externalId': row.googleId.trim(),
          'provider': 'google_workspace',
          'updatedBy': actor.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (employee != null) {
        batch.set(
          _db
              .collection('workspaceAccessGrants')
              .doc('${ref.id}_${employee.uid}'),
          {
            'resourceId': ref.id,
            'resourceName': row.name.trim(),
            'userId': employee.uid,
            'userName': employee.displayName,
            'employeeCode': employee.employeeId,
            'department': employee.department,
            'permission': row.permission,
            'grantedBy': actor.uid,
            'grantedByName': actor.displayName,
            'managerId': employee.managerId ?? '',
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
      batch.set(_db.collection('workspaceAuditLogs').doc(), {
        'actorId': actor.uid,
        'actorName': actor.displayName,
        'actorCode': actor.employeeId,
        'action': 'resource_created',
        'resourceId': ref.id,
        'resourceName': row.name.trim(),
        'targetUserId': employee?.uid ?? '',
        'managerId': manager?.uid ?? employee?.managerId ?? '',
        'metadata': {'source': 'csv', 'row': row.rowNumber},
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      resourcesCreated++;
      if (employee != null) grantsCreated++;
    }
    return WorkspaceBulkImportResult(
      resourcesCreated: resourcesCreated,
      grantsCreated: grantsCreated,
    );
  }

  Future<void> grantAccess({
    required UserModel actor,
    required CompanyWorkspaceResource resource,
    required UserModel target,
    required String permission,
  }) async {
    if (!canGrantAccess(actor)) {
      throw StateError('لا تملك صلاحية منح الوصول.');
    }
    final id = '${resource.id}_${target.uid}';
    final ref = _db.collection('workspaceAccessGrants').doc(id);
    await ref.set({
      'resourceId': resource.id,
      'resourceName': resource.name,
      'userId': target.uid,
      'userName': target.displayName,
      'employeeCode': target.employeeId,
      'department': target.department,
      'permission': permission,
      'grantedBy': actor.uid,
      'grantedByName': actor.displayName,
      'managerId': actor.role == EmployeeRole.manager
          ? actor.uid
          : (target.managerId ?? ''),
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'revokedBy': FieldValue.delete(),
      'revokedAt': FieldValue.delete(),
    }, SetOptions(merge: true));
    await recordAudit(
      actor: actor,
      action: 'access_granted',
      resourceId: resource.id,
      resourceName: resource.name,
      targetUserId: target.uid,
      managerId: actor.role == EmployeeRole.manager
          ? actor.uid
          : target.managerId,
      metadata: {'permission': permission, 'employeeCode': target.employeeId},
    );
  }

  Future<void> revokeAccess({
    required UserModel actor,
    required WorkspaceAccessGrant grant,
  }) async {
    await _db.collection('workspaceAccessGrants').doc(grant.id).update({
      'isActive': false,
      'revokedBy': actor.uid,
      'revokedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await recordAudit(
      actor: actor,
      action: 'access_revoked',
      resourceId: grant.resourceId,
      resourceName: grant.resourceName,
      targetUserId: grant.userId,
      managerId: actor.role == EmployeeRole.manager ? actor.uid : null,
    );
  }

  Future<void> recordAudit({
    required UserModel actor,
    required String action,
    required String resourceId,
    required String resourceName,
    String? targetUserId,
    String? managerId,
    Map<String, dynamic>? metadata,
  }) async {
    await _db.collection('workspaceAuditLogs').add({
      'actorId': actor.uid,
      'actorName': actor.displayName,
      'actorCode': actor.employeeId,
      'action': action,
      'resourceId': resourceId,
      'resourceName': resourceName,
      'targetUserId': targetUserId ?? actor.uid,
      'managerId': managerId ?? actor.managerId ?? '',
      'metadata': metadata ?? const <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
