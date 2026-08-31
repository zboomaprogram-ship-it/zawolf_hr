import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_operation_receipt.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_page.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_safe_error.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_sync_state.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/employee_portal_summary.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/it_ticket.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/knowledge_article.dart';
import 'package:zawolf_hr/features/company_os/domain/repositories/employee_portal_repository.dart';
import 'package:zawolf_hr/features/company_os/presentation/pages/company_os_portal_page.dart';
import 'package:zawolf_hr/features/company_os/presentation/pages/employee_ticket_page.dart';

void main() {
  testWidgets('portal is Arabic RTL and exposes loading then empty state', (
    tester,
  ) async {
    final summary = Completer<EmployeePortalSummary>();
    final repository = _FakePortalRepository(summaryFuture: summary.future);
    await tester.pumpWidget(_app(CompanyOsPortalPage(repository: repository)));
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('company-os-portal-list'))),
      ),
      TextDirection.rtl,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    summary.complete(
      const EmployeePortalSummary(
        openTicketCount: 0,
        assignedAssetCount: 0,
        pendingRequestCount: 0,
      ),
    );
    await tester.pump();
    expect(
      find.text('لا توجد عناصر تشغيلية تحتاج متابعتك الآن.'),
      findsOneWidget,
    );
    expect(find.text('لم ترسل أي تذكرة بعد.'), findsOneWidget);
  });

  testWidgets('portal failure is safe and retryable', (tester) async {
    final repository = _FakePortalRepository(
      summaryError: StateError('Firebase secret'),
    );
    await tester.pumpWidget(_app(CompanyOsPortalPage(repository: repository)));
    await tester.pump();
    expect(find.textContaining('Firebase'), findsNothing);
    expect(find.text('إعادة المحاولة'), findsWidgets);
  });

  for (final scenario in <({String name, Object result, String expected})>[
    (
      name: 'pending',
      result: const CompanyOsOperationReceipt(
        operationId: 'operation-1',
        status: CompanyOsSyncState.pending,
      ),
      expected: 'بانتظار تأكيد المزامنة',
    ),
    (
      name: 'saved',
      result: const CompanyOsOperationReceipt(
        operationId: 'operation-2',
        status: CompanyOsSyncState.synced,
      ),
      expected: 'تم حفظ التذكرة',
    ),
    (
      name: 'conflict',
      result: const CompanyOsSafeError(
        code: CompanyOsSafeCode.conflict,
        arabicMessage: 'تغيرت البيانات. حدّث الصفحة ثم أعد المحاولة.',
      ),
      expected: 'تغيرت البيانات. حدّث الصفحة ثم أعد المحاولة.',
    ),
    (
      name: 'denied',
      result: const CompanyOsSafeError(
        code: CompanyOsSafeCode.accessDenied,
        arabicMessage: 'لا تتوفر لك صلاحية تنفيذ هذا الإجراء.',
      ),
      expected: 'لا تتوفر لك صلاحية تنفيذ هذا الإجراء.',
    ),
  ]) {
    testWidgets('ticket submit shows safe ${scenario.name} state', (
      tester,
    ) async {
      final repository = _FakePortalRepository(createResult: scenario.result);
      await tester.pumpWidget(_app(EmployeeTicketPage(repository: repository)));
      await tester.enterText(
        find.byKey(const Key('ticket-subject')),
        'حاسوب العمل',
      );
      await tester.enterText(
        find.byKey(const Key('ticket-description')),
        'الجهاز لا يعمل الآن',
      );
      await tester.tap(find.byKey(const Key('ticket-submit')));
      await tester.pump();
      expect(find.text(scenario.expected), findsWidgets);
      expect(find.textContaining('permission-denied'), findsNothing);
    });
  }
}

Widget _app(Widget home) => MaterialApp(theme: ThemeData.dark(), home: home);

final class _FakePortalRepository implements EmployeePortalRepository {
  _FakePortalRepository({
    this.summaryFuture,
    this.summaryError,
    this.createResult,
  });
  final Future<EmployeePortalSummary>? summaryFuture;
  final Object? summaryError;
  final Object? createResult;

  @override
  Future<EmployeePortalSummary> summary() {
    if (summaryError != null) return Future.error(summaryError!);
    return summaryFuture ??
        Future.value(
          const EmployeePortalSummary(
            openTicketCount: 0,
            assignedAssetCount: 0,
            pendingRequestCount: 0,
          ),
        );
  }

  @override
  Future<CompanyOsPage<ItTicket>> ownTickets({
    String? cursor,
    int limit = 25,
  }) async => const CompanyOsPage(items: [], appliedScope: 'self');

  @override
  Future<ItTicket> ticket(String ticketId) => throw UnimplementedError();

  @override
  Future<CompanyOsOperationReceipt> addPublicComment({
    required String ticketId,
    required String operationId,
    required String body,
  }) async => CompanyOsOperationReceipt(
    operationId: operationId,
    status: CompanyOsSyncState.synced,
  );

  @override
  Future<CompanyOsOperationReceipt> createTicket({
    required String operationId,
    required String subject,
    required String description,
    required String category,
    required ItTicketPriority priority,
  }) async {
    if (createResult is CompanyOsSafeError) throw createResult!;
    return createResult as CompanyOsOperationReceipt? ??
        CompanyOsOperationReceipt(
          operationId: operationId,
          status: CompanyOsSyncState.synced,
        );
  }

  @override
  Future<CompanyOsPage<KnowledgeArticle>> knowledge({
    String? query,
    String? cursor,
    int limit = 25,
  }) async => const CompanyOsPage(items: [], appliedScope: 'published');
}
