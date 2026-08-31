import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/feature_flags/remote_company_os_feature_flags.dart';
import '../core/sync/authenticated_operation_client.dart';
import '../features/company_os/data/remote/company_os_api_client.dart';
import '../features/company_os/data/repositories/company_os_operations_repository_impl.dart';
import '../features/company_os/presentation/pages/company_operations_dashboard_page.dart';
import '../features/company_os/presentation/pages/company_os_audit_page.dart';
import '../features/company_os/presentation/pages/company_os_reports_page.dart';
import '../features/company_os/presentation/pages/company_os_search_page.dart';

enum CompanyOsOperationsSurface { dashboard, search, reports, audit }

final class CompanyOsOperationsEntry extends StatefulWidget {
  const CompanyOsOperationsEntry({super.key, required this.surface});
  final CompanyOsOperationsSurface surface;
  @override
  State<CompanyOsOperationsEntry> createState() =>
      _CompanyOsOperationsEntryState();
}

final class _CompanyOsOperationsEntryState
    extends State<CompanyOsOperationsEntry> {
  late final http.Client _client;
  late final CompanyOsOperationsRepositoryImpl _repository;
  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _repository = CompanyOsOperationsRepositoryImpl(
      CompanyOsApiClient(
        baseUri: Uri.parse('https://notification.zawolf.ai/company-os/'),
        client: AuthenticatedOperationClient(
          client: _client,
          tokenProvider: () async =>
              FirebaseAuth.instance.currentUser?.getIdToken(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = context.select<RemoteCompanyOsFeatureFlags, bool>(
      (flags) => flags.isReady,
    );
    if (!ready) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return switch (widget.surface) {
      CompanyOsOperationsSurface.dashboard => CompanyOperationsDashboardPage(
        repository: _repository,
      ),
      CompanyOsOperationsSurface.search => CompanyOsSearchPage(
        repository: _repository,
      ),
      CompanyOsOperationsSurface.reports => CompanyOsReportsPage(
        repository: _repository,
      ),
      CompanyOsOperationsSurface.audit => CompanyOsAuditPage(
        repository: _repository,
      ),
    };
  }
}
