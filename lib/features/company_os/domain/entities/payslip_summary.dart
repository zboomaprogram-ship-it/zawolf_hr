final class PayslipSummary {
  const PayslipSummary({
    required this.id,
    required this.employeeUid,
    required this.period,
    required this.gross,
    required this.net,
    required this.deductions,
    required this.currency,
  });

  final String id;
  final String employeeUid;
  final String period;
  final num gross;
  final num net;
  final num deductions;
  final String currency;
}
