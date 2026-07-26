import 'package:firebase_auth/firebase_auth.dart';

String userFacingError(
  Object error, {
  String fallback = 'تعذر تنفيذ العملية.',
}) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      'too-many-requests' =>
        'تمت محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى.',
      'network-request-failed' =>
        'تعذر الاتصال بالإنترنت. تحقق من الشبكة ثم أعد المحاولة.',
      'user-disabled' => 'هذا الحساب موقوف. تواصل مع إدارة الموارد البشرية.',
      _ => fallback,
    };
  }

  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'لا تملك صلاحية تنفيذ هذه العملية. حدّث بيانات الحساب ثم أعد المحاولة.',
      'unavailable' || 'deadline-exceeded' =>
        'الخدمة غير متاحة مؤقتاً. تحقق من الإنترنت ثم أعد المحاولة.',
      'failed-precondition' =>
        'تعذر إكمال الطلب بسبب إعداد ناقص. أعد المحاولة أو تواصل مع الإدارة.',
      'resource-exhausted' => 'الخدمة مشغولة حالياً. حاول مرة أخرى بعد قليل.',
      'already-exists' => 'تم تسجيل هذا الطلب بالفعل.',
      'not-found' => 'لم تعد البيانات المطلوبة موجودة.',
      _ => fallback,
    };
  }

  final message = error.toString().replaceFirst('Exception: ', '').trim();
  if (message.isNotEmpty &&
      !message.contains('cloud_firestore/') &&
      !message.contains('firebase_auth/')) {
    return message;
  }
  return fallback;
}
