import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AttendanceGatewayException implements Exception {
  final String code;

  /// Diagnostic text is retained for logs only. Never render it in the UI.
  final String message;

  const AttendanceGatewayException(this.code, this.message);

  String get userMessage => switch (code) {
    'checkout_disabled' =>
      'تسجيل الانصراف غير مفعّل حالياً، ولا يلزم اتخاذ إجراء إضافي.',
    'already_recorded' => 'تم تسجيل حضورك مسبقاً لهذا اليوم.',
    'unauthenticated' => 'انتهت جلسة الدخول. سجل الدخول مرة أخرى.',
    'permission_denied' ||
    'forbidden' => 'لا تملك صلاحية تنفيذ هذا الإجراء. راجع مسؤول النظام.',
    'network' || 'timeout' || 'server_unavailable' || 'unavailable' =>
      'تعذر التأكيد الآن. تم حفظ العملية للمزامنة عند توفر الإنترنت.',
    _ => 'تعذر إتمام الطلب الآن. تحقق من حالة الطلب قبل إعادة الإرسال.',
  };

  @override
  String toString() => userMessage;

  bool get isTemporary =>
      code == 'network' || code == 'timeout' || code == 'server_unavailable';
}

/// Routes attendance writes through the company server. The server validates
/// the Firebase session and writes with Admin SDK, shielding employees from
/// Firestore rule/quota errors while retaining device and audit controls.
class AttendanceGatewayService {
  static const baseUrl = 'https://notification.zawolf.ai';

  final FirebaseAuth _auth;
  final http.Client _client;

  AttendanceGatewayService({FirebaseAuth? auth, http.Client? client})
    : _auth = auth ?? FirebaseAuth.instance,
      _client = client ?? http.Client();

  Future<void> submit(Map<String, dynamic> action) async {
    await _post({'action': action});
  }

  /// Returns the server receipt for the new check-in pilot. Existing callers
  /// continue using [submit], so check-out behavior remains unchanged.
  Future<Map<String, dynamic>> submitWithReceipt(Map<String, dynamic> action) {
    return _post({'action': action});
  }

  /// Resolves only the authenticated employee's canonical check-in record.
  /// This is deliberately event-driven; it is never used as a polling API.
  Future<Map<String, dynamic>> checkInStatus(String attendanceId) {
    return _post({'attendanceId': attendanceId}, path: '/attendance/status');
  }

  /// Reads the server-owned check-out policy. If this request is unavailable,
  /// callers must keep check-out hidden rather than assuming it is enabled.
  Future<Map<String, dynamic>> checkoutPolicy() =>
      _request(path: '/attendance/checkout-policy');

  Future<Map<String, dynamic>> updateCheckoutPolicy({
    required bool enabled,
    required int expectedRevision,
    String? reason,
  }) => _post({
    'enabled': enabled,
    'expectedRevision': expectedRevision,
    if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
  }, path: '/attendance/checkout-policy');

  /// Device ownership is validated and written by the server, never by a
  /// Firestore transaction running on an employee device.
  Future<void> bindDevice({
    required String deviceId,
    required String deviceLabel,
  }) async {
    await _post({
      'action': {
        'type': 'bindDevice',
        'deviceId': deviceId,
        'deviceLabel': deviceLabel,
      },
    });
  }

  Future<Map<String, dynamic>> _post(
    Map<String, dynamic> payload, {
    String path = '/attendance/events',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AttendanceGatewayException(
        'unauthenticated',
        'انتهت جلسة الدخول. سجل الدخول مرة أخرى.',
      );
    }
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const AttendanceGatewayException(
        'unauthenticated',
        'تعذر التحقق من جلسة الدخول.',
      );
    }
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      Map<String, dynamic> body = const {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {}
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AttendanceGatewayException(
          '${body['code'] ?? 'server_unavailable'}',
          '${body['error'] ?? 'تعذر تأكيد الحضور الآن. سيتم إعادة المحاولة تلقائياً.'}',
        );
      }
      return body;
    } on AttendanceGatewayException {
      rethrow;
    } on TimeoutException {
      throw const AttendanceGatewayException(
        'timeout',
        'تعذر تأكيد الحضور الآن. تم حفظه للمزامنة التلقائية.',
      );
    } catch (_) {
      throw const AttendanceGatewayException(
        'network',
        'تعذر تأكيد الحضور الآن. تم حفظه للمزامنة التلقائية.',
      );
    }
  }

  Future<Map<String, dynamic>> _request({required String path}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AttendanceGatewayException(
        'unauthenticated',
        'انتهت جلسة الدخول. سجل الدخول مرة أخرى.',
      );
    }
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const AttendanceGatewayException(
        'unauthenticated',
        'تعذر التحقق من جلسة الدخول.',
      );
    }
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      final body = decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AttendanceGatewayException(
          '${body['code'] ?? 'server_unavailable'}',
          '${body['error'] ?? 'تعذر تحميل حالة الانصراف الآن.'}',
        );
      }
      return body;
    } on AttendanceGatewayException {
      rethrow;
    } on TimeoutException {
      throw const AttendanceGatewayException(
        'timeout',
        'تعذر تحميل حالة الانصراف الآن.',
      );
    } catch (_) {
      throw const AttendanceGatewayException(
        'network',
        'تعذر تحميل حالة الانصراف الآن.',
      );
    }
  }
}
