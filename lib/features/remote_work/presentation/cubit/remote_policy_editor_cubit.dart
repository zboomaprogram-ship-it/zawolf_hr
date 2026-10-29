import 'dart:math';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/remote_policy.dart';
import '../../domain/repositories/remote_policy_repository.dart';

sealed class RemotePolicyEditorState {
  const RemotePolicyEditorState();
}

final class RemotePolicyEditorLoading extends RemotePolicyEditorState {
  const RemotePolicyEditorLoading();
}

final class RemotePolicyEditorReady extends RemotePolicyEditorState {
  const RemotePolicyEditorReady({
    required this.aggregate,
    required this.schema,
    required this.draftId,
    required this.draftVersion,
    this.dirty = false,
    this.errors = const [],
    this.message,
    this.effectiveFrom,
  });

  final RemotePolicyAggregate aggregate;
  final Map<String, dynamic> schema;
  final String draftId;
  final int draftVersion;
  final bool dirty;
  final List<Map<String, dynamic>> errors;
  final String? message;
  final DateTime? effectiveFrom;
}

final class RemotePolicyEditorFailure extends RemotePolicyEditorState {
  const RemotePolicyEditorFailure(this.message);
  final String message;
}

final class RemotePolicyEditorCubit extends Cubit<RemotePolicyEditorState> {
  RemotePolicyEditorCubit({
    required RemotePolicyRepository repository,
    String draftId = 'company_attendance_policy',
  }) : _repository = repository,
       _draftId = draftId,
       super(const RemotePolicyEditorLoading());

  final RemotePolicyRepository _repository;
  String _draftId;
  String get draftId => _draftId;
  final Random _random = Random.secure();
  String? _pendingOperationId;
  String? _pendingPayloadHash;
  int _generation = 0;
  int _editRevision = 0;
  bool _saving = false;

  Future<void> load({String? draftId}) async {
    if (isClosed) return;
    if (draftId != null && draftId.trim().isNotEmpty) _draftId = draftId;
    var selectedDraftId = _draftId;
    final generation = ++_generation;
    emit(const RemotePolicyEditorLoading());
    try {
      final results = await Future.wait([
        _repository.loadCurrent(),
        _repository.loadSchema(),
      ]);
      var aggregate = results[0] as RemotePolicyAggregate;
      var draftVersion = 0;
      DateTime? effectiveFrom;
      try {
        final draft = await _repository.loadDraft(selectedDraftId);
        final rawAggregate = draft['aggregate'];
        if (draft['state'] == 'draft' && rawAggregate is Map) {
          aggregate = RemotePolicyAggregate.fromMap(
            Map<String, dynamic>.from(rawAggregate),
          );
          draftVersion = (draft['version'] as num?)?.toInt() ?? 0;
          effectiveFrom = DateTime.tryParse('${draft['effectiveFrom'] ?? ''}');
        } else if (draft['state'] == 'published' ||
            draft['state'] == 'scheduled') {
          selectedDraftId = _operationId();
        }
      } on RemotePolicyException catch (error) {
        if (error.code != 'draft_not_found') rethrow;
      }
      if (isClosed || generation != _generation) return;
      _draftId = selectedDraftId;
      emit(
        RemotePolicyEditorReady(
          aggregate: aggregate,
          schema: Map<String, dynamic>.from(results[1] as Map),
          draftId: selectedDraftId,
          draftVersion: draftVersion,
          effectiveFrom: effectiveFrom,
        ),
      );
    } catch (_) {
      if (isClosed || generation != _generation) return;
      emit(
        const RemotePolicyEditorFailure(
          'تعذر تحميل إعدادات سياسة الدوام. أعد المحاولة.',
        ),
      );
    }
  }

  void edit(RemotePolicyAggregate aggregate) {
    if (isClosed) return;
    final current = state;
    _editRevision++;
    if (current is RemotePolicyEditorReady) {
      emit(
        RemotePolicyEditorReady(
          aggregate: aggregate,
          schema: current.schema,
          draftId: current.draftId,
          draftVersion: current.draftVersion,
          dirty: true,
          effectiveFrom: current.effectiveFrom,
        ),
      );
    } else {
      emit(
        RemotePolicyEditorReady(
          aggregate: aggregate,
          schema: const {},
          draftId: _draftId,
          draftVersion: 0,
          dirty: true,
        ),
      );
    }
  }

  Future<RemotePolicyCommandReceipt?> saveDraft({
    required DateTime effectiveFrom,
  }) async {
    final current = state;
    if (isClosed ||
        _saving ||
        current is! RemotePolicyEditorReady ||
        !current.dirty) {
      return null;
    }
    _saving = true;
    final generation = _generation;
    final editRevision = _editRevision;
    final payloadHash =
        '${current.draftId}|${current.draftVersion}|${jsonEncode(current.aggregate.toAggregateMap())}|${effectiveFrom.toUtc().toIso8601String()}';
    if (_pendingOperationId == null || _pendingPayloadHash != payloadHash) {
      _pendingOperationId = _operationId();
      _pendingPayloadHash = payloadHash;
    }
    try {
      final receipt = await _repository.saveDraft(
        operationId: _pendingOperationId!,
        draftId: current.draftId,
        expectedVersion: current.draftVersion,
        aggregate: current.aggregate,
        effectiveFrom: effectiveFrom,
      );
      if (isClosed || generation != _generation) return null;
      _pendingOperationId = null;
      _pendingPayloadHash = null;
      final latest = state as RemotePolicyEditorReady;
      emit(
        RemotePolicyEditorReady(
          aggregate: latest.aggregate,
          schema: current.schema,
          draftId: current.draftId,
          draftVersion: receipt.version,
          dirty: editRevision != _editRevision,
          message: 'تم حفظ مسودة سياسة الدوام.',
          effectiveFrom: effectiveFrom,
        ),
      );
      return receipt;
    } catch (error) {
      if (isClosed || generation != _generation) return null;
      final errorMessage = error is RemotePolicyException
          ? error.message
          : (error is Exception
              ? error.toString().replaceFirst('Exception: ', '')
              : error.toString());
      if (state is RemotePolicyEditorReady) {
        final latest = state as RemotePolicyEditorReady;
        emit(
          RemotePolicyEditorReady(
            aggregate: latest.aggregate,
            schema: current.schema,
            draftId: current.draftId,
            draftVersion: current.draftVersion,
            dirty: true,
            message: errorMessage,
            effectiveFrom: latest.effectiveFrom,
          ),
        );
      }
      return null;
    } finally {
      _saving = false;
    }
  }

  String _operationId() =>
      'policy_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1 << 32)}';

  void recordReceipt(RemotePolicyCommandReceipt receipt) {
    final current = state;
    if (isClosed ||
        current is! RemotePolicyEditorReady ||
        receipt.draftId != current.draftId ||
        receipt.version < current.draftVersion) {
      return;
    }
    emit(
      RemotePolicyEditorReady(
        aggregate: current.aggregate,
        schema: current.schema,
        draftId: current.draftId,
        draftVersion: receipt.version,
        dirty: current.dirty,
        errors: current.errors,
        message: current.message,
        effectiveFrom: current.effectiveFrom,
      ),
    );
  }
}
