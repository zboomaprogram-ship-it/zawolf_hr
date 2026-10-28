import 'dart:math';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/remote_policy.dart';
import '../../domain/repositories/remote_policy_repository.dart';

sealed class RemotePolicyPublicationState {
  const RemotePolicyPublicationState();
}

final class RemotePolicyPublicationIdle extends RemotePolicyPublicationState {
  const RemotePolicyPublicationIdle();
}

final class RemotePolicyPublicationWorking
    extends RemotePolicyPublicationState {
  const RemotePolicyPublicationWorking(this.previous);
  final RemotePolicyPublicationReady? previous;
}

final class RemotePolicyPublicationReady extends RemotePolicyPublicationState {
  const RemotePolicyPublicationReady({
    required this.draftId,
    required this.draftVersion,
    this.preview,
    this.history = const [],
    this.message,
  });

  final String draftId;
  final int draftVersion;
  final Map<String, dynamic>? preview;
  final List<Map<String, dynamic>> history;
  final String? message;
}

final class RemotePolicyPublicationFailure
    extends RemotePolicyPublicationState {
  const RemotePolicyPublicationFailure(this.message);
  final String message;
}

final class RemotePolicyPublicationCubit
    extends Cubit<RemotePolicyPublicationState> {
  RemotePolicyPublicationCubit({
    required RemotePolicyRepository repository,
    required String draftId,
  }) : _repository = repository,
       _draftId = draftId,
       super(const RemotePolicyPublicationIdle());

  final RemotePolicyRepository _repository;
  String _draftId;
  String get draftId => _draftId;
  final Random _random = Random.secure();
  String? _pendingOperationId;
  String? _pendingFingerprint;

  void selectDraft({required String draftId, required int version}) {
    if (isClosed || state is RemotePolicyPublicationWorking) return;
    if (draftId == _draftId && _ready?.draftVersion == version) return;
    if (draftId != _draftId) {
      _pendingOperationId = null;
      _pendingFingerprint = null;
    }
    final history = _ready?.history ?? const <Map<String, dynamic>>[];
    _draftId = draftId;
    emit(
      RemotePolicyPublicationReady(
        draftId: draftId,
        draftVersion: version,
        history: history,
      ),
    );
  }

  Future<void> preview({
    required RemotePolicyAggregate aggregate,
    required String employeeId,
    required DateTime date,
    required int draftVersion,
  }) async {
    if (isClosed || state is RemotePolicyPublicationWorking) return;
    final previous = _ready;
    emit(RemotePolicyPublicationWorking(previous));
    try {
      final result = await _repository.preview(
        aggregate: aggregate,
        employeeId: employeeId,
        date: date,
      );
      if (isClosed) return;
      emit(
        RemotePolicyPublicationReady(
          draftId: draftId,
          draftVersion: draftVersion,
          preview: result,
          history: previous?.history ?? const [],
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(RemotePolicyPublicationFailure(error.toString()));
    }
  }

  Future<RemotePolicyCommandReceipt?> approve({
    required int expectedVersion,
    required String reason,
  }) async {
    return _run(
      fingerprint: jsonEncode(['approve', draftId, expectedVersion, reason]),
      expectedVersion: expectedVersion,
      action:
          (operationId) => _repository.approve(
            operationId: operationId,
            draftId: draftId,
            expectedVersion: expectedVersion,
            reason: reason,
          ),
    );
  }

  Future<RemotePolicyCommandReceipt?> publish({
    required int expectedVersion,
    required DateTime effectiveFrom,
  }) async {
    return _run(
      fingerprint: jsonEncode([
        'publish',
        draftId,
        expectedVersion,
        effectiveFrom.toUtc().toIso8601String(),
      ]),
      expectedVersion: expectedVersion,
      action:
          (operationId) => _repository.publish(
            operationId: operationId,
            draftId: draftId,
            expectedVersion: expectedVersion,
            effectiveFrom: effectiveFrom,
          ),
    );
  }

  Future<RemotePolicyCommandReceipt?> revert({
    required String targetRevisionId,
    required DateTime effectiveFrom,
  }) async {
    if (isClosed || state is RemotePolicyPublicationWorking) return null;
    final operationId = _retryOperation(
      jsonEncode([
        'revert',
        draftId,
        targetRevisionId,
        effectiveFrom.toUtc().toIso8601String(),
      ]),
    );
    final revertDraftId = 'revert_$operationId';
    final previous = _ready;
    emit(RemotePolicyPublicationWorking(previous));
    try {
      final receipt = await _repository.revert(
        operationId: operationId,
        draftId: revertDraftId,
        targetRevisionId: targetRevisionId,
        effectiveFrom: effectiveFrom,
      );
      if (isClosed) return null;
      _pendingOperationId = null;
      _pendingFingerprint = null;
      _draftId = receipt.draftId;
      emit(
        RemotePolicyPublicationReady(
          draftId: _draftId,
          draftVersion: receipt.version,
          history: previous?.history ?? const [],
          message: 'تم إنشاء مسودة من الإصدار السابق.',
        ),
      );
      return receipt;
    } catch (error) {
      if (isClosed) return null;
      emit(
        RemotePolicyPublicationReady(
          draftId: draftId,
          draftVersion: previous?.draftVersion ?? 0,
          history: previous?.history ?? const [],
          message: error.toString(),
        ),
      );
      return null;
    }
  }

  Future<void> loadHistory({int limit = 50}) async {
    if (isClosed || state is RemotePolicyPublicationWorking) return;
    final previous = _ready;
    emit(RemotePolicyPublicationWorking(previous));
    try {
      final result = await _repository.loadHistory(limit: limit);
      if (isClosed) return;
      final items = (result['items'] as List? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false);
      emit(
        RemotePolicyPublicationReady(
          draftId: draftId,
          draftVersion: previous?.draftVersion ?? 0,
          preview: previous?.preview,
          history: items,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(RemotePolicyPublicationFailure(error.toString()));
    }
  }

  Future<RemotePolicyCommandReceipt?> _run({
    required String fingerprint,
    required int expectedVersion,
    required Future<RemotePolicyCommandReceipt> Function(String operationId)
    action,
  }) async {
    if (isClosed || state is RemotePolicyPublicationWorking) return null;
    final previous = _ready;
    emit(RemotePolicyPublicationWorking(previous));
    try {
      final receipt = await action(_retryOperation(fingerprint));
      if (isClosed) return null;
      _pendingOperationId = null;
      _pendingFingerprint = null;
      emit(
        RemotePolicyPublicationReady(
          draftId: draftId,
          draftVersion: receipt.version,
          preview: previous?.preview,
          history: previous?.history ?? const [],
          message: receipt.status,
        ),
      );
      return receipt;
    } catch (error) {
      if (isClosed) return null;
      emit(
        RemotePolicyPublicationReady(
          draftId: draftId,
          draftVersion: expectedVersion,
          preview: previous?.preview,
          history: previous?.history ?? const [],
          message: error.toString(),
        ),
      );
      return null;
    }
  }

  RemotePolicyPublicationReady? get _ready => switch (state) {
    RemotePolicyPublicationReady value => value,
    RemotePolicyPublicationWorking(:final previous) => previous,
    _ => null,
  };

  String _operationId() =>
      'policy_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1 << 32)}';

  String _retryOperation(String fingerprint) {
    if (_pendingFingerprint != fingerprint || _pendingOperationId == null) {
      _pendingFingerprint = fingerprint;
      _pendingOperationId = _operationId();
    }
    return _pendingOperationId!;
  }
}
