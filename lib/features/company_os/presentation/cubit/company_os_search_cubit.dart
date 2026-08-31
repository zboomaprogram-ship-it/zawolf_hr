import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/company_operations_query.dart';
import '../../domain/repositories/company_os_operations_repository.dart';

sealed class CompanyOsSearchState {
  const CompanyOsSearchState();
}

final class CompanyOsSearchLoading extends CompanyOsSearchState {
  const CompanyOsSearchLoading();
}

final class CompanyOsSearchReady extends CompanyOsSearchState {
  const CompanyOsSearchReady(this.page, this.filter);
  final CompanyOperationsSearchPage page;
  final CompanyOperationsFilter filter;
}

final class CompanyOsSearchFailure extends CompanyOsSearchState {
  const CompanyOsSearchFailure(this.message, this.filter);
  final String message;
  final CompanyOperationsFilter filter;
}

final class CompanyOsSearchCubit extends Cubit<CompanyOsSearchState> {
  CompanyOsSearchCubit(this._repository)
    : super(const CompanyOsSearchLoading());
  final CompanyOsOperationsRepository _repository;

  Future<void> search(CompanyOperationsFilter filter) async {
    emit(const CompanyOsSearchLoading());
    try {
      emit(CompanyOsSearchReady(await _repository.search(filter), filter));
    } catch (_) {
      emit(CompanyOsSearchFailure('تعذر إكمال البحث. أعد المحاولة.', filter));
    }
  }
}
