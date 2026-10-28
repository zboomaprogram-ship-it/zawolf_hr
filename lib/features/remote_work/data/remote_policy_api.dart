import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/entities/remote_policy.dart';

final class RemotePolicyApi {
  RemotePolicyApi({
    AuthenticatedOperationClient? client,
    this.baseUri = const String.fromEnvironment(
      'ATTENDANCE_API_BASE_URL',
      defaultValue: 'https://notification.zawolf.ai',
    ),
  }) : _client =
           client ??
           AuthenticatedOperationClient(
             client: http.Client(),
             tokenProvider:
                 () async => FirebaseAuth.instance.currentUser?.getIdToken(),
           );

  final AuthenticatedOperationClient _client;
  final String baseUri;

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _client.get(Uri.parse('$baseUri$path'));
    return _requireSuccess(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    required String operationId,
    required Map<String, Object?> body,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUri$path'),
      operationId: operationId,
      body: body,
    );
    return _requireSuccess(response);
  }

  Map<String, dynamic> _requireSuccess(
    AuthenticatedOperationResponse response,
  ) {
    if (response.ok) return Map<String, dynamic>.from(response.data);
    const messages = {
      'session_expired': 'انتهت جلسة الدخول. سجل الدخول مرة أخرى.',
      'not_authorized': 'لا تملك صلاحية إدارة سياسة الدوام.',
      'version_conflict':
          'تغيرت السياسة أثناء تعديلك. حدّث المسودة ثم أعد المحاولة.',
      'policy_validation_failed': 'راجع الحقول المحددة في سياسة الدوام.',
      'operation_conflict': 'معرّف العملية مرتبط بطلب آخر. أعد المحاولة.',
      'connection_interrupted':
          'تعذر الاتصال بالخدمة. تحقق من الإنترنت ثم أعد المحاولة.',
      'invalid_effective_date': 'اختر تاريخ نشر صحيحاً في الحاضر أو المستقبل.',
      'policy_review_changed':
          'تغير موعد السريان. احفظ المسودة وأعد مراجعتها قبل النشر.',
      'policy_effective_time_conflict':
          'يوجد إصدار آخر بنفس موعد السريان. اختر موعداً مختلفاً.',
      'draft_not_editable':
          'نُشرت هذه المسودة بالفعل. حدّث السياسة لبدء مسودة جديدة.',
      'credential_unqualified':
          'لم يتم تأهيل طريقة التحقق للعمل عن بُعد بعد. تواصل مع مسؤول النظام.',
    };
    throw RemotePolicyException(
      response.safeCode,
      messages[response.safeCode] ?? 'تعذر تنفيذ إجراء سياسة الدوام الآن.',
    );
  }
}
