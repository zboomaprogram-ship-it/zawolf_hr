import 'package:cloud_firestore/cloud_firestore.dart';

class SalesKpiAgentOption {
  final String code;
  final String id;
  final String name;

  const SalesKpiAgentOption({
    required this.code,
    required this.id,
    required this.name,
  });

  bool get isLinked => id.trim().isNotEmpty;

  factory SalesKpiAgentOption.fromMap(Map<String, dynamic> map) {
    return SalesKpiAgentOption(
      code: map['code']?.toString() ?? '',
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'code': code, 'id': id, 'name': name};
}

class SalesKpiFilterOptions {
  final List<String> companies;
  final List<SalesKpiAgentOption> salesAgents;
  final List<SalesKpiAgentOption> teleSalesAgents;
  final List<String> entryChannels;

  const SalesKpiFilterOptions({
    this.companies = const [],
    this.salesAgents = const [],
    this.teleSalesAgents = const [],
    this.entryChannels = const [],
  });

  List<SalesKpiAgentOption> get linkedSalesAgents =>
      salesAgents.where((agent) => agent.isLinked).toList();
  List<SalesKpiAgentOption> get linkedTeleSalesAgents =>
      teleSalesAgents.where((agent) => agent.isLinked).toList();

  factory SalesKpiFilterOptions.fromMap(Map<String, dynamic> map) {
    List<String> strings(String key) => (map[key] as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    List<SalesKpiAgentOption> agents(String key) =>
        (map[key] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => SalesKpiAgentOption.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();

    return SalesKpiFilterOptions(
      companies: strings('companies'),
      salesAgents: agents('salesAgents'),
      teleSalesAgents: agents('teleSalesAgents'),
      entryChannels: strings('entryChannels'),
    );
  }
}

class SalesKpiFilters {
  final String startDate;
  final String endDate;
  final String company;
  final List<String> sales;
  final List<String> teleSales;
  final String entryChannel;
  final double salesTarget;
  final double teleTarget;
  final String idEmp;
  final bool cumulative;

  const SalesKpiFilters({
    this.startDate = '',
    this.endDate = '',
    this.company = 'ALL',
    this.sales = const [],
    this.teleSales = const [],
    this.entryChannel = 'ALL',
    this.salesTarget = 20000,
    this.teleTarget = 50,
    this.idEmp = '',
    this.cumulative = true,
  });

  factory SalesKpiFilters.fromMap(Map<String, dynamic> map) {
    List<String> values(String key) {
      final value = map[key];
      if (value is List) {
        return value
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty && item != 'ALL' && item != 'NONE')
            .toList();
      }
      final text = value?.toString() ?? '';
      if (text.isEmpty || text == 'ALL' || text == 'NONE') return const [];
      return text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    double number(String key, double fallback) {
      final value = map[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return SalesKpiFilters(
      startDate: map['startDate']?.toString() ?? '',
      endDate: map['endDate']?.toString() ?? '',
      company: map['company']?.toString() ?? 'ALL',
      sales: values('sales'),
      teleSales: values('teleSales'),
      entryChannel: map['entryChannel']?.toString() ?? 'ALL',
      salesTarget: number('salesTarget', 20000),
      teleTarget: number('teleTarget', 50),
      idEmp: map['idEmp']?.toString() ?? '',
      cumulative: map['cumulative'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
    'startDate': startDate,
    'endDate': endDate,
    'company': company,
    'sales': sales.isEmpty ? 'ALL' : sales,
    'teleSales': teleSales.isEmpty ? 'ALL' : teleSales,
    'entryChannel': entryChannel,
    'salesTarget': salesTarget,
    'teleTarget': teleTarget,
    'idEmp': idEmp,
    'cumulative': cumulative,
  };
}

class SalesKpiAgentSummary {
  final String kind;
  final String key;
  final String externalId;
  final String name;
  final double target;
  final double actual;
  final double finalKpi;
  final String mappedUserId;
  final String mappedEmployeeId;
  final String mappedEmployeeName;
  final Map<String, dynamic> providerDetails;

  const SalesKpiAgentSummary({
    required this.kind,
    required this.key,
    required this.externalId,
    required this.name,
    required this.target,
    required this.actual,
    required this.finalKpi,
    required this.mappedUserId,
    required this.mappedEmployeeId,
    required this.mappedEmployeeName,
    required this.providerDetails,
  });

  bool get isMapped => mappedUserId.isNotEmpty;

  factory SalesKpiAgentSummary.fromMap(Map<String, dynamic> map) {
    double readDouble(String key) => (map[key] as num?)?.toDouble() ?? 0;
    return SalesKpiAgentSummary(
      kind: map['kind'] as String? ?? '',
      key: map['key'] as String? ?? '',
      externalId: map['externalId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      target: readDouble('target'),
      actual: readDouble('actual'),
      finalKpi: readDouble('finalKpi'),
      mappedUserId: map['mappedUserId'] as String? ?? '',
      mappedEmployeeId: map['mappedEmployeeId'] as String? ?? '',
      mappedEmployeeName: map['mappedEmployeeName'] as String? ?? '',
      providerDetails: Map<String, dynamic>.from(
        map['providerDetails'] as Map? ?? const {},
      ),
    );
  }
}

class SalesKpiSummary {
  final String periodKey;
  final String periodStart;
  final String periodEnd;
  final int totalLeads;
  final int confirmedMeetings;
  final int closings;
  final int paidCustomers;
  final double totalPrice;
  final double downPayment;
  final double monthlyIncome;
  final double monthlyGrowthRate;
  final double teleConversionRate;
  final double salesConversionRate;
  final double salesTarget;
  final double teleSalesTarget;
  final double salesActual;
  final double teleSalesActual;
  final double salesEmployeeTarget;
  final double teleSalesEmployeeTarget;
  final int salesMappedEmployees;
  final int teleSalesMappedEmployees;
  final double salesDepartmentTarget;
  final double teleSalesDepartmentTarget;
  final double salesDepartmentActual;
  final double teleSalesDepartmentActual;
  final double salesAverageKpi;
  final double teleSalesAverageKpi;
  final int availableSalesAgents;
  final int availableTeleSalesAgents;
  final List<SalesKpiAgentSummary> agents;
  final String currency;
  final int mappedEmployees;
  final int unmatchedEmployees;
  final int createdTasks;
  final int apiAgentCount;
  final int apiIdentifiedAgentCount;
  final int apiMissingAgentIdCount;
  final bool apiIdentityMappingReady;
  final List<String> integrationWarnings;
  final List<String> unmappedApiAgentKeys;
  final SalesKpiFilters filters;
  final SalesKpiFilterOptions options;
  final DateTime? syncedAt;

  const SalesKpiSummary({
    required this.periodKey,
    required this.periodStart,
    required this.periodEnd,
    required this.totalLeads,
    required this.confirmedMeetings,
    required this.closings,
    required this.paidCustomers,
    required this.totalPrice,
    required this.downPayment,
    required this.monthlyIncome,
    required this.monthlyGrowthRate,
    required this.teleConversionRate,
    required this.salesConversionRate,
    required this.salesTarget,
    required this.teleSalesTarget,
    this.salesActual = 0,
    this.teleSalesActual = 0,
    this.salesEmployeeTarget = 0,
    this.teleSalesEmployeeTarget = 0,
    this.salesMappedEmployees = 0,
    this.teleSalesMappedEmployees = 0,
    this.salesDepartmentTarget = 0,
    this.teleSalesDepartmentTarget = 0,
    this.salesDepartmentActual = 0,
    this.teleSalesDepartmentActual = 0,
    this.salesAverageKpi = 0,
    this.teleSalesAverageKpi = 0,
    this.availableSalesAgents = 0,
    this.availableTeleSalesAgents = 0,
    this.agents = const [],
    this.currency = 'SAR',
    required this.mappedEmployees,
    required this.unmatchedEmployees,
    required this.createdTasks,
    this.apiAgentCount = 0,
    this.apiIdentifiedAgentCount = 0,
    this.apiMissingAgentIdCount = 0,
    this.apiIdentityMappingReady = false,
    this.integrationWarnings = const [],
    this.unmappedApiAgentKeys = const [],
    this.filters = const SalesKpiFilters(),
    this.options = const SalesKpiFilterOptions(),
    this.syncedAt,
  });

  double get effectiveSalesActual => salesDepartmentActual > 0
      ? salesDepartmentActual
      : (salesActual > 0 ? salesActual : totalPrice);

  double get effectiveSalesTarget =>
      salesDepartmentTarget > 0 ? salesDepartmentTarget : salesTarget;

  double get effectiveTeleSalesActual => teleSalesDepartmentActual > 0
      ? teleSalesDepartmentActual
      : (teleSalesActual > 0 ? teleSalesActual : confirmedMeetings.toDouble());

  double get effectiveTeleSalesTarget => teleSalesDepartmentTarget > 0
      ? teleSalesDepartmentTarget
      : teleSalesTarget;

  int get effectiveSalesMappedEmployees {
    if (salesMappedEmployees > 0) return salesMappedEmployees;
    return agents
        .where((agent) => agent.kind == 'sales' && agent.isMapped)
        .map((agent) => agent.mappedUserId)
        .toSet()
        .length;
  }

  int get effectiveTeleSalesMappedEmployees {
    if (teleSalesMappedEmployees > 0) return teleSalesMappedEmployees;
    return agents
        .where((agent) => agent.kind == 'tele_sales' && agent.isMapped)
        .map((agent) => agent.mappedUserId)
        .toSet()
        .length;
  }

  int get effectiveMappedEmployees {
    if (mappedEmployees > 0) return mappedEmployees;
    return agents
        .where((agent) => agent.isMapped)
        .map((agent) => agent.mappedUserId)
        .toSet()
        .length;
  }

  bool get hasAgentBreakdown => agents.isNotEmpty;

  factory SalesKpiSummary.fromMap(Map<String, dynamic> map) {
    int readInt(String key) => (map[key] as num?)?.toInt() ?? 0;
    double readDouble(String key) => (map[key] as num?)?.toDouble() ?? 0;

    return SalesKpiSummary(
      periodKey: map['periodKey'] as String? ?? '',
      periodStart: map['periodStart'] as String? ?? '',
      periodEnd: map['periodEnd'] as String? ?? '',
      totalLeads: readInt('totalLeads'),
      confirmedMeetings: readInt('confirmedMeetings'),
      closings: readInt('closings'),
      paidCustomers: readInt('paidCustomers'),
      totalPrice: readDouble('totalPrice'),
      downPayment: readDouble('downPayment'),
      monthlyIncome: readDouble('monthlyIncome'),
      monthlyGrowthRate: readDouble('monthlyGrowthRate'),
      teleConversionRate: readDouble('teleConversionRate'),
      salesConversionRate: readDouble('salesConversionRate'),
      salesTarget: readDouble('salesTarget'),
      teleSalesTarget: readDouble('teleSalesTarget'),
      salesActual: readDouble('salesActual'),
      teleSalesActual: readDouble('teleSalesActual'),
      salesEmployeeTarget: readDouble('salesEmployeeTarget'),
      teleSalesEmployeeTarget: readDouble('teleSalesEmployeeTarget'),
      salesMappedEmployees: readInt('salesMappedEmployees'),
      teleSalesMappedEmployees: readInt('teleSalesMappedEmployees'),
      salesDepartmentTarget: readDouble('salesDepartmentTarget'),
      teleSalesDepartmentTarget: readDouble('teleSalesDepartmentTarget'),
      salesDepartmentActual: readDouble('salesDepartmentActual'),
      teleSalesDepartmentActual: readDouble('teleSalesDepartmentActual'),
      salesAverageKpi: readDouble('salesAverageKpi'),
      teleSalesAverageKpi: readDouble('teleSalesAverageKpi'),
      availableSalesAgents: readInt('availableSalesAgents'),
      availableTeleSalesAgents: readInt('availableTeleSalesAgents'),
      agents: (map['agentSummaries'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                SalesKpiAgentSummary.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
      currency: map['currency'] as String? ?? 'SAR',
      mappedEmployees: readInt('mappedEmployees'),
      unmatchedEmployees: readInt('unmatchedEmployees'),
      createdTasks: readInt('createdTasks'),
      apiAgentCount: readInt('apiAgentCount'),
      apiIdentifiedAgentCount: readInt('apiIdentifiedAgentCount'),
      apiMissingAgentIdCount: readInt('apiMissingAgentIdCount'),
      apiIdentityMappingReady: map['apiIdentityMappingReady'] == true,
      integrationWarnings: (map['integrationWarnings'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      unmappedApiAgentKeys: (map['unmappedApiAgentKeys'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      filters: SalesKpiFilters.fromMap(
        Map<String, dynamic>.from(map['filters'] as Map? ?? const {}),
      ),
      options: SalesKpiFilterOptions.fromMap(
        Map<String, dynamic>.from(map['options'] as Map? ?? const {}),
      ),
      syncedAt: (map['syncedAt'] as Timestamp?)?.toDate(),
    );
  }
}
