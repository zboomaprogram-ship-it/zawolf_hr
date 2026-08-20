import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zawolf_hr/models/company_workspace_models.dart';
import 'package:zawolf_hr/utils/workspace_csv_import.dart';

void main() {
  final service = File(
    'lib/services/company_workspace_service.dart',
  ).readAsStringSync();
  final screen = File(
    'lib/screens/shared/company_workspace_center_screen.dart',
  ).readAsStringSync();
  final router = File('lib/navigation/router.dart').readAsStringSync();
  final rules = File('firestore.rules').readAsStringSync();
  final sheetEditor = File(
    'lib/screens/shared/workspace_sheet_editor_screen.dart',
  ).readAsStringSync();
  final folderBrowser = File(
    'lib/screens/shared/workspace_folder_browser_screen.dart',
  ).readAsStringSync();
  final reportsScreen = File(
    'lib/screens/hr/sheets_export_screen.dart',
  ).readAsStringSync();

  test('workspace center is available from one shared route', () {
    expect(router, contains("path: '/workspace'"));
    expect(router, contains('CompanyWorkspaceCenterScreen'));
    expect(screen, contains('مركز ملفات الشركة'));
  });

  test('only system admin adds resources and schema profiles', () {
    expect(service, contains('user.role == EmployeeRole.superAdmin'));
    expect(
      rules,
      contains(
        'allow create, update: if isAuth() && isActive() && isSuperAdmin()',
      ),
    );
    expect(rules, contains('match /workspaceSchemaProfiles/{profileId}'));
  });

  test('manager grants only scoped resources to assigned employees', () {
    expect(
      rules,
      contains('managesWorkspaceResource(request.resource.data.resourceId)'),
    );
    expect(
      rules,
      contains('isAssignedManagerForUser(request.resource.data.userId)'),
    );
    expect(rules, contains("permission in ['view', 'download', 'edit']"));
  });

  test('Google identifiers are isolated from employee-visible metadata', () {
    expect(rules, contains('match /workspaceResourceSecrets/{resourceId}'));
    expect(
      rules,
      contains(
        'allow read, create, update: if isAuth() && isActive() && isSuperAdmin()',
      ),
    );
    expect(service, contains("collection('workspaceResourceSecrets')"));
    expect(
      File('lib/models/company_workspace_models.dart').readAsStringSync(),
      isNot(contains("data['externalId']")),
    );
  });

  test('workspace actions produce immutable audit records', () {
    expect(service, contains("collection('workspaceAuditLogs').add"));
    expect(rules, contains('match /workspaceAuditLogs/{auditId}'));
    expect(rules, contains('allow update, delete: if false;'));
    expect(screen, isNot(contains('سجل التدقيق')));
    expect(reportsScreen, contains('سجل تدقيق Workspace'));
    expect(reportsScreen, contains('generateWorkspaceAuditReport'));
  });

  test('workspace dates tolerate Firestore and legacy ISO values', () {
    final expected = DateTime.utc(2026, 8, 13, 9, 50, 11);
    expect(workspaceDateTime(Timestamp.fromDate(expected))?.toUtc(), expected);
    expect(workspaceDateTime(expected.toIso8601String())?.toUtc(), expected);
    expect(workspaceDateTime(null), isNull);
  });

  test('bulk CSV validates and prepares employee resource links', () {
    final preview = parseWorkspaceCsvRows(
      [
        [
          'name',
          'type',
          'google_id',
          'department',
          'schema_profile',
          'manager_code',
          'employee_code',
          'permission',
        ],
        [
          'IT Tasks',
          'sheet',
          'google-1',
          'IT',
          'Tasks',
          'CEO-100',
          'IT-400',
          'edit',
        ],
      ],
      employeeCodes: {'CEO-100', 'IT-400'},
      schemaProfiles: {'Tasks'},
    );
    expect(preview.errors, isEmpty);
    expect(preview.canImport, isTrue);
    expect(preview.rows.single.employeeCode, 'IT-400');
    expect(preview.rows.single.permission, 'edit');
  });

  test('bulk CSV rejects unknown employees and duplicate Google IDs', () {
    final preview = parseWorkspaceCsvRows(
      [
        ['name', 'type', 'google_id', 'employee_code'],
        ['First', 'sheet', 'duplicate', 'UNKNOWN'],
        ['Second', 'sheet', 'duplicate', ''],
      ],
      employeeCodes: {'IT-400'},
      schemaProfiles: const {},
    );
    expect(preview.canImport, isFalse);
    expect(preview.errors.any((error) => error.contains('UNKNOWN')), isTrue);
    expect(preview.errors.any((error) => error.contains('مكرر')), isTrue);
  });

  test('access templates are protected and support the three scopes', () {
    expect(rules, contains('match /workspaceAccessTemplates/{templateId}'));
    expect(rules, contains("'employee', 'department', 'manager_team'"));
    expect(screen, contains('استيراد CSV'));
    expect(screen, contains('تطبيق قالب صلاحيات'));
  });

  test('workspace folders and Sheets open on dedicated pages', () {
    expect(screen, contains('WorkspaceFolderBrowserScreen'));
    expect(folderBrowser, contains('WorkspaceSheetEditorScreen'));
    expect(folderBrowser, isNot(contains('showDialog')));
  });

  test('Sheet editor provides native grid interactions', () {
    expect(sheetEditor, contains('PlutoGrid('));
    expect(sheetEditor, contains('enableAutoEditing: true'));
    expect(sheetEditor, contains('PlutoGridSelectingMode.cell'));
    expect(sheetEditor, contains('draggableScrollbar: true'));
    expect(sheetEditor, contains('_selectFullRow'));
    expect(sheetEditor, contains('_selectFullColumn'));
    expect(sheetEditor, contains('_addRows'));
    expect(sheetEditor, contains('_addColumns'));
    expect(sheetEditor, contains('_addSheetTab'));
    expect(sheetEditor, contains('_renameCurrentTab'));
    expect(sheetEditor, contains('_deleteCurrentTab'));
    expect(sheetEditor, contains('إضافة Sheet جديد'));
    expect(sheetEditor, contains('_createLabels'));
    expect(sheetEditor, contains('_formulaBar'));
  });
}
