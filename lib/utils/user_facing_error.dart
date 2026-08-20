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

  final message = error.toString().replaceFirst('Exception: ', '').trim();
  if (message.isNotEmpty &&
      !message.contains('cloud_firestore/') &&
      !message.contains('firebase_auth/')) {
    return message;
  }
  return fallback;
}
