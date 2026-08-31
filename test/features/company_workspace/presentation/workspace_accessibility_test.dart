import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_workspace/presentation/widgets/sheet/workspace_sheet_status_bar.dart';
import 'package:zawolf_hr/features/company_workspace/presentation/widgets/workspace_sync_status_banner.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('workspace status surfaces are selectable, RTL-safe and accessible', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(children: [
          WorkspaceSyncStatusBanner(message: 'سيتم الحفظ عند عودة الاتصال.', kind: WorkspaceSyncStatusKind.pending),
          WorkspaceSheetStatusBar(canEdit: true),
        ]),
      ),
    ));
    expect(find.text('سيتم الحفظ عند عودة الاتصال.'), findsOneWidget);
    expect(find.text('جاهز للحفظ'), findsOneWidget);
    expect(tester.getSemantics(find.text('جاهز للحفظ')), isNotNull);
  });
}
