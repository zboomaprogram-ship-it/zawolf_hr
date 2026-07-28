import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/screens/privacy_policy_screen.dart';

void main() {
  testWidgets(
    'privacy policy covers sensitive HR data and anonymous complaints',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));

      expect(find.text('سياسة الخصوصية'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('الموقع والحضور'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('الموقع والحضور'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('لا يستلم ZaWolf HR'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.textContaining('لا يستلم ZaWolf HR'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('الشكاوى مجهولة الهوية'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('الشكاوى مجهولة الهوية'), findsOneWidget);
    },
  );

  testWidgets('terms cover attendance integrity and account responsibility', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TermsConditionsScreen()));

    expect(find.text('الشروط والأحكام'), findsOneWidget);
    expect(find.text('الحساب والمسؤولية'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('الحضور والموقع'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('الحضور والموقع'), findsOneWidget);
    expect(find.textContaining('تسجيل حضور شخص آخر'), findsOneWidget);
  });
}
