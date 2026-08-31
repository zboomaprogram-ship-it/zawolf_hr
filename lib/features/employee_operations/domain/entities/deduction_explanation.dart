/// Employee-safe explanation of a single deduction. The effective date and
/// cycle are immutable business facts; review time never changes them.
final class DeductionExplanation {
  const DeductionExplanation({
    required this.sourceKey,
    required this.effectiveDate,
    required this.effectiveCycleKey,
    required this.sourceLabelAr,
    required this.reasonAr,
    required this.fraction,
    required this.status,
    this.amount,
    this.currency,
    this.reviewedAt,
    this.originalCheckIn,
  });

  final String sourceKey;
  final DateTime effectiveDate;
  final String effectiveCycleKey;
  final String sourceLabelAr;
  final String reasonAr;
  final double fraction;
  final DeductionReviewStatus status;
  final double? amount;
  final String? currency;
  final DateTime? reviewedAt;
  final DateTime? originalCheckIn;

  String get attendanceId => sourceKey.startsWith('attendance:')
      ? sourceKey.substring('attendance:'.length)
      : '';

  bool get canRequestCorrection =>
      sourceKey.startsWith('attendance:') &&
      status != DeductionReviewStatus.cancelled &&
      fraction > 0;
}

enum DeductionReviewStatus { pending, approved, rejected, cancelled }
