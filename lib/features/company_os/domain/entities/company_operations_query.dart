import 'company_os_page.dart';

final class CompanyOperationsFilter {
  const CompanyOperationsFilter({
    this.type = 'ticket',
    this.query,
    this.status,
    this.departmentId,
    this.from,
    this.to,
    this.cursor,
    this.limit = 25,
  });
  final String type;
  final String? query;
  final String? status;
  final String? departmentId;
  final DateTime? from;
  final DateTime? to;
  final String? cursor;
  final int limit;

  int get safeLimit => limit.clamp(1, 100);
}

final class CompanyOperationsDashboard {
  const CompanyOperationsDashboard({
    required this.openTickets,
    required this.assignedAssets,
    required this.expiringLicenses,
    required this.pendingRequests,
    required this.scope,
  });
  final int openTickets;
  final int assignedAssets;
  final int expiringLicenses;
  final int pendingRequests;
  final String scope;
}

final class CompanyOperationsSearchResult {
  const CompanyOperationsSearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.safeSubtitle,
    required this.route,
  });
  final String id;
  final String type;
  final String title;
  final String safeSubtitle;
  final String route;
}

typedef CompanyOperationsSearchPage =
    CompanyOsPage<CompanyOperationsSearchResult>;
