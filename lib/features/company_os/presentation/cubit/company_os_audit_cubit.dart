import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/company_operations_query.dart';
import '../../domain/entities/company_os_page.dart';
import '../../domain/entities/operational_audit_event.dart';
import '../../domain/repositories/company_os_operations_repository.dart';

sealed class CompanyOsAuditState {
  const CompanyOsAuditState();
}

final class CompanyOsAuditLoading extends CompanyOsAuditState {
  const CompanyOsAuditLoading();
}

final class CompanyOsAuditReady extends CompanyOsAuditState {
  const CompanyOsAuditReady(this.page);
  final CompanyOsPage<OperationalAuditEvent> page;
}

final class CompanyOsAuditFailure extends CompanyOsAuditState {
  const CompanyOsAuditFailure(this.message);
  final String message;
}

final class CompanyOsAuditCubit extends Cubit<CompanyOsAuditState> {
  CompanyOsAuditCubit(this._repository) : super(const CompanyOsAuditLoading());
  final CompanyOsOperationsRepository _repository;
  Future<void> load([
    CompanyOperationsFilter filter = const CompanyOperationsFilter(),
  ]) async {
    emit(const CompanyOsAuditLoading());
    try {
      emit(CompanyOsAuditReady(await _repository.audit(filter)));
    } catch (_) {
      emit(const CompanyOsAuditFailure('تعذر تحميل سجل التدقيق حالياً.'));
    }
  }
}
