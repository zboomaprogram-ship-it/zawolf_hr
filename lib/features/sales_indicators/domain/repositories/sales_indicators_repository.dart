import '../entities/sales_indicator_filter.dart';
import '../entities/sales_indicator_snapshot.dart';

sealed class SalesIndicatorsResult {
  const SalesIndicatorsResult();
}

final class SalesIndicatorsLoaded extends SalesIndicatorsResult {
  const SalesIndicatorsLoaded(this.snapshot);
  final SalesIndicatorSnapshot snapshot;
}

final class SalesIndicatorsAccessDenied extends SalesIndicatorsResult {
  const SalesIndicatorsAccessDenied();
}

final class SalesIndicatorsRetryableFailure extends SalesIndicatorsResult {
  const SalesIndicatorsRetryableFailure(this.safeMessage);
  final String safeMessage;
}

abstract interface class SalesIndicatorsRepository {
  Future<SalesIndicatorsResult> load(SalesIndicatorFilter filter);

  Future<SalesIndicatorsResult> reconcile({
    required SalesIndicatorFilter filter,
    required String providerRole,
    required String providerKey,
    required String employeeUserId,
  });
}
