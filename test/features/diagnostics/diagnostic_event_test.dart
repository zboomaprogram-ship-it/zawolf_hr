import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/diagnostics/domain/entities/diagnostic_event.dart';
import 'package:zawolf_hr/features/diagnostics/domain/entities/diagnostic_report.dart';

void main() {
  test('event strips identity and technical metadata before transport', () {
    final event = DiagnosticEvent.create(
      feature: 'Attendance CheckIn',
      safeCode: 'Temporarily Unavailable',
      release: '1.2.3+4 unsafe',
      occurredAt: DateTime.utc(2026, 8, 23),
      metadata: const {
        'surface': 'home',
        'email': 'employee@example.com',
        'state': 'firestore url=/private',
        'operation': 'submit',
      },
    );
    expect(event.feature, 'attendance_checkin');
    expect(event.safeCode, 'temporarily_unavailable');
    expect(event.metadata, {'surface': 'home', 'operation': 'submit'});
    expect(event.toSafeMap().toString(), isNot(contains('example.com')));
  });

  test('report parses only aggregate fields', () {
    final report = DiagnosticReport.fromSafeMap(const {
      'fingerprint': 'abc',
      'feature': 'request_visibility',
      'safeCode': 'access_denied',
      'release': '7',
      'count': 4,
      'lastSeenAt': '2026-08-23T10:00:00Z',
      'metadata': {'surface': 'requests'},
      'email': 'ignored@example.com',
    });
    expect(report.count, 4);
    expect(report.metadata, {'surface': 'requests'});
  });
}
