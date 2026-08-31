import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_operations_query.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_page.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/operational_audit_event.dart';
import 'package:zawolf_hr/features/company_os/domain/repositories/company_os_operations_repository.dart';
import 'package:zawolf_hr/features/company_os/presentation/pages/company_operations_dashboard_page.dart';
import 'package:zawolf_hr/features/company_os/presentation/pages/company_os_audit_page.dart';
import 'package:zawolf_hr/features/company_os/presentation/pages/company_os_reports_page.dart';
import 'package:zawolf_hr/features/company_os/presentation/pages/company_os_search_page.dart';

final class _FakeOperationsRepository implements CompanyOsOperationsRepository {
  _FakeOperationsRepository({this.fail = false});
  final bool fail;
  Never _failure() => throw StateError('technical details must stay hidden');

  @override
  Future<CompanyOperationsDashboard> dashboard(
    CompanyOperationsFilter filter,
  ) async {
    if (fail) _failure();
    return const CompanyOperationsDashboard(
      openTickets: 2,
      assignedAssets: 3,
      expiringLicenses: 4,
      pendingRequests: 5,
      scope: 'team',
    );
  }

  @override
  Future<CompanyOperationsSearchPage> search(
    CompanyOperationsFilter filter,
  ) async {
    if (fail) _failure();
    return const CompanyOsPage(items: [], appliedScope: 'team');
  }

  @override
  Future<CompanyOsPage<Map<String, Object?>>> report(
    String reportType,
    CompanyOperationsFilter filter,
  ) async {
    if (fail) _failure();
    return const CompanyOsPage(
      items: [
        {'title': 'تذكرة اختبار', 'safeSubtitle': 'مفتوحة'},
      ],
      appliedScope: 'team',
    );
  }

  @override
  Future<CompanyOsPage<OperationalAuditEvent>> audit(
    CompanyOperationsFilter filter,
  ) async {
    if (fail) _failure();
    return CompanyOsPage(
      items: [
        OperationalAuditEvent(
          id: 'a1',
          operationId: 'op1',
          actorUid: 'u1',
          actorRole: 'manager',
          action: 'تحديث',
          targetType: 'ticket',
          targetId: 't1',
          safeBefore: const {},
          safeAfter: const {},
          createdAt: DateTime(2026),
        ),
      ],
      appliedScope: 'team',
    );
  }

  @override
  Future<String> export(
    String reportType,
    CompanyOperationsFilter filter,
  ) async => 'id,title\n1,test';
}

Widget _app(Widget child, {Size size = const Size(1200, 800)}) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(home: child),
);

void main() {
  testWidgets('dashboard is Arabic RTL and responsive', (tester) async {
    await tester.pumpWidget(
      _app(
        CompanyOperationsDashboardPage(repository: _FakeOperationsRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('مركز عمليات الشركة'), findsOneWidget);
    expect(find.text('تذاكر مفتوحة'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).last)
          .textDirection,
      TextDirection.rtl,
    );
    await tester.binding.setSurfaceSize(const Size(390, 800));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('search shows a safe Arabic empty state', (tester) async {
    await tester.pumpWidget(
      _app(CompanyOsSearchPage(repository: _FakeOperationsRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نتائج ضمن نطاق صلاحياتك.'), findsOneWidget);
    expect(find.text('كلمة البحث'), findsOneWidget);
  });

  testWidgets('reports and audit render server scoped rows', (tester) async {
    await tester.pumpWidget(
      _app(CompanyOsReportsPage(repository: _FakeOperationsRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('تذكرة اختبار'), findsOneWidget);
    await tester.pumpWidget(
      _app(CompanyOsAuditPage(repository: _FakeOperationsRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('تحديث · ticket'), findsOneWidget);
  });

  testWidgets('errors remain Arabic and retryable without backend details', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CompanyOperationsDashboardPage(
          repository: _FakeOperationsRepository(fail: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحميل لوحة العمليات حالياً.'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.textContaining('technical details'), findsNothing);
  });
}
