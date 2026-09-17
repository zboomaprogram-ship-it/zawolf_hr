import 'package:flutter/foundation.dart';
import '../../../core/errors/safe_presentation_message.dart';

enum AttendanceFailureActionType {
  openLocationSettings,
  openAppSettings,
  retry,
  none,
}

/// A structured, presentation-safe diagnostic representation of an attendance
/// failure. Provides a clear Arabic title, actionable explanation, machine-readable
/// diagnostic code, and the recommended user recovery action.
@immutable
class AttendanceFailureDiagnostic {
  final String title;
  final String message;
  final String code;
  final AttendanceFailureActionType actionType;

  const AttendanceFailureDiagnostic({
    required this.title,
    required this.message,
    required this.code,
    this.actionType = AttendanceFailureActionType.none,
  });

  factory AttendanceFailureDiagnostic.fromError(Object error) {
    if (error.runtimeType.toString() == 'AttendanceGatewayException') {
      try {
        final dynamic dyn = error;
        final code = (dyn.code as String?) ?? '';
        final userMessage = (dyn.userMessage as String?) ?? error.toString();
        return _fromGatewayException(code, userMessage);
      } catch (_) {}
    }

    final raw =
        error
            .toString()
            .replaceFirst(
              RegExp(r'^(?:Exception|Bad state|StateError):\s*'),
              '',
            )
            .trim();

    // 1. Location Service Disabled
    if (raw.contains('خدمة الموقع مغلقة') ||
        raw.contains('خدمة الموقع غير متاحة') ||
        raw.contains('LocationServiceDisabledException')) {
      return const AttendanceFailureDiagnostic(
        title: 'خدمة الموقع الجغرافي مغلقة',
        message:
            'خدمة تحديد الموقع (GPS) مغلقة على هاتفك أو المتصفح. يرجى تفعيل الـ GPS ثم إعادة المحاولة.',
        code: 'ERR_GPS_DISABLED',
        actionType: AttendanceFailureActionType.openLocationSettings,
      );
    }

    // 2. Permission Denied Forever
    if (raw.contains('مرفوض نهائياً') ||
        raw.contains('حظر إذن الموقع') ||
        raw.contains('PermissionDeniedForever') ||
        raw.contains('deniedForever')) {
      return const AttendanceFailureDiagnostic(
        title: 'إذن الموقع محظور',
        message:
            'تم حظر إذن الموقع للتطبيق. يرجى فتح إعدادات الهاتف ومنح التطبيق صلاحية الموقع.',
        code: 'ERR_PERMISSION_BLOCKED',
        actionType: AttendanceFailureActionType.openAppSettings,
      );
    }

    // 3. Permission Denied
    if (raw.contains('رفض إذن الموقع') ||
        raw.contains('أذونات الموقع الجغرافي مطلوبة') ||
        raw.contains('PermissionDeniedException')) {
      return const AttendanceFailureDiagnostic(
        title: 'صلاحية الموقع مطلوبة',
        message:
            'تم رفض إذن الوصول إلى الموقع. اسمح للتطبيق باستخدام الموقع لتتمكن من تسجيل الحضور.',
        code: 'ERR_PERMISSION_DENIED',
        actionType: AttendanceFailureActionType.openAppSettings,
      );
    }

    // 4. Approximate Location (Reduced Accuracy)
    if (raw.contains('الموقع التقريبي') || raw.contains('reduced')) {
      return const AttendanceFailureDiagnostic(
        title: 'الموقع الدقيق مطلوب',
        message:
            'الموقع التقريبي مفعّل حالياً. افتح إعدادات التطبيق وفعّل خيار "الموقع الدقيق" (Precise location) للتحقق من نطاق الفرع.',
        code: 'ERR_APPROXIMATE_LOCATION',
        actionType: AttendanceFailureActionType.openAppSettings,
      );
    }

    // 5. Fresh GPS reading unavailable
    if (raw.toLowerCase().contains('تعذر الحصول على قراءة gps حديثة') ||
        raw.contains('تعذر الحصول على قراءة موقع حديثة')) {
      return const AttendanceFailureDiagnostic(
        title: 'تعذر تحديد موقع GPS حديث',
        message:
            'لم يرسل الهاتف قراءة GPS حديثة بعد. فعّل الموقع الدقيق وتحسين دقة الموقع من Google، واضغط إعادة المحاولة.',
        code: 'ERR_GPS_UNAVAILABLE',
        actionType: AttendanceFailureActionType.retry,
      );
    }

    // 6. Poor Accuracy / Weak GPS
    if (raw.contains('دقة القراءة') ||
        raw.contains('دقة الموقع') ||
        raw.contains('ضعف إشارة') ||
        raw.contains('accuracy') ||
        raw.contains('إشارة موقع GPS ضعيفة')) {
      return const AttendanceFailureDiagnostic(
        title: 'إشارة الـ GPS ضعيفة',
        message:
            'إشارة موقعك غير دقيقة حالياً (> 25 متراً). يرجى التواجد في مكان مكشوف والتأكد من تفعيل الموقع عالي الدقة.',
        code: 'ERR_POOR_GPS_ACCURACY',
        actionType: AttendanceFailureActionType.retry,
      );
    }

    // 6. Outside Geofence / Branch Range
    if (raw.contains('خارج نطاق') ||
        raw.contains('outside_geofence') ||
        raw.contains('outside')) {
      return AttendanceFailureDiagnostic(
        title: 'خارج نطاق فرع العمل',
        message:
            raw.contains('المسافة الحالية') || raw.contains('نطاق الفرع')
                ? raw
                : 'أنت حالياً خارج النطاق الجغرافي المسموح به لمقر عملك. يرجى الاقتراب من مقر الفرع ثم إعادة المحاولة.',
        code: 'ERR_OUTSIDE_GEOFENCE',
        actionType: AttendanceFailureActionType.retry,
      );
    }

    // 7. No Branch Assigned
    if (raw.contains('لم يتم تعيين موقع') ||
        raw.contains('لا يوجد موقع حضور نشط مسند') ||
        raw.contains('لم يتم العثور على الفرع المسند') ||
        (raw.contains('location') &&
            (raw.contains('empty') ||
                raw.contains('missing') ||
                raw.contains('تعيين')))) {
      return const AttendanceFailureDiagnostic(
        title: 'لم يُعيّن فرع عمل لحسابك',
        message:
            'لم يتم ربط حسابك بفرع أو موقع عمل نشط في النظام. يرجى التواصل مع إدارة الموارد البشرية لربط فرعك.',
        code: 'ERR_NO_LOCATION_ASSIGNED',
        actionType: AttendanceFailureActionType.none,
      );
    }

    // 8. Mock GPS / Spoofing
    if (raw.contains('Mock GPS') ||
        raw.contains('mock') ||
        raw.contains('تزييف')) {
      return const AttendanceFailureDiagnostic(
        title: 'تم رصد موقع وهمي (Mock GPS)',
        message:
            'تم الكشف عن استخدام تطبيق لتزييف الموقع الجغرافي. لا يمكن تسجيل الحضور أثناء تشغيل برامج التزييف.',
        code: 'ERR_MOCK_LOCATION_DETECTED',
        actionType: AttendanceFailureActionType.none,
      );
    }

    // 9. Developer Options / USB Debugging
    if (raw.contains('خيارات المطور') ||
        raw.contains('developerOptions') ||
        raw.contains('debugging')) {
      return const AttendanceFailureDiagnostic(
        title: 'خيارات المطور مفعلة',
        message:
            'لأمان تسجيل الحضور، يرجى إيقاف خيارات المطور (Developer Options) وتصحيح USB من إعدادات الهاتف.',
        code: 'ERR_DEV_OPTIONS_ENABLED',
        actionType: AttendanceFailureActionType.none,
      );
    }

    // 10. Device Lock Missing
    if (raw.contains('قفل آمن للجهاز') ||
        raw.contains('NotEnrolled') ||
        raw.contains('noCredentialsSet')) {
      return const AttendanceFailureDiagnostic(
        title: 'وسيلة قفل آمنة مطلوبة',
        message:
            'يجب تفعيل وسيلة قفل شاشة آمنة (بصمة أو رمز PIN) في إعدادات هاتفك قبل تسجيل الحضور.',
        code: 'ERR_NO_DEVICE_LOCK',
        actionType: AttendanceFailureActionType.none,
      );
    }

    // 11. Biometric Cancellation or Temporary Lockout
    if (raw.contains('فشل التحقق من هوية الجهاز') ||
        raw.contains('UserCancel') ||
        raw.contains('user_canceled') ||
        raw.contains('auth_in_progress')) {
      return const AttendanceFailureDiagnostic(
        title: 'تم إلغاء تأكيد البصمة',
        message:
            'تم إلغاء التحقق من البصمة أو الوجه. اضغط على الزر مجدداً لإتمام تسجيل الحضور.',
        code: 'ERR_BIOMETRIC_CANCELLED',
        actionType: AttendanceFailureActionType.retry,
      );
    }
    if (raw.contains('LockedOut') || raw.contains('permanently_locked_out')) {
      return const AttendanceFailureDiagnostic(
        title: 'البصمة مقفلة مؤقتاً',
        message:
            'تم إيقاف البصمة مؤقتاً بسبب تكرار المحاولات الخاطئة. افتح قفل الهاتف برمز PIN ثم أعد المحاولة.',
        code: 'ERR_BIOMETRIC_LOCKED',
        actionType: AttendanceFailureActionType.retry,
      );
    }

    // 12. Non-workday
    if (raw.contains('اليوم ليس ضمن أيام عملك')) {
      return const AttendanceFailureDiagnostic(
        title: 'يوم عطلة أسبوعية',
        message:
            'اليوم ليس ضمن أيام عملك المسجلة في النظام. لن يتم احتسابه غياباً أو خصماً.',
        code: 'ERR_SCHEDULE_OFF_DAY',
        actionType: AttendanceFailureActionType.none,
      );
    }

    // 13. Before Check-in Open Time
    if (raw.contains('تسجيل الحضور يفتح من الساعة')) {
      return AttendanceFailureDiagnostic(
        title: 'قبل موعد فتح الحضور',
        message: raw,
        code: 'ERR_BEFORE_CHECKIN_TIME',
        actionType: AttendanceFailureActionType.none,
      );
    }

    // 14. Company Day Off
    if (raw.contains('تسجيل الحضور غير متاح اليوم') ||
        raw.contains('العطلات')) {
      return AttendanceFailureDiagnostic(
        title: 'عطلة رسمية للشركة',
        message: raw,
        code: 'ERR_COMPANY_DAY_OFF',
        actionType: AttendanceFailureActionType.none,
      );
    }

    // 15. Approved Leave
    if (raw.contains('لديك إجازة معتمدة اليوم')) {
      return AttendanceFailureDiagnostic(
        title: 'إجازة معتمدة اليوم',
        message: raw,
        code: 'ERR_APPROVED_LEAVE',
        actionType: AttendanceFailureActionType.none,
      );
    }

    // 16. Before Checkout Time
    if (raw.contains('تسجيل الانصراف يفتح من الساعة')) {
      return AttendanceFailureDiagnostic(
        title: 'قبل موعد فتح الانصراف',
        message: raw,
        code: 'ERR_BEFORE_CHECKOUT_TIME',
        actionType: AttendanceFailureActionType.none,
      );
    }

    // 17. Checkout Expired
    if (raw.contains('انتهت مهلة تسجيل الانصراف')) {
      return AttendanceFailureDiagnostic(
        title: 'انتهت مهلة الانصراف',
        message: raw,
        code: 'ERR_CHECKOUT_EXPIRED',
        actionType: AttendanceFailureActionType.none,
      );
    }

    // 18. Duplicate Record
    if (raw.contains('يوجد تسجيل حضور محفوظ لهذا اليوم') ||
        raw.contains('already_recorded') ||
        raw.contains('تم تسجيل حضورك مسبقاً')) {
      return const AttendanceFailureDiagnostic(
        title: 'حضور مسجل مسبقاً',
        message:
            'تم تسجيل حضورك بالفعل لهذا اليوم. قم بتحديث الصفحة وسيظهر زر الانصراف في موعده.',
        code: 'ERR_ALREADY_CHECKED_IN',
        actionType: AttendanceFailureActionType.none,
      );
    }
    if (raw.contains('لقد قمت بتسجيل الانصراف بالفعل')) {
      return const AttendanceFailureDiagnostic(
        title: 'انصراف مسجل مسبقاً',
        message: 'لقد قمت بتسجيل الانصراف بالفعل لهذا اليوم.',
        code: 'ERR_ALREADY_CHECKED_OUT',
        actionType: AttendanceFailureActionType.none,
      );
    }

    // 19. Location Timeout
    if (raw.contains('TimeoutException') ||
        raw.contains('استغرقت عملية تحديد الموقع')) {
      return const AttendanceFailureDiagnostic(
        title: 'مهلة تحديد الموقع انتهت',
        message:
            'استغرقت عملية التقاط إحداثيات الـ GPS وقتاً أطول من المعتاد. تأكد من تشغيل الموقع والإنترنت وجرّب في مكان مكشوف.',
        code: 'ERR_LOCATION_TIMEOUT',
        actionType: AttendanceFailureActionType.retry,
      );
    }

    // 20. Quota / Network / Firestore details
    if (raw.contains('resource-exhausted') || raw.contains('quota')) {
      return const AttendanceFailureDiagnostic(
        title: 'حفظ محلي مؤقت (الحصة مكتملة)',
        message:
            'تم حفظ حضورك محلياً على الجهاز بنجاح لتجاوز حد الاستخدام اليومي، وستتم المزامنة تلقائياً.',
        code: 'ERR_STORAGE_QUOTA',
        actionType: AttendanceFailureActionType.none,
      );
    }
    if (raw.contains('unavailable') ||
        raw.contains('SocketException') ||
        raw.contains('network') ||
        raw.contains('deadline-exceeded')) {
      return const AttendanceFailureDiagnostic(
        title: 'تعذر الاتصال بالخادم مؤقتاً',
        message:
            'خدمة الحضور مشغولة أو يتعذر الاتصال بالشبكة حالياً. تم حفظ حضورك محلياً وستتم المزامنة فور توفر الإنترنت.',
        code: 'ERR_NETWORK_UNAVAILABLE',
        actionType: AttendanceFailureActionType.retry,
      );
    }

    // 21. Any Safe Arabic Business Message
    final safeArabic = safeArabicBusinessMessage(error);
    if (safeArabic != null) {
      return AttendanceFailureDiagnostic(
        title: 'تنبيه تسجيل الحضور',
        message: safeArabic,
        code: 'ERR_BUSINESS_POLICY',
        actionType: AttendanceFailureActionType.none,
      );
    }

    // 22. Generic Fallback
    return const AttendanceFailureDiagnostic(
      title: 'لم يكتمل تسجيل الحضور',
      message:
          'لم يتم حفظ تسجيل الحضور لهذه المحاولة، ولن يُسجَّل حضور مكرر. تأكد من تشغيل الإنترنت والموقع الدقيق ثم أعد المحاولة. إذا تكرر الأمر، يراجع HR حالة الحساب.',
      code: 'ERR_ATTENDANCE_UNKNOWN',
      actionType: AttendanceFailureActionType.retry,
    );
  }

