import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/request_visibility/domain/entities/request_visibility_record.dart';
import 'package:zawolf_hr/features/request_visibility/presentation/widgets/request_type_style.dart';

void main() {
  group('RequestTypeStyle', () {
    test('provides distinctive border colors and glow shadows for each request type', () {
      final leaveStyle = RequestTypeStyle.leave;
      final permissionStyle = RequestTypeStyle.permission;
      final advanceStyle = RequestTypeStyle.advance;
      final correctionStyle = RequestTypeStyle.attendanceCorrection;
      final deductionStyle = RequestTypeStyle.salaryDeduction;
      final complaintStyle = RequestTypeStyle.complaint;
      final resignationStyle = RequestTypeStyle.resignation;

      // Unique border colors
      expect(leaveStyle.borderColor, isNot(equals(permissionStyle.borderColor)));
      expect(permissionStyle.borderColor, isNot(equals(advanceStyle.borderColor)));
      expect(advanceStyle.borderColor, isNot(equals(correctionStyle.borderColor)));
      expect(correctionStyle.borderColor, isNot(equals(deductionStyle.borderColor)));
      expect(complaintStyle.borderColor, isNot(equals(resignationStyle.borderColor)));

      // Shadow colors have appropriate opacity
      expect(leaveStyle.shadowColor.a, greaterThan(0));
      expect(permissionStyle.shadowColor.a, greaterThan(0));

      // Arabic labels
      expect(leaveStyle.label, 'إجازة');
      expect(permissionStyle.label, 'إذن');
      expect(advanceStyle.label, 'سلفة');
      expect(correctionStyle.label, 'تصحيح حضور');
      expect(deductionStyle.label, 'خصم راتب');
      expect(complaintStyle.label, 'شكوى');
      expect(resignationStyle.label, 'استقالة');
    });

    test('maps lifecycle state and approval stage to correct localized labels and colors', () {
      expect(RequestTypeStyle.stateLabel(RequestLifecycleState.pending), 'قيد المراجعة');
      expect(RequestTypeStyle.stateLabel(RequestLifecycleState.approved), 'مقبول');
      expect(RequestTypeStyle.stateLabel(RequestLifecycleState.rejected), 'مرفوض');

      expect(RequestTypeStyle.stageLabel(RequestApprovalStage.manager), 'المدير');
      expect(RequestTypeStyle.stageLabel(RequestApprovalStage.hr), 'HR');
      expect(RequestTypeStyle.stageLabel(RequestApprovalStage.ceo), 'المالك');
    });
  });
}
