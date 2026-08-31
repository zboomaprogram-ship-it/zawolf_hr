import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy Workspace remains available during V2 migration', () {
    final router = File('lib/navigation/router.dart').readAsStringSync();
    final center = File(
      'lib/screens/shared/company_workspace_center_screen.dart',
    ).readAsStringSync();
    final editor = File(
      'lib/screens/shared/workspace_sheet_editor_screen.dart',
    ).readAsStringSync();

    expect(router, contains('CompanyWorkspaceCenterScreen'));
    expect(center, contains('GoogleWorkspaceService'));
    expect(editor, contains('PlutoGrid'));
  });
}