  static AttendanceFailureDiagnostic _fromGatewayException(
    String code,
    String userMessage,
  ) {
    final title = switch (code) {
      'checkout_disabled' => 'تسجيل الانصراف غير مفعّل',
      'already_recorded' => 'حضور مسجل مسبقاً',
      'unauthenticated' => 'انتهت جلسة الدخول',
      'permission_denied' || 'forbidden' => 'صلاحية غير متوفرة',
      'no_assignment' => 'لم يُعيّن فرع عمل',
      'assignment_changed' => 'تحديث في مواقع العمل',
      'account_inactive' => 'الحساب غير نشط',
      'device_conflict' => 'تعارض في جهاز الحضور',
      'device_mismatch' => 'جهاز الحضور غير مطابق',
      'stale_event' => 'انتهت صلاحية المحاولة',
      'invalid_request' => 'بيانات الحضور غير مكتملة',
      'checkin_missing' => 'لم يتم تسجيل الحضور أولاً',
      'inactive_location' => 'موقع الحضور غير نشط',
      'outside_range' => 'خارج نطاق الفرع',
      'network' ||
      'timeout' ||
      'server_unavailable' ||
      'unavailable' => 'تعذر تأكيد الحضور مؤقتاً',
      _ => 'لم يكتمل تسجيل الحضور',
    };

    final actionType = switch (code) {
      'outside_range' ||
      'network' ||
      'timeout' ||
      'server_unavailable' ||
      'unavailable' => AttendanceFailureActionType.retry,
      _ => AttendanceFailureActionType.none,
    };

    return AttendanceFailureDiagnostic(
      title: title,
      message: userMessage,
      code: 'GW_${code.toUpperCase()}',
      actionType: actionType,
    );
  }
}
