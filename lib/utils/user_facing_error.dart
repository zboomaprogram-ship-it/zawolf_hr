import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

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
        'تعذر حفظ الطلب بسبب صلاحيات الحساب. أغلق الشاشة وافتحها مرة أخرى، وإن استمرت المشكلة تواصل مع HR.',
      'unavailable' ||
      'deadline-exceeded' ||
      'cancelled' ||
      'aborted' => 'لم يتم حفظ الطلب. تحقق من الإنترنت ثم حاول مرة أخرى.',
      'failed-precondition' =>
        'يحتاج إعداد النظام إلى تحديث لإكمال هذا الطلب. أرسل صورة الخطأ إلى HR.',
      'resource-exhausted' =>
        'تم الوصول إلى حد استخدام الخدمة مؤقتاً. لم يتم حفظ الطلب؛ حاول لاحقاً.',
      'already-exists' => 'تم تسجيل هذا الطلب بالفعل.',
      'not-found' => 'لم تعد البيانات المطلوبة موجودة.',
      'unauthenticated' => 'انتهت جلسة الدخول. سجل الدخول مرة أخرى.',
      'invalid-argument' =>
        'بعض بيانات الطلب غير صحيحة. راجع التواريخ والوقت والسبب.',
      _ => fallback,
    };
  }

  if (error is http.ClientException ||
      error is TimeoutException ||
      error.toString().contains('Failed to fetch')) {
    return 'تعذر الاتصال بالخدمة مؤقتاً. لم يتم تنفيذ أي تعديل؛ تحقق من الإنترنت ثم أعد المحاولة.';
  }

  final message = _safeArabicBusinessMessage(error);
  if (message != null) {
    return message;
  }
  return fallback;
}

/// Legacy screens still use this utility directly. Keep the safety boundary
/// here rather than coupling older presentation code to the new core layer.
String? _safeArabicBusinessMessage(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '').trim();
  if (message.isEmpty || !RegExp(r'[\u0600-\u06FF]').hasMatch(message)) {
    return null;
  }

  const unsafeFragments = <String>[
    'cloud_firestore',
    'firebase_auth',
    'firebase',
    'permission-denied',
    'unavailable',
    'failed-precondition',
    'http',
    'exception',
    'stack trace',
    'typeerror',
  ];
  final normalized = message.toLowerCase();
  return unsafeFragments.any(normalized.contains) ? null : message;
}
