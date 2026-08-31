import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/company_operations_query.dart';
import '../../domain/entities/company_os_page.dart';
import '../../domain/repositories/company_os_operations_repository.dart';

sealed class CompanyOsReportsState {
  const CompanyOsReportsState();
}

final class CompanyOsReportsLoading extends CompanyOsReportsState {
  const CompanyOsReportsLoading();
}

final class CompanyOsReportsReady extends CompanyOsReportsState {
  const CompanyOsReportsReady(this.page, {this.csv});
  final CompanyOsPage<Map<String, Object?>> page;
  final String? csv;
}

final class CompanyOsReportsFailure extends CompanyOsReportsState {
  const CompanyOsReportsFailure(this.message);
  final String message;
}

final class CompanyOsReportsCubit extends Cubit<CompanyOsReportsState> {
  CompanyOsReportsCubit(this._repository)
    : super(const CompanyOsReportsLoading());
  final CompanyOsOperationsRepository _repository;
  String _type = 'ticket';
  CompanyOperationsFilter _filter = const CompanyOperationsFilter();

  Future<void> load(String type, CompanyOperationsFilter filter) async {
    _type = type;
    _filter = filter;
    emit(const CompanyOsReportsLoading());
    try {
      emit(CompanyOsReportsReady(await _repository.report(type, filter)));
    } catch (_) {
      emit(const CompanyOsReportsFailure('تعذر إنشاء التقرير حالياً.'));
    }
  }

  Future<void> export() async {
    final current = state;
    if (current is! CompanyOsReportsReady) return;
    try {
      emit(
        CompanyOsReportsReady(
          current.page,
          csv: await _repository.export(_type, _filter),
        ),
      );
    } catch (_) {
      emit(const CompanyOsReportsFailure('تعذر تصدير التقرير حالياً.'));
    }
  }
}
