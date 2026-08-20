import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/core/errors/errors.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_presentation_state.dart';
import 'package:zawolf_hr/features/attendance_checkin/presentation/widgets/checkin_status_feedback.dart';

void main() {
  Future<void> pumpFeedback(
    WidgetTester tester,
    CheckInPresentationState state,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CheckInStatusFeedback(state: state, failureMessage: null),
      ),
    ),
  );

  testWidgets('renders distinct safe Arabic feedback for saved and pending', (
    tester,
  ) async {
    await pumpFeedback(
      tester,
      const CheckInPresentationState(status: CheckInViewStatus.saved),
    );
    expect(find.textContaining('تم حفظ'), findsOneWidget);

    await pumpFeedback(
      tester,
      const CheckInPresentationState(status: CheckInViewStatus.pendingSync),
    );
    expect(find.textContaining('بانتظار المزامنة'), findsOneWidget);
  });

  testWidgets('never renders raw infrastructure details in failure feedback', (
    tester,
  ) async {
    await pumpFeedback(
      tester,
      CheckInPresentationState(
        status: CheckInViewStatus.failed,
        failure: AppFailure(
          category: FailureCategory.access,
          recovery: RecoveryGuidance.contactResponsibleTeam,
          outcomeCertainty: OutcomeCertainty.confirmedNotCompleted,
          diagnosticKey: 'FirebaseException: permission-denied',
        ),
      ),
    );

    final allText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .join(' ')
        .toLowerCase();
    expect(allText, isNot(contains('firebase')));
    expect(allText, isNot(contains('firestore')));
    expect(allText, isNot(contains('http')));
    expect(allText, contains('صلاحية'));
  });

  testWidgets('offers an explicit safe status check when a retry is supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckInStatusFeedback(
            state: const CheckInPresentationState(
              status: CheckInViewStatus.requiresStatusCheck,
            ),
            failureMessage: null,
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('تحقق من الحالة'), findsOneWidget);
  });
}
