import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/remote_work/presentation/widgets/remote_policy_effective_time_field.dart';

void main() {
  final value = DateTime(2030, 1, 15, 9, 30);
  Future<void> pump(
    WidgetTester tester,
    ValueChanged<DateTime> onChanged, {
    bool enabled = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: RemotePolicyEffectiveTimeField(
            value: value,
            enabled: enabled,
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );

  testWidgets('policy review shows the saved date, time and local timezone', (
    tester,
  ) async {
    await pump(tester, (_) {});
    expect(find.textContaining('2030-01-15 09:30'), findsOneWidget);
    expect(find.textContaining(value.timeZoneName), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(OutlinedButton))),
      TextDirection.rtl,
    );
  });

  testWidgets('choosing a publication date also requires an explicit time', (
    tester,
  ) async {
    DateTime? selected;
    await pump(tester, (date) => selected = date);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '10');
    await tester.enterText(fields.at(1), '45');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2030, 1, 15, 10, 45));
  });

  testWidgets(
    'cancelling time selection preserves the reviewed effective instant',
    (tester) async {
      DateTime? selected;
      await pump(tester, (date) => selected = date);
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    },
  );
}
