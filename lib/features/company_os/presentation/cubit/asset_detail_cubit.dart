import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/company_asset.dart';
import '../../domain/repositories/it_operations_repository.dart';

sealed class AssetDetailState {
  const AssetDetailState();
}

final class AssetDetailLoading extends AssetDetailState {
  const AssetDetailLoading();
}

final class AssetDetailReady extends AssetDetailState {
  const AssetDetailReady({
    required this.asset,
    required this.assignments,
    required this.maintenance,
    this.saving = false,
    this.message,
  });

  final CompanyAsset asset;
  final List<AssetAssignment> assignments;
  final List<AssetMaintenance> maintenance;
  final bool saving;
  final String? message;

  AssetDetailReady copyWith({bool? saving, String? message}) =>
      AssetDetailReady(
        asset: asset,
        assignments: assignments,
        maintenance: maintenance,
        saving: saving ?? this.saving,
        message: message,
      );
}

final class AssetDetailFailure extends AssetDetailState {
  const AssetDetailFailure(this.message);
  final String message;
}

final class AssetDetailCubit extends Cubit<AssetDetailState> {
  AssetDetailCubit(this._repository, this.assetId)
    : super(const AssetDetailLoading());

  final ItOperationsRepository _repository;
  final String assetId;

  Future<void> load() async {
    emit(const AssetDetailLoading());
    try {
      final asset = await _repository.asset(assetId);
      final assignments = await _repository.assetHistory(assetId);
      final maintenance = await _repository.assetMaintenance(assetId);
      emit(
        AssetDetailReady(
          asset: asset,
          assignments: assignments.items,
          maintenance: maintenance.items,
        ),
      );
    } catch (_) {
      emit(const AssetDetailFailure('تعذر تحميل تفاصيل الأصل.'));
    }
  }

  Future<void> assign(String employeeUid, {String condition = ''}) => _save(
    (asset) => _repository.assignAsset(
      assetId: asset.id,
      employeeUid: employeeUid,
      operationId: _operationId('assign'),
      expectedVersion: asset.version,
      condition: condition,
    ),
  );

  Future<void> returnAsset({String reason = '', String condition = ''}) =>
      _save(
        (asset) => _repository.returnAsset(
          assetId: asset.id,
          operationId: _operationId('return'),
          expectedVersion: asset.version,
          reason: reason,
          condition: condition,
        ),
      );

  Future<void> openMaintenance({
    required String problem,
    num cost = 0,
    String? costRequestId,
  }) => _save(
    (asset) => _repository.openAssetMaintenance(
      assetId: asset.id,
      operationId: _operationId('maintenance'),
      expectedVersion: asset.version,
      problem: problem,
      cost: cost,
      costRequestId: costRequestId,
    ),
  );

  Future<void> retire() => _save(
    (asset) => _repository.retireAsset(
      assetId: asset.id,
      operationId: _operationId('retire'),
      expectedVersion: asset.version,
    ),
  );

  Future<void> _save(Future<Object?> Function(CompanyAsset) action) async {
    final current = state;
    if (current is! AssetDetailReady || current.saving) return;
    emit(current.copyWith(saving: true));
    try {
      await action(current.asset);
      await load();
    } catch (_) {
      emit(
        current.copyWith(
          saving: false,
          message: 'تعذر حفظ العملية. حدّث البيانات ثم أعد المحاولة.',
        ),
      );
    }
  }

  String _operationId(String action) =>
      'asset-$action-$assetId-${DateTime.now().microsecondsSinceEpoch}';
}
