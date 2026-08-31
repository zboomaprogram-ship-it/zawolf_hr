import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/software_license.dart';
import '../../domain/repositories/it_operations_repository.dart';

sealed class SoftwareLicenseDetailState {
  const SoftwareLicenseDetailState();
}

final class SoftwareLicenseDetailLoading extends SoftwareLicenseDetailState {
  const SoftwareLicenseDetailLoading();
}

final class SoftwareLicenseDetailReady extends SoftwareLicenseDetailState {
  const SoftwareLicenseDetailReady({
    required this.license,
    required this.assignments,
    this.saving = false,
    this.message,
  });
  final SoftwareLicense license;
  final List<SoftwareAssignment> assignments;
  final bool saving;
  final String? message;

  SoftwareLicenseDetailReady copyWith({bool? saving, String? message}) =>
      SoftwareLicenseDetailReady(
        license: license,
        assignments: assignments,
        saving: saving ?? this.saving,
        message: message,
      );
}

final class SoftwareLicenseDetailFailure extends SoftwareLicenseDetailState {
  const SoftwareLicenseDetailFailure(this.message);
  final String message;
}

final class SoftwareLicenseDetailCubit
    extends Cubit<SoftwareLicenseDetailState> {
  SoftwareLicenseDetailCubit(this._repository, this.licenseId)
    : super(const SoftwareLicenseDetailLoading());
  final ItOperationsRepository _repository;
  final String licenseId;

  Future<void> load() async {
    emit(const SoftwareLicenseDetailLoading());
    try {
      final license = await _repository.license(licenseId);
      final assignments = await _repository.licenseAssignments(licenseId);
      emit(
        SoftwareLicenseDetailReady(
          license: license,
          assignments: assignments.items,
        ),
      );
    } catch (_) {
      emit(const SoftwareLicenseDetailFailure('تعذر تحميل تفاصيل الترخيص.'));
    }
  }

  Future<void> assign(String employeeUid) => _save(
    (license) => _repository.assignLicenseSeat(
      licenseId: license.id,
      employeeUid: employeeUid,
      operationId: _operationId('assign'),
      expectedVersion: license.version,
    ),
  );

  Future<void> revoke(String employeeUid) => _save(
    (license) => _repository.revokeLicenseSeat(
      licenseId: license.id,
      employeeUid: employeeUid,
      operationId: _operationId('revoke'),
      expectedVersion: license.version,
    ),
  );

  Future<void> renew(DateTime renewalAt, {int? totalSeats}) => _save(
    (license) => _repository.renewLicense(
      licenseId: license.id,
      operationId: _operationId('renew'),
      expectedVersion: license.version,
      renewalAt: renewalAt,
      totalSeats: totalSeats,
    ),
  );

  Future<void> _save(Future<Object?> Function(SoftwareLicense) action) async {
    final current = state;
    if (current is! SoftwareLicenseDetailReady || current.saving) return;
    emit(current.copyWith(saving: true));
    try {
      await action(current.license);
      await load();
    } catch (_) {
      emit(
        current.copyWith(
          saving: false,
          message: 'تعذر حفظ العملية. تحقق من السعة وحدّث البيانات.',
        ),
      );
    }
  }

  String _operationId(String action) =>
      'license-$action-$licenseId-${DateTime.now().microsecondsSinceEpoch}';
}
