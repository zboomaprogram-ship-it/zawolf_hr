import 'app_failure.dart';

/// A confirmed success or a structured failure for an adopted operation.
sealed class OperationResult<T> {
  const OperationResult._();

  const factory OperationResult.success(T value) = OperationSuccess<T>;
  const factory OperationResult.failure(AppFailure failure) =
      OperationFailure<T>;

  bool get isSuccess;
  T? get valueOrNull;
  AppFailure? get failureOrNull;
}

final class OperationSuccess<T> extends OperationResult<T> {
  const OperationSuccess(this.value) : super._();

  final T value;

  @override
  bool get isSuccess => true;

  @override
  T get valueOrNull => value;

  @override
  AppFailure? get failureOrNull => null;
}

final class OperationFailure<T> extends OperationResult<T> {
  const OperationFailure(this.failure) : super._();

  final AppFailure failure;

  @override
  bool get isSuccess => false;

  @override
  T? get valueOrNull => null;

  @override
  AppFailure get failureOrNull => failure;
}
