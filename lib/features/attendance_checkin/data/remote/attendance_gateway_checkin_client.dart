import '../../../../services/attendance_gateway_service.dart';
import '../../domain/entities/check_in_action.dart';
import '../../domain/entities/check_in_receipt.dart';
import '../../domain/entities/check_in_status_resolution.dart';

abstract interface class AttendanceGatewayCheckInTransport {
  Future<Map<String, Object?>> submit(Map<String, Object?> action);

  Future<Map<String, Object?>> status(String attendanceId);
}

abstract interface class CheckInRemoteClient {
  Future<CheckInReceipt> submit(CheckInAction action);

  Future<CheckInStatusResolution> resolveStatus(CheckInAction action);
}

/// Current company-gateway adapter. A future company API can replace this
/// adapter without changing domain or presentation contracts.
class AttendanceGatewayCheckInClient implements CheckInRemoteClient {
  AttendanceGatewayCheckInClient({AttendanceGatewayCheckInTransport? transport})
    : _transport = transport ?? _GatewayTransport();

  final AttendanceGatewayCheckInTransport _transport;

  @override
  Future<CheckInReceipt> submit(CheckInAction action) async {
    final response = await _transport.submit(action.payload);
    final attendanceId = response['attendanceId'];
    final status = response['status'];
    if (attendanceId is! String || attendanceId != action.actionId) {
      throw const AttendanceGatewayException(
        'invalid_receipt',
        'تعذر تأكيد تسجيل الحضور الآن.',
      );
    }
    return CheckInReceipt(
      attendanceId: attendanceId,
      status: status == 'already_recorded'
          ? CheckInReceiptStatus.alreadyRecorded
          : status == 'recorded'
          ? CheckInReceiptStatus.recorded
          : throw const AttendanceGatewayException(
              'invalid_receipt',
              'تعذر تأكيد تسجيل الحضور الآن.',
            ),
    );
  }

  @override
  Future<CheckInStatusResolution> resolveStatus(CheckInAction action) async {
    final response = await _transport.status(action.actionId);
    return switch (response['status']) {
      'recorded' || 'already_recorded' => CheckInStatusResolution.recorded,
      'not_recorded' => CheckInStatusResolution.notRecorded,
      _ => CheckInStatusResolution.unavailable,
    };
  }
}

class _GatewayTransport implements AttendanceGatewayCheckInTransport {
  _GatewayTransport({AttendanceGatewayService? gateway})
    : _gateway = gateway ?? AttendanceGatewayService();

  final AttendanceGatewayService _gateway;

  @override
  Future<Map<String, Object?>> submit(Map<String, Object?> action) async {
    final response = await _gateway.submitWithReceipt(
      Map<String, dynamic>.from(action),
    );
    return Map<String, Object?>.from(response);
  }

  @override
  Future<Map<String, Object?>> status(String attendanceId) async {
    final response = await _gateway.checkInStatus(attendanceId);
    return Map<String, Object?>.from(response);
  }
}
