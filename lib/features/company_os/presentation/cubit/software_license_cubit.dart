import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/software_license.dart';
import '../../domain/repositories/it_operations_repository.dart';

sealed class SoftwareLicenseState {
  const SoftwareLicenseState();
}

final class SoftwareLicenseLoading extends SoftwareLicenseState {
  const SoftwareLicenseLoading();
}

final class SoftwareLicenseReady extends SoftwareLicenseState {
  const SoftwareLicenseReady(this.items);
  final List<SoftwareLicense> items;
}

final class SoftwareLicenseFailure extends SoftwareLicenseState {
  const SoftwareLicenseFailure(this.message);
  final String message;
}

final class SoftwareLicenseCubit extends Cubit<SoftwareLicenseState> {
  SoftwareLicenseCubit(this._repository)
    : super(const SoftwareLicenseLoading());
  final ItOperationsRepository _repository;
  Future<void> load() async {
    emit(const SoftwareLicenseLoading());
    try {
      emit(SoftwareLicenseReady((await _repository.licenses()).items));
    } catch (_) {
      emit(const SoftwareLicenseFailure('تعذر تحميل تراخيص البرامج.'));
    }
  }
}
