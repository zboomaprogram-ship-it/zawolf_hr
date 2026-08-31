import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/core/errors/safe_presentation_message.dart';

void main() {
  test('accepts an app-authored Arabic business instruction', () {
    expect(
      safeArabicBusinessMessage(Exception('هذا الحساب مربوط بجهاز حضور آخر.')),
      'هذا الحساب مربوط بجهاز حضور آخر.',
    );
  });

  test('rejects a provider exception even when it contains Arabic text', () {
    expect(
      safeArabicBusinessMessage(
        Exception('cloud_firestore/permission-denied: لا تعرض هذا الخطأ'),
      ),
      isNull,
    );
  });
}
