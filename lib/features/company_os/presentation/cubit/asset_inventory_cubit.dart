import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/company_asset.dart';
import '../../domain/repositories/it_operations_repository.dart';

sealed class AssetInventoryState {
  const AssetInventoryState();
}

final class AssetInventoryLoading extends AssetInventoryState {
  const AssetInventoryLoading();
}

final class AssetInventoryReady extends AssetInventoryState {
  const AssetInventoryReady(this.items);
  final List<CompanyAsset> items;
}

final class AssetInventoryFailure extends AssetInventoryState {
  const AssetInventoryFailure(this.message);
  final String message;
}

final class AssetInventoryCubit extends Cubit<AssetInventoryState> {
  AssetInventoryCubit(this._repository) : super(const AssetInventoryLoading());
  final ItOperationsRepository _repository;
  Future<void> load() async {
    emit(const AssetInventoryLoading());
    try {
      emit(AssetInventoryReady((await _repository.assets()).items));
    } catch (_) {
      emit(const AssetInventoryFailure('تعذر تحميل سجل الأصول.'));
    }
  }
}
