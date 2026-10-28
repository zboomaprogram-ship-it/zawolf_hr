import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/entities/remote_work_models.dart';

final class RemoteWorkApi {
  RemoteWorkApi({
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

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUri$path').replace(
      queryParameters: query != null && query.isNotEmpty ? query : null,
    );
    final response = await _client.get(uri);
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
      'not_authorized': 'لا تملك صلاحية تنفيذ هذا الإجراء للعمل عن بُعد.',
      'mode_locked': 'لا يمكن التبديل بين الدوام المكتبي والعمل عن بعد في نفس اليوم.',
      'challenge_expired': 'انتهت صلاحية رمز التحقق. أعد المحاولة.',
      'challenge_consumed': 'تم استخدام رمز التحقق بالفعل. أعد إنشاء طلب جديد.',
      'credential_unqualified': 'جهازك غير مؤهل للعمل عن بُعد بمفتاح مرور معتمد من HR.',
      'weekly_allowance_conflict': 'تم استنفاد الأيام المسموح بها للعمل عن بُعد لهذا الأسبوع.',
      'operation_conflict': 'معرّف العملية مرتبط بطلب آخر. أعد المحاولة.',
      'attendance_not_found': 'لم يتم العثور على سجل الحضور المطلوب.',
      'invalid_command': 'نوع الأمر أو البيانات المدخلة غير صحيحة.',
    };
    throw RemoteWorkDomainException(
      response.safeCode,
      messages[response.safeCode] ?? 'تعذر تنفيذ إجراء العمل عن بُعد الآن.',
    );
  }
}
