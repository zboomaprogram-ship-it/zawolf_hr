import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/complaint_model.dart';

void main() {
  group('ComplaintModel', () {
    test('serializes anonymous complaint without public identity fields', () {
      const complaint = ComplaintModel(
        complaintId: 'complaint-1',
        userId: 'user-1',
        employeeId: '',
        employeeName: 'مجهول',
        department: '',
        title: 'عنوان الشكوى',
        body: 'تفاصيل كافية لاختبار الشكوى المجهولة',
        isAnonymous: true,
        status: 'new',
      );

      final data = complaint.toFirestore();

      expect(data['userId'], 'user-1');
      expect(data['employeeId'], isEmpty);
      expect(data['employeeName'], 'مجهول');
      expect(data['department'], isEmpty);
      expect(data['isAnonymous'], isTrue);
    });

    test('keeps regular complaint identity and anonymity disabled', () {
      const complaint = ComplaintModel(
        complaintId: 'complaint-2',
        userId: 'user-2',
        employeeId: 'EMP-2',
        employeeName: 'موظف تجريبي',
        department: 'IT',
        title: 'عنوان الشكوى',
        body: 'تفاصيل كافية لاختبار الشكوى العادية',
        status: 'new',
      );

      final data = complaint.toFirestore();

      expect(data['employeeId'], 'EMP-2');
      expect(data['employeeName'], 'موظف تجريبي');
      expect(data['department'], 'IT');
      expect(data['isAnonymous'], isFalse);
    });
  });
}
