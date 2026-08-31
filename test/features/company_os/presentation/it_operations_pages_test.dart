import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_asset.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_page.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_operation_receipt.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_safe_error.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_sync_state.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/it_ticket.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/software_license.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/ticket_private_note.dart';
import 'package:zawolf_hr/features/company_os/domain/repositories/it_operations_repository.dart';
import 'package:zawolf_hr/features/company_os/presentation/pages/company_assets_page.dart';
import 'package:zawolf_hr/features/company_os/presentation/pages/asset_detail_page.dart';
import 'package:zawolf_hr/features/company_os/presentation/pages/it_ticket_detail_page.dart';
import 'package:zawolf_hr/features/company_os/presentation/pages/it_ticket_queue_page.dart';
import 'package:zawolf_hr/features/company_os/presentation/pages/software_licenses_page.dart';

void main() {
  testWidgets('IT queue and assets render safe Arabic empty states', (
    tester,
  ) async {
    final repo = _FakeItRepository();
    await tester.pumpWidget(
      MaterialApp(home: ItTicketQueuePage(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('لا توجد تذاكر في قائمة الدعم حالياً.'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(home: CompanyAssetsPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('لا توجد أصول مسجلة حالياً.'), findsOneWidget);
  });

  testWidgets('license capacity is shown without exposing technical errors', (
    tester,
  ) async {
    final repo = _FakeItRepository(
      licensesValue: const [
        SoftwareLicense(
          id: 'l1',
          name: 'برنامج محاسبة',
          vendor: 'Z',
          totalSeats: 1,
          usedSeats: 1,
          status: 'active',
          version: 1,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: SoftwareLicensesPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('المتاح 0 من 1'), findsOneWidget);
    expect(find.byIcon(Icons.block), findsOneWidget);
  });

  testWidgets('asset detail exposes lifecycle actions and retained history', (
    tester,
  ) async {
    final repo = _FakeItRepository(assetValue: _asset());
    await tester.pumpWidget(
      MaterialApp(
        home: AssetDetailPage(repository: repo, assetId: 'a1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تسليم لموظف'), findsOneWidget);
    expect(find.text('فتح صيانة'), findsOneWidget);
    expect(find.text('استبعاد الأصل'), findsOneWidget);
    expect(find.text('لا توجد عمليات تسليم سابقة.'), findsOneWidget);
    expect(find.text('لا توجد عمليات صيانة سابقة.'), findsOneWidget);
  });

  testWidgets('license detail supports seat assignment and renewal', (
    tester,
  ) async {
    final license = _license();
    final repo = _FakeItRepository(licensesValue: [license]);
    await tester.pumpWidget(
      MaterialApp(home: SoftwareLicensesPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('برنامج محاسبة'));
    await tester.pumpAndSettle();
    expect(find.text('إسناد مقعد'), findsOneWidget);
    expect(find.text('تجديد الترخيص'), findsOneWidget);
    expect(find.text('لا توجد مقاعد مسندة حالياً.'), findsOneWidget);
  });

  testWidgets('workflow conflict displays only a safe Arabic message', (
    tester,
  ) async {
    final repo = _FakeItRepository(
      ticketValue: _ticket(),
      transitionFails: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ItTicketDetailPage(repository: repo, ticketId: 't1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('بدء التنفيذ'));
    await tester.pump();
    expect(
      find.text('تعذر حفظ التغيير. حدّث البيانات ثم أعد المحاولة.'),
      findsOneWidget,
    );
    expect(find.textContaining('Firebase'), findsNothing);
  });
}

ItTicket _ticket() => ItTicket(
  id: 't1',
  requesterUid: 'u1',
  subject: 'مشكلة جهاز',
  description: 'تفاصيل المشكلة',
  category: 'hardware',
  priority: ItTicketPriority.medium,
  status: ItTicketStatus.assigned,
  version: 2,
  createdAt: DateTime.utc(2026, 8, 24),
);

CompanyAsset _asset() => const CompanyAsset(
  id: 'a1',
  assetCode: 'AS-1',
  name: 'حاسب محمول',
  type: 'laptop',
  status: CompanyAssetStatus.available,
  version: 1,
);

SoftwareLicense _license() => const SoftwareLicense(
  id: 'l1',
  name: 'برنامج محاسبة',
  vendor: 'Z',
  totalSeats: 3,
  usedSeats: 1,
  status: 'active',
  version: 1,
);

class _FakeItRepository implements ItOperationsRepository {
  _FakeItRepository({
    this.licensesValue = const [],
    this.ticketValue,
    this.transitionFails = false,
    this.assetValue,
  });
  final List<SoftwareLicense> licensesValue;
  final ItTicket? ticketValue;
  final bool transitionFails;
  final CompanyAsset? assetValue;
  @override
  Future<CompanyOsPage<ItTicket>> tickets({
    String? cursor,
    int limit = 25,
  }) async => const CompanyOsPage(items: [], appliedScope: 'company');
  @override
  Future<CompanyOsPage<CompanyAsset>> assets({
    String? cursor,
    int limit = 25,
  }) async => const CompanyOsPage(items: [], appliedScope: 'company');
  @override
  Future<CompanyOsPage<SoftwareLicense>> licenses({
    String? cursor,
    int limit = 25,
  }) async => CompanyOsPage(items: licensesValue, appliedScope: 'company');
  @override
  Future<CompanyAsset> asset(String id) async => assetValue ?? _asset();
  @override
  Future<CompanyOsPage<AssetAssignment>> assetHistory(String assetId) async =>
      const CompanyOsPage(items: [], appliedScope: 'company');
  @override
  Future<CompanyOsPage<AssetMaintenance>> assetMaintenance(
    String assetId,
  ) async => const CompanyOsPage(items: [], appliedScope: 'company');
  @override
  Future<SoftwareLicense> license(String id) async =>
      licensesValue.firstWhere((item) => item.id == id, orElse: _license);
  @override
  Future<CompanyOsPage<SoftwareAssignment>> licenseAssignments(
    String licenseId,
  ) async => const CompanyOsPage(items: [], appliedScope: 'company');
  @override
  Future<ItTicket> ticket(String id) async => ticketValue ?? _ticket();
  @override
  Future<CompanyOsPage<TicketPrivateNote>> privateNotes(
    String ticketId,
  ) async => const CompanyOsPage(items: [], appliedScope: 'it_private');
  @override
  Future<CompanyOsOperationReceipt> transitionTicket({
    required String ticketId,
    required ItTicketStatus status,
    required String operationId,
    required int expectedVersion,
    String? resolutionSummary,
  }) async {
    if (transitionFails) {
      throw const CompanyOsSafeError(
        code: CompanyOsSafeCode.conflict,
        arabicMessage: 'تعارض',
      );
    }
    return CompanyOsOperationReceipt(
      operationId: operationId,
      status: CompanyOsSyncState.synced,
      resourceId: ticketId,
      version: expectedVersion + 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
