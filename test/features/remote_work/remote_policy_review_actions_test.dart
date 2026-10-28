import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/remote_work/presentation/widgets/remote_policy_review_actions.dart';

void main() {
  for (final blockedBy in ['unsaved', 'working', 'no_draft']) {
    testWidgets('$blockedBy prevents approval and publication', (tester) async {
      var approvals = 0;
      var publications = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemotePolicyReviewActions(
              draftVersion: blockedBy == 'no_draft' ? 0 : 2,
              hasUnsavedChanges: blockedBy == 'unsaved',
              working: blockedBy == 'working',
              reason: 'Reviewed',
              onApprove: () => approvals++,
              onPublish: () => publications++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('اعتماد المسودة'));
      await tester.tap(find.text('نشر السياسة المعتمدة'));
      expect(approvals, 0);
      expect(publications, 0);
      if (blockedBy == 'unsaved') {
        expect(find.textContaining('احفظ'), findsOneWidget);
      }
    });
  }

  testWidgets(
    'a saved draft allows review and publication with explicit reason',
    (tester) async {
      var approvals = 0;
      var publications = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemotePolicyReviewActions(
              draftVersion: 2,
              hasUnsavedChanges: false,
              working: false,
              reason: 'Reviewed',
              onApprove: () => approvals++,
              onPublish: () => publications++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('اعتماد المسودة'));
      await tester.tap(find.text('نشر السياسة المعتمدة'));
      expect(approvals, 1);
      expect(publications, 1);
    },
  );

  testWidgets('an empty review reason keeps approval unavailable', (
    tester,
  ) async {
    var approvals = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemotePolicyReviewActions(
            draftVersion: 2,
            hasUnsavedChanges: false,
            working: false,
            reason: '   ',
            onApprove: () => approvals++,
            onPublish: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('اعتماد المسودة'));
    expect(approvals, 0);
  });
}
