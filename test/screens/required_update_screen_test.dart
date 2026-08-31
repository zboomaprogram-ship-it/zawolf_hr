import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/screens/required_update_screen.dart';
import 'package:zawolf_hr/services/app_security_policy_service.dart';

void main() {
  testWidgets('shows a recoverable Arabic policy connection state', (tester) async {
    var retries = 0;
    await tester.pumpWidget(RequiredUpdateScreen(
      status: const AppSecurityStatus(
        policy: AppSecurityPolicy(),
        currentBuild: 1,
        version: '1.0.0',
        policyVerified: false,
      ),
      onRetry: () => retries += 1,
    ));
    expect(find.text('تعذر التحقق من الإصدار'), findsOneWidget);
    expect(find.text('إعادة الاتصال'), findsOneWidget);
    await tester.tap(find.text('إعادة الاتصال'));
    expect(retries, 1);
    expect(Directionality.of(tester.element(find.text('إعادة الاتصال'))), TextDirection.rtl);
  });

  testWidgets('shows unsupported release without an unusable update action', (tester) async {
    await tester.pumpWidget(RequiredUpdateScreen(
      status: const AppSecurityStatus(
        policy: AppSecurityPolicy(androidStoreUrl: '', iosStoreUrl: ''),
        currentBuild: 1,
        version: '1.0.0',
        policyVerified: true,
      ),
      onRetry: () {},
    ));
    expect(find.text('هذا الإصدار لم يعد مدعوماً'), findsOneWidget);
    expect(find.text('تحديث التطبيق'), findsNothing);
    expect(find.text('التحقق من توفر إصدار جديد'), findsOneWidget);
  });
}
