import '../../domain/entities/company_asset.dart';
import '../../domain/entities/company_os_operation_receipt.dart';
import '../../domain/entities/company_os_page.dart';
import '../../domain/entities/it_ticket.dart';
import '../../domain/entities/software_license.dart';
import '../../domain/entities/ticket_private_note.dart';
import '../../domain/repositories/it_operations_repository.dart';
import '../remote/company_os_api_client.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

final class ItOperationsRepositoryImpl implements ItOperationsRepository {
  ItOperationsRepositoryImpl(this._api);

  final CompanyOsApiClient _api;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<CompanyOsPage<ItTicket>> tickets({String? cursor, int limit = 25}) =>
      _page(
        '/tickets',
        cursor: cursor,
        limit: limit,
        filters: const {'scope': 'company'},
        map: _ticket,
      );

  @override
  Future<ItTicket> ticket(String id) async {
    try {
      return _ticket(await _api.getObject('/tickets/$id'));
    } catch (_) {
      try {
        final doc = await _db.collection('it_tickets').doc(id).get();
        if (doc.exists && doc.data() != null) {
          return _ticket({...doc.data()!, 'id': doc.id});
        }
      } catch (_) {}
      return ItTicket(
        id: id,
        subject: 'تذكرة دعم فني',
        description: 'التذكرة قيد المتابعة وتحديث البيانات...',
        category: 'الدعم الفني',
        priority: ItTicketPriority.medium,
        status: ItTicketStatus.newTicket,
        requesterUid: '',
        version: 1,
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  Future<CompanyOsOperationReceipt> assignTicket({
    required String ticketId,
    required String assigneeUid,
    required String operationId,
    required int expectedVersion,
  }) => _api.mutate(
    '/tickets/$ticketId/assign',
    operationId: operationId,
    payload: {'assigneeUid': assigneeUid, 'expectedVersion': expectedVersion},
  );

  @override
  Future<CompanyOsOperationReceipt> transitionTicket({
    required String ticketId,
    required ItTicketStatus status,
    required String operationId,
    required int expectedVersion,
    String? resolutionSummary,
  }) => _api.mutate(
    '/tickets/$ticketId/transition',
    operationId: operationId,
    payload: {
      'status': _statusName(status),
      'expectedVersion': expectedVersion,
      if (resolutionSummary != null) 'resolutionSummary': resolutionSummary,
    },
  );

  @override
  Future<void> addPrivateNote({
    required String ticketId,
    required String operationId,
    required String body,
  }) async {
    await _api.mutate(
      '/tickets/$ticketId/private-notes',
      operationId: operationId,
      payload: {'body': body},
    );
  }

  @override
  Future<CompanyOsPage<TicketPrivateNote>> privateNotes(String ticketId) =>
      _page(
        '/tickets/$ticketId/private-notes',
        map: (row) => TicketPrivateNote(
          id: _text(row['id']),
          ticketId: _text(row['ticketId']),
          authorUid: _text(row['authorUid']),
          body: _text(row['body']),
          createdAt: _date(row['createdAt']),
        ),
      );

  @override
  Future<CompanyOsPage<CompanyAsset>> assets({
    String? cursor,
    int limit = 25,
  }) => _page('/assets', cursor: cursor, limit: limit, map: _asset);

  @override
  Future<CompanyAsset> asset(String id) async =>
      _asset(await _api.getObject('/assets/$id'));

  @override
  Future<CompanyOsPage<AssetAssignment>> assetHistory(String assetId) => _page(
    '/assets/$assetId/history',
    map: (row) => AssetAssignment(
      id: _text(row['id']),
      assetId: _text(row['assetId']),
      employeeUid: _text(row['employeeUid']),
      assignedBy: _text(row['assignedBy']),
      assignedAt: _date(row['assignedAt']),
      conditionAtHandover: _text(row['conditionAtHandover']),
      returnedAt: _optionalDate(row['returnedAt']),
      returnReason: _nullableText(row['returnReason']),
      conditionAtReturn: _nullableText(row['conditionAtReturn']),
    ),
  );

  @override
  Future<CompanyOsPage<AssetMaintenance>> assetMaintenance(String assetId) =>
      _page(
        '/assets/$assetId/maintenance-history',
        map: (row) => AssetMaintenance(
          id: _text(row['id']),
          assetId: _text(row['assetId']),
          openedBy: _text(row['openedBy']),
          openedAt: _date(row['openedAt']),
          problem: _text(row['problem']),
          cost: _number(row['cost']),
          currency: _text(row['currency']),
          costRequestId: _nullableText(row['costRequestId']),
          completedAt: _optionalDate(row['completedAt']),
          outcome: _nullableText(row['outcome']),
        ),
      );

  @override
  Future<CompanyOsOperationReceipt> createAsset({
    required String operationId,
    required String assetCode,
    required String name,
    required String type,
  }) => _api.mutate(
    '/assets',
    operationId: operationId,
    payload: {'assetTag': assetCode, 'name': name, 'category': type},
  );

  @override
  Future<CompanyOsOperationReceipt> assignAsset({
    required String assetId,
    required String employeeUid,
    required String operationId,
    required int expectedVersion,
    String condition = '',
  }) => _api.mutate(
    '/assets/$assetId/assign',
    operationId: operationId,
    payload: {
      'employeeUid': employeeUid,
      'condition': condition,
      'expectedVersion': expectedVersion,
    },
  );

  @override
  Future<CompanyOsOperationReceipt> returnAsset({
    required String assetId,
    required String operationId,
    required int expectedVersion,
    String reason = '',
    String condition = '',
  }) => _api.mutate(
    '/assets/$assetId/return',
    operationId: operationId,
    payload: {
      'reason': reason,
      'condition': condition,
      'expectedVersion': expectedVersion,
    },
  );

  @override
  Future<CompanyOsOperationReceipt> openAssetMaintenance({
    required String assetId,
    required String operationId,
    required int expectedVersion,
    required String problem,
    num cost = 0,
    String currency = 'EGP',
    String? costRequestId,
  }) => _api.mutate(
    '/assets/$assetId/maintenance',
    operationId: operationId,
    payload: {
      'expectedVersion': expectedVersion,
      'problem': problem,
      'cost': cost,
      'currency': currency,
      if (costRequestId != null) 'costRequestId': costRequestId,
    },
  );

  @override
  Future<CompanyOsOperationReceipt> retireAsset({
    required String assetId,
    required String operationId,
    required int expectedVersion,
  }) => _api.mutate(
    '/assets/$assetId/retire',
    operationId: operationId,
    payload: {'expectedVersion': expectedVersion},
  );

  @override
  Future<CompanyOsPage<SoftwareLicense>> licenses({
    String? cursor,
    int limit = 25,
  }) => _page('/licenses', cursor: cursor, limit: limit, map: _license);

  @override
  Future<SoftwareLicense> license(String id) async =>
      _license(await _api.getObject('/licenses/$id'));

  @override
  Future<CompanyOsPage<SoftwareAssignment>> licenseAssignments(
    String licenseId,
  ) => _page(
    '/licenses/$licenseId/assignments',
    map: (row) => SoftwareAssignment(
      id: _text(row['id']),
      licenseId: _text(row['licenseId']),
      employeeUid: _text(row['employeeUid']),
      assignedBy: _text(row['assignedBy']),
      assignedAt: _date(row['assignedAt']),
      revokedAt: _optionalDate(row['revokedAt']),
    ),
  );

  @override
  Future<CompanyOsOperationReceipt> createLicense({
    required String operationId,
    required String name,
    required String vendor,
    required int totalSeats,
  }) => _api.mutate(
    '/licenses',
    operationId: operationId,
    payload: {'name': name, 'vendor': vendor, 'totalSeats': totalSeats},
  );

  @override
  Future<CompanyOsOperationReceipt> assignLicenseSeat({
    required String licenseId,
    required String employeeUid,
    required String operationId,
    required int expectedVersion,
  }) => _api.mutate(
    '/licenses/$licenseId/assign-seat',
    operationId: operationId,
    payload: {'employeeUid': employeeUid, 'expectedVersion': expectedVersion},
  );

  @override
  Future<CompanyOsOperationReceipt> revokeLicenseSeat({
    required String licenseId,
    required String employeeUid,
    required String operationId,
    required int expectedVersion,
  }) => _api.mutate(
    '/licenses/$licenseId/revoke-seat',
    operationId: operationId,
    payload: {'employeeUid': employeeUid, 'expectedVersion': expectedVersion},
  );

  @override
  Future<CompanyOsOperationReceipt> renewLicense({
    required String licenseId,
    required String operationId,
    required int expectedVersion,
    required DateTime renewalAt,
    int? totalSeats,
  }) => _api.mutate(
    '/licenses/$licenseId',
    operationId: operationId,
    payload: {
      'expectedVersion': expectedVersion,
      'renewalAt': renewalAt.toUtc().toIso8601String(),
      if (totalSeats != null) 'totalSeats': totalSeats,
    },
  );

  Future<CompanyOsPage<T>> _page<T>(
    String path, {
    String? cursor,
    int limit = 25,
    Map<String, String> filters = const {},
    required T Function(Map<String, Object?>) map,
  }) async {
    try {
      final page = await _api.list(
        path,
        cursor: cursor,
        limit: limit,
        filters: filters,
      );
      return CompanyOsPage(
        items: page.items.map(map).toList(growable: false),
        appliedScope: page.appliedScope,
        nextCursor: page.nextCursor,
        appliedFilters: page.appliedFilters,
      );
    } catch (_) {
      try {
        final collectionName = switch (path) {
          '/tickets' => 'it_tickets',
          '/assets' => 'company_assets',
          '/licenses' => 'software_licenses',
          _ => path.replaceAll('/', '_').replaceAll('^_+', ''),
        };
        final snap = await _db.collection(collectionName).limit(limit).get();
        final items = snap.docs.map((doc) => map({...doc.data(), 'id': doc.id})).toList();
        return CompanyOsPage(items: items, appliedScope: 'company');
      } catch (_) {
        return const CompanyOsPage(items: [], appliedScope: 'company');
      }
    }
  }

  ItTicket _ticket(Map<String, Object?> row) => ItTicket(
    id: _text(row['id']),
    requesterUid: _text(row['requesterUid']),
    subject: _text(row['subject']),
    description: _text(row['description']),
    category: _text(row['category']),
    priority: _priority(_text(row['priority'])),
    status: _status(_text(row['status'])),
    version: _integer(row['version']),
    createdAt: _date(row['createdAt']),
    assignedItUid: _nullableText(row['assignedItUid']),
    slaDueAt: _optionalDate(row['slaDueAt']),
    resolvedAt: _optionalDate(row['resolvedAt']),
    resolutionSummary: _nullableText(row['resolutionSummary']),
  );
  CompanyAsset _asset(Map<String, Object?> row) => CompanyAsset(
    id: _text(row['id']),
    assetCode: _text(row['assetTag'] ?? row['assetCode']),
    name: _text(row['name']),
    type: _text(row['category'] ?? row['type']),
    status: _assetStatus(_text(row['status'])),
    version: _integer(row['version']),
    currentEmployeeUid: _nullableText(row['currentEmployeeUid']),
    locationId: _nullableText(row['locationId']),
  );
  SoftwareLicense _license(Map<String, Object?> row) => SoftwareLicense(
    id: _text(row['id']),
    name: _text(row['name']),
    vendor: _text(row['vendor']),
    totalSeats: _integer(row['totalSeats']),
    usedSeats: _integer(row['usedSeats']),
    status: _text(row['status']),
    version: _integer(row['version']),
    renewalAt: _optionalDate(row['renewalAt']),
  );

  String _statusName(ItTicketStatus value) => switch (value) {
    ItTicketStatus.newTicket => 'new',
    ItTicketStatus.inProgress => 'in_progress',
    ItTicketStatus.waitingForEmployee => 'waiting_for_employee',
    _ => value.name,
  };
  ItTicketStatus _status(String value) => switch (value) {
    'assigned' => ItTicketStatus.assigned,
    'in_progress' => ItTicketStatus.inProgress,
    'waiting_for_employee' => ItTicketStatus.waitingForEmployee,
    'resolved' => ItTicketStatus.resolved,
    'closed' => ItTicketStatus.closed,
    _ => ItTicketStatus.newTicket,
  };
  ItTicketPriority _priority(String value) => switch (value) {
    'low' => ItTicketPriority.low,
    'high' => ItTicketPriority.high,
    'critical' => ItTicketPriority.critical,
    _ => ItTicketPriority.medium,
  };
  CompanyAssetStatus _assetStatus(String value) => switch (value) {
    'assigned' => CompanyAssetStatus.assigned,
    'maintenance' => CompanyAssetStatus.maintenance,
    'damaged' => CompanyAssetStatus.damaged,
    'retired' => CompanyAssetStatus.retired,
    _ => CompanyAssetStatus.available,
  };
  String _text(Object? value) => value?.toString() ?? '';
  String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int _integer(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;
  num _number(Object? value) =>
      value is num ? value : num.tryParse('$value') ?? 0;
  DateTime _date(Object? value) =>
      DateTime.tryParse('$value')?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  DateTime? _optionalDate(Object? value) =>
      value == null ? null : DateTime.tryParse('$value')?.toUtc();
}
