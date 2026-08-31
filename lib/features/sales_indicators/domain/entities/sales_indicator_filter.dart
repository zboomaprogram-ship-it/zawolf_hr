final class SalesIndicatorFilter {
  const SalesIndicatorFilter({
    required this.startDate,
    required this.endDate,
    this.company = 'ALL',
    this.sales = const <String>[],
    this.teleSales = const <String>[],
    this.entryChannel = 'ALL',
    this.salesTarget = 20000,
    this.teleTarget = 50,
  });

  final String startDate;
  final String endDate;
  final String company;
  final List<String> sales;
  final List<String> teleSales;
  final String entryChannel;
  final double salesTarget;
  final double teleTarget;

  /// Stable, header-safe identity used to make an on-demand provider sync
  /// idempotent for the exact same filter selection.
  String get stableIdentity {
    final raw = <Object>[
      startDate,
      endDate,
      company,
      ...sales,
      ...teleSales,
      entryChannel,
      salesTarget,
      teleTarget,
    ].join('-').toLowerCase();
    final safe = raw.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    return safe.substring(0, safe.length > 180 ? 180 : safe.length);
  }

  Map<String, Object> toMap() => <String, Object>{
    'startDate': startDate,
    'endDate': endDate,
    'company': company,
    'sales': sales,
    'teleSales': teleSales,
    'entryChannel': entryChannel,
    'salesTarget': salesTarget,
    'teleTarget': teleTarget,
  };
}
