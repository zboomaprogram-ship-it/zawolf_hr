import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/request_staffing_alerts/domain/request_staffing_conflict.dart';

void main() {
  test('normalizes job titles without treating blank titles as a match', () {
    expect(normalizeStaffingJobTitle('  Senior   Designer '), 'senior designer');
    expect(normalizeStaffingJobTitle(''), isEmpty);
  });
}
