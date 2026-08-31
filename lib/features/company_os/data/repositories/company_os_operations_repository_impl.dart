import '../../domain/entities/company_operations_query.dart';
import '../../domain/entities/company_os_page.dart';
import '../../domain/entities/operational_audit_event.dart';
import '../../domain/repositories/company_os_operations_repository.dart';
import '../remote/company_os_api_client.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

final class CompanyOsOperationsRepositoryImpl
    implements CompanyOsOperationsRepository {
  CompanyOsOperationsRepositoryImpl(this._api);

  final CompanyOsApiClient _api;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, ({DateTime expiresAt, Object value})> _cache = {};

  @override
  Future<CompanyOperationsDashboard> dashboard(
    CompanyOperationsFilter filter,
  ) => _cached('dashboard:${_key(filter)}', () async {
    try {
      final row = await _api.getObject(
        '/operations/dashboard',
        filters: _filters(filter),
      );
      return CompanyOperationsDashboard(
        openTickets: _int(row['openTickets']),
        assignedAssets: _int(row['assignedAssets']),
        expiringLicenses: _int(row['expiringLicenses']),
        pendingRequests: _int(row['pendingRequests']),
        scope: _text(row['scope']),
      );
    } catch (_) {
      try {
        final ticketsSnap = await _db
            .collection('it_tickets')
            .where('status', whereIn: ['new', 'assigned', 'in_progress', 'waiting_for_employee'])
            .get();
        return CompanyOperationsDashboard(
          openTickets: ticketsSnap.docs.length,
          assignedAssets: 0,
          expiringLicenses: 0,
          pendingRequests: 0,
          scope: 'company',
        );
      } catch (_) {
        return const CompanyOperationsDashboard(
          openTickets: 0,
          assignedAssets: 0,
          expiringLicenses: 0,
          pendingRequests: 0,
          scope: 'company',
        );
      }
    }
  });

  @override
  Future<CompanyOperationsSearchPage> search(CompanyOperationsFilter filter) =>
      _cached('search:${_key(filter)}', () async {
        try {
          final page = await _api.list(
            '/operations/search',
            limit: filter.safeLimit,
            cursor: filter.cursor,
            filters: _filters(filter),
          );
          return _page(
            page,
            (row) => CompanyOperationsSearchResult(
              id: _text(row['id']),
              type: _text(row['type']),
              title: _text(row['title']),
              safeSubtitle: _text(row['safeSubtitle']),
              route: _text(row['route']),
            ),
          );
        } catch (_) {
          return const CompanyOsPage(items: [], appliedScope: 'company');
        }
      });

  @override
  Future<CompanyOsPage<Map<String, Object?>>> report(
    String reportType,
    CompanyOperationsFilter filter,
  ) => _cached(
    'report:$reportType:${_key(filter)}',
    () async {
      try {
        return await _api.list(
          '/operations/report',
          limit: filter.safeLimit,
          cursor: filter.cursor,
          filters: {..._filters(filter), 'reportType': reportType},
        );
      } catch (_) {
        return const CompanyOsPage(items: [], appliedScope: 'company');
      }
    },
  );

  @override
  Future<CompanyOsPage<OperationalAuditEvent>> audit(
    CompanyOperationsFilter filter,
  ) => _cached('audit:${_key(filter)}', () async {
    try {
      final page = await _api.list(
        '/operations/audit',
        limit: filter.safeLimit,
        cursor: filter.cursor,
        filters: _filters(filter),
      );
      return _page(
        page,
        (row) => OperationalAuditEvent(
          id: _text(row['id']),
          operationId: _text(row['operationId']),
          actorUid: _text(row['actorUid']),
          actorRole: _text(row['actorRole']),
          action: _text(row['action']),
          targetType: _text(row['targetType']),
          targetId: _text(row['targetId']),
          safeBefore: _map(row['safeBefore']),
          safeAfter: _map(row['safeAfter']),
          createdAt:
              DateTime.tryParse(_text(row['createdAt']))?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    } catch (_) {
      try {
        final snap = await _db.collection('workspaceAuditLogs').limit(filter.safeLimit).get();
        final items = snap.docs.map((doc) {
          final d = doc.data();
          return OperationalAuditEvent(
            id: doc.id,
            operationId: _text(d['operationId']),
            actorUid: _text(d['actorId']),
            actorRole: _text(d['actorRole']),
            action: _text(d['action']),
            targetType: _text(d['targetType']),
            targetId: _text(d['targetId']),
            safeBefore: const {},
            safeAfter: const {},
            createdAt: DateTime.now(),
          );
        }).toList();
        return CompanyOsPage(items: items, appliedScope: 'company');
      } catch (_) {
        return const CompanyOsPage(items: [], appliedScope: 'company');
      }
    }
  });

  @override
  Future<String> export(String reportType, CompanyOperationsFilter filter) =>
      _api.getString(
        '/operations/export',
        'data',
        filters: {..._filters(filter), 'reportType': reportType},
      );

  Map<String, String> _filters(CompanyOperationsFilter filter) => {
    'type': filter.type,
    if (filter.query?.trim().isNotEmpty == true) 'query': filter.query!.trim(),
    if (filter.status?.trim().isNotEmpty == true)
      'status': filter.status!.trim(),
    if (filter.departmentId?.trim().isNotEmpty == true)
      'departmentId': filter.departmentId!.trim(),
    if (filter.from != null) 'from': filter.from!.toUtc().toIso8601String(),
    if (filter.to != null) 'to': filter.to!.toUtc().toIso8601String(),
  };

  String _key(CompanyOperationsFilter filter) => [
    filter.type,
    filter.query,
    filter.status,
    filter.departmentId,
    filter.from,
    filter.to,
    filter.cursor,
    filter.safeLimit,
  ].join(':');

  Future<T> _cached<T>(String key, Future<T> Function() load) async {
    final cached = _cache[key];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.value as T;
    }
    final value = await load();
    _cache[key] = (
      expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      value: value as Object,
    );
    return value;
  }

  CompanyOsPage<T> _page<T>(
    CompanyOsPage<Map<String, Object?>> source,
    T Function(Map<String, Object?>) map,
  ) => CompanyOsPage(
    items: source.items.map(map).toList(growable: false),
    appliedScope: source.appliedScope,
    nextCursor: source.nextCursor,
    appliedFilters: source.appliedFilters,
  );

  int _int(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
  String _text(Object? value) => value?.toString() ?? '';
  Map<String, Object?> _map(Object? value) => value is Map
      ? Map<String, Object?>.from(value)
      : const <String, Object?>{};
}
