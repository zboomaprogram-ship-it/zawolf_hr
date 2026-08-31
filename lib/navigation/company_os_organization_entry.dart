import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/sync/authenticated_operation_client.dart';
import '../features/company_os/data/local/company_os_database.dart';
import '../features/company_os/data/local/company_os_outbox.dart';
import '../features/company_os/data/remote/company_os_api_client.dart';
import '../features/organization_structure/data/local/organization_structure_local_store.dart';
import '../features/organization_structure/data/remote/organization_structure_api.dart';
import '../features/organization_structure/data/repositories/organization_structure_repository_impl.dart';
import '../features/organization_structure/presentation/pages/organization_structure_editor_page.dart';

final class CompanyOsOrganizationEntry extends StatefulWidget {
  const CompanyOsOrganizationEntry({super.key, this.embedded = false});

  final bool embedded;
  @override
  State<CompanyOsOrganizationEntry> createState() =>
      _CompanyOsOrganizationEntryState();
}

final class _CompanyOsOrganizationEntryState
    extends State<CompanyOsOrganizationEntry> {
  late final http.Client _client;
  late final OrganizationStructureRepositoryImpl _repository;
  CompanyOsDatabase? _database;
  late final Future<bool> _canManage;
  @override
  void initState() {
    super.initState();
    _client = http.Client();
    // drift_flutter requires extra SQLite/WASM runtime assets on web. The
    // organization screen is online-only there, so do not let an optional
    // local outbox prevent the page itself from rendering.
    _database = kIsWeb ? null : CompanyOsDatabase();
    final api = OrganizationStructureApi(
      CompanyOsApiClient(
        baseUri: Uri.parse('https://notification.zawolf.ai/company-os/'),
        client: AuthenticatedOperationClient(
          client: _client,
          tokenProvider: () async =>
              FirebaseAuth.instance.currentUser?.getIdToken(),
        ),
      ),
    );
    _canManage = api.canManage().catchError((_) => false);
    _repository = OrganizationStructureRepositoryImpl(
      api: api,
      local: _database == null
          ? null
          : OrganizationStructureLocalStore(
              outbox: CompanyOsOutbox(_database!),
              database: _database!,
            ),
      actorUid: FirebaseAuth.instance.currentUser?.uid,
    );
  }

  @override
  void dispose() {
    _client.close();
    _database?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _canManage,
    builder: (context, snapshot) => OrganizationStructureEditorPage(
      repository: _repository,
      canManage: snapshot.data ?? false,
      multiTreeEnabled: true,
      embedded: widget.embedded,
    ),
  );
}
