class RequestApprovalPolicy {
  final bool requireHrAfterManagerApproval;
  final int ceoLeaveApprovalThresholdDays;
  final bool requireCeoApprovalForRemote;
  final int leaveNoticeDaysNormal;
  final int probationPeriodDays;
  final int payrollWorkDaysPerMonth;
  final bool requireCeoApprovalForAdvance;
  final double advanceMaxSalaryPercentage;

  const RequestApprovalPolicy({
    this.requireHrAfterManagerApproval = false,
    this.ceoLeaveApprovalThresholdDays = 3,
    this.requireCeoApprovalForRemote = true,
    this.leaveNoticeDaysNormal = 2,
    this.probationPeriodDays = 90,
    this.payrollWorkDaysPerMonth = 26,
    this.requireCeoApprovalForAdvance = true,
    this.advanceMaxSalaryPercentage = 50.0,
  });

  factory RequestApprovalPolicy.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const RequestApprovalPolicy();

    int parsePositiveInt(dynamic value, int fallback) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    double parsePositiveDouble(dynamic value, double fallback) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }

    return RequestApprovalPolicy(
      requireHrAfterManagerApproval:
          data['requireHrAfterManagerApproval'] as bool? ?? false,
      ceoLeaveApprovalThresholdDays: parsePositiveInt(
        data['ceoLeaveApprovalThresholdDays'],
        3,
      ),
      requireCeoApprovalForRemote:
          data['requireCeoApprovalForRemote'] as bool? ?? true,
      leaveNoticeDaysNormal: parsePositiveInt(
        data['leaveNoticeDaysNormal'],
        2,
      ),
      probationPeriodDays: parsePositiveInt(
        data['probationPeriodDays'],
        90,
      ),
      payrollWorkDaysPerMonth: parsePositiveInt(
        data['payrollWorkDaysPerMonth'],
        26,
      ),
      requireCeoApprovalForAdvance:
          data['requireCeoApprovalForAdvance'] as bool? ?? true,
      advanceMaxSalaryPercentage: parsePositiveDouble(
        data['advanceMaxSalaryPercentage'],
        50.0,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requireHrAfterManagerApproval': requireHrAfterManagerApproval,
      'ceoLeaveApprovalThresholdDays': ceoLeaveApprovalThresholdDays,
      'requireCeoApprovalForRemote': requireCeoApprovalForRemote,
      'leaveNoticeDaysNormal': leaveNoticeDaysNormal,
      'probationPeriodDays': probationPeriodDays,
      'payrollWorkDaysPerMonth': payrollWorkDaysPerMonth,
      'requireCeoApprovalForAdvance': requireCeoApprovalForAdvance,
      'advanceMaxSalaryPercentage': advanceMaxSalaryPercentage,
    };
  }

  String get finalManagerApprovalStatus =>
      requireHrAfterManagerApproval ? 'pending_hr' : 'approved';
}
