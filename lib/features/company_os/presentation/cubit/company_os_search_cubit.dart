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
  int _activeRequestId = 0;

  Future<void> search(CompanyOperationsFilter filter) async {
    final currentRequestId = ++_activeRequestId;
    emit(const CompanyOsSearchLoading());
    try {
      final results = await _repository.search(filter);
      if (isClosed || currentRequestId != _activeRequestId) return;
      emit(CompanyOsSearchReady(results, filter));
    } catch (_) {
      if (isClosed || currentRequestId != _activeRequestId) return;
      emit(CompanyOsSearchFailure('تعذر إكمال البحث. أعد المحاولة.', filter));
    }
  }
}
