import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/sync/authenticated_operation_client.dart';

/// HR-only password reset through the server-side Firebase Admin SDK.
/// This request never carries or receives a password; the server selects it.
final class HrPasswordResetService {
  HrPasswordResetService({http.Client? client})
    : _client = client ?? http.Client();

  static final instance = HrPasswordResetService();
  static final Uri _endpoint = Uri.parse(
    'https://notification.zawolf.ai/operations/employee-password-reset',
  );

  final http.Client _client;

  Future<void> resetToCompanyDefault({required String employeeUserId}) async {
    final targetId = employeeUserId.trim();
    if (targetId.isEmpty) throw ArgumentError.value(employeeUserId);
    final response = await AuthenticatedOperationClient(
      client: _client,
      tokenProvider:
          () async => await FirebaseAuth.instance.currentUser?.getIdToken(true),
    ).post(
      _endpoint,
      operationId:
          'hr-password-reset-$targetId-${DateTime.now().microsecondsSinceEpoch}',
      body: {'employeeUserId': targetId},
    );
    if (!response.ok) throw HrPasswordResetException(response.safeCode);
  }
}

final class HrPasswordResetException implements Exception {
  const HrPasswordResetException(this.code);

  final String code;
}
