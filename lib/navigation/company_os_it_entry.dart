import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/feature_flags/remote_company_os_feature_flags.dart';
import '../core/sync/authenticated_operation_client.dart';
import '../features/company_os/data/remote/company_os_api_client.dart';
import '../features/company_os/data/repositories/it_operations_repository_impl.dart';
import '../features/company_os/presentation/pages/company_assets_page.dart';
import '../features/company_os/presentation/pages/it_ticket_queue_page.dart';
import '../features/company_os/presentation/pages/software_licenses_page.dart';

enum CompanyOsItSurface { tickets, assets, licenses }

final class CompanyOsItEntry extends StatefulWidget {
  const CompanyOsItEntry({super.key, required this.surface});
  final CompanyOsItSurface surface;
  @override
  State<CompanyOsItEntry> createState() => _CompanyOsItEntryState();
}

final class _CompanyOsItEntryState extends State<CompanyOsItEntry> {
  late final http.Client _client;
  late final ItOperationsRepositoryImpl _repository;
  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _repository = ItOperationsRepositoryImpl(
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
      CompanyOsItSurface.tickets => ItTicketQueuePage(repository: _repository),
      CompanyOsItSurface.assets => CompanyAssetsPage(repository: _repository),
      CompanyOsItSurface.licenses => SoftwareLicensesPage(
        repository: _repository,
      ),
    };
  }
}
