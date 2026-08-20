/// Employee check-in reliability pilot.
///
/// This feature is deliberately separate from the live check-out path.
library;

export 'attendance_checkin_pilot.dart';
export 'domain/entities/check_in_action.dart';
export 'domain/entities/check_in_receipt.dart';
export 'domain/entities/check_in_presentation_state.dart';
export 'domain/entities/check_in_status_resolution.dart';
export 'domain/entities/pending_check_in.dart';
export 'domain/repositories/attendance_check_in_repository.dart';
export 'presentation/cubit/checkin_cubit.dart';
export 'presentation/widgets/checkin_status_feedback.dart';
