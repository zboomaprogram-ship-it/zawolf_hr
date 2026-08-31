enum WorkspaceReportPeriodType { daily, weekly, monthly, custom }

final class WorkspaceReportPeriod {
  WorkspaceReportPeriod({
    required this.type,
    required this.startsOn,
    required this.endsOn,
  }) : assert(!endsOn.isBefore(startsOn));

  final WorkspaceReportPeriodType type;
  final DateTime startsOn;
  final DateTime endsOn;

  String reportKey({required String reportType, required String scopeId}) {
    String key(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    return '$reportType:$scopeId:${type.name}:${key(startsOn)}:${key(endsOn)}';
  }
}
