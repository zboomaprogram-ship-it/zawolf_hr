import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/design_system/components/skeletons.dart';
import 'package:zawolf_hr/theme/theme.dart';

Widget _wrap(Widget child, {double width = 390, double height = 844}) {
  return MaterialApp(
    theme: ZaWolfTheme.darkTheme,
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Skeleton height parity tests (Task C011)', () {
    const viewports = <String, Size>{
      'mobile_390': Size(390, 844),
      'desktop_1024': Size(1024, 768),
    };

    for (final entry in viewports.entries) {
      final name = entry.key;
      final size = entry.value;

      testWidgets('SkeletonEmployeeRow maintains 72px height on $name', (tester) async {
        await tester.pumpWidget(_wrap(const SkeletonEmployeeRow(), width: size.width, height: size.height));
        final finder = find.byType(SkeletonEmployeeRow);
        expect(finder, findsOneWidget);
        final renderSize = tester.getSize(finder);
        expect(renderSize.height, equals(SkeletonEmployeeRow.height));
      });

      testWidgets('SkeletonStatCard maintains 110px height on $name', (tester) async {
        await tester.pumpWidget(_wrap(const SkeletonStatCard(), width: size.width, height: size.height));
        final finder = find.byType(SkeletonStatCard);
        expect(finder, findsOneWidget);
        final renderSize = tester.getSize(finder);
        expect(renderSize.height, equals(SkeletonStatCard.height));
      });

      testWidgets('SkeletonInsightCard maintains 136px height on $name', (tester) async {
        await tester.pumpWidget(_wrap(const SkeletonInsightCard(), width: size.width, height: size.height));
        final finder = find.byType(SkeletonInsightCard);
        expect(finder, findsOneWidget);
        final renderSize = tester.getSize(finder);
        expect(renderSize.height, equals(SkeletonInsightCard.height));
      });

      testWidgets('SkeletonAttendanceRow maintains 68px height on $name', (tester) async {
        await tester.pumpWidget(_wrap(const SkeletonAttendanceRow(), width: size.width, height: size.height));
        final finder = find.byType(SkeletonAttendanceRow);
        expect(finder, findsOneWidget);
        final renderSize = tester.getSize(finder);
        expect(renderSize.height, equals(SkeletonAttendanceRow.height));
      });

      testWidgets('SkeletonTableRows maintains 48px per row on $name', (tester) async {
        const rows = 4;
        await tester.pumpWidget(_wrap(const SkeletonTableRows(rowCount: rows), width: size.width, height: size.height));
        final finder = find.byType(SkeletonTableRows);
        expect(finder, findsOneWidget);
        final renderSize = tester.getSize(finder);
        expect(renderSize.height, equals(SkeletonTableRows.rowHeight * rows));
      });
    }
  });
}
