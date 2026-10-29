import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/design_system/components/stale_while_refresh.dart';
import 'package:zawolf_hr/theme/theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ZaWolfTheme.darkTheme,
      home: Scaffold(body: child),
    );

void main() {
  group('StaleWhileRefresh (Task C012)', () {
    testWidgets('shows loading placeholder when loading with no data', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StaleWhileRefresh(
            hasData: false,
            isLoading: true,
            loadingPlaceholder: Text('قيد التحميل الهيكلي'),
            child: Text('البيانات الحقيقية'),
          ),
        ),
      );

      expect(find.text('قيد التحميل الهيكلي'), findsOneWidget);
      expect(find.text('البيانات الحقيقية'), findsNothing);
    });

    testWidgets('preserves child content and shows progress bar when refreshing with data', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StaleWhileRefresh(
            hasData: true,
            isRefreshing: true,
            loadingPlaceholder: Text('قيد التحميل الهيكلي'),
            child: Text('البيانات الحقيقية'),
          ),
        ),
      );

      expect(find.text('البيانات الحقيقية'), findsOneWidget);
      expect(find.text('قيد التحميل الهيكلي'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('displays error banner above stale child when refresh fails', (tester) async {
      var retryCalled = false;
      await tester.pumpWidget(
        _wrap(
          StaleWhileRefresh(
            hasData: true,
            errorMessage: 'تعذر تحديث البيانات',
            onRetry: () => retryCalled = true,
            child: const Text('البيانات السابقة'),
          ),
        ),
      );

      expect(find.text('البيانات السابقة'), findsOneWidget);
      expect(find.text('تعذر تحديث البيانات'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      expect(retryCalled, isTrue);
    });
  });
}
