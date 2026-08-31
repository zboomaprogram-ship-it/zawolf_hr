final class FinancialLedgerEntry {
  const FinancialLedgerEntry({
    required this.id,
    required this.employeeUid,
    required this.entryType,
    required this.sourceType,
    required this.sourceId,
    required this.effectiveDate,
    required this.amount,
    required this.currency,
    required this.direction,
    required this.status,
    required this.description,
  });
  final String id;
  final String employeeUid;
  final String entryType;
  final String sourceType;
  final String sourceId;
  final DateTime effectiveDate;
  final num amount;
  final String currency;
  final String direction;
  final String status;
  final String description;
}
