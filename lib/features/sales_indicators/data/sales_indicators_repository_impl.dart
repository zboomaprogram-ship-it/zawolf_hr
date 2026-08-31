import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/entities/sales_identity_mapping.dart';
import '../domain/entities/sales_indicator_filter.dart';
import '../domain/entities/sales_indicator_snapshot.dart';
import '../domain/repositories/sales_indicators_repository.dart';
import '../../diagnostics/domain/entities/diagnostic_event.dart';
import '../../diagnostics/domain/repositories/diagnostics_repository.dart';

final class SalesIndicatorsRepositoryImpl implements SalesIndicatorsRepository {
  SalesIndicatorsRepositoryImpl({
    required AuthenticatedOperationClient operationClient,
    required Uri operationsBaseUri,
    DiagnosticsRepository? diagnostics,
  }) : _operationClient = operationClient,
       _operationsBaseUri = operationsBaseUri,
       _diagnostics = diagnostics;

  final AuthenticatedOperationClient _operationClient;
  final Uri _operationsBaseUri;
  final DiagnosticsRepository? _diagnostics;

  @override
  Future<SalesIndicatorsResult> load(SalesIndicatorFilter filter) async {
    return _load(filter, allowSync: true);
  }

  Future<SalesIndicatorsResult> _load(
    SalesIndicatorFilter filter, {
    required bool allowSync,
  }) async {
    // The Node gateway receives repeated `sales` and `teleSales` keys.
    // `queryParameters` serializes a Dart List as one literal value, making
    // valid sales data look like an empty/invalid filter.
    final pairs = <String>[
      'startDate=${Uri.encodeQueryComponent(filter.startDate)}',
      'endDate=${Uri.encodeQueryComponent(filter.endDate)}',
      'company=${Uri.encodeQueryComponent(filter.company)}',
      ...filter.sales.map(
        (value) => 'sales=${Uri.encodeQueryComponent(value)}',
      ),
      ...filter.teleSales.map(
        (value) => 'teleSales=${Uri.encodeQueryComponent(value)}',
      ),
      'entryChannel=${Uri.encodeQueryComponent(filter.entryChannel)}',
      'salesTarget=${Uri.encodeQueryComponent('${filter.salesTarget}')}',
      'teleTarget=${Uri.encodeQueryComponent('${filter.teleTarget}')}',
    ];
    final uri = _operationsBaseUri
        .resolve('/operations/sales-indicators')
        .replace(query: pairs.join('&'));
    final response = await _operationClient.get(uri);
    if (response.statusCode == 401 || response.statusCode == 403) {
      return const SalesIndicatorsAccessDenied();
    }
    if (!response.ok) {
      if (allowSync && response.safeCode == 'snapshot_not_ready') {
        final sync = await _operationClient.post(
          _operationsBaseUri.resolve('/operations/sales-indicators/sync'),
          operationId: 'sales-sync-${filter.stableIdentity}',
          body: filter.toMap(),
        );
        if (sync.ok || sync.statusCode == 202) {
          return _load(filter, allowSync: false);
        }
      }
      await _report(response.safeCode, 'load');
      return SalesIndicatorsRetryableFailure(
        response.safeCode == 'snapshot_not_ready'
            ? 'لم تكتمل مزامنة هذه الفلاتر بعد. أعد المحاولة بعد المزامنة.'
            : 'تعذر تحميل مؤشرات المبيعات الآن. أعد المحاولة لاحقاً.',
      );
    }
    final raw = response.data['snapshot'];
    if (raw is! Map) {
      return const SalesIndicatorsRetryableFailure(
        'تعذر التحقق من بيانات مؤشرات المبيعات.',
      );
    }
    return SalesIndicatorsLoaded(_snapshot(Map<String, Object?>.from(raw)));
  }

