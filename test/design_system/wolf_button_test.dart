import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/components/wolf_button.dart';
import 'package:zawolf_hr/theme/theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ZaWolfTheme.darkTheme,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('WolfButton primary fires tap when enabled', (tester) async {
    var pressed = false;
    await tester.pumpWidget(_wrap(WolfButton(
      onPressed: () => pressed = true,
      text: 'حفظ',
    )));
    await tester.tap(find.text('حفظ'));
    expect(pressed, isTrue);
  });

  testWidgets('WolfButton loading blocks taps', (tester) async {
    await tester.pumpWidget(_wrap(WolfButton(
      onPressed: () {},
      text: 'حفظ',
      loading: true,
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('حفظ'), findsNothing);
    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkWell.onTap, isNull);
  });

  testWidgets('WolfButton disabled renders dimmed and inert', (tester) async {
    var pressed = false;
    await tester.pumpWidget(_wrap(const WolfButton(
      onPressed: null,
      text: 'حفظ',
    )));
    final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacity.opacity, lessThan(1.0));
    await tester.tap(find.text('حفظ'), warnIfMissed: false);
    expect(pressed, isFalse);
  });

  testWidgets('WolfButton ghost variant has no fill decoration',
      (tester) async {
    await tester.pumpWidget(_wrap(const WolfButton(
      onPressed: null,
      text: 'إلغاء',
      variant: WolfButtonVariant.ghost,
    )));
    final container = tester.widget<Container>(find.byType(Container).first);
    expect((container.decoration as BoxDecoration).color, Colors.transparent);
  });
}
