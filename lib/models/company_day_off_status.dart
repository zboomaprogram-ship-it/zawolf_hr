class CompanyDayOffStatus {
  final bool isDayOff;
  final String reason;

  const CompanyDayOffStatus({required this.isDayOff, required this.reason});

  const CompanyDayOffStatus.workDay() : isDayOff = false, reason = '';
}
