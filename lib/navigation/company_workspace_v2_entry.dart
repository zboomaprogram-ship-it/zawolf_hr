import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import '../features/company_workspace/data/datasources/company_workspace_remote_data_source.dart';
import '../features/company_workspace/data/datasources/firebase_workspace_session.dart';
import '../features/company_workspace/data/datasources/workspace_resource_remote_data_source.dart';
import '../features/company_workspace/data/datasources/workspace_sheet_remote_data_source.dart';
import '../features/company_workspace/data/datasources/workspace_access_admin_remote_data_source.dart';
import '../features/company_workspace/data/datasources/workspace_reports_remote_data_source.dart';
import '../features/company_workspace/data/local/workspace_operation_outbox_database.dart';
import '../features/company_workspace/data/repositories/company_workspace_repository_impl.dart';
import '../features/company_workspace/data/repositories/workspace_resource_repository_impl.dart';
import '../features/company_workspace/data/repositories/workspace_sheet_repository_impl.dart';
import '../features/company_workspace/data/repositories/workspace_access_administration_repository_impl.dart';
import '../features/company_workspace/data/repositories/workspace_reports_repository_impl.dart';
import '../features/company_workspace/domain/entities/workspace_access_grant.dart';
import '../features/company_workspace/domain/entities/workspace_resource.dart';
import '../features/company_workspace/domain/use_cases/list_accessible_resources.dart';
import '../features/company_workspace/presentation/cubit/workspace_browser_cubit.dart';
import '../features/company_workspace/presentation/cubit/workspace_operations_cubit.dart';
import '../features/company_workspace/presentation/cubit/workspace_sheet_cubit.dart';
import '../features/company_workspace/presentation/cubit/workspace_sheet_sync_cubit.dart';
import '../features/company_workspace/presentation/cubit/workspace_access_admin_cubit.dart';
import '../features/company_workspace/presentation/cubit/workspace_reports_cubit.dart';
import '../features/company_workspace/presentation/pages/company_files_page.dart';
import '../features/company_workspace/presentation/pages/workspace_sheet_editor_page.dart';
import '../features/company_workspace/presentation/pages/workspace_access_admin_page.dart';
import '../features/company_workspace/presentation/pages/workspace_reports_page.dart';

/// Composition root for the disabled-by-default Workspace V2 pilot.
///
/// This is intentionally outside `presentation`: it binds Firebase identity,
/// HTTP and local persistence to domain contracts without allowing widgets to
/// import infrastructure. The existing `/workspace` implementation remains
/// the rollback path until the flag is deliberately enabled for a pilot.
class CompanyWorkspaceV2Entry extends StatefulWidget {
  const CompanyWorkspaceV2Entry({required this.actorId, super.key});

  final String actorId;

  @override
  State<CompanyWorkspaceV2Entry> createState() =>
      _CompanyWorkspaceV2EntryState();
}

class _CompanyWorkspaceV2EntryState extends State<CompanyWorkspaceV2Entry> {
  late final http.Client _client;
  late final WorkspaceOperationOutboxDatabase _database;
  late final FirebaseWorkspaceSession _session;
  late final WorkspaceResourceRepositoryImpl _resources;
  late final WorkspaceSheetRepositoryImpl _sheets;
  late final CompanyWorkspaceRepositoryImpl _operations;
  late final WorkspaceAccessAdministrationRepositoryImpl _accessAdministration;
  late final WorkspaceReportsRepositoryImpl _reports;
  Timer? _outboxReplayTimer;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _database = WorkspaceOperationOutboxDatabase();
    _session = FirebaseWorkspaceSession(FirebaseAuth.instance);
    const baseUri = 'https://notification.zawolf.ai';
    _resources = WorkspaceResourceRepositoryImpl(
      HttpWorkspaceResourceRemoteDataSource(
        client: _client,
        session: _session,
        baseUri: Uri.parse(baseUri),
      ),
    );
    _sheets = WorkspaceSheetRepositoryImpl(
      remote: HttpWorkspaceSheetRemoteDataSource(
        client: _client,
        session: _session,
        baseUri: Uri.parse(baseUri),
      ),
    );
    _operations = CompanyWorkspaceRepositoryImpl(
      remote: HttpCompanyWorkspaceRemoteDataSource(
        client: _client,
        session: _session,
        baseUri: Uri.parse(baseUri),
      ),
      outbox: DriftWorkspaceOperationOutbox(_database),
      // The pilot executes authorization on the server. Grant inspection UI
      // is introduced later with its own scoped repository.
      grantsLoader: (_) async => const <WorkspaceAccessGrant>[],
      accessChecker: ({required resourceId, required capability}) async =>
          false,
    );
    _accessAdministration = WorkspaceAccessAdministrationRepositoryImpl(
      HttpWorkspaceAccessAdminRemoteDataSource(
        client: _client,
        session: _session,
        baseUri: Uri.parse(baseUri),
      ),
    );
    _reports = WorkspaceReportsRepositoryImpl(
      HttpWorkspaceReportsRemoteDataSource(
        client: _client,
        session: _session,
        baseUri: Uri.parse(baseUri),
      ),
    );
    // A queued mutation is always idempotent on the server. Replaying only
    // while this V2 screen is alive gives employees a calm recovery path after
    // temporary Wi‑Fi/provider failures without introducing a second worker.
    unawaited(_replayWorkspaceOutbox());
    _outboxReplayTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_replayWorkspaceOutbox()),
    );
  }

  Future<void> _replayWorkspaceOutbox() async {
    try {
      await _operations.replayPending(widget.actorId, limit: 25);
    } on Object {
      // Pending operations remain in Drift. The individual screen shows the
      // last safe status; do not surface a background technical failure.
    }
  }

  @override
  void dispose() {
    _outboxReplayTimer?.cancel();
    _client.close();
    _database.close();
    super.dispose();
  }

  void _openSpreadsheet(WorkspaceResource resource) {
    _openSpreadsheetId(resource.id);
  }

  void _openSpreadsheetId(String resourceId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => WorkspaceSheetCubit(repository: _sheets),
            ),
            BlocProvider(
              create: (_) => WorkspaceSheetSyncCubit(
                repository: _operations,
                actorId: widget.actorId,
              ),
            ),
          ],
          child: WorkspaceSheetEditorPage(
            resourceId: resourceId,
            initialTab: '',
          ),
        ),
      ),
    );
  }

  void _openAccessAdministration() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider(
          create: (_) => WorkspaceAccessAdminCubit(_accessAdministration),
          child: const WorkspaceAccessAdminPage(),
        ),
      ),
    );
  }

  void _openReports() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider(
          create: (_) => WorkspaceReportsCubit(_reports),
          child: WorkspaceReportsPage(onOpenResource: _openSpreadsheetId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) =>
            WorkspaceBrowserCubit(ListAccessibleResources(_resources))..load(),
      ),
      BlocProvider(
        create: (_) => WorkspaceOperationsCubit(
          repository: _operations,
          actorId: widget.actorId,
        ),
      ),
    ],
    child: CompanyFilesPage(
      onOpenSpreadsheet: _openSpreadsheet,
      onDownload: (resource) => _resources.download(resource.id),
      // The server is still the authority and denies this action for everyone
      // except a super admin or a dynamically identified IT manager.
      onManageAccess: _openAccessAdministration,
      onOpenReports: _openReports,
    ),
  );
}
