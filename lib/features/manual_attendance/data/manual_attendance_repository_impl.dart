import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../domain/manual_attendance_repository.dart';

class ManualAttendanceRepositoryImpl implements ManualAttendanceRepository {
  ManualAttendanceRepositoryImpl({
    FirebaseAuth? auth,
    http.Client? client,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _client = client ?? http.Client();

  static const _baseUrl = 'https://notification.zawolf.ai';
  final FirebaseAuth _auth;
  final http.Client _client;
  final Random _random = Random.secure();

  String _operationId() =>
      List.generate(
        32,
        (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_random.nextInt(36)],
      ).join();

  @override
  Future<List<ManualAttendanceEmployee>> findEmployees(String query) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('انتهت الجلسة، سجل الدخول مرة أخرى.');
    }
    final response = await _client.get(
      Uri.parse('$_baseUrl/operations/manual-attendance/employees?query=${Uri.encodeQueryComponent(query)}'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300 || data['ok'] != true) {
      throw StateError('${data['error'] ?? 'تعذر تحميل الموظفين.'}');
    }
    return (data['employees'] as List? ?? const []).whereType<Map>().map((item) {
      final raw = Map<String, dynamic>.from(item);
      return ManualAttendanceEmployee(
        id: '${raw['id'] ?? ''}',
        name: '${raw['name'] ?? 'موظف'}',
        employeeCode: '${raw['employeeCode'] ?? ''}',
        department: '${raw['department'] ?? ''}',
        email: '${raw['email'] ?? ''}',
        isCheckedIn: raw['isCheckedIn'] == true,
        isCheckedOut: raw['isCheckedOut'] == true,
        checkInAt: DateTime.tryParse('${raw['checkInAt'] ?? ''}'),
        checkOutAt: DateTime.tryParse('${raw['checkOutAt'] ?? ''}'),
      );
    }).toList(growable: false);
  }

  @override
  Future<void> record({
    required String employeeId,
    required String eventType,
    required DateTime effectiveAt,
    required String reason,
  }) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('انتهت الجلسة، سجل الدخول مرة أخرى.');
    }
    final response = await _client.post(
      Uri.parse('$_baseUrl/operations/manual-attendance'),
      headers: {
        'content-type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'operationId': _operationId(),
        'employeeId': employeeId,
        'eventType': eventType,
        'effectiveAt': effectiveAt.toIso8601String(),
        'reason': reason,
      }),
    );
    final decoded =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final data =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['ok'] != true) {
      throw StateError('${data['error'] ?? 'تعذر تسجيل الحضور اليدوي.'}');
    }
  }
}
