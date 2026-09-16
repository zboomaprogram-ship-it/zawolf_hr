import 'early_leave_deduction_policy.dart';

enum EarlyLeaveRequestState { pendingManager, pendingHr, approved, rejected }

final class EarlyLeaveCheckoutEligibility {
  const EarlyLeaveCheckoutEligibility({
    required this.permissionId,
    required this.requestState,
    required this.requestedCheckoutAt,
    required this.normalCheckoutAt,
    required this.requestedMinutes,
  });

  final String permissionId;
  final EarlyLeaveRequestState requestState;
  final DateTime requestedCheckoutAt;
  final DateTime normalCheckoutAt;
  final int requestedMinutes;

  int get requestedHours => requestedMinutes ~/ 60;
  double get potentialDayFraction =>
      EarlyLeaveDeductionPolicy.dayFraction(requestedMinutes);

  bool canCheckoutAt(DateTime now) =>
      !now.isBefore(requestedCheckoutAt) && now.isBefore(normalCheckoutAt);

  String get warningArabic {
    final fraction = EarlyLeaveDeductionPolicy.fractionLabel(
      potentialDayFraction,
    );
    return switch (requestState) {
      EarlyLeaveRequestState.approved =>
        'تمت الموافقة على إذن المغادرة المبكرة. لا يترتب خصم عند الانصراف في الوقت المطلوب.',
      EarlyLeaveRequestState.rejected =>
        'تم رفض إذن المغادرة المبكرة. تسجيل الانصراف الآن سينشئ خصم $fraction بانتظار مراجعة الموارد البشرية.',
      _ =>
        'طلب المغادرة المبكرة ما زال قيد المراجعة. إذا رُفض بعد الانصراف فسيُنشأ خصم $fraction بانتظار مراجعة الموارد البشرية.',
    };
  }
}

EarlyLeaveRequestState? parseEarlyLeaveRequestState(String value) =>
    switch (value) {
      'pending_manager' => EarlyLeaveRequestState.pendingManager,
      'pending_hr' => EarlyLeaveRequestState.pendingHr,
      'approved' => EarlyLeaveRequestState.approved,
      'rejected' => EarlyLeaveRequestState.rejected,
      _ => null,
    };
