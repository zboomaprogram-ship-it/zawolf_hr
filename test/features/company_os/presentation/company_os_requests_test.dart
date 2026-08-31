import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_operation_receipt.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_attachment_reference.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_page.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_sync_state.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/financial_ledger_entry.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/payslip_summary.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/unified_operational_request.dart';
import 'package:zawolf_hr/features/company_os/domain/repositories/finance_repository.dart';
import 'package:zawolf_hr/features/company_os/domain/repositories/operational_request_repository.dart';
import 'package:zawolf_hr/features/company_os/presentation/pages/employee_finance_page.dart';
import 'package:zawolf_hr/features/company_os/presentation/pages/operational_request_page.dart';

void main() {
  testWidgets('Arabic request form contains access and cost categories', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OperationalRequestFormPage(repository: _RequestRepository()),
      ),
    );
    expect(find.text('خدمات تقنية وتشغيلية'), findsWidgets);
    expect(find.text('طلب صلاحية أو وصول'), findsOneWidget);
    expect(find.text('المبلغ المطلوب'), findsNothing);
    expect(find.text('إرسال الطلب'), findsOneWidget);
  });

  testWidgets('approval journey renders Finance owner payment and closure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OperationalRequestDetailPage(
          repository: _RequestRepository(),
          requestId: 'request-1',
          canDecide: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('المالية'), findsOneWidget);
    expect(find.textContaining('مالك الشركة'), findsOneWidget);
    expect(find.textContaining('تنفيذ الصرف'), findsOneWidget);
    expect(find.text('موافقة'), findsOneWidget);
  });

  testWidgets('finance page exposes Arabic empty state safely', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: EmployeeFinancePage(repository: _FinanceRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('السجل المالي'), findsOneWidget);
    expect(find.text('لا توجد حركات مالية في هذه الفترة.'), findsOneWidget);
    expect(find.text('لا توجد قسيمة راتب منشورة لهذه الفترة.'), findsOneWidget);
  });

  testWidgets('payment stage exposes dedicated payment completion action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OperationalRequestDetailPage(
          repository: _RequestRepository(paymentPending: true),
          requestId: 'request-1',
          canDecide: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تأكيد تنفيذ الصرف'), findsOneWidget);
    expect(find.text('موافقة'), findsNothing);
  });
}

final class _RequestRepository implements OperationalRequestRepository {
  _RequestRepository({this.paymentPending = false});
  final bool paymentPending;

  late final requestValue = UnifiedOperationalRequest(
    id: 'request-1',
    requesterUid: 'employee-1',
    requestType: 'payment',
    costBearing: true,
    businessReason: 'سداد فاتورة تشغيلية',
    executionDate: DateTime.utc(2026, 8, 24),
    status: OperationalRequestStatus.pending,
    approvalPolicyVersion: 1,
    version: 1,
    amount: 100,
    currency: 'EGP',
    approvalPlan: ApprovalPlan(
      requestId: 'request-1',
      policyVersion: 1,
      createdAt: DateTime.utc(2026, 8, 24),
      stages: [
        ApprovalStage(
          type: ApprovalStageType.manager,
          required: true,
          status: paymentPending ? 'approved' : 'pending',
        ),
        ApprovalStage(
          type: ApprovalStageType.finance,
          required: true,
          status: paymentPending ? 'approved' : 'pending',
        ),
        ApprovalStage(
          type: ApprovalStageType.owner,
          required: true,
          status: paymentPending ? 'approved' : 'pending',
        ),
        const ApprovalStage(type: ApprovalStageType.payment, required: true),
        ApprovalStage(type: ApprovalStageType.closure, required: true),
      ],
    ),
  );

  @override
  Future<CompanyOsPage<UnifiedOperationalRequest>> requests({
    String? cursor,
    int limit = 25,
  }) async => CompanyOsPage(items: [requestValue], appliedScope: 'self');
  @override
  Future<UnifiedOperationalRequest> request(String id) async => requestValue;
  @override
  Future<CompanyOsOperationReceipt> create({
    required String operationId,
    required String requestType,
    required String businessReason,
    required DateTime executionDate,
    num? amount,
    String? currency,
    List<CompanyOsAttachmentReference> attachments = const [],
  }) async => CompanyOsOperationReceipt(
    operationId: operationId,
    status: CompanyOsSyncState.synced,
  );
  @override
  Future<CompanyOsOperationReceipt> decide({
    required String requestId,
    required String operationId,
    required int expectedVersion,
    required bool approved,
    required String reason,
  }) async => CompanyOsOperationReceipt(
    operationId: operationId,
    status: CompanyOsSyncState.synced,
  );
  @override
  Future<CompanyOsOperationReceipt> completePayment({
    required String requestId,
    required String operationId,
    required int expectedVersion,
    required String reference,
  }) async => CompanyOsOperationReceipt(
    operationId: operationId,
    status: CompanyOsSyncState.synced,
  );
  @override
  Future<CompanyOsOperationReceipt> completeClosure({
    required String requestId,
    required String operationId,
    required int expectedVersion,
    required String note,
    bool accessProvisioning = false,
  }) async => CompanyOsOperationReceipt(
    operationId: operationId,
    status: CompanyOsSyncState.synced,
  );
}

final class _FinanceRepository implements FinanceRepository {
  @override
  Future<CompanyOsPage<FinancialLedgerEntry>> ledger({
    required DateTime from,
    required DateTime to,
    String? employeeUid,
    String? cursor,
    int limit = 25,
  }) async => const CompanyOsPage(items: [], appliedScope: 'self');

  @override
  Future<PayslipSummary?> payslip({
    required String period,
    String? employeeUid,
  }) async => null;
}
