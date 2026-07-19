import 'package:intl/intl.dart';

class PayrollCycle {
  static const int closingDay = 25;
  static const int openingDay = 26;

  final String key;
  final DateTime start;
  final DateTime end;
  final DateTime nextStart;

  const PayrollCycle({
    required this.key,
    required this.start,
    required this.end,
    required this.nextStart,
  });

  factory PayrollCycle.forDate(DateTime date) {
    final endMonth = date.day <= closingDay
        ? DateTime(date.year, date.month)
        : DateTime(date.year, date.month + 1);
    return PayrollCycle.forKey(DateFormat('yyyy-MM').format(endMonth));
  }

  factory PayrollCycle.forKey(String key) {
    final parts = key.split('-');
    if (parts.length != 2) {
      throw FormatException('Invalid payroll cycle key: $key');
    }
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final cycleEndMonth = DateTime(year, month);
    final previousMonth = DateTime(year, month - 1);
    return PayrollCycle(
      key: DateFormat('yyyy-MM').format(cycleEndMonth),
      start: DateTime(previousMonth.year, previousMonth.month, openingDay),
      end: DateTime(cycleEndMonth.year, cycleEndMonth.month, closingDay),
      nextStart: DateTime(cycleEndMonth.year, cycleEndMonth.month, openingDay),
    );
  }

  static String keyFor(DateTime date) => PayrollCycle.forDate(date).key;

  String get startDateKey => DateFormat('yyyy-MM-dd').format(start);
  String get endDateKey => DateFormat('yyyy-MM-dd').format(end);
  String get nextStartDateKey => DateFormat('yyyy-MM-dd').format(nextStart);

  String get arabicRangeLabel => 'من $startDateKey إلى $endDateKey';
}
