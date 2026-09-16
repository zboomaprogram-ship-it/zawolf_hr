import '../../../models/user_model.dart';
import 'early_leave_checkout_eligibility.dart';

abstract interface class EarlyLeaveCheckoutRepository {
  Stream<EarlyLeaveCheckoutEligibility?> watchForToday(
    UserModel employee, {
    DateTime? now,
  });

  Future<EarlyLeaveCheckoutEligibility?> loadForToday(
    UserModel employee, {
    DateTime? now,
  });
}
