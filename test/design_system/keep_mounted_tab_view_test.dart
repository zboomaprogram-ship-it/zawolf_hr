import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/design_system/components/keep_mounted_tab_view.dart';
import 'package:zawolf_hr/theme/theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ZaWolfTheme.darkTheme,
      home: Scaffold(body: child),
    );

void main() {
  group('KeepMountedTabItem & KeepMountedTabBarView (Task C013)', () {
    testWidgets('builds tab lazily and keeps state alive when switching tabs', (tester) async {
      var tab1BuildCount = 0;
      var tab2BuildCount = 0;

      await tester.pumpWidget(
        _wrap(
          DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'التبويب الأول'),
                    Tab(text: 'التبويب الثاني'),
                  ],
                ),
                Expanded(
                  child: KeepMountedTabBarView(
                    builders: [
                      (context) {
                        tab1BuildCount++;
                        return const Center(child: Text('محتوى 1'));
                      },
                      (context) {
                        tab2BuildCount++;
                        return const Center(child: Text('محتوى 2'));
                      },
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Tab 1 is initially built; Tab 2 is not built yet
      expect(find.text('محتوى 1'), findsOneWidget);
      expect(tab1BuildCount, equals(1));
      expect(tab2BuildCount, equals(0));

      // Switch to Tab 2
      await tester.tap(find.text('التبويب الثاني'));
      await tester.pumpAndSettle();

      expect(find.text('محتوى 2'), findsOneWidget);
      expect(tab2BuildCount, equals(1));

      // Switch back to Tab 1 - should reuse cached child without rebuilding
      await tester.tap(find.text('التبويب الأول'));
      await tester.pumpAndSettle();

      expect(find.text('محتوى 1'), findsOneWidget);
      expect(tab1BuildCount, equals(1));
    });
  });
}
