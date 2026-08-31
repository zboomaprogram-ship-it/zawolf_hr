import 'company_os_sync_state.dart';

final class CompanyOsOperationReceipt {
  const CompanyOsOperationReceipt({
    required this.operationId,
    required this.status,
    this.resourceId,
    this.version,
    this.safeCode,
  });

  final String operationId;
  final CompanyOsSyncState status;
  final String? resourceId;
  final int? version;
  final String? safeCode;
}
