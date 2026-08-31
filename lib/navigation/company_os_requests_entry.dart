import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/feature_flags/remote_company_os_feature_flags.dart';
import '../core/sync/authenticated_operation_client.dart';
import '../features/company_os/data/remote/company_os_api_client.dart';
import '../features/company_os/data/repositories/finance_repository_impl.dart';
import '../features/company_os/data/repositories/drive_company_os_attachment_repository.dart';
import '../features/company_os/data/repositories/operational_request_repository_impl.dart';
import '../features/company_os/domain/entities/operational_request_category.dart';
import '../features/company_os/presentation/pages/employee_finance_page.dart';
import '../features/company_os/presentation/pages/operational_request_page.dart';

enum CompanyOsRequestSurface { create, detail, finance }

final class CompanyOsRequestsEntry extends StatefulWidget {
  const CompanyOsRequestsEntry({
    super.key,
    required this.surface,
    this.requestId,
    this.canDecide = false,
    this.initialCategory,
  });
  final CompanyOsRequestSurface surface;
  final String? requestId;
  final bool canDecide;
  final OperationalRequestCategory? initialCategory;

  @override
  State<CompanyOsRequestsEntry> createState() => _CompanyOsRequestsEntryState();
}

final class _CompanyOsRequestsEntryState extends State<CompanyOsRequestsEntry> {
  late final http.Client _client;
  late final OperationalRequestRepositoryImpl _requests;
  late final DriveCompanyOsAttachmentRepository _attachments;
  late final FinanceRepositoryImpl _finance;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    final api = CompanyOsApiClient(
      baseUri: Uri.parse('https://notification.zawolf.ai/company-os/'),
      client: AuthenticatedOperationClient(
        client: _client,
        tokenProvider: () async =>
            FirebaseAuth.instance.currentUser?.getIdToken(),
      ),
    );
    _requests = OperationalRequestRepositoryImpl(api);
    _attachments = DriveCompanyOsAttachmentRepository(api);
    _finance = FinanceRepositoryImpl(api);
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
      CompanyOsRequestSurface.create => OperationalRequestFormPage(
        repository: _requests,
        attachmentRepository: _attachments,
        initialCategory: widget.initialCategory,
      ),
      CompanyOsRequestSurface.detail => OperationalRequestDetailPage(
        repository: _requests,
        requestId: widget.requestId ?? '',
        canDecide: widget.canDecide,
      ),
      CompanyOsRequestSurface.finance => EmployeeFinancePage(
        repository: _finance,
      ),
    };
  }
}
