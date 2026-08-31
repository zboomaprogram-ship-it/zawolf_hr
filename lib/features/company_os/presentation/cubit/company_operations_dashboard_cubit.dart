import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/company_operations_query.dart';
import '../../domain/repositories/company_os_operations_repository.dart';

sealed class CompanyOperationsDashboardState {
  const CompanyOperationsDashboardState();
}

final class CompanyOperationsDashboardLoading
    extends CompanyOperationsDashboardState {
  const CompanyOperationsDashboardLoading();
}

final class CompanyOperationsDashboardReady
    extends CompanyOperationsDashboardState {
  const CompanyOperationsDashboardReady(this.value);
  final CompanyOperationsDashboard value;
}

final class CompanyOperationsDashboardFailure
    extends CompanyOperationsDashboardState {
  const CompanyOperationsDashboardFailure(this.message);
  final String message;
}

final class CompanyOperationsDashboardCubit
    extends Cubit<CompanyOperationsDashboardState> {
  CompanyOperationsDashboardCubit(this._repository)
    : super(const CompanyOperationsDashboardLoading());
  final CompanyOsOperationsRepository _repository;

  Future<void> load([
    CompanyOperationsFilter filter = const CompanyOperationsFilter(),
  ]) async {
    emit(const CompanyOperationsDashboardLoading());
    try {
      emit(
        CompanyOperationsDashboardReady(await _repository.dashboard(filter)),
      );
    } catch (_) {
      emit(
        const CompanyOperationsDashboardFailure(
          'تعذر تحميل لوحة العمليات حالياً.',
        ),
      );
    }
  }
}
