import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/feature_flags/remote_company_os_feature_flags.dart';
import '../core/sync/authenticated_operation_client.dart';
import '../features/company_os/data/remote/company_os_api_client.dart';
import '../features/company_os/data/repositories/employee_portal_repository_impl.dart';
import '../features/company_os/data/repositories/firestore_company_announcement_repository.dart';
import '../features/company_os/presentation/pages/company_os_portal_page.dart';

final class CompanyOsEntry extends StatefulWidget {
  const CompanyOsEntry({super.key});

  @override
  State<CompanyOsEntry> createState() => _CompanyOsEntryState();
}

final class _CompanyOsEntryState extends State<CompanyOsEntry> {
  late final http.Client _httpClient;
  late final EmployeePortalRepositoryImpl _repository;
  late final FirestoreCompanyAnnouncementRepository _announcementRepository;

  @override
  void initState() {
    super.initState();
    _httpClient = http.Client();
    _repository = EmployeePortalRepositoryImpl(
      CompanyOsApiClient(
        baseUri: Uri.parse('https://notification.zawolf.ai/company-os/'),
        client: AuthenticatedOperationClient(
          client: _httpClient,
          tokenProvider: () async =>
              FirebaseAuth.instance.currentUser?.getIdToken(),
        ),
      ),
    );
    _announcementRepository = FirestoreCompanyAnnouncementRepository(
      FirebaseFirestore.instance,
    );
  }

  @override
  void dispose() {
    _httpClient.close();
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
    return CompanyOsPortalPage(
      repository: _repository,
      announcementRepository: _announcementRepository,
    );
  }
}