  @override
  Future<SalesIndicatorsResult> reconcile({
    required SalesIndicatorFilter filter,
    required String providerRole,
    required String providerKey,
    required String employeeUserId,
  }) async {
    final response = await _operationClient.post(
      _operationsBaseUri.resolve('/operations/sales-indicators/mappings'),
      operationId: 'sales-map-${DateTime.now().microsecondsSinceEpoch}',
      body: <String, Object?>{
        'providerRole': providerRole,
        'providerKey': providerKey,
        'employeeUserId': employeeUserId,
      },
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      return const SalesIndicatorsAccessDenied();
    }
    if (!response.ok) {
      await _report(response.safeCode, 'reconcile');
      return const SalesIndicatorsRetryableFailure(
        'تعذر حفظ ربط الموظف. تحقق من الحساب ثم أعد المحاولة.',
      );
    }
    return load(filter);
  }

  SalesIndicatorSnapshot _snapshot(Map<String, Object?> map) {
    final filterMap = Map<String, Object?>.from(
      map['filters'] as Map? ?? const {},
    );
    List<String> strings(Object? value) => value is List
        ? value.map((item) => '$item').toList(growable: false)
        : value == null || '$value' == 'ALL'
        ? const <String>[]
        : <String>['$value'];
    double number(Object? value, double fallback) =>
        value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
    final filter = SalesIndicatorFilter(
      startDate: '${filterMap['startDate'] ?? ''}',
      endDate: '${filterMap['endDate'] ?? ''}',
      company: '${filterMap['company'] ?? 'ALL'}',
      sales: strings(filterMap['sales']),
      teleSales: strings(filterMap['teleSales']),
      entryChannel: '${filterMap['entryChannel'] ?? 'ALL'}',
      salesTarget: number(filterMap['salesTarget'], 20000),
      teleTarget: number(filterMap['teleTarget'], 50),
    );
    final rows = (map['agentSummaries'] as List? ?? const <Object>[])
        .whereType<Map>()
        .map((raw) {
          final row = Map<String, Object?>.from(raw);
          final status = switch ('${row['mappingStatus'] ?? ''}') {
            'mapped' => SalesIdentityMappingStatus.mapped,
            'ambiguous' => SalesIdentityMappingStatus.ambiguous,
            _ => SalesIdentityMappingStatus.unmapped,
          };
          return SalesIdentityMapping(
            providerRole: '${row['kind'] ?? ''}',
            providerKey: '${row['key'] ?? ''}',
            providerEmployeeId: '${row['externalId'] ?? ''}',
            status: status,
            userId: '${row['mappedUserId'] ?? ''}',
            employeeId: '${row['mappedEmployeeId'] ?? ''}',
            employeeName: '${row['mappedEmployeeName'] ?? row['name'] ?? ''}',
            target: number(row['target'], 0),
            actual: number(row['actual'], 0),
            finalKpi: number(row['finalKpi'], 0),
          );
        })
        .toList(growable: false);
    return SalesIndicatorSnapshot(
      snapshotId: '${map['snapshotId'] ?? ''}',
      filterVersion: '${map['filterVersion'] ?? ''}',
      filter: filter,
      sourceHealth: switch ('${map['sourceHealth'] ?? ''}') {
        'healthy' => SalesSourceHealth.healthy,
        'partial' => SalesSourceHealth.partial,
        'stale' => SalesSourceHealth.stale,
        _ => SalesSourceHealth.unavailable,
      },
      generatedAt: DateTime.tryParse(
        '${map['syncedAt'] ?? map['generatedAt'] ?? ''}',
      ),
      rows: rows,
      warningsAr: strings(map['integrationWarnings']),
    );
  }

  Future<void> _report(String safeCode, String operation) async {
    await _diagnostics?.report(
      DiagnosticEvent.create(
        feature: 'sales_indicators',
        safeCode: safeCode,
        release: const String.fromEnvironment(
          'APP_RELEASE',
          defaultValue: 'unknown',
        ),
        occurredAt: DateTime.now(),
        metadata: {'operation': operation, 'surface': 'sales'},
      ),
    );
  }
}
