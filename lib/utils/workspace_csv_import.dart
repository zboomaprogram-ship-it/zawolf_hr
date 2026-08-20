import '../models/company_workspace_models.dart';

class WorkspaceCsvPreview {
  final List<WorkspaceBulkResourceRow> rows;
  final List<String> errors;

  const WorkspaceCsvPreview({required this.rows, required this.errors});

  bool get canImport => rows.isNotEmpty && errors.isEmpty;
}

WorkspaceCsvPreview parseWorkspaceCsvRows(
  List<List<dynamic>> csvRows, {
  required Set<String> employeeCodes,
  required Set<String> schemaProfiles,
}) {
  if (csvRows.isEmpty) {
    return const WorkspaceCsvPreview(rows: [], errors: ['ملف CSV فارغ.']);
  }
  String normalize(Object? value) => '$value'
      .replaceFirst('\ufeff', '')
      .trim()
      .toLowerCase()
      .replaceAll(' ', '_');
  final headers = csvRows.first.map(normalize).toList(growable: false);
  final headerIndex = <String, int>{
    for (var index = 0; index < headers.length; index++) headers[index]: index,
  };
  final errors = <String>[];
  for (final required in ['name', 'type']) {
    if (!headerIndex.containsKey(required)) {
      errors.add('العمود المطلوب غير موجود: $required');
    }
  }
  if (errors.isNotEmpty) {
    return WorkspaceCsvPreview(rows: const [], errors: errors);
  }

  String value(List<dynamic> row, String name) {
    final index = headerIndex[name];
    if (index == null || index >= row.length) return '';
    return '${row[index]}'.trim();
  }

  final normalizedCodes = employeeCodes
      .map((code) => code.trim().toUpperCase())
      .toSet();
  final normalizedProfiles = schemaProfiles
      .map((profile) => profile.trim().toLowerCase())
      .toSet();
  final seenGoogleIds = <String>{};
  final parsed = <WorkspaceBulkResourceRow>[];
  for (var index = 1; index < csvRows.length; index++) {
    final source = csvRows[index];
    if (source.every((cell) => '$cell'.trim().isEmpty)) continue;
    final rowNumber = index + 1;
    final name = value(source, 'name');
    var type = value(source, 'type').toLowerCase();
    type = switch (type) {
      'google_sheet' || 'google sheets' || 'spreadsheet' => 'sheet',
      'drive_folder' => 'folder',
      'drive_file' => 'file',
      _ => type,
    };
    final googleId = value(source, 'google_id');
    final managerCode = value(source, 'manager_code').toUpperCase();
    final employeeCode = value(source, 'employee_code').toUpperCase();
    final schemaProfile = value(source, 'schema_profile');
    final permissionValue = value(source, 'permission').toLowerCase();
    final permission = permissionValue.isEmpty ? 'view' : permissionValue;

    if (name.isEmpty) errors.add('الصف $rowNumber: الاسم مطلوب.');
    if (!const ['sheet', 'folder', 'file'].contains(type)) {
      errors.add('الصف $rowNumber: النوع يجب أن يكون sheet أو folder أو file.');
    }
    if (!const ['view', 'download', 'edit'].contains(permission)) {
      errors.add('الصف $rowNumber: الصلاحية غير صحيحة.');
    }
    if (managerCode.isNotEmpty && !normalizedCodes.contains(managerCode)) {
      errors.add('الصف $rowNumber: كود المدير $managerCode غير موجود.');
    }
    if (employeeCode.isNotEmpty && !normalizedCodes.contains(employeeCode)) {
      errors.add('الصف $rowNumber: كود الموظف $employeeCode غير موجود.');
    }
    if (schemaProfile.isNotEmpty &&
        !normalizedProfiles.contains(schemaProfile.toLowerCase())) {
      errors.add('الصف $rowNumber: Schema Profile غير موجود.');
    }
    if (googleId.isNotEmpty && !seenGoogleIds.add(googleId)) {
      errors.add('الصف $rowNumber: Google ID مكرر داخل الملف.');
    }
    parsed.add(
      WorkspaceBulkResourceRow(
        rowNumber: rowNumber,
        name: name,
        type: type,
        googleId: googleId,
        department: value(source, 'department'),
        description: value(source, 'description'),
        schemaProfile: schemaProfile,
        managerCode: managerCode,
        employeeCode: employeeCode,
        permission: permission,
      ),
    );
  }
  if (parsed.isEmpty && errors.isEmpty) errors.add('لا توجد صفوف بيانات.');
  return WorkspaceCsvPreview(rows: parsed, errors: errors);
}
