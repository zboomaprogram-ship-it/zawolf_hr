import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../company_os/domain/entities/company_os_sync_state.dart';
import '../../../company_os/domain/entities/company_os_safe_error.dart';
import '../../domain/entities/organization_change_set.dart';
import '../../domain/repositories/organization_structure_repository.dart';

enum OrganizationSaveStatus {
  idle,
  previewing,
  ready,
  saving,
  saved,
  pendingSync,
  statusChecking,
  conflict,
  denied,
  failure,
}

final class OrganizationEditorState {
  const OrganizationEditorState({
    this.status = OrganizationSaveStatus.idle,
    this.change,
    this.preview,
    this.message,
  });
  final OrganizationSaveStatus status;
  final OrganizationChangeSet? change;
  final OrganizationImpactPreview? preview;
  final String? message;
}

final class OrganizationEditorCubit extends Cubit<OrganizationEditorState> {
  OrganizationEditorCubit(this._repository)
    : super(const OrganizationEditorState());
  final OrganizationStructureRepository _repository;

  Future<void> prepare(OrganizationChangeSet change) async {
    emit(
      OrganizationEditorState(
        status: OrganizationSaveStatus.previewing,
        change: change,
      ),
    );
    try {
      final preview = await _repository.preview(change);
      emit(
        OrganizationEditorState(
          status: OrganizationSaveStatus.ready,
          change: change,
          preview: preview,
        ),
      );
    } catch (_) {
      emit(
        OrganizationEditorState(
          status: OrganizationSaveStatus.failure,
          change: change,
          message: 'تعذر تجهيز معاينة التغيير.',
        ),
      );
    }
  }

  Future<bool> apply(OrganizationChangeSet change) async {
    emit(
      OrganizationEditorState(
        status: OrganizationSaveStatus.saving,
        change: change,
      ),
    );
    try {
      final result = await _repository.apply(change);
      emit(
        OrganizationEditorState(
          status: result.status.name == 'pending'
              ? OrganizationSaveStatus.pendingSync
              : OrganizationSaveStatus.saved,
          change: change,
          message: result.status.name == 'pending'
              ? 'تم حفظ التغيير للمزامنة.'
              : 'تم حفظ التغيير.',
        ),
      );
      return true;
    } on CompanyOsSafeError catch (error) {
      emit(
        OrganizationEditorState(
          status: error.code == CompanyOsSafeCode.accessDenied
              ? OrganizationSaveStatus.denied
              : error.code == CompanyOsSafeCode.conflict
              ? OrganizationSaveStatus.conflict
              : OrganizationSaveStatus.failure,
          change: change,
          message: error.arabicMessage,
        ),
      );
      return false;
    } catch (_) {
      emit(
        OrganizationEditorState(
          status: OrganizationSaveStatus.failure,
          change: change,
          message: 'تعذر حفظ التغيير.',
        ),
      );
      return false;
    }
  }

  Future<void> checkStatus() async {
    final change = state.change;
    if (change == null) return;
    emit(
      OrganizationEditorState(
        status: OrganizationSaveStatus.statusChecking,
        change: change,
      ),
    );
    try {
      final receipt = await _repository.operationStatus(change.operationId);
      final status = receipt?.status;
      emit(
        OrganizationEditorState(
          status: status == CompanyOsSyncState.synced
              ? OrganizationSaveStatus.saved
              : status == CompanyOsSyncState.conflict
              ? OrganizationSaveStatus.conflict
              : OrganizationSaveStatus.pendingSync,
          change: change,
          message: status == CompanyOsSyncState.synced
              ? 'تمت مزامنة التغيير.'
              : status == CompanyOsSyncState.conflict
              ? 'يوجد تعارض. حدّث الصفحة ثم أعد المحاولة.'
              : 'لا يزال التغيير بانتظار المزامنة.',
        ),
      );
    } catch (_) {
      emit(
        OrganizationEditorState(
          status: OrganizationSaveStatus.pendingSync,
          change: change,
          message: 'تعذر التحقق الآن. سيُعاد التحقق لاحقًا.',
        ),
      );
    }
  }
}
