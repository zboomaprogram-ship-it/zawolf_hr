import '../../domain/entities/company_os_operation_receipt.dart';
import '../../domain/entities/company_os_attachment_reference.dart';
import '../../domain/entities/company_os_page.dart';
import '../../domain/entities/unified_operational_request.dart';
import '../../domain/repositories/operational_request_repository.dart';
import '../remote/company_os_api_client.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

final class OperationalRequestRepositoryImpl
    implements OperationalRequestRepository {
  OperationalRequestRepositoryImpl(this._api);
  final CompanyOsApiClient _api;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, ({DateTime expiresAt, Object value})> _cache = {};

  @override
  Future<CompanyOsPage<UnifiedOperationalRequest>> requests({
    String? cursor,
    int limit = 25,
  }) async {
    final cacheKey = 'list:$cursor:$limit';
    final cached = _cache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.value as CompanyOsPage<UnifiedOperationalRequest>;
    }
    try {
      final page = await _api.list('/requests', cursor: cursor, limit: limit);
      final result = CompanyOsPage(
        items: page.items.map(_request).toList(growable: false),
        appliedScope: page.appliedScope,
        nextCursor: page.nextCursor,
        appliedFilters: page.appliedFilters,
      );
      _cache[cacheKey] = (
        expiresAt: DateTime.now().add(const Duration(seconds: 30)),
        value: result,
      );
      return result;
    } catch (_) {
      try {
        final snap = await _db
            .collection('administrativeRequests')
            .limit(limit)
            .get();
        final items = snap.docs
            .map((doc) => _request({...doc.data(), 'id': doc.id}))
            .toList();
        return CompanyOsPage(items: items, appliedScope: 'company');
      } catch (_) {
        return const CompanyOsPage(items: [], appliedScope: 'company');
      }
    }
  }

  @override
  Future<UnifiedOperationalRequest> request(String id) async {
    final cacheKey = 'request:$id';
    final cached = _cache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.value as UnifiedOperationalRequest;
    }
    final result = _request(await _api.getObject('/requests/$id'));
    _cache[cacheKey] = (
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      value: result,
    );
    return result;
  }

  @override
  Future<CompanyOsOperationReceipt> create({
    required String operationId,
    required String requestType,
    required String businessReason,
    required DateTime executionDate,
    num? amount,
    String? currency,
    List<CompanyOsAttachmentReference> attachments = const [],
  }) => _mutate(
    '/requests',
    operationId: operationId,
    payload: {
      'requestType': requestType,
      'businessReason': businessReason,
      'executionDate': executionDate.toUtc().toIso8601String(),
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (attachments.isNotEmpty)
        'attachments': attachments
            .map(
              (attachment) => {
                'id': attachment.id,
                'displayName': attachment.displayName,
                'contentType': attachment.contentType,
                'sizeBytes': attachment.sizeBytes,
              },
            )
            .toList(growable: false),
    },
  );

  @override
  Future<CompanyOsOperationReceipt> decide({
    required String requestId,
    required String operationId,
    required int expectedVersion,
    required bool approved,
    required String reason,
  }) => _mutate(
    '/requests/$requestId/decision',
    operationId: operationId,
    payload: {
      'expectedVersion': expectedVersion,
      'approved': approved,
      'reason': reason,
    },
  );

  @override
  Future<CompanyOsOperationReceipt> completePayment({
    required String requestId,
    required String operationId,
    required int expectedVersion,
    required String reference,
  }) => _mutate(
    '/requests/$requestId/payment',
    operationId: operationId,
    payload: {'expectedVersion': expectedVersion, 'reference': reference},
  );

  @override
  Future<CompanyOsOperationReceipt> completeClosure({
    required String requestId,
    required String operationId,
    required int expectedVersion,
    required String note,
    bool accessProvisioning = false,
  }) => _mutate(
    '/requests/$requestId/${accessProvisioning ? 'provisioning' : 'closure'}',
    operationId: operationId,
    payload: {'expectedVersion': expectedVersion, 'note': note},
  );

  Future<CompanyOsOperationReceipt> _mutate(
    String path, {
    required String operationId,
    required Map<String, Object?> payload,
  }) async {
    final result = await _api.mutate(
      path,
      operationId: operationId,
      payload: payload,
    );
    _cache.clear();
    return result;
  }

  UnifiedOperationalRequest _request(Map<String, Object?> row) {
    final rawPlan = row['approvalPlan'];
    final plan = rawPlan is Map
        ? Map<String, Object?>.from(rawPlan)
        : const <String, Object?>{};
    final rawStages = plan['stages'];
    final stages = rawStages is List
        ? rawStages
              .whereType<Map>()
              .map((raw) {
                final stage = Map<String, Object?>.from(raw);
                return ApprovalStage(
                  type: _stageType('${stage['type']}'),
                  required: stage['required'] != false,
                  assigneeUid: _nullable(stage['assigneeUid']),
                  status: '${stage['status'] ?? 'pending'}',
                );
              })
              .toList(growable: false)
        : const <ApprovalStage>[];
    final status = '${row['operationalStatus'] ?? row['status']}';
    return UnifiedOperationalRequest(
      id: '${row['id'] ?? ''}',
      requesterUid: '${row['requesterUid'] ?? row['userId'] ?? ''}',
      requestType: '${row['requestType'] ?? ''}',
      costBearing: row['costBearing'] == true,
      businessReason: '${row['businessReason'] ?? row['notes'] ?? ''}',
      executionDate: _date(row['executionDate']),
      status: _status(status),
      approvalPolicyVersion: _integer(
        row['approvalPolicyVersion'] ?? plan['policyVersion'],
      ),
      version: _integer(row['version']),
      amount: row['amount'] is num
          ? row['amount'] as num
          : num.tryParse('${row['amount']}'),
      currency: _nullable(row['currency']),
      attachments: _attachments(row['attachments']),
      approvalPlan: stages.isEmpty
          ? null
          : ApprovalPlan(
              requestId: '${row['id'] ?? ''}',
              policyVersion: _integer(plan['policyVersion']),
              stages: stages,
              createdAt: _date(plan['createdAt'] ?? row['submittedAt']),
            ),
    );
  }

  List<CompanyOsAttachmentReference> _attachments(Object? value) =>
      value is List
      ? value
            .whereType<Map>()
            .map((raw) {
              final item = Map<String, Object?>.from(raw);
              return CompanyOsAttachmentReference(
                id: '${item['id'] ?? ''}',
                displayName: '${item['displayName'] ?? ''}',
                contentType: '${item['contentType'] ?? ''}',
                sizeBytes: _integer(item['sizeBytes']),
              );
            })
            .where((item) => item.id.isNotEmpty)
            .toList(growable: false)
      : const [];

  ApprovalStageType _stageType(String value) => switch (value) {
    'specialist' => ApprovalStageType.specialist,
    'finance' => ApprovalStageType.finance,
    'owner' => ApprovalStageType.owner,
    'payment' => ApprovalStageType.payment,
    'closure' => ApprovalStageType.closure,
    _ => ApprovalStageType.manager,
  };
  OperationalRequestStatus _status(String value) => switch (value) {
    'approved' => OperationalRequestStatus.approved,
    'rejected' => OperationalRequestStatus.rejected,
    'paid' => OperationalRequestStatus.paid,
    'closed' => OperationalRequestStatus.closed,
    _ => OperationalRequestStatus.pending,
  };
  int _integer(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;
  DateTime _date(Object? value) =>
      DateTime.tryParse('$value')?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  String? _nullable(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
