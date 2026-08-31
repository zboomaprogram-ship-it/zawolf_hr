import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workspace_access_grant.dart';
import '../../domain/entities/workspace_source_import.dart';
import '../../domain/entities/workspace_pilot_configuration.dart';
import '../../domain/repositories/workspace_access_administration_repository.dart';

sealed class WorkspaceAccessAdminState {
  const WorkspaceAccessAdminState();
}

final class WorkspaceAccessAdminIdle extends WorkspaceAccessAdminState {
  const WorkspaceAccessAdminIdle();
}

final class WorkspaceAccessAdminLoading extends WorkspaceAccessAdminState {
  const WorkspaceAccessAdminLoading();
}

final class WorkspaceAccessAdminReady extends WorkspaceAccessAdminState {
  const WorkspaceAccessAdminReady(
    this.grants, {
    this.message,
    this.isError = false,
    this.pilotConfiguration,
  });
  final List<WorkspaceAccessGrant> grants;
  final String? message;
  final bool isError;
  final WorkspacePilotConfiguration? pilotConfiguration;
}

final class WorkspaceAccessAdminFailure extends WorkspaceAccessAdminState {
  const WorkspaceAccessAdminFailure(this.message);
  final String message;
}

/// Owns administration screen state only. The repository owns all API details.
final class WorkspaceAccessAdminCubit extends Cubit<WorkspaceAccessAdminState> {
  WorkspaceAccessAdminCubit(this._repository)
    : super(const WorkspaceAccessAdminIdle());

  final WorkspaceAccessAdministrationRepository _repository;
  String? _resourceId;

  WorkspaceAccessAdminReady? get _readyState => switch (state) {
    WorkspaceAccessAdminReady ready => ready,
    _ => null,
  };

  void _busy() {
    final ready = _readyState;
    if (ready == null) {
      emit(const WorkspaceAccessAdminLoading());
      return;
    }
    // Keep the current grants visible while an administration action runs.
    // This avoids the empty-screen flash that made normal access work feel slow.
    emit(
      WorkspaceAccessAdminReady(
        ready.grants,
        message: ready.message,
        isError: false,
        pilotConfiguration: ready.pilotConfiguration,
      ),
    );
  }

  void _failure(String message) {
    final ready = _readyState;
    if (ready == null) {
      emit(WorkspaceAccessAdminFailure(message));
      return;
    }
    emit(
      WorkspaceAccessAdminReady(
        ready.grants,
        message: message,
        isError: true,
        pilotConfiguration: ready.pilotConfiguration,
      ),
    );
  }

  Future<void> loadGrants(String resourceId) async {
    _resourceId = resourceId;
    _busy();
    try {
      emit(WorkspaceAccessAdminReady(await _repository.listGrants(resourceId)));
    } on Object {
      _failure('تعذر تحميل صلاحيات الوصول الآن.');
    }
  }

  Future<void> createGrant(WorkspaceAccessGrant grant) async {
    _resourceId = grant.resourceId;
    _busy();
    try {
      await _repository.createGrant(grant);
      final grants = await _repository.listGrants(grant.resourceId);
      emit(WorkspaceAccessAdminReady(grants, message: 'تم منح الصلاحية.'));
    } on Object {
      _failure('تعذر حفظ الصلاحية. تحقق من البيانات وأعد المحاولة.');
    }
  }

  Future<void> revoke(String grantId) async {
    final resourceId = _resourceId;
    if (resourceId == null) return;
    _busy();
    try {
      await _repository.revokeGrant(grantId);
      emit(
        WorkspaceAccessAdminReady(
          await _repository.listGrants(resourceId),
          message: 'تم سحب الصلاحية.',
        ),
      );
    } on Object {
      _failure('تعذر سحب الصلاحية الآن.');
    }
  }

  Future<void> importSource() async {
    final current = _readyState;
    _busy();
    try {
      final WorkspaceSourceImportResult result = await _repository
          .importCompanySource();
      emit(
        WorkspaceAccessAdminReady(
          current?.grants ?? const [],
          message: 'تمت المزامنة: ${result.discovered} ملفاً ومجلداً.',
        ),
      );
    } on Object {
      _failure('تعذرت مزامنة ملفات الشركة الآن. أعد المحاولة لاحقاً.');
    }
  }

  Future<void> loadPilotConfiguration() async {
    final current = _readyState;
    _busy();
    try {
      final configuration = await _repository.loadPilotConfiguration();
      emit(
        WorkspaceAccessAdminReady(
          current?.grants ?? const [],
          pilotConfiguration: configuration,
        ),
      );
    } on Object {
      _failure('تعذر تحميل إعداد تجربة V2 الآن.');
    }
  }

  Future<void> savePilotConfiguration(
    WorkspacePilotConfiguration configuration, {
    required String reason,
  }) async {
    final current = _readyState;
    _busy();
    try {
      await _repository.savePilotConfiguration(configuration, reason: reason);
      emit(
        WorkspaceAccessAdminReady(
          current?.grants ?? const [],
          pilotConfiguration: configuration,
          message: configuration.enabledForEveryone
              ? 'تم تشغيل V2 افتراضياً. يمكن التراجع فوراً من هنا.'
              : 'تم حفظ جمهور التجربة المحدود. يمكن التراجع فوراً من هنا.',
        ),
      );
    } on Object {
      _failure('تعذر حفظ إعداد تجربة V2 الآن.');
    }
  }
}
