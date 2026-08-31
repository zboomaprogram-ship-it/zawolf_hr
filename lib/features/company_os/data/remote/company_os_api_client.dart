import '../../../../core/sync/authenticated_operation_client.dart';
import '../../domain/entities/company_os_operation_receipt.dart';
import '../../domain/entities/company_os_page.dart';
import '../../domain/entities/company_os_safe_error.dart';
import '../../domain/entities/company_os_sync_state.dart';

final class CompanyOsApiClient {
  CompanyOsApiClient({
    required Uri baseUri,
    required AuthenticatedOperationClient client,
  }) : _baseUri = baseUri,
       _client = client;

  final Uri _baseUri;
  final AuthenticatedOperationClient _client;

  Future<CompanyOsOperationReceipt> mutate(
    String path, {
    required String operationId,
    Map<String, Object?> payload = const {},
  }) async {
    final response = await _client.post(
      _resolve(path),
      operationId: operationId,
      body: payload,
    );
    if (!response.ok) throw _safeError(response.safeCode);
    final data = response.data;
    return CompanyOsOperationReceipt(
      operationId: _requiredString(data, 'operationId'),
      status: _syncState(data['status']),
      resourceId: _optionalString(data['resourceId']),
      version: _optionalInt(data['version']),
      safeCode: _optionalString(data['safeCode']),
    );
  }

  Future<Map<String, Object?>> postObject(
    String path, {
    required String operationId,
    Map<String, Object?> payload = const {},
  }) async {
    final response = await _client.post(
      _resolve(path),
      operationId: operationId,
      body: payload,
    );
    if (!response.ok) throw _safeError(response.safeCode);
    return Map<String, Object?>.from(response.data);
  }

  Future<CompanyOsPage<Map<String, Object?>>> list(
    String path, {
    int limit = 25,
    String? cursor,
    Map<String, String> filters = const {},
  }) async {
    if (!const {10, 25, 50, 100}.contains(limit)) {
      throw ArgumentError.value(limit, 'limit', 'must be 10, 25, 50, or 100');
    }
    final uri = _resolve(path).replace(
      queryParameters: {
        ..._resolve(path).queryParameters,
        ...filters,
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final response = await _client.get(uri);
    if (!response.ok) throw _safeError(response.safeCode);
    final rawItems = response.data['items'];
    if (rawItems is! List) throw _safeError('unexpected');
    final items = rawItems
        .map((item) {
          if (item is! Map) throw _safeError('unexpected');
          return Map<String, Object?>.from(item);
        })
        .toList(growable: false);
    return CompanyOsPage(
      items: items,
      appliedScope: _requiredString(response.data, 'appliedScope'),
      nextCursor: _optionalString(response.data['nextCursor']),
      appliedFilters: response.data['appliedFilters'] is Map
          ? Map<String, Object?>.from(response.data['appliedFilters'] as Map)
          : const {},
    );
  }

  Future<Map<String, Object?>?> getOptionalObject(
    String path, {
    Map<String, String> filters = const {},
  }) async {
    final resolved = _resolve(path);
    final response = await _client.get(
      resolved.replace(
        queryParameters: {...resolved.queryParameters, ...filters},
      ),
    );
    if (!response.ok) throw _safeError(response.safeCode);
    final raw = response.data['data'];
    if (raw == null) return null;
    if (raw is! Map) throw _safeError('unexpected');
    return Map<String, Object?>.from(raw);
  }

  Future<Map<String, Object?>> getEnvelope(
    String path, {
    Map<String, String> filters = const {},
  }) async {
    final resolved = _resolve(path);
    final response = await _client.get(
      resolved.replace(
        queryParameters: {...resolved.queryParameters, ...filters},
      ),
    );
    if (!response.ok) throw _safeError(response.safeCode);
    return Map<String, Object?>.from(response.data);
  }

  Future<Map<String, Object?>> getObject(
    String path, {
    Map<String, String> filters = const {},
  }) async =>
      (await getOptionalObject(path, filters: filters)) ??
      (throw _safeError('unexpected'));

  Future<String> getString(
    String path,
    String key, {
    Map<String, String> filters = const {},
  }) async {
    final resolved = _resolve(path);
    final response = await _client.get(
      resolved.replace(
        queryParameters: {...resolved.queryParameters, ...filters},
      ),
    );
    if (!response.ok) throw _safeError(response.safeCode);
    final value = response.data[key];
    if (value is! String) throw _safeError('unexpected');
    return value;
  }

  Uri _resolve(String path) =>
      _baseUri.resolve(path.replaceFirst(RegExp(r'^/'), ''));

  String _requiredString(Map<String, Object?> data, String key) {
    final value = _optionalString(data[key]);
    if (value == null) throw _safeError('unexpected');
    return value;
  }

  String? _optionalString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int? _optionalInt(Object? value) =>
      value is int ? value : int.tryParse('$value');

  CompanyOsSyncState _syncState(Object? value) => switch ('$value') {
    'saved' || 'synced' => CompanyOsSyncState.synced,
    'pending' => CompanyOsSyncState.pending,
    'conflict' => CompanyOsSyncState.conflict,
    'status_check_required' => CompanyOsSyncState.needsStatusCheck,
    _ => throw _safeError('unexpected'),
  };

  CompanyOsSafeError _safeError(String code) {
    final normalized = code.toLowerCase();
    return switch (normalized) {
      'access_denied' || 'not_authorized' => const CompanyOsSafeError(
        code: CompanyOsSafeCode.accessDenied,
        arabicMessage: 'لا تتوفر لك صلاحية تنفيذ هذا الإجراء.',
      ),
      'invalid_input' => const CompanyOsSafeError(
        code: CompanyOsSafeCode.invalidInput,
        arabicMessage: 'تحقق من البيانات المدخلة ثم أعد المحاولة.',
      ),
      'conflict' => const CompanyOsSafeError(
        code: CompanyOsSafeCode.conflict,
        arabicMessage: 'تغيرت البيانات. حدّث الصفحة ثم أعد المحاولة.',
      ),
      'capacity_reached' => const CompanyOsSafeError(
        code: CompanyOsSafeCode.capacityReached,
        arabicMessage: 'لا توجد سعة متاحة لهذا الإجراء.',
      ),
      'status_check_required' => const CompanyOsSafeError(
        code: CompanyOsSafeCode.statusCheckRequired,
        arabicMessage: 'تحقق من حالة الطلب قبل إعادة الإرسال.',
        retryable: true,
      ),
      'session_expired' || 'unauthenticated' => const CompanyOsSafeError(
        code: CompanyOsSafeCode.sessionExpired,
        arabicMessage: 'انتهت جلسة الدخول. سجل الدخول مرة أخرى.',
      ),
      'rate_limited' => const CompanyOsSafeError(
        code: CompanyOsSafeCode.temporaryUnavailable,
        arabicMessage: 'تم إرسال محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة.',
        retryable: true,
      ),
      _ => const CompanyOsSafeError(
        code: CompanyOsSafeCode.temporaryUnavailable,
        arabicMessage: 'الخدمة غير متاحة مؤقتاً. أعد المحاولة بعد لحظات.',
        retryable: true,
      ),
    };
  }
}
