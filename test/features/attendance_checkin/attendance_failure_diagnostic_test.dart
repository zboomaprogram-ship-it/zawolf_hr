import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/attendance_checkin/presentation/attendance_failure_diagnostic.dart';
import 'package:zawolf_hr/services/attendance_gateway_service.dart';

void main() {
  group('AttendanceFailureDiagnostic Tests', () {
    test('identifies GPS service disabled with action to open location settings', () {
      final diag = AttendanceFailureDiagnostic.fromError(
        Exception('خدمة الموقع مغلقة. فعّل GPS / Location من إعدادات الهاتف ثم اضغط تحديث الموقع.'),
      );

      expect(diag.code, 'ERR_GPS_DISABLED');
      expect(diag.title, contains('خدمة الموقع'));
      expect(diag.message, contains('GPS'));
      expect(diag.actionType, AttendanceFailureActionType.openLocationSettings);
    });

    test('identifies permission denied forever with action to open app settings', () {
      final diag = AttendanceFailureDiagnostic.fromError(
        Exception('إذن الموقع مرفوض نهائياً. افتح إعدادات التطبيق وفعّل صلاحية الموقع.'),
      );

      expect(diag.code, 'ERR_PERMISSION_BLOCKED');
      expect(diag.title, contains('محظور'));
      expect(diag.actionType, AttendanceFailureActionType.openAppSettings);
    });

    test('identifies approximate location warning', () {
      final diag = AttendanceFailureDiagnostic.fromError(
        Exception('الموقع التقريبي مفعّل. افتح إعدادات التطبيق وفعّل الموقع الدقيق (Precise location).'),
      );

      expect(diag.code, 'ERR_APPROXIMATE_LOCATION');
      expect(diag.title, contains('الموقع الدقيق مطلوب'));
      expect(diag.actionType, AttendanceFailureActionType.openAppSettings);
    });

    test('identifies outside geofence with detailed distance info', () {
      final diag = AttendanceFailureDiagnostic.fromError(
        Exception('أنت خارج نطاق العمل المسموح به لفرع (المعادي).\nالمسافة الحالية: 320 متر.\nنطاق الفرع: 50 متر.'),
      );

      expect(diag.code, 'ERR_OUTSIDE_GEOFENCE');
      expect(diag.title, contains('خارج نطاق فرع العمل'));
      expect(diag.message, contains('320 متر'));
      expect(diag.actionType, AttendanceFailureActionType.retry);
    });

    test('identifies biometric user cancellation', () {
      final diag = AttendanceFailureDiagnostic.fromError(
        Exception('فشل التحقق من هوية الجهاز.'),
      );

      expect(diag.code, 'ERR_BIOMETRIC_CANCELLED');
      expect(diag.title, contains('إلغاء'));
      expect(diag.actionType, AttendanceFailureActionType.retry);
    });

    test('identifies biometric temporary lockout', () {
      final diag = AttendanceFailureDiagnostic.fromError(
        Exception('خطأ في المصادقة: PlatformException(LockedOut, Too many attempts, null, null)'),
      );

      expect(diag.code, 'ERR_BIOMETRIC_LOCKED');
      expect(diag.title, contains('مقفلة'));
      expect(diag.actionType, AttendanceFailureActionType.retry);
    });

    test('identifies developer options enabled on Android', () {
      final diag = AttendanceFailureDiagnostic.fromError(
        Exception('لأمان الحضور، أوقف خيارات المطور وUSB debugging ثم أعد تشغيل التطبيق.'),
      );

      expect(diag.code, 'ERR_DEV_OPTIONS_ENABLED');
      expect(diag.title, contains('خيارات المطور'));
      expect(diag.actionType, AttendanceFailureActionType.none);
    });

    test('identifies non-workday according to schedule', () {
      final diag = AttendanceFailureDiagnostic.fromError(
        Exception('اليوم ليس ضمن أيام عملك المسجلة. لن يتم احتسابه غياباً أو خصماً.'),
      );

      expect(diag.code, 'ERR_SCHEDULE_OFF_DAY');
      expect(diag.title, contains('عطلة أسبوعية'));
    });

    test('identifies AttendanceGatewayException codes with structured codes', () {
      const error = AttendanceGatewayException('device_mismatch', 'diagnostic msg');
      final diag = AttendanceFailureDiagnostic.fromError(error);

      expect(diag.code, 'GW_DEVICE_MISMATCH');
      expect(diag.title, contains('غير مطابق'));
      expect(diag.message, contains('جهاز حضور آخر'));
    });
  });
}
